import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../settings_service.dart';
import 'ai_client.dart';
import 'ai_rate_limiter.dart';

/// Possibili tag di scena (devono coincidere con quelli accettati dal worker
/// in `worker/src/handlers/branch.ts`).
const List<String> kBranchSceneTags = [
  'kitchen_calm',
  'kitchen_chaos',
  'living_calm',
  'living_chaos',
  'bedroom_night',
  'bathroom',
  'street',
  'supermarket',
  'blaze_aura',
  'victory_glow',
  'sad_rain',
  'funny_explosion',
];

class BranchBlock {
  final String type;
  final String speaker;
  final String text;
  BranchBlock({required this.type, required this.speaker, required this.text});

  factory BranchBlock.fromJson(Map<String, dynamic> j) => BranchBlock(
        type: (j['type'] ?? 'narration') as String,
        speaker: (j['speaker'] ?? 'narrator') as String,
        text: ((j['text'] ?? '') as String).trim(),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'speaker': speaker,
        'text': text,
      };
}

class BranchChoice {
  final String id;
  final String label;
  BranchChoice({required this.id, required this.label});

  factory BranchChoice.fromJson(Map<String, dynamic> j) => BranchChoice(
        id: (j['id'] ?? '') as String,
        label: (j['label'] ?? '') as String,
      );
}

class BranchNode {
  final String sceneTag;
  final List<BranchBlock> blocks;
  final List<BranchChoice> choices;
  final bool isEnding;
  final String? endingTitle;
  final int depth;

  BranchNode({
    required this.sceneTag,
    required this.blocks,
    required this.choices,
    required this.isEnding,
    required this.endingTitle,
    required this.depth,
  });

  factory BranchNode.fromJson(Map<String, dynamic> j) {
    final page = (j['page'] as Map<String, dynamic>?) ?? {};
    return BranchNode(
      sceneTag: (page['sceneTag'] ?? 'living_calm') as String,
      blocks: ((page['blocks'] as List<dynamic>?) ?? [])
          .map((e) => BranchBlock.fromJson(e as Map<String, dynamic>))
          .toList(),
      choices: ((j['choices'] as List<dynamic>?) ?? [])
          .map((e) => BranchChoice.fromJson(e as Map<String, dynamic>))
          .toList(),
      isEnding: (j['isEnding'] as bool?) ?? false,
      endingTitle: j['endingTitle'] as String?,
      depth: (j['depth'] as int?) ?? 0,
    );
  }
}

/// Una entry della cronologia: la scelta presa + un riassunto della scena
/// risultante (1 frase). Mandata di nuovo al worker per dare contesto.
class BranchHistoryItem {
  final String choice;
  final String summary;
  BranchHistoryItem({required this.choice, required this.summary});

  Map<String, dynamic> toJson() => {'choice': choice, 'summary': summary};
}

class BranchSession {
  final String seed;
  final List<BranchHistoryItem> history;
  BranchNode? current;
  int depth;

  BranchSession({required this.seed, required this.depth, required this.history, this.current});
}

class BranchService {
  BranchService._();
  static final BranchService instance = BranchService._();

  static const String _kStorageKey = 'ai.branch.lastSession';

  final AiRateLimiter limiter =
      const AiRateLimiter(endpoint: 'branch', perDay: 30);

  /// Avvia una nuova storia con uno spunto.
  Future<({BranchSession session, BranchNode node})> start(String seed) async {
    final session = BranchSession(seed: seed, depth: 0, history: []);
    final node = await _step(session, lastChoice: null);
    session.current = node;
    session.depth = node.depth;
    await _persist(session);
    return (session: session, node: node);
  }

  /// Avanza la storia con la scelta selezionata.
  Future<BranchNode> choose(BranchSession session, BranchChoice choice) async {
    final summary = (session.current?.blocks.isNotEmpty == true)
        ? session.current!.blocks.map((b) => b.text).join(' ')
        : '';
    session.history.add(BranchHistoryItem(
      choice: choice.label,
      summary: summary.length > 200 ? summary.substring(0, 200) : summary,
    ));
    final node = await _step(session, lastChoice: choice.label);
    session.current = node;
    session.depth = node.depth + 1;
    await _persist(session);
    return node;
  }

  Future<BranchNode> _step(
    BranchSession session, {
    required String? lastChoice,
  }) async {
    final lang = SettingsService.language.value.code;
    final res = await AiClient.instance.post(
      'branch',
      {
        'seed': session.seed,
        'history': session.history.map((h) => h.toJson()).toList(),
        'lastChoice': lastChoice,
        'depth': session.depth,
        'lang': lang,
      },
      limiter: limiter,
      timeout: const Duration(seconds: 35),
    );
    return BranchNode.fromJson(res);
  }

  Future<void> _persist(BranchSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStorageKey, jsonEncode({
        'seed': session.seed,
        'depth': session.depth,
        'history': session.history.map((h) => h.toJson()).toList(),
      }));
    } catch (_) {/* best-effort */}
  }
}
