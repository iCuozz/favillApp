import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/comic_data.dart';

class ComicLoader {
  static Future<ComicData> load() async {
    final jsonString = await rootBundle.loadString('data/comic_data.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return ComicData.fromJson(jsonMap);
  }
}