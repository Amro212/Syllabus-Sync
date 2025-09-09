/**
 * Syllabus Sync Server - Cloudflare Workers API
 * 
 * Provides endpoints for:
 * - Health check
 * - Syllabus parsing with heuristics + OpenAI fallback
 * - PDF upload/storage (optional)
 */

export default {
	async fetch(request, env, ctx): Promise<Response> {
		const url = new URL(request.url);
		const path = url.pathname;

		// CORS headers (will be tightened in 4.2)
		const corsHeaders = {
			'Access-Control-Allow-Origin': '*',
			'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
			'Access-Control-Allow-Headers': 'Content-Type',
		};

		// Small helpers for JSON responses
		const json = (data: unknown, init?: ResponseInit) =>
			new Response(JSON.stringify(data), {
				status: init?.status ?? 200,
				headers: { 'Content-Type': 'application/json', ...corsHeaders, ...(init?.headers ?? {}) },
			});

		// Handle preflight requests
		if (request.method === 'OPTIONS') {
			return new Response(null, { headers: corsHeaders });
		}

		try {
			// Health check endpoint
			if (path === '/health' && request.method === 'GET') {
				return json({ ok: true, timestamp: new Date().toISOString() });
			}

			// Parse endpoint (stub) — Milestone 4.1
			if (path === '/parse' && request.method === 'POST') {
				const started = Date.now();
				let body: unknown = undefined;
				try {
					body = await request.json();
				} catch {
					// For 4.1, just treat as empty input; 4.2 will enforce content-type/shape
					body = {};
				}

				const text = typeof (body as any).text === 'string' ? (body as any).text : '';
				const response = {
					events: [] as any[],
					confidence: 0,
					diagnostics: {
						source: 'heuristics' as const,
						processingTimeMs: Date.now() - started,
						textLength: text.length,
						warnings: ['stub: parser not yet implemented'],
					},
				};

				return json(response, { status: 200 });
			}

			// Upload endpoint (optional, stub) — Milestone 4.1
			if (path === '/upload' && request.method === 'POST') {
				// In future, return a presigned URL for direct-to-storage upload
				return json({
					uploadUrl: 'https://example.invalid/upload/stub',
					expiresIn: 600,
					fields: {},
				});
			}

			// Default 404 for unknown routes
			return new Response(
				JSON.stringify({ error: 'Not Found', path }),
				{
					status: 404,
					headers: {
						'Content-Type': 'application/json',
						...corsHeaders,
					},
				}
			);
		} catch (error) {
			return json({ error: 'Internal Server Error' }, { status: 500 });
		}
	},
} satisfies ExportedHandler<Env>;
