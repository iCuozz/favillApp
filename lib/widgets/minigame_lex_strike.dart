import 'dart:math';
import 'package:flutter/material.dart';
import '../models/comic_data.dart';

/// Schermata mini-game "Lex Strike": slingshot con un singolo lancio.
/// L'utente trascina l'orsetto e rilascia — la traiettoria parabolica colpisce
/// i prodotti sullo scaffale, innescando una reazione a catena BFS.
///
/// Tier (configurabile da JSON):
///   ≥ 8 prodotti → STRIKE
///   3–7           → Parziale
///   0–2           → Mancato
class MinigameLexStrikeScreen extends StatefulWidget {
  final MinigameConfig config;
  final void Function(Map<String, int> statEffects, String tierLabel) onComplete;

  const MinigameLexStrikeScreen({
    super.key,
    required this.config,
    required this.onComplete,
  });

  @override
  State<MinigameLexStrikeScreen> createState() =>
      _MinigameLexStrikeScreenState();
}

enum _Phase { tutorial, aiming, launched, chainReaction, result }

class _MinigameLexStrikeScreenState extends State<MinigameLexStrikeScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.tutorial;

  // ─── Drag ────────────────────────────────────────────────────────────────
  Offset? _dragOffset;
  static const double _kMaxDrag = 85.0;

  // ─── Products ─────────────────────────────────────────────────────────────
  late List<bool> _fallen;
  late List<AnimationController> _fallCtrl;
  late List<Animation<double>> _fallAnim;

  // ─── Projectile ───────────────────────────────────────────────────────────
  late AnimationController _projCtrl;
  Offset _projPos = Offset.zero;
  Offset _projVelocity = Offset.zero;

  // ─── Layout (computed once) ───────────────────────────────────────────────
  bool _layoutReady = false;
  late Size _screenSize;
  late Offset _slingshotPos;
  late List<Offset> _productCenters;
  static const double _kProductSize = 46.0;
  static const double _kProductGap = 10.0;

  // ─── Result ───────────────────────────────────────────────────────────────
  int _fallenCount = 0;

  // ─── Cosmetics ────────────────────────────────────────────────────────────
  static const List<Color> _kProductColors = [
    Color(0xFFE74C3C),
    Color(0xFF3498DB),
    Color(0xFFF39C12),
    Color(0xFF2ECC71),
    Color(0xFF9B59B6),
    Color(0xFFE67E22),
    Color(0xFF1ABC9C),
    Color(0xFFE74C3C),
    Color(0xFF3498DB),
    Color(0xFFF39C12),
    Color(0xFF2ECC71),
    Color(0xFF9B59B6),
  ];
  static const _kProductEmojis = ['🍅', '🥫', '🍝', '🥦', '🫙', '🥕'];

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final n = widget.config.productsTotal.clamp(1, 12);
    _fallen = List.filled(n, false);
    _fallCtrl = List.generate(
      n,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      ),
    );
    _fallAnim = _fallCtrl
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeIn))
        .toList();

    _projCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 580),
    )
      ..addListener(_onProjTick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _resolveHits();
      });
  }

  void _initLayout(Size size) {
    if (_layoutReady) return;
    _layoutReady = true;
    _screenSize = size;
    _slingshotPos = Offset(size.width / 2, size.height * 0.73);

    const cols = 6;
    final n = widget.config.productsTotal.clamp(1, 12);
    const stride = _kProductSize + _kProductGap;
    const totalW = cols * stride - _kProductGap;
    final startX = (size.width - totalW) / 2 + _kProductSize / 2;
    final row1Y = size.height * 0.27;
    final row2Y = row1Y + _kProductSize + 14;

    _productCenters = [];
    for (int i = 0; i < n; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      _productCenters.add(Offset(
        startX + col * stride,
        row == 0 ? row1Y : row2Y,
      ));
    }
    _projPos = _slingshotPos;
  }

  // ─── Physics ─────────────────────────────────────────────────────────────
  void _onProjTick() {
    final t = _projCtrl.value;
    const dt = 0.58;
    final g = _screenSize.height * 1.55;
    setState(() {
      _projPos = Offset(
        _slingshotPos.dx + _projVelocity.dx * t * dt,
        _slingshotPos.dy +
            _projVelocity.dy * t * dt +
            0.5 * g * (t * dt) * (t * dt),
      );
    });
  }

  void _resolveHits() {
    final impact = _projPos;
    const directR = 68.0;
    const chainR = 74.0;
    const chainP = 0.62;
    final rng = Random();

    final fallen = <int>{};
    for (int i = 0; i < _productCenters.length; i++) {
      if ((_productCenters[i] - impact).distance < directR) fallen.add(i);
    }

    // BFS chain reaction
    final queue = fallen.toList();
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (int i = 0; i < _productCenters.length; i++) {
        if (!fallen.contains(i)) {
          final d = (_productCenters[cur] - _productCenters[i]).distance;
          if (d < chainR && rng.nextDouble() < chainP) {
            fallen.add(i);
            queue.add(i);
          }
        }
      }
    }

    _fallenCount = fallen.length;
    setState(() => _phase = _Phase.chainReaction);

    final sorted = fallen.toList()..sort();
    for (int k = 0; k < sorted.length; k++) {
      final idx = sorted[k];
      Future.delayed(Duration(milliseconds: k * 70), () {
        if (!mounted) return;
        setState(() => _fallen[idx] = true);
        _fallCtrl[idx].forward();
      });
    }

    Future.delayed(Duration(milliseconds: sorted.length * 70 + 700), () {
      if (!mounted) return;
      setState(() => _phase = _Phase.result);
    });
  }

  // ─── Gesture handlers ────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails _) {
    if (_phase == _Phase.tutorial) setState(() => _phase = _Phase.aiming);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_phase != _Phase.aiming) return;
    final raw = d.localPosition - _slingshotPos;
    setState(() {
      _dragOffset = raw.distance > _kMaxDrag
          ? raw / raw.distance * _kMaxDrag
          : raw;
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_phase != _Phase.aiming || _dragOffset == null) return;
    final drag = _dragOffset!;
    if (drag.distance < 12) {
      setState(() => _dragOffset = null);
      return;
    }
    final dir = drag / drag.distance;
    final speed = (drag.distance / _kMaxDrag) * _screenSize.height * 2.2;
    _projVelocity = Offset(-dir.dx * speed, -dir.dy * speed);
    _projPos = _slingshotPos;
    setState(() {
      _phase = _Phase.launched;
      _dragOffset = null;
    });
    _projCtrl.forward();
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    for (final c in _fallCtrl) { c.dispose(); }
    _projCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          _initLayout(Size(constraints.maxWidth, constraints.maxHeight));
          return GestureDetector(
            onPanStart: _phase == _Phase.tutorial || _phase == _Phase.aiming
                ? _onPanStart
                : null,
            onPanUpdate:
                _phase == _Phase.aiming ? _onPanUpdate : null,
            onPanEnd: _phase == _Phase.aiming ? _onPanEnd : null,
            behavior: HitTestBehavior.translucent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildBackground(),
                _buildShelves(),
                _buildProducts(),
                _buildLexCharacter(),
                _buildSlingshotAndTrajectory(),
                if (_phase == _Phase.launched ||
                    _phase == _Phase.chainReaction)
                  _buildProjectile(),
                _buildHud(),
                if (_phase == _Phase.tutorial) _buildTutorialHint(),
                if (_phase == _Phase.result) _buildResultOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: const _SupermarketBgPainter(),
    );
  }

  Widget _buildLexCharacter() {
    if (!_layoutReady) return const SizedBox.shrink();
    return CustomPaint(
      size: _screenSize,
      painter: _LexPainter(slingshotPos: _slingshotPos),
    );
  }

  Widget _buildShelves() {
    final row1Bottom = _screenSize.height * 0.27 + _kProductSize + 2;
    final row2Bottom = _screenSize.height * 0.27 + _kProductSize + 14 + _kProductSize + 2;
    return CustomPaint(
      size: _screenSize,
      painter: _ShelfPainter(
        row1Y: row1Bottom,
        row2Y: row2Bottom,
        width: _screenSize.width,
      ),
    );
  }

  Widget _buildProducts() {
    return Stack(
      children: List.generate(_productCenters.length, (i) {
        return AnimatedBuilder(
          animation: _fallAnim[i],
          builder: (_, child) {
            final p = _fallAnim[i].value;
            return Positioned(
              left: _productCenters[i].dx - _kProductSize / 2,
              top: _productCenters[i].dy - _kProductSize / 2 + p * 220,
              child: Opacity(
                opacity: (1 - p * 0.85).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: p * (i.isEven ? 0.9 : -0.9),
                  child: child,
                ),
              ),
            );
          },
          child: Container(
            width: _kProductSize,
            height: _kProductSize,
            decoration: BoxDecoration(
              color: _kProductColors[i % _kProductColors.length],
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _kProductEmojis[i % _kProductEmojis.length],
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSlingshotAndTrajectory() {
    return CustomPaint(
      size: _screenSize,
      painter: _SlingshotPainter(
        center: _slingshotPos,
        dragOffset: _phase == _Phase.aiming ? _dragOffset : null,
        maxDrag: _kMaxDrag,
        screenSize: _screenSize,
        showBand: _phase == _Phase.aiming || _phase == _Phase.tutorial,
      ),
    );
  }

  Widget _buildProjectile() {
    return Positioned(
      left: _projPos.dx - 16,
      top: _projPos.dy - 16,
      child: const Text('🐻', style: TextStyle(fontSize: 32)),
    );
  }

  Widget _buildHud() {
    final label = switch (_phase) {
      _Phase.tutorial => '👶 Trascina l\'orsetto e rilascia!',
      _Phase.aiming => '🎯 Mira — più tiri indietro, più forza',
      _Phase.launched => '🐻 Vola!',
      _Phase.chainReaction => '💥 Reazione a catena!',
      _Phase.result => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 52,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(160),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialHint() {
    return Positioned(
      bottom: 90,
      left: 0,
      right: 0,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1.0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          child: const Icon(Icons.swipe_up_rounded,
              color: Colors.white54, size: 44),
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    final tier = widget.config.tierFor(_fallenCount);
    final isStrike = _fallenCount >= widget.config.tiers.first.minProducts;
    final isPartial = !isStrike && _fallenCount >= 3;

    final emoji = isStrike ? '🎳' : (isPartial ? '💥' : '😤');
    final bgColor = isStrike
        ? const Color(0xFF27AE60)
        : (isPartial ? const Color(0xFFF39C12) : const Color(0xFFE74C3C));

    return Container(
      color: Colors.black.withAlpha(210),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 14),
            Text(
              tier.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$_fallenCount prodotti abbattuti su ${widget.config.productsTotal}',
              style: const TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: bgColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 44, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: () =>
                  widget.onComplete(tier.statEffects, tier.label),
              child: const Text('Avanti →'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Painters ────────────────────────────────────────────────────────────────

class _ShelfPainter extends CustomPainter {
  final double row1Y, row2Y, width;
  const _ShelfPainter(
      {required this.row1Y, required this.row2Y, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    const plankH = 13.0;
    final shadow = Paint()..color = Colors.black.withAlpha(75);
    final wood = Paint()..color = const Color(0xFF7B3F00);
    final highlight = Paint()
      ..color = const Color(0xFF9E5520)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final y in [row1Y, row2Y]) {
      canvas.drawRect(Rect.fromLTWH(0, y + 3, width, plankH), shadow);
      canvas.drawRect(Rect.fromLTWH(0, y, width, plankH), wood);
      canvas.drawLine(
          Offset(0, y + 1), Offset(width, y + 1), highlight);
    }
  }

  @override
  bool shouldRepaint(_ShelfPainter _) => false;
}

class _SlingshotPainter extends CustomPainter {
  final Offset center;
  final Offset? dragOffset;
  final double maxDrag;
  final Size screenSize;
  final bool showBand;

  const _SlingshotPainter({
    required this.center,
    required this.dragOffset,
    required this.maxDrag,
    required this.screenSize,
    required this.showBand,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final forkPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final leftTip = center + const Offset(-22, -32);
    final rightTip = center + const Offset(22, -32);

    // Prongs
    canvas.drawLine(center + const Offset(-5, 8), leftTip, forkPaint);
    canvas.drawLine(center + const Offset(5, 8), rightTip, forkPaint);

    // Handle — hidden behind Lex's body, skip drawing
    if (!showBand) return;

    final orsettoPosNow =
        dragOffset != null ? center + dragOffset! : center;
    final rbPaint = Paint()
      ..color = const Color(0xFFA0522D)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(leftTip, orsettoPosNow, rbPaint);
    canvas.drawLine(rightTip, orsettoPosNow, rbPaint);

    // Orsetto (circle) at rest or dragged
    final ballPaint = Paint()..color = const Color(0xFF8B6914);
    canvas.drawCircle(orsettoPosNow, 13, ballPaint);
    // emoji-like eyes
    final eyePaint = Paint()..color = Colors.black;
    canvas.drawCircle(orsettoPosNow + const Offset(-4, -3), 2, eyePaint);
    canvas.drawCircle(orsettoPosNow + const Offset(4, -3), 2, eyePaint);

    // Dotted trajectory preview when dragging
    if (dragOffset != null && dragOffset!.distance > 12) {
      _drawTrajectory(canvas, orsettoPosNow);
    }
  }

  void _drawTrajectory(Canvas canvas, Offset startPos) {
    final drag = startPos - center;
    if (drag.distance < 1) return;
    final dir = drag / drag.distance;
    final speed = (drag.distance / maxDrag) * screenSize.height * 2.2;
    final vx = -dir.dx * speed;
    final vy = -dir.dy * speed;
    const dt = 0.58;
    final g = screenSize.height * 1.55;
    const steps = 14;

    final dotPaint = Paint()
      ..color = Colors.white.withAlpha(130)
      ..style = PaintingStyle.fill;

    for (int i = 1; i <= steps; i++) {
      final t = (i / steps) * dt;
      final px = startPos.dx + vx * t;
      final py = startPos.dy + vy * t + 0.5 * g * t * t;
      if (px < -20 || px > screenSize.width + 20 || py < -80) continue;
      final r = 3.5 * (1.0 - i / (steps * 1.4));
      canvas.drawCircle(Offset(px, py), r.clamp(1.0, 4.0), dotPaint);
    }
  }

  @override
  bool shouldRepaint(_SlingshotPainter old) =>
      dragOffset != old.dragOffset || showBand != old.showBand;
}

// ─── Supermarket background ───────────────────────────────────────────────────

class _SupermarketBgPainter extends CustomPainter {
  const _SupermarketBgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Ceiling strip ─────────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.05),
      Paint()..color = const Color(0xFFF0EDE3),
    );

    // Fluorescent light strips (3 across)
    final lightGlow = Paint()
      ..color = const Color(0xFFFFFDE7).withAlpha(200)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final lightFace = Paint()..color = const Color(0xFFFFFBEC);
    for (final frac in [0.18, 0.5, 0.82]) {
      final lx = w * frac;
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(lx, h * 0.026),
            width: w * 0.20,
            height: h * 0.04),
        lightGlow,
      );
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(lx, h * 0.026),
            width: w * 0.17,
            height: h * 0.026),
        lightFace,
      );
    }

    // ── IperPassata banner ────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.05, w, h * 0.045),
      Paint()..color = const Color(0xFFBF360C),
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: '🏪  IperPassata',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        (w - tp.width) / 2,
        h * 0.05 + (h * 0.045 - tp.height) / 2,
      ),
    );

    // ── Wall (cream tiles) ────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.095, w, h * 0.655),
      Paint()..color = const Color(0xFFF4EFE6),
    );

    // Tile grid — horizontal
    final gridH = Paint()
      ..color = const Color(0xFFDDD6CB)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final gridV = Paint()
      ..color = const Color(0xFFE8E0D5)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const tileS = 52.0;
    for (double y = h * 0.095; y < h * 0.75; y += tileS) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridH);
    }
    for (double x = 0; x < w; x += tileS) {
      canvas.drawLine(Offset(x, h * 0.095), Offset(x, h * 0.75), gridV);
    }

    // Warm ambient light from ceiling
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.55),
          radius: 0.85,
          colors: [Color(0x22FFFDE7), Color(0x00FFFDE7)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ── Floor (light grey tiles) ──────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.75, w, h * 0.25),
      Paint()..color = const Color(0xFFCEC9BE),
    );
    final floorGrid = Paint()
      ..color = const Color(0xFFB8B3A8)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    const fTile = 48.0;
    for (double x = 0; x < w; x += fTile) {
      canvas.drawLine(
          Offset(x, h * 0.75), Offset(x, h), floorGrid);
    }
    for (double y = h * 0.75; y < h; y += fTile / 2) {
      canvas.drawLine(Offset(0, y), Offset(w, y), floorGrid);
    }

    // Floor base shadow along wall
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.75, w, 4),
      Paint()..color = Colors.black.withAlpha(30),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Lex character (from behind) ─────────────────────────────────────────────

