import { isAppStorePurchaseConfigured } from './appStore';

type SupabaseRequestOptions = {
	method?: 'GET' | 'POST';
	query?: Record<string, string>;
	body?: unknown;
	headers?: Record<string, string>;
};

export type AIUsageSnapshot = {
	freeUsedCount: number;
	freeRemaining: number;
	freeAllowance: number;
	paidRemaining: number;
	totalRemaining: number;
	canScan: boolean;
	productId: string;
	packCredits: number;
	purchasesAvailable: boolean;
};

type AIUsageBalanceRow = {
	free_used_count: number;
	free_remaining: number;
	free_allowance: number;
	paid_remaining: number;
	total_remaining: number;
	can_scan: boolean;
};

type ReserveCreditRow = AIUsageBalanceRow & {
	event_id: string | null;
	credit_source: 'free' | 'paid' | null;
	reused: boolean;
};

type PurchaseEventRow = {
	user_id: string;
	transaction_id: string;
};

const DEFAULT_PRODUCT_ID = 'syllabussync.ai_scans_5';
const DEFAULT_PACK_CREDITS = 5;

export function aiProductID(env: Env): string {
	return ((env as any).APPLE_IAP_PRODUCT_ID_AI_SCANS_5 as string | undefined)?.trim() || DEFAULT_PRODUCT_ID;
}

export function aiPackCredits(env: Env): number {
	const raw = Number.parseInt(((env as any).APPLE_IAP_PACK_CREDITS as string | undefined) || '', 10);
	return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_PACK_CREDITS;
}

export function mapUsageSnapshot(env: Env, row: AIUsageBalanceRow): AIUsageSnapshot {
	return {
		freeUsedCount: row.free_used_count,
		freeRemaining: row.free_remaining,
		freeAllowance: row.free_allowance,
		paidRemaining: row.paid_remaining,
		totalRemaining: row.total_remaining,
		canScan: row.can_scan,
		productId: aiProductID(env),
		packCredits: aiPackCredits(env),
		purchasesAvailable: isAppStorePurchaseConfigured(env),
	};
}

export async function getAIUsageBalance(env: Env, userID: string): Promise<AIUsageSnapshot> {
	const rows = await supabaseRpc<AIUsageBalanceRow>(env, 'get_ai_usage_balance', {
		target_user_id: userID,
	});
	const row = rows[0] ?? {
		free_used_count: 0,
		free_remaining: 2,
		free_allowance: 2,
		paid_remaining: 0,
		total_remaining: 2,
		can_scan: true,
	};
	return mapUsageSnapshot(env, row);
}

export async function findPurchaseEventByTransactionID(env: Env, transactionID: string): Promise<PurchaseEventRow | null> {
	const rows = await supabaseRequest<PurchaseEventRow>(env, '/rest/v1/ai_usage_events', {
		query: {
			select: 'user_id,transaction_id',
			transaction_id: `eq.${transactionID}`,
			limit: '1',
		},
	});
	return rows[0] ?? null;
}

export async function reserveParseCredit(
	env: Env,
	userID: string,
	requestKey: string | null,
): Promise<{ eventID: string | null; creditSource: 'free' | 'paid' | null; reused: boolean; usage: AIUsageSnapshot; canScan: boolean }> {
	const rows = await supabaseRpc<ReserveCreditRow>(env, 'reserve_ai_parse_credit', {
		target_user_id: userID,
		target_request_key: requestKey,
	});
	const row = rows[0];
	if (!row) {
		throw new Error('reserve_ai_parse_credit returned no rows');
	}

	return {
		eventID: row.event_id,
		creditSource: row.credit_source,
		reused: row.reused,
		usage: mapUsageSnapshot(env, row),
		canScan: row.can_scan,
	};
}

export async function finalizeParseCredit(env: Env, eventID: string | null): Promise<void> {
	if (!eventID) return;
	await supabaseRpcNoResult(env, 'finalize_ai_parse_credit', { target_event_id: eventID });
}

export async function refundParseCredit(env: Env, eventID: string | null): Promise<void> {
	if (!eventID) return;
	await supabaseRpcNoResult(env, 'refund_ai_parse_credit', { target_event_id: eventID });
}

export async function creditPurchase(
	env: Env,
	userID: string,
	input: {
		transactionID: string;
		originalTransactionID?: string | null;
		appTransactionID?: string | null;
		productID: string;
		environment: string;
		credits: number;
		metadata?: Record<string, unknown>;
	},
): Promise<AIUsageSnapshot> {
	const rows = await supabaseRpc<AIUsageBalanceRow>(env, 'credit_ai_purchase', {
		target_user_id: userID,
		purchase_transaction_id: input.transactionID,
		purchase_original_transaction_id: input.originalTransactionID ?? null,
		purchase_app_transaction_id: input.appTransactionID ?? null,
		purchase_product_id: input.productID,
		purchase_environment: input.environment,
		purchased_units: input.credits,
		purchase_metadata: input.metadata ?? {},
	});
	const row = rows[0];
	if (!row) {
		throw new Error('credit_ai_purchase returned no rows');
	}
	return mapUsageSnapshot(env, row);
}

async function supabaseRpcNoResult(env: Env, fn: string, body: Record<string, unknown>): Promise<void> {
	await supabaseRequest<unknown>(env, `/rest/v1/rpc/${fn}`, {
		method: 'POST',
		body,
		headers: { Prefer: 'return=minimal' },
	});
}

async function supabaseRpc<T>(env: Env, fn: string, body: Record<string, unknown>): Promise<T[]> {
	return supabaseRequest<T>(env, `/rest/v1/rpc/${fn}`, {
		method: 'POST',
		body,
	});
}

async function supabaseRequest<T>(
	env: Env,
	path: string,
	options: SupabaseRequestOptions = {},
): Promise<T[]> {
	const serviceRoleKey = (env as any).SUPABASE_SERVICE_ROLE_KEY as string | undefined;
	const supabaseURL = (env as any).SUPABASE_URL as string | undefined;
	if (!serviceRoleKey || !supabaseURL) {
		throw new Error('Supabase service role is not configured.');
	}

	const url = new URL(path, `${supabaseURL}/`);
	for (const [key, value] of Object.entries(options.query ?? {})) {
		url.searchParams.set(key, value);
	}

	const response = await fetch(url, {
		method: options.method ?? 'GET',
		headers: {
			Authorization: `Bearer ${serviceRoleKey}`,
			apikey: serviceRoleKey,
			'Content-Type': 'application/json',
			...options.headers,
		},
		body: options.body === undefined ? undefined : JSON.stringify(options.body),
	});

	if (!response.ok) {
		throw new Error(`Supabase request failed with ${response.status}: ${(await response.text()).slice(0, 300)}`);
	}

	if (response.status === 204) {
		return [];
	}

	return await response.json<T[]>();
}
