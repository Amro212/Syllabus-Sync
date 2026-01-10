import { logError, logRequest, nowIso } from '../logging';
import { validateSingleEvent } from '../validation/eventValidation';

type ChatMessage = { role: 'system' | 'user' | 'assistant'; content: string };

export interface PromptRequest {
  model: string;
  temperature?: number;
  messages: ChatMessage[];
  // When present and type is 'json_schema', we call the Responses API
  response_format?:
  | { type: 'json_object' }
  | { type: 'json_schema'; json_schema: { name: string; schema: unknown; strict?: boolean } };
}

export interface OpenAIClientOptions {
  timeoutMs?: number; // default 20000
  retries?: number; // default 2 (total attempts = retries + 1)
}

const DEFAULT_TIMEOUT_MS = 30000;
const DEFAULT_RETRIES = 2;

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function calcBackoff(attempt: number): number {
  const base = 300 * Math.pow(2, attempt); // 300ms, 600ms
  const jitter = Math.floor(Math.random() * 200); // 0..200ms
  return base + jitter;
}

async function fetchWithTimeout(url: string, init: RequestInit, timeoutMs: number): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort('timeout'), timeoutMs);
  try {
    const res = await fetch(url, { ...init, signal: controller.signal });
    return res;
  } finally {
    clearTimeout(timer);
  }
}

function isRetriableStatus(status: number): boolean {
  return status === 408 || status === 429 || (status >= 500 && status < 600);
}

function extractTextFromResponse(data: any): string | null {
  // Try Responses API shapes first
  if (typeof data?.output_text === 'string' && data.output_text.trim().length > 0) {
    return data.output_text;
  }
  const maybeOutputText = data?.output?.[0]?.content?.[0]?.text;
  if (typeof maybeOutputText === 'string') return maybeOutputText;

  // Chat Completions shape
  const chatText = data?.choices?.[0]?.message?.content;
  if (typeof chatText === 'string') return chatText;

  // Some SDKs nest under message.content[0].text
  const deepText = data?.choices?.[0]?.message?.content?.[0]?.text;
  if (typeof deepText === 'string') return deepText;

  return null;
}

