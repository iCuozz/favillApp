import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/comic_data.dart';
import '../settings_service.dart';

class _VoiceProfile {
  final double pitch;
  final double rate;

  const _VoiceProfile({
    required this.pitch,
    required this.rate,
  });
}

/// Wrapper su [FlutterTts] con voci differenziate per personaggio.
///
/// Le voci di sistema realmente diverse non sono garantite su tutte le
/// piattaforme: si simula la differenza tra personaggi modulando pitch e
/// rate, mantenendo il funzionamento offline e gratuito.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _isSpeaking = false;
  int _sessionId = 0;
  Completer<void>? _speakCompleter;

  final ValueNotifier<int> currentBlockIndex = ValueNotifier<int>(-1);
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);

  static const _profileFavilla = _VoiceProfile(pitch: 1.15, rate: 0.5);
  static const _profileSparkle = _VoiceProfile(pitch: 1.6, rate: 0.6);
  static const _profileMallow = _VoiceProfile(pitch: 0.75, rate: 0.45);
  static const _profileNarration = _VoiceProfile(pitch: 1.0, rate: 0.45);
  static const _profileThought = _VoiceProfile(pitch: 1.05, rate: 0.42);
  static const _profileSystem = _VoiceProfile(pitch: 0.9, rate: 0.5);
  static const _profileDefault = _VoiceProfile(pitch: 1.0, rate: 0.5);

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() {
      if (!(_speakCompleter?.isCompleted ?? true)) {
        _speakCompleter?.complete();
      }
    });
    _tts.setCancelHandler(() {
      if (!(_speakCompleter?.isCompleted ?? true)) {
        _speakCompleter?.complete();
      }
    });
    _tts.setErrorHandler((message) {
      if (kDebugMode) {
        debugPrint('TTS error: $message');
      }
      if (!(_speakCompleter?.isCompleted ?? true)) {
        _speakCompleter?.complete();
      }
    });
  }

  _VoiceProfile _profileFor(TextBlock block) {
    if (block.isNarration) return _profileNarration;
    if (block.isSystem) return _profileSystem;
    if (block.isThought) return _profileThought;
    final id = block.speaker ?? '';
    if (id == 'favilla' || id == 'favilla_blaze') return _profileFavilla;
    if (id == 'sparkle_ale') return _profileSparkle;
    if (id == 'mallow_bellow') return _profileMallow;
    return _profileDefault;
  }

  String _sanitize(String text) {
    final clean = text.trim();
    if (clean.length <= 600) return clean;
    return '${clean.substring(0, 600)}…';
  }

  String _languageTag(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.english:
        return 'en-US';
      case AppLanguage.italian:
        return 'it-IT';
    }
  }

  Future<void> _applyProfile(_VoiceProfile profile, AppLanguage lang) async {
    try {
      await _tts.setLanguage(_languageTag(lang));
    } catch (_) {
      // Lingua non disponibile sul device: si usa quella di default.
    }
    await _tts.setPitch(profile.pitch.clamp(0.5, 2.0));
    await _tts.setSpeechRate(profile.rate.clamp(0.0, 1.0));
  }

  /// Legge in sequenza i [blocks] di un pannello con voce per personaggio.
  Future<void> speakBlocks(
    List<TextBlock> blocks, {
    required AppLanguage language,
    void Function(int index)? onBlockStart,
  }) async {
    if (blocks.isEmpty) return;
    await _ensureInitialized();
    await stop();

    final mySession = ++_sessionId;
    _isSpeaking = true;
    isSpeaking.value = true;

    try {
      for (int i = 0; i < blocks.length; i++) {
        if (mySession != _sessionId) break;
        final block = blocks[i];
        final text = _sanitize(block.text);
        if (text.isEmpty) continue;

        currentBlockIndex.value = i;
        onBlockStart?.call(i);

        await _applyProfile(_profileFor(block), language);

        _speakCompleter = Completer<void>();
        final result = await _tts.speak(text);
        if (result == 1) {
          await _speakCompleter!.future;
        } else {
          _speakCompleter?.complete();
        }
        _speakCompleter = null;
      }
    } finally {
      if (mySession == _sessionId) {
        _isSpeaking = false;
        isSpeaking.value = false;
        currentBlockIndex.value = -1;
      }
    }
  }

  /// Legge un testo libero usando il profilo voce di Favilla.
  /// Usato dalla chat "Chiedi a Favilla".
  Future<void> speakAsFavilla(
    String text, {
    required AppLanguage language,
  }) async {
    final clean = _sanitize(text);
    if (clean.isEmpty) return;
    await _ensureInitialized();
    await stop();

    final mySession = ++_sessionId;
    _isSpeaking = true;
    isSpeaking.value = true;

    try {
      await _applyProfile(_profileFavilla, language);
      _speakCompleter = Completer<void>();
      final result = await _tts.speak(clean);
      if (result == 1) {
        await _speakCompleter!.future;
      } else {
        _speakCompleter?.complete();
      }
      _speakCompleter = null;
    } finally {
      if (mySession == _sessionId) {
        _isSpeaking = false;
        isSpeaking.value = false;
        currentBlockIndex.value = -1;
      }
    }
  }

  Future<void> stop() async {
    if (!_initialized) return;
    _sessionId++;
    if (_isSpeaking) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
    _isSpeaking = false;
    isSpeaking.value = false;
    currentBlockIndex.value = -1;
    if (!(_speakCompleter?.isCompleted ?? true)) {
      _speakCompleter?.complete();
    }
  }
}
