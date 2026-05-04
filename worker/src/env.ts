export interface Env {
  // Secrets
  GEMINI_API_KEY: string;

  // Vars
  GEMINI_MODEL: string;
  ALLOWED_ORIGINS: string;
  MIN_APP_VERSION: string;

  // Bindings (opzionale: legato in wrangler.toml dopo aver creato il KV)
  AI_KV?: KVNamespace;
}

export interface RequestMeta {
  clientId: string;
  appVersion: string;
  origin: string | null;
  ip: string;
}
