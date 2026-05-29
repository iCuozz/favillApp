// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import '../models/comic_data.dart';

/// Mini-game RINCORSA — city/park Temple-Run: insegui il ladro che ha rubato la borsetta di Favilla.
///
/// 3 corsie. Scivola sinistra/destra per cambiare corsia ed evitare ostacoli.
/// Gap decresce naturalmente mentre corri; le collisioni lo aumentano.
///
/// Tier: gap ≤ 0.30 → score 2 (preso) | ≤ 0.65 → score 1 (quasi) | > 0.65 → score 0 (perso).
class MinigameRincorsaScreen extends StatefulWidget {
  final MinigameConfig config;
  final void Function(
          Map<String, int> statEffects, String tierLabel, MinigameTier tier)
      onComplete;

  const MinigameRincorsaScreen(
      {super.key, required this.config, required this.onComplete});

  @override
  State<MinigameRincorsaScreen> createState() => _MinigameRincorsaScreenState();
}

// ─── Game constants ─────────────────────────────────────────────────────────
const _kStartGap = 0.55;
const _kNaturalRecovery = 0.022; // gap/s — running > walking thief
const _kCollisionPenalty = 0.18;
const _kObstacleSpeed = 0.62; // track-y units/s
const _kSpawnInterval = 1.35; // seconds
const _kSwitchSpeed = 9.0; // lerp units/s
const _kStunDuration = 0.55; // seconds

// Visual track constants
const _kHorizonFrac = 0.38; // horizon fraction of screen height
const _kHorizonHalfW = 44.0; // track half-width at horizon (px)
const _kBottomHalfWFrac = 0.44; // track half-width at bottom = frac * screenW

// ─── Data ────────────────────────────────────────────────────────────────────

enum _ObstacleType { branch, trunk, squirrel, hedgehog, puddle }

extension _ObstacleExt on _ObstacleType {
  String get emoji {
    switch (this) {
      case _ObstacleType.branch:
        return '🌿';
      case _ObstacleType.trunk:
        return '🪵';
      case _ObstacleType.squirrel:
        return '🐿️';
      case _ObstacleType.hedgehog:
        return '🦔';
      case _ObstacleType.puddle:
        return '💧';
    }
  }
}

class _Obstacle {
  final int lane;
  double y; // 0 = top (just spawned), 1 = bottom (at player)
  final _ObstacleType type;
  bool consumed; // already scored a hit

  _Obstacle({required this.lane, required this.y, required this.type})
      : consumed = false;
}

enum _RunState { normal, switching, stunned }

// ─── Widget ───────────────────────────────────────────────────────────────────

