import { Hono } from 'hono';
import type { Env } from './env';
import { appGuard, corsMiddleware } from './lib/guard';
import { GeminiError } from './lib/gemini';
import { notImplemented } from './handlers/_stub';
import { handleChat } from './handlers/chat';
import { handleMission } from './handlers/mission';

const app = new Hono<{ Bindings: Env }>();

app.use('*', corsMiddleware);

app.get('/health', (c) =>
  c.json({
    ok: true,
    model: c.env.GEMINI_MODEL,
    minAppVersion: c.env.MIN_APP_VERSION,
    hasKey: Boolean(c.env.GEMINI_API_KEY),
    hasKv: Boolean(c.env.AI_KV),
    time: new Date().toISOString(),
  }),
);

const api = new Hono<{ Bindings: Env }>();
api.use('*', appGuard);

api.post('/chat', handleChat);
api.post('/mission', handleMission);
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
