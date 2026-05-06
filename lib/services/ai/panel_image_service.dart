import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'ai_client.dart';
import 'client_id.dart';
import 'mission_generator_service.dart';

/// Cliente per `/v1/panel-image`. Non passa per [AiClient.post] perché
/// la risposta è binaria (image/jpeg).
///
/// Cache su filesystem locale: chiave deterministica
/// `missionId-panelIndex` ⇒ stesso file sempre.
class PanelImageService {
  PanelImageService._();
  static final PanelImageService instance = PanelImageService._();

  static const String _kFolder = 'ai_panel_images';

  String? _appVersionCache;
  Future<String> _appVersion() async {
    if (_appVersionCache != null) return _appVersionCache!;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersionCache = info.version;
    } catch (_) {
      _appVersionCache = '0.0.0';
    }
    return _appVersionCache!;
  }

  Future<Directory> _cacheDir() async {
    if (kIsWeb) {
      throw const FileSystemException('Filesystem cache non disponibile su web.');
    }
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/$_kFolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _fileKey(String missionId, int panelIndex) {
    final raw = '$missionId|$panelIndex';
    final hash = sha1.convert(utf8.encode(raw)).toString();
    return '$hash.jpg';
  }

  /// Ritorna il File locale se già in cache.
  Future<File?> cachedFile(String missionId, int panelIndex) async {
    if (kIsWeb) return null;
    final dir = await _cacheDir();
    final f = File('${dir.path}/${_fileKey(missionId, panelIndex)}');
    if (await f.exists() && await f.length() > 0) return f;
    return null;
  }

  /// Scarica + salva il PNG/JPEG e ritorna il File. Se l'AI è disabilitata
  /// o c'è un errore, ritorna null senza lanciare (la UI mostrerà il
  /// fallback procedurale).
  Future<File?> fetchAndCache({
    required GeneratedMission mission,
    required int panelIndex,
    Duration timeout = const Duration(seconds: 50),
  }) async {
    if (kIsWeb || !AiClient.instance.enabled) return null;

    final cached = await cachedFile(mission.id, panelIndex);
    if (cached != null) return cached;

    final panel = mission.panels[panelIndex];
    final scene = (panel.sceneDescription ?? '').trim();
    if (scene.isEmpty) return null;

    final url = Uri.parse('${AiClient.baseUrl}/v1/panel-image');
    final clientId = await ClientId.get();
    final appVersion = await _appVersion();

    http.Response res;
    try {
      res = await http.post(
        url,
        headers: {
          'content-type': 'application/json',
          'x-client-id': clientId,
          'x-app-version': appVersion,
        },
        body: jsonEncode({
          'missionSeed': mission.id,
          'panelIndex': panelIndex,
          'sceneDescription': scene,
          'characters': panel.characters,
        }),
      ).timeout(timeout);
    } on TimeoutException {
      if (kDebugMode) debugPrint('panel-image timeout');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('panel-image network error: $e');
      return null;
    }

    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      if (kDebugMode) {
        debugPrint('panel-image http ${res.statusCode}: '
            '${res.body.length > 200 ? res.body.substring(0, 200) : res.body}');
      }
      return null;
    }

    try {
      final dir = await _cacheDir();
      final f = File('${dir.path}/${_fileKey(mission.id, panelIndex)}');
      await f.writeAsBytes(res.bodyBytes, flush: true);
      return f;
    } catch (e) {
      if (kDebugMode) debugPrint('panel-image disk write failed: $e');
      return null;
    }
  }

  /// Cancella le immagini cachate di una missione (chiamato in delete()).
  Future<void> deleteForMission(String missionId, int panelCount) async {
    if (kIsWeb) return;
    try {
      final dir = await _cacheDir();
      for (var i = 0; i < panelCount; i++) {
        final f = File('${dir.path}/${_fileKey(missionId, i)}');
        if (await f.exists()) await f.delete();
      }
    } catch (_) {/* best effort */}
  }
}