export async function callOpenAIParse(
  env: Env,
  prompt: PromptRequest,
  reqMeta?: { requestId?: string; route?: string; method?: string },
  options: OpenAIClientOptions = {}
): Promise<unknown[]> {
  const timeoutOverride = parseInt((env as any).OPENAI_TIMEOUT_MS || '', 10);
  const retriesOverride = parseInt((env as any).OPENAI_RETRIES || '', 10);
  const timeoutMs = options.timeoutMs
    ?? (Number.isFinite(timeoutOverride) && timeoutOverride > 0 ? timeoutOverride : undefined)
    ?? DEFAULT_TIMEOUT_MS;
  const retries = options.retries
    ?? (Number.isFinite(retriesOverride) && retriesOverride >= 0 ? retriesOverride : undefined)
    ?? DEFAULT_RETRIES;
  const apiKey = env.OPENAI_API_KEY;
  const started = Date.now();
  const requestId = reqMeta?.requestId || (globalThis as any).crypto?.randomUUID?.() || 'unknown';
  const route = reqMeta?.route || '/parse';
  const method = reqMeta?.method || 'POST';

  if (!apiKey) {
    const status = 500;
    logError(env, {
      ts: nowIso(),
      requestId,
      route,
      method,
      status,
      durationMs: Date.now() - started,
      error: { message: 'OPENAI_API_KEY missing', code: 'CONFIG_MISSING' },
    });
    throw Object.assign(new Error('OPENAI_API_KEY missing'), { code: 'CONFIG_MISSING' });
  }

  // Use Chat Completions for maximum compatibility. Some Responses API deployments
  // expect a different structure (e.g., text.format) and reject response_format.
  // We include response_format if present; on 400 complaining about response_format,
  // we retry without it and rely on strict prompting + local validation.
  let url = 'https://api.openai.com/v1/chat/completions';
  let body: any = {
    model: prompt.model,
    messages: prompt.messages,
    temperature: prompt.temperature ?? 0,
  };
  if (prompt.response_format) body.response_format = prompt.response_format;

  const init: RequestInit = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  };

  let lastError: any = null;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      // Log the request attempt for debugging
      if (attempt === 0) {
        logRequest(env, 'debug', {
          ts: nowIso(),
          requestId,
          route,
          method,
          status: 0,
          durationMs: 0,
          openaiRequest: { model: body.model, temperature: body.temperature, timeoutMs, retries }
        });
      }

      const res = await fetchWithTimeout(url, init, timeoutMs);
      if (!res.ok) {
        const status = res.status;
        const text = await res.text().catch(() => '');
        // Fallback: some servers reject response_format; retry once without it
        if (
          status === 400 &&
          body.response_format &&
          (/Unsupported parameter:\s*'response_format'|moved to 'text\.format'|Invalid value for 'response_format'/i.test(text)) &&
          attempt === 0 // Only try this fallback on first attempt
        ) {
          logRequest(env, 'warn', {
            ts: nowIso(),
            requestId,
            route,
            method,
            status: 0,
            durationMs: Date.now() - started,
            openaiWarning: 'Removing response_format due to API incompatibility'
          });
          delete body.response_format;
          init.body = JSON.stringify(body);
          const delay = calcBackoff(attempt);
          await sleep(delay);
          continue;
        }
        if (isRetriableStatus(status) && attempt < retries) {
          const delay = calcBackoff(attempt);
          await sleep(delay);
          continue;
        }
        const err = new Error(`OpenAI HTTP ${status}: ${text.slice(0, 300)}`);
        (err as any).code = 'OPENAI_HTTP';
        (err as any).status = status;
        throw err;
      }
      const data = await res.json();
      const text = extractTextFromResponse(data);
      if (!text) {
        const err = new Error('OpenAI returned empty content');
        (err as any).code = 'OPENAI_EMPTY';
        throw err;
      }
      let parsed: unknown;
      try {
        parsed = JSON.parse(text);
      } catch (e) {
        const err = new Error('Invalid JSON from OpenAI');
        (err as any).code = 'INVALID_JSON';
        (err as any).raw = text?.slice?.(0, 300);
        throw err;
      }

      const eventsArray = extractEventsArray(parsed);
      if (!eventsArray) {
        const err = new Error('Expected JSON object with events array');
        (err as any).code = 'INVALID_SHAPE';
        throw err;
      }

      // Light validation: ensure each item roughly matches EventItemDTO
      const invalids: string[] = [];
      for (let i = 0; i < eventsArray.length; i++) {
        const v = validateSingleEvent(eventsArray[i]);
        if (!v.valid) invalids.push(`item ${i + 1}: ${v.errors.join('; ')}`);
      }
      if (invalids.length > 0) {
        const err = new Error(`Schema validation failed: ${invalids.join(' | ')}`);
        (err as any).code = 'SCHEMA_INVALID';
        throw err;
      }

      logRequest(env, 'debug', {
        ts: nowIso(),
        requestId,
        route,
        method,
        status: 200,
        durationMs: Date.now() - started,
        items: eventsArray.length,
      });
      return eventsArray as unknown[];
    } catch (error) {
      lastError = normalizeOpenAIError(error);
      if (attempt < retries) {
        const delay = calcBackoff(attempt);
        await sleep(delay);
        continue;
      }
    }
  }

  logError(env, {
    ts: nowIso(),
    requestId,
    route,
    method,
    status: 502,
    durationMs: Date.now() - started,
    error: {
      message: (lastError as any)?.message || 'OpenAI call failed',
      stack: (lastError as any)?.stack,
      code: (lastError as any)?.code || 'OPENAI_ERROR',
    },
  });
  throw (lastError as Error) || Object.assign(new Error('OpenAI call failed'), { code: 'OPENAI_ERROR' });
}

function extractEventsArray(parsed: unknown): unknown[] | null {
  if (Array.isArray(parsed)) {
    return stripTimezoneOffsets(parsed);
  }
  if (parsed && typeof parsed === 'object') {
    const events = (parsed as any).events;
    if (Array.isArray(events)) {
      return stripTimezoneOffsets(events);
    }
  }
  return null;
}

/**
 * Strip timezone offsets from date strings to prevent DST-related display bugs.
 * Converts "2026-04-18T08:30:00.000-05:00" to "2026-04-18T08:30:00.000"
 */
function stripTimezoneOffsets(events: unknown[]): unknown[] {
  return events.map(event => {
    if (event && typeof event === 'object') {
      const eventObj = event as any;
      const result = { ...eventObj };

      // Strip timezone offset from start
      if (typeof result.start === 'string') {
        result.start = result.start.replace(/([+-]\d{2}:\d{2}|Z)$/, '');
      }

      // Strip timezone offset from end
      if (typeof result.end === 'string') {
        result.end = result.end.replace(/([+-]\d{2}:\d{2}|Z)$/, '');
      }

      return result;
    }
    return event;
  });
}

function normalizeOpenAIError(error: unknown): Error {
  if (error instanceof Error) {
    return error;
  }
  if (typeof error === 'string') {
    const err = new Error(error);
    (err as any).code = error === 'timeout' ? 'OPENAI_TIMEOUT' : 'OPENAI_ERROR';
    return err;
  }
  const err = new Error('OpenAI call failed');
  Object.assign(err as any, error ?? {});
  return err;
}
