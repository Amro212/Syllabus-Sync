import { env, createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import { describe, it, expect, beforeEach } from 'vitest';
import worker from '../src/index';

// Workaround type helper for Request in workers test env
const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;

describe('CORS and Content Validation (4.2)', () => {
  beforeEach(() => {
    // Configure allowed origins for tests
    env.ALLOWED_ORIGINS = 'http://localhost:*,capacitor://*';
  });

  it('allows preflight for allowed origin with correct headers', async () => {
    const req = new IncomingRequest('http://example.com/parse', {
      method: 'OPTIONS',
      headers: {
        Origin: 'http://localhost:3000',
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'content-type,x-client-id,authorization',
      },
    });
    const ctx = createExecutionContext();
    const res = await worker.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(res.status).toBe(204);
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe('http://localhost:3000');
    expect(res.headers.get('Access-Control-Allow-Methods')).toBe('GET, POST, OPTIONS');
    expect(res.headers.get('Access-Control-Allow-Headers')).toContain('content-type');
  });

  it('rejects preflight for disallowed origin', async () => {
    const req = new IncomingRequest('http://example.com/parse', {
      method: 'OPTIONS',
      headers: {
        Origin: 'https://malicious.com',
      },
    });
    const ctx = createExecutionContext();
    const res = await worker.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(res.status).toBe(403);
  });

  it('rejects POST /parse with disallowed origin', async () => {
    const req = new IncomingRequest('http://example.com/parse', {
      method: 'POST',
      headers: {
        Origin: 'https://evil.com',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text: 'hello' }),
    });
    const ctx = createExecutionContext();
    const res = await worker.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(res.status).toBe(403);
  });

  it('accepts POST /parse with allowed origin and responds with CORS headers', async () => {
    const origin = 'http://localhost:5173';
    const req = new IncomingRequest('http://example.com/parse', {
      method: 'POST',
      headers: {
        Origin: origin,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text: 'hello world' }),
    });
    const ctx = createExecutionContext();
    const res = await worker.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(res.status).toBe(200);
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe(origin);
  });

  it('treats Origin "null" as allowed (native iOS)', async () => {
    const req = new IncomingRequest('http://example.com/parse', {
      method: 'POST',
      headers: {
        Origin: 'null',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text: 'ok' }),
    });
    const ctx = createExecutionContext();
    const res = await worker.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(res.status).toBe(200);
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe('null');
  });

  it('rejects unsupported content-type with 415', async () => {
    const req = new IncomingRequest('http://example.com/parse', {
      method: 'POST',
      headers: {
        Origin: 'http://localhost:3000',
        'Content-Type': 'text/plain',
      },
      body: 'plain text',
    });
    const ctx = createExecutionContext();
    const res = await worker.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(res.status).toBe(415);
  });

  it('rejects >1MB body with 413 based on Content-Length', async () => {
    // Create ~1.1MB JSON body quickly
    const payload = 'x'.repeat(1_050_000);
    const body = JSON.stringify({ text: payload });
    const req = new IncomingRequest('http://example.com/parse', {
      method: 'POST',
      headers: {
        Origin: 'http://localhost:3000',
        'Content-Type': 'application/json',
        'Content-Length': String(body.length),
      },
      body,
    });
    const ctx = createExecutionContext();
    const res = await worker.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(res.status).toBe(413);
  });

  it('rejects >250k characters in text field with 413', async () => {
    const longText = 'a'.repeat(250_001);
    const req = new IncomingRequest('http://example.com/parse', {
      method: 'POST',
      headers: {
        Origin: 'http://localhost:3000',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text: longText }),
    });
    const ctx = createExecutionContext();
    const res = await worker.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(res.status).toBe(413);
  });

  it('rejects invalid JSON with 400', async () => {
    const req = new IncomingRequest('http://example.com/parse', {
      method: 'POST',
      headers: {
        Origin: 'http://localhost:3000',
        'Content-Type': 'application/json',
      },
      body: '{ invalid json',
    });
    const ctx = createExecutionContext();
    const res = await worker.fetch(req, env, ctx);
    await waitOnExecutionContext(ctx);
    expect(res.status).toBe(400);
  });
});

