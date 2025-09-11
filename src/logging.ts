export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export interface RequestLog {
  ts: string;
  requestId: string;
  route: string;
  method: string;
  status: number;
  durationMs: number;
  // Optional contextual fields allowed, but avoid PII
  [key: string]: unknown;
}

export interface ErrorLog extends RequestLog {
  error: {
    message?: string;
    stack?: string;
    code?: string | number;
  };
}

function shouldLog(env: Env, level: LogLevel): boolean {
  // Only log to console for development by default
  const envMode = env.NODE_ENV?.toLowerCase?.() || '';
  if (envMode !== 'development') return false;

  const levels: LogLevel[] = ['debug', 'info', 'warn', 'error'];
  const configured = (env.LOG_LEVEL?.toLowerCase?.() as LogLevel) || 'info';
  return levels.indexOf(level) >= levels.indexOf(configured);
}

export function logRequest(env: Env, level: LogLevel, entry: RequestLog): void {
  if (!shouldLog(env, level)) return;
  const payload = { level, ...entry };
  if (level === 'error') console.error(JSON.stringify(payload));
  else if (level === 'warn') console.warn(JSON.stringify(payload));
  else if (level === 'debug') console.debug(JSON.stringify(payload));
  else console.log(JSON.stringify(payload));
}

export function logError(env: Env, entry: ErrorLog): void {
  logRequest(env, 'error', entry);
}

export function nowIso(): string {
  return new Date().toISOString();
}

