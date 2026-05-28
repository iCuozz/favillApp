---
name: narrative-flow-checker
description: >
  Verifica la coerenza narrativa di tutti gli episodi di Favilla Blaze.
  Controlla riferimenti a branch rotti, branch irraggiungibili, e
  inconsistenze cross-episodio dove la stat_entry di un episodio non rispecchia
  le scelte fatte in un episodio precedente (es. posizione camicia bruciata).
  Da eseguire ogni volta che si aggiunge o modifica un episodio.
---

# Narrative Flow Checker — FavillApp

Verifica la coerenza narrativa di tutti gli episodi simulando ogni possibile
percorso statistico e controllando che le condizioni `stat_entry` siano
sempre coerenti con le scelte pregresse del giocatore.

## Quando usarla

- **Dopo aver aggiunto un nuovo episodio** (aggiornare anche `EPISODE_ORDER` nello script)
- Dopo aver modificato un `stat_entry` in qualsiasi episodio JSON
- Dopo aver aggiunto o modificato un branch che influenza stat usate da episodi successivi
- Dopo aver aggiunto una nuova regola di coerenza cross-episodio

## Esecuzione

```bash
# Controllo completo di tutti gli episodi
node .github/skills/narrative-flow-checker/scripts/check-narrative-flow.cjs .

# Solo un episodio specifico (controlli strutturali)
node .github/skills/narrative-flow-checker/scripts/check-narrative-flow.cjs . --episode s1_ritorno_casa

# Mostra tutti i 256+ percorsi simulati
node .github/skills/narrative-flow-checker/scripts/check-narrative-flow.cjs . --all-paths
```

## Cosa controlla

### 1. Controlli strutturali (per ogni episodio)
| Check | Cosa verifica |
|---|---|
| goto_branch risolto | Ogni `goto_branch` punta a un branch esistente nello stesso episodio |
| Branch raggiungibili | Ogni branch in `branches` è puntato da almeno un `goto_branch` |

### 2. Copertura stat_entry
Elenca tutte le regole `stat_entry` attive con le loro condizioni, incluse le regole `all_of`.

### 3. Simulazione percorsi cumulativi
Simula tutti i percorsi possibili attraverso tutti gli episodi in sequenza,
partendo dalle stat iniziali (`segreto=50, legame=50, scintille=50, resistenza=50`).
Per ogni percorso, registra quale `entryBranch` viene attivato in ogni episodio.

### 4. Regole di coerenza cross-episodio
Definite nello script in `CROSS_EPISODE_RULES`. Ogni regola riceve la storia
delle scelte di un percorso e verifica che l'instradamento sia coerente.

**Regola attuale:**
- **EP3 shirt location**: `intro_vestiti_bruciati*` deve corrispondere alla scelta
  fatta in EP2 (`bagno` → camicia in zaino / `finge_niente` → camicia addosso)

## Aggiungere un nuovo episodio

1. Aggiungere il percorso del JSON in `EPISODE_ORDER` nello script:
   ```js
   const EPISODE_ORDER = [
     'quests/prologo.json',
     'quests/s1/s1_mattina_dopo.json',
     // ...
     'quests/s2/s2_nuovo_episodio.json',  // ← aggiungere qui
   ];
   ```

2. Se il nuovo episodio ha una `stat_entry` che dipende da una scelta specifica
   di un episodio precedente, aggiungere una regola in `CROSS_EPISODE_RULES`:
   ```js
   {
     name: 'Nome della regola',
     description: 'Descrizione breve',
     check(episodeChoices) {
       const epPrev = episodeChoices.find(e => e.episode === 'id_episodio_precedente');
       const epCurr = episodeChoices.find(e => e.episode === 'id_episodio_attuale');
       if (!epPrev || !epCurr) return null;

       const choiceLabel = epPrev.choiceLabel || '';
       const entry = epCurr.entryBranch;
       if (!entry) return null;

       if (choiceLabel.includes('scelta_a') && entry === 'branch_sbagliato') {
         return `Descrizione dell'inconsistenza`;
       }
       return null; // tutto ok
     },
   },
   ```

3. Eseguire lo script e verificare ✅

## Perché il sistema stat-proxy può avere inconsistenze

Il motore usa le stat cumulative come proxy per le scelte passate.
Questo funziona bene nella maggior parte dei percorsi, ma può fallire
quando una stat viene influenzata da più scelte in direzioni opposte.

**Esempio (risolto in EP3):**
La `stat_entry` di `s1_ritorno_casa` prova a dedurre se la camicia è
addosso a Favilla (scelta `finge_niente` in EP2) o nello zaino (scelta `bagno`).
La `resistenza` è il proxy: alta = finge, bassa = bagno. Ma il caffè (EP1)
abbassa la `resistenza` di 15, facendo fallire il proxy su percorsi `caffè+finge`.

**Soluzione adottata:** aggiunta una terza regola `all_of: [segreto<40, resistenza<50]`
che cattura esattamente i percorsi `caffè+finge` (segreto molto basso, resistenza
abbassata dal caffè e non recuperata dal bagno). La regola è matematicamente
univoca perché il `bagno` aggiunge +15 a segreto, portandolo sempre ≥40.

**Soluzione architettuale futura:** aggiungere un sistema di `worldFlags`
(boolean) a `GameState` per tracciare scelte specifiche senza perdita di informazione.
