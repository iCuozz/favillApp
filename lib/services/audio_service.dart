// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/comic_data.dart';

/// Gestisce musica ambientale per episodio, layer contestuali e SFX.
///
/// Uso:
///   await AudioService.instance.init();
///   AudioService.instance.playAmbient('prologo');   // avvia il tema dell'episodio
///   AudioService.instance.playSfx(SfxEvent.choiceSelect);
///
/// I file audio vanno messi in assets/audio/:
///   ambient/<audio_theme>.mp3    (es. ambient/nova_mattina.mp3)
///   ambient/layers/<scene>.mp3   (es. ambient/layers/school.mp3)
///   ambient/accent/<cue>.mp3     (es. ambient/accent/dialogue.mp3)
///   sfx/tap_panel.mp3
///   sfx/choice_select.mp3
///   sfx/minigame_success.mp3
///   sfx/minigame_fail.mp3
class AudioService {
  AudioService._();
  static final instance = AudioService._();

  static const _kVolumePrefKey = 'audio.volume';
  static const _kEnabledPrefKey = 'audio.enabled';

  final AudioPlayer _ambientBase = AudioPlayer();
  final AudioPlayer _ambientLayer = AudioPlayer();
  final AudioPlayer _ambientAccent = AudioPlayer();
  final AudioPlayer _cuePlayer = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  double _volume = 0.6;
  bool _enabled = true;
  String? _currentEpisodeTheme;
  String? _currentSceneKey;
  String? _currentAccentKey;

  final ValueNotifier<bool> enabledListenable = ValueNotifier<bool>(true);
  final ValueNotifier<double> volumeListenable = ValueNotifier<double>(0.6);

