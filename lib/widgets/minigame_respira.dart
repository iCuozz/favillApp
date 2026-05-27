import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comic_data.dart';

enum _RespiraPhase { tutorial, playing, result }

/// Mini-game EP1 "Respira": tieni premuto per sopprimere il calore.
/// Il calore sale automaticamente; tenendo premuto si abbassa.
/// Successo = sopravvivi per tutta la durata senza raggiungere il limite.
class MinigameRespiraScreen extends StatefulWidget {
  final MinigameConfig config;
  final void Function(
          Map<String, int> statEffects, String tierLabel, MinigameTier tier)
      onComplete;

  const MinigameRespiraScreen(
      {super.key, required this.config, required this.onComplete});

  @override
  State<MinigameRespiraScreen> createState() => _MinigameRespiraScreenState();
}

class _MinigameRespiraScreenState extends State<MinigameRespiraScreen>
    with TickerProviderStateMixin {
  _RespiraPhase _phase = _RespiraPhase.tutorial;
  double _heat = 0.28;
  double _timeLeft = 0;
  bool _holding = false;
  bool _success = false;
  Timer? _ticker;

  late AnimationController _pulseCtrl;
  late AnimationController _resultCtrl;

  // Calore sale di questo valore al secondo (passivo)
  static const _kRiseRate = 0.055;
  // Calore scende di questo valore al secondo (tasto premuto)
  static const _kDecayRate = 0.14;
  static const _kTickMs = 50;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  void _startGame() {
    setState(() {
      _phase = _RespiraPhase.playing;
      _heat = 0.28;
      _timeLeft = (widget.config.durationSeconds ?? 12).toDouble();
      _holding = false;
    });
    _ticker = Timer.periodic(
        const Duration(milliseconds: _kTickMs), _tick);
  }

  void _tick(Timer _) {
    if (_phase != _RespiraPhase.playing) return;
    const dt = _kTickMs / 1000.0;
    setState(() {
      _heat = (_holding
              ? (_heat - _kDecayRate * dt)
              : (_heat + _kRiseRate * dt))
          .clamp(0.0, 1.0);
      _timeLeft -= dt;
      if (_heat >= 1.0) {
        _endGame(false);
      } else if (_timeLeft <= 0) {
        _endGame(true);
      }
    });
  }

  void _endGame(bool success) {
    _ticker?.cancel();
    _success = success;
    HapticFeedback.mediumImpact();
    setState(() => _phase = _RespiraPhase.result);
    _resultCtrl.forward();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0820),
      body: SafeArea(
        child: switch (_phase) {
          _RespiraPhase.tutorial => _buildTutorial(),
          _RespiraPhase.playing => _buildGame(),
          _RespiraPhase.result => _buildResult(),
        },
      ),
    );
  }

  Widget _buildTutorial() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            const Text(
              'Le mani si scaldano.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.3),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tieni premuto per sopprimere il calore.\nNon lasciare che raggiunga il rosso.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 44),
            GestureDetector(
              onTap: _startGame,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 44, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A148C), Color(0xFF880E4F)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B1FA2).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Text('Inizia',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    final heatColor = Color.lerp(
      const Color(0xFF1565C0),
      const Color(0xFFD32F2F),
      Curves.easeIn.transform(_heat),
    )!;
    final duration = (widget.config.durationSeconds ?? 12).toDouble();
    final progress = (_timeLeft / duration).clamp(0.0, 1.0);

    return Column(
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white10,
                  color: Colors.white38,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_timeLeft.ceil()}s',
                style: const TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ],
          ),
        ),
        const Spacer(),
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => CustomPaint(
            size: const Size(260, 260),
            painter: _HeatPainter(
              heat: _heat,
              pulse: _holding ? 0 : _pulseCtrl.value * 0.06 * _heat,
              heatColor: heatColor,
            ),
          ),
        ),
        const SizedBox(height: 20),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: _heat > 0.85 ? Colors.red[300]! : Colors.white54,
            fontSize: 15,
            fontWeight: _heat > 0.85 ? FontWeight.bold : FontWeight.normal,
          ),
          child: Text(_holding
              ? '✋  Trattieni...'
              : _heat > 0.85
                  ? '⚠️  Troppo caldo!'
                  : '🔥  Tieni premuto'),
        ),
        const Spacer(),
        // Bottone hold
        Listener(
          onPointerDown: (_) => setState(() => _holding = true),
          onPointerUp: (_) => setState(() => _holding = false),
          onPointerCancel: (_) => setState(() => _holding = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _holding
                  ? heatColor.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: _holding ? heatColor : Colors.white24,
                width: _holding ? 3 : 1.5,
              ),
              boxShadow: _holding
                  ? [
                      BoxShadow(
                          color: heatColor.withValues(alpha: 0.45),
                          blurRadius: 28,
                          spreadRadius: 4)
                    ]
                  : [],
            ),
            child: const Center(
              child: Text('✋', style: TextStyle(fontSize: 52)),
            ),
          ),
        ),
        const SizedBox(height: 52),
      ],
    );
  }

  Widget _buildResult() {
    final tier = widget.config.tierFor(_success ? 1 : 0);
    return ScaleTransition(
      scale: CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_success ? '❄️' : '🔥',
                  style: const TextStyle(fontSize: 84)),
              const SizedBox(height: 16),
              Text(
                tier.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.3),
              ),
              const SizedBox(height: 36),
              GestureDetector(
                onTap: () =>
                    widget.onComplete(tier.statEffects, tier.label, tier),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _success
                          ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                          : [
                              const Color(0xFFB71C1C),
                              const Color(0xFFC62828)
                            ],
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Text('Avanti →',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeatPainter extends CustomPainter {
  final double heat;
  final double pulse;
  final Color heatColor;

  const _HeatPainter(
      {required this.heat, required this.pulse, required this.heatColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final r = size.width / 2 - 14;

    // Glow diffuso
    canvas.drawCircle(
      center,
      r * (0.65 + heat * 0.35 + pulse),
      Paint()
        ..color = heatColor.withValues(alpha: 0.12 + heat * 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32),
    );

    // Sfondo anello
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..style = PaintingStyle.fill,
    );

    // Arco riempimento calore (senso orario dal top)
    final arcSweep = heat * 2 * pi;
    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + arcSweep,
        colors: [
          heatColor.withValues(alpha: 0.6),
          heatColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r))
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (arcSweep > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r - 2),
        -pi / 2,
        arcSweep,
        false,
        arcPaint,
      );
    }

    // Anello outline
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Marcatore soglia pericolo a 85%
    const dangerAngle = -pi / 2 + 0.85 * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r + 10),
      dangerAngle - 0.05,
      0.10,
      false,
      Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.7)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke,
    );

    // Emoji centrale
    final emoji = heat > 0.6 ? '🔥' : (heat > 0.3 ? '🌡️' : '❄️');
    final tp = TextPainter(
      text: TextSpan(
          text: emoji,
          style: TextStyle(fontSize: 44 + heat * 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_HeatPainter old) =>
      heat != old.heat || heatColor != old.heatColor || pulse != old.pulse;
}
