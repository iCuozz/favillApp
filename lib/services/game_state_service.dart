import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';

/// Persiste e notifica lo stato RPG del gioco (le 4 stat di Favilla).
class GameStateService {
  GameStateService._();
  static final instance = GameStateService._();

  static const _prefix = 'game_state.';

  final ValueNotifier<GameState> state = ValueNotifier(const GameState());

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, int>{};
    for (final key in StatKey.all) {
      final stored = prefs.getInt('$_prefix$key');
      if (stored != null) map[key] = stored;
    }
    if (map.isNotEmpty) {
      state.value = GameState.fromMap(map);
    }
  }

  Future<void> applyEffects(Map<String, int> effects) async {
    if (effects.isEmpty) return;
    final next = state.value.applyEffects(effects);
    state.value = next;
    await _persist(next);
  }

  Future<void> reset() async {
    state.value = const GameState();
    final prefs = await SharedPreferences.getInstance();
    for (final key in StatKey.all) {
      await prefs.remove('$_prefix$key');
    }
  }

  Future<void> _persist(GameState gs) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in StatKey.all) {
      await prefs.setInt('$_prefix$key', gs[key]);
    }
  }
}
