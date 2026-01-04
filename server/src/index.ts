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
import { buildParseSyllabusRequest } from './prompts/parseSyllabus';
import { detectCourseCode } from './utils/courseCode';
import { callOpenAIParse } from './clients/openai';

// Basic in-memory token buckets by IP (per-isolate, best-effort)
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

function checkRateLimit(env: Env, req: Request) {
	const MAX_REQUESTS = Number.parseInt(env.RATE_LIMIT_REQUESTS || '100', 10) || 100;
	const WINDOW_MS = 60 * 60 * 1000; // 1 hour window
	const RATE_PER_MS = MAX_REQUESTS / WINDOW_MS;

	const key = getClientIp(req);
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
			const allowOrigin = isOriginAllowed(origin) && origin ? origin : '*';
			return {
				'Access-Control-Allow-Origin': allowOrigin,
				'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
				'Access-Control-Allow-Headers': 'content-type, x-client-id, authorization',
				'Vary': 'Origin',
			};
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
					// Rate limit by IP
					const rl = checkRateLimit(env, request);
					if (!rl.allowed) {
						const status = 429;
						const durationMs = Date.now() - startedAt;
						logRequest(env, 'info', { ts: nowIso(), requestId, route: path, method, status, durationMs });
						return new Response(JSON.stringify({ error: 'Too Many Requests' }), {
							status,
							headers: { 'Content-Type': 'application/json', 'Retry-After': String(rl.retryAfterSec), ...corsHeaders },
						});
					}
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
						return new Response(JSON.stringify({ error: 'Unable to determine courseCode from syllabus text.' }), {
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
					const usedByIp = openaiUsage.perIpCalls.get(ip) || 0;

					if (usedByIp >= perIpLimit) {
						const status = 429;
						logRequest(env, 'info', {
							ts: nowIso(), requestId, route: path, method, status,
							durationMs: Date.now() - startedAt,
							openaiDenied: 'per_ip_cap', perIpLimit, usedByIp,
						});
						return new Response(JSON.stringify({ error: 'OpenAI usage limit reached. Please try again later.' }), {
							status,
							headers: { 'Content-Type': 'application/json', ...corsHeaders },
						});
					}

					if (dailyBudget > 0 && (openaiUsage.totalCost + costPerCall) > dailyBudget) {
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
					const { request: promptReq, processedText } = buildParseSyllabusRequest(text, {
						courseCode,
						termStart: (body as any).termStart,
						termEnd: (body as any).termEnd,
						timezone: tz,
						model: (env as any).OPENAI_MODEL || 'gpt-4o-mini',
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
					openaiUsage.perIpCalls.set(ip, usedByIp + 1);

					const validationResult = validateEvents(aiItems, validationConfig);
					if (validationResult.events.length === 0) {
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

					const avgConfidence = validationResult.events.length
						? validationResult.events.reduce((sum, e) => sum + (e.confidence ?? 0), 0) / validationResult.events.length
						: 0;

					const warnings = [...validationResult.warnings];
					if (!validationResult.valid) {
						warnings.push(...validationResult.errors);
					}

					const response = {
						events: validationResult.events,
						source: 'openai' as const,
						confidence: Number.isFinite(avgConfidence) ? Number(avgConfidence.toFixed(3)) : 0,
						preprocessedText: processedText,
						diagnostics: {
							source: 'openai' as const,
							processingTimeMs: Date.now() - parseStarted,
							textLength: text.length,
							warnings,
							validation: validationResult.stats,
							openai: { processingTimeMs: aiTime, usedModel: (env as any).OPENAI_MODEL || 'gpt-4o-mini' }
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
						eventsFound: validationResult.events.length,
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

			// Auth provider check endpoint - checks if user exists and their provider
			if (path === '/auth/check-provider' && request.method === 'POST') {
				try {
					// Validate content-type
					const contentType = request.headers.get('content-type') || '';
					if (!contentType.toLowerCase().startsWith('application/json')) {
						return json({ error: 'Unsupported Media Type' }, { status: 415 });
					}

					const body = await request.json() as { email?: string };
					const email = body.email?.trim().toLowerCase();

					if (!email) {
						return json({ error: 'Email is required' }, { status: 400 });
					}

					// Basic email format validation
					const emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
					if (!emailRegex.test(email)) {
						return json({ error: 'Invalid email format' }, { status: 400 });
					}

					// Check for Supabase service role key
					const serviceRoleKey = (env as any).SUPABASE_SERVICE_ROLE_KEY;
					const supabaseUrl = (env as any).SUPABASE_URL;

					if (!serviceRoleKey || !supabaseUrl) {
						// If service role key not configured, return unknown (fail open)
						logRequest(env, 'warn', {
							ts: nowIso(),
							requestId,
							route: path,
							method,
							status: 200,
							durationMs: Date.now() - startedAt,
							warning: 'SUPABASE_SERVICE_ROLE_KEY or SUPABASE_URL not configured',
						});
						return json({ exists: false, provider: null });
					}

					// Query Supabase Admin API to find user by email
					// List all users and filter by email client-side
					const adminResponse = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
						method: 'GET',
						headers: {
							'Authorization': `Bearer ${serviceRoleKey}`,
							'apikey': serviceRoleKey,
							'Content-Type': 'application/json',
						},
					});

					if (!adminResponse.ok) {
						logRequest(env, 'warn', {
							ts: nowIso(),
							requestId,
							route: path,
							method,
							status: adminResponse.status,
							durationMs: Date.now() - startedAt,
							warning: 'Supabase admin API error',
						});
						// On error, fail open (allow the flow)
						return json({ exists: false, provider: null });
					}

					const adminData = await adminResponse.json() as {
						users?: Array<{
							email?: string;
							app_metadata?: {
								provider?: string;
								providers?: string[];
							}
						}>
					};
					const users = adminData.users || [];

					// Find the user with matching email
					const user = users.find(u => u.email?.toLowerCase() === email);

					if (!user) {
						return json({ exists: false, provider: null });
					}

					// Get the provider from app_metadata
					// Prefer the primary provider, fallback to first in providers array
					const provider = user.app_metadata?.provider || user.app_metadata?.providers?.[0] || 'email';

					logRequest(env, 'info', {
						ts: nowIso(),
						requestId,
						route: path,
						method,
						status: 200,
						durationMs: Date.now() - startedAt,
						userExists: true,
						provider,
					});

					return json({ exists: true, provider });

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
							code: 'AUTH_CHECK_ERROR',
						},
					});
					// On error, fail open (allow the flow)
					return json({ exists: false, provider: null });
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
