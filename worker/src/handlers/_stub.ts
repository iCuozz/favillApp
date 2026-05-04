import type { Context } from 'hono';
import type { Env } from '../env';

export function notImplemented(c: Context<{ Bindings: Env }>, name: string): Response {
  return c.json(
    {
      error: 'not_implemented',
      endpoint: name,
      message: 'This endpoint is scaffolded and will be implemented in a later phase.',
    },
    501,
  );
}
