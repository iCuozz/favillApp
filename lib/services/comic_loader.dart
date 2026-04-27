import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/comic_data.dart';
import 'settings_service.dart';

class ComicLoader {
  /// Per un asset come `assets/data/foo.json` prova a caricare prima
  /// `assets/data/foo.<lang>.json` (se non italiano) e fa fallback al file
  /// originale se la versione localizzata non esiste.
  static Future<String> _loadLocalized(String assetPath) async {
    final lang = SettingsService.language.value;
    if (lang != AppLanguage.italian && assetPath.endsWith('.json')) {
      final localized =
          '${assetPath.substring(0, assetPath.length - 5)}.${lang.code}.json';
      try {
        return await rootBundle.loadString(localized);
      } catch (_) {
        // fallback al file di default
      }
    }
    return rootBundle.loadString(assetPath);
  }

  static Future<ComicIndex> loadIndex() async {
    final jsonString = await _loadLocalized('assets/data/comic_index.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return ComicIndex.fromJson(jsonMap);
  }

  static Future<EpisodeContent> loadEpisodeContent(String assetPath) async {
    final jsonString = await _loadLocalized(assetPath);
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return EpisodeContent.fromJson(jsonMap);
  }
}