class _MinigameRincorsaScreenState extends State<MinigameRincorsaScreen>
    with TickerProviderStateMixin {
  // ── Game state ────────────────────────────────────────────────────────────
  double _gap = _kStartGap;
  double _elapsed = 0;
  bool _finished = false;

  // ── Runner ────────────────────────────────────────────────────────────────
  int _lane = 1; // logical lane (0=L 1=C 2=R)
  int _fromLane = 1;
  int _toLane = 1;
  double _laneT = 1.0; // 0→1 lerp during switch
  _RunState _runState = _RunState.normal;
  double _stunT = 0.0; // 0→1 stun progress

  // ── Obstacles ─────────────────────────────────────────────────────────────
  final List<_Obstacle> _obstacles = [];
  double _timeSinceSpawn = 0.0;
  int _lastSpawnLane = -1;
  int _consecutiveSpawnSame = 0;

  // ── Scrolling track ───────────────────────────────────────────────────────
  double _scrollOffset = 0.0; // 0..1, loops

  // ── Particle system (dust on collision) ──────────────────────────────────
  final List<_Particle> _particles = [];

  // ── Ticker ────────────────────────────────────────────────────────────────
  late Ticker _ticker;
  Duration? _lastTick;

  // ── Stun flash ────────────────────────────────────────────────────────────
  late AnimationController _flashCtrl;
  late Animation<double> _flashAnim;

  // ── Screen shake ─────────────────────────────────────────────────────────
  late AnimationController _shakeCtrl;
  late Animation<Offset> _shakeAnim;

  // ── Tutorial ─────────────────────────────────────────────────────────────
  bool _showTutorial = true;

  final _rng = Random();

  int get _durationSeconds => widget.config.durationSeconds ?? 15;
  int get _secondsLeft => max(0, _durationSeconds - _elapsed.floor());

  @override
  void initState() {
    super.initState();

    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _flashAnim = Tween<double>(begin: 0, end: 0.55)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_flashCtrl);

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _shakeAnim = Tween<Offset>(begin: Offset.zero, end: const Offset(6, 4))
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_shakeCtrl);

    _ticker = createTicker(_onTick);
  }

  void _startGame() {
    setState(() => _showTutorial = false);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_finished) return;

    final dt =
        _lastTick == null ? 0.0 : (elapsed - _lastTick!).inMicroseconds / 1e6;
    _lastTick = elapsed;

    if (dt <= 0) return;

    setState(() {
      _elapsed += dt;
      _scrollOffset = (_scrollOffset + dt * 0.55) % 1.0;

      // ── Natural gap recovery ─────────────────────────────────────────────
      _gap = (_gap - _kNaturalRecovery * dt).clamp(0.0, 1.0);

      // ── Lane switch lerp ─────────────────────────────────────────────────
      if (_runState == _RunState.switching) {
        _laneT = min(1.0, _laneT + _kSwitchSpeed * dt);
        if (_laneT >= 1.0) {
          _lane = _toLane;
          _runState = _RunState.normal;
          _laneT = 1.0;
        }
      }

      // ── Stun countdown ───────────────────────────────────────────────────
      if (_runState == _RunState.stunned) {
        _stunT = min(1.0, _stunT + dt / _kStunDuration);
        if (_stunT >= 1.0) {
          _runState = _RunState.normal;
          _stunT = 0.0;
        }
      }

      // ── Spawn obstacle ───────────────────────────────────────────────────
      _timeSinceSpawn += dt;
      if (_timeSinceSpawn >= _kSpawnInterval) {
        _timeSinceSpawn = 0;
        _spawnObstacle();
      }

      // ── Move obstacles + collision ────────────────────────────────────────
      for (final obs in _obstacles) {
        obs.y += _kObstacleSpeed * dt;

        if (!obs.consumed && obs.y >= 0.72 && obs.y <= 0.90) {
          final visualLane = _runState == _RunState.switching
              ? (_laneT < 0.5 ? _fromLane : _toLane)
              : _lane;
          if (obs.lane == visualLane && _runState != _RunState.stunned) {
            _onCollision(obs);
          }
        }
      }

      // Remove old obstacles
      _obstacles.removeWhere((o) => o.y > 1.15);

      // ── Particles ────────────────────────────────────────────────────────
      for (final p in _particles) {
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.life -= dt * 2.2;
        p.vy += 1.5 * dt; // gravity
      }
      _particles.removeWhere((p) => p.life <= 0);

      // ── Win / time check ─────────────────────────────────────────────────
      if (_gap <= 0 || _elapsed >= _durationSeconds) {
        _finish();
      }
    });
  }

  void _spawnObstacle() {
    // Pick random lane, avoid 2+ consecutive on same lane
    final available = [0, 1, 2].where((l) {
      if (_consecutiveSpawnSame >= 2 && l == _lastSpawnLane) return false;
      return true;
    }).toList()
      ..shuffle(_rng);
    final lane = available.first;

    final type =
        _ObstacleType.values[_rng.nextInt(_ObstacleType.values.length)];
    _obstacles.add(_Obstacle(lane: lane, y: -0.08, type: type));

    if (lane == _lastSpawnLane) {
      _consecutiveSpawnSame++;
    } else {
      _consecutiveSpawnSame = 0;
    }
    _lastSpawnLane = lane;
  }

  void _onCollision(_Obstacle obs) {
    obs.consumed = true;
    _gap = (_gap + _kCollisionPenalty).clamp(0.0, 1.0);
    _runState = _RunState.stunned;
    _stunT = 0.0;
    _flashCtrl.forward(from: 0).then((_) => _flashCtrl.reverse());
    _shakeCtrl.forward(from: 0);

    // Spawn dust particles
    // (We'll need size in onTick, use placeholder coords)
    HapticFeedback.heavyImpact();
    for (int i = 0; i < 10; i++) {
      _particles.add(_Particle(
        x: 0.5 + (_rng.nextDouble() - 0.5) * 0.15,
        y: 0.88,
        vx: (_rng.nextDouble() - 0.5) * 0.5,
        vy: -0.4 - _rng.nextDouble() * 0.4,
        color: Color.lerp(const Color(0xFFD4A017), const Color(0xFFBF360C),
            _rng.nextDouble())!,
        life: 1.0,
        size: 6 + _rng.nextDouble() * 8,
      ));
    }
  }

  void _onSwipe(DragEndDetails details) {
    if (_finished || _showTutorial) return;
    if (_runState == _RunState.stunned) return;

    final vx = details.velocity.pixelsPerSecond.dx;
    if (vx.abs() < 150) return; // threshold

    final currentLogical = _runState == _RunState.switching ? _toLane : _lane;
    final target = vx < 0
        ? (currentLogical - 1).clamp(0, 2)
        : (currentLogical + 1).clamp(0, 2);

    if (target == currentLogical) return; // already at edge

    HapticFeedback.lightImpact();
    setState(() {
      _fromLane = currentLogical;
      _toLane = target;
      _laneT = 0.0;
      _runState = _RunState.switching;
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _ticker.stop();

    final int score = _gap <= 0.30
        ? 2
        : _gap <= 0.65
            ? 1
            : 0;
    final tier = widget.config.tierFor(score);
    widget.onComplete(tier.statEffects, tier.label, tier);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _flashCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Current visual lane x (0..1 normalized) ──────────────────────────────
  double get _visualLaneNorm {
    final from = _fromLane / 2.0;
    final to = _toLane / 2.0;
    return lerpDouble(from, to, _laneT)!;
  }

  @override
  Widget build(BuildContext context) {
    if (_showTutorial) return _buildTutorial(context);

    return LayoutBuilder(builder: (ctx, constraints) {
      final size = constraints.biggest;
      return GestureDetector(
        onHorizontalDragEnd: _onSwipe,
        child: AnimatedBuilder(
          animation: _shakeAnim,
          builder: (ctx, child) => Transform.translate(
            offset: _shakeAnim.value,
            child: child,
          ),
          child: _buildGame(size),
        ),
      );
    });
  }

  Widget _buildGame(Size size) {
    final horizonY = size.height * _kHorizonFrac;
    final bHalfW = size.width * _kBottomHalfWFrac;

    // Favilla visual X at bottom
    final favillaVisX = _laneVisualX(_visualLaneNorm, size);
    // Lex position (upper track, moves down as gap shrinks)
    final lexT = (0.08 + (1.0 - _gap) * 0.28).clamp(0.0, 0.50);
    final lexPos = _trackPos(lexT, 1, size, horizonY, bHalfW);
    final lexSize = lerpDouble(22.0, 62.0, (1.0 - _gap).clamp(0, 1))!;

    return Stack(
      children: [
        // ── Background (CustomPaint) ───────────────────────────────────────
        RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: _TrackPainter(
              scrollOffset: _scrollOffset,
              flashIntensity: _flashAnim.value,
              stunProgress: _stunT,
            ),
          ),
        ),

        // ── Obstacles ─────────────────────────────────────────────────────
        for (final obs in _obstacles) ...[
          () {
            final pos = _trackPos(obs.y, obs.lane, size, horizonY, bHalfW);
            final sz = _trackSpriteSize(obs.y);
            final glow = (!obs.consumed && obs.y >= 0.55 && obs.y <= 0.90)
                ? (obs.y - 0.55) / 0.35
                : 0.0;
            return Positioned(
              left: pos.dx - sz / 2,
              top: pos.dy - sz * 0.9,
              child: _ObstacleSprite(
                emoji: obs.type.emoji,
                size: sz,
                glowFactor: glow.clamp(0, 1),
                lane: obs.lane,
                currentLane: _lane,
              ),
            );
          }(),
        ],

        // ── Lex ───────────────────────────────────────────────────────────
        Positioned(
          left: lexPos.dx - lexSize / 2,
          top: lexPos.dy - lexSize * 0.85,
          child: _LexSprite(size: lexSize, gap: _gap),
        ),

        // ── Particles ─────────────────────────────────────────────────────
        for (final p in _particles)
          Positioned(
            left: p.x * size.width - p.size / 2,
            top: p.y * size.height - p.size / 2,
            child: Opacity(
              opacity: p.life.clamp(0, 1),
              child: Container(
                width: p.size,
                height: p.size,
                decoration: BoxDecoration(
                  color: p.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: p.color.withOpacity(0.6), blurRadius: 4)
                  ],
                ),
              ),
            ),
          ),

        // ── Favilla ───────────────────────────────────────────────────────
        Positioned(
          left: favillaVisX - 24,
          top: size.height * 0.84,
          child: _FavillaSprite(stunned: _runState == _RunState.stunned),
        ),

        // ── Flash overlay ─────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _flashAnim,
          builder: (ctx, _) => Opacity(
            opacity: _flashAnim.value,
            child: Container(color: Colors.red.withOpacity(0.65)),
          ),
        ),

        // ── HUD ───────────────────────────────────────────────────────────
        _Hud(
          secondsLeft: _secondsLeft,
          gap: _gap,
          totalSeconds: _durationSeconds,
        ),
      ],
    );
  }

  // Compute visual X of Favilla at normalized lane position (0=left, 1=right)
  double _laneVisualX(double normLane, Size size) {
    final bHalfW = size.width * _kBottomHalfWFrac;
    final trackLeft = size.width / 2 - bHalfW;
    return trackLeft + normLane * (bHalfW * 2);
  }

  // Track position from t (0=horizon, 1=bottom) and lane (0,1,2)
  static Offset _trackPos(
      double t, int lane, Size size, double horizonY, double bHalfW) {
    final screenY = horizonY + (size.height - horizonY) * t;
    final halfW = lerpDouble(_kHorizonHalfW, bHalfW, t)!;
    final laneW = halfW * 2 / 3;
    final x = (size.width / 2 - halfW) + laneW * (lane + 0.5);
    return Offset(x, screenY);
  }

  static double _trackSpriteSize(double t) =>
      lerpDouble(20.0, 68.0, t.clamp(0, 1))!;

  Widget _buildTutorial(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2A0D),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B5E20), Color(0xFF0D2A0D)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⚡  FERMA IL LADRO!  🏃',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Bangers',
                      fontSize: 30,
                      color: Colors.white,
                      letterSpacing: 3,
                    )),
                const SizedBox(height: 28),
                const _TutorialItem(
                    icon: '👜',
                    label: 'Ha la tua borsetta. Documenti. Chiavi. Tutto.'),
                const _TutorialItem(
                    icon: '👈', label: 'Swipe sinistra — cambia corsia'),
                const _TutorialItem(
                    icon: '👉', label: 'Swipe destra — cambia corsia'),
                const _TutorialItem(
                    icon: '🌿', label: 'Evita gli ostacoli nel boschetto'),
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: _startGame,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFFD700)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Text('CORRI!',
                        style: TextStyle(
                          fontFamily: 'Bangers',
                          fontSize: 28,
                          color: Colors.white,
                          letterSpacing: 4,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Particle ────────────────────────────────────────────────────────────────

class _Particle {
  double x, y;
  double vx, vy;
  double life;
  double size;
  Color color;
  _Particle(
      {required this.x,
      required this.y,
      required this.vx,
      required this.vy,
      required this.life,
      required this.size,
      required this.color});
}

// ─── Track CustomPainter ─────────────────────────────────────────────────────

class _TrackPainter extends CustomPainter {
  final double scrollOffset;
  final double flashIntensity;
  final double stunProgress;

  const _TrackPainter({
    required this.scrollOffset,
    required this.flashIntensity,
    required this.stunProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final horizonY = size.height * _kHorizonFrac;
    final bHalfW = size.width * _kBottomHalfWFrac;

    _drawSky(canvas, size, horizonY);
    _drawBoschetto(canvas, size, horizonY, bHalfW);
    _drawUnderbrush(canvas, size, horizonY, bHalfW);
    _drawTrack(canvas, size, horizonY, bHalfW);
    _drawLaneMarkings(canvas, size, horizonY, bHalfW);
    _drawEdgeShadow(canvas, size, horizonY, bHalfW);
  }

  void _drawSky(Canvas canvas, Size size, double horizonY) {
    final rect = Rect.fromLTWH(0, 0, size.width, horizonY + 20);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    final cloudPaint = Paint()..color = Colors.white.withOpacity(0.85);

    void drawCloud(double x, double y) {
      canvas.drawCircle(Offset(x - 12, y + 1), 10, cloudPaint);
      canvas.drawCircle(Offset(x, y - 3), 14, cloudPaint);
      canvas.drawCircle(Offset(x + 13, y + 2), 11, cloudPaint);
    }

    drawCloud(size.width * 0.20, horizonY * 0.35);
    drawCloud(size.width * 0.58, horizonY * 0.20);
    drawCloud(size.width * 0.82, horizonY * 0.50);
  }

  void _drawBoschetto(
      Canvas canvas, Size size, double horizonY, double bHalfW) {
    for (int i = 8; i >= 0; i--) {
      final t = 1.0 - i / 8.0;
      final rng = Random(42 + i);
      final trackEdgeL =
          size.width / 2 - lerpDouble(_kHorizonHalfW, bHalfW, t)!;
      final trackEdgeR =
          size.width / 2 + lerpDouble(_kHorizonHalfW, bHalfW, t)!;
      final y = lerpDouble(horizonY + 4, size.height * 0.98, t)!;
      final sideSpacing = 22 * (0.5 + t * 0.5);
      for (int j = 0; j < 2; j++) {
        final leftX = trackEdgeL -
            18 -
            (j * sideSpacing) -
            rng.nextDouble() * (6 + t * 10);
        final rightX = trackEdgeR +
            18 +
            (j * sideSpacing) +
            rng.nextDouble() * (6 + t * 10);
        _drawSingleTree(canvas, leftX, y, t);
        _drawSingleTree(canvas, rightX, y, t);
      }
    }
  }

  void _drawSingleTree(Canvas canvas, double x, double y, double depth) {
    final scale = lerpDouble(0.12, 1.0, depth)!;
    final trunkH = 50 * scale;
    final trunkW = 6 * scale;
    final baseR = 18 * scale;
    final trunkRect = Rect.fromCenter(
      center: Offset(x, y - trunkH * 0.5),
      width: trunkW,
      height: trunkH,
    );
    canvas.drawRect(
      trunkRect.shift(const Offset(2, 2)),
      Paint()..color = Colors.black.withOpacity(0.20),
    );
    canvas.drawRect(trunkRect, Paint()..color = const Color(0xFF5D4037));

    canvas.drawCircle(
      Offset(x, y - trunkH - baseR * 0.10),
      baseR * 1.15,
      Paint()..color = const Color(0xFF1B5E20),
    );
    canvas.drawCircle(
      Offset(x - 8 * scale, y - trunkH + 5 * scale),
      baseR * 0.9,
      Paint()..color = const Color(0xFF2E7D32),
    );
    canvas.drawCircle(
      Offset(x + 9 * scale, y - trunkH + 3 * scale),
      baseR * 0.85,
      Paint()..color = const Color(0xFF388E3C),
    );
    canvas.drawCircle(
      Offset(x, y - trunkH - 8 * scale),
      baseR * 0.7,
      Paint()..color = const Color(0xFF558B2F),
    );
  }

  void _drawUnderbrush(
      Canvas canvas, Size size, double horizonY, double bHalfW) {
    final rng = Random(91);
    final bushLight = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.95);
    final bushDark = Paint()..color = const Color(0xFF2E7D32).withOpacity(0.95);
    final tuft = Paint()..color = const Color(0xFF2E7D32).withOpacity(0.72);

    for (int side = 0; side < 2; side++) {
      for (int i = 0; i < 8; i++) {
        final t = (0.08 + i * 0.11 + rng.nextDouble() * 0.05).clamp(0.08, 0.95);
        final halfW = lerpDouble(_kHorizonHalfW, bHalfW, t)!;
        final edgeX =
            side == 0 ? size.width / 2 - halfW : size.width / 2 + halfW;
        final y = lerpDouble(horizonY + 10, size.height, t)!;
        final spread = lerpDouble(8, 22, t)!;
        final baseX = side == 0 ? edgeX - spread * 0.55 : edgeX + spread * 0.55;

        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(baseX, y),
              width: spread * 1.25,
              height: spread * 0.7),
          bushDark,
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(
                  baseX + (side == 0 ? -spread * 0.12 : spread * 0.12),
                  y - spread * 0.10),
              width: spread,
              height: spread * 0.62),
          bushLight,
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(
                  baseX + (side == 0 ? spread * 0.18 : -spread * 0.18),
                  y - spread * 0.18),
              width: spread * 0.82,
              height: spread * 0.55),
          bushDark,
        );

        for (int tuftI = 0; tuftI < 2; tuftI++) {
          final tx = baseX + (tuftI == 0 ? -spread * 0.18 : spread * 0.18);
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset(tx, y - spread * 0.45),
                width: spread * 0.10,
                height: spread * 0.45),
            tuft,
          );
          canvas.drawOval(
            Rect.fromCenter(
                center: Offset(tx + spread * 0.08, y - spread * 0.48),
                width: spread * 0.08,
                height: spread * 0.38),
            tuft,
          );
        }
      }
    }
  }

  void _drawTrack(Canvas canvas, Size size, double horizonY, double bHalfW) {
    final cx = size.width / 2;

    final path = Path()
      ..moveTo(cx - _kHorizonHalfW, horizonY + 8)
      ..lineTo(cx + _kHorizonHalfW, horizonY + 8)
      ..lineTo(cx + bHalfW, size.height + 10)
      ..lineTo(cx - bHalfW, size.height + 10)
      ..close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF8B6342), Color(0xFF6D4C41)],
      ).createShader(
          Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY));
    canvas.drawPath(path, paint);

    final leafColors = [
      const Color(0xFFD4A017),
      const Color(0xFFBF360C),
      const Color(0xFF8BC34A),
      const Color(0xFF795548),
    ];
    final rngLeaves = Random(17);
    for (int i = 0; i < 25; i++) {
      final t = 0.08 + rngLeaves.nextDouble() * 0.88;
      final y = lerpDouble(horizonY + 12, size.height - 8, t)!;
      final halfW = lerpDouble(_kHorizonHalfW, bHalfW, t)!;
      final x = cx - halfW * 0.88 + rngLeaves.nextDouble() * (halfW * 1.76);
      final width = 6.0 + rngLeaves.nextDouble() * 6.0;
      final color =
          leafColors[rngLeaves.nextInt(leafColors.length)].withOpacity(0.6);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((rngLeaves.nextDouble() - 0.5) * 1.2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: width, height: 3),
        Paint()..color = color,
      );
      canvas.restore();
    }

    final rootPaint = Paint()
      ..color = const Color(0xFF4E342E).withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final rngRoots = Random(31);
    for (int i = 0; i < 5; i++) {
      final t = 0.18 + rngRoots.nextDouble() * 0.70;
      final y = lerpDouble(horizonY + 14, size.height - 26, t)!;
      final halfW = lerpDouble(_kHorizonHalfW, bHalfW, t)!;
      final startX = cx - halfW * (0.72 + rngRoots.nextDouble() * 0.10);
      final endX = cx + halfW * (0.72 + rngRoots.nextDouble() * 0.10);
      final controlY = y + (rngRoots.nextDouble() - 0.5) * 18;
      final controlX = cx + (rngRoots.nextDouble() - 0.5) * halfW * 0.35;
      final rootPath = Path()
        ..moveTo(startX, y)
        ..quadraticBezierTo(
            controlX, controlY, endX, y + (rngRoots.nextDouble() - 0.5) * 10);
      canvas.drawPath(rootPath, rootPaint);
    }
  }

  void _drawLaneMarkings(
      Canvas canvas, Size size, double horizonY, double bHalfW) {
    final cx = size.width / 2;
    // Sentiero di terra: solchi scuri animati al posto delle strisce stradali
    final rutPaint = Paint()
      ..color = const Color(0xFF2F1B12).withOpacity(0.62)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (final f in [1 / 3.0, 2 / 3.0]) {
      final tx = (cx - _kHorizonHalfW) + (_kHorizonHalfW * 2) * f;
      final bx = (cx - bHalfW) + (bHalfW * 2) * f;
      final ty = horizonY + 8;
      final by = size.height + 10;

      const dashCount = 10;
      for (int i = 0; i < dashCount; i++) {
        final t0 = ((i + scrollOffset) / dashCount) % 1.0;
        final t1 = ((i + scrollOffset + 0.040) / dashCount) % 1.0;
        if (t0 >= t1) continue;

        final x0 = lerpDouble(tx, bx, t0)!;
        final y0 = lerpDouble(ty, by, t0)!;
        final x1 = lerpDouble(tx, bx, t1)!;
        final y1 = lerpDouble(ty, by, t1)!;
        canvas.drawLine(Offset(x0, y0), Offset(x1, y1), rutPaint);
      }
    }
  }

  void _drawEdgeShadow(
      Canvas canvas, Size size, double horizonY, double bHalfW) {
    final cx = size.width / 2;
    // Left edge vignette
    canvas.drawPath(
      Path()
        ..moveTo(0, horizonY + 8)
        ..lineTo(cx - _kHorizonHalfW, horizonY + 8)
        ..lineTo(cx - bHalfW, size.height + 10)
        ..lineTo(0, size.height + 10)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [Colors.transparent, Colors.black.withOpacity(0.22)],
        ).createShader(Rect.fromLTWH(0, 0, cx, size.height)),
    );
    // Right edge vignette
    canvas.drawPath(
      Path()
        ..moveTo(size.width, horizonY + 8)
        ..lineTo(cx + _kHorizonHalfW, horizonY + 8)
        ..lineTo(cx + bHalfW, size.height + 10)
        ..lineTo(size.width, size.height + 10)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.transparent, Colors.black.withOpacity(0.22)],
        ).createShader(Rect.fromLTWH(cx, 0, cx, size.height)),
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.scrollOffset != scrollOffset ||
      old.flashIntensity != flashIntensity ||
      old.stunProgress != stunProgress;
}

