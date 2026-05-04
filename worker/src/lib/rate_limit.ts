import type { Env, RequestMeta } from '../env';

/**
 * Rate limit per (clientId + endpoint) usando KV come storage.
 * Se KV non è configurato, lascia passare (utile in sviluppo locale).
 */
export async function checkRateLimit(
  env: Env,
  meta: RequestMeta,
  endpoint: string,
  opts: { perDay: number },
): Promise<{ allowed: boolean; remaining: number; resetAt: number }> {
  const day = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  const key = `rl:${endpoint}:${meta.clientId}:${day}`;

  if (!env.AI_KV) {
    return { allowed: true, remaining: opts.perDay, resetAt: nextMidnight() };
  }

  const raw = await env.AI_KV.get(key);
  const used = raw ? parseInt(raw, 10) || 0 : 0;
  if (used >= opts.perDay) {
    return { allowed: false, remaining: 0, resetAt: nextMidnight() };
  }

  await env.AI_KV.put(key, String(used + 1), {
    expirationTtl: 60 * 60 * 26, // ~26h: copre cambi di fuso
  });
  return {
    allowed: true,
    remaining: opts.perDay - used - 1,
    resetAt: nextMidnight(),
  };
}

function nextMidnight(): number {
  const d = new Date();
  d.setUTCHours(24, 0, 0, 0);
  return d.getTime();
}
