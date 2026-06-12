#!/usr/bin/env python3
"""
validate_narrative.py — Favilla Blaze
======================================
Esegui dopo ogni nuovo episodio per verificare:
  1. Tutti i JSON delle quest sono validi
  2. Nessun percorso porta una stat sotto il floor
  3. Ogni scelta ha almeno un'opzione sicura per tutte le possibili stat in ingresso
  4. Riepilogo worst-case cumulativo episodio per episodio
  5. Soglie narrative: quando una stat incrocia un valore critico, la storia deve cambiare

Uso:
  python3 tools/validate_narrative.py

Aggiungere i nuovi episodi alla lista EPISODES in ordine narrativo.
"""

import json
import itertools
import os
import sys
from pathlib import Path

# ─── Configurazione ───────────────────────────────────────────────────────────

FLOORS = {
    'segreto':   5,
    'legame':    0,
    'scintille': 0,
    'resistenza': 1,
}

STAT_CAPS = {k: 100 for k in FLOORS}
STAT_INITIAL = {k: 50 for k in FLOORS}

# Soglie narrative per ciascuna stat.
# direction: 'lt' = pericolo quando la stat scende sotto questo valore
#            'gte' = bonus quando la stat sale sopra/su questo valore
# Il validatore segue il percorso peggiore per 'lt' e il migliore per 'gte'.
THRESHOLDS = {
    'segreto': [
        {'value': 50, 'label': '🔒 Cauto',     'direction': 'lt', 'impact': 'EP3 intro alternativa (già implementata)'},
        {'value': 30, 'label': '🔒 Pericolo',   'direction': 'lt', 'impact': 'Mallow/Mondo iniziano a sospettare — dialoghi diversi, opzioni filtrate'},
        {'value': 15, 'label': '🔒 Sulla corda','direction': 'lt', 'impact': 'Il segreto sta per crollare — i personaggi reagiscono, la Corvi indaga'},
        {'value': 8,  'label': '🔒 Rivelazione', 'direction': 'lt', 'impact': 'Imminente scoperta — tono e scelte radicalmente diversi'},
    ],
    'legame': [
        {'value': 40, 'label': '💞 Solido',     'direction': 'gte','impact': 'Sblocca "Cena di Famiglia". Mallow più presente.'},
        {'value': 25, 'label': '💞 Distante',   'direction': 'lt', 'impact': 'Mallow nota la distanza. Dialoghi più guardinghi.'},
        {'value': 10, 'label': '💞 Crisi',      'direction': 'lt', 'impact': 'Crisi familiare. Lex lo sente. Scene molto tese.'},
    ],
    'scintille': [
        {'value': 45, 'label': '✨ Kryptonite',  'direction': 'lt', 'impact': 'Minigame più difficili (già implementato). Intro EP2 se <45.'},
        {'value': 10, 'label': '✨ Spenta',      'direction': 'lt', 'impact': 'Trasformazione impossibile. Storia alternativa obbligatoria.'},
    ],
    'resistenza': [
        {'value': 40, 'label': '💪 Affaticata',  'direction': 'lt', 'impact': 'Sblocca Palestra (già implementato). Intro stanchezza.'},
        {'value': 25, 'label': '💪 Esausta',     'direction': 'lt', 'impact': 'Favilla collassa? Mallow la vede crollare. Toni più cupi.'},
        {'value': 10, 'label': '💪 Limite',      'direction': 'lt', 'impact': 'Rischi fisici reali. Scelte drastiche obbligatorie.'},
    ],
}

