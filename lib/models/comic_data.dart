// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

class ComicIndex {
  final List<CharacterDefinition> characters;

  ComicIndex({
    required this.characters,
  });

  factory ComicIndex.fromJson(Map<String, dynamic> json) {
    final charactersJson = (json['characters'] as List<dynamic>? ?? []);

    return ComicIndex(
      characters: charactersJson
          .map((e) => CharacterDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  CharacterDefinition? getCharacterById(String id) {
    for (final c in characters) {
      if (c.id == id) return c;
    }
    return null;
  }

  String getSpeakerName(String? speakerId) {
    if (speakerId == null || speakerId.isEmpty) return '';
    return getCharacterById(speakerId)?.displayName ?? speakerId;
  }
}

class CharacterDefinition {
  final String id;
  final String name;
  final String displayName;
  final String role;
  final String variant;

  CharacterDefinition({
    required this.id,
    required this.name,
    required this.displayName,
    required this.role,
    required this.variant,
  });

  factory CharacterDefinition.fromJson(Map<String, dynamic> json) {
    return CharacterDefinition(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      variant: json['variant'] as String? ?? '',
    );
  }
}

class EpisodeSummary {
  final String id;
  final String title;
  final String subtitle;
  final String thumbnail;
  final String file;

  const EpisodeSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.thumbnail,
    required this.file,
  });

  factory EpisodeSummary.fromJson(Map<String, dynamic> json) {
    return EpisodeSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
      file: json['file'] as String? ?? '',
    );
  }
}

/// Una regola di ingresso condizionale basata sulle stat.
/// Valutata all'avvio della quest: il primo match determina il branch iniziale.
/// Singola condizione su una stat numerica: { stat, op, value }
class StatCondition {
  final String stat;
  final String op;
  final int value;

  const StatCondition({required this.stat, required this.op, required this.value});

  bool matches(Map<String, int> stats) {
    final v = stats[stat] ?? 0;
    switch (op) {
      case 'lt':  return v < value;
      case 'lte': return v <= value;
      case 'gt':  return v > value;
      case 'gte': return v >= value;
      case 'eq':  return v == value;
      default:    return false;
    }
  }

  factory StatCondition.fromJson(Map<String, dynamic> json) => StatCondition(
        stat:  json['stat'] as String? ?? '',
        op:    json['op']   as String? ?? 'lt',
        value: json['value'] as int?   ?? 0,
      );
}

/// Condizione su un world flag booleano: { "flag": "nome", "is": true/false }
/// Un flag assente equivale a false.
class FlagCondition {
  final String flag;
  final bool expectedValue;

  const FlagCondition({required this.flag, required this.expectedValue});

  bool matches(Map<String, bool> flags) =>
      (flags[flag] ?? false) == expectedValue;

  factory FlagCondition.fromJson(Map<String, dynamic> json) => FlagCondition(
        flag:          json['flag'] as String? ?? '',
        expectedValue: json['is']   as bool?   ?? false,
      );
}

/// Regola stat_entry: determina il branch di ingresso in base a stat e/o flag.
///
/// Formati JSON supportati:
///   - Singola stat:  { "stat": "segreto", "op": "lt", "value": 50, "goto_branch": "..." }
///   - AND stat:      { "all_of": [{stat,op,value},...], "goto_branch": "..." }
///   - Con flag:      aggiungere "flag_conditions": [{"flag":"nome","is":true}]
///   - Prepend:       aggiungere "prepend": true
class StatEntryRule {
  final String stat;
  final String op; // "lt", "lte", "gt", "gte", "eq"
  final int value;
  final String gotoBranch;

  /// Se true, il branch viene anteposto alle pagine principali (prepend).
  final bool prepend;

  /// Condizioni stat in AND. Se non vuota, sovrascrive stat/op/value.
  final List<StatCondition> allOf;

  /// Condizioni flag in AND. Valutate sempre in aggiunta alle stat.
  final List<FlagCondition> flagConditions;

  const StatEntryRule({
    required this.stat,
    required this.op,
    required this.value,
    required this.gotoBranch,
    this.prepend = false,
    this.allOf = const [],
    this.flagConditions = const [],
  });

