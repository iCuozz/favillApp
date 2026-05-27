# Skill: narrative-updater

## Scopo
Mantiene sincronizzati tutti i documenti narrativi del progetto (JSON + Obsidian).
Da invocare ogni volta che si modifica narrazione, stat, personaggi o regole.

---

## Vault Obsidian
`~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Favilla Blaze/`

> **Fonte di verità unica:** i file in `docs/` del progetto sono **symlink** ai file Obsidian.
> Non esistono due copie — è sempre lo stesso file. iCloud sincronizza le modifiche da iPhone automaticamente.
> Non copiare mai manualmente: modificare direttamente il file (da Obsidian o da editor) e il cambiamento è subito visibile in entrambi i posti.

### Documenti nel vault — quando aggiornarli

| File Obsidian | Symlink in `docs/` | Contenuto | Aggiornare quando… |
|---|---|---|---|
| `NARRATIVE_BIBLE.md` | `docs/NARRATIVE_BIBLE.md` | Capisaldi: mondo, personaggi, stat, lore, principi narrativi, regole su pietra | Cambia un personaggio, una regola, il sistema stat, il lore dei poteri, i principi narrativi |
| `Mappa Narrativa.md` | `docs/MAPPA_NARRATIVA.md` | Timeline episodi, diagrammi Mermaid, traccia stat cumulativi | Cambia `stat_effects`, branch, scelte, `stat_entry`, testo chiave di una scena; nuovo episodio |
| `Grafo Narrativo.canvas` | `docs/GRAFO_NARRATIVO.canvas` | Grafo visuale interattivo (Obsidian Canvas) | **Stesse occasioni di `Mappa Narrativa.md`** — i due file devono essere sempre sincronizzati |
| `Idee & Direzioni Future.md` | `docs/IDEE_FUTURE.md` | Idee episodi futuri, archi narrativi, meccaniche in design | L'utente descrive un'idea futura; si decide una direzione narrativa per S2/S3 |

> **Regola base:** dopo ogni cambio narrativo, aggiorna TUTTI i documenti pertinenti nella stessa sessione. Non lasciare mai un documento indietro.

---

## Come aggiornare `Narrative Bible.md`

1. Leggi la versione attuale
2. Modifica solo le sezioni impattate (non riscrivere tutto)
3. La Bible non fa mai riferimento a singoli episodi — solo a regole, personaggi e principi
4. Aggiorna anche `docs/NARRATIVE_BIBLE.md` nel progetto (i due file devono essere identici)

---

## Come aggiornare `Mappa Narrativa.md`

1. Leggi i JSON degli episodi coinvolti per avere i dati precisi
2. Aggiorna i diagrammi Mermaid con branch/scelte/stat corretti
3. Aggiorna la tabella stat cumulativi
4. Aggiorna le note/callout se la meccanica è cambiata
5. Incrementa il numero di revisione in testa al file (es. `rev.4`)

### Struttura diagrammi Mermaid
```
flowchart TD
    Pn["📄 pN · descrizione breve\n(personaggi)"]
    CHn{{"❓ scelta · prompt"}}
    Bn["🌿 branch_id\ntesto breve\n+stat=val / -stat=val"]
    ENTRY["🟠 intro_branch ·prepend· o ·replace·\ntesto breve"]
    EP["🔚 Epilogo · ..."]
    ENTRY_COND{{"🔀 STAT ENTRY\nstat condizione?"}}
```

Formato stat_effects: `+stat=val` / `-stat=val` separati da ` / `.

---

## Come aggiornare `Grafo Narrativo.canvas`

Il `.canvas` è JSON con `nodes` e `edges`. Genera sempre il file completo via script Python — non modificare a mano.

### Colori nodi
| Colore | Codice | Uso |
|--------|--------|-----|
| Viola  | `"6"`  | Episodio principale |
| Giallo | `"3"`  | Nodo scelta (❓) |
| Verde  | `"4"`  | Branch sicuro (+Segreto / outcome positivo) |
| Cyan   | `"5"`  | Branch neutro / epilogo / fine episodio |
| Arancio| `"2"`  | STAT ENTRY / condizionale |
| Rosso  | `"1"`  | Branch rischioso (-Segreto / outcome negativo) |

### Layout coordinate (riferimento per nuovi episodi)
- Offset X per episodio: `+1400px` rispetto al precedente (EP4 parte da ~7800)
- Branch alto: `y = -220` dal nodo scelta · Branch basso: `y = +160`
- STAT ENTRY: `y = -280/-390` (sopra il nodo episodio)
- Distanza episodio → scelta: `+360-400px` X · Distanza scelta → branch: `+400px` X

### Formato testo nodi
```
## 📖 EP4 · Titolo\n*Sottotitolo.*              ← episodio
### ❓ Prompt scelta\n*Contesto.*                ← scelta
### 🌿 branch_id\n*Testo.*\n`+15 💞 Legame`     ← branch
### 🟠 STAT ENTRY\n`stat < val`\n→ **branch**   ← entry
```

---

## ✅ Validazione obbligatoria dopo ogni nuovo episodio

```bash
python3 tools/validate_narrative.py
```

Verifica: JSON validi · floor mai violati · almeno un'opzione sicura per ogni scelta · worst-case cumulativo.
**Aggiungere ogni nuovo episodio alla lista `EPISODES`** in `validate_narrative.py`.

Output atteso: `✅ VALIDAZIONE PASSATA` — se compare `🔴` correggere i `stat_effects` prima di procedere.

---

## 🪨 REGOLE SU PIETRA (non negoziabili)

### Stat floor
Definiti in `StatKey.minValues` (`lib/models/game_state.dart`). Il motore nasconde automaticamente le scelte che li violano.

| Stat | Floor | Motivazione |
|------|-------|-------------|
| 🔒 Segreto | **5** | Sempre positivo — storia sempre leggibile |
| 💞 Legame | 0 | — |
| ✨ Scintille | 0 | — |
| 💪 Resistenza | **1** | Nessun episodio di crollo è ancora scritto |

> **Regola d'authoring:** ogni scelta deve avere SEMPRE almeno un'opzione sicura per tutti i floor.

### Mallow e il segreto
- Mallow non scopre il segreto di Favilla **prima delle stagioni finali** (non S2, non S3 iniziale)
- Non esistono branch che rendono possibile la rivelazione nelle stagioni iniziali
- Flag `mallow_sa` riservato per episodio dedicato in stagione avanzata

### Lex — fil rouge comico permanente
- Lex tenta sempre di raccontare il segreto a Mallow man mano che cresce
- Mallow non capisce mai — questo non va risolto prima della stagione finale
- Ogni episodio può avere un momento Lex-tenta-di-rivelare come beat comico/emotivo

### Regole generali
- Non inventare testi narrativi — usare solo quelli dai JSON o concordati con l'utente
- Non modificare i JSON da questa skill — solo leggere e documentare
- Episodi non ancora implementati come JSON → segnalare come `(pianificato)` nella mappa
- `docs/NARRATIVE_BIBLE.md` e `Narrative Bible.md` in Obsidian sono **lo stesso file** (symlink) — non servono aggiornamenti manuali incrociati