  bool get enabled => _enabled;
  double get volume => _volume;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble(_kVolumePrefKey) ?? 0.6;
    _enabled = prefs.getBool(_kEnabledPrefKey) ?? true;
    enabledListenable.value = _enabled;
    volumeListenable.value = _volume;
    await _ambientBase.setVolume(_volume * 0.38);
    await _ambientLayer.setVolume(_volume * 0.22);
    await _ambientAccent.setVolume(_volume * 0.16);
    await _cuePlayer.setVolume(_volume * 0.18);
    await _sfx.setVolume(_volume);
    await _ambientBase.setReleaseMode(ReleaseMode.loop);
    await _ambientLayer.setReleaseMode(ReleaseMode.loop);
    await _ambientAccent.setReleaseMode(ReleaseMode.loop);
  }

  /// Avvia la musica ambientale del tema specificato (definito nel JSON come `audio_theme`).
  /// Se il tema è già in riproduzione non fa nulla.
  Future<void> playAmbient(String? audioTheme) async {
    await updateEpisodeContext(
      episodeId: audioTheme,
      episodeTheme: audioTheme,
      forceRefresh: true,
    );
  }

  Future<void> stopAmbient() async {
    _currentEpisodeTheme = null;
    _currentSceneKey = null;
    _currentAccentKey = null;
    await _ambientBase.stop();
    await _ambientLayer.stop();
    await _ambientAccent.stop();
    await _cuePlayer.stop();
    await _sfx.stop();
  }

  Future<void> updateEpisodeContext({
    required String? episodeId,
    String? episodeTheme,
    PageVfxConfig? vfx,
    String? sceneHint,
    String? toneHint,
    bool forceRefresh = false,
    bool powerMode = false,
    double intensity = 1.0,
  }) async {
    if (!_enabled) return;

    final baseTheme = _resolveEpisodeTheme(episodeId, episodeTheme);
    final sceneKey = _resolveSceneKey(
      vfx: vfx,
      episodeId: episodeId,
      sceneHint: sceneHint,
    );
    final accentKey = _resolveAccentKey(
      vfx: vfx,
      toneHint: toneHint,
      powerMode: powerMode,
    );

    final nextThemeKey = baseTheme ?? '';
    final nextSceneKey = sceneKey ?? '';
    final nextAccentKey = accentKey ?? '';
    final shouldSkip = !forceRefresh &&
        _currentEpisodeTheme == nextThemeKey &&
        _currentSceneKey == nextSceneKey &&
        _currentAccentKey == nextAccentKey;
    if (shouldSkip) return;

    _currentEpisodeTheme = nextThemeKey;
    _currentSceneKey = nextSceneKey;
    _currentAccentKey = nextAccentKey;

    await _playLooped(
      player: _ambientBase,
      assetPath: baseTheme == null ? null : 'audio/ambient/$baseTheme.mp3',
      volume: _volume * 0.38,
    );
    await _playLooped(
      player: _ambientLayer,
      assetPath: sceneKey == null ? null : 'audio/ambient/layers/$sceneKey.mp3',
      volume: _volume * 0.22 * intensity.clamp(0.4, 1.5),
    );
    await _playLooped(
      player: _ambientAccent,
      assetPath:
          accentKey == null ? null : 'audio/ambient/accent/$accentKey.mp3',
      volume: _volume * 0.16 * intensity.clamp(0.4, 1.5),
    );
  }

  Future<void> playNarrativeCue({
    required String cue,
    double intensity = 1.0,
  }) async {
    if (!_enabled) return;
    final safeCue = cue.trim().toLowerCase();
    if (safeCue.isEmpty) return;
    try {
      await _cuePlayer.stop();
      await _cuePlayer.setVolume(_volume * 0.18 * intensity.clamp(0.4, 1.5));
      await _cuePlayer.play(AssetSource('audio/accent/$safeCue.mp3'));
    } catch (_) {
      // File non trovato — silenzioso, il cue è opzionale
    }
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
    volumeListenable.value = _volume;
    await _ambientBase.setVolume(_volume * 0.38);
    await _ambientLayer.setVolume(_volume * 0.22);
    await _ambientAccent.setVolume(_volume * 0.16);
    await _cuePlayer.setVolume(_volume * 0.18);
    await _sfx.setVolume(_volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kVolumePrefKey, _volume);
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    enabledListenable.value = enabled;
    if (!enabled) await stopAmbient();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledPrefKey, enabled);
  }

  void dispose() {
    enabledListenable.dispose();
    volumeListenable.dispose();
    _ambientBase.dispose();
    _ambientLayer.dispose();
    _ambientAccent.dispose();
    _cuePlayer.dispose();
    _sfx.dispose();
  }

  Future<void> _playLooped({
    required AudioPlayer player,
    required String? assetPath,
    required double volume,
  }) async {
    try {
      await player.stop();
      if (assetPath == null) return;
      await player.setVolume(volume);
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // Asset opzionale: se non esiste, restiamo silenziosi.
    }
  }

  String? _resolveEpisodeTheme(String? episodeId, String? explicitTheme) {
    final theme = explicitTheme?.trim();
    if (theme != null && theme.isNotEmpty) return theme;
    final id = episodeId?.trim();
    if (id == null || id.isEmpty) return null;
    return switch (id) {
      'prologo' => 'prologo_hum',
      's1_mattina_dopo' => 'mattina_dopo_hum',
      's1_scuola_1' => 'scuola_pressure',
      's1_ritorno_casa' => 'ritorno_casa_hum',
      's1_spesa_sabato' => 'supermercato_neon',
      's1_domenica_parco' => 'parco_morning',
      's1_mare' => 'mare_breeze',
      's1_centro_commerciale' => 'mall_neon',
      's1_lunedi_asilo' => 'asilo_morning',
      's1_palestra' => 'gym_respiro',
      _ => null,
    };
  }

  String? _resolveSceneKey({
    PageVfxConfig? vfx,
    String? episodeId,
    String? sceneHint,
  }) {
    final hinted =
        vfx?.scene?.trim().toLowerCase() ?? sceneHint?.trim().toLowerCase();
    if (hinted != null && hinted.isNotEmpty) return hinted;
    final id = episodeId?.toLowerCase() ?? '';
    if (id.contains('mare')) return 'beach';
    if (id.contains('parco')) return 'park';
    if (id.contains('scuola')) return 'school';
    if (id.contains('palestra')) return 'gym';
    if (id.contains('centro_commerciale')) return 'mall';
    if (id.contains('asilo')) return 'kindergarten';
    if (id.contains('ritorno_casa') ||
        id.contains('mattina_dopo') ||
        id.contains('prologo') ||
        id.contains('casa')) {
      return 'home';
    }
    return null;
  }

  String? _resolveAccentKey({
    PageVfxConfig? vfx,
    String? toneHint,
    bool powerMode = false,
  }) {
    if (powerMode || vfx?.forcePower == true) return 'power';
    final hinted =
        vfx?.focus?.trim().toLowerCase() ?? toneHint?.trim().toLowerCase();
    if (hinted == null || hinted.isEmpty) return null;
    return switch (hinted) {
      'dialogue' => 'dialogue',
      'thought' => 'thought',
      'system' => 'system',
      'neutral' => null,
      _ => hinted,
    };
  }
}

enum AudioNarrativeCue { dialogue, thought, system, power }

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
