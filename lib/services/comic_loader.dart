import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/comic_data.dart';

class ComicLoader {
  static Future<ComicIndex> loadIndex() async {
    final jsonString =
        await rootBundle.loadString('assets/data/comic_index.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return ComicIndex.fromJson(jsonMap);
  }

  static Future<EpisodeContent> loadEpisodeContent(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return EpisodeContent.fromJson(jsonMap);
  }
}
