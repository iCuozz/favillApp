// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/world_map.dart';

/// Persiste e notifica lo stato della mappa del mondo:
/// location sbloccate e quest completate.
class WorldStateService {
  WorldStateService._();
  static final instance = WorldStateService._();

  static const _kUnlockedLocations = 'world.unlockedLocations';
  static const _kCompletedQuests = 'world.completedQuests';

  final ValueNotifier<WorldState> state = ValueNotifier(const WorldState());

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked =
        (prefs.getStringList(_kUnlockedLocations) ?? []).toSet();
    final completed =
        (prefs.getStringList(_kCompletedQuests) ?? []).toSet();
    state.value = WorldState(
      unlockedLocations: unlocked,
      completedQuests: completed,
    );
  }

  Future<void> unlockLocation(String locationId) async {
    final current = state.value;
    if (current.unlockedLocations.contains(locationId)) return;
    final next = current.copyWith(
      unlockedLocations: {...current.unlockedLocations, locationId},
    );
    state.value = next;
    await _persist(next);
  }

  Future<void> completeQuest(
    String questId, {
    WorldMap? worldMap,
    Map<String, int>? currentStats,
  }) async {
    final current = state.value;
    if (current.completedQuests.contains(questId)) return;
    final next = current.copyWith(
      completedQuests: {...current.completedQuests, questId},
    );
    state.value = next;
    await _persist(next);

    // Sblocca automaticamente le location che dipendono da questa quest,
    // rispettando eventuali condizioni sulle stat.
    if (worldMap != null) {
      for (final loc in worldMap.locations) {
        if (loc.unlockAfterQuest == questId &&
            !next.unlockedLocations.contains(loc.id)) {
          final statsMet = currentStats == null || loc.areStatConditionsMet(currentStats);
          if (statsMet) {
            await unlockLocation(loc.id);
          }
        }
      }
    }
  }

  Future<void> reset() async {
    state.value = const WorldState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUnlockedLocations);
    await prefs.remove(_kCompletedQuests);
  }

  Future<void> _persist(WorldState ws) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _kUnlockedLocations, ws.unlockedLocations.toList());
    await prefs.setStringList(
        _kCompletedQuests, ws.completedQuests.toList());
  }
}