  bool matches(Map<String, int> stats, Map<String, bool> flags) {
    // Valuta le stat conditions
    final statOk = allOf.isNotEmpty
        ? allOf.every((c) => c.matches(stats))
        : _matchSingleStat(stats);
    if (!statOk) return false;
    // Valuta le flag conditions (AND con le stat)
    return flagConditions.every((fc) => fc.matches(flags));
  }

  bool _matchSingleStat(Map<String, int> stats) {
    if (stat.isEmpty) return true; // regola solo-flag: nessuna stat richiesta
    final statVal = stats[stat] ?? 0;
    switch (op) {
      case 'lt':  return statVal < value;
      case 'lte': return statVal <= value;
      case 'gt':  return statVal > value;
      case 'gte': return statVal >= value;
      case 'eq':  return statVal == value;
      default:    return false;
    }
  }

  factory StatEntryRule.fromJson(Map<String, dynamic> json) {
    final allOfJson = json['all_of'] as List<dynamic>?;
    final flagsJson = json['flag_conditions'] as List<dynamic>?;
    return StatEntryRule(
      stat:         json['stat']         as String? ?? '',
      op:           json['op']           as String? ?? 'lt',
      value:        json['value']        as int?    ?? 0,
      gotoBranch:   json['goto_branch']  as String? ?? '',
      prepend:      json['prepend']      as bool?   ?? false,
      allOf: allOfJson == null
          ? const []
          : allOfJson
              .map((e) => StatCondition.fromJson(e as Map<String, dynamic>))
              .toList(),
      flagConditions: flagsJson == null
          ? const []
          : flagsJson
              .map((e) => FlagCondition.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class EpisodeContent {
  final String id;
  final List<ComicPage> pages;
  final Map<String, Branch> branches;
  final Branch? epilogue;

  /// Regole valutate all'avvio: la prima che fa match imposta il branch iniziale
  /// sostituendo le pagine main (anziché appendersi dopo).
  final List<StatEntryRule> statEntry;

  /// Nome del tema audio ambientale per questo episodio (senza estensione).
  /// Corrisponde a un file in assets/audio/ambient/<audioTheme>.mp3.
  /// Null = nessuna musica.
  final String? audioTheme;

  EpisodeContent({
    required this.id,
    required this.pages,
    this.branches = const {},
    this.epilogue,
    this.statEntry = const [],
    this.audioTheme,
  });

  bool get hasBranches => branches.isNotEmpty;

  /// Risolve le regole stat_entry contro le stat e i world flags correnti.
  /// Restituisce il branch ID da usare come ingresso, o null se nessuna regola fa match.
  String? resolveEntryBranch(Map<String, int> stats, Map<String, bool> flags) {
    for (final rule in statEntry) {
      if (rule.matches(stats, flags)) return rule.gotoBranch;
    }
    return null;
  }

  /// Restituisce true se il branch di entry specificato è in modalità prepend.
  bool isEntryBranchPrepend(String branchId) {
    return statEntry.any((r) => r.gotoBranch == branchId && r.prepend);
  }

  factory EpisodeContent.fromJson(Map<String, dynamic> json) {
    final pagesJson = (json['pages'] as List<dynamic>? ?? []);

    final branchesJson = json['branches'] as Map<String, dynamic>?;
    final branches = <String, Branch>{};
    if (branchesJson != null) {
      branchesJson.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          branches[key] = Branch.fromJson(key, value);
        }
      });
    }

    final epilogueJson = json['epilogue'] as Map<String, dynamic>?;
    final statEntryJson = (json['stat_entry'] as List<dynamic>? ?? []);

    return EpisodeContent(
      id: json['id'] as String? ?? '',
      pages: pagesJson
          .map((p) => ComicPage.fromJson(p as Map<String, dynamic>))
          .toList(),
      branches: branches,
      epilogue: epilogueJson != null
          ? Branch.fromJson('__epilogue__', epilogueJson)
          : null,
      statEntry: statEntryJson
          .map((r) => StatEntryRule.fromJson(r as Map<String, dynamic>))
          .toList(),
      audioTheme: json['audio_theme'] as String?,
    );
  }
}

class Episode {
  final String id;
  final String title;
  final String subtitle;
  final String thumbnail;
  final List<ComicPage> pages;
  final Map<String, Branch> branches;
  final Branch? epilogue;

  /// Nome del tema audio ambientale per questo episodio (senza estensione).
  /// Corrisponde a un file in assets/audio/ambient/<audioTheme>.mp3.
  final String? audioTheme;

