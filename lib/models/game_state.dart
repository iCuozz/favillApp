/// Stat keys per il sistema RPG di Favilla Blaze.
class StatKey {
  static const segreto = 'segreto';
  static const legame = 'legame';
  static const scintille = 'scintille';
  static const resistenza = 'resistenza';

  static const all = [segreto, legame, scintille, resistenza];
}

/// Stato globale del gioco: le 4 stat di Favilla.
/// Ogni stat è un intero 0–100.
class GameState {
  final int segreto;
  final int legame;
  final int scintille;
  final int resistenza;

  const GameState({
    this.segreto = 50,
    this.legame = 50,
    this.scintille = 50,
    this.resistenza = 50,
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

  GameState applyEffects(Map<String, int> effects) {
    return GameState(
      segreto: (segreto + (effects[StatKey.segreto] ?? 0)).clamp(0, 100),
      legame: (legame + (effects[StatKey.legame] ?? 0)).clamp(0, 100),
      scintille: (scintille + (effects[StatKey.scintille] ?? 0)).clamp(0, 100),
      resistenza:
          (resistenza + (effects[StatKey.resistenza] ?? 0)).clamp(0, 100),
    );
  }

  Map<String, int> toMap() => {
        StatKey.segreto: segreto,
        StatKey.legame: legame,
        StatKey.scintille: scintille,
        StatKey.resistenza: resistenza,
      };

  factory GameState.fromMap(Map<String, int> map) => GameState(
        segreto: map[StatKey.segreto] ?? 50,
        legame: map[StatKey.legame] ?? 50,
        scintille: map[StatKey.scintille] ?? 50,
        resistenza: map[StatKey.resistenza] ?? 50,
      );
}
