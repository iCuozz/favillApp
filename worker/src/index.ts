import { Hono } from 'hono';
import type { Env } from './env';
import { appGuard, corsMiddleware } from './lib/guard';
import {
  handleAskReal,
  handleAskRealAdminAnswer,
  handleAskRealAdminList,
} from './handlers/ask_real';
import { handleAdminUi } from './handlers/admin_ui';

const app = new Hono<{ Bindings: Env }>();

app.use('*', corsMiddleware);

app.get('/health', (c) =>
  c.json({
    ok: true,
    minAppVersion: c.env.MIN_APP_VERSION,
    hasKv: Boolean(c.env.AI_KV),
    hasDb: Boolean(c.env.DB),
    time: new Date().toISOString(),
  }),
);

// Endpoint admin per moderare le domande inviate a "Chiedi a Favilla reale".
// Protetti da ADMIN_TOKEN (Bearer auth), montati fuori dall'`appGuard`
// così Favilla può chiamarli da una semplice pagina HTML/curl senza dover
// inviare gli header `x-client-id`/`x-app-version` dell'app.
app.get('/admin', handleAdminUi);
app.get('/admin/ask-real', handleAskRealAdminList);
app.post('/admin/ask-real/:id', handleAskRealAdminAnswer);

const api = new Hono<{ Bindings: Env }>();
api.use('*', appGuard);

api.post('/ask-real', handleAskReal);

app.route('/v1', api);

app.onError((err, c) => {
  console.error(JSON.stringify({
    event: 'unhandled_error',
    message: err instanceof Error ? err.message : String(err),
  }));
  return c.json({ error: 'internal_error' }, 500);
});

app.notFound((c) => c.json({ error: 'not_found' }, 404));

export default app;
