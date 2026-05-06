-- Tabella per i token push (FCM) registrati dai client.
-- Un client_id può aggiornare il proprio token nel tempo (es. reinstallazione).
CREATE TABLE IF NOT EXISTS push_tokens (
  client_id TEXT PRIMARY KEY,
  token TEXT NOT NULL,
  platform TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_updated ON push_tokens(updated_at);
