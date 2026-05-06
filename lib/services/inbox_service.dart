import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/ai_client.dart';

/// Una risposta arrivata da "Favilla coi superpoteri".
class InboxReply {
  final String id;
  final String question;
  final String answer;
  final DateTime answeredAt;
  final bool read;

  InboxReply({
    required this.id,
    required this.question,
    required this.answer,
    required this.answeredAt,
    this.read = false,
  });

  InboxReply copyWith({bool? read}) => InboxReply(
        id: id,
        question: question,
        answer: answer,
        answeredAt: answeredAt,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'answer': answer,
        'answeredAt': answeredAt.millisecondsSinceEpoch,
        'read': read,
      };

  factory InboxReply.fromJson(Map<String, dynamic> j) => InboxReply(
        id: j['id'] as String,
        question: j['question'] as String? ?? '',
        answer: j['answer'] as String? ?? '',
        answeredAt: DateTime.fromMillisecondsSinceEpoch(
          (j['answeredAt'] as int?) ?? 0,
        ),
        read: j['read'] as bool? ?? false,
      );
}

/// Cache locale + sync per le risposte ricevute da Favilla.
///
/// Espone [unreadCount] come [ValueNotifier] così l'AppBar di AskFavilla
/// può mostrare un badge senza polling reattivo.
class InboxService {
  InboxService._();
  static final InboxService instance = InboxService._();

  static const _kCacheKey = 'ai.inbox.replies';
  static const _kLastFetchedAt = 'ai.inbox.lastFetchedAt';

  final ValueNotifier<int> unreadCount = ValueNotifier(0);
  final ValueNotifier<List<InboxReply>> replies = ValueNotifier(const []);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCacheKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final loaded = list
          .map((e) => InboxReply.fromJson(e as Map<String, dynamic>))
          .toList();
      replies.value = loaded;
      unreadCount.value = loaded.where((r) => !r.read).length;
    } catch (_) {
      // cache corrotta
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCacheKey,
      jsonEncode(replies.value.map((r) => r.toJson()).toList()),
    );
  }

  Future<int> _lastFetchedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kLastFetchedAt) ?? 0;
  }

  Future<void> _saveLastFetchedAt(int ts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastFetchedAt, ts);
  }

  /// Polla `/v1/inbox?since=<lastSeen>` e merge nelle risposte locali.
  /// Ritorna il numero di nuove risposte ricevute.
  Future<int> sync() async {
    if (!AiClient.instance.enabled) return 0;
    await init();

    // since = max(answeredAt) tra le risposte già in cache, fallback al
    // last fetch persistito. -1 giorno per non perderne nessuna in caso
    // di clock skew.
    int since = await _lastFetchedAt();
    for (final r in replies.value) {
      final ts = r.answeredAt.millisecondsSinceEpoch;
      if (ts > since) since = ts;
    }
    since = since > 0 ? since - 60000 : 0;

    Map<String, dynamic> res;
    try {
      res = await AiClient.instance.get(
        'inbox',
        query: {'since': '$since'},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Inbox sync error: $e');
      return 0;
    }

    final items = (res['items'] as List<dynamic>? ?? const []);
    if (items.isEmpty) {
      await _saveLastFetchedAt(DateTime.now().millisecondsSinceEpoch);
      return 0;
    }

    final byId = {for (final r in replies.value) r.id: r};
    var newCount = 0;
    for (final raw in items) {
      final m = raw as Map<String, dynamic>;
      final id = m['id'] as String?;
      final answer = (m['favilla_answer'] as String?)?.trim();
      final answeredAt = m['answered_at'];
      if (id == null || answer == null || answer.isEmpty || answeredAt == null) {
        continue;
      }
      final ts = answeredAt is int
          ? answeredAt
          : int.tryParse('$answeredAt') ?? 0;
      if (byId.containsKey(id)) {
        // Aggiornamento di un'eventuale risposta editata: sovrascrivi testo
        // mantenendo lo stato di lettura.
        final existing = byId[id]!;
        byId[id] = InboxReply(
          id: id,
          question: m['question'] as String? ?? existing.question,
          answer: answer,
          answeredAt: DateTime.fromMillisecondsSinceEpoch(ts),
          read: existing.read,
        );
      } else {
        byId[id] = InboxReply(
          id: id,
          question: m['question'] as String? ?? '',
          answer: answer,
          answeredAt: DateTime.fromMillisecondsSinceEpoch(ts),
          read: false,
        );
        newCount++;
      }
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.answeredAt.compareTo(a.answeredAt));
    replies.value = merged;
    unreadCount.value = merged.where((r) => !r.read).length;
    await _persist();
    await _saveLastFetchedAt(DateTime.now().millisecondsSinceEpoch);
    return newCount;
  }

  Future<void> markRead(String id) async {
    final updated = replies.value
        .map((r) => r.id == id ? r.copyWith(read: true) : r)
        .toList();
    replies.value = updated;
    unreadCount.value = updated.where((r) => !r.read).length;
    await _persist();
  }

  Future<void> markAllRead() async {
    final updated = replies.value.map((r) => r.copyWith(read: true)).toList();
    replies.value = updated;
    unreadCount.value = 0;
    await _persist();
  }
}
