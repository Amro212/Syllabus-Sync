const APP_STORE_AUDIENCE = 'appstoreconnect-v1';
const APP_STORE_PRODUCTION_URL = 'https://api.storekit.apple.com';
const APP_STORE_SANDBOX_URL = 'https://api.storekit-sandbox.apple.com';

type AppStoreTransactionInfoResponse = {
	signedTransactionInfo: string;
};

type DecodedTransactionPayload = {
	transactionId: string;
	originalTransactionId?: string;
	appTransactionId?: string;
	appAccountToken?: string;
	productId: string;
	bundleId: string;
	environment: string;
	revocationDate?: number;
	signedDate?: number;
};

export type VerifiedAppStorePurchase = {
	transactionID: string;
	originalTransactionID: string | null;
	appTransactionID: string | null;
	appAccountToken: string | null;
	productID: string;
	bundleID: string;
	environment: string;
	revocationDate: number | null;
	signedDate: number | null;
};

export type VerifyPurchaseInput = {
	transactionID: string;
	environment?: string | null;
	signedTransactionInfo?: string | null;
};

export function isAppStorePurchaseConfigured(env: Env): boolean {
	return [env.APP_STORE_ISSUER_ID, env.APP_STORE_KEY_ID, env.APP_STORE_PRIVATE_KEY, env.APPLE_BUNDLE_ID]
		.every(value => Boolean(value?.trim()));
}

export async function verifyAppStorePurchase(
	env: Env,
	input: VerifyPurchaseInput,
): Promise<VerifiedAppStorePurchase> {
	const normalizedEnvironment = normalizeEnvironment(input.environment);

	if (normalizedEnvironment === 'xcode') {
		if ((env.NODE_ENV || '').toLowerCase() !== 'development') {
			throw new Error('Xcode StoreKit transactions are only available in development.');
		}
		if (!input.signedTransactionInfo) {
			throw new Error('Missing signed transaction for Xcode StoreKit validation.');
		}
		return mapTransactionPayload(decodeTransactionBlob<DecodedTransactionPayload>(input.signedTransactionInfo));
	}

	const bearerToken = await createAppStoreServerToken(env);
	const baseURL = normalizedEnvironment === 'sandbox' ? APP_STORE_SANDBOX_URL : APP_STORE_PRODUCTION_URL;
	const url = `${baseURL}/inApps/v1/transactions/${encodeURIComponent(input.transactionID)}`;
	const response = await fetch(url, {
		method: 'GET',
		headers: {
			Authorization: `Bearer ${bearerToken}`,
			Accept: 'application/json',
		},
	});

	if (!response.ok) {
		throw new Error(`App Store transaction lookup failed with ${response.status}: ${(await response.text()).slice(0, 300)}`);
	}

	const body = await response.json() as AppStoreTransactionInfoResponse;
	if (!body.signedTransactionInfo) {
		throw new Error('App Store transaction lookup returned no signed transaction info.');
	}

	return mapTransactionPayload(decodeJWSPayload<DecodedTransactionPayload>(body.signedTransactionInfo));
}

function mapTransactionPayload(payload: DecodedTransactionPayload): VerifiedAppStorePurchase {
	if (!payload.transactionId || !payload.productId || !payload.bundleId || !payload.environment) {
		throw new Error('App Store transaction payload is missing required fields.');
	}

	return {
		transactionID: payload.transactionId,
		originalTransactionID: payload.originalTransactionId ?? null,
		appTransactionID: payload.appTransactionId ?? null,
		appAccountToken: payload.appAccountToken ?? null,
		productID: payload.productId,
		bundleID: payload.bundleId,
		environment: payload.environment,
		revocationDate: payload.revocationDate ?? null,
		signedDate: payload.signedDate ?? null,
	};
}

async function createAppStoreServerToken(env: Env): Promise<string> {
	const issuerID = requiredEnv(env, 'APP_STORE_ISSUER_ID');
	const keyID = requiredEnv(env, 'APP_STORE_KEY_ID');
	const bundleID = requiredEnv(env, 'APPLE_BUNDLE_ID');
	const privateKey = requiredEnv(env, 'APP_STORE_PRIVATE_KEY');

	const issuedAt = Math.floor(Date.now() / 1000);
	const expiresAt = issuedAt + 60 * 10;
	const header = {
		alg: 'ES256',
		kid: keyID,
		typ: 'JWT',
	};
	const payload = {
		iss: issuerID,
		iat: issuedAt,
		exp: expiresAt,
		aud: APP_STORE_AUDIENCE,
		bid: bundleID,
	};

	const encodedHeader = base64url(JSON.stringify(header));
	const encodedPayload = base64url(JSON.stringify(payload));
	const signingInput = `${encodedHeader}.${encodedPayload}`;
	const signature = await signES256(privateKey, signingInput);
	return `${signingInput}.${signature}`;
}

async function signES256(privateKeyPem: string, signingInput: string): Promise<string> {
	const pemBody = privateKeyPem
		.replace(/\\n/g, '\n')
		.replace('-----BEGIN PRIVATE KEY-----', '')
		.replace('-----END PRIVATE KEY-----', '')
		.replace(/\s+/g, '');
	const keyData = base64urlToBytes(pemBody.replace(/\+/g, '-').replace(/\//g, '_'));
	const cryptoKey = await crypto.subtle.importKey(
		'pkcs8',
		keyData,
		{
			name: 'ECDSA',
			namedCurve: 'P-256',
		},
		false,
		['sign'],
	);
	const signature = await crypto.subtle.sign(
		{ name: 'ECDSA', hash: 'SHA-256' },
		cryptoKey,
		new TextEncoder().encode(signingInput),
	);
	return base64urlBytes(new Uint8Array(signature));
}

function requiredEnv(env: Env, key: string): string {
	const value = ((env as any)[key] as string | undefined)?.trim();
	if (!value) {
		throw new Error(`${key} is not configured.`);
	}
	return value;
}

function normalizeEnvironment(value?: string | null): 'production' | 'sandbox' | 'xcode' {
	switch ((value || '').toLowerCase()) {
		case 'sandbox':
			return 'sandbox';
		case 'xcode':
			return 'xcode';
		default:
			return 'production';
	}
}

function decodeTransactionBlob<T>(value: string): T {
	const trimmed = value.trim();
	if (trimmed.startsWith('{')) {
		return JSON.parse(trimmed) as T;
	}
	return decodeJWSPayload<T>(trimmed);
}

function decodeJWSPayload<T>(jws: string): T {
	const parts = jws.split('.');
	if (parts.length < 2) {
		throw new Error('Invalid JWS payload.');
	}
	const payloadBytes = base64urlToBytes(parts[1]);
	return JSON.parse(new TextDecoder().decode(payloadBytes)) as T;
}

function base64url(input: string): string {
	return base64urlBytes(new TextEncoder().encode(input));
}

function base64urlBytes(bytes: Uint8Array): string {
	return btoa(String.fromCharCode(...bytes))
		.replace(/\+/g, '-')
		.replace(/\//g, '_')
		.replace(/=+$/g, '');
}

function base64urlToBytes(value: string) {
	const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
	const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);
	const decoded = atob(padded);
	return Uint8Array.from(decoded, (char) => char.charCodeAt(0));
}
