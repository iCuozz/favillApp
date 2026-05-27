#!/usr/bin/env python3
"""
validate_narrative.py — Favilla Blaze
======================================
Esegui dopo ogni nuovo episodio per verificare:
  1. Tutti i JSON delle quest sono validi
  2. Nessun percorso porta una stat sotto il floor
  3. Ogni scelta ha almeno un'opzione sicura per tutte le possibili stat in ingresso
  4. Riepilogo worst-case cumulativo episodio per episodio

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

# Episodi in ordine narrativo. Aggiungere nuovi episodi qui.
EPISODES = [
    'assets/data/quests/prologo.json',
    'assets/data/quests/s1/s1_mattina_dopo.json',
    'assets/data/quests/s1/s1_scuola_1.json',
    'assets/data/quests/s1/s1_ritorno_casa.json',
    'assets/data/quests/s1/s1_spesa_sabato.json',
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

    # 4. Riepilogo
    print("\n╔══════════════════════════════════════════════════════════╗")
    if all_ok:
        print("║  ✅  VALIDAZIONE PASSATA — tutti i floor sono rispettati ║")
    else:
        print("║  🔴  ERRORI TROVATI — correggere prima di pubblicare     ║")
    print("╚══════════════════════════════════════════════════════════╝\n")
    sys.exit(0 if all_ok else 1)

if __name__ == '__main__':
    main()
