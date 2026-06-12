// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

/// Stat keys per il sistema RPG di Favilla Blaze.
class StatKey {
  static const segreto = 'segreto';
  static const legame = 'legame';
  static const scintille = 'scintille';
  static const resistenza = 'resistenza';

  static const all = [segreto, legame, scintille, resistenza];

  /// Floor minimi per ciascuna stat.
  /// Segreto resta sempre > 0 per garantire la tenuta narrativa.
  /// Resistenza parte da 1 per evitare crisi non ancora scritte.
  static const Map<String, int> minValues = {
    segreto: 5,
    legame: 0,
    scintille: 0,
    resistenza: 1,
  };
}

/// Stato globale del gioco: le 4 stat di Favilla + world flags booleani.
///
/// I [flags] tracciano scelte narrative specifiche cross-episodio
/// (es. "shirt_in_backpack") che non possono essere dedotte
/// in modo affidabile dalle sole stat numeriche.
///
/// I flag assenti sono semanticamente equivalenti a [false].
class GameState {
  final int segreto;
  final int legame;
  final int scintille;
  final int resistenza;

  /// World flags: Map<flagName, bool>. Immutabile per design.
  final Map<String, bool> flags;

  /// Memoria narrativa persistente: Map<key, value>.
  /// Permette callback testuali coerenti tra episodi.
  final Map<String, String> memories;

  /// Ultimo episodio in cui è stato usato l'espresso.
  /// Traccia il cooldown: disponibile ogni 3 episodi a partire dal 3.
  final int? lastCaffeEpisode;

  const GameState({
    this.segreto = 50,
    this.legame = 50,
    this.scintille = 50,
    this.resistenza = 50,
    this.flags = const {},
    this.memories = const {},
    this.lastCaffeEpisode,
  });

  int operator [](String key) {
    switch (key) {
      case StatKey.segreto:
        return segreto;
      case StatKey.legame:
        return legame;
      case StatKey.scintille:
        return scintille;
      case StatKey.resistenza:
        return resistenza;
      default:
        return 0;
    }
  }

  /// Applica effetti sulle stat + aggiorna i flags atomicamente.
  /// I flags esistenti non menzionati in [newFlags] vengono preservati.
  GameState applyChoice({
    Map<String, int> effects = const {},
    Map<String, bool> newFlags = const {},
    Map<String, String> newMemories = const {},
    int? newLastCaffeEpisode,
  }) {
    int clamp(String key, int value) =>
        value.clamp(StatKey.minValues[key] ?? 0, 100);
    final mergedFlags = {...flags, ...newFlags};
    final mergedMemories = {...memories, ...newMemories};
    mergedMemories.removeWhere((key, value) => key.isEmpty || value.isEmpty);
    return GameState(
      segreto:
          clamp(StatKey.segreto, segreto + (effects[StatKey.segreto] ?? 0)),
      legame: clamp(StatKey.legame, legame + (effects[StatKey.legame] ?? 0)),
      scintille: clamp(
          StatKey.scintille, scintille + (effects[StatKey.scintille] ?? 0)),
      resistenza: clamp(
          StatKey.resistenza, resistenza + (effects[StatKey.resistenza] ?? 0)),
      flags: Map.unmodifiable(mergedFlags),
      memories: Map.unmodifiable(mergedMemories),
      lastCaffeEpisode: newLastCaffeEpisode ?? lastCaffeEpisode,
    );
  }

  /// Retrocompatibilità: applica solo effetti stat (nessun cambio flag).
  GameState applyEffects(Map<String, int> effects) =>
      applyChoice(effects: effects);

  /// Solo stat, usata per serializzazione e stat_entry matching.
  Map<String, int> toStatsMap() => {
        StatKey.segreto: segreto,
        StatKey.legame: legame,
        StatKey.scintille: scintille,
        StatKey.resistenza: resistenza,
      };

  /// @deprecated Usa [toStatsMap]. Mantenuto per retrocompatibilità.
  Map<String, int> toMap() => toStatsMap();

  factory GameState.fromMaps({
    required Map<String, int> stats,
    Map<String, bool> flags = const {},
    Map<String, String> memories = const {},
    int? lastCaffeEpisode,
  }) =>
      GameState(
        segreto: stats[StatKey.segreto] ?? 50,
        legame: stats[StatKey.legame] ?? 50,
        scintille: stats[StatKey.scintille] ?? 50,
        resistenza: stats[StatKey.resistenza] ?? 50,
        flags: Map.unmodifiable(flags),
        memories: Map.unmodifiable(memories),
        lastCaffeEpisode: lastCaffeEpisode,
      );

  /// @deprecated Usa [GameState.fromMaps]. Mantenuto per retrocompatibilità.
  factory GameState.fromMap(Map<String, int> map) =>
      GameState.fromMaps(stats: map);
}
