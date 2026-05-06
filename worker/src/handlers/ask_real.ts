import type { Context } from 'hono';
import type { Env } from '../env';
import { checkRateLimit, refundRateLimit } from '../lib/rate_limit';
import { sendFcm } from '../lib/fcm';

interface AskRealBody {
  question?: string;
  aiAnswer?: string;
  contact?: string;
  lang?: 'it' | 'en';
}

const PER_DAY = 3;            // max 3 domande/giorno per utente
const MAX_QUESTION_CHARS = 600;
const MAX_AI_ANSWER_CHARS = 2000;
const MAX_CONTACT_CHARS = 120;

/**
 * POST /v1/ask-real
 * Salva nella coda moderata una domanda che l'utente vuole inoltrare
 * a "Favilla reale". Risposta IA opzionale (per contesto di Favilla).
 */
export async function handleAskReal(
  c: Context<{ Bindings: Env }>,
): Promise<Response> {
  const meta = c.get('meta');
  const body = await c.req.json<AskRealBody>().catch(() => ({} as AskRealBody));

  const question = (body.question ?? '').trim();
  if (!question) {
    return c.json({ error: 'empty_question' }, 400);
  }
  if (question.length > MAX_QUESTION_CHARS) {
    return c.json({ error: 'question_too_long', max: MAX_QUESTION_CHARS }, 400);
  }

  const aiAnswer = (body.aiAnswer ?? '').slice(0, MAX_AI_ANSWER_CHARS) || null;
  const contact = (body.contact ?? '').trim().slice(0, MAX_CONTACT_CHARS) || null;
  const lang = body.lang === 'en' ? 'en' : 'it';

  if (!c.env.DB) {
    return c.json({ error: 'storage_not_configured' }, 503);
  }

  const limit = await checkRateLimit(c.env, meta, 'ask-real', { perDay: PER_DAY });
  if (!limit.allowed) {
    return c.json({
      error: 'quota_exceeded',
      message: 'Hai inviato troppe domande oggi. Riprova domani.',
      remaining: 0,
      resetAt: limit.resetAt,
    }, 429);
  }

  const id = crypto.randomUUID();
  const now = Date.now();

  try {
    await c.env.DB.prepare(
      `INSERT INTO questions
         (id, client_id, lang, question, ai_answer, contact, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)`,
    ).bind(id, meta.clientId, lang, question, aiAnswer, contact, now).run();
  } catch (err) {
    console.error(JSON.stringify({
      event: 'ask_real_db_error',
      message: err instanceof Error ? err.message : String(err),
    }));
    await refundRateLimit(c.env, meta, 'ask-real');
    return c.json({ error: 'storage_error' }, 502);
  }

  return c.json({
    ok: true,
    id,
    remaining: limit.remaining,
    resetAt: limit.resetAt,
  });
}

/**
 * GET /v1/ask-real/admin?status=pending&limit=50
 * Protetto da `Authorization: Bearer <ADMIN_TOKEN>`.
 */
export async function handleAskRealAdminList(
  c: Context<{ Bindings: Env }>,
): Promise<Response> {
  const auth = c.req.header('authorization') ?? '';
  if (!c.env.ADMIN_TOKEN || auth !== `Bearer ${c.env.ADMIN_TOKEN}`) {
    return c.json({ error: 'unauthorized' }, 401);
  }
  if (!c.env.DB) {
    return c.json({ error: 'storage_not_configured' }, 503);
  }

  const status = c.req.query('status') ?? 'pending';
  const limit = Math.min(parseInt(c.req.query('limit') ?? '50', 10) || 50, 200);

  const res = await c.env.DB.prepare(
    `SELECT id, client_id, lang, question, ai_answer, contact, status,
            favilla_answer, created_at, answered_at
       FROM questions
       WHERE status = ?
       ORDER BY created_at DESC
       LIMIT ?`,
  ).bind(status, limit).all();

  return c.json({ items: res.results ?? [] });
}

/**
 * POST /v1/ask-real/admin/:id
 * Body: { answer?: string, status?: 'answered' | 'skipped' | 'featured' }
 * Protetto da `Authorization: Bearer <ADMIN_TOKEN>`.
 */
export async function handleAskRealAdminAnswer(
  c: Context<{ Bindings: Env }>,
): Promise<Response> {
  const auth = c.req.header('authorization') ?? '';
  if (!c.env.ADMIN_TOKEN || auth !== `Bearer ${c.env.ADMIN_TOKEN}`) {
    return c.json({ error: 'unauthorized' }, 401);
  }
  if (!c.env.DB) {
    return c.json({ error: 'storage_not_configured' }, 503);
  }

  const id = c.req.param('id');
  if (!id) return c.json({ error: 'missing_id' }, 400);
  const body = await c.req.json<{ answer?: string; status?: string }>()
    .catch(() => ({} as { answer?: string; status?: string }));
  const newStatus = body.status === 'skipped' || body.status === 'featured'
    ? body.status
    : 'answered';
  const answer = (body.answer ?? '').trim() || null;

  await c.env.DB.prepare(
    `UPDATE questions
        SET favilla_answer = ?, status = ?, answered_at = ?
      WHERE id = ?`,
  ).bind(answer, newStatus, Date.now(), id).run();

  // Se è una vera risposta, prova a inviare la push al client che l'aveva
  // mandata. Errori FCM non bloccano la risposta admin (best-effort).
  if (newStatus === 'answered' && answer) {
    c.executionCtx.waitUntil(notifyClient(c.env, id, answer));
  }

  return c.json({ ok: true });
}

async function notifyClient(env: Env, questionId: string, answer: string): Promise<void> {
  if (!env.DB) return;
  try {
    const row = await env.DB.prepare(
      `SELECT q.client_id, q.question, q.lang, p.token
         FROM questions q
         LEFT JOIN push_tokens p ON p.client_id = q.client_id
        WHERE q.id = ?`,
    ).bind(questionId).first<{
      client_id: string;
      question: string;
      lang: string;
      token: string | null;
    }>();
    if (!row || !row.token) return;

    const isEn = row.lang === 'en';
    const title = isEn ? '✨ Favilla replied!' : '✨ Favilla ti ha risposto!';
    const preview = answer.length > 90 ? answer.slice(0, 87) + '...' : answer;

    const result = await sendFcm(env, {
      token: row.token,
      notification: { title, body: preview },
      data: {
        type: 'ask_real_answer',
        questionId,
        question: row.question.slice(0, 200),
      },
      android: {
        priority: 'HIGH',
        notification: {
          channel_id: 'favilla_replies',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
    });

    console.log(JSON.stringify({
      event: 'fcm_send',
      questionId,
      ok: result.ok,
      status: result.status,
    }));

    // Token non valido (404 / UNREGISTERED): rimuoviamo dalla tabella così
    // non ritentiamo all'infinito.
    if (result.status === 404 || (result.body && result.body.includes('UNREGISTERED'))) {
      await env.DB.prepare(
        `DELETE FROM push_tokens WHERE client_id = ?`,
      ).bind(row.client_id).run();
    }
  } catch (err) {
    console.error(JSON.stringify({
      event: 'notify_client_error',
      questionId,
      message: err instanceof Error ? err.message : String(err),
    }));
  }
}
