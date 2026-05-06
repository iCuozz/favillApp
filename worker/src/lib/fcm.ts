/**
 * FCM HTTP v1 sender per Cloudflare Workers.
 *
 * Usa il service account JSON di Firebase per firmare un JWT ES256/RS256
 * (qui RS256, formato standard) e ottenere un OAuth2 access token, poi invia
 * via `https://fcm.googleapis.com/v1/projects/{project}/messages:send`.
 *
 * Tutto con WebCrypto nativo dei Workers — niente dipendenze esterne.
 *
 * Il token OAuth dura 1 ora ed è cacheato in KV (`fcm:access_token`).
 */
import type { Env } from '../env';

interface ServiceAccount {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  token_uri: string;
}

interface FcmMessage {
  token: string;
  notification?: { title?: string; body?: string };
  data?: Record<string, string>;
  android?: {
    priority?: 'NORMAL' | 'HIGH';
    notification?: {
      channel_id?: string;
      sound?: string;
      click_action?: string;
    };
  };
}

const KV_TOKEN_KEY = 'fcm:access_token';

export async function sendFcm(env: Env, message: FcmMessage): Promise<{ ok: boolean; status: number; body?: string }> {
  if (!env.FCM_SERVICE_ACCOUNT_JSON) {
    return { ok: false, status: 0, body: 'fcm_not_configured' };
  }
  let sa: ServiceAccount;
  try {
    sa = JSON.parse(env.FCM_SERVICE_ACCOUNT_JSON) as ServiceAccount;
  } catch {
    return { ok: false, status: 0, body: 'invalid_service_account_json' };
  }

  const token = await getAccessToken(env, sa);
  if (!token) {
    return { ok: false, status: 0, body: 'token_failed' };
  }

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ message }),
    },
  );
  const body = await res.text().catch(() => '');
  return { ok: res.ok, status: res.status, body: body.slice(0, 500) };
}

async function getAccessToken(env: Env, sa: ServiceAccount): Promise<string | null> {
  if (env.AI_KV) {
    const cached = await env.AI_KV.get<{ token: string; exp: number }>(KV_TOKEN_KEY, 'json');
    if (cached && cached.exp > Date.now() / 1000 + 60) {
      return cached.token;
    }
  }

  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  };
  const header = { alg: 'RS256', typ: 'JWT', kid: sa.private_key_id };

  const enc = (obj: object) =>
    base64UrlEncode(new TextEncoder().encode(JSON.stringify(obj)));
  const signingInput = `${enc(header)}.${enc(claim)}`;

  const key = await importPrivateKey(sa.private_key);
  const sig = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    new TextEncoder().encode(signingInput),
  );
  const jwt = `${signingInput}.${base64UrlEncode(new Uint8Array(sig))}`;

  const tokenRes = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  if (!tokenRes.ok) {
    const errBody = await tokenRes.text().catch(() => '');
    console.error(JSON.stringify({
      event: 'fcm_token_error',
      status: tokenRes.status,
      body: errBody.slice(0, 300),
    }));
    return null;
  }
  const json = (await tokenRes.json()) as { access_token: string; expires_in: number };

  if (env.AI_KV) {
    await env.AI_KV.put(
      KV_TOKEN_KEY,
      JSON.stringify({ token: json.access_token, exp: now + json.expires_in }),
      { expirationTtl: Math.max(60, json.expires_in - 120) },
    );
  }
  return json.access_token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  const der = base64Decode(cleaned);
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

function base64UrlEncode(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64Decode(b64: string): ArrayBuffer {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}