# Episodi in ordine narrativo. Aggiungere nuovi episodi qui.
# Nota: EP6 (s1_mare) e EP6alt (s1_centro_commerciale) sono mutuamente esclusivi
# nella giocabilità (condizione su resistenza). La worst-case simulation li tratta
# entrambi in sequenza, il che non è possibile in-game — valutare manualmente.
EPISODES = [
    'assets/data/quests/prologo.json',
    'assets/data/quests/s1/s1_mattina_dopo.json',
    'assets/data/quests/s1/s1_scuola_1.json',
    'assets/data/quests/s1/s1_ritorno_casa.json',
    'assets/data/quests/s1/s1_spesa_sabato.json',
    'assets/data/quests/s1/s1_domenica_parco.json',
    'assets/data/quests/s1/s1_mare.json',
    'assets/data/quests/s1/s1_centro_commerciale.json',
    'assets/data/quests/s1/s1_lunedi_asilo.json',
    'assets/data/quests/s1/s1_palestra.json',
    'assets/data/quests/s1/s1_allagamento.json',
    'assets/data/quests/s1/s1_prima_conseguenza.json',
    'assets/data/quests/s1/s1_comare.json',
    'assets/data/quests/s1/s1_cena_famiglia.json',
]

# ─── Helpers ──────────────────────────────────────────────────────────────────

def clamp_stats(stats: dict) -> dict:
    return {
        k: max(FLOORS.get(k, 0), min(STAT_CAPS.get(k, 100), v))
        for k, v in stats.items()
    }

def apply_effects(stats: dict, effects: dict) -> dict:
    result = dict(stats)
    for k, v in effects.items():
        result[k] = result.get(k, 50) + v
    return clamp_stats(result)

def would_violate_floor(stats: dict, effects: dict) -> bool:
    for k, v in effects.items():
        if stats.get(k, 50) + v < FLOORS.get(k, 0):
            return True
    return False

def get_choices_from_quest(data: dict) -> list:
    """Estrae tutte le scelte (contesto, choice_obj) da un quest JSON."""
    choices = []

    def scan_pages(pages, ctx):
        for p in pages:
            c = p.get('choice')
            if c:
                choices.append((ctx, c))

    scan_pages(data.get('pages', []), 'main')
    for bname, b in data.get('branches', {}).items():
        scan_pages(b.get('pages', []), f'branch:{bname}')
    ep = data.get('epilogue', {})
    scan_pages(ep.get('pages', []), 'epilogue')
    return choices

def get_stat_entries(data: dict) -> list:
    return data.get('stat_entry', [])

# ─── Validazione singolo episodio ─────────────────────────────────────────────

def validate_episode(path: str, all_reachable_stats: list[dict]) -> tuple[bool, list[dict]]:
    """
    Valida un episodio rispetto a tutti gli stati in ingresso possibili.
    Restituisce (ok, stati_in_uscita_possibili).
    """
    ok = True
    data = json.load(open(path))
    ep_id = data.get('id', path)
    choices = get_choices_from_quest(data)
    stat_entries = get_stat_entries(data)

    print(f"\n{'═'*60}")
    print(f"  {ep_id}")
    print(f"{'═'*60}")
    print(f"  Scelte trovate: {len(choices)}")
    print(f"  Stat entry: {len(stat_entries)}")

    # Per ogni stato in ingresso, simula tutte le scelte
    exit_stats = set()  # Set di tuple per deduplicare

    for in_stats in all_reachable_stats:
        for ctx, choice in choices:
            safe_opts = [
                o for o in choice.get('options', [])
                if not would_violate_floor(in_stats, o.get('stat_effects', {}))
            ]
            all_opts = choice.get('options', [])

            if not safe_opts:
                print(f"\n  🔴 ERRORE AUTHORING [{ctx}] \"{choice.get('prompt','')[:55]}\"")
                print(f"     Tutte le {len(all_opts)} opzioni violano i floor per stato: {in_stats}")
                print(f"     Il safety net del motore mostrerà tutte le opzioni — da correggere!")
                ok = False
            else:
                filtered = len(all_opts) - len(safe_opts)
                if filtered > 0:
                    print(f"\n  🟡 [{ctx}] \"{choice.get('prompt','')[:55]}\"")
                    print(f"     {filtered}/{len(all_opts)} opzione/i filtrata/e per stat: {in_stats}")
                    for o in all_opts:
                        eff = o.get('stat_effects', {})
                        viol = would_violate_floor(in_stats, eff)
                        marker = "🚫 FILTRATO" if viol else "✅"
                        print(f"     {marker} [{o['label'][:45]}] {eff}")

        # Calcola tutti gli stati di uscita per questo ingresso
        # (prodotto cartesiano di tutte le scelte)
        out_for_this = [dict(in_stats)]
        for ctx, choice in choices:
            safe_opts = [
                o for o in choice.get('options', [])
                if not would_violate_floor(in_stats, o.get('stat_effects', {}))
            ] or choice.get('options', [])  # safety net

            new_out = []
            for current in out_for_this:
                for o in safe_opts:
                    new_out.append(apply_effects(current, o.get('stat_effects', {})))
            if new_out:
                out_for_this = new_out

        for s in out_for_this:
            exit_stats.add(tuple(sorted(s.items())))

    exit_stats_list = [dict(t) for t in exit_stats]
    return ok, exit_stats_list