// ─── Sprite widgets ───────────────────────────────────────────────────────────

class _ObstacleSprite extends StatelessWidget {
  final String emoji;
  final double size;
  final double glowFactor;
  final int lane;
  final int currentLane;

  const _ObstacleSprite({
    required this.emoji,
    required this.size,
    required this.glowFactor,
    required this.lane,
    required this.currentLane,
  });

  @override
  Widget build(BuildContext context) {
    final inLane = lane == currentLane;
    final danger = inLane && glowFactor > 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (danger)
          Container(
            width: size * 1.6,
            height: size * 1.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.18 * glowFactor),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.35 * glowFactor),
                  blurRadius: 18,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        // Shadow on sand
        Positioned(
          bottom: 0,
          child: Container(
            width: size * 0.9,
            height: size * 0.12,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(size),
            ),
          ),
        ),
        Text(emoji, style: TextStyle(fontSize: size * 0.78)),
      ],
    );
  }
}

class _FavillaSprite extends StatelessWidget {
  final bool stunned;
  const _FavillaSprite({required this.stunned});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (!stunned)
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD54F).withOpacity(0.42),
                  blurRadius: 18,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
        Text(stunned ? '😵' : '⚡', style: const TextStyle(fontSize: 38)),
      ],
    );
  }
}

