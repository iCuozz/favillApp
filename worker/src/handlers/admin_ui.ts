import type { Context } from 'hono';
import type { Env } from '../env';

/**
 * GET /admin
 * Pagina HTML statica con UI minimale per leggere/rispondere alle domande
 * inviate a "Favilla coi superpoteri".
 *
 * L'auth è interamente client-side: l'utente incolla il token ADMIN_TOKEN
 * in un input, viene salvato in localStorage e usato come header
 * `Authorization: Bearer ...` per chiamare gli endpoint /admin/ask-real.
 */
export async function handleAdminUi(_c: Context<{ Bindings: Env }>): Promise<Response> {
  return new Response(HTML, {
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'no-store',
    },
  });
}

const HTML = /* html */ `<!doctype html>
<html lang="it">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Favilla coi superpoteri — Inbox</title>
  <style>
    :root {
      --bg: #1a1428;
      --card: #261b3a;
      --border: #3a2a55;
      --accent: #ffb84d;
      --accent2: #ff6fae;
      --text: #f5eef8;
      --muted: #a99bb8;
      --danger: #ff5c7a;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      min-height: 100vh;
    }
    header {
      padding: 16px 20px;
      background: linear-gradient(135deg, #2a1f44, #3d2660);
      border-bottom: 2px solid var(--border);
      display: flex; align-items: center; gap: 12px; flex-wrap: wrap;
    }
    header h1 {
      margin: 0; font-size: 18px; flex: 1;
    }
    header h1 small { color: var(--muted); font-weight: 400; font-size: 13px; }
    .tabs { display: flex; gap: 4px; padding: 8px 16px; background: #221634; border-bottom: 1px solid var(--border); overflow-x: auto; }
    .tab {
      padding: 8px 14px; border-radius: 8px 8px 0 0; background: transparent;
      color: var(--muted); border: none; cursor: pointer; font-size: 13px;
      font-weight: 600; white-space: nowrap;
    }
    .tab.active { background: var(--card); color: var(--accent); }
    main { padding: 16px; max-width: 800px; margin: 0 auto; }
    .auth-bar {
      background: var(--card); padding: 12px; border-radius: 10px;
      margin-bottom: 16px; display: flex; gap: 8px; align-items: center;
      border: 1px solid var(--border);
    }
    .auth-bar input {
      flex: 1; background: #0f0a1a; color: var(--text); border: 1px solid var(--border);
      padding: 8px 12px; border-radius: 6px; font-family: ui-monospace, monospace;
      font-size: 12px;
    }
    button {
      background: var(--accent); color: #1a1428; border: none; padding: 8px 14px;
      border-radius: 6px; cursor: pointer; font-weight: 700; font-size: 13px;
    }
    button.secondary { background: transparent; color: var(--muted); border: 1px solid var(--border); }
    button.danger { background: var(--danger); color: white; }
    button:disabled { opacity: 0.4; cursor: not-allowed; }
    .card {
      background: var(--card); border: 1px solid var(--border);
      border-radius: 12px; padding: 16px; margin-bottom: 12px;
    }
    .meta {
      display: flex; gap: 12px; font-size: 11px; color: var(--muted);
      margin-bottom: 8px; flex-wrap: wrap;
    }
    .meta .badge { background: #0f0a1a; padding: 2px 8px; border-radius: 4px; }
    .question {
      font-size: 15px; line-height: 1.45; margin: 8px 0;
      white-space: pre-wrap;
    }
    .ai-answer {
      font-size: 12px; color: var(--muted); background: #0f0a1a;
      padding: 8px 10px; border-radius: 6px; border-left: 3px solid #6a4ba8;
      margin: 8px 0; max-height: 90px; overflow: auto; white-space: pre-wrap;
    }
    .contact { font-size: 12px; color: var(--accent2); font-family: ui-monospace, monospace; }
    textarea {
      width: 100%; background: #0f0a1a; color: var(--text); border: 1px solid var(--border);
      padding: 10px; border-radius: 6px; font-family: inherit; font-size: 14px;
      min-height: 90px; resize: vertical; margin-top: 8px;
    }
    .actions { display: flex; gap: 8px; margin-top: 8px; flex-wrap: wrap; }
    .empty {
      text-align: center; color: var(--muted); padding: 40px 16px;
      font-style: italic;
    }
    .toast {
      position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
      background: var(--card); border: 1px solid var(--border); padding: 10px 16px;
      border-radius: 8px; box-shadow: 0 4px 16px rgba(0,0,0,0.4);
      font-size: 13px; opacity: 0; transition: opacity .2s;
      pointer-events: none; z-index: 100;
    }
    .toast.show { opacity: 1; }
    .toast.error { border-color: var(--danger); color: var(--danger); }
    .ai-toggle { font-size: 11px; color: var(--muted); cursor: pointer; user-select: none; }
  </style>
</head>
<body>
  <header>
    <h1>✨ Favilla coi superpoteri <small>— inbox amministratore</small></h1>
    <button class="secondary" id="refresh">↻ Aggiorna</button>
  </header>
  <div class="tabs">
    <button class="tab active" data-status="pending">In attesa</button>
    <button class="tab" data-status="answered">Risposte</button>
    <button class="tab" data-status="featured">Featured</button>
    <button class="tab" data-status="skipped">Skip</button>
  </div>
  <main>
    <div class="auth-bar">
      <input id="token" type="password" placeholder="Incolla qui ADMIN_TOKEN..." />
      <button id="save-token">Salva</button>
    </div>
    <div id="list"></div>
  </main>
  <div class="toast" id="toast"></div>
  <script>
    const TOKEN_KEY = 'favilla_admin_token';
    const tokenInput = document.getElementById('token');
    const list = document.getElementById('list');
    const toast = document.getElementById('toast');
    let currentStatus = 'pending';

    tokenInput.value = localStorage.getItem(TOKEN_KEY) || '';
    document.getElementById('save-token').onclick = () => {
      localStorage.setItem(TOKEN_KEY, tokenInput.value.trim());
      load();
    };
    document.getElementById('refresh').onclick = load;
    document.querySelectorAll('.tab').forEach(t => {
      t.onclick = () => {
        document.querySelectorAll('.tab').forEach(x => x.classList.remove('active'));
        t.classList.add('active');
        currentStatus = t.dataset.status;
        load();
      };
    });

    function showToast(msg, isError) {
      toast.textContent = msg;
      toast.className = 'toast show' + (isError ? ' error' : '');
      setTimeout(() => toast.className = 'toast' + (isError ? ' error' : ''), 2400);
    }

    function fmtDate(ts) {
      const d = new Date(ts);
      return d.toLocaleString('it-IT', { dateStyle: 'short', timeStyle: 'short' });
    }
    function escapeHtml(s) {
      return (s || '').replace(/[&<>"']/g, c => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
      }[c]));
    }

    async function load() {
      const token = tokenInput.value.trim();
      if (!token) {
        list.innerHTML = '<div class="empty">Incolla il token amministratore qui sopra per iniziare.</div>';
        return;
      }
      list.innerHTML = '<div class="empty">Carico...</div>';
      try {
        const res = await fetch('/admin/ask-real?status=' + currentStatus + '&limit=100', {
          headers: { 'authorization': 'Bearer ' + token },
        });
        if (res.status === 401) {
          list.innerHTML = '<div class="empty">Token non valido.</div>';
          return;
        }
        if (!res.ok) {
          list.innerHTML = '<div class="empty">Errore ' + res.status + '</div>';
          return;
        }
        const data = await res.json();
        renderItems(data.items || []);
      } catch (e) {
        list.innerHTML = '<div class="empty">Errore di rete: ' + e.message + '</div>';
      }
    }

    function renderItems(items) {
      if (items.length === 0) {
        list.innerHTML = '<div class="empty">Nessuna domanda in questo stato.</div>';
        return;
      }
      list.innerHTML = items.map(it => renderCard(it)).join('');
      items.forEach(it => wireCard(it));
    }

    function renderCard(it) {
      const aiHtml = it.ai_answer
        ? '<details><summary class="ai-toggle">Mostra risposta AI</summary><div class="ai-answer">' + escapeHtml(it.ai_answer) + '</div></details>'
        : '';
      const contactHtml = it.contact
        ? '<div class="contact">📩 ' + escapeHtml(it.contact) + '</div>'
        : '';
      const isPending = it.status === 'pending';
      const existingAnswer = it.favilla_answer ? escapeHtml(it.favilla_answer) : '';
      const formHtml = isPending
        ? '<textarea id="answer-' + it.id + '" placeholder="Scrivi la tua risposta personale..."></textarea>' +
          '<div class="actions">' +
            '<button data-act="answer" data-id="' + it.id + '">✨ Rispondi</button>' +
            '<button class="secondary" data-act="featured" data-id="' + it.id + '">⭐ Featured (no reply)</button>' +
            '<button class="secondary" data-act="skipped" data-id="' + it.id + '">Skip</button>' +
          '</div>'
        : (existingAnswer ? '<div class="ai-answer" style="border-left-color: var(--accent);"><strong>Risposta tua:</strong>\\n' + existingAnswer + '</div>' : '');
      return '<div class="card" id="card-' + it.id + '">' +
        '<div class="meta">' +
          '<span class="badge">' + it.lang + '</span>' +
          '<span>' + fmtDate(it.created_at) + '</span>' +
          (it.answered_at ? '<span>↩ ' + fmtDate(it.answered_at) + '</span>' : '') +
        '</div>' +
        contactHtml +
        '<div class="question">' + escapeHtml(it.question) + '</div>' +
        aiHtml +
        formHtml +
      '</div>';
    }

    function wireCard(it) {
      const card = document.getElementById('card-' + it.id);
      if (!card) return;
      card.querySelectorAll('button[data-act]').forEach(btn => {
        btn.onclick = () => submitAnswer(it.id, btn.dataset.act);
      });
    }

    async function submitAnswer(id, action) {
      const token = tokenInput.value.trim();
      const ta = document.getElementById('answer-' + id);
      const answer = ta ? ta.value.trim() : '';
      if (action === 'answer' && !answer) {
        showToast('Scrivi una risposta prima di inviare.', true);
        return;
      }
      const body = {
        status: action === 'answer' ? 'answered' : action,
        answer: action === 'answer' ? answer : undefined,
      };
      try {
        const res = await fetch('/admin/ask-real/' + id, {
          method: 'POST',
          headers: { 'authorization': 'Bearer ' + token, 'content-type': 'application/json' },
          body: JSON.stringify(body),
        });
        if (!res.ok) {
          showToast('Errore ' + res.status, true);
          return;
        }
        showToast(action === 'answer' ? '✨ Risposta inviata!' : 'Aggiornato.');
        load();
      } catch (e) {
        showToast('Errore: ' + e.message, true);
      }
    }

    if (tokenInput.value) load();
  </script>
</body>
</html>`;
