import { Hono } from 'hono';
import type { Env } from './env';
import { appGuard, corsMiddleware } from './lib/guard';
import { GeminiError } from './lib/gemini';
import { notImplemented } from './handlers/_stub';
import { handleChat } from './handlers/chat';
import { handleMission } from './handlers/mission';
import { handlePanelImage } from './handlers/panel_image';
import {
  handleAskReal,
  handleAskRealAdminAnswer,
  handleAskRealAdminList,
} from './handlers/ask_real';
import { handleAdminUi } from './handlers/admin_ui';
import { handleInbox, handlePushRegister } from './handlers/inbox';

const app = new Hono<{ Bindings: Env }>();

app.use('*', corsMiddleware);

app.get('/health', (c) =>
  c.json({
    ok: true,
    model: c.env.GEMINI_MODEL,
    minAppVersion: c.env.MIN_APP_VERSION,
    hasKey: Boolean(c.env.GEMINI_API_KEY),
    hasKv: Boolean(c.env.AI_KV),
    hasDb: Boolean(c.env.DB),
    time: new Date().toISOString(),
  }),
);

// Endpoint admin per moderare le domande inviate a "Favilla reale".
// Protetti da ADMIN_TOKEN (Bearer auth), montati fuori dall'`appGuard`
// così Favilla può chiamarli da una semplice pagina HTML/curl senza dover
// inviare gli header `x-client-id`/`x-app-version` dell'app.
app.get('/admin', handleAdminUi);
app.get('/admin/ask-real', handleAskRealAdminList);
app.post('/admin/ask-real/:id', handleAskRealAdminAnswer);

const api = new Hono<{ Bindings: Env }>();
api.use('*', appGuard);

api.post('/chat', handleChat);
api.post('/mission', handleMission);
api.post('/panel-image', handlePanelImage);
api.post('/ask-real', handleAskReal);
api.post('/push/register', handlePushRegister);
api.get('/inbox', handleInbox);
api.post('/caption', (c) => notImplemented(c, 'caption'));
api.post('/next-panel', (c) => notImplemented(c, 'next-panel'));

app.route('/v1', api);

app.onError((err, c) => {
  if (err instanceof GeminiError) {
    console.warn(JSON.stringify({
      event: 'gemini_error',
      status: err.status,
      message: err.message,
      detail: err.detail,
    }));
    // 429 / 503 upstream = "Gemini è sovraccarico, riprova tra poco".
    // Codice dedicato così l'app può mostrare un messaggio chiaro
    // e l'utente non perde la quota (vedi refund nei singoli handler).
    if (err.status === 429 || err.status === 503) {
      return c.json(
        { error: 'upstream_busy', message: err.message },
        503,
      );
    }
    return c.json({ error: 'ai_error', message: err.message }, err.status as 400 | 502);
  }
  console.error(JSON.stringify({
    event: 'unhandled_error',
    message: err.message,
  }));
  return c.json({ error: 'internal_error' }, 500);
});

app.notFound((c) => c.json({ error: 'not_found' }, 404));

export default app;