# ─── Worst-case singola dimensione ────────────────────────────────────────────

def simulate_worst_case_for_stat(episodes: list, target_stat: str) -> None:
    """Simula il percorso che minimizza target_stat attraverso tutti gli episodi."""
    print(f"\n{'─'*60}")
    print(f"  WORST-CASE per '{target_stat}' (scelta sempre peggiore)")
    print(f"{'─'*60}")
    stats = dict(STAT_INITIAL)
    print(f"  Start: {stats}")

    for path in episodes:
        data = json.load(open(path))
        ep_id = data.get('id', path)
        choices = get_choices_from_quest(data)

        for ctx, choice in choices:
            safe_opts = [
                o for o in choice.get('options', [])
                if not would_violate_floor(stats, o.get('stat_effects', {}))
            ] or choice.get('options', [])

            # Scegli l'opzione che minimizza target_stat
            worst = min(safe_opts, key=lambda o: o.get('stat_effects', {}).get(target_stat, 0))
            eff = worst.get('stat_effects', {})
            stats = apply_effects(stats, eff)
            print(f"  [{ep_id}·{ctx}] \"{worst['label'][:40]}\" {eff}")
            print(f"    → {target_stat}={stats[target_stat]}  resistenza={stats['resistenza']}")

    print(f"\n  Stat finali worst-case: {stats}")
    for k, floor in FLOORS.items():
        if stats[k] < floor:
            print(f"  🔴 VIOLAZIONE FLOOR: {k}={stats[k]} < floor={floor}")
        elif stats[k] == floor:
            print(f"  🟡 Al floor: {k}={stats[k]} (OK — engine protegge gli episodi successivi)")
        else:
            print(f"  ✅ {k}={stats[k]} (floor={floor})")

# ─── Soglie narrative per-stat ────────────────────────────────────────

def _choose_extreme(safe_opts: list, stat_name: str, maximize: bool):
    """Sceglie l'opzione che minimizza o massimizza stat_name tra quelle safe."""
    if maximize:
        return max(safe_opts, key=lambda o: o.get('stat_effects', {}).get(stat_name, 0))
    return min(safe_opts, key=lambda o: o.get('stat_effects', {}).get(stat_name, 0))

