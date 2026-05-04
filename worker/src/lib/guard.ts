import type { Context, Next } from 'hono';
import type { Env, RequestMeta } from '../env';

declare module 'hono' {
  interface ContextVariableMap {
    meta: RequestMeta;
  }
}

/**
 * Verifica se l'origin del browser è ammesso. In aggiunta alla lista
 * ALLOWED_ORIGINS, accetta sempre `http://localhost:*` e `http://127.0.0.1:*`
 * per facilitare lo sviluppo Flutter web.
 */
export function isOriginAllowed(origin: string | null, allowedCsv: string): boolean {
  if (!origin) return true; // chiamate non-browser (Android/iOS) non inviano Origin
  const allowed = (allowedCsv ?? '').split(',').map((s) => s.trim()).filter(Boolean);
  if (allowed.includes('*')) return true;
  if (allowed.includes(origin)) return true;
  try {
    const url = new URL(origin);
    if (url.hostname === 'localhost' || url.hostname === '127.0.0.1') return true;
  } catch {
    return false;
  }
  return false;
}

/**
 * Middleware CORS. Risponde ai preflight OPTIONS e aggiunge gli header
 * Access-Control-* alle risposte successive.
 */
export async function corsMiddleware(
  c: Context<{ Bindings: Env }>,
  next: Next,
): Promise<Response | void> {
  const origin = c.req.header('origin') ?? null;
  const allowed = isOriginAllowed(origin, c.env.ALLOWED_ORIGINS);

  if (c.req.method === 'OPTIONS') {
    if (!allowed) return c.json({ error: 'origin_not_allowed' }, 403);
    return new Response(null, {
      status: 204,
      headers: {
        'access-control-allow-origin': origin ?? '*',
        'access-control-allow-methods': 'GET,POST,OPTIONS',
        'access-control-allow-headers': 'content-type,x-client-id,x-app-version',
        'access-control-max-age': '86400',
        vary: 'origin',
      },
    });
  }

  await next();

  if (origin && allowed && c.res) {
    c.res.headers.set('access-control-allow-origin', origin);
    c.res.headers.set('vary', 'origin');
  }
}

/**
 * Estrae header standard, valida versione minima dell'app e popola
 * `c.var.meta` per gli handler downstream. La parte CORS è in
 * [corsMiddleware] e va registrata prima.
 */
export async function appGuard(
  c: Context<{ Bindings: Env }>,
  next: Next,
): Promise<Response | void> {
  const origin = c.req.header('origin') ?? null;
  if (!isOriginAllowed(origin, c.env.ALLOWED_ORIGINS)) {
    return c.json({ error: 'origin_not_allowed' }, 403);
  }

  const appVersion = c.req.header('x-app-version') ?? '';
  if (!isVersionAtLeast(appVersion, c.env.MIN_APP_VERSION)) {
    return c.json({ error: 'app_version_too_old', min: c.env.MIN_APP_VERSION }, 426);
  }

  const clientId = c.req.header('x-client-id') ?? '';
  if (!clientId || clientId.length < 8 || clientId.length > 64) {
    return c.json({ error: 'missing_client_id' }, 400);
  }

  const ip = c.req.header('cf-connecting-ip') ?? 'unknown';
  c.set('meta', { clientId, appVersion, origin, ip });

  await next();
}

function isVersionAtLeast(actual: string, min: string): boolean {
  const a = actual.split('.').map((n) => parseInt(n, 10) || 0);
  const b = min.split('.').map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const x = a[i] ?? 0;
    const y = b[i] ?? 0;
    if (x > y) return true;
    if (x < y) return false;
  }
  return true;
}
