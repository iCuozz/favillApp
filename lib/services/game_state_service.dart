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

  final ValueNotifier<GameState> state = ValueNotifier(const GameState());

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = <String, int>{};
    for (final key in StatKey.all) {
      final stored = prefs.getInt('$_prefix$key');
      if (stored != null) stats[key] = stored;
    }
    final flagsJson = prefs.getString(_kFlags);
    final flags = <String, bool>{};
    if (flagsJson != null) {
      final decoded = jsonDecode(flagsJson) as Map<String, dynamic>;
      decoded.forEach((k, v) {
        if (v is bool) flags[k] = v;
      });
    }
    if (stats.isNotEmpty || flags.isNotEmpty) {
      state.value = GameState.fromMaps(stats: stats, flags: flags);
    }
  }

  /// Applica effetti sulle stat e aggiorna i flags atomicamente.
  /// Un solo aggiornamento del ValueNotifier e una sola scrittura su disco.
  Future<void> applyChoice({
    Map<String, int> effects = const {},
    Map<String, bool> newFlags = const {},
  }) async {
    if (effects.isEmpty && newFlags.isEmpty) return;
    final next = state.value.applyChoice(effects: effects, newFlags: newFlags);
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
  }
}
