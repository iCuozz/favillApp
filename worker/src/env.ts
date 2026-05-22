export interface Env {
  // Secrets
  ADMIN_TOKEN?: string;

  // Vars
  ALLOWED_ORIGINS: string;
  MIN_APP_VERSION: string;

  // Bindings
  AI_KV?: KVNamespace;
  DB?: D1Database;
}

export interface RequestMeta {
  clientId: string;
  appVersion: string;
  origin: string | null;
  ip: string;
}
