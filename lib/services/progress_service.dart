import 'package:shared_preferences/shared_preferences.dart';

class ReadingProgress {
  final String episodeId;
  final int pageIndex;
  final int visibleBlocks;

  const ReadingProgress({
    required this.episodeId,
    required this.pageIndex,
    required this.visibleBlocks,
  });
}

class ProgressService {
  static const _kCurrentEpisodeId = 'progress.current.episodeId';
  static const _kCurrentPageIndex = 'progress.current.pageIndex';
  static const _kCurrentVisibleBlocks = 'progress.current.visibleBlocks';
  static const _kCompletedEpisodes = 'progress.completedEpisodes';

  static Future<ReadingProgress?> loadCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final episodeId = prefs.getString(_kCurrentEpisodeId);
    if (episodeId == null || episodeId.isEmpty) return null;

    return ReadingProgress(
      episodeId: episodeId,
      pageIndex: prefs.getInt(_kCurrentPageIndex) ?? 0,
      visibleBlocks: prefs.getInt(_kCurrentVisibleBlocks) ?? 1,
    );
  }

  static Future<void> saveCurrent({
    required String episodeId,
    required int pageIndex,
    required int visibleBlocks,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentEpisodeId, episodeId);
    await prefs.setInt(_kCurrentPageIndex, pageIndex);
    await prefs.setInt(_kCurrentVisibleBlocks, visibleBlocks);
  }

  static Future<void> clearCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentEpisodeId);
    await prefs.remove(_kCurrentPageIndex);
    await prefs.remove(_kCurrentVisibleBlocks);
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
    await prefs.remove(_kCompletedEpisodes);
  }
}