class _LexPainter extends CustomPainter {
  final Offset slingshotPos;
  const _LexPainter({required this.slingshotPos});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = slingshotPos.dx;
    final sy = slingshotPos.dy;

    // ── Shared paints ─────────────────────────────────────────────────────────
    final skinPaint = Paint()..color = const Color(0xFFFFCBA4);
    final oniePaint = Paint()..color = const Color(0xFF82C4E0);
    final snapPaint = Paint()..color = const Color(0xFF5AAECF);
    final hairPaint = Paint()
      ..color = const Color(0xFF5C3317)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final armPaint = Paint()
      ..color = const Color(0xFFFFCBA4)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final legPaint = Paint()
      ..color = const Color(0xFF82C4E0)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final shoePaint = Paint()..color = const Color(0xFF7B3F00);
    final shadowPaint = Paint()..color = Colors.black.withAlpha(28);

    // Drop shadow for body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx + 3, sy + 29), width: 54, height: 62),
        const Radius.circular(27),
      ),
      shadowPaint,
    );

    // ── Body (onesie) ─────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, sy + 26), width: 52, height: 58),
        const Radius.circular(26),
      ),
      oniePaint,
    );

    // Collar crease at top of body
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx, sy + 2), width: 30, height: 14),
      0, 3.14159, false,
      Paint()
        ..color = const Color(0xFF5AAECF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Snap buttons at bottom
    for (final dx in [-9.0, 0.0, 9.0]) {
      canvas.drawCircle(Offset(cx + dx, sy + 52), 3, snapPaint);
    }

    // ── Arms (reaching up toward slingshot handle) ────────────────────────────
    canvas.drawLine(
        Offset(cx - 25, sy + 10), Offset(cx - 7, sy - 5), armPaint);
    canvas.drawLine(
        Offset(cx + 25, sy + 10), Offset(cx + 7, sy - 5), armPaint);

    // ── Legs peeking out ──────────────────────────────────────────────────────
    canvas.drawLine(
        Offset(cx - 14, sy + 53), Offset(cx - 16, sy + 76), legPaint);
    canvas.drawLine(
        Offset(cx + 14, sy + 53), Offset(cx + 16, sy + 76), legPaint);

    // Little shoes
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx - 19, sy + 83), width: 22, height: 11),
        const Radius.circular(5),
      ),
      shoePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx + 19, sy + 83), width: 22, height: 11),
        const Radius.circular(5),
      ),
      shoePaint,
    );

    // ── Neck ─────────────────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(cx, sy - 3), width: 18, height: 16),
      skinPaint,
    );

    // ── Head ─────────────────────────────────────────────────────────────────
    // Shadow
    canvas.drawCircle(Offset(cx + 2, sy - 34), 22, shadowPaint);
    // Skin
    canvas.drawCircle(Offset(cx, sy - 36), 22, skinPaint);
    // Ear bumps
    canvas.drawCircle(Offset(cx - 21, sy - 36), 5, skinPaint);
    canvas.drawCircle(Offset(cx + 21, sy - 36), 5, skinPaint);

    // ── Hair tuft ─────────────────────────────────────────────────────────────
    final hairBase = Offset(cx, sy - 57);
    canvas.drawLine(hairBase, hairBase + const Offset(-6, -9), hairPaint);
    canvas.drawLine(hairBase, hairBase + const Offset(0, -13), hairPaint);
    canvas.drawLine(hairBase, hairBase + const Offset(6, -9), hairPaint);
    canvas.drawLine(
        hairBase + const Offset(-3, -2),
        hairBase + const Offset(-10, -6),
        hairPaint..strokeWidth = 2.5);
    canvas.drawLine(
        hairBase + const Offset(3, -2),
        hairBase + const Offset(10, -6),
        Paint()
          ..color = const Color(0xFF5C3317)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_LexPainter old) => slingshotPos != old.slingshotPos;
}
