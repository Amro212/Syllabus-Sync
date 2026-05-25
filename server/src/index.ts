/**
 * Syllabus Sync Server - Cloudflare Workers API
 * 
 * Provides endpoints for:
 * - Health check
 * - Syllabus parsing via OpenAI
 * - PDF upload/storage (optional)
 */
import { logRequest, logError, nowIso } from './logging';
import { ensureOpenAIKey } from './env';
import { validateEvents, type ValidationConfig } from './validation/eventValidation';
import { ensureSchemeCoverage } from './validation/eventValidation';
import { buildParseSyllabusRequest } from './prompts/parseSyllabus';
import { detectCourseCode } from './utils/courseCode';
import { callOpenAIParse } from './clients/openai';
import { splitMultiDayRecurrence } from './utils/splitMultiDayRecurrence';
import { extractGradingScheme } from './utils/extractGradingScheme';

type SocialUserProfileRow = {
	id: string;
	username?: string | null;
	display_name?: string | null;
};

type SocialFriendshipRow = {
	id: string;
	user_a_id: string;
	user_b_id: string;
};

type SocialFriendRequestRow = {
	from_user_id: string;
	to_user_id: string;
	status: string;
};

type SocialCourseMembershipRow = {
	user_id: string;
	code: string;
};

type RecommendationUser = {
	id: string;
	username: string;
	displayName: string | null;
	mutualFriendsCount: number;
	sharedCourseCodes: string[];
	requestState: 'none' | 'requested' | 'friends';
};

type AuthenticatedUser = {
	id: string;
	email?: string | null;
};

type DurableLimitRequest = {
	limit: number;
	windowSec: number;
	cost?: number;
};

type DurableLimitResponse = {
	allowed: boolean;
	remaining: number;
	retryAfterSec: number;
	limit: number;
	used: number;
};

// Basic in-memory token buckets (local/test fallback only).
const buckets = new Map<string, { tokens: number; lastRefill: number }>();

// Basic in-memory OpenAI usage tracking (per-isolate, best-effort)
type OpenAIUsage = {
	dayKey: string; // YYYY-MM-DD UTC
	totalCalls: number;
	totalCost: number;
	perIpCalls: Map<string, number>;
};
const openaiUsage: OpenAIUsage = {
	dayKey: new Date().toISOString().slice(0, 10),
	totalCalls: 0,
	totalCost: 0,
	perIpCalls: new Map(),
};

export class AbuseLimiter {
	constructor(private readonly state: DurableObjectState) {}

	async fetch(request: Request): Promise<Response> {
		if (request.method !== 'POST') {
			return new Response('Method Not Allowed', { status: 405 });
		}

		const body = await request.json() as DurableLimitRequest;
		const limit = Math.max(1, Math.floor(body.limit));
		const windowSec = Math.max(1, Math.floor(body.windowSec));
		const cost = Math.max(0, Number(body.cost ?? 1));
		const now = Date.now();
		const windowMs = windowSec * 1000;
		const stored = await this.state.storage.get<{ used: number; resetAt: number }>('window');
		const current = stored && stored.resetAt > now
			? stored
			: { used: 0, resetAt: now + windowMs };
		const nextUsed = current.used + cost;

		if (nextUsed > limit) {
			const retryAfterSec = Math.max(1, Math.ceil((current.resetAt - now) / 1000));
			return Response.json({
				allowed: false,
				remaining: Math.max(0, Math.floor(limit - current.used)),
				retryAfterSec,
				limit,
				used: current.used,
			} satisfies DurableLimitResponse);
		}

		current.used = nextUsed;
		await this.state.storage.put('window', current);
		return Response.json({
			allowed: true,
			remaining: Math.max(0, Math.floor(limit - current.used)),
			retryAfterSec: 0,
			limit,
			used: current.used,
		} satisfies DurableLimitResponse);
	}
}

function normalizedCourseCode(code: string): string {
	return code.trim().toUpperCase();
}

function deduplicatedFriendships(rows: SocialFriendshipRow[]): SocialFriendshipRow[] {
	const seen = new Set<string>();
	const unique: SocialFriendshipRow[] = [];
	for (const row of rows) {
		if (seen.has(row.id)) continue;
		seen.add(row.id);
		unique.push(row);
	}
	return unique;
}

function requestSortOrder(state: RecommendationUser['requestState']): number {
	switch (state) {
		case 'none': return 0;
		case 'requested': return 1;
		case 'friends': return 2;
	}
}

