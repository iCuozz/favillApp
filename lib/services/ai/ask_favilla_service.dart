import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../settings_service.dart';
import 'ai_client.dart';
import 'ai_rate_limiter.dart';

enum ChatRole { user, model }

class ChatMessage {
  final ChatRole role;
  final String text;
  final DateTime timestamp;
  final bool sentToReal;

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.sentToReal = false,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({bool? sentToReal}) => ChatMessage(
        role: role,
        text: text,
        timestamp: timestamp,
        sentToReal: sentToReal ?? this.sentToReal,
      );

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'text': text,
        'ts': timestamp.toIso8601String(),
        'sentToReal': sentToReal,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: j['role'] == 'model' ? ChatRole.model : ChatRole.user,
        text: j['text'] as String? ?? '',
        timestamp: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
        sentToReal: j['sentToReal'] as bool? ?? false,
      );
}

class AskFavillaService {
  AskFavillaService._();
  static final AskFavillaService instance = AskFavillaService._();

  static const _kHistoryKey = 'ai.askFavilla.history';
  static const int _maxLocalHistory = 40;
  static const int _historyTurnsToServer = 6;

  final AiRateLimiter limiter =
      const AiRateLimiter(endpoint: 'chat', perDay: 20);

  final AiRateLimiter askRealLimiter =
      const AiRateLimiter(endpoint: 'ask-real', perDay: 3);

  Future<List<ChatMessage>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistoryKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveHistory(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = messages.length > _maxLocalHistory
        ? messages.sublist(messages.length - _maxLocalHistory)
        : messages;
    await prefs.setString(
      _kHistoryKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  /// Pubblico: salva l'intera lista (usato dopo `submitToReal` per
  /// persistere il flag `sentToReal`).
  Future<void> persist(List<ChatMessage> messages) => _saveHistory(messages);

  /// Inoltra una domanda + (opzionale) la risposta IA alla coda moderata
  /// di "Favilla reale". Ritorna `remaining` (quante domande/giorno restano).
  Future<int> submitToReal({
    required String question,
    String? aiAnswer,
    String? contact,
  }) async {
    final payload = <String, dynamic>{
      'question': question,
      if (aiAnswer != null && aiAnswer.isNotEmpty) 'aiAnswer': aiAnswer,
      if (contact != null && contact.isNotEmpty) 'contact': contact,
    };

    final res = await AiClient.instance.post(
      'ask-real',
      payload,
      limiter: askRealLimiter,
    );

    final remaining = res['remaining'];
    return remaining is int ? remaining : 0;
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHistoryKey);
  }

  /// Invia un messaggio al Worker e ritorna la risposta. Aggiorna anche
  /// la storia salvata localmente.
  Future<ChatMessage> send({
    required String userMessage,
    required List<ChatMessage> currentHistory,
  }) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      throw AiException('empty', 'Messaggio vuoto.');
    }

    final lastTurns = currentHistory.length > _historyTurnsToServer
        ? currentHistory.sublist(currentHistory.length - _historyTurnsToServer)
        : currentHistory;

    final payload = <String, dynamic>{
      'message': trimmed,
      'history': lastTurns
          .map((m) => {'role': m.role.name, 'text': m.text})
          .toList(),
    };

    final res = await AiClient.instance.post(
      'chat',
      payload,
      limiter: limiter,
    );

    final reply = (res['reply'] as String? ?? '').trim();
    if (reply.isEmpty) {
      throw AiException('empty_reply', 'Risposta vuota.');
    }

    final userMsg = ChatMessage(role: ChatRole.user, text: trimmed);
    final modelMsg = ChatMessage(role: ChatRole.model, text: reply);
    final next = [...currentHistory, userMsg, modelMsg];
    await _saveHistory(next);
    return modelMsg;
  }

  /// Chip di suggerimento, dipendono dalla lingua corrente.
  List<String> suggestions() {
    switch (SettingsService.language.value) {
      case AppLanguage.english:
        return const [
          'How do I survive bedtime?',
          'Tell me about Sparkle Ale',
          'A pep talk for tough mornings',
          'A funny mission idea',
        ];
      case AppLanguage.italian:
        return const [
          'Come sopravvivo alla nanna?',
          'Raccontami di Sparkle Ale',
          'Una carica per le mattine difficili',
          'Un\'idea di missione divertente',
        ];
    }
  }
}
