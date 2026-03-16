import { env, createExecutionContext, waitOnExecutionContext, SELF } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import worker from '../src/index';

// For now, you'll need to do something like this to get a correctly-typed
// `Request` to pass to `worker.fetch()`.
const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

describe('Hello World worker', () => {
	beforeEach(() => {
		env.OPENAI_API_KEY = 'test-key';
		env.ALLOWED_ORIGINS = 'http://localhost:*';
	});

	afterEach(() => {
		vi.restoreAllMocks();
	});

	it('responds with Hello World! (unit style)', async () => {
		const request = new IncomingRequest('http://example.com');
		// Create an empty context to pass to `worker.fetch()`.
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		// Wait for all `Promise`s passed to `ctx.waitUntil()` to settle before running test assertions
		await waitOnExecutionContext(ctx);
		expect(await response.text()).toMatchInlineSnapshot(`"{"error":"Not Found","path":"/"}"`);
	});

	it('responds with Hello World! (integration style)', async () => {
		const response = await SELF.fetch('https://example.com');
		expect(await response.text()).toMatchInlineSnapshot(`"{"error":"Not Found","path":"/"}"`);
	});

	it('returns injected grading placeholders when AI yields no valid events', async () => {
		vi.spyOn(globalThis, 'fetch').mockResolvedValue(
			new Response(JSON.stringify({
				choices: [
					{
						message: {
							content: '{"events":[]}',
						},
					},
				],
			}), {
				status: 200,
				headers: { 'Content-Type': 'application/json' },
			})
		);

		const request = new IncomingRequest('http://example.com/parse', {
			method: 'POST',
			headers: {
				Origin: 'http://localhost:3000',
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({
				text: [
					'CS101 Introduction to Testing',
					'Grading Breakdown:',
					'Final Exam 100%',
				].join('\n'),
				courseCode: 'CS101',
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
	});
});
