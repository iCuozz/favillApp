# FavillApp Worker

Proxy minimale su Cloudflare Workers per la feature **"Chiedi a Favilla reale"**: gli utenti inviano domande dall'app, l'autrice risponde dalla pagina admin, le risposte vengono salvate nel database D1.

Non è un proxy AI — nessuna chiamata a Gemini o altri LLM.

## Endpoint

| Path                        | Stato          | Descrizione                              |
|-----------------------------|----------------|------------------------------------------|
| `GET  /health`              | ✅ attivo       | smoke test, controlla KV/DB/version     |
| `POST /v1/ask-real`         | ✅ attivo       | Invia una domanda a Favilla reale        |
| `GET  /admin`               | ✅ attivo       | Pagina HTML di moderazione (admin)       |
| `GET  /admin/ask-real`      | ✅ attivo       | Lista domande (Bearer token)             |
| `POST /admin/ask-real/:id`  | ✅ attivo       | Risponde o salta una domanda             |

Tutti gli endpoint `/v1/*` richiedono gli header:
- `X-App-Version` ≥ `MIN_APP_VERSION` (altrimenti `426`)
- `X-Client-Id` (UUID stabile per device, 8-64 char)
- `Origin` ∈ `ALLOWED_ORIGINS` quando presente

## Setup

```bash
cd worker
npm install
cp .dev.vars.example .dev.vars  # aggiungi ADMIN_TOKEN
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
# scommenta [[kv_namespaces]] in wrangler.toml e incolla l'id
```

## Deploy

```bash
npm run deploy
```

## Configurazione `wrangler.toml`

- `ALLOWED_ORIGINS` — lista CSV (es. `https://favilla.app,http://localhost`)
- `MIN_APP_VERSION` — versione minima accettata (es. `1.0.6`)
- `ADMIN_TOKEN` — secret per proteggere gli endpoint `/admin/*`
