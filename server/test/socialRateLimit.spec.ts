import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import worker from '../src/index';

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

describe('Social abuse controls', () => {
  let originalFetch: typeof fetch;

  beforeEach(() => {
    env.NODE_ENV = 'test';
    env.OPENAI_API_KEY = 'test-key';
    env.ALLOWED_ORIGINS = 'http://localhost:*';
    env.SUPABASE_URL = 'https://example.supabase.co';
    env.SUPABASE_SERVICE_ROLE_KEY = 'service-role-test-key';
    env.RATE_LIMIT_SOCIAL = '1';
    originalFetch = globalThis.fetch;
    (globalThis as any).fetch = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes('/auth/v1/user')) {
        return new Response(JSON.stringify({ id: '44444444-4444-4444-4444-444444444444' }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      return new Response(JSON.stringify([]), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    });
  });

  afterEach(() => {
    (globalThis as any).fetch = originalFetch;
    vi.restoreAllMocks();
  });

  async function recommendations(token = 'social-token') {
    const req = new IncomingRequest('http://example.com/social/recommendations', {
      method: 'GET',
      headers: {
        Origin: 'http://localhost:3000',
        Authorization: `Bearer ${token}`,
        'CF-Connecting-IP': '203.0.113.10',
      },
    });
    const ctx = createExecutionContext();
    const res = await worker.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);
    return res;
  }

  it('rate limits repeated social recommendation requests by user and IP', async () => {
    const first = await recommendations();
    expect(first.status).toBe(200);

    const second = await recommendations();
    expect(second.status).toBe(429);
    expect(Number(second.headers.get('Retry-After') || '0')).toBeGreaterThan(0);
  });
});
