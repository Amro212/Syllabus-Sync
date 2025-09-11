export function ensureOpenAIKey(env: Env): { ok: true } | { ok: false; message: string; code: string } {
  const key = env.OPENAI_API_KEY;
  if (!key || typeof key !== 'string' || key.trim().length === 0) {
    return {
      ok: false,
      code: 'CONFIG_MISSING',
      message:
        'Server misconfigured: OPENAI_API_KEY is not set. Use `wrangler secret put OPENAI_API_KEY` (prod) or add to .dev.vars (dev).',
    };
  }
  return { ok: true };
}

