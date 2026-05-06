import type { Context } from 'hono';
import type { Env } from '../env';

interface RegisterBody {
  token?: string;
  platform?: 'android' | 'ios' | 'web';
}

/**
 * POST /v1/push/register
 * Registra (o aggiorna) il token FCM per il client_id corrente.
 */
export async function handlePushRegister(
  c: Context<{ Bindings: Env }>,
): Promise<Response> {
  const meta = c.get('meta');
  if (!c.env.DB) return c.json({ error: 'storage_not_configured' }, 503);

  const body = await c.req.json<RegisterBody>().catch(() => ({} as RegisterBody));
  const token = (body.token ?? '').trim();
  const platform = body.platform === 'ios' || body.platform === 'web' ? body.platform : 'android';

  if (!token || token.length < 32 || token.length > 4096) {
    return c.json({ error: 'invalid_token' }, 400);
  }

  await c.env.DB.prepare(
    `INSERT INTO push_tokens (client_id, token, platform, updated_at)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(client_id) DO UPDATE SET
       token = excluded.token,
       platform = excluded.platform,
       updated_at = excluded.updated_at`,
  ).bind(meta.clientId, token, platform, Date.now()).run();

  return c.json({ ok: true });
}

/**
 * GET /v1/inbox?since=<ms>
 * Ritorna le risposte di "Favilla coi superpoteri" rivolte al client_id.
 */
export async function handleInbox(
  c: Context<{ Bindings: Env }>,
): Promise<Response> {
  const meta = c.get('meta');
  if (!c.env.DB) return c.json({ items: [] });

  const since = parseInt(c.req.query('since') ?? '0', 10) || 0;

  const res = await c.env.DB.prepare(
    `SELECT id, question, favilla_answer, status, created_at, answered_at
       FROM questions
       WHERE client_id = ?
         AND favilla_answer IS NOT NULL
         AND answered_at IS NOT NULL
         AND answered_at > ?
       ORDER BY answered_at DESC
       LIMIT 50`,
  ).bind(meta.clientId, since).all();

  return c.json({ items: res.results ?? [] });
}
