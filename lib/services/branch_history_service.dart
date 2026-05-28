// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'package:shared_preferences/shared_preferences.dart';

/// Tiene traccia dei branch (finali alternativi) sbloccati dal lettore,
/// per episodio. Usato per mostrare progressi del tipo "1/3 finali sbloccati"
/// e per offrire il replay.
class BranchHistoryService {
  static String _key(String episodeId) => 'branchHistory.$episodeId';

  static Future<Set<String>> getUnlocked(String episodeId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key(episodeId)) ?? const <String>[]).toSet();
  }

  static Future<void> markUnlocked(String episodeId, String branchId) async {
    if (branchId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current =
        (prefs.getStringList(_key(episodeId)) ?? const <String>[]).toSet();
    if (current.add(branchId)) {
      await prefs.setStringList(_key(episodeId), current.toList());
    }
  }

  static Future<void> reset(String episodeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(episodeId));
  }

  /// Cancella la cronologia branch per tutti gli episodi noti.
  static Future<void> resetAll(Iterable<String> episodeIds) async {
    final prefs = await SharedPreferences.getInstance();
    for (final id in episodeIds) {
      await prefs.remove(_key(id));
    }
  }
}
