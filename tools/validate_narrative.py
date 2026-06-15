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
        {'value': 70, 'label': '💞 Fortissimo',  'direction': 'gte','impact': 'Sblocca EP9c "Cena di Famiglia".'},
        {'value': 40, 'label': '💞 Solido',     'direction': 'gte','impact': 'Sblocca "Cena di Famiglia". Mallow più presente.'},
        {'value': 40, 'label': '💞 Distante',   'direction': 'lt', 'impact': 'EP6alt intro_legame_distante. Mallow nota la distanza.'},
        {'value': 10, 'label': '💞 Crisi',      'direction': 'lt', 'impact': 'Crisi familiare. Lex lo sente. Scene molto tese.'},
    ],
    'scintille': [
        {'value': 45, 'label': '✨ Kryptonite',  'direction': 'lt', 'impact': 'Minigame più difficili (già implementato). Intro EP2 se <45.'},
        {'value': 35, 'label': '✨ Spenta',      'direction': 'lt', 'impact': 'EP8 intro_senza_fiamma. Poteri molto ridotti.'},
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
    'assets/data/quests/s1/s1_crepa.json',
    'assets/data/quests/s1/s1_disegno_lex.json',
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
    ep = data.get('epilogue') or {}
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
            # Filtra opzioni: safe solo se NESSUN tier (incluso base) viola il floor
            safe_opts = [
                o for o in choice.get('options', [])
                if not any(would_violate_floor(stats, e) for e in _all_effects_for_option(o))
            ] or choice.get('options', [])

            # Scegli l'opzione che minimizza target_stat (considerando tier minigame)
            worst = min(safe_opts, key=lambda o: _extreme_stat_value(_all_effects_for_option(o), target_stat, maximize=False))
            eff_choices = _all_effects_for_option(worst)
            eff = min(eff_choices, key=lambda e: e.get(target_stat, 0)) if eff_choices else worst.get('stat_effects', {})
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

def _all_effects_for_option(opt: dict) -> list[dict]:
    """Restituisce tutti i possibili stat_effects per un'opzione,
    inclusi quelli dei tier dei minigame. La scelta peggiore potrebbe
    essere un tier, non l'effetto base dell'opzione."""
    base = dict(opt.get('stat_effects', {}))
    mg = opt.get('minigame')
    if mg and mg.get('tiers'):
        return [base] + [dict(t.get('stat_effects', {})) for t in mg['tiers']]
    return [base]

def _extreme_stat_value(effects_list: list[dict], stat_name: str, maximize: bool) -> int:
    """Trova il valore min o max di stat_name in una lista di effetti."""
    vals = [e.get(stat_name, 0) for e in effects_list]
    return max(vals) if maximize else min(vals)

def _choose_extreme(safe_opts: list, stat_name: str, maximize: bool):
    """Sceglie l'opzione che minimizza o massimizza stat_name tra quelle safe,
    considerando anche i tier dei minigame."""
    def key_fn(o):
        return _extreme_stat_value(_all_effects_for_option(o), stat_name, maximize)
    if maximize:
        return max(safe_opts, key=key_fn)
    return min(safe_opts, key=key_fn)

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
                        if not any(would_violate_floor(stats, e) for e in _all_effects_for_option(o))
                    ] or choice.get('options', [])
                    opt = _choose_extreme(safe_opts, stat_name, maximize=False)
                    eff_opt = _all_effects_for_option(opt)
                    eff = min(eff_opt, key=lambda e: e.get(stat_name, 0)) if eff_opt else opt.get('stat_effects', {})
                    stats = apply_effects(stats, eff)

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
                        if not any(would_violate_floor(stats, e) for e in _all_effects_for_option(o))
                    ] or choice.get('options', [])
                    opt = _choose_extreme(safe_opts, stat_name, maximize=True)
                    eff_opt = _all_effects_for_option(opt)
                    eff = max(eff_opt, key=lambda e: e.get(stat_name, 0)) if eff_opt else opt.get('stat_effects', {})
                    stats = apply_effects(stats, eff)

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


# ─── Verifica raggiungibilità stat_entry ──────────────────────────────────────

def _all_effects_from_choice(choice: dict) -> list[dict]:
    """Espande una choice in tutte le possibili combinazioni di effetti,
    inclusi i tier dei minigame."""
    all_effects = []
    for opt in choice.get('options', []):
        base = dict(opt.get('stat_effects', {}))
        mg = opt.get('minigame')
        if mg and mg.get('tiers'):
            # Ogni tier è un possibile esito
            for tier in mg['tiers']:
                tier_eff = dict(tier.get('stat_effects', base))
                all_effects.append(tier_eff)
        else:
            # Opzione senza minigame, usa gli effetti base
            all_effects.append(base)
    return all_effects


