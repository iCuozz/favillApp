// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/comic_data.dart';
import '../services/audio_service.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kTotalElements = 4;
const _kGameDuration = Duration(seconds: 20);
const _kSafeWindowMin = Duration(milliseconds: 1200);
const _kSafeWindowMax = Duration(milliseconds: 3200);
const _kDangerWindowMin = Duration(milliseconds: 800);
const _kDangerWindowMax = Duration(milliseconds: 2200);
const _kFixDuration = Duration(milliseconds: 600);

const _kChildColors = [
  Color(0xFFFF6B6B), // coral — fire hair
  Color(0xFFFFD93D), // yellow — sparkles
  Color(0xFF4ECDC4), // teal — Mallow's shirt
  Color(0xFFFF8C42), // orange — Lex pointing
];

const Map<int, String> _kElementLabels = {
  0: 'capelli di fuoco',
  1: 'scintille gialle',
  2: 'papà che guarda',
  3: 'dito puntato',
};

enum _GamePhase { tutorial, playing, success, caught }

// ── Main widget ───────────────────────────────────────────────────────────────

/// Mini-game DISEGNA — Stealth Drawing Sabotage.
///
/// Lex sta disegnando una scena compromettente: mamma coi capelli a fuoco,
/// papà che guarda, lui che indica. Il giocatore (Favilla) deve modificare
/// gli elementi incriminanti quando Mallow distoglie lo sguardo.
///
/// Meccanica: Mallow alterna momenti in cui guarda altrove (safe) e momenti
/// in cui guarda verso Lex (danger). Toccare un elemento during safe lo "fixa"
/// dopo una breve animazione. Toccare during danger = caught (penalità).
///
/// Tiers:
///   score 4 (all fixed, 0 caught) → branch_umorismo (perfetto)
///   score 2-3 fixed              → branch_facciata (abbastanza)
///   score 0-1 fixed or caught≥2  → branch_confessa (scoperto)
class MinigameDisegnaScreen extends StatefulWidget {
  final MinigameConfig config;
  final void Function(
      Map<String, int> statEffects, String tierLabel, MinigameTier tier)
      onComplete;

  const MinigameDisegnaScreen(
      {super.key, required this.config, required this.onComplete});

  @override
  State<MinigameDisegnaScreen> createState() => _MinigameDisegnaScreenState();
}

