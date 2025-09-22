import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { callOpenAIParse } from '../src/clients/openai.js';

type EnvLike = Partial<Env> & { [k: string]: any };

const goodEvent = {
  id: 'a1',
  courseCode: 'CS101',
  type: 'ASSIGNMENT',
  title: 'Assignment 1',
  start: '2025-09-12T00:00:00.000-05:00',
};

describe('OpenAI client', () => {
  const env: EnvLike = { OPENAI_API_KEY: 'sk-test' } as any;
  const reqMeta = { requestId: 'test', route: '/parse', method: 'POST' };
  let originalFetch: typeof fetch;

  beforeEach(() => {
    originalFetch = globalThis.fetch;
  });

  afterEach(() => {
    (globalThis as any).fetch = originalFetch;
    vi.restoreAllMocks();
  });

  it('sends response_format with Chat Completions when json_schema is requested', async () => {
    const mock = vi.fn(async (url: string, init: any) => {
      expect(url).toContain('/v1/chat/completions');
      const body = JSON.parse(init.body);
      expect(body.response_format?.type).toBe('json_schema');
      return new Response(
        JSON.stringify({ choices: [ { message: { content: JSON.stringify([goodEvent]) } } ] }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }) as any;
    ;(globalThis as any).fetch = mock;

    const prompt = {
      model: 'gpt-4o-mini',
      messages: [ { role: 'system', content: 'test' }, { role: 'user', content: 'parse' } ],
      response_format: { type: 'json_schema', json_schema: { name: 'event_items', schema: { type: 'array', items: {} } } }
    } as any;

    const res = await callOpenAIParse(env as Env, prompt, reqMeta, { timeoutMs: 5000, retries: 0 });
    expect(Array.isArray(res)).toBe(true);
    expect((res as any[]).length).toBe(1);
    expect((res as any[])[0].id).toBe('a1');
  });

  it('uses Chat Completions when response_format is json_object and parses choices[0].message.content', async () => {
    const mock = vi.fn(async (url: string, init: any) => {
      expect(url).toContain('/v1/chat/completions');
      return new Response(
        JSON.stringify({ choices: [ { message: { content: JSON.stringify([goodEvent]) } } ] }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }) as any;
    ;(globalThis as any).fetch = mock;

    const prompt = {
      model: 'gpt-4o-mini',
      messages: [ { role: 'system', content: 'test' }, { role: 'user', content: 'parse' } ],
      response_format: { type: 'json_object' }
    } as any;

    const res = await callOpenAIParse(env as Env, prompt, reqMeta, { timeoutMs: 5000, retries: 0 });
    expect(Array.isArray(res)).toBe(true);
    expect((res as any[])[0].courseCode).toBe('CS101');
  });

  it('retries on 500 then succeeds', async () => {
    const calls: any[] = [];
    const mock = vi.fn(async (url: string, init: any) => {
      calls.push(1);
      if (calls.length === 1) {
        return new Response('oops', { status: 500 });
      }
      return new Response(
        JSON.stringify({ choices: [ { message: { content: JSON.stringify([goodEvent]) } } ] }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }) as any;
    ;(globalThis as any).fetch = mock;

    const prompt = {
      model: 'gpt-4o-mini',
      messages: [ { role: 'user', content: 'go' } ],
    } as any;

    const res = await callOpenAIParse(env as Env, prompt, reqMeta, { timeoutMs: 5000, retries: 1 });
    expect(calls.length).toBe(2);
    expect((res as any[]).length).toBe(1);
  });

  it('falls back by removing response_format when server rejects it', async () => {
    let call = 0;
    const mock = vi.fn(async (url: string, init: any) => {
      call++;
      if (call === 1) {
        // Simulate server rejecting response_format
        return new Response(
          JSON.stringify({ error: { message: "Unsupported parameter: 'response_format'. In the Responses API, this parameter has moved to 'text.format'." } }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        );
      }
      const body = JSON.parse(init.body);
      expect(body.response_format).toBeUndefined();
      return new Response(
        JSON.stringify({ choices: [ { message: { content: JSON.stringify([goodEvent]) } } ] }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }) as any;
    ;(globalThis as any).fetch = mock;

    const prompt = {
      model: 'gpt-4o-mini',
      messages: [ { role: 'system', content: 'test' }, { role: 'user', content: 'parse' } ],
      response_format: { type: 'json_schema', json_schema: { name: 'event_items', schema: { type: 'array', items: {} } } }
    } as any;

    const res = await callOpenAIParse(env as Env, prompt, reqMeta, { timeoutMs: 5000, retries: 1 });
    expect(call).toBeGreaterThan(1);
    expect((res as any[])[0].id).toBe('a1');
  });
});
