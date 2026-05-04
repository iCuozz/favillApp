import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache locale per risposte AI deterministiche.
///
/// Una entry è composta da `endpoint + payload normalizzato`. Il payload
/// viene serializzato JSON in modo deterministico, hashato in SHA-256 e
/// usato come chiave. La cache risiede in `shared_preferences` con TTL.
class AiCache {
  static const _kPrefix = 'ai.cache.';

  static String _key(String endpoint, Map<String, dynamic> payload) {
    final sorted = _sortKeys(payload);
    final raw = jsonEncode({'e': endpoint, 'p': sorted});
    final digest = sha256.convert(utf8.encode(raw)).toString();
    return '$_kPrefix$digest';
  }

  static Object? _sortKeys(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((e) => e.toString()).toList()..sort();
      return {for (final k in keys) k: _sortKeys(value[k])};
    }
    if (value is List) {
      return value.map(_sortKeys).toList();
    }
    return value;
  }

  static Future<String?> read(
    String endpoint,
    Map<String, dynamic> payload, {
    Duration ttl = const Duration(days: 7),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(endpoint, payload));
    if (raw == null) return null;
    try {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final ts = entry['ts'] as int? ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > ttl.inMilliseconds) return null;
      return entry['v'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(
    String endpoint,
    Map<String, dynamic> payload,
    String value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(endpoint, payload),
      jsonEncode({
        'ts': DateTime.now().millisecondsSinceEpoch,
        'v': value,
      }),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_kPrefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
