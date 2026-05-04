# FavillApp AI Worker

Proxy minimale su Cloudflare Workers tra l'app Flutter e Google Gemini.
Nasconde la API key, applica rate limit per utente, valida versione app e
origini, e logga in modo minimale (mai PII / mai body utente).

## Endpoint

| Path                 | Stato            | Descrizione                                  |
|----------------------|------------------|----------------------------------------------|
| `GET  /health`       | ✅ implementato   | smoke test, controlla secret/KV/version     |
| `POST /v1/chat`      | 🚧 stub (501)     | "Chiedi a Favilla" — fase 3                 |
| `POST /v1/mission`   | 🚧 stub (501)     | Generatore missione — fase 4                |
| `POST /v1/caption`   | 🚧 stub (501)     | Didascalia foto — fase 5                    |
| `POST /v1/next-panel`| 🚧 stub (501)     | Indovina la vignetta — fase 6 (build-time)  |

Tutti gli endpoint `/v1/*` richiedono gli header:
- `X-App-Version` ≥ `MIN_APP_VERSION` (altrimenti `426`)
- `X-Client-Id` (UUID stabile per device, 8-64 char)
- `Origin` ∈ `ALLOWED_ORIGINS` quando presente

## Setup

```bash
cd worker
npm install
cp .dev.vars.example .dev.vars  # poi metti la chiave reale
npm run typecheck
npm run dev                     # http://127.0.0.1:8787
```

Smoke test:
```bash
curl http://127.0.0.1:8787/health
```

## KV per rate limit

```bash
npx wrangler kv namespace create AI_KV
# scommenta la sezione [[kv_namespaces]] in wrangler.toml e incolla l'id
```

## Secret in produzione

```bash
npx wrangler secret put GEMINI_API_KEY
```

## Deploy

```bash
npm run deploy
```

## Configurazione `wrangler.toml`

- `GEMINI_MODEL` (default `gemini-2.5-flash`)
- `ALLOWED_ORIGINS` lista CSV (es. `https://favilla.app,http://localhost`)
- `MIN_APP_VERSION` versione minima accettata (es. `1.0.3`)

Per usare il Worker dall'app Flutter:
```bash
flutter run --dart-define=AI_BASE_URL=https://your-worker.workers.dev
```
## flutter run --dart-define-from-file=dart_defines.json