def _min_max_stat_for_episode(episodes: list, stat_name: str, up_to_episode_idx: int):
    """
    Calcola il minimo e massimo raggiungibile per stat_name dopo aver giocato
    tutti gli episodi fino a up_to_episode_idx (escluso).
    Considera TUTTI i possibili esiti dei minigame (tutti i tier).
    """
    stats_min = dict(STAT_INITIAL)
    stats_max = dict(STAT_INITIAL)

    for idx in range(up_to_episode_idx):
        path_ep = episodes[idx]
        data = json.load(open(path_ep))
        choices = get_choices_from_quest(data)

        for ctx, choice in choices:
            # Raccogli TUTTI i possibili effetti (inclusi tier minigame)
            all_effects = _all_effects_from_choice(choice)

            # Filtra quelli che violano i floor
            safe_min = [e for e in all_effects if not would_violate_floor(stats_min, e)]
            safe_max = [e for e in all_effects if not would_violate_floor(stats_max, e)]

            if safe_min:
                worst = min(safe_min, key=lambda e: e.get(stat_name, 0))
                stats_min = apply_effects(stats_min, worst)

            if safe_max:
                best = max(safe_max, key=lambda e: e.get(stat_name, 0))
                stats_max = apply_effects(stats_max, best)

    return stats_min.get(stat_name, 50), stats_max.get(stat_name, 50)


def check_stat_entry_reachability(episodes: list) -> bool:
    """
    Verifica che ogni condizione stat_entry sia raggiungibile.
    Per 'lt': il valore minimo della stat deve scendere sotto la soglia.
    Per 'gte': il valore massimo deve superare la soglia.
    Salta le condizioni basate solo su flag (verificabili solo a runtime).
    """
    ok = True

    for ep_idx, path_ep in enumerate(episodes):
        data = json.load(open(path_ep))
        ep_id = data.get('id', path_ep)
        stat_entries = data.get('stat_entry', [])

        for rule_idx, rule in enumerate(stat_entries):
            conditions = []

            if rule.get('all_of'):
                conditions = [{'stat': c['stat'], 'op': c['op'], 'value': c['value']} for c in rule['all_of']]
            elif rule.get('stat'):
                conditions = [{'stat': rule['stat'], 'op': rule['op'], 'value': rule['value']}]

            # Le flag_conditions da sole non hanno soglia stat numerica
            if not conditions and rule.get('flag_conditions'):
                continue

            for cond in conditions:
                stat = cond['stat']
                op = cond['op']
                value = cond['value']
                branch = rule.get('goto_branch', '?')

                if op in ('lt', 'lte'):
                    min_val, _ = _min_max_stat_for_episode(episodes, stat, ep_idx)
                    if value <= min_val:
                        print(f"  \U0001f534 [{ep_id}] stat_entry[{rule_idx}]: {stat} {op} {value} \u2192 {branch}")
                        print(f"     Soglia {value} \u2264 min raggiungibile {min_val} \u2014 CONDIZIONE MAI VERA")
                        ok = False

                elif op in ('gt', 'gte'):
                    _, max_val = _min_max_stat_for_episode(episodes, stat, ep_idx)
                    if value > max_val:
                        print(f"  \U0001f534 [{ep_id}] stat_entry[{rule_idx}]: {stat} {op} {value} \u2192 {branch}")
                        print(f"     Soglia {value} > max raggiungibile {max_val} \u2014 CONDIZIONE MAI VERA")
                        ok = False

    if ok:
        print("  \u2705 Tutte le soglie stat_entry sono raggiungibili")
    return ok

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
        'legame': {70: 'EP9c (requires_stats)', 40: 'EP6alt (intro_legame_distante) + EP9c soglia', 10: '—'},
        'scintille': {45: 'EP2 (stat_entry) + minigame', 35: 'EP8 (intro_senza_fiamma)'},
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
                        if not any(would_violate_floor(stats, e) for e in _all_effects_for_option(o))
                    ] or choice.get('options', [])
                    maximize = t['direction'] == 'gte'
                    opt = _choose_extreme(safe_opts, stat_name, maximize=maximize)
                    eff_opt = _all_effects_for_option(opt)
                    eff = max(eff_opt, key=lambda e: e.get(stat_name, 0)) if maximize else min(eff_opt, key=lambda e: e.get(stat_name, 0))
                    stats = apply_effects(stats, eff)

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

    # 6. Verifica raggiungibilità stat_entry (branch non morti)
    print("\n─── 6. Raggiungibilità soglie stat_entry ─────────────────")
    if not check_stat_entry_reachability(EPISODES):
        all_ok = False

    # 7. Riepilogo finale
    print("\n╔══════════════════════════════════════════════════════════╗")
    if all_ok:
        print("║  ✅  VALIDAZIONE PASSATA — tutti i floor sono rispettati ║")
    else:
        print("║  🔴  ERRORI TROVATI — correggere prima di pubblicare     ║")
    print("╚══════════════════════════════════════════════════════════╝\n")
    sys.exit(0 if all_ok else 1)

if __name__ == '__main__':
    main()
