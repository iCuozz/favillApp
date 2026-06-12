// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/comic_data.dart';
import '../l10n/app_strings.dart';
import '../services/audio_service.dart';
import '../services/game_state_service.dart';
import '../services/narrative_memory_service.dart';
import '../services/settings_service.dart';
import '../services/tts/tts_service.dart';
import 'comic_page_image.dart';
import 'comic_text_block_widget.dart';
import 'espresso_button.dart';

class ComicPageStage extends StatefulWidget {
  final ComicIndex comicIndex;
  final ComicPage page;

  /// Posizione effettiva della pagina nell'elenco _effectivePages.
  /// Usata per differenziare pagine di branch che condividono page.index=0.
  final int pageViewIndex;
  final VoidCallback? onPageCompleted;
  final int initialVisibleBlocks;
  final ValueChanged<int>? onVisibleBlocksChanged;

  const ComicPageStage({
    super.key,
    required this.comicIndex,
    required this.page,
    required this.pageViewIndex,
    this.onPageCompleted,
    this.initialVisibleBlocks = 1,
    this.onVisibleBlocksChanged,
  });

  @override
  State<ComicPageStage> createState() => ComicPageStageState();
}

class ComicPageStageState extends State<ComicPageStage>
    with TickerProviderStateMixin {
  late int visibleBlocks;
  late final AnimationController _ambientCtrl;
  late final AnimationController _entryZoomCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _hitFlashCtrl;
  late final AnimationController _pageTransitionCtrl;

  static const List<String> _powerKeywords = [
    'fuoco',
    'fiamma',
    'fiamme',
    'brucia',
    'bruciature',
    'calore',
    'scalda',
    'scott',
    'light',
    'glow',
    'burn',
    'heat',
    'spark',
    'scintill',
    'poter',
  ];
  static const List<String> _rainKeywords = [
    'allag',
    'piogg',
    'tempesta',
    'storm',
    'rain',
  ];
  static const List<String> _mistKeywords = [
    'notte',
    'night',
    'ombra',
    'fumo',
    'smoke',
    'foschia',
    'fog',
    'balcone',
  ];
  static const List<String> _lightsKeywords = [
    'galaxia',
    'mall',
    'centro_commerciale',
    'parcheggio',
    'led',
    'neon',
  ];

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _entryZoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _hitFlashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 210),
    );
    _pageTransitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    visibleBlocks = _clampInitial(widget.initialVisibleBlocks);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeTriggerMicroEffectsForVisibleBlock(visibleBlocks - 1);
    });
    if (SettingsService.ttsEnabled.value && SettingsService.ttsAutoplay.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTts();
      });
    }
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _ambientCtrl.dispose();
    _entryZoomCtrl.dispose();
    _shakeCtrl.dispose();
    _hitFlashCtrl.dispose();
    _pageTransitionCtrl.dispose();
    super.dispose();
  }

  int _clampInitial(int value) {
    final total = widget.page.panels.isEmpty
        ? 1
        : widget.page.panels.first.textBlocks.length;
    if (total <= 0) return 1;
    if (value < 1) return 1;
    if (value > total) return total;
    return value;
  }

  @override
  void didUpdateWidget(covariant ComicPageStage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pageViewIndex != widget.pageViewIndex) {
      visibleBlocks = _clampInitial(widget.initialVisibleBlocks);
      TtsService.instance.stop();
      _entryZoomCtrl.forward(from: 0);
      _shakeCtrl.reset();
      _hitFlashCtrl.reset();
      _pageTransitionCtrl.forward(from: 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _maybeTriggerMicroEffectsForVisibleBlock(visibleBlocks - 1);
        }
      });
      if (SettingsService.ttsEnabled.value &&
          SettingsService.ttsAutoplay.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startTts();
        });
      }
    }
  }

  Future<void> _startTts() async {
    if (!mounted) return;
    final panel = widget.page.panels.isEmpty ? null : widget.page.panels.first;
    if (panel == null || panel.textBlocks.isEmpty) return;
    final resolvedBlocks = _resolvedTextBlocks(panel);
    await TtsService.instance.speakBlocks(
      resolvedBlocks,
      language: SettingsService.language.value,
      onBlockStart: (index) {
        if (!mounted) return;
        if (index + 1 > visibleBlocks) {
          setState(() {
            visibleBlocks = index + 1;
          });
          _maybeTriggerMicroEffectsForVisibleBlock(index);
          widget.onVisibleBlocksChanged?.call(visibleBlocks);
        }
      },
    );
    if (!mounted) return;
    if (visibleBlocks >= panel.textBlocks.length) {
      widget.onPageCompleted?.call();
    }
  }

  void _toggleTts() {
    SettingsService.tapFeedback();
    if (TtsService.instance.isSpeaking.value) {
      TtsService.instance.stop();
    } else {
      _startTts();
    }
  }

  bool advance() {
    final totalBlocks = widget.page.panels.first.textBlocks.length;

    if (visibleBlocks < totalBlocks) {
      setState(() {
        visibleBlocks++;
      });
      _maybeTriggerMicroEffectsForVisibleBlock(visibleBlocks - 1);
      widget.onVisibleBlocksChanged?.call(visibleBlocks);
      return true;
    }

    widget.onPageCompleted?.call();
    return false;
  }

  bool goBackBlock() {
    if (visibleBlocks > 1) {
      setState(() {
        visibleBlocks--;
      });
      widget.onVisibleBlocksChanged?.call(visibleBlocks);
      return true;
    }
    return false;
  }

  void _handleTap() {
    SettingsService.tapFeedback();
    advance();
  }

  void _handleEspressoPressed() async {
    SettingsService.tapFeedback();
    
    // Applica gli effetti: +10 resistenza, -15 scintille
    // e traccia l'uso dell'espresso con il numero di episodio
    await GameStateService.instance.applyChoice(
      effects: {
        'resistenza': 10,
        'scintille': -15,
      },
      currentEpisodeForCaffe: GameStateService.instance.currentEpisodeNumber,
      newMemories: {
        'espresso_used_latest': GameStateService.instance.currentEpisodeNumber.toString(),
      },
    );
    
    // Avanza a prossima pagina (mostra il tutorial narrative)
    advance();
  }

  bool _containsPowerCue(String raw) {
    final text = raw.toLowerCase();
    return _powerKeywords.any(text.contains);
  }

  String _resolveNarrativeText(String raw) {
    final memories = GameStateService.instance.state.value.memories;
    return NarrativeMemoryService.resolveText(raw, memories);
  }

  List<TextBlock> _resolvedTextBlocks(Panel panel) {
    return panel.textBlocks
        .map(
          (block) => TextBlock(
            id: block.id,
            type: block.type,
            speaker: block.speaker,
            text: _resolveNarrativeText(block.text),
          ),
        )
        .toList(growable: false);
  }

  double get _vfxIntensity => widget.page.vfx?.intensity ?? 1.0;

  _AmbientScene? _sceneFromString(String? raw) {
    final s = raw?.trim().toLowerCase();
    return switch (s) {
      'rain' => _AmbientScene.rain,
      'mist' => _AmbientScene.mist,
      'lights' => _AmbientScene.lights,
      'dust' => _AmbientScene.dust,
      _ => null,
    };
  }

  _NarrativeTone? _toneFromString(String? raw) {
    final s = raw?.trim().toLowerCase();
    return switch (s) {
      'dialogue' => _NarrativeTone.dialogue,
      'thought' => _NarrativeTone.thought,
      'system' => _NarrativeTone.system,
      'neutral' => _NarrativeTone.neutral,
      _ => null,
    };
  }

  _AmbientScene _resolveSceneMode(List<TextBlock> visibleTextBlocks) {
    final configured = _sceneFromString(widget.page.vfx?.scene);
    if (configured != null) return configured;
    final source = StringBuffer()
      ..write(widget.page.background.toLowerCase())
      ..write(' ')
      ..writeAll(visibleTextBlocks.map((b) => b.text.toLowerCase()), ' ');
    final s = source.toString();
    if (_rainKeywords.any(s.contains)) return _AmbientScene.rain;
    if (_mistKeywords.any(s.contains)) return _AmbientScene.mist;
    if (_lightsKeywords.any(s.contains)) return _AmbientScene.lights;
    return _AmbientScene.dust;
  }

  _NarrativeTone _resolveNarrativeTone(List<TextBlock> visibleTextBlocks) {
    final configured = _toneFromString(widget.page.vfx?.focus);
    if (configured != null) return configured;
    if (visibleTextBlocks.isEmpty) return _NarrativeTone.neutral;
    final current = visibleTextBlocks.last;
    if (current.isSystem) return _NarrativeTone.system;
    if (current.isThought) return _NarrativeTone.thought;
    if (current.isDialogue) return _NarrativeTone.dialogue;
    return _NarrativeTone.neutral;
  }

  bool _isPowerMoment(List<TextBlock> visibleTextBlocks, Panel panel) {
    final forcePower = widget.page.vfx?.forcePower;
    if (forcePower != null) return forcePower;
    final source = StringBuffer()
      ..write(widget.page.background)
      ..write(' ')
      ..write(panel.characters.join(' '))
      ..write(' ')
      ..writeAll(visibleTextBlocks.map((b) => b.text), ' ');
    return _containsPowerCue(source.toString());
  }

  void _maybeTriggerMicroEffectsForVisibleBlock(int blockIndex) {
    if (blockIndex < 0) return;
    if (widget.page.panels.isEmpty) return;
    final panel = widget.page.panels.first;
    if (blockIndex >= panel.textBlocks.length) return;
    final block = _resolvedTextBlocks(panel)[blockIndex];
    final raw = '${block.text} ${widget.page.background}';
    final isPower = _containsPowerCue(raw);
    final isHit = isPower ||
        block.isSystem ||
        block.text.contains('!') ||
        block.text.contains('?');
    if (isPower) {
      _shakeCtrl.forward(from: 0);
    }
    if (isHit) {
      _hitFlashCtrl.forward(from: 0);
    }
    AudioService.instance.playNarrativeCue(
      cue: switch (block.type) {
        'dialogue' => 'dialogue',
        'thought' => 'thought',
        'system' => 'system',
        'narration' => isPower ? 'power' : 'dialogue',
        _ => 'dialogue',
      },
      intensity: _vfxIntensity,
    );
  }

  List<double> _sceneColorMatrix(_AmbientScene scene, bool powerMode) {
    switch (scene) {
      case _AmbientScene.rain:
        return [
          0.88,
          0.0,
          0.04,
          0.0,
          -6,
          0.0,
          0.93,
          0.04,
          0.0,
          -4,
          0.02,
          0.08,
          1.03,
          0.0,
          6,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
        ];
      case _AmbientScene.mist:
        return [
          0.9,
          0.03,
          0.03,
          0.0,
          4,
          0.02,
          0.92,
          0.03,
          0.0,
          4,
          0.02,
          0.05,
          0.95,
          0.0,
          6,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
        ];
      case _AmbientScene.lights:
        return [
          1.03,
          0.02,
          0.02,
          0.0,
          6,
          0.02,
          1.02,
          0.02,
          0.0,
          4,
          0.02,
          0.03,
          1.0,
          0.0,
          2,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
        ];
      case _AmbientScene.dust:
        final warm = powerMode ? 0.04 : 0.02;
        return [
          1.0 + warm,
          0.01,
          0.0,
          0.0,
          3,
          0.01,
          1.0,
          0.0,
          0.0,
          1,
          0.0,
          0.01,
          0.98,
          0.0,
          -2,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
        ];
    }
  }

  Color _sceneTransitionTint(_AmbientScene scene, bool powerMode) {
    return switch (scene) {
      _AmbientScene.rain => const Color(0xFF0D1B2A),
      _AmbientScene.mist => const Color(0xFF1E1B2E),
      _AmbientScene.lights => const Color(0xFF101E30),
      _AmbientScene.dust =>
        powerMode ? const Color(0xFF2A130D) : const Color(0xFF101010),
    };
  }

  @override
  Widget build(BuildContext context) {
    final panel = widget.page.panels.first;
    final resolvedBlocks = _resolvedTextBlocks(panel);
    final visibleTextBlocks = resolvedBlocks.take(visibleBlocks).toList();
    final totalBlocks = panel.textBlocks.length;
    final isLastBlockVisible = visibleBlocks >= totalBlocks;
    final isPowerMoment = _isPowerMoment(visibleTextBlocks, panel);
    final sceneMode = _resolveSceneMode(visibleTextBlocks);
    final narrativeTone = _resolveNarrativeTone(visibleTextBlocks);
    final effectIntensity = _vfxIntensity;
    final showCinematicBars = widget.page.vfx?.cinematicBars ?? isPowerMoment;

    return GestureDetector(
      onTap: _handleTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _ambientCtrl,
                      _entryZoomCtrl,
                      _shakeCtrl,
                      _hitFlashCtrl,
                    ]),
                    builder: (context, child) {
                      final phase = _ambientCtrl.value * math.pi * 2;
                      final parallaxX = math.sin(phase) *
                          (isPowerMoment ? 9.0 : 4.0) *
                          effectIntensity;
                      final parallaxY = math.cos(phase * 0.8) *
                          (isPowerMoment ? 6.0 : 3.0) *
                          effectIntensity;

                      final entryT =
                          Curves.easeOutCubic.transform(_entryZoomCtrl.value);
                      final startZoom = isPowerMoment ? 1.09 : 1.05;
                      const endZoom = 1.0;
                      final zoom =
                          (startZoom + ((endZoom - startZoom) * entryT)) +
                              (math.sin(phase * 0.5) *
                                  (isPowerMoment ? 0.008 : 0.003) *
                                  effectIntensity);

                      final shakeEase =
                          Curves.easeOut.transform(_shakeCtrl.value);
                      final shakeAmp = (1 - shakeEase) *
                          (isPowerMoment ? 5.0 : 2.5) *
                          effectIntensity;
                      final shakeX =
                          math.sin(_shakeCtrl.value * math.pi * 18) * shakeAmp;
                      final shakeY = math.cos(_shakeCtrl.value * math.pi * 14) *
                          shakeAmp *
                          0.35;

                      return Transform.translate(
                        offset: Offset(parallaxX + shakeX, parallaxY + shakeY),
                        child: Transform.scale(
                          scale: zoom,
                          child: child,
                        ),
                      );
                    },
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(
                        _sceneColorMatrix(sceneMode, isPowerMoment),
                      ),
                      child: ComicPageImage(
                        assetPath: widget.page.background,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _hitFlashCtrl,
                      builder: (context, _) {
                        final k = Curves.easeOut.transform(_hitFlashCtrl.value);
                        final alpha = (1 - k) *
                            (isPowerMoment ? 0.22 : 0.12) *
                            effectIntensity;
                        return Container(
                          color: Colors.white.withValues(alpha: alpha),
                        );
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pageTransitionCtrl,
                      builder: (context, _) {
                        final k = Curves.easeOutCubic
                            .transform(_pageTransitionCtrl.value);
                        final alpha = (1 - k) *
                            (isPowerMoment ? 0.34 : 0.24) *
                            effectIntensity;
                        return Container(
                          color: _sceneTransitionTint(sceneMode, isPowerMoment)
                              .withValues(alpha: alpha),
                        );
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _ambientCtrl,
                      builder: (context, _) {
                        final pulse = 0.08 +
                            ((math.sin(_ambientCtrl.value * math.pi * 2) + 1) *
                                0.5 *
                                0.14);
                        final opacity = isPowerMoment
                            ? (pulse * effectIntensity).clamp(0.0, 1.0)
                            : 0.0;
                        return AnimatedOpacity(
                          opacity: opacity,
                          duration: const Duration(milliseconds: 240),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0, -0.25),
                                radius: 1.15,
                                colors: [
                                  Color(0x66FF8A50),
                                  Color(0x22FF7043),
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _ambientCtrl,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _AmbientParticlesPainter(
                            t: _ambientCtrl.value,
                            powerMode: isPowerMoment,
                            seed: widget.pageViewIndex,
                            scene: sceneMode,
                            intensity: effectIntensity,
                          ),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _ambientCtrl,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _AmbientAtmospherePainter(
                            t: _ambientCtrl.value,
                            powerMode: isPowerMoment,
                            scene: sceneMode,
                            intensity: effectIntensity,
                          ),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: showCinematicBars ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 260),
                      child: Column(
                        children: [
                          Container(
                            height: 14,
                            color: Colors.black.withValues(alpha: 0.7),
                          ),
                          const Spacer(),
                          Container(
                            height: 14,
                            color: Colors.black.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _ambientCtrl,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _NarrativeFocusPainter(
                            t: _ambientCtrl.value,
                            tone: narrativeTone,
                            powerMode: isPowerMoment,
                            intensity: effectIntensity,
                          ),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color.fromARGB(170, 0, 0, 0),
                            Color.fromARGB(220, 0, 0, 0),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            visibleTextBlocks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final block = entry.value;

                          return TweenAnimationBuilder<double>(
                            key: ValueKey(
                              '${widget.pageViewIndex}_${block.id.isNotEmpty ? block.id : index}',
                            ),
                            tween: Tween(begin: 0, end: 1),
                            duration: SettingsService
                                .textAnimationSpeed.value.duration,
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 12),
                                  child: child,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ComicTextBlockWidget(
                                comicIndex: widget.comicIndex,
                                block: block,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  if (GameStateService.instance.currentQuestId != null &&
                      GameStateService.instance.currentQuestId != 'prologo' &&
                      GameStateService.instance.currentQuestId != 's1_mattina_dopo')
                    Positioned(
                      top: 12,
                      right: 12,
                      child: EspressoButton(
                        currentEpisode: GameStateService.instance.currentEpisodeNumber,
                        lastCaffeEpisode: GameStateService.instance.gameState.lastCaffeEpisode,
                        onPressed: _handleEspressoPressed,
                        isAvailable: true,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Text(
                    'Pagina ${widget.pageViewIndex + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(totalBlocks, (index) {
                          final isVisible = index < visibleBlocks;

                          return Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: isVisible ? Colors.white : Colors.white24,
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: SettingsService.ttsEnabled,
                    builder: (context, enabled, _) {
                      if (!enabled) return const SizedBox.shrink();
                      return ValueListenableBuilder<bool>(
                        valueListenable: TtsService.instance.isSpeaking,
                        builder: (context, speaking, _) {
                          return IconButton(
                            tooltip: speaking
                                ? AppStrings.ttsStopTooltip
                                : AppStrings.ttsPlayTooltip,
                            icon: Icon(
                              speaking
                                  ? Icons.stop_circle_outlined
                                  : Icons.volume_up_outlined,
                              size: 22,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: _toggleTts,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isLastBlockVisible
                        ? AppStrings.tapToContinue
                        : AppStrings.tapToContinue,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientParticlesPainter extends CustomPainter {
  final double t;
  final bool powerMode;
  final int seed;
  final _AmbientScene scene;
  final double intensity;

  const _AmbientParticlesPainter({
    required this.t,
    required this.powerMode,
    required this.seed,
    required this.scene,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final particles = switch (scene) {
      _AmbientScene.rain => powerMode ? 24 : 14,
      _AmbientScene.mist => powerMode ? 20 : 12,
      _AmbientScene.lights => powerMode ? 22 : 14,
      _AmbientScene.dust => powerMode ? 18 : 10,
    };
    final particleCount = (particles * intensity).round().clamp(6, 46);
    for (var i = 0; i < particleCount; i++) {
      final n = (i + 1) * 0.6180339887 + seed * 0.113;
      final x = ((n * 137.5) % 1.0) * size.width;
      final drift = math.sin((t * 2 * math.pi) + n * 12.0);
      final yBase = ((n * 53.7) % 1.0) * size.height;
      final y = switch (scene) {
        _AmbientScene.rain =>
          ((yBase + (t * size.height * 1.3) + (n * size.height)) % size.height),
        _ => (yBase + drift * (powerMode ? 16.0 : 8.0)) % size.height,
      };
      final radius = switch (scene) {
        _AmbientScene.rain => powerMode ? 1.4 : 1.0,
        _AmbientScene.lights => powerMode ? 1.6 + (n % 1.4) : 1.0 + (n % 1.0),
        _ => powerMode ? 1.2 + (n % 1.2) : 0.8 + (n % 0.8),
      };
      final alphaBase = powerMode ? 0.26 : 0.12;
      final alphaPulse = (math.sin((t * 2 * math.pi) + n * 20.0) + 1) * 0.5;
      final alpha =
          (alphaBase * (0.65 + (alphaPulse * 0.7)) * intensity).clamp(0.0, 1.0);
      final color = switch (scene) {
        _AmbientScene.rain => const Color(0xFFB3E5FC).withValues(alpha: alpha),
        _AmbientScene.lights =>
          const Color(0xFFFFF59D).withValues(alpha: alpha),
        _ => powerMode
            ? const Color(0xFFFFA36C).withValues(alpha: alpha)
            : Colors.white.withValues(alpha: alpha),
      };
      final paint = Paint()..color = color;
      if (scene == _AmbientScene.rain) {
        final len = powerMode ? 11.0 : 8.0;
        canvas.drawLine(
          Offset(x, y),
          Offset(x - 2.2, (y + len).clamp(0.0, size.height)),
          paint..strokeWidth = powerMode ? 1.3 : 1.0,
        );
      } else {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientParticlesPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.powerMode != powerMode ||
        oldDelegate.seed != seed ||
        oldDelegate.scene != scene ||
        oldDelegate.intensity != intensity;
  }
}

class _AmbientAtmospherePainter extends CustomPainter {
  final double t;
  final bool powerMode;
  final _AmbientScene scene;
  final double intensity;

  const _AmbientAtmospherePainter({
    required this.t,
    required this.powerMode,
    required this.scene,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (scene) {
      case _AmbientScene.mist:
        _paintMist(canvas, size);
      case _AmbientScene.lights:
        _paintLights(canvas, size);
      case _AmbientScene.rain:
      case _AmbientScene.dust:
        return;
    }
  }

  void _paintMist(Canvas canvas, Size size) {
    final dx = math.sin(t * math.pi * 2) * 22;
    final dy = math.cos(t * math.pi * 2 * 0.7) * 10;
    final alpha = (powerMode ? 0.22 : 0.14) * intensity;
    final rect =
        Offset(dx - 30, dy - 20) & Size(size.width + 60, size.height + 40);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF90A4AE).withValues(alpha: alpha * 0.75),
          const Color(0xFF607D8B).withValues(alpha: alpha),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintLights(Canvas canvas, Size size) {
    final sweep = (math.sin(t * math.pi * 2) + 1) * 0.5;
    final x = size.width * (0.15 + sweep * 0.7);
    final paint = Paint()
      ..shader = RadialGradient(
        radius: powerMode ? 0.48 : 0.36,
        colors: [
          Colors.white.withValues(alpha: (powerMode ? 0.11 : 0.07) * intensity),
          const Color(0xFF64B5F6)
              .withValues(alpha: (powerMode ? 0.08 : 0.05) * intensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(x, size.height * 0.32), radius: size.width * 0.42));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientAtmospherePainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.powerMode != powerMode ||
        oldDelegate.scene != scene ||
        oldDelegate.intensity != intensity;
  }
}

enum _AmbientScene { dust, rain, mist, lights }

enum _NarrativeTone { neutral, dialogue, thought, system }

class _NarrativeFocusPainter extends CustomPainter {
  final double t;
  final _NarrativeTone tone;
  final bool powerMode;
  final double intensity;

  const _NarrativeFocusPainter({
    required this.t,
    required this.tone,
    required this.powerMode,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (tone) {
      case _NarrativeTone.dialogue:
        _paintDialogueFocus(canvas, size);
      case _NarrativeTone.thought:
        _paintThoughtVignette(canvas, size);
      case _NarrativeTone.system:
        _paintSystemPulse(canvas, size);
      case _NarrativeTone.neutral:
        return;
    }
  }

  void _paintDialogueFocus(Canvas canvas, Size size) {
    final breath = (math.sin(t * math.pi * 2) + 1) * 0.5;
    final center = Offset(size.width * 0.5, size.height * 0.68);
    final radius = size.width * (0.62 + breath * 0.05);
    final overlay = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.25),
        radius: 1.0,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: (powerMode ? 0.18 : 0.24) * intensity),
        ],
        stops: const [0.38, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawRect(Offset.zero & size, overlay);
  }

  void _paintThoughtVignette(Canvas canvas, Size size) {
    final drift = math.sin(t * math.pi * 2 * 0.6) * 0.03;
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(drift, -0.08),
        radius: 1.05,
        colors: [
          const Color(0xFF6A1B9A).withValues(alpha: 0.05),
          Colors.black.withValues(alpha: 0.26 * intensity),
        ],
        stops: const [0.25, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintSystemPulse(Canvas canvas, Size size) {
    final k = (math.sin(t * math.pi * 2 * 1.8) + 1) * 0.5;
    final alpha = (0.06 + k * 0.08) * intensity;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: alpha),
          Colors.transparent,
          Colors.white.withValues(alpha: alpha * 0.8),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _NarrativeFocusPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.tone != tone ||
        oldDelegate.powerMode != powerMode ||
        oldDelegate.intensity != intensity;
  }
}