def simulate_thresholds(episodes: list) -> None:
    """Analizza quando ogni percorso incrocia le soglie narrative di ogni stat."""
    print(f"\n{'─'*60}")
    print(f"  SOGLIE NARRATIVE — per ciascuna stat")
    print(f"{'─'*60}\n")

    for stat_name, thresholds in THRESHOLDS.items():
        print(f"  [{stat_name.upper()}]")
        lt_thresholds = [t for t in thresholds if t['direction'] == 'lt']
        gte_thresholds = [t for t in thresholds if t['direction'] == 'gte']

        # Per soglie 'lt' (pericolo): segue il percorso peggiore (minimizza stat)
        if lt_thresholds:
            stats = dict(STAT_INITIAL)
            unresolved = sorted(lt_thresholds, key=lambda t: t['value'])
            for path in episodes:
                data = json.load(open(path))
                ep_id = data.get('id', path)
                for ctx, choice in get_choices_from_quest(data):
                    safe_opts = [
                        o for o in choice.get('options', [])
                        if not would_violate_floor(stats, o.get('stat_effects', {}))
                    ] or choice.get('options', [])
                    opt = _choose_extreme(safe_opts, stat_name, maximize=False)
                    stats = apply_effects(stats, opt.get('stat_effects', {}))

                still_unresolved = []
                for t in unresolved:
                    if stats[stat_name] <= t['value']:
                        print(f"    ⚠️  {t['label']} ({stat_name} ≤ {t['value']}) → {ep_id}")
                        print(f"         Impatto: {t['impact']}")
                    else:
                        still_unresolved.append(t)
                unresolved = still_unresolved

            if not unresolved:
                print(f"    ✅ Soglie 'lt' superate. Min: {stats[stat_name]}")

        # Per soglie 'gte' (bonus): segue il percorso migliore (massimizza stat)
        if gte_thresholds:
            stats = dict(STAT_INITIAL)
            unresolved = sorted(gte_thresholds, key=lambda t: t['value'], reverse=True)
            for path in episodes:
                data = json.load(open(path))
                ep_id = data.get('id', path)
                for ctx, choice in get_choices_from_quest(data):
                    safe_opts = [
                        o for o in choice.get('options', [])
                        if not would_violate_floor(stats, o.get('stat_effects', {}))
                    ] or choice.get('options', [])
                    opt = _choose_extreme(safe_opts, stat_name, maximize=True)
                    stats = apply_effects(stats, opt.get('stat_effects', {}))

                still_unresolved = []
                for t in unresolved:
                    if stats[stat_name] >= t['value']:
                        print(f"    ✅ {t['label']} ({stat_name} ≥ {t['value']}) → {ep_id}")
                        print(f"         Impatto: {t['impact']}")
                    else:
                        still_unresolved.append(t)
                unresolved = still_unresolved

            if unresolved:
                vals = [t['value'] for t in unresolved]
                print(f"    ⚠️  Soglie 'gte' non raggiunte: {vals} (max: {stats[stat_name]})")
        print()

    # --- What-if: scenario ipotetico ---
    print(f"  ─── What-if: 'e se aggiungessimo una scelta che scaria -X?' ───")
    for stat_name in ['scintille', 'segreto', 'resistenza']:
        lt_vals = [t['value'] for t in THRESHOLDS[stat_name] if t['direction'] == 'lt' and t['value'] > 5]
        if not lt_vals:
            continue
        next_soglia = min(lt_vals)
        margin = 50 - next_soglia
        print(f"    [{stat_name}] prossima soglia a {next_soglia} — margine {margin}pt da inizio")
        worst_val = 0
        for path in episodes:
            data = json.load(open(path))
            for ctx, choice in get_choices_from_quest(data):
                for opt in choice.get('options', []):
                    v = opt.get('stat_effects', {}).get(stat_name, 0)
                    if v < 0:
                        worst_val = min(worst_val, v)
        if worst_val < 0:
            steps = (next_soglia - 50) // worst_val if worst_val != 0 else 999
            print(f"      Peggior singolo effetto: {worst_val} → ~{max(1, abs(steps))} scelte per raggiungerla")


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    root = Path(__file__).parent.parent
    os.chdir(root)

    print("╔══════════════════════════════════════════════════════════╗")
    print("║   FAVILLA BLAZE — Validazione Narrativa & Stat Floors   ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print(f"\nFloor: {FLOORS}")
    print(f"Episodi da validare: {len(EPISODES)}\n")

    # 1. Validità JSON
    print("─── 1. Validità JSON ───────────────────────────────────────")
    for path in EPISODES:
        try:
            json.load(open(path))
            print(f"  ✅ {path}")
        except Exception as e:
            print(f"  🔴 {path}: {e}")

    # 2. Validazione scelte episodio per episodio
    print("\n─── 2. Validazione scelte & floor ──────────────────────────")
    all_ok = True
    reachable = [dict(STAT_INITIAL)]

    for path in EPISODES:
        ok, reachable = validate_episode(path, reachable)
        if not ok:
            all_ok = False

    # 3. Worst-case per Segreto e Resistenza
    print("\n─── 3. Simulazione worst-case ──────────────────────────────")
    simulate_worst_case_for_stat(EPISODES, 'segreto')
    simulate_worst_case_for_stat(EPISODES, 'resistenza')

    # 4. Soglie narrative per-stat (quando la storia deve cambiare)
    print("\n─── 4. Analisi soglie narrative ────────────────────────")
    simulate_thresholds(EPISODES)

    # 5. Riepilogo soglie narrative (implementate vs da implementare)
    print("\n─── 5. Riepilogo implementazione soglie ────────────────")
    print(f"{'Soglia':<30} {'Stato':<18} {'Episodio':<20} {'Note'}")
    print(f"{'─'*85}")

    # Mappa delle soglie già implementate nel motore
    implemented = {
        'segreto': {50: 'EP3 (stat_entry)', 30: 'EP2 (intro_segreto_pericolo)', 15: 'EP5 (intro_segreto_corda)', 8: '—'},
        'legame': {40: 'Backlog (Cena di Famiglia)', 25: 'EP6alt (intro_legame_distante)', 10: '—'},
        'scintille': {45: 'EP2 (stat_entry) + minigame', 10: 'main.dart (rincorsa)'},
        'resistenza': {40: 'EP7.5 (stat unlock)', 25: 'EP4 (intro_esausta)', 10: 'EP5 (intro_resistenza_limite)'},
    }

    # Trova la prima volta che ogni soglia viene incrociata
    crossed_once = set()
    for stat_name, thresholds in THRESHOLDS.items():
        imp = implemented.get(stat_name, {})
        for t in thresholds:
            key = (stat_name, t['value'])
            if key in crossed_once:
                continue
            stats = dict(STAT_INITIAL)
            found_ep = None
            for path in EPISODES:
                if found_ep:
                    break
                data = json.load(open(path))
                ep_id = data.get('id', path)
                choices = get_choices_from_quest(data)
                for ctx, choice in choices:
                    safe_opts = [
                        o for o in choice.get('options', [])
                        if not would_violate_floor(stats, o.get('stat_effects', {}))
                    ] or choice.get('options', [])
                    maximize = t['direction'] == 'gte'
                    opt = _choose_extreme(safe_opts, stat_name, maximize=maximize)
                    stats = apply_effects(stats, opt.get('stat_effects', {}))

                # Verifica soglia
                if t['direction'] == 'lt' and stats[stat_name] <= t['value']:
                    found_ep = ep_id
                elif t['direction'] == 'gte' and stats[stat_name] >= t['value']:
                    found_ep = ep_id
            if found_ep:
                crossed_once.add(key)
                status = imp.get(t['value'], '—')
                stato = '✅' if status != '—' else '❌'
                note = status if status != '—' else 'Narrativa da scrivere'
                label = f"{t['label']} ({stat_name}{'≤' if t['direction']=='lt' else '≥'}{t['value']})"
                print(f"{label:<30} {stato:<5} {found_ep:<25} {note}")

    print(f"\n{'─'*60}")
    print(f"  Legenda: ✅ = già gestito dal motore | ❌ = serve narrativa alternativa")
    print(f"{'─'*60}")

    # 6. Riepilogo finale
    print("\n╔══════════════════════════════════════════════════════════╗")
    if all_ok:
        print("║  ✅  VALIDAZIONE PASSATA — tutti i floor sono rispettati ║")
    else:
        print("║  🔴  ERRORI TROVATI — correggere prima di pubblicare     ║")
    print("╚══════════════════════════════════════════════════════════╝\n")
    sys.exit(0 if all_ok else 1)

if __name__ == '__main__':
    main()
