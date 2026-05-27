import 'package:shared_preferences/shared_preferences.dart';

class ReadingProgress {
  final String episodeId;
  final int pageIndex;
  final int visibleBlocks;

  /// Id del branch narrativo attivo, o null se l'utente è sul percorso principale
  /// o se l'episodio non ha branching.
  final String? branchId;

  /// Id del branch di entry (stat_entry) attivo all'avvio dell'episodio.
  /// Salvato per garantire coerenza degli indici di pagina anche se le stat cambiano
  /// durante l'episodio.
  final String? entryBranchId;

  const ReadingProgress({
    required this.episodeId,
    required this.pageIndex,
    required this.visibleBlocks,
    this.branchId,
    this.entryBranchId,
  });
}

class ProgressService {
  static const _kCurrentEpisodeId = 'progress.current.episodeId';
  static const _kCurrentPageIndex = 'progress.current.pageIndex';
  static const _kCurrentVisibleBlocks = 'progress.current.visibleBlocks';
  static const _kCurrentBranchId = 'progress.current.branchId';
  static const _kCurrentEntryBranchId = 'progress.current.entryBranchId';
  static const _kCompletedEpisodes = 'progress.completedEpisodes';

  static Future<ReadingProgress?> loadCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final episodeId = prefs.getString(_kCurrentEpisodeId);
    if (episodeId == null || episodeId.isEmpty) return null;

    final branchId = prefs.getString(_kCurrentBranchId);
    final entryBranchId = prefs.getString(_kCurrentEntryBranchId);

    return ReadingProgress(
      episodeId: episodeId,
      pageIndex: prefs.getInt(_kCurrentPageIndex) ?? 0,
      visibleBlocks: prefs.getInt(_kCurrentVisibleBlocks) ?? 1,
      branchId: (branchId != null && branchId.isNotEmpty) ? branchId : null,
      entryBranchId: (entryBranchId != null && entryBranchId.isNotEmpty) ? entryBranchId : null,
    );
  }

  static Future<void> saveCurrent({
    required String episodeId,
    required int pageIndex,
    required int visibleBlocks,
    String? branchId,
    String? entryBranchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentEpisodeId, episodeId);
    await prefs.setInt(_kCurrentPageIndex, pageIndex);
    await prefs.setInt(_kCurrentVisibleBlocks, visibleBlocks);
    if (branchId == null || branchId.isEmpty) {
      await prefs.remove(_kCurrentBranchId);
    } else {
      await prefs.setString(_kCurrentBranchId, branchId);
    }
    if (entryBranchId == null || entryBranchId.isEmpty) {
      await prefs.remove(_kCurrentEntryBranchId);
    } else {
      await prefs.setString(_kCurrentEntryBranchId, entryBranchId);
    }
  }

  static Future<void> clearCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentEpisodeId);
    await prefs.remove(_kCurrentPageIndex);
    await prefs.remove(_kCurrentVisibleBlocks);
    await prefs.remove(_kCurrentBranchId);
    await prefs.remove(_kCurrentEntryBranchId);
  }

  static Future<Set<String>> loadCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kCompletedEpisodes) ?? <String>[]).toSet();
  }

  static Future<void> markCompleted(String episodeId) async {
    final prefs = await SharedPreferences.getInstance();
    final current =
        (prefs.getStringList(_kCompletedEpisodes) ?? <String>[]).toSet();
    current.add(episodeId);
    await prefs.setStringList(_kCompletedEpisodes, current.toList());
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentEpisodeId);
    await prefs.remove(_kCurrentPageIndex);
    await prefs.remove(_kCurrentVisibleBlocks);
    await prefs.remove(_kCurrentBranchId);
    await prefs.remove(_kCurrentEntryBranchId);
    await prefs.remove(_kCompletedEpisodes);
  }
}
