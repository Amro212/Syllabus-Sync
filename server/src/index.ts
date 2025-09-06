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

		// CORS headers
		const corsHeaders = {
			'Access-Control-Allow-Origin': '*',
			'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
			'Access-Control-Allow-Headers': 'Content-Type',
		};

		// Handle preflight requests
		if (request.method === 'OPTIONS') {
			return new Response(null, { headers: corsHeaders });
		}

		try {
			// Health check endpoint
			if (path === '/health' && request.method === 'GET') {
				return new Response(
					JSON.stringify({ ok: true, timestamp: new Date().toISOString() }),
					{
						status: 200,
						headers: {
							'Content-Type': 'application/json',
							...corsHeaders,
						},
					}
				);
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
			return new Response(
				JSON.stringify({ error: 'Internal Server Error' }),
				{
					status: 500,
					headers: {
						'Content-Type': 'application/json',
						...corsHeaders,
					},
				}
			);
		}
	},
} satisfies ExportedHandler<Env>;
