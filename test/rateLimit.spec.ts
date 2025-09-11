import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import { describe, it, expect, beforeEach } from 'vitest';
import worker from '../src/index';

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

describe('Rate Limiting (4.3)', () => {
  beforeEach(() => {
    env.RATE_LIMIT_REQUESTS = '2';
    env.ALLOWED_ORIGINS = 'http://localhost:*';
  });

  async function doParse(ip: string) {
    const req = new IncomingRequest('http://example.com/parse', {
      method: 'POST',
      headers: {
        Origin: 'http://localhost:3000',
        'Content-Type': 'application/json',
        'CF-Connecting-IP': ip,
      },
      body: JSON.stringify({ text: 'hello' }),
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
    await doParse('10.0.0.1');
    await doParse('10.0.0.1');
    const blocked = await doParse('10.0.0.1');
    expect(blocked.status).toBe(429);

    // Different IP should still be allowed
    const other1 = await doParse('10.0.0.2');
    expect(other1.status).toBe(200);
  });
});

