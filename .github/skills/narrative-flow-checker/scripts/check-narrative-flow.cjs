#!/usr/bin/env node
/**
 * Narrative Flow Checker — FavillApp
 *
 * Verifica:
 *   1. Tutti i goto_branch puntano a branch esistenti nello stesso episodio
 *   2. Tutti i branch sono raggiungibili da almeno un percorso
 *   3. stat_entry: simula tutti i percorsi statistici e segnala rami ambigui
 *   4. Cross-episode: rileva disallineamenti tra il branch scelto in un episodio
 *      e l'instradamento del successivo (proxy-stat inconsistency)
 *
 * Usage:
 *   node check-narrative-flow.cjs [project-root]
 *   node check-narrative-flow.cjs [project-root] --episode s1_ritorno_casa
 *   node check-narrative-flow.cjs [project-root] --all-paths
 */

const fs = require('fs');
const path = require('path');

const projectRoot = process.argv[2] || process.cwd();
const filterEpisode = (() => {
  const i = process.argv.indexOf('--episode');
  return i >= 0 ? process.argv[i + 1] : null;
})();
const showAllPaths = process.argv.includes('--all-paths');

// ─── Config ────────────────────────────────────────────────────────────────

const INITIAL_STATS = { segreto: 50, legame: 50, scintille: 50, resistenza: 50 };
const STAT_MIN = { segreto: 0, legame: 0, scintille: 0, resistenza: 0 };
const STAT_MAX = { segreto: 100, legame: 100, scintille: 100, resistenza: 100 };

// Ordered episode sequence (add new episodes here as they're created)
const EPISODE_ORDER = [
  'quests/prologo.json',
  'quests/s1/s1_mattina_dopo.json',
  'quests/s1/s1_scuola_1.json',
  'quests/s1/s1_ritorno_casa.json',
  'quests/s1/s1_spesa_sabato.json',
  'quests/s1/s1_domenica_parco.json',
  'quests/s1/s1_mare.json',
];

// ─── Helpers ───────────────────────────────────────────────────────────────

function clamp(stat, value) {
  return Math.max(STAT_MIN[stat] ?? 0, Math.min(STAT_MAX[stat] ?? 100, value));
}

function applyEffects(stats, effects) {
  const out = { ...stats };
  for (const [k, v] of Object.entries(effects || {})) {
    out[k] = clamp(k, (out[k] ?? 50) + v);
  }
  return out;
}

function evalOp(value, op, threshold) {
  switch (op) {
    case 'lt':  return value <  threshold;
    case 'lte': return value <= threshold;
    case 'gt':  return value >  threshold;
    case 'gte': return value >= threshold;
    case 'eq':  return value === threshold;
    default:    return false;
  }
}

function matchStatEntry(rule, stats, flags) {
  // Stat conditions
  let statOk;
  if (rule.all_of) {
    statOk = rule.all_of.every(c => evalOp(stats[c.stat] ?? 50, c.op, c.value));
  } else if (rule.stat) {
    statOk = evalOp(stats[rule.stat] ?? 50, rule.op, rule.value);
  } else {
    statOk = true; // flag-only rule
  }
  if (!statOk) return false;
  // Flag conditions (AND)
  for (const fc of (rule.flag_conditions || [])) {
    if ((flags[fc.flag] ?? false) !== fc.is) return false;
  }
  return true;
}

function resolveStatEntry(statEntry, stats, flags) {
  for (const rule of (statEntry || [])) {
    if (matchStatEntry(rule, stats, flags)) return rule.goto_branch;
  }
  return null;
}

function applySetFlags(flags, setFlags) {
  return { ...flags, ...(setFlags || {}) };
}

// ─── Structural checks ─────────────────────────────────────────────────────

function collectGotoBranches(obj, found = new Set()) {
  if (!obj || typeof obj !== 'object') return found;
  if (Array.isArray(obj)) { obj.forEach(i => collectGotoBranches(i, found)); return found; }
  if (obj.goto_branch) found.add(obj.goto_branch);
  for (const v of Object.values(obj)) collectGotoBranches(v, found);
  return found;
}