function sortRecommendationUsers(users: RecommendationUser[]): RecommendationUser[] {
	return [...users].sort((lhs, rhs) => {
		const lhsState = requestSortOrder(lhs.requestState);
		const rhsState = requestSortOrder(rhs.requestState);
		if (lhsState !== rhsState) return lhsState - rhsState;

		const lhsRecommended = lhs.mutualFriendsCount > 0 || lhs.sharedCourseCodes.length > 0;
		const rhsRecommended = rhs.mutualFriendsCount > 0 || rhs.sharedCourseCodes.length > 0;
		if (lhsRecommended !== rhsRecommended) return lhsRecommended ? -1 : 1;
		if (lhs.mutualFriendsCount !== rhs.mutualFriendsCount) return rhs.mutualFriendsCount - lhs.mutualFriendsCount;
		if (lhs.sharedCourseCodes.length !== rhs.sharedCourseCodes.length) return rhs.sharedCourseCodes.length - lhs.sharedCourseCodes.length;
		return lhs.username.localeCompare(rhs.username, undefined, { sensitivity: 'base' });
	});
}

function inFilter(values: string[]): string {
	return `in.(${values.join(',')})`;
}

function resetOpenAIUsageIfNewDay() {
	const today = new Date().toISOString().slice(0, 10);
	if (openaiUsage.dayKey !== today) {
		openaiUsage.dayKey = today;
		openaiUsage.totalCalls = 0;
		openaiUsage.totalCost = 0;
		openaiUsage.perIpCalls.clear();
	}
}

function getClientIp(req: Request): string {
	// Prefer Cloudflare-provided header; fallback to X-Forwarded-For
	const h = req.headers;
	const ip = h.get('CF-Connecting-IP') || h.get('x-forwarded-for')?.split(',')[0].trim();
	return ip || 'unknown';
}

function isProduction(env: Env): boolean {
	return (env.NODE_ENV || '').toLowerCase() === 'production';
}

function isUnsafeProductionOrigin(origin: string): boolean {
	if (origin.includes('*')) return true;
	try {
		const url = new URL(origin);
		const hostname = url.hostname.toLowerCase();
		return url.protocol !== 'https:'
			|| hostname === 'localhost'
			|| hostname === '127.0.0.1'
			|| hostname === '::1'
			|| hostname.endsWith('.localhost');
	} catch {
		return true;
	}
}

function validateProductionConfig(env: Env): string | null {
	if (!isProduction(env)) return null;
	if ((env as any).DEBUG_ALLOW_TEST_FAILURES === 'true') {
		return 'Production debug failure injection is enabled.';
	}
	if (!(env as any).ABUSE_LIMITER) {
		return 'Production abuse limiter binding is not configured.';
	}
	const origins = (env.ALLOWED_ORIGINS ?? '').split(',').map((s: string) => s.trim()).filter(Boolean);
	const unsafeOrigin = origins.find(isUnsafeProductionOrigin);
	if (unsafeOrigin) {
		return `Production CORS origin is unsafe: ${unsafeOrigin}`;
	}
	return null;
}

function bearerTokenFrom(request: Request): string {
	const authorization = request.headers.get('authorization') || request.headers.get('Authorization') || '';
	return authorization.startsWith('Bearer ') ? authorization.slice(7).trim() : '';
}

async function authenticateRequest(env: Env, request: Request): Promise<
	| { ok: true; user: AuthenticatedUser }
	| { ok: false; status: 401 | 500; error: string }
> {
	const accessToken = bearerTokenFrom(request);
	if (!accessToken) {
		return { ok: false, status: 401, error: 'Missing bearer token.' };
	}

	const serviceRoleKey = (env as any).SUPABASE_SERVICE_ROLE_KEY;
	const supabaseUrl = (env as any).SUPABASE_URL;
	if (!serviceRoleKey || !supabaseUrl) {
		return { ok: false, status: 500, error: 'Authentication is not configured.' };
	}

	const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
		method: 'GET',
		headers: {
			'Authorization': `Bearer ${accessToken}`,
			'apikey': serviceRoleKey,
			'Content-Type': 'application/json',
		},
	});

	if (!response.ok) {
		return { ok: false, status: 401, error: 'Unauthorized.' };
	}

	const user = await response.json() as { id?: string; email?: string | null };
	if (!user.id) {
		return { ok: false, status: 401, error: 'Unable to resolve current user.' };
	}

	return { ok: true, user: { id: user.id.toLowerCase(), email: user.email ?? null } };
}

function checkRateLimit(env: Env, key: string) {
	const MAX_REQUESTS = Number.parseInt(env.RATE_LIMIT_REQUESTS || '100', 10) || 100;
	const WINDOW_MS = 60 * 60 * 1000; // 1 hour window
	const RATE_PER_MS = MAX_REQUESTS / WINDOW_MS;

	const now = Date.now();
	let bucket = buckets.get(key);
	if (!bucket) {
		bucket = { tokens: MAX_REQUESTS, lastRefill: now };
		buckets.set(key, bucket);
	}
	// Refill
	const elapsed = Math.max(0, now - bucket.lastRefill);
	bucket.tokens = Math.min(MAX_REQUESTS, bucket.tokens + elapsed * RATE_PER_MS);
	bucket.lastRefill = now;

	if (bucket.tokens >= 1) {
		bucket.tokens -= 1;
		return { allowed: true, remaining: Math.floor(bucket.tokens), retryAfterSec: 0, limit: MAX_REQUESTS } as const;
	}

	const needed = 1 - bucket.tokens; // fractional tokens needed
	const msUntilNext = needed / RATE_PER_MS; // time to regain 1 token
	const retryAfterSec = Math.ceil(msUntilNext / 1000);
	return { allowed: false, remaining: 0, retryAfterSec, limit: MAX_REQUESTS } as const;
}

