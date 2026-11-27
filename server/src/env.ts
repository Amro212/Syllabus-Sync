export const DEFAULT_OPENROUTER_MODEL = 'deepseek/deepseek-v4.1-flash-1017';

export function ensureOpenRouterKey(env: Env): { ok: true } | { ok: false; message: string; code: string } {
  const key = env.OPENROUTER_API_KEY;
  if (!key || typeof key !== 'string' || key.trim().length === 0) {
    return {
      ok: false,
      code: 'CONFIG_MISSING',
      message:
        'AI scanning is temporarily unavailable. Please try again later.',
    };
  }
  return { ok: true };
}

