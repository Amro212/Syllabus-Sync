import { env, createExecutionContext, waitOnExecutionContext, SELF } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import worker from '../src/index';

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;
const TEST_USER_ID = '11111111-1111-1111-1111-111111111111';
const TEST_PRODUCT_ID = 'syllabussync.ai_scans_5';
const TEST_BUNDLE_ID = 'SylSyn.Syllabus-Sync';
const TEST_PRIVATE_KEY = `-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgime/Jruks463ToPF
huKi0aG8DVF7Zb1E6QiXA5JdL+yhRANCAATiAV+ZVCuOLs4a38EDHS5D1CfsFo47
RJEuuQYkanmIO31bg+UAsq0TPwLF3MvUupNjmQrU5SvrpQPvmSKrVwew
-----END PRIVATE KEY-----`;

describe('worker', () => {
	beforeEach(() => {
		env.OPENROUTER_API_KEY = 'test-key';
		env.ALLOWED_ORIGINS = 'http://localhost:*';
		env.SUPABASE_URL = 'https://example.supabase.co';
		env.SUPABASE_SERVICE_ROLE_KEY = 'service-role-test-key';
		env.APPLE_BUNDLE_ID = TEST_BUNDLE_ID;
		env.APP_STORE_ISSUER_ID = '57246542-96fe-1a63-e053-0824d011072a';
		env.APP_STORE_KEY_ID = '2X9R4HXF34';
		env.APP_STORE_PRIVATE_KEY = TEST_PRIVATE_KEY;
		env.APPLE_IAP_PRODUCT_ID_AI_SCANS_5 = TEST_PRODUCT_ID;
		env.APPLE_IAP_PACK_CREDITS = '5';
	});

	afterEach(() => {
		vi.restoreAllMocks();
	});

	it('responds with not found (unit style)', async () => {
		const request = new IncomingRequest('http://example.com');
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);
		expect(await response.text()).toMatchInlineSnapshot(`"{"error":"Not Found","path":"/"}"`);
	});

	it('responds with not found (integration style)', async () => {
		const response = await SELF.fetch('https://example.com');
		expect(await response.text()).toMatchInlineSnapshot(`"{"error":"Not Found","path":"/"}"`);
	});

	it('serves release pages without API credentials', async () => {
		const unconfigured = { ...env, OPENROUTER_API_KEY: '', SUPABASE_SERVICE_ROLE_KEY: '' };
		for (const [path, title] of [['/privacy', 'Privacy Policy'], ['/support', 'Support']]) {
			const response = await worker.fetch(new IncomingRequest(`https://example.com${path}`), unconfigured, createExecutionContext());
			expect(response.status).toBe(200);
			expect(response.headers.get('Content-Type')).toContain('text/html');
			expect(await response.text()).toContain(`<h1>${title}</h1>`);
		}
	});

	it('requires authentication for account deletion', async () => {
		const response = await worker.fetch(new IncomingRequest('https://example.com/account', { method: 'DELETE' }), env, createExecutionContext());
		expect(response.status).toBe(401);
	});

	it('deletes only the account identified by the signed-in session', async () => {
		const removeUser = vi.fn();
		mockFetch(async (input, init) => {
			if (String(input).endsWith('/auth/v1/user')) return jsonResponse({ id: TEST_USER_ID });
			removeUser(String(input), init?.method);
			return jsonResponse({});
		});
		const request = new IncomingRequest('https://example.com/account', {
			method: 'DELETE',
			headers: { Authorization: 'Bearer valid-token', 'Content-Type': 'application/json' },
			body: JSON.stringify({ userId: 'ignored' }),
		});
		const response = await worker.fetch(request, env, createExecutionContext());
		expect(response.status).toBe(200);
		expect(await response.json()).toEqual({ deleted: true });
		expect(removeUser).toHaveBeenCalledExactlyOnceWith(`https://example.supabase.co/auth/v1/admin/users/${TEST_USER_ID}`, 'DELETE');
	});

	it('requires a current app build before accepting syllabus text in production', async () => {
		mockFetch(createHandler({}));
		const production = { ...env, NODE_ENV: 'production', ALLOWED_ORIGINS: '' };
		const response = await worker.fetch(new IncomingRequest('https://example.com/parse', {
			method: 'POST',
			headers: { Authorization: 'Bearer valid-token' },
		}), production, createExecutionContext());
		expect(response.status).toBe(409);
		expect(await response.json()).toMatchObject({ code: 'AI_CONSENT_REQUIRED' });
	});

	it('returns ai usage balance for authenticated user', async () => {
		mockFetch(createHandler({
			getAIUsageBalance: {
				free_used_count: 1,
				free_remaining: 1,
				free_allowance: 2,
				paid_remaining: 3,
				total_remaining: 4,
				can_scan: true,
			},
		}));

		const request = new IncomingRequest('http://example.com/ai-usage', {
			method: 'GET',
			headers: {
				Origin: 'http://localhost:3000',
				Authorization: 'Bearer valid-token',
			},
		});

		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);

		expect(response.status).toBe(200);
		const payload = await response.json<any>();
		expect(payload.usage).toMatchObject({
			freeUsedCount: 1,
			freeRemaining: 1,
			paidRemaining: 3,
			totalRemaining: 4,
			productId: TEST_PRODUCT_ID,
			packCredits: 5,
			purchasesAvailable: true,
		});
	});

	it('returns payment required when user has no scan credits', async () => {
		mockFetch(createHandler({
			reserveParseCredit: {
				event_id: null,
				credit_source: null,
				reused: false,
				free_used_count: 2,
				free_remaining: 0,
				free_allowance: 2,
				paid_remaining: 0,
				total_remaining: 0,
				can_scan: false,
			},
		}));

		const request = new IncomingRequest('http://example.com/parse', {
			method: 'POST',
			headers: {
				Origin: 'http://localhost:3000',
				'Content-Type': 'application/json',
				Authorization: 'Bearer valid-token',
				'x-idempotency-key': 'parse-001',
			},
			body: JSON.stringify({
				text: 'CS101\nMidterm on October 20',
			}),
		});

		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);

		expect(response.status).toBe(402);
		const payload = await response.json<any>();
		expect(payload.code).toBe('PAYMENT_REQUIRED');
		expect(payload.usage).toMatchObject({
			freeRemaining: 0,
			paidRemaining: 0,
			totalRemaining: 0,
		});
	});

	it('refunds reserved credit when OpenRouter parsing fails', async () => {
		const refundSpy = vi.fn();
		mockFetch(createHandler({
			reserveParseCredit: {
				event_id: 'evt-refund',
				credit_source: 'free',
				reused: false,
				free_used_count: 1,
				free_remaining: 1,
				free_allowance: 2,
				paid_remaining: 0,
				total_remaining: 1,
				can_scan: true,
			},
			openRouterError: 'boom',
			onRefund: refundSpy,
		}));

		const request = new IncomingRequest('http://example.com/parse', {
			method: 'POST',
			headers: {
				Origin: 'http://localhost:3000',
				'Content-Type': 'application/json',
				Authorization: 'Bearer valid-token',
				'x-idempotency-key': 'parse-002',
			},
			body: JSON.stringify({
				text: 'CS101\nAssignment 1 due October 20',
			}),
		});

		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);

		expect(response.status).toBe(502);
		expect(refundSpy).toHaveBeenCalledTimes(1);
	});

	it('returns injected grading placeholders and finalizes reserved credit', async () => {
		const finalizeSpy = vi.fn();
		mockFetch(createHandler({
			reserveParseCredit: {
				event_id: 'evt-success',
				credit_source: 'free',
				reused: false,
				free_used_count: 1,
				free_remaining: 1,
				free_allowance: 2,
				paid_remaining: 0,
				total_remaining: 1,
				can_scan: true,
			},
			finalizeParseCredit: finalizeSpy,
			openRouterContent: '{"events":[]}',
		}));

		const request = new IncomingRequest('http://example.com/parse', {
			method: 'POST',
			headers: {
				Origin: 'http://localhost:3000',
				'Content-Type': 'application/json',
				Authorization: 'Bearer valid-token',
				'x-idempotency-key': 'parse-003',
			},
			body: JSON.stringify({
				text: [
					'CS101 Introduction to Testing',
					'Grading Breakdown:',
					'Final Exam: 100%',
				].join('\n'),
			}),
		});

		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);

		expect(response.status).toBe(200);
		const payload = await response.json<any>();
		expect(payload.events).toHaveLength(1);
		expect(payload.events[0]).toMatchObject({
			title: 'Final Exam',
			type: 'FINAL',
			needsDate: true,
			start: null,
		});
		expect(payload.usage).toMatchObject({
			freeRemaining: 1,
			totalRemaining: 1,
		});
		expect(finalizeSpy).toHaveBeenCalledTimes(1);
	});

	it.each([
		{ accountToken: TEST_USER_ID.toUpperCase(), status: 200 },
		{ accountToken: '22222222-2222-4222-8222-222222222222', status: 409 },
	])('binds verified scan purchases to the account (status $status)', async ({ accountToken, status }) => {
		mockFetch(createHandler({
			findPurchaseEvent: [],
			creditPurchase: {
				free_used_count: 2,
				free_remaining: 0,
				free_allowance: 2,
				paid_remaining: 5,
				total_remaining: 5,
				can_scan: true,
			},
			appStoreTransactionPayload: {
				transactionId: '200000000000001',
				originalTransactionId: '200000000000001',
				appTransactionId: '300000000000001',
				appAccountToken: accountToken,
				productId: TEST_PRODUCT_ID,
				bundleId: TEST_BUNDLE_ID,
				environment: 'Sandbox',
				signedDate: Date.now(),
			},
		}));

		const request = new IncomingRequest('http://example.com/iap/credit', {
			method: 'POST',
			headers: {
				Origin: 'http://localhost:3000',
				'Content-Type': 'application/json',
				Authorization: 'Bearer valid-token',
			},
			body: JSON.stringify({
				transactionId: '200000000000001',
				productId: TEST_PRODUCT_ID,
				environment: 'sandbox',
			}),
		});

		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);

		expect(response.status).toBe(status);
		if (status === 409) {
			await expect(response.json()).resolves.toEqual({
				error: 'Sign in to the Syllabus Sync account used for this purchase.',
			});
			return;
		}
		const payload = await response.json<any>();
		expect(payload.credited).toBe(true);
		expect(payload.usage).toMatchObject({
			paidRemaining: 5,
			totalRemaining: 5,
		});
	});
});

