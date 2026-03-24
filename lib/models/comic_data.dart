class ComicData {
  final List<CharacterDefinition> characters;
  final List<Episode> episodes;

  ComicData({
    required this.characters,
    required this.episodes,
  });

  factory ComicData.fromJson(Map<String, dynamic> json) {
    final episodesJson = (json['episodes'] as List<dynamic>? ?? []);
    final charactersJson = (json['characters'] as List<dynamic>? ?? []);

    return ComicData(
      characters: charactersJson
          .map((e) => CharacterDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
      episodes: episodesJson
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
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
      displayName: json['display_name'] as String? ?? json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      variant: json['variant'] as String? ?? '',
    );
  }
}

class Episode {
  final String id;
  final String title;
  final String subtitle;
  final String thumbnail;
  final Map<String, dynamic> metadata;
  final List<ComicPage> pages;

  Episode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.thumbnail,
    required this.metadata,
    required this.pages,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    final pagesJson = (json['pages'] as List<dynamic>? ?? []);

    return Episode(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      pages: pagesJson
          .map((p) => ComicPage.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ComicPage {
  final int index;
  final String background;
  final Map<String, dynamic> metadata;
  final List<Panel> panels;

  ComicPage({
    required this.index,
    required this.background,
    required this.metadata,
    required this.panels,
  });

  factory ComicPage.fromJson(Map<String, dynamic> json) {
    final panelsJson = (json['panels'] as List<dynamic>? ?? []);

    return ComicPage(
      index: json['index'] as int? ?? 0,
      background: json['background'] as String? ?? '',
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      panels: panelsJson
          .map((p) => Panel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Panel {
  final String id;
  final String layout;
  final List<String> characters;
  final Map<String, dynamic> metadata;
  final List<TextBlock> textBlocks;
  final List<Interaction> interactions;

  Panel({
    required this.id,
    required this.layout,
    required this.characters,
    required this.metadata,
    required this.textBlocks,
    required this.interactions,
  });

  factory Panel.fromJson(Map<String, dynamic> json) {
    final chars = (json['characters'] as List<dynamic>? ?? []).cast<String>();
    final tbJson = (json['text_blocks'] as List<dynamic>? ?? []);
    final intJson = (json['interactions'] as List<dynamic>? ?? []);

    return Panel(
      id: json['id'] as String? ?? '',
      layout: json['layout'] as String? ?? 'full',
      characters: chars,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? <String, dynamic>{},
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
  final String type; // narration, dialogue, thought, system
  final String? speaker;
  final String text;
  final Map<String, dynamic> style;

  TextBlock({
    required this.id,
    required this.type,
    this.speaker,
    required this.text,
    required this.style,
  });

  factory TextBlock.fromJson(Map<String, dynamic> json) {
    return TextBlock(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'narration',
      speaker: json['speaker'] as String?,
      text: json['text'] as String? ?? '',
      style: (json['style'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  bool get isNarration => type == 'narration';
  bool get isDialogue => type == 'dialogue';
  bool get isThought => type == 'thought';
  bool get isSystem => type == 'system';
}

class Interaction {
  final String type; // tap, etc.
  final String target; // es. cucchiaio
  final String effect; // es. shake
  final String? sound; // path suono

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