-- Tabella domande inviate a "Favilla reale".
-- Una riga per ogni messaggio che l'utente ha scelto di sottoporre alla
-- creator umana. La risposta AI è salvata per contesto (così Favilla vede
-- cosa aveva già detto l'IA).
CREATE TABLE IF NOT EXISTS questions (
  id TEXT PRIMARY KEY,
  client_id TEXT NOT NULL,
  lang TEXT NOT NULL,
  question TEXT NOT NULL,
  ai_answer TEXT,
  contact TEXT,                -- opzionale: email o @instagram per notificare
  status TEXT NOT NULL DEFAULT 'pending',  -- pending | answered | skipped | featured
  favilla_answer TEXT,
  created_at INTEGER NOT NULL, -- epoch ms
  answered_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_questions_status ON questions(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_questions_client ON questions(client_id, created_at DESC);
