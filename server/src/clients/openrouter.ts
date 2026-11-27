import { logError, logRequest, nowIso } from '../logging';
import { validateSingleEvent } from '../validation/eventValidation';

type ChatMessage = { role: 'system' | 'user' | 'assistant'; content: string };

export interface PromptRequest {
  model: string;
  temperature?: number;
  messages: ChatMessage[];
  response_format?:
  | { type: 'json_object' }
  | { type: 'json_schema'; json_schema: { name: string; schema: unknown; strict?: boolean } };
}

export interface OpenRouterClientOptions {
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

class OpenRouterHTTPError extends Error {
  readonly code = 'OPENROUTER_HTTP';

  constructor(readonly status: number) {
    super(`OpenRouter HTTP ${status}`);
  }
}

export async function callOpenRouterParse(
  env: Env,
  prompt: PromptRequest,
  reqMeta?: { requestId?: string; route?: string; method?: string },
  options: OpenRouterClientOptions = {}
): Promise<unknown[]> {
  const timeoutOverride = parseInt(env.OPENROUTER_TIMEOUT_MS || '', 10);
  const retriesOverride = parseInt(env.OPENROUTER_RETRIES || '', 10);
  const timeoutMs = options.timeoutMs
    ?? (Number.isFinite(timeoutOverride) && timeoutOverride > 0 ? timeoutOverride : undefined)
    ?? DEFAULT_TIMEOUT_MS;
  const retries = options.retries
    ?? (Number.isFinite(retriesOverride) && retriesOverride >= 0 ? retriesOverride : undefined)
    ?? DEFAULT_RETRIES;
  const apiKey = env.OPENROUTER_API_KEY?.trim();
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
      error: { message: 'OPENROUTER_API_KEY missing', code: 'CONFIG_MISSING' },
    });
    throw Object.assign(new Error('OPENROUTER_API_KEY missing'), { code: 'CONFIG_MISSING' });
  }

  const url = 'https://openrouter.ai/api/v1/chat/completions';
  const init: RequestInit = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
      'X-OpenRouter-Title': 'Syllabus Sync',
    },
    body: JSON.stringify({
      model: prompt.model,
      messages: prompt.messages,
      temperature: prompt.temperature ?? 0,
      max_tokens: Number.parseInt(env.OPENROUTER_MAX_COMPLETION_TOKENS || '4096', 10) || 4096,
      response_format: prompt.response_format,
      provider: { require_parameters: true, data_collection: 'deny', zdr: true },
    }),
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
          openrouterRequest: { model: prompt.model, temperature: prompt.temperature ?? 0, timeoutMs, retries }
        });
      }

      const res = await fetchWithTimeout(url, init, timeoutMs);
      if (!res.ok) throw new OpenRouterHTTPError(res.status);
      const data = await res.json<{ choices?: { message?: { content?: string } }[]; error?: { code?: number } }>();
      if (data.error) throw new OpenRouterHTTPError(data.error.code ?? 502);
      const text = data.choices?.[0]?.message?.content;
      if (!text) {
        const err = new Error('OpenRouter returned empty content');
        (err as any).code = 'OPENROUTER_EMPTY';
        throw err;
      }
      let parsed: unknown;
      try {
        parsed = JSON.parse(text);
      } catch (e) {
        const err = new Error('Invalid JSON from OpenRouter');
        (err as any).code = 'INVALID_JSON';
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
      lastError = normalizeOpenRouterError(error);
      if (attempt === retries || (error instanceof OpenRouterHTTPError && !isRetriableStatus(error.status))) break;
      await sleep(calcBackoff(attempt));
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
      message: (lastError as any)?.message || 'OpenRouter call failed',
      stack: (lastError as any)?.stack,
      code: (lastError as any)?.code || 'OPENROUTER_ERROR',
    },
  });
  throw (lastError as Error) || Object.assign(new Error('OpenRouter call failed'), { code: 'OPENROUTER_ERROR' });
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

function normalizeOpenRouterError(error: unknown): Error {
  if (error instanceof Error) {
    return error;
  }
  if (typeof error === 'string') {
    const err = new Error(error);
    (err as any).code = error === 'timeout' ? 'OPENROUTER_TIMEOUT' : 'OPENROUTER_ERROR';
    return err;
  }
  const err = new Error('OpenRouter call failed');
  Object.assign(err as any, error ?? {});
  return err;
}