type HandlerOptions = {
	getAIUsageBalance?: Record<string, unknown>;
	reserveParseCredit?: Record<string, unknown>;
	openRouterContent?: string;
	openRouterError?: string;
	findPurchaseEvent?: Record<string, unknown>[];
	creditPurchase?: Record<string, unknown>;
	appStoreTransactionPayload?: Record<string, unknown>;
	onRefund?: ReturnType<typeof vi.fn>;
	finalizeParseCredit?: ReturnType<typeof vi.fn>;
};

function createHandler(options: HandlerOptions) {
	return async (input: RequestInfo | URL, init?: RequestInit) => {
		const url = String(input);
		if (url.includes('/auth/v1/user')) {
			return jsonResponse({ id: TEST_USER_ID });
		}
		if (url.includes('/rest/v1/rpc/get_ai_usage_balance')) {
			return jsonResponse([options.getAIUsageBalance ?? defaultUsageBalance()]);
		}
		if (url.includes('/rest/v1/rpc/reserve_ai_parse_credit')) {
			return jsonResponse([options.reserveParseCredit ?? defaultReserveCredit()]);
		}
		if (url.includes('/rest/v1/rpc/finalize_ai_parse_credit')) {
			options.finalizeParseCredit?.();
			return new Response(null, { status: 204 });
		}
		if (url.includes('/rest/v1/rpc/refund_ai_parse_credit')) {
			options.onRefund?.();
			return new Response(null, { status: 204 });
		}
		if (url.includes('/rest/v1/ai_usage_events')) {
			return jsonResponse(options.findPurchaseEvent ?? []);
		}
		if (url.includes('/rest/v1/rpc/credit_ai_purchase')) {
			return jsonResponse([options.creditPurchase ?? {
				free_used_count: 2,
				free_remaining: 0,
				free_allowance: 2,
				paid_remaining: 5,
				total_remaining: 5,
				can_scan: true,
			}]);
		}
		if (url.includes('/inApps/v1/transactions/')) {
			return jsonResponse({
				signedTransactionInfo: buildJWS(options.appStoreTransactionPayload ?? {
					transactionId: '200000000000001',
					originalTransactionId: '200000000000001',
					appTransactionId: '300000000000001',
					appAccountToken: TEST_USER_ID,
					productId: TEST_PRODUCT_ID,
					bundleId: TEST_BUNDLE_ID,
					environment: 'Sandbox',
				}),
			});
		}
		if (url.includes('/v1/chat/completions')) {
			if (options.openRouterError) {
				return new Response(options.openRouterError, { status: 500 });
			}
			return jsonResponse({
				choices: [
					{
						message: {
							content: options.openRouterContent ?? JSON.stringify([{
								id: 'a1',
								courseCode: 'CS101',
								type: 'ASSIGNMENT',
								title: 'Assignment 1',
								start: '2025-10-20T00:00:00.000-05:00',
							}]),
						},
					},
				],
			});
		}
		throw new Error(`Unhandled fetch: ${url} ${init?.method ?? 'GET'}`);
	};
}

function defaultUsageBalance() {
	return {
		free_used_count: 0,
		free_remaining: 2,
		free_allowance: 2,
		paid_remaining: 0,
		total_remaining: 2,
		can_scan: true,
	};
}

function defaultReserveCredit() {
	return {
		event_id: 'evt-1',
		credit_source: 'free',
		reused: false,
		...defaultUsageBalance(),
	};
}

function buildJWS(payload: Record<string, unknown>): string {
	const header = base64url(JSON.stringify({ alg: 'ES256', kid: 'TEST', typ: 'JWT' }));
	const body = base64url(JSON.stringify(payload));
	return `${header}.${body}.signature`;
}

function base64url(value: string): string {
	return btoa(value).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function jsonResponse(value: unknown, status = 200): Response {
	return new Response(JSON.stringify(value), {
		status,
		headers: { 'Content-Type': 'application/json' },
	});
}

function mockFetch(handler: ReturnType<typeof createHandler>) {
	vi.spyOn(globalThis, 'fetch').mockImplementation(handler as typeof fetch);
}