class _LexSprite extends StatelessWidget {
  final double size;
  final double gap;
  const _LexSprite({required this.size, required this.gap});

  @override
  Widget build(BuildContext context) {
    final thiefEmoji = gap < 0.15 ? '😱' : '🏃';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size * 0.95,
          height: size * 0.95,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Text(thiefEmoji, style: TextStyle(fontSize: size)),
              Positioned(
                right: -2,
                bottom: 0,
                child: Text('👜', style: TextStyle(fontSize: size * 0.45)),
              ),
            ],
          ),
        ),
        if (gap < 0.25) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'PRESO!',
              style: TextStyle(
                fontSize: (size * 0.22).clamp(8, 12),
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── HUD ─────────────────────────────────────────────────────────────────────

class _Hud extends StatelessWidget {
  final int secondsLeft;
  final double gap;
  final int totalSeconds;

  const _Hud(
      {required this.secondsLeft,
      required this.gap,
      required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final timeProgress = secondsLeft / totalSeconds;
    final lexClose = gap < 0.35;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lexClose ? 'LA BORSA! CI SEI!' : 'RINCORRI IL LADRO!',
                style: TextStyle(
                  fontFamily: 'Bangers',
                  fontSize: 26,
                  color: lexClose ? const Color(0xFFFFD700) : Colors.white,
                  letterSpacing: 3,
                  shadows: const [
                    Shadow(
                        color: Colors.black87,
                        blurRadius: 6,
                        offset: Offset(1, 1))
                  ],
                ),
              ),
              // Timer pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: secondsLeft <= 5
                      ? Colors.red.withOpacity(0.85)
                      : Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${secondsLeft}s',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1),
                ),
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
                    ? const Color(0xFF4CAF50)
                    : timeProgress > 0.25
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Gap / distance indicator
          Row(
            children: [
              const Text('⚡ ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1.0 - gap,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      gap < 0.30
                          ? const Color(0xFF4CAF50)
                          : gap < 0.55
                              ? const Color(0xFFFFD700)
                              : Colors.orange,
                    ),
                  ),
                ),
              ),
              const Text(' 👜', style: TextStyle(fontSize: 16)),
            ],
          ),

          const SizedBox(height: 4),
          Center(
            child: Text(
              _gapLabel(gap),
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.7),
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _gapLabel(double g) {
    if (g < 0.15) return 'PRENDILA! ADESSO!';
    if (g < 0.30) return 'La borsa è quasi tua...';
    if (g < 0.50) return 'Continua! Non mollare!';
    if (g < 0.65) return 'Corri, Favilla! Corri!';
    return 'Il ladro sta scappando!';
  }
}

// ─── Tutorial helpers ────────────────────────────────────────────────────────

class _TutorialItem extends StatelessWidget {
  final String icon;
  final String label;
  const _TutorialItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
