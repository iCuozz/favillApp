# Skill: git-sync

## Scopo
Committare e pushare tutte le modifiche al repository remoto (`origin/main`).
Da invocare alla fine di ogni sessione di lavoro o dopo ogni cambiamento significativo.

---

## Quando invocare questa skill

Invocare **sempre** al termine di:
- creazione o modifica di un episodio JSON
- aggiornamento di documenti Obsidian (Mappa, Bible, Grafo, Idee)
- modifiche al codice Flutter (`lib/`, `assets/`)
- aggiornamento di tool o skill

> **Regola:** se hai modificato qualcosa, esegui git-sync prima di chiudere la sessione.

---

## Procedura

### 1. Verifica stato
```bash
cd /Users/andreacuozzo/Projects/favillApp
git status
```
Se non ci sono modifiche → fine, niente da committare.

### 2. Staging
```bash
git add -A
```

### 3. Messaggio di commit
Il messaggio deve essere **descrittivo e strutturato**:

```
<tipo>: <breve descrizione>

- dettaglio 1
- dettaglio 2
- ...

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

**Tipi:**
| Tipo | Quando |
|------|--------|
| `feat` | Nuova funzionalità (nuovo episodio, nuova meccanica) |
| `fix` | Correzione bug (JSON invalido, unlock sbagliato) |
| `docs` | Solo aggiornamenti documenti Obsidian/Bible/Mappa |
| `refactor` | Riscrittura codice senza cambi funzionali |
| `chore` | Skill, tool, configurazione |

**Esempi:**
```
feat: EP4 La Spesa del Sabato — Lex il sabotatore, Carmela seed

- Add s1_spesa_sabato.json con branch_tardi e branch_prima
- Update world_map.json: EP4 aggiunto a supermercato
- Update Mappa Narrativa + Grafo Narrativo con EP4
```

```
fix: world_map.json missing comma + scuola circular unlock
```

```
docs: update Mappa Narrativa rev.4 con EP4 narrative emergente
```

### 4. Commit & push
```bash
git commit -m "<messaggio>"
git push origin main
```

### 5. Verifica
```bash
git status
# atteso: "nothing to commit, working tree clean"
git log --oneline -3
# mostra gli ultimi 3 commit per conferma
```

---

## Note importanti

- **Branch:** lavorare sempre su `main` (progetto personale, nessun PR flow necessario per ora)
- **Symlink:** i file `docs/` sono symlink — git li traccia correttamente come symlink, non come copie. Non copiare mai il contenuto.
- **File Obsidian:** i `.canvas` e `.md` in `docs/` vengono committati come symlink → il contenuto reale è in iCloud e NON nel repo. Questo è corretto: il repo traccia la struttura, iCloud traccia il contenuto Obsidian.
- **Non committare mai:** credenziali, `.env`, file temporanei, output di build (`build/`)
