// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:async';
import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comic_data.dart';

/// Mini-game DISTRAI LEX — tappa gli oggetti per distrarre Lex prima che
/// raggiunga l'acqua.
///
/// - Ogni 1.2s appare un oggetto (🐚 / 🏐 / 🎩) in posizione casuale.
/// - Auto-scompare dopo 2s se non tappato.
/// - Lex avanza verso il mare: +0.025/s. Ogni tap riuscito: -0.05.
/// - Timer: 15s. Score = tap riusciti totali.
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

// ─── Game constants ───────────────────────────────────────────────────────────

const _kLexSpeed      = 0.025;  // progress/s
const _kTapReduction  = 0.05;
const _kSpawnMs       = 1200;
const _kObjectLifeMs  = 2000;
const _kObjects       = ['🐚', '🏐', '🎩'];

// ─── Data ─────────────────────────────────────────────────────────────────────

class _SpawnedObject {
  final int id;
  final String emoji;
  final double x, y;   // 0..1 normalised screen fraction
  final DateTime birth;
  double scale;        // 0→1 pop-in

  _SpawnedObject({
    required this.id,
    required this.emoji,
    required this.x,
    required this.y,
    required this.birth,
    this.scale = 0.0,
  });
}

class _TapParticle {
  double x, y;        // normalised screen
  double vx, vy;
  double life;
  double size;
  Color color;
  _TapParticle({required this.x, required this.y, required this.vx,
    required this.vy, required this.life, required this.size,
    required this.color});
}

// ─── State ────────────────────────────────────────────────────────────────────

class _MinigameDistraiLexScreenState extends State<MinigameDistraiLexScreen>
    with TickerProviderStateMixin {

  double _lexProgress = 0.0;
  int    _secondsLeft = 15;
  int    _taps = 0;
  bool   _finished = false;

  final List<_SpawnedObject>  _spawned   = [];
  final List<_TapParticle>    _particles = [];
  int _nextId = 0;

  Timer? _gameTicker;
  Timer? _spawnTimer;

  // Wave / visual animation (continuous)
  late AnimationController _waveCtrl;

  // Lex wobble
  late AnimationController _wobbleCtrl;
  late Animation<double> _wobbleAnim;

  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.config.durationSeconds ?? 15;

    // Continuous wave animation
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Lex horizontal wobble
    _wobbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _wobbleAnim = Tween<double>(begin: -4.0, end: 4.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_wobbleCtrl);

    _gameTicker =
        Timer.periodic(const Duration(milliseconds: 33), _gameTick);
    _spawnTimer =
        Timer.periodic(const Duration(milliseconds: _kSpawnMs), _spawn);
  }

  void _gameTick(Timer t) {
    if (_finished || !mounted) return;
    const dt = 0.033;
    setState(() {
      // Lex advances
      _lexProgress = (_lexProgress + _kLexSpeed * dt).clamp(0.0, 1.0);

      // Pop-in animation for objects
      final now = DateTime.now();
      for (final o in _spawned) {
        o.scale = (o.scale + dt * 5.0).clamp(0.0, 1.0);
        // expire
      }
      _spawned.removeWhere(
          (o) => now.difference(o.birth).inMilliseconds >= _kObjectLifeMs);

      // Particles
      for (final p in _particles) {
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.life -= dt * 2.5;
        p.vy += 1.8 * dt;
      }
      _particles.removeWhere((p) => p.life <= 0);

      // Countdown every 30 ticks ≈ 1s (33ms * 30 ≈ 990ms)
      if (t.tick % 30 == 0) {
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
        emoji: _kObjects[_rng.nextInt(_kObjects.length)],
        x: 0.06 + _rng.nextDouble() * 0.82,
        // Keep objects in upper half (sky/upper beach area), avoid HUD and Lex row
        y: 0.22 + _rng.nextDouble() * 0.40,
        birth: DateTime.now(),
      ));
    });
  }

  void _tapObject(int id) {
    if (_finished) return;
    final idx = _spawned.indexWhere((o) => o.id == id);
    if (idx == -1) return;

    final obj = _spawned[idx];
    HapticFeedback.lightImpact();

    setState(() {
      _spawned.removeAt(idx);
      _taps++;
      _lexProgress = (_lexProgress - _kTapReduction).clamp(0.0, 1.0);
    });

    // Spawn sparkle particles at tap position
    for (int i = 0; i < 8; i++) {
      final angle = (_rng.nextDouble() * 2 * pi);
      final speed = 0.2 + _rng.nextDouble() * 0.3;
      _particles.add(_TapParticle(
        x: obj.x,
        y: obj.y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 0.2,
        life: 1.0,
        size: 5 + _rng.nextDouble() * 7,
        color: [
          const Color(0xFFFFD700),
          const Color(0xFFFF8C00),
          const Color(0xFF00CFFF),
        ][_rng.nextInt(3)],
      ));
    }
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
    _waveCtrl.dispose();
    _wobbleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSecs  = widget.config.durationSeconds ?? 15;
    final timeProgress = _secondsLeft / totalSecs;
    final isClose    = _lexProgress >= 0.65;

    return Scaffold(
      backgroundColor: const Color(0xFF87CEEB),
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return AnimatedBuilder(
            animation: Listenable.merge([_waveCtrl, _wobbleCtrl]),
            builder: (ctx, child) {
              final waveOffset = _waveCtrl.value;
              final lexX = lerpDouble(0.08, 0.74, _lexProgress)! * w;
              final lexY = h * 0.72;

              return Stack(
                children: [
                  // ── Beach background (CustomPaint) ──────────────────────
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(w, h),
                      painter: _BeachPainter(
                        waveOffset: waveOffset,
                        lexProgress: _lexProgress,
                      ),
                    ),
                  ),

                  // ── Tappable objects ────────────────────────────────────
                  for (final obj in List.of(_spawned))
                    Positioned(
                      left: obj.x * w - 28,
                      top:  obj.y * h - 28,
                      child: GestureDetector(
                        onTap: () => _tapObject(obj.id),
                        child: _ObjectWidget(
                          obj: obj,
                          lifeMs: _kObjectLifeMs,
                        ),
                      ),
                    ),

                  // ── Tap sparkle particles ───────────────────────────────
                  for (final p in _particles)
                    Positioned(
                      left: p.x * w - p.size / 2,
                      top:  p.y * h - p.size / 2,
                      child: Opacity(
                        opacity: p.life.clamp(0, 1),
                        child: Container(
                          width: p.size,
                          height: p.size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.color,
                            boxShadow: [
                              BoxShadow(
                                color: p.color.withOpacity(0.7),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Lex character ───────────────────────────────────────
                  Positioned(
                    left: lexX - 22 + _wobbleAnim.value,
                    top:  lexY - 36,
                    child: _LexCharacter(
                      progress: _lexProgress,
                      isClose: isClose,
                    ),
                  ),

                  // ── HUD ─────────────────────────────────────────────────
                  _DistraiHud(
                    secondsLeft: _secondsLeft,
                    timeProgress: timeProgress,
                    taps: _taps,
                    isClose: isClose,
                  ),
                ],
              );
            },
          );
        }),
      ),
    );
  }
}

