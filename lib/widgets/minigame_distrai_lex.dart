// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/comic_data.dart';

/// Mini-game DISTRAI LEX — tappa gli oggetti per distrarre Lex prima che
/// raggiunga l'acqua.
///
/// - Ogni 1.2s appare un nuovo oggetto (🐚 / 🏐 / 🎩) in posizione casuale.
/// - L'oggetto sparisce dopo 2s se non tappato.
/// - Lex avanza verso l'acqua: +0.025/s. Ogni tap riuscito: -0.05.
/// - Timer: 15s.
/// - Score = tap riusciti totali.
/// - Tier: ≥5 = preso_bene, 3–4 = quasi_visto, ≤2 = momento_magico.
class MinigameDistraiLexScreen extends StatefulWidget {
  final MinigameConfig config;
  final void Function(
          Map<String, int> statEffects, String tierLabel, MinigameTier tier)
      onComplete;

  const MinigameDistraiLexScreen(
      {super.key, required this.config, required this.onComplete});

  @override
  State<MinigameDistraiLexScreen> createState() =>
      _MinigameDistraiLexScreenState();
}

class _MinigameDistraiLexScreenState extends State<MinigameDistraiLexScreen>
    with TickerProviderStateMixin {
  static const _lexSpeed = 0.025; // per second
  static const _tapReduction = 0.05;
  static const _spawnIntervalMs = 1200;
  static const _objectLifeMs = 2000;

  static const _objects = ['🐚', '🏐', '🎩'];
  final _random = Random();

  double _lexProgress = 0.0; // 0 = shore, 1 = reached water
  int _secondsLeft = 15;
  int _taps = 0;
  bool _finished = false;

  // Active objects: each entry is {id, emoji, x, y, birth (DateTime)}
  final List<_SpawnedObject> _spawned = [];
  int _nextId = 0;

  Timer? _gameTicker; // 100ms game loop
  Timer? _spawnTimer; // 1200ms spawn

  // Bounce animation for Lex icon
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.config.durationSeconds ?? 15;

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _bounceAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
    );

    _gameTicker =
        Timer.periodic(const Duration(milliseconds: 100), _gameTick);
    _spawnTimer =
        Timer.periodic(const Duration(milliseconds: _spawnIntervalMs), _spawn);
  }

  void _gameTick(Timer t) {
    if (_finished) return;
    setState(() {
      _lexProgress = (_lexProgress + _lexSpeed / 10).clamp(0.0, 1.0);
      // Expire old objects
      final now = DateTime.now();
      _spawned.removeWhere(
          (o) => now.difference(o.birth).inMilliseconds >= _objectLifeMs);
      // Countdown every 10 ticks = 1s
      if (t.tick % 10 == 0) {
        _secondsLeft = (_secondsLeft - 1).clamp(0, 999);
        if (_secondsLeft <= 0 || _lexProgress >= 1.0) _finish();
      }
    });
  }

  void _spawn(Timer t) {
    if (_finished) return;
    setState(() {
      _spawned.add(_SpawnedObject(
        id: _nextId++,
        emoji: _objects[_random.nextInt(_objects.length)],
        // x: 0.05 – 0.85 of width; y: 0.25 – 0.75 of height (avoid UI bars)
        x: 0.05 + _random.nextDouble() * 0.80,
        y: 0.25 + _random.nextDouble() * 0.50,
        birth: DateTime.now(),
      ));
    });
  }

  void _tapObject(int id) {
    if (_finished) return;
    final idx = _spawned.indexWhere((o) => o.id == id);
    if (idx == -1) return;
    setState(() {
      _spawned.removeAt(idx);
      _taps++;
      _lexProgress = (_lexProgress - _tapReduction).clamp(0.0, 1.0);
    });
    _bounceController.forward(from: 0);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _gameTicker?.cancel();
    _spawnTimer?.cancel();

    final tier = widget.config.tierFor(_taps);
    widget.onComplete(tier.statEffects, tier.label, tier);
  }

  @override
  void dispose() {
    _gameTicker?.cancel();
    _spawnTimer?.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeProgress = _secondsLeft / (widget.config.durationSeconds ?? 15);
    final isClose = _lexProgress >= 0.65;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F2E),
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            children: [
              // Ocean gradient background
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A2540), Color(0xFF1B6CA8)],
                  ),
                ),
              ),

              // Top HUD
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        'DISTRAI LEX!',
                        style: TextStyle(
                          fontFamily: 'Bangers',
                          fontSize: 34,
                          color:
                              isClose ? const Color(0xFFFF6B35) : Colors.white,
                          letterSpacing: 4,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 8)
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'TAPPA GLI OGGETTI',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Timer bar
                      _Bar(
                        progress: timeProgress,
                        lowColor: Colors.red,
                        highColor: Colors.cyanAccent,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_secondsLeft s  •  $_taps tap',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Lex progress bar
                      Row(
                        children: [
                          Text('🏖️ ',
                              style: const TextStyle(fontSize: 16)),
                          Expanded(
                            child: _Bar(
                              progress: _lexProgress,
                              highColor: Colors.orange,
                              lowColor: Colors.greenAccent,
                              reverse: true,
                            ),
                          ),
                          const Text(' 🌊', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isClose ? 'Lex sta arrivando all\'acqua!' : 'Lex: tenuto a bada',
                        style: TextStyle(
                          fontSize: 12,
                          color: isClose
                              ? const Color(0xFFFF6B35)
                              : Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tappable objects
              for (final obj in List.of(_spawned))
                Positioned(
                  left: obj.x * w - 24,
                  top: obj.y * h - 24,
                  child: GestureDetector(
                    onTap: () => _tapObject(obj.id),
                    child: _ObjectTile(
                      emoji: obj.emoji,
                      birth: obj.birth,
                      lifeMs: _objectLifeMs,
                    ),
                  ),
                ),

              // Lex icon on the progress bar area (animated bounce)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _bounceAnim,
                  builder: (ctx, child) => Transform.translate(
                    offset: Offset(0, _bounceAnim.value),
                    child: child,
                  ),
                  child: Center(
                    child: Text(
                      '👶',
                      style: TextStyle(fontSize: isClose ? 42 : 32),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _SpawnedObject {
  final int id;
  final String emoji;
  final double x;
  final double y;
  final DateTime birth;

  const _SpawnedObject(
      {required this.id,
      required this.emoji,
      required this.x,
      required this.y,
      required this.birth});
}

class _ObjectTile extends StatelessWidget {
  final String emoji;
  final DateTime birth;
  final int lifeMs;

  const _ObjectTile(
      {required this.emoji, required this.birth, required this.lifeMs});

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(birth).inMilliseconds;
    final fade = 1.0 - (age / lifeMs).clamp(0.0, 1.0);

    return Opacity(
      opacity: fade.clamp(0.3, 1.0),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 12,
            ),
          ],
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double progress;
  final Color highColor;
  final Color lowColor;
  final bool reverse;

  const _Bar({
    required this.progress,
    required this.highColor,
    required this.lowColor,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = reverse
        ? (progress > 0.5 ? lowColor : progress > 0.25 ? Colors.orange : highColor)
        : (progress > 0.5 ? highColor : progress > 0.25 ? Colors.orange : lowColor);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 7,
        backgroundColor: Colors.white.withOpacity(0.1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
