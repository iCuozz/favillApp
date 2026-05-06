import type { Env, RequestMeta } from '../env';

/**
 * Rate limit per (clientId + endpoint) usando KV come storage.
 * Se KV non è configurato, lascia passare (utile in sviluppo locale).
 *
 * NOTA: questa funzione INCREMENTA il counter. Usare solo dopo aver
 * verificato che la richiesta sia andata a buon fine (oppure chiamare
 * [refundRateLimit] in caso di fallimento upstream).
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

/**
 * Restituisce un tentativo all'utente: usato quando Gemini fallisce con
 * un errore upstream (502/503/timeout) e non vogliamo punire l'utente per
 * un problema infrastrutturale. Best-effort: errori KV vengono ignorati.
 */
export async function refundRateLimit(
  env: Env,
  meta: RequestMeta,
  endpoint: string,
): Promise<void> {
  if (!env.AI_KV) return;
  const day = new Date().toISOString().slice(0, 10);
  const key = `rl:${endpoint}:${meta.clientId}:${day}`;
  try {
    const raw = await env.AI_KV.get(key);
    const used = raw ? parseInt(raw, 10) || 0 : 0;
    if (used <= 0) return;
    await env.AI_KV.put(key, String(used - 1), {
      expirationTtl: 60 * 60 * 26,
    });
  } catch (e) {
    console.warn('refundRateLimit failed:', (e as Error).message);
  }
}

function nextMidnight(): number {
  const d = new Date();
  d.setUTCHours(24, 0, 0, 0);
  return d.getTime();
}