// ─── Beach CustomPainter ──────────────────────────────────────────────────────

class _BeachPainter extends CustomPainter {
  final double waveOffset;
  final double lexProgress;

  const _BeachPainter({required this.waveOffset, required this.lexProgress});

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawSea(canvas, size, waveOffset);
    _drawSand(canvas, size);
    _drawWaves(canvas, size, waveOffset);
    _drawLexTrack(canvas, size);
  }

  void _drawSky(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.45);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FC3F7), Color(0xFF87CEEB)],
        ).createShader(rect),
    );

    // Sun
    final sunPaint = Paint()
      ..color = const Color(0xFFFFE066)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.12), 28, sunPaint);
    final sunPaint2 = Paint()..color = const Color(0xFFFFF176);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.12), 18, sunPaint2);

    // Clouds (static, based on fixed seeds)
    _drawCloud(canvas, Offset(size.width * 0.2, size.height * 0.10), 38);
    _drawCloud(canvas, Offset(size.width * 0.55, size.height * 0.08), 24);
  }

  void _drawCloud(Canvas canvas, Offset center, double radius) {
    final p = Paint()..color = Colors.white.withOpacity(0.85);
    canvas.drawCircle(center, radius, p);
    canvas.drawCircle(center.translate(-radius * 0.6, radius * 0.2), radius * 0.65, p);
    canvas.drawCircle(center.translate( radius * 0.6, radius * 0.2), radius * 0.55, p);
  }

  void _drawSea(Canvas canvas, Size size, double wave) {
    final seaTop = size.height * 0.44;
    final rect = Rect.fromLTWH(0, seaTop, size.width, size.height * 0.20);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF039BE5), Color(0xFF0277BD)],
        ).createShader(rect),
    );
  }

  void _drawWaves(Canvas canvas, Size size, double wave) {
    final waveY = size.height * 0.60;
    final paint = Paint()
      ..color = const Color(0xFF29B6F6).withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      final yOff = waveY + layer * 8.0;
      final phase = wave * 2 * pi + layer * 1.1;
      path.moveTo(0, yOff);
      for (double x = 0; x <= size.width; x += 4) {
        final y = yOff + sin(x / 28 + phase) * 5;
        path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF4DD0E1).withOpacity(0.55 - layer * 0.12)
          ..strokeWidth = 2.5 - layer * 0.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawSand(Canvas canvas, Size size) {
    final sandTop = size.height * 0.58;
    final rect = Rect.fromLTWH(0, sandTop, size.width, size.height - sandTop);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFF9E4A3), Color(0xFFD4A44C)],
        ).createShader(rect),
    );

    // Footprints / dots
    final dotPaint = Paint()
      ..color = const Color(0xFFC79A3A).withOpacity(0.35);
    final rng = Random(12);
    for (int i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = sandTop + rng.nextDouble() * (size.height - sandTop);
      canvas.drawCircle(Offset(x, y), 1.5 + rng.nextDouble() * 2, dotPaint);
    }
  }

  void _drawLexTrack(Canvas canvas, Size size) {
    // Subtle dashed track from start to water (Lex path)
    final trackPaint = Paint()
      ..color = const Color(0xFFE65100).withOpacity(0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final startX = size.width * 0.08;
    final endX   = size.width * 0.82;
    final y      = size.height * 0.72;

    for (double x = startX; x < endX; x += 14) {
      canvas.drawLine(Offset(x, y + 18), Offset(x + 8, y + 18), trackPaint);
    }
  }

  @override
  bool shouldRepaint(_BeachPainter old) =>
      old.waveOffset != waveOffset || old.lexProgress != lexProgress;
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _ObjectWidget extends StatelessWidget {
  final _SpawnedObject obj;
  final int lifeMs;

  const _ObjectWidget({required this.obj, required this.lifeMs});

  @override
  Widget build(BuildContext context) {
    final age      = DateTime.now().difference(obj.birth).inMilliseconds;
    final lifeFrac = age / lifeMs;
    final opacity  = lifeFrac > 0.75 ? 1.0 - (lifeFrac - 0.75) / 0.25 : 1.0;
    final scale    = obj.scale;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity.clamp(0.15, 1.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glow ring
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.22),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.40),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.55),
                  width: 1.5,
                ),
              ),
            ),
            // Shadow on sand
            Positioned(
              bottom: 2,
              child: Container(
                width: 36,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Text(obj.emoji, style: const TextStyle(fontSize: 28)),
          ],
        ),
      ),
    );
  }
}

