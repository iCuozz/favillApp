// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestisce musica ambientale per episodio e SFX per interazioni.
///
/// Uso:
///   await AudioService.instance.init();
///   AudioService.instance.playAmbient('prologo');   // avvia il tema dell'episodio
///   AudioService.instance.playSfx(SfxEvent.choiceSelect);
///
/// I file audio vanno messi in assets/audio/:
///   ambient/<audio_theme>.mp3    (es. ambient/nova_mattina.mp3)
///   sfx/tap_panel.mp3
///   sfx/choice_select.mp3
///   sfx/minigame_success.mp3
///   sfx/minigame_fail.mp3
class AudioService {
  AudioService._();
  static final instance = AudioService._();

  static const _kVolumePrefKey = 'audio.volume';
  static const _kEnabledPrefKey = 'audio.enabled';

  final AudioPlayer _ambient = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  double _volume = 0.6;
  bool _enabled = true;
  String? _currentTheme;

  bool get enabled => _enabled;
  double get volume => _volume;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble(_kVolumePrefKey) ?? 0.6;
    _enabled = prefs.getBool(_kEnabledPrefKey) ?? true;
    await _ambient.setVolume(_volume * 0.4); // musica più bassa degli SFX
    await _sfx.setVolume(_volume);
    await _ambient.setReleaseMode(ReleaseMode.loop);
  }

  /// Avvia la musica ambientale del tema specificato (definito nel JSON come `audio_theme`).
  /// Se il tema è già in riproduzione non fa nulla.
  Future<void> playAmbient(String? audioTheme) async {
    if (!_enabled || audioTheme == null || audioTheme.isEmpty) return;
    if (_currentTheme == audioTheme) return;
    _currentTheme = audioTheme;
    try {
      await _ambient.stop();
      await _ambient.play(AssetSource('audio/ambient/$audioTheme.mp3'));
    } catch (_) {
      // File non trovato — silenzioso, l'audio è opzionale
    }
  }

  Future<void> stopAmbient() async {
    _currentTheme = null;
    await _ambient.stop();
  }

  /// Riproduce un effetto sonoro.
  Future<void> playSfx(SfxEvent event) async {
    if (!_enabled) return;
    try {
      await _sfx.stop();
      await _sfx.play(AssetSource('audio/sfx/${event.filename}'));
    } catch (_) {
      // File non trovato — silenzioso
    }
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _ambient.setVolume(_volume * 0.4);
    await _sfx.setVolume(_volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kVolumePrefKey, _volume);
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) await _ambient.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledPrefKey, enabled);
  }

  void dispose() {
    _ambient.dispose();
    _sfx.dispose();
  }
}

enum SfxEvent {
  tapPanel('tap_panel.mp3'),
  choiceSelect('choice_select.mp3'),
  minigameSuccess('minigame_success.mp3'),
  minigameFail('minigame_fail.mp3'),
  statUp('stat_up.mp3'),
  statDown('stat_down.mp3');

  final String filename;
  const SfxEvent(this.filename);
}