  Episode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.thumbnail,
    required this.pages,
    this.branches = const {},
    this.epilogue,
    this.audioTheme,
  });

  bool get hasBranches => branches.isNotEmpty;

  /// Indice della pagina (in `pages`) che contiene un `choice`, o -1 se nessuna.
  int get choicePageIndex {
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].choice != null) return i;
    }
    return -1;
  }
}

/// Un ramo narrativo alternativo: una sequenza di pagine con un id.
class Branch {
  final String id;
  final List<ComicPage> pages;
  /// Se true, l'epilogo globale dell'episodio non viene aggiunto dopo questo branch.
  final bool skipsEpilogue;

  const Branch({required this.id, required this.pages, this.skipsEpilogue = false});

  factory Branch.fromJson(String id, Map<String, dynamic> json) {
    final pagesJson = (json['pages'] as List<dynamic>? ?? []);
    return Branch(
      id: id,
      pages: pagesJson
          .map((p) => ComicPage.fromJson(p as Map<String, dynamic>))
          .toList(),
      skipsEpilogue: json['skips_epilogue'] as bool? ?? false,
    );
  }
}

/// Una scelta proposta al lettore alla fine di una pagina.
class Choice {
  final String id;
  final String prompt;
  final List<ChoiceOption> options;

  const Choice({
    required this.id,
    required this.prompt,
    required this.options,
  });

