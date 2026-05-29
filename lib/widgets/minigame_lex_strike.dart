// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final void Function(Map<String, int> statEffects, String tierLabel, MinigameTier tier) onComplete;

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
  final List<Offset> _projTrail = [];

  // ─── Wind ─────────────────────────────────────────────────────────────────
  double _windForce = 0.0; // normalised -1..1, randomised at init

  // ─── Impact flash ─────────────────────────────────────────────────────────
  late AnimationController _flashCtrl;
  late Animation<double> _flashAnim;

  // ─── Layout (computed once) ───────────────────────────────────────────────
  bool _layoutReady = false;
  late Size _screenSize;
  late Offset _slingshotPos;
  late List<Offset> _productCenters;
  static const double _kProductSize = 44.0;
  static const double _kProductGap = 14.0;

  // ─── Result ───────────────────────────────────────────────────────────────
  int _fallenCount = 0;

  // ─── Screen shake ────────────────────────────────────────────────────────
  late AnimationController _shakeCtrl;
  late Animation<Offset> _shakeAnim;

  // ─── Retry on complete miss ────────────────────────────────────────────────
  bool _retryUsed = false;
  double _retryPowerMul = 1.0;
  bool _showRetryOverlay = false;

  // ─── Wind animation ───────────────────────────────────────────────────────
  late AnimationController _windParticleCtrl;

  // ─── Result overlay animation ─────────────────────────────────────────────
  late AnimationController _resultCtrl;
  late Animation<double> _resultScaleAnim;

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
    final rng = Random();
    _windForce = (rng.nextDouble() * 2 - 1) * 0.65;

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

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(8, -6)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(8, -6), end: const Offset(-7, 5)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(-7, 5), end: const Offset(5, -4)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(5, -4), end: const Offset(-4, 3)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(-4, 3), end: Offset.zero), weight: 2),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);

    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _resultScaleAnim = CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut);

    _windParticleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _loadTutorialPref();
  }

  Future<void> _loadTutorialPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _phase != _Phase.tutorial) return;
    if (prefs.getBool('tut_lex_strike') ?? false) {
      setState(() => _phase = _Phase.aiming);
    }
  }

  void _initLayout(Size size) {
    if (_layoutReady) return;
    _layoutReady = true;
    _screenSize = size;
    _slingshotPos = Offset(size.width / 2, size.height * 0.76);

    // 3 rows × 4 cols spread across the far-wall area (h*0.06–h*0.62)
    const cols = 4;
    final n = widget.config.productsTotal.clamp(1, 12);
    const stride = _kProductSize + _kProductGap;
    const totalW = cols * stride - _kProductGap;
    final startX = (size.width - totalW) / 2 + _kProductSize / 2;
    final row1Y = size.height * 0.15;
    final row2Y = size.height * 0.30;
    final row3Y = size.height * 0.45;

    _productCenters = [];
    for (int i = 0; i < n; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final rowY = row == 0 ? row1Y : (row == 1 ? row2Y : row3Y);
      _productCenters.add(Offset(startX + col * stride, rowY));
    }
    _projPos = _slingshotPos;
  }

  // ─── Physics ─────────────────────────────────────────────────────────────
  void _onProjTick() {
    final t = _projCtrl.value;
    const dt = 0.58;
    final g = _screenSize.height * 1.55;
    // Wind force: horizontal drift proportional to time squared (acceleration)
    final windAcc = _windForce * _screenSize.width * 0.55;
    final newPos = Offset(
      _slingshotPos.dx + _projVelocity.dx * t * dt + 0.5 * windAcc * (t * dt) * (t * dt),
      _slingshotPos.dy +
          _projVelocity.dy * t * dt +
          0.5 * g * (t * dt) * (t * dt),
    );
    setState(() {
      _projTrail.add(_projPos);
      if (_projTrail.length > 10) _projTrail.removeAt(0);
      _projPos = newPos;
    });
  }

  void _resolveHits() {
    final impact = _projPos;
    const directR = 46.0;
    const chainR = 66.0;
    const chainP = 0.40;
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

    // Retry su miss completo (nessun prodotto colpito, solo una volta)
    if (fallen.isEmpty && !_retryUsed) {
      _retryUsed = true;
      _retryPowerMul = 0.75;
      _projCtrl.stop();
      setState(() => _showRetryOverlay = true);
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _showRetryOverlay = false;
          _phase = _Phase.aiming;
          _projPos = _slingshotPos;
          _projTrail.clear();
          _dragOffset = null;
        });
        _projCtrl.reset();
      });
      return; // non entrare in chainReaction
    }

    _fallenCount = fallen.length;
    setState(() => _phase = _Phase.chainReaction);

    if (fallen.isNotEmpty) {
      _shakeCtrl.forward(from: 0);
      _flashCtrl.forward(from: 0).then((_) => _flashCtrl.reverse());
      HapticFeedback.heavyImpact();
    }

    final sorted = fallen.toList()..sort();
    for (int k = 0; k < sorted.length; k++) {
      final idx = sorted[k];
      Future.delayed(Duration(milliseconds: k * 70), () {
        if (!mounted) return;
        setState(() => _fallen[idx] = true);
        _fallCtrl[idx].forward();
        if (k > 0) HapticFeedback.lightImpact();
      });
    }

    Future.delayed(Duration(milliseconds: sorted.length * 70 + 700), () {
      if (!mounted) return;
      setState(() => _phase = _Phase.result);
      _resultCtrl.forward(from: 0);
    });
  }

  // ─── Gesture handlers ────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails _) {
    if (_phase == _Phase.tutorial) {
      SharedPreferences.getInstance()
          .then((p) => p.setBool('tut_lex_strike', true));
      setState(() => _phase = _Phase.aiming);
    }
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
    final speed = (drag.distance / _kMaxDrag) * _screenSize.height * 2.2 * _retryPowerMul;
    _projVelocity = Offset(-dir.dx * speed, -dir.dy * speed);
    _projPos = _slingshotPos;
    setState(() {
      _phase = _Phase.launched;
      _dragOffset = null;
    });
    HapticFeedback.mediumImpact();
    _projCtrl.forward(from: 0);
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    for (final c in _fallCtrl) { c.dispose(); }
    _projCtrl.dispose();
    _shakeCtrl.dispose();
    _flashCtrl.dispose();
    _resultCtrl.dispose();
    _windParticleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.translate(
          offset: _shakeAnim.value,
          child: child,
        ),
        child: LayoutBuilder(
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
                  _buildShelves3D(),
                  _buildProducts3D(),
                  _buildLexCharacter(),
                  _buildSlingshotAndTrajectory(),
                  if (_phase == _Phase.launched ||
                      _phase == _Phase.chainReaction) ...[
                    _buildTrail(),
                    _buildProjectile(),
                  ],
                  _buildWindIndicator(),
                  _buildHud(),
                  if (_phase == _Phase.tutorial) _buildTutorialHint(),
                  // Impact flash overlay
                  FadeTransition(
                    opacity: _flashAnim,
                    child: Container(color: Colors.white.withAlpha(80)),
                  ),
                  if (_phase == _Phase.result) _buildResultOverlay(),
                  // Retry overlay
                  if (_showRetryOverlay) _buildRetryOverlay(),
                ],
              ),
            );
          },
        ),
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

  Widget _buildShelves3D() {
    const halfProd = _kProductSize / 2; // 22.0
    final row1Bottom = _screenSize.height * 0.15 + halfProd + 4;
    final row2Bottom = _screenSize.height * 0.30 + halfProd + 4;
    final row3Bottom = _screenSize.height * 0.45 + halfProd + 4;
    return CustomPaint(
      size: _screenSize,
      painter: _ShelfPainter(
        row1Y: row1Bottom,
        row2Y: row2Bottom,
        row3Y: row3Bottom,
        width: _screenSize.width,
      ),
    );
  }

  Widget _buildProducts3D() {
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
                  child: Transform(
                    transform: Matrix4.identity()
                      ..rotateX(p * 1.8 * (i.isEven ? 1 : -1))
                      ..rotateZ(p * (i.isEven ? 0.9 : -0.9)),
                    alignment: Alignment.center,
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

  Widget _buildTrail() {
    return CustomPaint(
      size: _screenSize,
      painter: _TrailPainter(trail: List.from(_projTrail)),
    );
  }

  Widget _buildWindIndicator() {
    if (_phase == _Phase.result) return const SizedBox.shrink();
    final abs = _windForce.abs();
    if (abs < 0.08) return const SizedBox.shrink();
    final isRight = _windForce > 0;
    final strength = (abs * 3).ceil().clamp(1, 3);
    final arrows = List.filled(strength, isRight ? '›' : '‹').join(' ');

    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _windParticleCtrl,
          builder: (_, __) {
            final t = _windParticleCtrl.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(120),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.air, color: Colors.lightBlueAccent, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'Vento $arrows',
                        style: const TextStyle(
                          color: Colors.lightBlueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Particelle animate
                      SizedBox(
                        width: 36,
                        height: 14,
                        child: Stack(
                          children: List.generate(3, (i) {
                            // Offset staggerato per ogni particella
                            final phase = (t + i / 3.0) % 1.0;
                            final x = isRight ? phase * 36 : (1 - phase) * 36;
                            final alpha = (sin(phase * pi)).clamp(0.0, 1.0);
                            return Positioned(
                              left: x - 3,
                              top: 3 + (i - 1) * 3.0,
                              child: Opacity(
                                opacity: alpha,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                 decoration: const BoxDecoration(
                                    color: Colors.lightBlueAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRetryOverlay() {
    return AnimatedOpacity(
      opacity: _showRetryOverlay ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.black.withAlpha(200),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😤', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              const Text(
                'Mancato!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Riprova — un ultimo lancio',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
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
        windForce: _windForce,
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

    // Quote narrative per tier (indicizzate per posizione, non label)
    final tierIndex = widget.config.tiers.indexOf(tier);
    const narrativeQuotes = [
      '"Prodotti ovunque.\nLex urla, poi ride."',       // tier 0 (STRIKE)
      '"Quasi. Il bancone\ntrema ancora."',              // tier 1 (parziale)
      '"L\'orsetto rimbalza.\nNessuno ha visto niente."', // tier 2 (mancato)
    ];
    final quote = narrativeQuotes[tierIndex.clamp(0, narrativeQuotes.length - 1)];

    return Container(
      color: Colors.black.withAlpha(210),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _resultScaleAnim,
              child: Text(emoji, style: const TextStyle(fontSize: 80)),
            ),
            const SizedBox(height: 14),
            FadeTransition(
              opacity: _resultCtrl,
              child: Text(
                tier.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _resultCtrl,
              child: Text(
                '$_fallenCount prodotti abbattuti su ${widget.config.productsTotal}',
                style: const TextStyle(color: Colors.white60, fontSize: 15),
              ),
            ),
            const SizedBox(height: 16),
            // Quote narrativa
            FadeTransition(
              opacity: _resultCtrl,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  quote,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _resultCtrl,
              child: ElevatedButton(
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
                    widget.onComplete(tier.statEffects, tier.label, tier),
                child: const Text('Avanti →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Painters ────────────────────────────────────────────────────────────────

class _ShelfPainter extends CustomPainter {
  final double row1Y, row2Y, row3Y, width;
  const _ShelfPainter(
      {required this.row1Y, required this.row2Y, required this.row3Y, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    // Shelf spans the far-wall x range
    final fwL = size.width * 0.18;
    final fwR = size.width * 0.82;

    const plankTopH  = 5.0;   // top surface — visible because we look slightly from above
    const plankFaceH = 11.0;  // front face height
    const plankTotalH = plankTopH + plankFaceH;

    final topSurface = Paint()..color = const Color(0xFF9E6B3E); // lit top
    final frontFace  = Paint()..color = const Color(0xFF7B3F00); // darker face
    final highlight  = Paint()
      ..color = const Color(0xFFBE8B5A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final shadow = Paint()..color = Colors.black.withAlpha(55);

    for (final y in [row1Y, row2Y, row3Y]) {
      // Drop shadow below plank
      canvas.drawRect(Rect.fromLTWH(fwL, y + plankTotalH, fwR - fwL, 3.5), shadow);
      // Top surface (lighter wood — lit from ceiling lights)
      canvas.drawRect(Rect.fromLTWH(fwL, y, fwR - fwL, plankTopH), topSurface);
      // Front face (darker)
      canvas.drawRect(Rect.fromLTWH(fwL, y + plankTopH, fwR - fwL, plankFaceH), frontFace);
      // Highlight on top edge
      canvas.drawLine(Offset(fwL, y + 0.6), Offset(fwR, y + 0.6), highlight);
    }
  }

  @override
  bool shouldRepaint(_ShelfPainter _) => false;
}

/// Scia del proiettile in volo.
class _TrailPainter extends CustomPainter {
  final List<Offset> trail;
  const _TrailPainter({required this.trail});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < trail.length; i++) {
      final frac = (i + 1) / trail.length;
      final r = 6.0 * frac;
      canvas.drawCircle(
        trail[i],
        r,
        Paint()..color = Colors.orangeAccent.withAlpha((frac * 100).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => trail != old.trail;
}

class _SlingshotPainter extends CustomPainter {
  final Offset center;
  final Offset? dragOffset;
  final double maxDrag;
  final Size screenSize;
  final bool showBand;
  final double windForce;

  const _SlingshotPainter({
    required this.center,
    required this.dragOffset,
    required this.maxDrag,
    required this.screenSize,
    required this.showBand,
    this.windForce = 0.0,
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
    final windAcc = windForce * screenSize.width * 0.55;
    const steps = 16;

    final dotPaint = Paint()
      ..color = Colors.white.withAlpha(130)
      ..style = PaintingStyle.fill;

    for (int i = 1; i <= steps; i++) {
      final t = (i / steps) * dt;
      final px = startPos.dx + vx * t + 0.5 * windAcc * t * t;
      final py = startPos.dy + vy * t + 0.5 * g * t * t;
      if (px < -20 || px > screenSize.width + 20 || py < -80) continue;
      final r = 3.5 * (1.0 - i / (steps * 1.4));
      canvas.drawCircle(Offset(px, py), r.clamp(1.0, 4.0), dotPaint);
    }
  }

  @override
  bool shouldRepaint(_SlingshotPainter old) =>
      dragOffset != old.dragOffset || showBand != old.showBand || windForce != old.windForce;
}

// ─── Supermarket background ───────────────────────────────────────────────────

class _SupermarketBgPainter extends CustomPainter {
  const _SupermarketBgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── One-point perspective geometry ───────────────────────────────────────
    // Far wall (back of the supermarket aisle) — derived first, then
    // floor/ceiling trapezoids are computed FROM these edges (rubber-duck fix).
    final fwL = w * 0.18;
    final fwR = w * 0.82;
    final fwT = h * 0.055;
    final fwB = h * 0.62;

    // ── Ceiling trapezoid ─────────────────────────────────────────────────────
    final ceilPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(fwR, fwT)
      ..lineTo(fwL, fwT)
      ..close();
    canvas.drawPath(ceilPath, Paint()..color = const Color(0xFFF2EDE3));

    // Perspective fluorescent light strips (correctly perspected trapezoids)
    for (final frac in [0.22, 0.50, 0.78]) {
      // Near end (y=0): strip half-width = 6.5% of screen width
      final nearLeft  = w * (frac - 0.065);
      final nearRight = w * (frac + 0.065);
      // Far end (y=fwT): perspected onto far-wall top edge
      final farCx     = fwL + frac * (fwR - fwL);
      final halfFarW  = 0.065 * (fwR - fwL);
      final farLeft   = farCx - halfFarW;
      final farRight  = farCx + halfFarW;

      final glowPath = Path()
        ..moveTo(nearLeft, 0)
        ..lineTo(nearRight, 0)
        ..lineTo(farRight, fwT)
        ..lineTo(farLeft, fwT)
        ..close();
      canvas.drawPath(
        glowPath,
        Paint()
          ..color = const Color(0xFFFFFDE7).withAlpha(155)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      final facePath = Path()
        ..moveTo(nearLeft + 3, 0)
        ..lineTo(nearRight - 3, 0)
        ..lineTo(farRight - 2, fwT * 0.55)
        ..lineTo(farLeft + 2, fwT * 0.55)
        ..close();
      canvas.drawPath(facePath, Paint()..color = const Color(0xFFFFFBEC));
    }

    // ── Left side wall ────────────────────────────────────────────────────────
    final leftWall = Path()
      ..moveTo(0, 0)
      ..lineTo(fwL, fwT)
      ..lineTo(fwL, fwB)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(leftWall, Paint()..color = const Color(0xFFEBE5DA));

    // Shelf outline lines on left side wall (perspective)
    final sidePaint = Paint()
      ..color = const Color(0xFFC0BAB0)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    for (final tY in [0.15, 0.30, 0.45]) {
      // Screen-space y on the left wall edge
      final yScreen = h * tY;
      // Matching y on the far-wall left edge (linear in perspective)
      final tFrac  = (tY - fwT / h) / (fwB / h - fwT / h);
      final yFar   = (fwT + (fwB - fwT) * tFrac).clamp(fwT, fwB);
      canvas.drawLine(Offset(0, yScreen), Offset(fwL, yFar), sidePaint);
    }

    // ── Right side wall ───────────────────────────────────────────────────────
    final rightWall = Path()
      ..moveTo(w, 0)
      ..lineTo(fwR, fwT)
      ..lineTo(fwR, fwB)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(rightWall, Paint()..color = const Color(0xFFEBE5DA));
    for (final tY in [0.15, 0.30, 0.45]) {
      final yScreen = h * tY;
      final tFrac   = (tY - fwT / h) / (fwB / h - fwT / h);
      final yFar    = (fwT + (fwB - fwT) * tFrac).clamp(fwT, fwB);
      canvas.drawLine(Offset(w, yScreen), Offset(fwR, yFar), sidePaint);
    }

    // ── Far wall ──────────────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTRB(fwL, fwT, fwR, fwB),
      Paint()..color = const Color(0xFFF4EFE6),
    );

    // Tile grid on far wall
    final gridPaint = Paint()
      ..color = const Color(0xFFDDD6CB)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;
    for (double y = fwT; y < fwB; y += 38) {
      canvas.drawLine(Offset(fwL, y), Offset(fwR, y), gridPaint);
    }
    for (double x = fwL; x < fwR; x += 46) {
      canvas.drawLine(Offset(x, fwT), Offset(x, fwB), gridPaint);
    }

    // ── "IperPassata" banner ──────────────────────────────────────────────────
    final bannerH = (fwB - fwT) * 0.075;
    canvas.drawRect(
      Rect.fromLTWH(fwL, fwT, fwR - fwL, bannerH),
      Paint()..color = const Color(0xFFBF360C),
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: '🏪  IperPassata',
        style: TextStyle(
          color: Colors.white, fontSize: 11,
          fontWeight: FontWeight.bold, letterSpacing: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(
      fwL + (fwR - fwL - tp.width) / 2,
      fwT + (bannerH - tp.height) / 2,
    ));

    // ── Floor trapezoid (top edge = far wall BOTTOM — not VP) ─────────────────
    final floorPath = Path()
      ..moveTo(fwL, fwB)
      ..lineTo(fwR, fwB)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(floorPath, Paint()..color = const Color(0xFFCEC9BE));

    final tilePaint = Paint()
      ..color = const Color(0xFFB4AFA4)
      ..strokeWidth = 0.85
      ..style = PaintingStyle.stroke;

    // Vertical (depth) lines — radiate FROM far-wall bottom edge TO screen corners
    const nV = 7;
    for (int k = 0; k <= nV; k++) {
      final t = k / nV;
      canvas.drawLine(
        Offset(fwL + (fwR - fwL) * t, fwB),
        Offset(w * t, h),
        tilePaint,
      );
    }
    // Horizontal lines — quadratic bunching (denser near far wall = more realistic)
    const nH = 5;
    for (int k = 1; k < nH; k++) {
      final t  = (k / nH) * (k / nH); // quadratic compression
      final y  = fwB + (h - fwB) * t;
      final xl = fwL + (0 - fwL) * t;
      final xr = fwR + (w - fwR) * t;
      canvas.drawLine(Offset(xl, y), Offset(xr, y), tilePaint);
    }

    // Shadow strip at far-wall / floor junction
    canvas.drawRect(
      Rect.fromLTWH(fwL, fwB - 1, fwR - fwL, 4),
      Paint()..color = Colors.black.withAlpha(40),
    );

    // Warm ambient light from ceiling
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.45),
          radius: 0.85,
          colors: [Color(0x22FFFDE7), Color(0x00FFFDE7)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(_SupermarketBgPainter _) => false;
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
