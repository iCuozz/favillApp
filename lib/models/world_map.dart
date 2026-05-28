// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:ui';

/// Una quest legata a una location, corrisponde a un episodio/scena narrativa.
class WorldQuest {
  final String id;
  final String title;
  final String subtitle;
  final String file;
  final String thumbnail;
  final int season;

  /// Ids delle quest che devono essere completate prima di questa.
  final List<String> requiresCompleted;

  /// Stat minime richieste per sbloccarla, es. {"segreto": 30}.
  final Map<String, int> requiresStats;

  const WorldQuest({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.file,
    required this.thumbnail,
    required this.season,
    this.requiresCompleted = const [],
    this.requiresStats = const {},
  });

  factory WorldQuest.fromJson(Map<String, dynamic> json) {
    final completed = (json['requires_completed'] as List<dynamic>? ?? [])
        .cast<String>();
    final statsJson = json['requires_stats'] as Map<String, dynamic>? ?? {};
    final stats = statsJson.map((k, v) => MapEntry(k, v as int));

    return WorldQuest(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      file: json['file'] as String,
      thumbnail: json['thumbnail'] as String? ?? '',
      season: json['season'] as int? ?? 1,
      requiresCompleted: completed,
      requiresStats: stats,
    );
  }
}

/// Una location della mappa di Nova Tutinia.
class WorldLocation {
  final String id;
  final String name;
  final String emoji;
  final String description;

  /// Posizione relativa sulla mappa (0.0–1.0).
  final Offset position;

  /// Se true, disponibile fin dall'inizio senza sblocco.
  final bool unlockedByDefault;

  /// Id della quest il cui completamento sblocca questa location.
  final String? unlockAfterQuest;

  /// Stat che devono essere SOTTO questa soglia per sbloccare la location
  /// (verificate al momento del completamento di unlockAfterQuest).
  final Map<String, int> unlockIfStatLt;

  /// Stat che devono essere SOPRA O UGUALI a questa soglia per sbloccare la location
  /// (verificate al momento del completamento di unlockAfterQuest).
  final Map<String, int> unlockIfStatGte;

  final List<WorldQuest> quests;

  const WorldLocation({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.position,
    this.unlockedByDefault = false,
    this.unlockAfterQuest,
    this.unlockIfStatLt = const {},
    this.unlockIfStatGte = const {},
    this.quests = const [],
  });

  /// Restituisce true se le condizioni stat (se presenti) sono soddisfatte.
  bool areStatConditionsMet(Map<String, int> stats) {
    for (final entry in unlockIfStatLt.entries) {
      if ((stats[entry.key] ?? 0) >= entry.value) return false;
    }
    for (final entry in unlockIfStatGte.entries) {
      if ((stats[entry.key] ?? 0) < entry.value) return false;
    }
    return true;
  }

  factory WorldLocation.fromJson(Map<String, dynamic> json) {
    final posJson = json['position'] as Map<String, dynamic>? ?? {};
    final questsJson = (json['quests'] as List<dynamic>? ?? []);
    final statLtJson = json['unlock_if_stat_lt'] as Map<String, dynamic>? ?? {};
    final statGteJson = json['unlock_if_stat_gte'] as Map<String, dynamic>? ?? {};

    return WorldLocation(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '📍',
      description: json['description'] as String? ?? '',
      position: Offset(
        (posJson['x'] as num?)?.toDouble() ?? 0.5,
        (posJson['y'] as num?)?.toDouble() ?? 0.5,
      ),
      unlockedByDefault: json['unlocked_by_default'] as bool? ?? false,
      unlockAfterQuest: json['unlock_after_quest'] as String?,
      unlockIfStatLt: statLtJson.map((k, v) => MapEntry(k, v as int)),
      unlockIfStatGte: statGteJson.map((k, v) => MapEntry(k, v as int)),
      quests: questsJson
          .map((q) => WorldQuest.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// La mappa del mondo: tutte le location di Nova Tutinia.
class WorldMap {
  final List<WorldLocation> locations;

  const WorldMap({required this.locations});

  WorldLocation? locationById(String id) {
    for (final loc in locations) {
      if (loc.id == id) return loc;
    }
    return null;
  }

  WorldQuest? questById(String id) {
    for (final loc in locations) {
      for (final q in loc.quests) {
        if (q.id == id) return q;
      }
    }
    return null;
  }

  factory WorldMap.fromJson(Map<String, dynamic> json) {
    final locsJson = (json['locations'] as List<dynamic>? ?? []);
    return WorldMap(
      locations: locsJson
          .map((l) => WorldLocation.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Stato corrente del mondo: location sbloccate + quest completate.
class WorldState {
  final Set<String> unlockedLocations;
  final Set<String> completedQuests;

  const WorldState({
    this.unlockedLocations = const {},
    this.completedQuests = const {},
  });

  bool isLocationUnlocked(WorldLocation loc) =>
      loc.unlockedByDefault || unlockedLocations.contains(loc.id);

  bool isQuestCompleted(String questId) => completedQuests.contains(questId);

  bool isQuestAvailable(WorldQuest quest, Map<String, int> currentStats) {
    for (final req in quest.requiresCompleted) {
      if (!completedQuests.contains(req)) return false;
    }
    for (final entry in quest.requiresStats.entries) {
      if ((currentStats[entry.key] ?? 0) < entry.value) return false;
    }
    return true;
  }

  WorldState copyWith({
    Set<String>? unlockedLocations,
    Set<String>? completedQuests,
  }) =>
      WorldState(
        unlockedLocations: unlockedLocations ?? this.unlockedLocations,
        completedQuests: completedQuests ?? this.completedQuests,
      );
}
