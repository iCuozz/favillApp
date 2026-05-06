import 'package:shared_preferences/shared_preferences.dart';

/// Limite per (endpoint × giorno × installazione), salvato in
/// `shared_preferences`. Serve come safety net UX prima ancora di chiamare
/// il Worker. Il rate limit autorevole resta lato server.
class AiRateLimiter {
  final String endpoint;
  final int perDay;

  const AiRateLimiter({required this.endpoint, required this.perDay});

  String get _key {
    final day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    return 'ai.rl.$endpoint.$day';
  }

  Future<int> usedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  Future<int> remaining() async => (perDay - await usedToday()).clamp(0, perDay);

  Future<bool> canConsume() async => await usedToday() < perDay;

  Future<void> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_key) ?? 0) + 1;
    await prefs.setInt(_key, next);
  }

  /// Forza il counter al valore [used] (clamp 0..perDay). Usato per
  /// sincronizzarsi con `remaining` autorevole restituito dal server.
  Future<void> setUsed(int used) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = used.clamp(0, perDay);
    await prefs.setInt(_key, clamped);
  }
}

class AiQuotaExceeded implements Exception {
  final String endpoint;
  AiQuotaExceeded(this.endpoint);
  @override
  String toString() => 'AiQuotaExceeded($endpoint)';
}