class _MinigameDisegnaScreenState extends State<MinigameDisegnaScreen>
    with SingleTickerProviderStateMixin {
  final _rng = Random();

  // ── State ─────────────────────────────────────────────────────────────────

  _GamePhase _phase = _GamePhase.tutorial;
  int _tutorialStep = 0;

  late final List<_DrawingElement> _elements;
  int _fixedCount = 0;
  int _caughtCount = 0;
  bool _isSafe = true;
  bool _isFixing = false;
  int _fixingIndex = -1;

  Timer? _attentionTimer;
  Timer? _fixTimer;
  Timer? _gameTimer;
  int _secondsLeft = _kGameDuration.inSeconds;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Create the 4 drawing elements at random positions
    _elements = List.generate(_kTotalElements, (i) {
      return _DrawingElement(
        id: i,
        label: _kElementLabels[i]!,
        color: _kChildColors[i],
        // Position them in a child-like composition
        left: 0.10 + _rng.nextDouble() * 0.15 + (i * 0.20),
        top: 0.15 + _rng.nextDouble() * 0.50,
        size: 50.0 + _rng.nextDouble() * 20.0,
        rotation: -0.15 + _rng.nextDouble() * 0.30,
      );
    });

    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _attentionTimer?.cancel();
    _fixTimer?.cancel();
    _gameTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Game logic ─────────────────────────────────────────────────────────────

  void _startGame() {
    setState(() {
      _phase = _GamePhase.playing;
      _fixedCount = 0;
      _caughtCount = 0;
      _secondsLeft = _kGameDuration.inSeconds;
    });
    _scheduleAttention();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
      });
      if (_secondsLeft <= 0) {
        _endGame();
      }
    });
  }

  void _scheduleAttention() {
    _attentionTimer?.cancel();
    final nextSafe = _isSafe
        ? _kSafeWindowMin.inMilliseconds +
            _rng.nextInt(_kSafeWindowMax.inMilliseconds -
                _kSafeWindowMin.inMilliseconds)
        : _kDangerWindowMin.inMilliseconds +
            _rng.nextInt(_kDangerWindowMax.inMilliseconds -
                _kDangerWindowMin.inMilliseconds);

    _attentionTimer = Timer(Duration(milliseconds: nextSafe), () {
      if (!mounted || _phase != _GamePhase.playing) return;
      setState(() {
        _isSafe = !_isSafe;
      });
      // If we're fixing and danger starts, that's a catch
      if (!_isSafe && _isFixing) {
        _onCaught();
      }
      _scheduleAttention();
    });
  }

  void _onTapElement(int index) {
    if (_phase != _GamePhase.playing) return;
    if (_elements[index].isFixed) return;
    if (_isFixing) return;

    if (!_isSafe) {
      _onCaught();
      return;
    }

    // Start fixing
    setState(() {
      _isFixing = true;
      _fixingIndex = index;
    });

    _fixTimer = Timer(_kFixDuration, () {
      if (!mounted) return;
      setState(() {
        _elements[index].isFixed = true;
        _fixedCount++;
        _isFixing = false;
        _fixingIndex = -1;
      });

      AudioService.instance.playSfx(SfxEvent.tapPanel);

      if (_fixedCount >= _kTotalElements) {
        _endGame();
      }
    });
  }

  void _onCaught() {
    if (_phase != _GamePhase.playing) return;
    setState(() {
      _caughtCount++;
      _isFixing = false;
      _fixingIndex = -1;
      _phase = _GamePhase.caught;
    });
    _fixTimer?.cancel();
    AudioService.instance.playSfx(SfxEvent.minigameFail);

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _phase = _GamePhase.playing;
      });
    });
  }

  void _endGame() {
    _attentionTimer?.cancel();
    _fixTimer?.cancel();
    _gameTimer?.cancel();
    if (!mounted) return;

    final tiers = widget.config.tiers;
    if (tiers.isEmpty) return;

    // Score = fixedCount, but caught≥2 forces lowest tier
    final effectiveScore = _caughtCount >= 2 ? 0 : _fixedCount;

    // Find matching tier (highest min that we satisfy)
    MinigameTier? matched;
    for (final t in tiers) {
      if (effectiveScore >= t.minProducts &&
          (matched == null || t.minProducts > matched.minProducts)) {
        matched = t;
      }
    }
    matched ??= tiers.last;

    final isSuccess = effectiveScore >= 3;
    AudioService.instance.playSfx(
        isSuccess ? SfxEvent.minigameSuccess : SfxEvent.minigameFail);

    widget.onComplete(
      Map<String, int>.from(matched.statEffects),
      matched.label,
      matched,
    );
  }

  // ── Tutorial ───────────────────────────────────────────────────────────────

  static const _tutorialSteps = [
    'Lex prende i pastelli.\nSta disegnando qualcosa.\nQualcosa che Mallow non deve vedere.',
    'Quando Mallow guarda altrove (verde),\ntocca gli elementi per modificarli.',
    'Quando Mallow guarda verso Lex (rosso),\nstai ferma! Non toccare niente.',
    'Modifica tutti e 4 gli elementi\nprima che Mallow noti il disegno.',
  ];

  void _nextTutorial() {
    if (_tutorialStep < _tutorialSteps.length - 1) {
      setState(() => _tutorialStep++);
    } else {
      _startGame();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6D3), // warm paper color
      body: SafeArea(
        child: _phase == _GamePhase.tutorial
            ? _buildTutorial()
            : _buildGame(),
      ),
    );
  }

  Widget _buildTutorial() {
    return GestureDetector(
      onTap: _nextTutorial,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFF5E6D3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Demo: small drawing preview
            Container(
              width: 200,
              height: 160,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4A574), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _DrawingPainter(
                  elements: _elements,
                  isSafe: true,
                  isFixing: false,
                  fixingIndex: -1,
                ),
              ),
            ),
            // Tutorial text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _tutorialSteps[_tutorialStep],
                key: ValueKey(_tutorialStep),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ComicNeue',
                  fontSize: 18,
                  height: 1.5,
                  color: Color(0xFF3D2B1F),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_tutorialSteps.length, (i) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _tutorialStep
                        ? const Color(0xFFE67E22)
                        : const Color(0xFFD4A574).withOpacity(0.4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Text(
              'tocca per continuare',
              style: TextStyle(
                fontFamily: 'ComicNeue',
                fontSize: 13,
                color: const Color(0xFF8B7355).withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        // ── Mallow attention indicator ──────────────────────────────────────
        _buildMallowIndicator(),
        // ── Drawing area ────────────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (_phase != _GamePhase.playing || _isFixing) return;
              // Check if tapped near any element
              final box = context.findRenderObject() as RenderBox;
              final local = box.globalToLocal(details.globalPosition);
              // Convert to relative coords
              final size = box.size;
              final rx = local.dx / size.width;
              final ry = local.dy / size.height;

              // Find closest unfixed element
              int closest = -1;
              double closestDist = 0.15; // tap radius in relative coords
              for (int i = 0; i < _elements.length; i++) {
                if (_elements[i].isFixed) continue;
                final dx = rx - (_elements[i].left + 0.04);
                final dy = ry - (_elements[i].top + 0.04);
                final dist = sqrt(dx * dx + dy * dy);
                if (dist < closestDist) {
                  closest = i;
                  closestDist = dist;
                }
              }
              if (closest >= 0) {
                _onTapElement(closest);
              }
            },
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isSafe
                      ? const Color(0xFF27AE60).withOpacity(0.3)
                      : const Color(0xFFE74C3C).withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The drawing itself
                    CustomPaint(
                      painter: _DrawingPainter(
                        elements: _elements,
                        isSafe: _isSafe,
                        isFixing: _isFixing,
                        fixingIndex: _fixingIndex,
                      ),
                    ),
                    // Fixed count indicator
                    Positioned(
                      top: 8,
                      right: 12,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_kTotalElements, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _fixedCount
                                  ? const Color(0xFF27AE60)
                                  : const Color(0xFFBDC3C7),
                              border: Border.all(
                                color: i < _fixedCount
                                    ? const Color(0xFF219A52)
                                    : const Color(0xFF95A5A6),
                                width: 1.5,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // Caught flash
                    if (_phase == _GamePhase.caught)
                      Container(
                        color: const Color(0xFFE74C3C).withOpacity(0.15),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // ── Timer bar ───────────────────────────────────────────────────────
        _buildTimerBar(),
      ],
    );
  }

  Widget _buildMallowIndicator() {
    final Color indicatorColor =
        _isSafe ? const Color(0xFF27AE60) : const Color(0xFFE74C3C);
    final String label =
        _isSafe ? 'Mallow guarda il piatto' : 'Mallow guarda verso Lex';
    final IconData icon =
        _isSafe ? Icons.visibility_off_outlined : Icons.visibility_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.08),
        border: Border(
          bottom: BorderSide(color: indicatorColor.withOpacity(0.2), width: 1),
        ),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              key: ValueKey(_isSafe),
              color: indicatorColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              label,
              key: ValueKey(_isSafe),
              style: TextStyle(
                fontFamily: 'ComicNeue',
                fontSize: 16,
                color: indicatorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          // Caught counter
          if (_caughtCount > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: const Color(0xFFE74C3C).withOpacity(0.7), size: 18),
                const SizedBox(width: 4),
                Text(
                  '$_caughtCount',
                  style: TextStyle(
                    fontFamily: 'ComicNeue',
                    fontSize: 15,
                    color: const Color(0xFFE74C3C).withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    final progress = _secondsLeft / _kGameDuration.inSeconds;
    final Color barColor = progress > 0.5
        ? const Color(0xFF27AE60)
        : progress > 0.25
            ? const Color(0xFFF39C12)
            : const Color(0xFFE74C3C);

    return Container(
      width: double.infinity,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8D5C4),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: AnimatedContainer(
          duration: const Duration(seconds: 1),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────────────

class _DrawingElement {
  final int id;
  final String label;
  final Color color;
  final double left;
  final double top;
  final double size;
  final double rotation;
  bool isFixed;

  _DrawingElement({
    required this.id,
    required this.label,
    required this.color,
    required this.left,
    required this.top,
    required this.size,
    required this.rotation,
    this.isFixed = false,
  });
}

// ── Custom painter ───────────────────────────────────────────────────────────

class _DrawingPainter extends CustomPainter {
  final List<_DrawingElement> elements;
  final bool isSafe;
  final bool isFixing;
  final int fixingIndex;

  _DrawingPainter({
    required this.elements,
    required this.isSafe,
    required this.isFixing,
    required this.fixingIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background: subtle ruled lines like notebook paper
    final linePaint = Paint()
      ..color = const Color(0xFFE8F0FE).withOpacity(0.5)
      ..strokeWidth = 1;
    for (double y = 20; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Draw each element
    for (final el in elements) {
      final cx = el.left * size.width;
      final cy = el.top * size.height;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(el.rotation);

      if (el.isFixed) {
        _drawFixedElement(canvas, el, size);
      } else if (isFixing && el.id == fixingIndex) {
        _drawFixingElement(canvas, el, size);
      } else {
        _drawIncriminatingElement(canvas, el, size);
      }

      canvas.restore();
    }

    // Title: "IL DISEGNO DI LEX" in child handwriting style at the bottom
    final titlePaint = Paint()
      ..color = const Color(0xFF2C3E50).withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    // Just a simple underline suggesting a title
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.92),
      Offset(size.width * 0.75, size.height * 0.92),
      titlePaint,
    );
  }

  void _drawIncriminatingElement(
      Canvas canvas, _DrawingElement el, Size size) {
    final s = el.size;

    // Glowing pulse when safe
    final fillPaint = Paint()
      ..color = el.color.withOpacity(isSafe ? 0.35 : 0.18)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = el.color.withOpacity(isSafe ? 0.7 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSafe ? 2.5 : 1.5
      ..strokeCap = StrokeCap.round;

    // Draw a child-like shape: circle with squiggly outline
    final path = Path();
    final n = 12;
    for (int i = 0; i < n; i++) {
      final angle = (i / n) * 2 * pi;
      final r = s * (0.5 + 0.08 * sin(angle * 3 + el.id));
      final x = r * cos(angle);
      final y = r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Draw the label (what element it is) — child handwriting simulation
    _drawChildLabel(canvas, el.label, 0, s * 0.75, el.color.withOpacity(0.6));
  }

  void _drawFixingElement(
      Canvas canvas, _DrawingElement el, Size size) {
    final s = el.size;
    final progress = 0.5; // Mid-fix

    // Transition: color fading
    final fixPaint = Paint()
      ..color = const Color(0xFF27AE60).withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final path = Path();
    final n = 12;
    for (int i = 0; i < n; i++) {
      final angle = (i / n) * 2 * pi;
      final r = s * (0.5 + 0.06 * sin(angle * 3 + el.id));
      final x = r * cos(angle);
      final y = r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, fixPaint);

    // Scribble overlay (simulating Favilla "fixing" the drawing)
    final scribblePaint = Paint()
      ..color = const Color(0xFF27AE60).withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int j = 0; j < 5; j++) {
      final path2 = Path();
      final startX = -s * 0.4 + (j * s * 0.2);
      path2.moveTo(startX, -s * 0.3);
      path2.quadraticBezierTo(
          startX + s * 0.15, -s * 0.1, startX - s * 0.05, s * 0.2);
      canvas.drawPath(path2, scribblePaint);
    }
  }

  void _drawFixedElement(
      Canvas canvas, _DrawingElement el, Size size) {
    final s = el.size;

    // Neutral, "fixed" version — a simple shape
    final fillPaint = Paint()
      ..color = const Color(0xFF95A5A6).withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF7F8C8D).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Simple circle — "normalized"
    canvas.drawCircle(Offset.zero, s * 0.4, fillPaint);
    canvas.drawCircle(Offset.zero, s * 0.4, strokePaint);

    // Checkmark
    final checkPaint = Paint()
      ..color = const Color(0xFF27AE60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final checkPath = Path();
    checkPath.moveTo(-s * 0.2, 0);
    checkPath.lineTo(-s * 0.05, s * 0.15);
    checkPath.lineTo(s * 0.25, -s * 0.15);
    canvas.drawPath(checkPath, checkPaint);
  }

  void _drawChildLabel(
      Canvas canvas, String text, double dx, double dy, Color color) {
    // Simple dot indicators instead of full text (child drawing aesthetic)
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dx, dy), 3, dotPaint);
    canvas.drawCircle(Offset(dx + 8, dy - 2), 2.5, dotPaint);
    canvas.drawCircle(Offset(dx + 14, dy + 1), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return oldDelegate.isSafe != isSafe ||
        oldDelegate.isFixing != isFixing ||
        oldDelegate.fixingIndex != fixingIndex ||
        oldDelegate.elements != elements;
  }
}
