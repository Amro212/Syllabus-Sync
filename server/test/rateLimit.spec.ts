import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import worker from '../src/index';

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;
const goodEvent = {
  id: 'a1',
  courseCode: 'CS101',
  type: 'ASSIGNMENT',
  title: 'Assignment 1',
  start: '2025-09-12T00:00:00.000-05:00',
};

describe('Rate Limiting (4.3)', () => {
  let originalFetch: typeof fetch;

  beforeEach(() => {
    env.RATE_LIMIT_REQUESTS = '2';
    env.ALLOWED_ORIGINS = 'http://localhost:*';
    env.OPENAI_API_KEY = 'test-key';
    env.SUPABASE_URL = 'https://example.supabase.co';
    env.SUPABASE_SERVICE_ROLE_KEY = 'service-role-test-key';
    originalFetch = globalThis.fetch;
    (globalThis as any).fetch = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      if (url.includes('/auth/v1/user')) {
        const authorization = new Headers(init?.headers).get('authorization') || '';
        const id = authorization.includes('other-token')
          ? '22222222-2222-2222-2222-222222222222'
          : authorization.includes('bucket-token')
          ? '33333333-3333-3333-3333-333333333333'
          : '11111111-1111-1111-1111-111111111111';
        return new Response(JSON.stringify({ id }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      return new Response(
        JSON.stringify({ choices: [{ message: { content: JSON.stringify([goodEvent]) } }] }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    });
  });

  afterEach(() => {
    (globalThis as any).fetch = originalFetch;
    vi.restoreAllMocks();
  });

  async function doParse(ip: string, token = 'valid-token') {
    const req = new IncomingRequest('http://example.com/parse', {
      method: 'POST',
      headers: {
        Origin: 'http://localhost:3000',
        'Content-Type': 'application/json',
        'CF-Connecting-IP': ip,
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ text: 'hello', courseCode: 'CS101' }),
    });
    const ctx = createExecutionContext();
    const res = await worker.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);
    return res;
  }

  it('limits requests per IP and returns 429 with Retry-After', async () => {
    const res1 = await doParse('1.2.3.4');
    expect(res1.status).toBe(200);
    const res2 = await doParse('1.2.3.4');
    expect(res2.status).toBe(200);
    const res3 = await doParse('1.2.3.4');
    expect(res3.status).toBe(429);
    expect(Number(res3.headers.get('Retry-After') || '0')).toBeGreaterThan(0);
    // CORS header present
    expect(res3.headers.get('Access-Control-Allow-Origin')).toBe('http://localhost:3000');
  });

  it('uses separate buckets for different IPs', async () => {
    // First IP consumes 2 tokens
    await doParse('10.0.0.1', 'bucket-token');
    await doParse('10.0.0.1', 'bucket-token');
    const blocked = await doParse('10.0.0.1', 'bucket-token');
    expect(blocked.status).toBe(429);

    // Same user is blocked even from a different IP.
    const other1 = await doParse('10.0.0.2', 'bucket-token');
    expect(other1.status).toBe(429);

    // Different user has a separate authenticated bucket.
    const otherUser = await doParse('10.0.0.2', 'other-token');
    expect(otherUser.status).toBe(200);
  });
});
