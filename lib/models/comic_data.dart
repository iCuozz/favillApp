class ComicIndex {
  final List<CharacterDefinition> characters;
  final List<EpisodeSummary> episodes;

  ComicIndex({
    required this.characters,
    required this.episodes,
  });

  factory ComicIndex.fromJson(Map<String, dynamic> json) {
    final charactersJson = (json['characters'] as List<dynamic>? ?? []);
    final episodesJson = (json['episodes'] as List<dynamic>? ?? []);

    return ComicIndex(
      characters: charactersJson
          .map((e) => CharacterDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
      episodes: episodesJson
          .map((e) => EpisodeSummary.fromJson(e as Map<String, dynamic>))
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

  EpisodeSummary({
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

class EpisodeContent {
  final String id;
  final List<ComicPage> pages;
  final Map<String, Branch> branches;
  final Branch? epilogue;

  EpisodeContent({
    required this.id,
    required this.pages,
    this.branches = const {},
    this.epilogue,
  });

  bool get hasBranches => branches.isNotEmpty;

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

    return EpisodeContent(
      id: json['id'] as String? ?? '',
      pages: pagesJson
          .map((p) => ComicPage.fromJson(p as Map<String, dynamic>))
          .toList(),
      branches: branches,
      epilogue: epilogueJson != null
          ? Branch.fromJson('__epilogue__', epilogueJson)
          : null,
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

  Episode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.thumbnail,
    required this.pages,
    this.branches = const {},
    this.epilogue,
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

  const Branch({required this.id, required this.pages});

  factory Branch.fromJson(String id, Map<String, dynamic> json) {
    final pagesJson = (json['pages'] as List<dynamic>? ?? []);
    return Branch(
      id: id,
      pages: pagesJson
          .map((p) => ComicPage.fromJson(p as Map<String, dynamic>))
          .toList(),
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

class ChoiceOption {
  final String id;
  final String label;
  final String gotoBranch;
  final String? hint;

  /// Effetti sulle stat RPG: es. {"segreto": 1, "legame": -1}
  final Map<String, int> statEffects;

  const ChoiceOption({
    required this.id,
    required this.label,
    required this.gotoBranch,
    this.hint,
    this.statEffects = const {},
  });

  factory ChoiceOption.fromJson(Map<String, dynamic> json) {
    final effectsJson = json['stat_effects'] as Map<String, dynamic>?;
    final statEffects = <String, int>{};
    effectsJson?.forEach((key, value) {
      if (value is int) statEffects[key] = value;
    });

    return ChoiceOption(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      gotoBranch: json['goto_branch'] as String? ?? '',
      hint: json['hint'] as String?,
      statEffects: statEffects,
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
