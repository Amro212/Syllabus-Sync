/**
 * Syllabus Sync Server - Cloudflare Workers API
 * 
 * Provides endpoints for:
 * - Health check
 * - Syllabus parsing with heuristics + OpenAI fallback
 * - PDF upload/storage (optional)
 */
import { logRequest, logError, nowIso } from './logging';
import { ensureOpenAIKey } from './env';
import { buildEvents } from './parsing/eventBuilder';
import { validateEvents, type ValidationConfig } from './validation/eventValidation';
import { buildParseSyllabusRequest } from './prompts/parseSyllabus';
import { callOpenAIParse } from './clients/openai';

// Basic in-memory token buckets by IP (per-isolate, best-effort)
const buckets = new Map<string, { tokens: number; lastRefill: number }>();

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
	async fetch(request, env, ctx): Promise<Response> {
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

				// Parse syllabus text using heuristics
				try {
					const parseConfig = {
						courseId: (body as any).courseId || 'unknown',
						courseCode: (body as any).courseCode,
						defaultYear: (body as any).defaultYear || new Date().getFullYear(),
						minConfidence: 0.3,
						deduplicate: true
					};

					// Step 1: Build event candidates from text
					const buildResult = buildEvents(text, parseConfig);
					
					// Step 2: Validate and process events
					const validationConfig: ValidationConfig = {
						defaultCourseId: parseConfig.courseId,
						defaultCourseCode: parseConfig.courseCode,
						// Add term window if provided
						...(body as any).termStart && { termStart: new Date((body as any).termStart) },
						...(body as any).termEnd && { termEnd: new Date((body as any).termEnd) },
						strict: false
					};

					const validationResult = validateEvents(buildResult.events, validationConfig);
					
					// Calculate overall confidence
					const overallConfidence = validationResult.events.length > 0
						? validationResult.events.reduce((sum, e) => sum + (e.confidence || 0), 0) / validationResult.events.length
						: 0;

					// Confidence router (Milestone 6.3)
					const threshold = Math.max(0, Math.min(1, Number.parseFloat((env as any).PARSE_CONFIDENCE_THRESHOLD || '0.6')));
					let source: 'heuristics' | 'openai' = 'heuristics';
					let finalEvents = validationResult.events as any[];
					let finalConfidence = overallConfidence;
					const diags: any = {
						source: 'heuristics' as const,
						processingTimeMs: Date.now() - parseStarted,
						textLength: text.length,
						threshold,
						warnings: [
							...buildResult.stats.warnings,
							...validationResult.warnings
						],
						parsing: {
							totalLines: buildResult.stats.totalLines,
							linesWithDates: buildResult.stats.linesWithDates,
							linesWithTypes: buildResult.stats.linesWithTypes,
							candidatesGenerated: buildResult.stats.candidatesGenerated,
							candidatesAfterDedup: buildResult.stats.candidatesAfterDedup,
							averageConfidence: buildResult.stats.averageConfidence
						},
						validation: {
							totalEvents: validationResult.stats.totalEvents,
							validEvents: validationResult.stats.validEvents,
							invalidEvents: validationResult.stats.invalidEvents,
							clampedEvents: validationResult.stats.clampedEvents,
							defaultsApplied: validationResult.stats.defaultsApplied,
							errors: validationResult.errors
						}
					};

					const needsOpenAI = finalEvents.length === 0 || overallConfidence < threshold;
					if (needsOpenAI) {
						try {
							const tz = request.headers.get('CF-Timezone') || 'UTC';
							const promptReq = buildParseSyllabusRequest(text, {
								courseId: parseConfig.courseId,
								courseCode: parseConfig.courseCode,
								termStart: (body as any).termStart,
								termEnd: (body as any).termEnd,
								timezone: tz,
								model: (env as any).OPENAI_MODEL || 'gpt-5-mini',
							});
							const aiStarted = Date.now();
							const aiItems = (await callOpenAIParse(env, promptReq, { requestId, route: path, method })) as any[];
							const aiTime = Date.now() - aiStarted;
							source = 'openai';
							finalEvents = aiItems;
							const confidences = finalEvents.map((e) => typeof e.confidence === 'number' ? e.confidence : 0.7);
							finalConfidence = confidences.length ? confidences.reduce((a, b) => a + b, 0) / confidences.length : 0.7;
							diags.openai = { processingTimeMs: aiTime, usedModel: (env as any).OPENAI_MODEL || 'gpt-5-mini' };
						} catch (e) {
							diags.openai = { error: { message: (e as any)?.message, code: (e as any)?.code }, fallback: 'heuristics' };
						}
					}

					const response = {
						events: finalEvents,
						source,
						confidence: Number.isFinite(finalConfidence) ? Number(finalConfidence.toFixed(3)) : 0,
						diagnostics: diags,
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
						parserPath: source,
						eventsFound: Array.isArray(finalEvents) ? finalEvents.length : 0,
						overallConfidence: response.confidence,
					});
					return res;

				} catch (parseError) {
					// Fallback to empty response if parsing fails
					const response = {
						events: [] as any[],
						confidence: 0,
						diagnostics: {
							source: 'heuristics' as const,
							processingTimeMs: Date.now() - parseStarted,
							textLength: text.length,
							warnings: [`Parsing failed: ${(parseError as Error).message}`],
						},
					};
					
					const res = json(response, { status: 200 });
					logRequest(env, 'info', {
						ts: nowIso(),
						requestId,
						route: path,
						method,
						status: 200,
						durationMs: Date.now() - startedAt,
						// Redacted metrics only; never log raw text
						payloadChars: typeof text === 'string' ? text.length : 0,
						eventsFound: 0,
						overallConfidence: 0,
						parseError: (parseError as Error).message
					});
					return res;
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
	},
} satisfies ExportedHandler<Env>;
