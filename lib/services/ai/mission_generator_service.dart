import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../settings_service.dart';
import 'ai_client.dart';
import 'ai_rate_limiter.dart';

/// Pannello di una missione generata dall'AI. Schema parallelo (ma più
/// semplice) di [Panel] in models/comic_data.dart.
class GeneratedTextBlock {
  final String type;
  final String speaker;
  final String text;

  GeneratedTextBlock({
    required this.type,
    required this.speaker,
    required this.text,
  });

  factory GeneratedTextBlock.fromJson(Map<String, dynamic> j) =>
      GeneratedTextBlock(
        type: j['type'] as String? ?? 'narration',
        speaker: j['speaker'] as String? ?? 'narrator',
        text: (j['text'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'speaker': speaker,
        'text': text,
      };
}

class GeneratedPanel {
  final List<GeneratedTextBlock> textBlocks;

  GeneratedPanel({required this.textBlocks});

  factory GeneratedPanel.fromJson(Map<String, dynamic> j) {
    final blocks = (j['textBlocks'] as List<dynamic>? ?? [])
        .map((e) => GeneratedTextBlock.fromJson(e as Map<String, dynamic>))
        .toList();
    return GeneratedPanel(textBlocks: blocks);
  }

  Map<String, dynamic> toJson() => {
        'textBlocks': textBlocks.map((b) => b.toJson()).toList(),
      };
}

class GeneratedMission {
  final String id;
  final String title;
  final String? subtitle;
  final List<GeneratedPanel> panels;
  final String situation;
  final DateTime createdAt;
  final String lang;

  GeneratedMission({
    required this.id,
    required this.title,
    this.subtitle,
    required this.panels,
    required this.situation,
    required this.createdAt,
    required this.lang,
  });

  factory GeneratedMission.fromAiJson({
    required Map<String, dynamic> json,
    required String situation,
    required String lang,
  }) {
    final panels = (json['panels'] as List<dynamic>? ?? [])
        .map((e) => GeneratedPanel.fromJson(e as Map<String, dynamic>))
        .toList();
    return GeneratedMission(
      id: const Uuid().v4(),
      title: (json['title'] as String? ?? '').trim(),
      subtitle: (json['subtitle'] as String?)?.trim(),
      panels: panels,
      situation: situation,
      createdAt: DateTime.now(),
      lang: lang,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'panels': panels.map((p) => p.toJson()).toList(),
        'situation': situation,
        'createdAt': createdAt.toIso8601String(),
        'lang': lang,
      };

  factory GeneratedMission.fromJson(Map<String, dynamic> j) {
    return GeneratedMission(
      id: j['id'] as String? ?? const Uuid().v4(),
      title: j['title'] as String? ?? '',
      subtitle: j['subtitle'] as String?,
      panels: (j['panels'] as List<dynamic>? ?? [])
          .map((p) => GeneratedPanel.fromJson(p as Map<String, dynamic>))
          .toList(),
      situation: j['situation'] as String? ?? '',
      createdAt:
          DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      lang: j['lang'] as String? ?? 'it',
    );
  }

  /// Plain-text esportabile (share / TTS).
  String toShareText() {
    final lines = <String>[
      title,
      if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
      '',
    ];
    for (var i = 0; i < panels.length; i++) {
      lines.add('— Pannello ${i + 1} —');
      for (final b in panels[i].textBlocks) {
        if (b.type == 'narration') {
          lines.add(b.text);
        } else if (b.type == 'thought') {
          lines.add('(${_speakerName(b.speaker)} pensa) ${b.text}');
        } else {
          lines.add('${_speakerName(b.speaker)}: ${b.text}');
        }
      }
      lines.add('');
    }
    return lines.join('\n').trim();
  }

  static String _speakerName(String id) {
    switch (id) {
      case 'favilla':
        return 'Favilla';
      case 'sparkle_ale':
        return 'Sparkle Ale';
      case 'mallow_bellow':
        return 'Mallow Bellow';
      default:
        return '';
    }
  }
}

class MissionGeneratorService {
  MissionGeneratorService._();
  static final MissionGeneratorService instance = MissionGeneratorService._();

  static const _kStorageKey = 'ai.missions.collection';
  static const int _maxStored = 30;

  final AiRateLimiter limiter =
      const AiRateLimiter(endpoint: 'mission', perDay: 5);

  Future<GeneratedMission> generate(String situation) async {
    final trimmed = situation.trim();
    if (trimmed.length < 5) {
      throw AiException('too_short', 'Descrivi un po\' meglio la situazione.');
    }

    final lang = SettingsService.language.value.code;
    final res = await AiClient.instance.post(
      'mission',
      {'situation': trimmed},
      limiter: limiter,
    );
    final raw = res['mission'] as Map<String, dynamic>?;
    if (raw == null) {
      throw AiException('bad_response', 'Risposta vuota dal server AI.');
    }

    final mission = GeneratedMission.fromAiJson(
      json: raw,
      situation: trimmed,
      lang: lang,
    );
    if (mission.panels.isEmpty || mission.title.isEmpty) {
      throw AiException('bad_response', 'Missione generata non valida.');
    }
    return mission;
  }

  Future<List<GeneratedMission>> loadCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStorageKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => GeneratedMission.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(GeneratedMission mission) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadCollection();
    final next = [mission, ...current.where((m) => m.id != mission.id)];
    final trimmed =
        next.length > _maxStored ? next.sublist(0, _maxStored) : next;
    await prefs.setString(
      _kStorageKey,
      jsonEncode(trimmed.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadCollection();
    final next = current.where((m) => m.id != id).toList();
    await prefs.setString(
      _kStorageKey,
      jsonEncode(next.map((m) => m.toJson()).toList()),
    );
  }

  /// Suggerimenti di situazioni "tipo".
  List<String> suggestions() {
    switch (SettingsService.language.value) {
      case AppLanguage.english:
        return const [
          'The kids refuse to go to bed',
          'Monday morning, lost backpack',
          'Toy explosion in the living room',
          'Spaghetti dinner, three opinions',
        ];
      case AppLanguage.italian:
        return const [
          'I bambini non vogliono dormire',
          'Lunedì mattina, zaino sparito',
          'Esplosione di giocattoli in salotto',
          'Cena con la pasta, tre opinioni diverse',
        ];
    }
  }
}