class _LexCharacter extends StatelessWidget {
  final double progress;
  final bool isClose;

  const _LexCharacter({required this.progress, required this.isClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Danger glow when close to water
        if (isClose)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.45 + progress * 0.25),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        // Shadow on sand
        Positioned(
          bottom: 0,
          child: Container(
            width: 32,
            height: 7,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        Text('👶', style: TextStyle(fontSize: isClose ? 40 : 34)),
        // Arrow indicator above Lex
        if (!isClose)
          Positioned(
            top: -18,
            child: const Text('⬇️', style: TextStyle(fontSize: 14)),
          ),
        if (isClose)
          Positioned(
            top: -20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'FERMO!',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DistraiHud extends StatelessWidget {
  final int secondsLeft;
  final double timeProgress;
  final int taps;
  final bool isClose;

  const _DistraiHud({
    required this.secondsLeft,
    required this.timeProgress,
    required this.taps,
    required this.isClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.55),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title + timer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isClose ? 'TAPPALI! 🚨' : 'DISTRAI LEX!',
                  style: TextStyle(
                    fontFamily: 'Bangers',
                    fontSize: 26,
                    color:
                        isClose ? const Color(0xFFFF6B35) : Colors.white,
                    letterSpacing: 3,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 6),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '🐾 $taps',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: secondsLeft <= 5
                            ? Colors.red.withOpacity(0.85)
                            : Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${secondsLeft}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Timer bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: timeProgress,
                minHeight: 5,
                backgroundColor: Colors.white.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  timeProgress > 0.5
                      ? Colors.cyanAccent
                      : timeProgress > 0.25
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Hint
            Text(
              isClose
                  ? 'Lex sta quasi toccando il mare!'
                  : 'Tappa gli oggetti per distrarlo! 🐚🏐🎩',
              style: TextStyle(
                fontSize: 11,
                color: isClose
                    ? const Color(0xFFFF6B35)
                    : Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