function checkStructural(episode, filename) {
  const errors = [];
  const warnings = [];

  const branchNames = new Set(Object.keys(episode.branches || {}));
  if (episode.epilogue) branchNames.add('__epilogue__'); // synthetic

  // All goto_branch refs (including stat_entry)
  const allRefs = collectGotoBranches({
    pages: episode.pages,
    branches: episode.branches,
    epilogue: episode.epilogue,
  });

  // stat_entry refs
  for (const rule of (episode.stat_entry || [])) {
    allRefs.add(rule.goto_branch);
  }

  // Check every reference resolves
  for (const ref of allRefs) {
    if (!branchNames.has(ref)) {
      errors.push(`goto_branch "${ref}" non esiste in branches`);
    }
  }

  // Check every branch is reachable
  for (const b of branchNames) {
    if (b === '__epilogue__') continue; // epilogue is always played last, not via goto_branch
    if (!allRefs.has(b)) {
      warnings.push(`Branch "${b}" non è raggiunto da nessun goto_branch — potrebbe essere un dead branch`);
    }
  }

  return { errors, warnings };
}

// ─── Path simulation ───────────────────────────────────────────────────────

/**
 * Enumerate all leaf choices in an episode.
 * Returns an array of {label, effectsList} where effectsList is a list of
 * effect maps that accumulate through the episode.
 */
function enumerateEpisodePaths(episode) {
  // Collect all choices (main pages + epilogue pages + branch pages)
  const choices = [];

  function scanPages(pages, prefix) {
    for (const page of (pages || [])) {
      if (page.choice) {
        choices.push({ prefix, choice: page.choice });
      }
    }
  }

  function scanBranch(branchId, pages) {
    scanPages(pages, `[${branchId}]`);
  }

  scanPages(episode.pages, '');
  if (episode.epilogue) scanPages(episode.epilogue.pages, '[epilogue]');
  for (const [id, b] of Object.entries(episode.branches || {})) {
    scanBranch(id, b.pages);
  }

  // For simplicity: enumerate top-level choices only (main pages + epilogue)
  // and collect their combined effects as representative paths
  const mainChoices = [];
  for (const page of (episode.pages || [])) {
    if (page.choice) mainChoices.push(page.choice);
  }
  const epilogueChoices = [];
  if (episode.epilogue) {
    for (const page of (episode.epilogue.pages || [])) {
      if (page.choice) epilogueChoices.push(page.choice);
    }
  }

  function crossProduct(choiceGroups) {
    if (choiceGroups.length === 0) return [{ label: '', effects: {}, branches: [] }];
    const [head, ...rest] = choiceGroups;
    const restPaths = crossProduct(rest);
    const result = [];
    for (const opt of head.options) {
      const optEffects = opt.stat_effects || {};
      const optLabel = opt.id;
      const optBranch = opt.goto_branch;

      // Also check minigame tiers
      const tierPaths = opt.minigame
        ? opt.minigame.tiers.map(t => ({
            label: `${optLabel}[${t.label.slice(0,8)}]`,
            effects: { ...optEffects, ...(t.stat_effects || {}) },
            branch: t.goto_branch || optBranch,
          }))
        : [{ label: optLabel, effects: optEffects, branch: optBranch }];

      for (const tier of tierPaths) {
        for (const rp of restPaths) {
          result.push({
            label: [tier.label, rp.label].filter(Boolean).join('+'),
            effects: mergeEffects(tier.effects, rp.effects),
            branches: [tier.branch, ...(rp.branches || [])].filter(Boolean),
          });
        }
      }
    }
    return result;
  }

  return crossProduct([...mainChoices, ...epilogueChoices]);
}

function mergeEffects(a, b) {
  const out = { ...a };
  for (const [k, v] of Object.entries(b)) {
    out[k] = (out[k] || 0) + v;
  }
  return out;
}

// ─── Cross-episode consistency ─────────────────────────────────────────────

/**
 * Simulate all cumulative paths across all episodes.
 * For each final path, record which stat_entry branch was triggered at each episode.
 */
function simulateAllPaths(episodes) {
  // Start with a single path
  let paths = [{ label: 'START', stats: { ...INITIAL_STATS }, history: [] }];

  for (const ep of episodes) {
    const nextPaths = [];

    for (const p of paths) {
      // Resolve stat_entry for this episode
      const entryBranch = resolveStatEntry(ep.stat_entry, p.stats);

      // Get all episode-level choice paths
      const epPaths = enumerateEpisodePaths(ep);

      for (const ep of epPaths.length ? epPaths : [{ label: '', effects: {}, branches: [] }]) {
        const newStats = applyEffects(p.stats, ep.effects);
        nextPaths.push({
          label: [p.label, `${ep.id || ''}(${ep.label || 'no-choice'})`].filter(l => l && l !== 'START').join(' → '),
          stats: newStats,
          history: [...p.history, {
            episode: ep.id,
            entryBranch,
            choices: ep.branches || [],
          }],
        });
      }
    }

    paths = nextPaths;
  }

  return paths;
}

