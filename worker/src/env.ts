export interface Env {
  // Secrets
  GEMINI_API_KEY: string;
  ADMIN_TOKEN?: string;
  /** JSON del service account FCM (Firebase Admin SDK). Se assente, push disabilitate. */
  FCM_SERVICE_ACCOUNT_JSON?: string;

  // Vars
  GEMINI_MODEL: string;
  ALLOWED_ORIGINS: string;
  MIN_APP_VERSION: string;

  // Bindings (opzionale: legato in wrangler.toml dopo aver creato il KV)
  AI_KV?: KVNamespace;
  AI?: Ai;
  DB?: D1Database;
}

export interface RequestMeta {
  clientId: string;
  appVersion: string;
  origin: string | null;
  ip: string;
}