  factory Choice.fromJson(Map<String, dynamic> json) {
    final optionsJson = (json['options'] as List<dynamic>? ?? []);
    return Choice(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      options: optionsJson
          .map((o) => ChoiceOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Singolo livello di risultato per un mini-game.
class MinigameTier {
  final int minProducts;
  final String label;
  final Map<String, int> statEffects;
  /// Branch verso cui navigare dopo questo tier. Se vuoto, usa il goto_branch dell'opzione padre.
  final String gotoBranch;
  /// World flags da impostare quando questo tier viene raggiunto.
  final Map<String, bool> setFlags;

  const MinigameTier({
    required this.minProducts,
    required this.label,
    required this.statEffects,
    this.gotoBranch = '',
    this.setFlags = const {},
  });

  factory MinigameTier.fromJson(Map<String, dynamic> json) {
    final raw = json['stat_effects'] as Map<String, dynamic>?;
    final effects = <String, int>{};
    raw?.forEach((k, v) {
      if (v is int) effects[k] = v;
    });
    final flagsRaw = json['set_flags'] as Map<String, dynamic>?;
    final flags = <String, bool>{};
    flagsRaw?.forEach((k, v) {
      if (v is bool) flags[k] = v;
    });
    return MinigameTier(
      minProducts: json['min'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      statEffects: effects,
      gotoBranch: json['goto_branch'] as String? ?? '',
      setFlags: flags,
    );
  }
}

/// Configurazione di un mini-game associato a una scelta.
class MinigameConfig {
  final String type;
  final int productsTotal;

  /// Durata in secondi per mini-game a timer (es. respira). Null = non usato.
  final int? durationSeconds;

  /// Numero di round per mini-game a tentativi (es. schiva_lex). Null = non usato.
  final int? rounds;

  /// Tiers ordinati dal più alto al più basso (minProducts desc).
  final List<MinigameTier> tiers;

  /// Tema visivo opzionale per minigame multi-scenario (es. rincorsa_lex: "beach" | "mall").
  final String theme;

  const MinigameConfig({
    required this.type,
    required this.productsTotal,
    this.durationSeconds,
    this.rounds,
    required this.tiers,
    this.theme = 'beach',
  });

  factory MinigameConfig.fromJson(Map<String, dynamic> json) {
    final tiersRaw = (json['tiers'] as List<dynamic>?) ?? [];
    final tiers = tiersRaw
        .map((t) => MinigameTier.fromJson(t as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.minProducts.compareTo(a.minProducts));
    return MinigameConfig(
      type: json['type'] as String? ?? '',
      productsTotal: json['products_total'] as int? ?? 12,
      durationSeconds: json['duration_seconds'] as int?,
      rounds: json['rounds'] as int?,
      tiers: tiers,
      theme: json['theme'] as String? ?? 'beach',
    );
  }

  /// Restituisce il tier corrispondente al numero di prodotti abbattuti.
  MinigameTier tierFor(int fallen) {
    for (final t in tiers) {
      if (fallen >= t.minProducts) return t;
    }
    return tiers.last;
  }
}

class ChoiceOption {
  final String id;
  final String label;
  final String gotoBranch;
  final String? hint;

  /// Effetti sulle stat RPG: es. {"segreto": 1, "legame": -1}.
  final Map<String, int> statEffects;

  /// World flags da impostare atomicamente insieme agli effetti stat.
  /// Es. {"shirt_in_backpack": true}
  final Map<String, bool> setFlags;

  /// Se presente, questa scelta apre un mini-game prima di navigare al branch.
  final MinigameConfig? minigame;

  const ChoiceOption({
    required this.id,
    required this.label,
    required this.gotoBranch,
    this.hint,
    this.statEffects = const {},
    this.setFlags = const {},
    this.minigame,
  });

  factory ChoiceOption.fromJson(Map<String, dynamic> json) {
    final effectsJson = json['stat_effects'] as Map<String, dynamic>?;
    final statEffects = <String, int>{};
    effectsJson?.forEach((key, value) {
      if (value is int) statEffects[key] = value;
    });

    final flagsJson = json['set_flags'] as Map<String, dynamic>?;
    final setFlags = <String, bool>{};
    flagsJson?.forEach((key, value) {
      if (value is bool) setFlags[key] = value;
    });

    final minigameJson = json['minigame'] as Map<String, dynamic>?;

    return ChoiceOption(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      gotoBranch: json['goto_branch'] as String? ?? '',
      hint: json['hint'] as String?,
      statEffects: statEffects,
      setFlags: setFlags,
      minigame: minigameJson != null ? MinigameConfig.fromJson(minigameJson) : null,
    );
  }
}

class ComicPage {
  final int index;
  final String background;
  final List<Panel> panels;
  final Choice? choice;

  ComicPage({
    required this.index,
    required this.background,
    required this.panels,
    this.choice,
  });

  factory ComicPage.fromJson(Map<String, dynamic> json) {
    final panelsJson = (json['panels'] as List<dynamic>? ?? []);
    final choiceJson = json['choice'] as Map<String, dynamic>?;

    return ComicPage(
      index: json['index'] as int? ?? 0,
      background: json['background'] as String? ?? '',
      panels: panelsJson
          .map((p) => Panel.fromJson(p as Map<String, dynamic>))
          .toList(),
      choice: choiceJson != null ? Choice.fromJson(choiceJson) : null,
    );
  }
}

class Panel {
  final String id;
  final List<String> characters;
  final List<TextBlock> textBlocks;
  final List<Interaction> interactions;

  Panel({
    required this.id,
    required this.characters,
    required this.textBlocks,
    required this.interactions,
  });

  factory Panel.fromJson(Map<String, dynamic> json) {
    final chars = (json['characters'] as List<dynamic>? ?? []).cast<String>();
    final tbJson = (json['text_blocks'] as List<dynamic>? ?? []);
    final intJson = (json['interactions'] as List<dynamic>? ?? []);

    return Panel(
      id: json['id'] as String? ?? '',
      characters: chars,
      textBlocks: tbJson
          .map((t) => TextBlock.fromJson(t as Map<String, dynamic>))
          .toList(),
      interactions: intJson
          .map((i) => Interaction.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TextBlock {
  final String id;
  final String type;
  final String? speaker;
  final String text;

  TextBlock({
    required this.id,
    required this.type,
    this.speaker,
    required this.text,
  });

  factory TextBlock.fromJson(Map<String, dynamic> json) {
    return TextBlock(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'narration',
      speaker: json['speaker'] as String?,
      text: json['text'] as String? ?? '',
    );
  }

  bool get isNarration => type == 'narration';
  bool get isDialogue => type == 'dialogue';
  bool get isThought => type == 'thought';
  bool get isSystem => type == 'system';
}

class Interaction {
  final String type;
  final String target;
  final String effect;
  final String? sound;

  Interaction({
    required this.type,
    required this.target,
    required this.effect,
    this.sound,
  });

  factory Interaction.fromJson(Map<String, dynamic> json) {
    return Interaction(
      type: json['type'] as String? ?? '',
      target: json['target'] as String? ?? '',
      effect: json['effect'] as String? ?? '',
      sound: json['sound'] as String?,
    );
  }
}
