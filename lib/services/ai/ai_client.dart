import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../settings_service.dart';
import 'ai_cache.dart';
import 'ai_rate_limiter.dart';
import 'client_id.dart';

/// Eccezione user-facing per qualunque errore del Worker AI.
class AiException implements Exception {
  final String code;
  final String message;
  final int? status;

  AiException(this.code, this.message, {this.status});

  @override
  String toString() => 'AiException($code, $status): $message';
}

/// Client HTTP verso il Cloudflare Worker.
///
/// Il base URL viene iniettato a build time:
/// `flutter run --dart-define=AI_BASE_URL=https://...workers.dev`.
/// Se non fornito, il client risulta `disabled` e tutte le feature AI
/// degradano gracefully.
class AiClient {
  AiClient._();
  static final AiClient instance = AiClient._();

  static const String baseUrl =
      String.fromEnvironment('AI_BASE_URL', defaultValue: '');

  bool get enabled => baseUrl.isNotEmpty;

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

  /// POST verso `/v1/<endpoint>` con cache + rate limit opzionali.
  ///
  /// - [cacheable]: se true, prima di chiamare il Worker controlla
  ///   [AiCache] e in caso positivo ritorna senza consumare quota.
  /// - [limiter]: se fornito, controlla la quota locale e la consuma in
  ///   caso di chiamata effettiva (non in caso di cache hit).
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> payload, {
    bool cacheable = false,
    AiRateLimiter? limiter,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!enabled) {
      throw AiException('ai_disabled',
          'AI base URL non configurato (build con --dart-define=AI_BASE_URL).');
    }

    if (cacheable) {
      final cached = await AiCache.read(endpoint, payload);
      if (cached != null) {
        try {
          return jsonDecode(cached) as Map<String, dynamic>;
        } catch (_) {/* cache invalidata, prosegui */}
      }
    }

    if (limiter != null && !await limiter.canConsume()) {
      throw AiQuotaExceeded(endpoint);
    }

    final clientId = await ClientId.get();
    final appVersion = await _appVersion();
    final url = Uri.parse('$baseUrl/v1/$endpoint');

    final body = jsonEncode({
      ...payload,
      'lang': SettingsService.language.value.code,
    });

    http.Response res;
    try {
      res = await http.post(
        url,
        headers: {
          'content-type': 'application/json',
          'x-client-id': clientId,
          'x-app-version': appVersion,
        },
        body: body,
      ).timeout(timeout);
    } on TimeoutException {
      throw AiException('timeout', 'La richiesta AI ha impiegato troppo.');
    } catch (e) {
      throw AiException('network', 'Errore di rete: $e');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = _decodeJson(res.body);
      if (limiter != null) {
        await limiter.consume();
      }
      if (cacheable) {
        await AiCache.write(endpoint, payload, jsonEncode(decoded));
      }
      return decoded;
    }

    final decoded = _safeDecode(res.body);
    final code = (decoded?['error'] as String?) ?? 'http_${res.statusCode}';
    final msg = (decoded?['message'] as String?) ?? res.body;
    if (kDebugMode) {
      debugPrint('AI error $code (${res.statusCode}): $msg');
    }
    throw AiException(code, msg, status: res.statusCode);
  }

  Future<Map<String, dynamic>> health() async {
    if (!enabled) throw AiException('ai_disabled', 'AI disabled');
    final res = await http
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 10));
    return _decodeJson(res.body);
  }

  Map<String, dynamic> _decodeJson(String body) {
    final v = jsonDecode(body);
    if (v is! Map<String, dynamic>) {
      throw AiException('bad_response', 'Risposta non valida dal server AI.');
    }
    return v;
  }

  Map<String, dynamic>? _safeDecode(String body) {
    try {
      final v = jsonDecode(body);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }
}