async function consumeDurableLimit(
	env: Env,
	key: string,
	limit: number,
	windowSec: number,
	cost = 1,
): Promise<DurableLimitResponse | null> {
	const limiter = (env as any).ABUSE_LIMITER as DurableObjectNamespace | undefined;
	if (!limiter) return null;

	const id = limiter.idFromName(key);
	const response = await limiter.get(id).fetch('https://abuse-limiter.local/consume', {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ limit, windowSec, cost } satisfies DurableLimitRequest),
	});
	if (!response.ok) {
		throw new Error(`Abuse limiter failed with ${response.status}`);
	}
	return await response.json<DurableLimitResponse>();
}

async function enforceRequestLimit(
	env: Env,
	key: string,
	limit: number,
	windowSec: number,
) {
	const durable = await consumeDurableLimit(env, key, limit, windowSec);
	if (durable) return durable;
	if (isProduction(env)) {
		return { allowed: false, remaining: 0, retryAfterSec: 60, limit, used: 0 } satisfies DurableLimitResponse;
	}
	const memory = checkRateLimit(env, key);
	return { ...memory, used: limit - memory.remaining } satisfies DurableLimitResponse;
}

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		const url = new URL(request.url);
		const path = url.pathname;
		const method = request.method;
		const requestId = (globalThis as any).crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2);
		const startedAt = Date.now();

		// Build CORS allow-list from env
		const allowedOriginPatterns = (env.ALLOWED_ORIGINS ?? '')
			.split(',')
			.map((s: string) => s.trim())
			.filter(Boolean);

		const originHeader = request.headers.get('Origin');

		const isOriginAllowed = (origin: string | null): boolean => {
			// Treat null origin as allowed for native iOS contexts
			if (origin === 'null') return true;
			if (!origin) return true; // Non-CORS requests or server-to-server
			for (const pattern of allowedOriginPatterns) {
				if (isProduction(env)) {
					if (isUnsafeProductionOrigin(pattern)) continue;
					return pattern === origin;
				}
				// Exact match
				if (pattern === origin) return true;
				// Wildcard pattern support, e.g., http://localhost:* or capacitor://*
				const regexStr = '^' + pattern.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*') + '$';
				const regex: RegExp = new RegExp(regexStr);
				if (regex.test(origin)) return true;
			}
			return false;
		};

		const buildCorsHeaders = (origin: string | null) => {
			const headers: Record<string, string> = {
				'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
				'Access-Control-Allow-Headers': 'content-type, x-client-id, authorization',
				'Vary': 'Origin',
			};
			if (origin && isOriginAllowed(origin)) {
				headers['Access-Control-Allow-Origin'] = origin;
			}
			return headers;
		};

		const corsHeaders = buildCorsHeaders(originHeader);

		// Fail-fast if required secrets are missing (Task 4.5)
		const openaiCheck = ensureOpenAIKey(env);
		if (!openaiCheck.ok) {
			const status = 500;
			logError(env, {
				ts: nowIso(),
				requestId,
				route: path,
				method,
				status,
				durationMs: Date.now() - startedAt,
				error: { message: openaiCheck.message, code: openaiCheck.code },
			});
			return new Response(JSON.stringify({ error: openaiCheck.message, code: openaiCheck.code }), {
				status,
				headers: { 'Content-Type': 'application/json', ...corsHeaders },
			});
		}

		const productionConfigError = validateProductionConfig(env);
		if (productionConfigError) {
			const status = 500;
			logError(env, {
				ts: nowIso(),
				requestId,
				route: path,
				method,
				status,
				durationMs: Date.now() - startedAt,
				error: { message: productionConfigError, code: 'PRODUCTION_CONFIG_INVALID' },
			});
			return new Response(JSON.stringify({ error: 'Server security configuration is invalid.', code: 'PRODUCTION_CONFIG_INVALID' }), {
				status,
				headers: { 'Content-Type': 'application/json', ...corsHeaders },
			});
		}

		// Small helpers for JSON responses
		const json = (data: unknown, init?: ResponseInit) =>
			new Response(JSON.stringify(data), {
				status: init?.status ?? 200,
				headers: { 'Content-Type': 'application/json', ...corsHeaders, ...(init?.headers ?? {}) },
			});

		// Handle preflight requests
		if (request.method === 'OPTIONS') {
			if (!isOriginAllowed(originHeader)) {
				const status = 403;
				const durationMs = Date.now() - startedAt;
				logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs });
				return new Response(JSON.stringify({ error: 'Forbidden: origin not allowed' }), {
					status,
					headers: { 'Content-Type': 'application/json', ...corsHeaders },
				});
			}
			{
				const status = 204;
				const durationMs = Date.now() - startedAt;
				logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs });
				return new Response(null, { status, headers: corsHeaders });
			}
		}

		try {
			// Health check endpoint
			if (path === '/health' && request.method === 'GET') {
				const res = json({ ok: true, timestamp: new Date().toISOString() });
				logRequest(env, 'info', {
					ts: nowIso(),
					requestId,
					route: path,
					method,
					status: 200,
					durationMs: Date.now() - startedAt,
				});
				return res;
			}

			// Parse endpoint — Milestone 4.2: CORS + content validation + 4.3 rate limiting
			if (path === '/parse' && request.method === 'POST') {
				try {
					const parseStarted = Date.now();
					// Enforce CORS allow-list
					if (!isOriginAllowed(originHeader)) {
						const status = 403;
						const durationMs = Date.now() - startedAt;
						logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs });
						return new Response(JSON.stringify({ error: 'Forbidden: origin not allowed' }), {
							status,
							headers: { 'Content-Type': 'application/json', ...corsHeaders },
						});
					}

					const auth = await authenticateRequest(env, request);
					if (!auth.ok) {
						const status = auth.status;
						const durationMs = Date.now() - startedAt;
						logRequest(env, status >= 500 ? 'error' : 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs });
						return new Response(JSON.stringify({ error: auth.error }), {
							status,
							headers: { 'Content-Type': 'application/json', ...corsHeaders },
						});
					}

					const requestLimit = Number.parseInt(env.RATE_LIMIT_REQUESTS || '100', 10) || 100;
					for (const key of [`parse:ip:${getClientIp(request)}`, `parse:user:${auth.user.id}`]) {
						const rl = await enforceRequestLimit(env, key, requestLimit, 60 * 60);
						if (!rl.allowed) {
							const status = 429;
							const durationMs = Date.now() - startedAt;
							logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs });
							return new Response(JSON.stringify({ error: 'Too Many Requests' }), {
								status,
								headers: { 'Content-Type': 'application/json', 'Retry-After': String(rl.retryAfterSec), ...corsHeaders },
							});
						}
					}

					if ((env as any).DEBUG_ALLOW_TEST_FAILURES === 'true') {
						const forcedError = request.headers.get('x-debug-force-error');
						if (forcedError === '500') {
							const status = 500;
							logRequest(env, 'warn', {
								ts: nowIso(),
								requestId,
								route: path,
								method,
								status,
								durationMs: Date.now() - startedAt,
								debugForced: forcedError,
							});
							return new Response(JSON.stringify({ error: 'Forced 500 for testing' }), {
								status,
								headers: { 'Content-Type': 'application/json', ...corsHeaders },
							});
						}

						if (forcedError === 'timeout') {
							logRequest(env, 'warn', {
								ts: nowIso(),
								requestId,
								route: path,
								method,
								status: 0,
								durationMs: Date.now() - startedAt,
								debugForced: forcedError,
							});
							await new Promise((resolve) => setTimeout(resolve, 60_000));
						}

						const forceInvalid = request.headers.get('x-debug-force-invalid-json');
						if (forceInvalid === '1') {
							logRequest(env, 'warn', {
								ts: nowIso(),
								requestId,
								route: path,
								method,
								status: 200,
								durationMs: Date.now() - startedAt,
								debugForced: 'invalid-json',
							});
							return new Response('not-json', {
								status: 200,
								headers: { 'Content-Type': 'application/json', ...corsHeaders },
							});
						}
					}

					// Validate content-type
					const contentType = request.headers.get('content-type') || '';
					if (!contentType.toLowerCase().startsWith('application/json')) {
						const status = 415;
						logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs: Date.now() - startedAt });
						return new Response(JSON.stringify({ error: 'Unsupported Media Type: application/json required' }), {
							status,
							headers: { 'Content-Type': 'application/json', ...corsHeaders },
						});
					}

					// Enforce ~1MB body limit using Content-Length header if present
					const contentLengthHeader = request.headers.get('content-length');
					if (contentLengthHeader) {
						const contentLength = parseInt(contentLengthHeader, 10);
						if (!Number.isNaN(contentLength) && contentLength > 1_000_000) {
							const status = 413;
							logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs: Date.now() - startedAt });
							return new Response(JSON.stringify({ error: 'Payload Too Large' }), {
								status,
								headers: { 'Content-Type': 'application/json', ...corsHeaders },
							});
						}
					}
					let body: unknown = undefined;
					try {
						// Read as text first to enforce character/byte limits
						const raw = await request.text();
						// Check character length (250k chars)
						if (raw.length > 250_000) {
							const status = 413;
							logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs: Date.now() - startedAt });
							return new Response(JSON.stringify({ error: 'Payload Too Large: text exceeds 250k characters' }), {
								status,
								headers: { 'Content-Type': 'application/json', ...corsHeaders },
							});
						}
						// Check byte length (~1MB)
						const rawBytes = new TextEncoder().encode(raw);
						if (rawBytes.length > 1_000_000) {
							const status = 413;
							logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs: Date.now() - startedAt });
							return new Response(JSON.stringify({ error: 'Payload Too Large' }), {
								status,
								headers: { 'Content-Type': 'application/json', ...corsHeaders },
							});
						}
						body = JSON.parse(raw);
					} catch {
						const status = 400;
						logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs: Date.now() - startedAt });
						return new Response(JSON.stringify({ error: 'Bad Request: invalid JSON' }), {
							status,
							headers: { 'Content-Type': 'application/json', ...corsHeaders },
						});
					}

					const text = typeof (body as any).text === 'string' ? (body as any).text : '';
					if ((body as any).text !== undefined && typeof (body as any).text !== 'string') {
						const status = 400;
						logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs: Date.now() - startedAt });
						return new Response(JSON.stringify({ error: 'Bad Request: text must be a string' }), {
							status,
							headers: { 'Content-Type': 'application/json', ...corsHeaders },
						});
					}
					if (text.length > 250_000) {
						const status = 413;
						logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs: Date.now() - startedAt });
						return new Response(JSON.stringify({ error: 'Payload Too Large: text exceeds 250k characters' }), {
							status,
							headers: { 'Content-Type': 'application/json', ...corsHeaders },
						});
					}

					const providedCourseCode = typeof (body as any).courseCode === 'string'
						? (body as any).courseCode.trim()
						: '';
					const detectedCourseCode = detectCourseCode(text);
					const courseCode = providedCourseCode || detectedCourseCode;

					if (!courseCode) {
						const status = 422;
						logRequest(env, 'info', {
							ts: nowIso(), requestId, route: path, method, status,
							durationMs: Date.now() - startedAt,
							error: 'Course code could not be determined from syllabus text',
						});
						return new Response(JSON.stringify({
							error: 'Unable to determine course code from syllabus text. Please provide it manually.',
							code: 'COURSE_CODE_MISSING',
						}), {
							status,
							headers: { 'Content-Type': 'application/json', ...corsHeaders },
						});
					}

					const validationConfig: ValidationConfig = {
						defaultCourseCode: courseCode,
						...(body as any).termStart && { termStart: new Date((body as any).termStart) },
						...(body as any).termEnd && { termEnd: new Date((body as any).termEnd) },
						strict: false
					};

					resetOpenAIUsageIfNewDay();
					const ip = getClientIp(request);
					const perIpLimit = Number.parseInt((env as any).RATE_LIMIT_OPENAI || '10', 10) || 10;
					const dailyBudget = Number.parseFloat((env as any).OPENAI_DAILY_BUDGET || '0');
					const costPerCall = Number.parseFloat(((env as any).OPENAI_COST_PER_CALL as string) || '0.02');
					const usageKey = `${auth.user.id}:${ip}`;
					const usedByIp = openaiUsage.perIpCalls.get(usageKey) || 0;
					const openAiWindowSec = 24 * 60 * 60;
					const openAiLimiter = await consumeDurableLimit(env, `openai:user:${auth.user.id}`, perIpLimit, openAiWindowSec);

					if (openAiLimiter ? !openAiLimiter.allowed : usedByIp >= perIpLimit) {
						const status = 429;
						logRequest(env, 'info', {
							ts: nowIso(), requestId, route: path, method, status,
							durationMs: Date.now() - startedAt,
							openaiDenied: 'per_user_cap', perIpLimit, usedByIp,
						});
						return new Response(JSON.stringify({ error: 'OpenAI usage limit reached. Please try again later.' }), {
							status,
							headers: {
								'Content-Type': 'application/json',
								...(openAiLimiter ? { 'Retry-After': String(openAiLimiter.retryAfterSec) } : {}),
								...corsHeaders,
							},
						});
					}

					const budgetLimiter = dailyBudget > 0
						? await consumeDurableLimit(env, `openai:budget:${new Date().toISOString().slice(0, 10)}`, Math.ceil(dailyBudget * 100_000), openAiWindowSec, Math.ceil(costPerCall * 100_000))
						: null;

					if (budgetLimiter ? !budgetLimiter.allowed : dailyBudget > 0 && (openaiUsage.totalCost + costPerCall) > dailyBudget) {
						const status = 429;
						logRequest(env, 'info', {
							ts: nowIso(), requestId, route: path, method, status,
							durationMs: Date.now() - startedAt,
							openaiDenied: 'budget_exceeded', dailyBudget, spent: openaiUsage.totalCost,
						});
						return new Response(JSON.stringify({ error: 'OpenAI budget exceeded. Try again tomorrow.' }), {
							status,
							headers: { 'Content-Type': 'application/json', ...corsHeaders },
						});
					}

					const tz = (body as any).timezone || request.headers.get('CF-Timezone') || 'UTC';

					// ── Pass 0: deterministic grading-scheme extraction ──
					const gradingScheme = extractGradingScheme(text);

					const { request: promptReq, processedText } = buildParseSyllabusRequest(text, {
						courseCode,
						termStart: (body as any).termStart,
						termEnd: (body as any).termEnd,
						timezone: tz,
						model: (env as any).OPENAI_MODEL || 'gpt-4.1-mini',
						gradingScheme,
					});

					let aiItems: unknown[];
					const aiStarted = Date.now();
					try {
						aiItems = (await callOpenAIParse(env, promptReq, { requestId, route: path, method })) as unknown[];
					} catch (e) {
						logError(env, {
							ts: nowIso(),
							requestId,
							route: path,
							method,
							status: 502,
							durationMs: Date.now() - startedAt,
							error: {
								message: (e as any)?.message || 'OpenAI parsing failed',
								stack: (e as any)?.stack,
								code: (e as any)?.code || 'OPENAI_ERROR'
							},
						});
						return new Response(JSON.stringify({
							error: 'OpenAI parsing failed',
							details: (e as any)?.message || 'Unknown error'
						}), {
							status: 502,
							headers: { 'Content-Type': 'application/json', ...corsHeaders },
						});
					}
					const aiTime = Date.now() - aiStarted;
					openaiUsage.totalCalls += 1;
					openaiUsage.totalCost += costPerCall;
					openaiUsage.perIpCalls.set(usageKey, usedByIp + 1);

					const validationResult = validateEvents(aiItems, {
						...validationConfig,
						gradingScheme: gradingScheme?.deliverables,
					});
					const warnings = [...validationResult.warnings];
					if (!validationResult.valid) {
						warnings.push(...validationResult.errors);
					}

					// ── Consistency guarantee: inject missing grading deliverables ──
					let coveredEvents = validationResult.events;
					if (gradingScheme?.deliverables?.length) {
						const coverage = ensureSchemeCoverage(
							coveredEvents,
							gradingScheme.deliverables,
							courseCode,
						);
						coveredEvents = coverage.events;
						if (coverage.injected.length > 0) {
							warnings.push(
								`Schema coverage: injected ${coverage.injected.length} missing deliverable(s): ${coverage.injected.join(', ')}`
							);
						}
					}

					if (coveredEvents.length === 0) {
						const status = 422;
						logRequest(env, 'info', {
							ts: nowIso(), requestId, route: path, method, status,
							durationMs: Date.now() - startedAt,
							error: validationResult.errors.join(' | ') || 'No valid events after validation',
						});
						return new Response(JSON.stringify({
							error: 'Validation failed',
							details: validationResult.errors
						}), {
							status,
							headers: { 'Content-Type': 'application/json', ...corsHeaders },
						});
					}

					// Post-process: split multi-day recurrence rules into separate events
					const splitEvents = splitMultiDayRecurrence(coveredEvents);

					const avgConfidence = coveredEvents.length
						? coveredEvents.reduce((sum, e) => sum + (e.confidence ?? 0), 0) / coveredEvents.length
						: 0;

					const response = {
						events: splitEvents,
						source: 'openai' as const,
						confidence: Number.isFinite(avgConfidence) ? Number(avgConfidence.toFixed(3)) : 0,
						preprocessedText: processedText,
						gradingScheme: gradingScheme?.deliverables?.map(d => ({
							name: d.name,
							weight: d.weight,
							type: d.type,
						})) ?? [],
						diagnostics: {
							source: 'openai' as const,
							processingTimeMs: Date.now() - parseStarted,
							textLength: text.length,
							warnings,
							validation: validationResult.stats,
							openai: { processingTimeMs: aiTime, usedModel: (env as any).OPENAI_MODEL || 'gpt-4.1-mini' }
						}
					};

					const res = json(response, { status: 200 });
					logRequest(env, 'info', {
						ts: nowIso(),
						requestId,
						route: path,
						method,
						status: 200,
						durationMs: Date.now() - startedAt,
						payloadChars: typeof text === 'string' ? text.length : 0,
						parserPath: 'openai',
						eventsFound: coveredEvents.length,
						averageConfidence: response.confidence,
					});
					return res;

				} catch (parseError) {
					const status = 500;
					logError(env, {
						ts: nowIso(),
						requestId,
						route: path,
						method,
						status,
						durationMs: Date.now() - startedAt,
						error: {
							message: (parseError as Error).message,
							stack: (parseError as Error).stack,
							code: 'PARSE_ERROR'
						}
					});
					return new Response(JSON.stringify({
						error: 'Parsing failed',
						details: (parseError as Error).message
					}), {
						status,
						headers: { 'Content-Type': 'application/json', ...corsHeaders },
					});
				}
			}
			// Upload endpoint (optional, stub) — Milestone 4.1
			if (path === '/upload' && request.method === 'POST') {
				// In future, return a presigned URL for direct-to-storage upload
				const res = json({
					uploadUrl: 'https://example.invalid/upload/stub',
					expiresIn: 600,
					fields: {},
				});
				logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status: 200, durationMs: Date.now() - startedAt });
				return res;
			}

			// Deprecated: account enumeration is intentionally not supported.
			if (path === '/auth/check-provider' && request.method === 'POST') {
				logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status: 410, durationMs: Date.now() - startedAt });
				return json({ error: 'Account provider lookup is no longer available.' }, { status: 410 });
			}

			if (path === '/social/recommendations' && request.method === 'GET') {
				try {
					const serviceRoleKey = (env as any).SUPABASE_SERVICE_ROLE_KEY;
					const supabaseUrl = (env as any).SUPABASE_URL;
					if (!serviceRoleKey || !supabaseUrl) {
						return json({ error: 'Supabase social recommendations are not configured.' }, { status: 500 });
					}

					const auth = await authenticateRequest(env, request);
					if (!auth.ok) return json({ error: auth.error }, { status: auth.status });
					const currentUserId = auth.user.id;

					const restHeaders = {
						'Authorization': `Bearer ${serviceRoleKey}`,
						'apikey': serviceRoleKey,
						'Content-Type': 'application/json',
					};
					const restBaseURL = `${supabaseUrl}/rest/v1`;

					const restSelect = async <T>(table: string, params: Record<string, string>): Promise<T[]> => {
						const url = new URL(`${restBaseURL}/${table}`);
						for (const [key, value] of Object.entries(params)) {
							url.searchParams.set(key, value);
						}

						const response = await fetch(url.toString(), {
							method: 'GET',
							headers: restHeaders,
						});
						if (!response.ok) {
							throw new Error(`Supabase REST ${table} failed with ${response.status}`);
						}
						return await response.json() as T[];
					};

					const currentFriendships = await restSelect<SocialFriendshipRow>('friends', {
						select: 'id,user_a_id,user_b_id',
						or: `(user_a_id.eq.${currentUserId},user_b_id.eq.${currentUserId})`,
					});

					const friendIds = new Set<string>();
					for (const friendship of currentFriendships) {
						friendIds.add(friendship.user_a_id === currentUserId ? friendship.user_b_id : friendship.user_a_id);
					}

					const [outgoingPendingRows, incomingPendingRows, myCourseRows] = await Promise.all([
						restSelect<SocialFriendRequestRow>('friend_requests', {
							select: 'from_user_id,to_user_id,status',
							from_user_id: `eq.${currentUserId}`,
							status: 'eq.pending',
						}),
						restSelect<SocialFriendRequestRow>('friend_requests', {
							select: 'from_user_id,to_user_id,status',
							to_user_id: `eq.${currentUserId}`,
							status: 'eq.pending',
						}),
						restSelect<SocialCourseMembershipRow>('courses', {
							select: 'user_id,code',
							user_id: `eq.${currentUserId}`,
						}),
					]);

					const outgoingPendingIds = new Set(outgoingPendingRows.map(row => row.to_user_id));
					const incomingPendingIds = new Set(incomingPendingRows.map(row => row.from_user_id));
					const myCourseCodes = new Set(
						myCourseRows
							.map(row => normalizedCourseCode(row.code))
							.filter(code => code.length > 0)
					);

					if (friendIds.size === 0 && myCourseCodes.size === 0) {
						return json({ users: [] });
					}

					const candidateIds = new Set<string>();
					const seedSharedCoursesByUser = new Map<string, Set<string>>();

					if (friendIds.size > 0) {
						const friendIdList = Array.from(friendIds);
						const [friendshipsByA, friendshipsByB] = await Promise.all([
							restSelect<SocialFriendshipRow>('friends', {
								select: 'id,user_a_id,user_b_id',
								user_a_id: inFilter(friendIdList),
							}),
							restSelect<SocialFriendshipRow>('friends', {
								select: 'id,user_a_id,user_b_id',
								user_b_id: inFilter(friendIdList),
							}),
						]);

						for (const friendship of deduplicatedFriendships([...friendshipsByA, ...friendshipsByB])) {
							if (friendship.user_a_id !== currentUserId && !friendIds.has(friendship.user_a_id)) {
								candidateIds.add(friendship.user_a_id);
							}
							if (friendship.user_b_id !== currentUserId && !friendIds.has(friendship.user_b_id)) {
								candidateIds.add(friendship.user_b_id);
							}
						}
					}

					if (myCourseCodes.size > 0) {
						const courseCodeFilters = Array.from(myCourseCodes);
						const allCourseRows = await restSelect<SocialCourseMembershipRow>('courses', {
							select: 'user_id,code',
							code: inFilter(courseCodeFilters),
						});

						for (const row of allCourseRows) {
							if (row.user_id === currentUserId) continue;
							const normalizedCode = normalizedCourseCode(row.code);
							if (!myCourseCodes.has(normalizedCode)) continue;
							if (friendIds.has(row.user_id)) continue;

							candidateIds.add(row.user_id);
							if (!seedSharedCoursesByUser.has(row.user_id)) {
								seedSharedCoursesByUser.set(row.user_id, new Set<string>());
							}
							seedSharedCoursesByUser.get(row.user_id)!.add(normalizedCode);
						}
					}

					candidateIds.delete(currentUserId);
					if (candidateIds.size === 0) {
						return json({ users: [] });
					}

					const candidateIdList = Array.from(candidateIds);
					const profiles = await restSelect<SocialUserProfileRow>('users', {
						select: 'id,username,display_name',
						id: inFilter(candidateIdList),
					});

					const relevantFriendIds = Array.from(new Set([...candidateIdList, ...Array.from(friendIds)]));
					const friendshipsForMutuals = relevantFriendIds.length === 0
						? []
						: deduplicatedFriendships([
							...(await restSelect<SocialFriendshipRow>('friends', {
								select: 'id,user_a_id,user_b_id',
								user_a_id: inFilter(relevantFriendIds),
							})),
							...(await restSelect<SocialFriendshipRow>('friends', {
								select: 'id,user_a_id,user_b_id',
								user_b_id: inFilter(relevantFriendIds),
							})),
						]);

					const friendIdsByUser = new Map<string, Set<string>>();
					for (const friendship of friendshipsForMutuals) {
						if (!friendIdsByUser.has(friendship.user_a_id)) {
							friendIdsByUser.set(friendship.user_a_id, new Set<string>());
						}
						if (!friendIdsByUser.has(friendship.user_b_id)) {
							friendIdsByUser.set(friendship.user_b_id, new Set<string>());
						}
						friendIdsByUser.get(friendship.user_a_id)!.add(friendship.user_b_id);
						friendIdsByUser.get(friendship.user_b_id)!.add(friendship.user_a_id);
					}

					const users: RecommendationUser[] = [];
					for (const profile of profiles) {
						const userId = profile.id;
						const username = profile.username?.trim();
						if (!username) continue;
						if (incomingPendingIds.has(userId)) continue;
						if (friendIds.has(userId)) continue;

						const adjacency = friendIdsByUser.get(userId) ?? new Set<string>();
						let mutualFriendsCount = 0;
						for (const friendId of friendIds) {
							if (adjacency.has(friendId)) {
								mutualFriendsCount += 1;
							}
						}

						const sharedCourseCodes = Array.from(seedSharedCoursesByUser.get(userId) ?? []).sort();
						if (mutualFriendsCount == 0 && sharedCourseCodes.length === 0) {
							continue;
						}

						users.push({
							id: userId,
							username,
							displayName: profile.display_name ?? null,
							mutualFriendsCount,
							sharedCourseCodes,
							requestState: outgoingPendingIds.has(userId) ? 'requested' : 'none',
						});
					}

					return json({ users: sortRecommendationUsers(users) });
				} catch (error) {
					logError(env, {
						ts: nowIso(),
						requestId,
						route: path,
						method,
						status: 500,
						durationMs: Date.now() - startedAt,
						error: {
							message: (error as Error).message,
							stack: (error as Error).stack,
							code: 'SOCIAL_RECOMMENDATIONS_ERROR',
						},
					});
					return json({ error: 'Failed to fetch social recommendations.' }, { status: 500 });
				}
			}

			// Default 404 for unknown routes
			{
				const status = 404;
				const durationMs = Date.now() - startedAt;
				logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs });
				return new Response(
					JSON.stringify({ error: 'Not Found', path }),
					{
						status,
						headers: {
							'Content-Type': 'application/json',
							...corsHeaders,
						},
					}
				);
			}
		} catch (error) {
			const status = 500;
			logError(env, {
				ts: nowIso(),
				requestId,
				route: path,
				method,
				status,
				durationMs: Date.now() - startedAt,
				error: {
					message: (error as any)?.message,
					stack: (error as any)?.stack,
					code: (error as any)?.code,
				},
			});
			return json({ error: 'Internal Server Error' }, { status });
		}
	}
} satisfies ExportedHandler<Env>;