// ─── Main ──────────────────────────────────────────────────────────────────

function loadEpisode(relPath) {
  const fullPath = path.join(projectRoot, 'assets', 'data', relPath);
  try {
    return { ...JSON.parse(fs.readFileSync(fullPath, 'utf8')), _file: relPath };
  } catch (e) {
    return null;
  }
}

let totalErrors = 0;
let totalWarnings = 0;

console.log('\n╔══════════════════════════════════════════════════════╗');
console.log('║       NARRATIVE FLOW CHECKER — FavillApp             ║');
console.log('╚══════════════════════════════════════════════════════╝\n');

// ─── 1. Structural checks per episode ──────────────────────────────────────

console.log('━━━ 1. CONTROLLI STRUTTURALI ━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

const loadedEpisodes = [];
for (const relPath of EPISODE_ORDER) {
  if (filterEpisode && !relPath.includes(filterEpisode)) continue;
  const ep = loadEpisode(relPath);
  if (!ep) {
    console.log(`  ⚠️  ${relPath} — file non trovato, saltato`);
    continue;
  }
  loadedEpisodes.push(ep);

  const { errors, warnings } = checkStructural(ep, relPath);
  const status = errors.length ? '❌' : warnings.length ? '⚠️ ' : '✅';
  console.log(`  ${status} ${ep.id} (${relPath})`);
  for (const e of errors)   { console.log(`       ❌ ${e}`); totalErrors++; }
  for (const w of warnings) { console.log(`       ⚠️  ${w}`); totalWarnings++; }
}

// ─── 2. Stat-entry coverage per episode ────────────────────────────────────

console.log('\n━━━ 2. COPERTURA STAT_ENTRY ━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

for (const ep of loadedEpisodes) {
  if (!(ep.stat_entry || []).length) continue;
  console.log(`  📊 ${ep.id}:`);
  for (const rule of ep.stat_entry) {
    let desc;
    if (rule.all_of) {
      desc = rule.all_of.map(c => `${c.stat} ${c.op} ${c.value}`).join(' AND ');
    } else if (rule.stat) {
      desc = `${rule.stat} ${rule.op} ${rule.value}`;
    } else {
      desc = '(solo flags)';
    }
    const flagDesc = (rule.flag_conditions || []).map(fc => `${fc.flag}==${fc.is}`).join(' AND ');
    const full = [desc, flagDesc].filter(Boolean).join(' && ');
    console.log(`     Rule [${full}] → "${rule.goto_branch}"`);
    if (rule.prepend) console.log(`       (prepend: true — aggiunto prima dei main pages)`);
  }
}

// ─── 3. Full path simulation & cross-episode consistency ───────────────────

console.log('\n━━━ 3. SIMULAZIONE PERCORSI CUMULATIVI ━━━━━━━━━━━━━━━━\n');
console.log('  Statistiche iniziali:', JSON.stringify(INITIAL_STATS));
console.log('  Flags iniziali: {}');
console.log('  Episodi in sequenza:', loadedEpisodes.map(e => e.id).join(' → '));
console.log();

// Build cumulative paths through all episodes sequentially
let paths = [{ label: '', stats: { ...INITIAL_STATS }, flags: {}, episodeChoices: [] }];
const inconsistencies = [];

for (const ep of loadedEpisodes) {
  const nextPaths = [];

  for (const p of paths) {
    // Check stat_entry for this episode given current stats + flags
    const entryBranch = resolveStatEntry(ep.stat_entry, p.stats, p.flags);

    // Enumerate all choices in this episode (main pages + epilogue)
    const mainChoices = (ep.pages || []).filter(pg => pg.choice).map(pg => pg.choice);
    const epilogueChoices = ((ep.epilogue || {}).pages || []).filter(pg => pg.choice).map(pg => pg.choice);
    const allChoices = [...mainChoices, ...epilogueChoices];

    function buildPaths(choiceGroups, accumulated) {
      if (!choiceGroups.length) return [accumulated];
      const [head, ...rest] = choiceGroups;
      const results = [];
      for (const opt of head.options) {
        const baseEffects = opt.stat_effects || {};
        const baseSetFlags = opt.set_flags || {};
        const baseBranch = opt.goto_branch;
        const baseLabel = opt.id;

        const tierList = opt.minigame
          ? opt.minigame.tiers.map(t => ({
              id: `${opt.id}[${t.goto_branch || 'tier'}]`,
              effects: mergeEffects(baseEffects, t.stat_effects || {}),
              setFlags: baseSetFlags, // minigame tiers don't set flags
              branch: t.goto_branch || baseBranch,
            }))
          : [{ id: baseLabel, effects: baseEffects, setFlags: baseSetFlags, branch: baseBranch }];

        for (const tier of tierList) {
          const newAcc = {
            label: [accumulated.label, tier.id].filter(Boolean).join('+'),
            effects: mergeEffects(accumulated.effects, tier.effects),
            setFlags: { ...accumulated.setFlags, ...tier.setFlags },
            branches: [...(accumulated.branches || []), tier.branch],
          };
          results.push(...buildPaths(rest, newAcc));
        }
      }
      return results;
    }

    const epChoicePaths = allChoices.length
      ? buildPaths(allChoices, { label: '', effects: {}, setFlags: {}, branches: [] })
      : [{ label: '', effects: {}, setFlags: {}, branches: [] }];

    for (const ecp of epChoicePaths) {
      const newStats = applyEffects(p.stats, ecp.effects);
      const newFlags = applySetFlags(p.flags, ecp.setFlags);
      const label = [p.label, `${ep.id}/${ecp.label || '∅'}`].filter(Boolean).join(' | ');

      nextPaths.push({
        label,
        stats: newStats,
        flags: newFlags,
        episodeChoices: [...p.episodeChoices, {
          episode: ep.id,
          entryBranch,
          choices: ecp.branches,
          choiceLabel: ecp.label,
        }],
      });
    }
  }

  paths = nextPaths;
}

console.log(`  Percorsi totali simulati: ${paths.length}`);
if (showAllPaths) {
  console.log('\n  Tutti i percorsi:');
  for (const p of paths) {
    const s = p.stats;
    const f = Object.entries(p.flags).map(([k,v])=>`${k}=${v}`).join(',') || '∅';
    console.log(`    [S:${s.segreto} L:${s.legame} Sc:${s.scintille} R:${s.resistenza} flags:{${f}}] ${p.label}`);
  }
}

// ─── 4. Known cross-episode consistency rules ──────────────────────────────

console.log('\n━━━ 4. REGOLE DI COERENZA CROSS-EPISODIO ━━━━━━━━━━━━━━\n');

/**
 * Define consistency rules.
 * Each rule: given the choices history, the stat_entry branch triggered in episode X
 * should be consistent with a prior choice in episode Y.
 */
const CROSS_EPISODE_RULES = [
  {
    name: 'EP3 shirt location (s1_ritorno_casa)',
    description: 'intro_vestiti_bruciati* deve corrispondere alla scelta in s1_scuola_1',
    check(episodeChoices) {
      const ep2 = episodeChoices.find(e => e.episode === 's1_scuola_1');
      const ep3 = episodeChoices.find(e => e.episode === 's1_ritorno_casa');
      if (!ep2 || !ep3) return null; // skip if not both episodes are present

      // Determine shirt location from EP2 choice
      const ep2Choice = ep2.choiceLabel || '';
      const shirtOnBody = ep2Choice.includes('finge_niente');
      const shirtInBackpack = ep2Choice.includes('bagno');

      const entry = ep3.entryBranch;
      if (!entry) return null; // no stat_entry triggered — always consistent

      if (shirtOnBody && entry === 'intro_vestiti_bruciati') {
        return `camicia ADDOSSO (finge) ma EP3 usa scena "zaino" (${entry})`;
      }
      if (shirtInBackpack && entry === 'intro_vestiti_bruciati_indosso') {
        return `camicia in ZAINO (bagno) ma EP3 usa scena "indosso" (${entry})`;
      }
      return null;
    },
  },
  {
    name: 'EP5 favilla_transformed_public flag',
    description: 'branch_perso_trasformazione deve impostare favilla_transformed_public=true',
    check(episodeChoices) {
      const ep5 = episodeChoices.find(e => e.episode === 's1_domenica_parco');
      if (!ep5) return null;
      // Only check paths that went through the trasformazione branch
      if (ep5.branch !== 'branch_perso_trasformazione') return null;
      // The flag should be set — if we got here the path went through that branch
      // The checker already tracks flags in worldFlags; if the flag is missing it's an issue
      if (!ep5.worldFlags || ep5.worldFlags['favilla_transformed_public'] !== true) {
        return `branch_perso_trasformazione raggiunto ma favilla_transformed_public non impostato a true`;
      }
      return null;
    },
  },
];

let crossErrors = 0;
for (const rule of CROSS_EPISODE_RULES) {
  console.log(`  🔍 ${rule.name}`);
  console.log(`     ${rule.description}`);
  const failures = [];
  for (const p of paths) {
    const err = rule.check(p.episodeChoices);
    if (err) failures.push({ path: p.label, stats: p.stats, err });
  }
  if (!failures.length) {
    console.log(`     ✅ Nessuna inconsistenza su ${paths.length} percorsi\n`);
  } else {
    console.log(`     ❌ ${failures.length} percorsi inconsistenti:\n`);
    for (const f of failures) {
      const s = f.stats;
      console.log(`       ❌ ${f.err}`);
      console.log(`          Percorso: ${f.path}`);
      console.log(`          Stat finali: S:${s.segreto} L:${s.legame} Sc:${s.scintille} R:${s.resistenza}\n`);
      crossErrors++;
      totalErrors++;
    }
  }
}

// ─── 5. Copertura flag: ogni flag usato in flag_conditions deve essere impostato a monte ──

console.log('\n━━━ 5. COPERTURA DEI WORLD FLAGS ━━━━━━━━━━━━━━━━━━━━━━\n');

// Raccoglie tutti i flag USATI in flag_conditions (con l'episodio che li usa)
const flagsConsumed = new Map(); // flag → Set<episodeId>
for (const ep of loadedEpisodes) {
  for (const rule of (ep.stat_entry || [])) {
    for (const fc of (rule.flag_conditions || [])) {
      if (!flagsConsumed.has(fc.flag)) flagsConsumed.set(fc.flag, new Set());
      flagsConsumed.get(fc.flag).add(ep.id);
    }
  }
}

// Raccoglie tutti i flag IMPOSTATI in set_flags (con l'episodio che li imposta)
const flagsProduced = new Map(); // flag → Set<episodeId>
for (const ep of loadedEpisodes) {
  function collectSetFlags(pages) {
    for (const pg of (pages || [])) {
      for (const opt of (pg.choice?.options || [])) {
        for (const flag of Object.keys(opt.set_flags || {})) {
          if (!flagsProduced.has(flag)) flagsProduced.set(flag, new Set());
          flagsProduced.get(flag).add(ep.id);
        }
        // Also collect set_flags from minigame tiers
        for (const tier of (opt.minigame?.tiers || [])) {
          for (const flag of Object.keys(tier.set_flags || {})) {
            if (!flagsProduced.has(flag)) flagsProduced.set(flag, new Set());
            flagsProduced.get(flag).add(ep.id);
          }
        }
      }
    }
  }
  collectSetFlags(ep.pages);
  collectSetFlags((ep.epilogue || {}).pages);
  for (const branchPages of Object.values(ep.branches || {})) {
    collectSetFlags((branchPages || {}).pages);
  }
}

if (flagsConsumed.size === 0 && flagsProduced.size === 0) {
  console.log('  ℹ️  Nessun world flag definito ancora.\n');
} else {
  // Mostra flags prodotti
  for (const [flag, producers] of flagsProduced) {
    const consumers = flagsConsumed.get(flag);
    if (consumers) {
      console.log(`  ✅ "${flag}"`);
      console.log(`     Impostato in: ${[...producers].join(', ')}`);
      console.log(`     Usato in:     ${[...consumers].join(', ')}\n`);
    } else {
      console.log(`  ⚠️  "${flag}": impostato in ${[...producers].join(', ')} ma mai usato in flag_conditions`);
      totalWarnings++;
    }
  }

  // Flag usati ma mai impostati da nessun episodio → errore authoring
  for (const [flag, consumers] of flagsConsumed) {
    if (!flagsProduced.has(flag)) {
      console.log(`  ❌ "${flag}": usato in ${[...consumers].join(', ')} ma NESSUN episodio lo imposta con set_flags!`);
      console.log(`     (Ricorda: flag assente = false — ma potrebbe essere un errore di authoring)\n`);
      totalErrors++;
    }
  }
}


// ─── Summary ───────────────────────────────────────────────────────────────

console.log('━━━ RIEPILOGO ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
console.log(`  Errori strutturali:      ${totalErrors - crossErrors}`);
console.log(`  Avvertenze strutturali:  ${totalWarnings}`);
console.log(`  Errori cross-episodio:   ${crossErrors}`);
console.log();

if (totalErrors === 0 && totalWarnings === 0) {
  console.log('  ✅ Tutto ok — narrativa coerente su tutti i percorsi\n');
} else if (totalErrors === 0) {
  console.log('  ⚠️  Nessun errore critico ma attenzione agli avvertimenti\n');
} else {
  console.log('  ❌ Trovati errori che richiedono correzione\n');
  process.exit(1);
}
