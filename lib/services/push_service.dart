import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'ai/ai_client.dart';
import 'ai/client_id.dart';
import 'inbox_service.dart';

/// Wrapper attorno a Firebase Messaging.
///
/// - Inizializza Firebase (richiede `google-services.json` in `android/app/`).
/// - Registra/aggiorna il token FCM lato Worker.
/// - In foreground mostra una notifica locale (Android non lo fa di default).
/// - Dopo qualunque messaggio AskReal forza un sync dell'inbox così l'app
///   apre direttamente la risposta più fresca.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _channelId = 'favilla_replies';
  static const _channelName = 'Risposte di Favilla';
  static const _channelDescription =
      'Notifiche quando Favilla coi superpoteri risponde a una tua domanda';

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _token;

  /// Best-effort init. Non lancia mai eccezioni: se Firebase non è
  /// configurato (build dev senza `google-services.json`) le push restano
  /// disattivate ma l'app funziona ugualmente con polling al resume.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase init skipped: $e');
      return;
    }

    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );
    } catch (e) {
      if (kDebugMode) debugPrint('Local notif init failed: $e');
    }

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _token = token;
        unawaited(_registerToken(token));
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        unawaited(_registerToken(t));
      });

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    } catch (e) {
      if (kDebugMode) debugPrint('FCM setup failed: $e');
    }
  }

  String? get token => _token;

  Future<void> _registerToken(String token) async {
    if (!AiClient.instance.enabled) return;
    try {
      await AiClient.instance.post('push/register', {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      if (kDebugMode) {
        final cid = await ClientId.get();
        debugPrint('FCM token registered for $cid');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM register failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage msg) {
    final notif = msg.notification;
    if (notif != null) {
      _local.show(
        msg.hashCode,
        notif.title,
        notif.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
    if (msg.data['type'] == 'ask_real_answer') {
      unawaited(InboxService.instance.sync());
    }
  }

  void _onMessageOpened(RemoteMessage msg) {
    if (msg.data['type'] == 'ask_real_answer') {
      unawaited(InboxService.instance.sync());
    }
  }
}
