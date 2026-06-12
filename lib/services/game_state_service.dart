// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';

/// Persiste e notifica lo stato RPG del gioco (le 4 stat + world flags di Favilla).
class GameStateService {
  GameStateService._();
  static final instance = GameStateService._();

  static const _prefix = 'game_state.';
  static const _kFlags = '${_prefix}flags';
  static const _kMemories = '${_prefix}memories';
  static const _kLastCaffeEpisode = '${_prefix}last_caffe_episode';

  final ValueNotifier<GameState> state = ValueNotifier(const GameState());
  
  /// Traccia l'episodio corrente (es: "s1_mare" = episodio 1, "s1_domenica_parco" = episodio 2, etc.)
  String? _currentQuestId;

  /// Mappa questId → episodeNumber per il calcolo del cooldown dell'espresso
  static const Map<String, int> _episodeMap = {
    's1_centro_commerciale': 1,
    's1_domenica_parco': 2,
    's1_lunedi_asilo': 3,
    's1_mare': 4,
    's1_mattina_dopo': 5,
    's1_palestra': 6,
    's1_ritorno_casa': 7,
    's1_scuola_1': 8,
    's1_spesa_sabato': 9,
  };

  /// Getter per l'episodio corrente (1-9)
  int get currentEpisodeNumber => _episodeMap[_currentQuestId] ?? 0;

  /// QuestId dell'episodio corrente (es: "prologo", "s1_mattina_dopo", ecc.)
  String? get currentQuestId => _currentQuestId;

  /// Setter per tracciare il questId corrente
  void setCurrentQuest(String questId) {
    _currentQuestId = questId;
  }

  GameState get gameState => state.value;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = <String, int>{};
    for (final key in StatKey.all) {
      final stored = prefs.getInt('$_prefix$key');
      if (stored != null) stats[key] = stored;
    }
    final flagsJson = prefs.getString(_kFlags);
    final memoriesJson = prefs.getString(_kMemories);
    final lastCaffeEpisode = prefs.getInt(_kLastCaffeEpisode);
    final flags = <String, bool>{};
    final memories = <String, String>{};
    if (flagsJson != null) {
      final decoded = jsonDecode(flagsJson) as Map<String, dynamic>;
      decoded.forEach((k, v) {
        if (v is bool) flags[k] = v;
      });
    }
    if (memoriesJson != null) {
      final decoded = jsonDecode(memoriesJson) as Map<String, dynamic>;
      decoded.forEach((k, v) {
        final key = k.trim();
        if (key.isEmpty) return;
        final value = switch (v) {
          final String s => s.trim(),
          final int n => n.toString(),
          final double n => n.toString(),
          final bool b => b.toString(),
          _ => '',
        };
        if (value.isNotEmpty) memories[key] = value;
      });
    }
    if (stats.isNotEmpty || flags.isNotEmpty || memories.isNotEmpty) {
      state.value = GameState.fromMaps(
        stats: stats,
        flags: flags,
        memories: memories,
        lastCaffeEpisode: lastCaffeEpisode,
      );
    }
  }

  /// Applica effetti sulle stat e aggiorna i flags atomicamente.
  /// Un solo aggiornamento del ValueNotifier e una sola scrittura su disco.
  Future<void> applyChoice({
    Map<String, int> effects = const {},
    Map<String, bool> newFlags = const {},
    Map<String, String> newMemories = const {},
    int? currentEpisodeForCaffe,
  }) async {
    if (effects.isEmpty && newFlags.isEmpty && newMemories.isEmpty) return;
    final next = state.value.applyChoice(
      effects: effects,
      newFlags: newFlags,
      newMemories: newMemories,
      newLastCaffeEpisode: currentEpisodeForCaffe,
    );
    state.value = next;
    await _persist(next);
  }

  /// Retrocompatibilità: applica solo effetti stat.
  Future<void> applyEffects(Map<String, int> effects) =>
      applyChoice(effects: effects);

  Future<void> reset() async {
    state.value = const GameState();
    final prefs = await SharedPreferences.getInstance();
    for (final key in StatKey.all) {
      await prefs.remove('$_prefix$key');
    }
    await prefs.remove(_kFlags);
    await prefs.remove(_kMemories);
    await prefs.remove(_kLastCaffeEpisode);
  }

  Future<void> _persist(GameState gs) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in StatKey.all) {
      await prefs.setInt('$_prefix$key', gs[key]);
    }
    if (gs.flags.isEmpty) {
      await prefs.remove(_kFlags);
    } else {
      await prefs.setString(_kFlags, jsonEncode(gs.flags));
    }
    if (gs.memories.isEmpty) {
      await prefs.remove(_kMemories);
    } else {
      await prefs.setString(_kMemories, jsonEncode(gs.memories));
    }
    if (gs.lastCaffeEpisode != null) {
      await prefs.setInt(_kLastCaffeEpisode, gs.lastCaffeEpisode!);
    } else {
      await prefs.remove(_kLastCaffeEpisode);
    }
  }
}
