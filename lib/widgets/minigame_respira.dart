import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comic_data.dart';

enum _RespiraPhase { tutorial, playing, result }

// ─────────────────────────── Ember particle ────────────────────────────────
class _Ember {
  double x;      // 0..1 normalizzato
  double y;      // 0..1 normalizzato
  double vy;     // velocità verticale (negativa = su)
  double vx;     // drift laterale
  double size;
  double life;   // 0..1 (1=vivo, 0=morto)
  double decay;  // velocità di spegnimento
  Color color;

  _Ember({
    required this.x,
    required this.y,
    required this.vy,
    required this.vx,
    required this.size,
    required this.life,
    required this.decay,
    required this.color,
  });
}

// ─────────────────────────────── Widget ────────────────────────────────────

/// Mini-game EP1 "Respira": gauge del calore con surge randomici.
/// Difficoltà alta: rise rapido, surge improvvisi, decadimento lento.
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
  double _heat = 0.45;
  double _timeLeft = 0;
  bool _holding = false;
  bool _success = false;
  Timer? _ticker;

  // Surge system
  double _nextSurgeIn = 2.8;   // secondi al prossimo surge
  double _surgeProgress = 0.0; // 0=niente, 0..1=warning, >1=esplosione
  bool _inSurgeWarning = false;
  static const _kSurgeWarnDuration = 0.9; // secondi di avvertimento

  // Shake
  final _rng = Random();
  double _shakeX = 0;
  double _shakeY = 0;

  // Ember particles
  final List<_Ember> _embers = [];

  // ── Parametri difficoltà ──────────────────────────────────────────────
  static const _kRiseRate = 0.12;   // passivo per secondo (era 0.055)
  static const _kDecayRate = 0.095; // decadimento mentre si tiene (era 0.14)
  static const _kStartHeat = 0.45;  // calore iniziale (era 0.28)
  static const _kTickMs = 40;       // 25fps

  late AnimationController _pulseCtrl;
  late AnimationController _resultCtrl;
  late AnimationController _surgeWarnCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _surgeWarnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);
  }

  void _startGame() {
    setState(() {
      _phase = _RespiraPhase.playing;
      _heat = _kStartHeat;
      _timeLeft = (widget.config.durationSeconds ?? 12).toDouble();
      _holding = false;
      _nextSurgeIn = 2.5 + _rng.nextDouble() * 1.5;
      _inSurgeWarning = false;
      _surgeProgress = 0;
    });
    _ticker = Timer.periodic(
        const Duration(milliseconds: _kTickMs), _tick);
  }

  void _tick(Timer _) {
    if (_phase != _RespiraPhase.playing) return;
    const dt = _kTickMs / 1000.0;

    setState(() {
      // ── Aggiorna calore ──────────────────────────────────────────────
      _heat = (_holding
              ? (_heat - _kDecayRate * dt)
              : (_heat + _kRiseRate * dt))
          .clamp(0.0, 1.0);
      _timeLeft -= dt;

      // ── Surge countdown ──────────────────────────────────────────────
      if (!_inSurgeWarning) {
        _nextSurgeIn -= dt;
        if (_nextSurgeIn <= 0) {
          _inSurgeWarning = true;
          _surgeProgress = 0;
          HapticFeedback.lightImpact();
        }
      } else {
        _surgeProgress += dt / _kSurgeWarnDuration;
        if (_surgeProgress >= 1.0) {
          // 💥 SURGE!
          final spike = 0.12 + _rng.nextDouble() * 0.14;
          _heat = (_heat + spike).clamp(0.0, 1.0);
          HapticFeedback.heavyImpact();
          _inSurgeWarning = false;
          _surgeProgress = 0;
          // Prossimo surge: 2.5..5s
          _nextSurgeIn = 2.5 + _rng.nextDouble() * 2.5;
        }
      }

      // ── Shake a calore alto ──────────────────────────────────────────
      if (_heat > 0.72) {
        final intensity = (_heat - 0.72) / 0.28 * 6;
        _shakeX = (_rng.nextDouble() - 0.5) * intensity;
        _shakeY = (_rng.nextDouble() - 0.5) * intensity;
      } else {
        _shakeX = 0;
        _shakeY = 0;
      }

      // ── Ember particles ──────────────────────────────────────────────
      _updateEmbers(dt);

      // ── Fine partita ─────────────────────────────────────────────────
      if (_heat >= 1.0) {
        _endGame(false);
      } else if (_timeLeft <= 0) {
        _endGame(true);
      }
    });
  }

  void _updateEmbers(double dt) {
    // Rimuovi morti
    _embers.removeWhere((e) => e.life <= 0);
    // Aggiorna esistenti
    for (final e in _embers) {
      e.y += e.vy * dt;
      e.x += e.vx * dt;
      e.life -= e.decay * dt;
    }
    // Spawn nuove braci in base al calore
    final spawnRate = (_heat * 12).round();
    for (int i = 0; i < min(spawnRate, 3); i++) {
      if (_rng.nextDouble() < 0.35) {
        _embers.add(_Ember(
          x: 0.3 + _rng.nextDouble() * 0.4,
          y: 0.55 + _rng.nextDouble() * 0.1,
          vy: -(0.06 + _rng.nextDouble() * 0.12),
          vx: (_rng.nextDouble() - 0.5) * 0.04,
          size: 2 + _rng.nextDouble() * 4,
          life: 1.0,
          decay: 0.6 + _rng.nextDouble() * 0.8,
          color: _rng.nextDouble() < 0.5
              ? const Color(0xFFFF6D00)
              : const Color(0xFFFFAB40),
        ));
      }
    }
  }

  void _endGame(bool success) {
    _ticker?.cancel();
    _success = success;
    if (success) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() => _phase = _RespiraPhase.result);
    _resultCtrl.forward();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseCtrl.dispose();
    _resultCtrl.dispose();
    _surgeWarnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: switch (_phase) {
          _RespiraPhase.tutorial => _buildTutorial(),
          _RespiraPhase.playing => _buildGame(context),
          _RespiraPhase.result => _buildResult(),
        },
      ),
    );
  }

  // ────────────────────────────── Tutorial ──────────────────────────────────

  Widget _buildTutorial() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C0820), Color(0xFF1A0010)],
        ),
      ),
      child: Center(
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
                'Tieni premuto per sopprimere il calore.\n'
                'Attenzione ai picchi improvvisi — ci sarà un avviso.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white54, fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 44),
              GestureDetector(
                onTap: _startGame,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 44, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A1B9A), Color(0xFFC62828)],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC62828).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
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
      ),
    );
  }

  // ─────────────────────────────── Game ────────────────────────────────────

  Widget _buildGame(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final heatColor = Color.lerp(
      const Color(0xFF1565C0),
      const Color(0xFFBF360C),
      Curves.easeIn.transform(_heat),
    )!;
    final bgColor = Color.lerp(
      const Color(0xFF0C0820),
      const Color(0xFF3D0000),
      Curves.easeIn.transform(_heat),
    )!;
    final duration = (widget.config.durationSeconds ?? 12).toDouble();
    final timerProgress = (_timeLeft / duration).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(_shakeX, _shakeY),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgColor, Color.lerp(bgColor, Colors.black, 0.4)!],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Ember particles ────────────────────────────────────────
            CustomPaint(
              size: Size(size.width, size.height),
              painter: _EmberPainter(embers: _embers, canvasSize: size),
            ),

            // ── Surge warning overlay ───────────────────────────────────
            if (_inSurgeWarning)
              AnimatedBuilder(
                animation: _surgeWarnCtrl,
                builder: (_, __) => IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          const Color(0xFFFF6D00).withValues(
                              alpha: 0.18 * _surgeWarnCtrl.value * _surgeProgress),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── UI layer ───────────────────────────────────────────────
            Column(
              children: [
                const SizedBox(height: 20),

                // Timer bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: timerProgress,
                          backgroundColor: Colors.white10,
                          color: Color.lerp(
                            Colors.greenAccent,
                            Colors.redAccent,
                            1 - timerProgress,
                          ),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_timeLeft.ceil()}s',
                        style: const TextStyle(
                            color: Colors.white30, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Gauge centrale ──────────────────────────────────────
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    final pulse = _holding
                        ? 0.0
                        : _pulseCtrl.value * 0.07 * _heat;
                    return CustomPaint(
                      size: const Size(270, 270),
                      painter: _HeatPainter(
                        heat: _heat,
                        pulse: pulse,
                        heatColor: heatColor,
                        surgeWarning: _inSurgeWarning ? _surgeProgress : 0,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Status text
                _buildStatusText(),

                const Spacer(),

                // ── Hold button ─────────────────────────────────────────
                _buildHoldButton(heatColor),

                const SizedBox(height: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    String text;
    Color color;
    FontWeight weight = FontWeight.w600;

    if (_inSurgeWarning) {
      text = '⚡  Picco in arrivo!';
      color = const Color(0xFFFFAB40);
      weight = FontWeight.bold;
    } else if (_holding) {
      text = _heat > 0.7 ? '✋  Tieni ancora...' : '✋  Bene, continua.';
      color = Colors.white60;
    } else if (_heat > 0.85) {
      text = '⚠️  TROPPO CALDO!';
      color = Colors.red[300]!;
      weight = FontWeight.bold;
    } else if (_heat > 0.6) {
      text = '🔥  Tieni premuto!';
      color = const Color(0xFFFF8A65);
    } else {
      text = '🔥  Tieni premuto.';
      color = Colors.white54;
    }

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 150),
      style: TextStyle(color: color, fontSize: 16, fontWeight: weight),
      child: Text(text),
    );
  }

  Widget _buildHoldButton(Color heatColor) {
    return Listener(
      onPointerDown: (_) => setState(() => _holding = true),
      onPointerUp: (_) => setState(() => _holding = false),
      onPointerCancel: (_) => setState(() => _holding = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 152,
        height: 152,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _holding
              ? heatColor.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: _holding
                ? heatColor
                : (_inSurgeWarning
                    ? const Color(0xFFFF6D00)
                    : Colors.white24),
            width: _holding ? 3.5 : (_inSurgeWarning ? 2.5 : 1.5),
          ),
          boxShadow: [
            if (_holding)
              BoxShadow(
                color: heatColor.withValues(alpha: 0.5),
                blurRadius: 32,
                spreadRadius: 6,
              ),
            if (_inSurgeWarning && !_holding)
              BoxShadow(
                color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Center(
          child: Text(
            _holding ? '✋' : (_heat > 0.8 ? '😰' : '✋'),
            style: const TextStyle(fontSize: 52),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────── Result ─────────────────────────────────────

  Widget _buildResult() {
    final tier = widget.config.tierFor(_success ? 1 : 0);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _success
              ? [const Color(0xFF0A1A0A), const Color(0xFF1B5E20)]
              : [const Color(0xFF1A0000), const Color(0xFF4A1010)],
        ),
      ),
      child: ScaleTransition(
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
                            ? [
                                const Color(0xFF1B5E20),
                                const Color(0xFF2E7D32)
                              ]
                            : [
                                const Color(0xFFB71C1C),
                                const Color(0xFFC62828)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: (_success
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFFB71C1C))
                              .withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        )
                      ],
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
      ),
    );
  }
}

// ──────────────────────────── Heat gauge painter ────────────────────────────

class _HeatPainter extends CustomPainter {
  final double heat;
  final double pulse;
  final Color heatColor;
  final double surgeWarning; // 0..1

  const _HeatPainter({
    required this.heat,
    required this.pulse,
    required this.heatColor,
    required this.surgeWarning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final r = size.width / 2 - 16;

    // ── Glow esterno ─────────────────────────────────────────────────────
    canvas.drawCircle(
      center,
      r * (0.6 + heat * 0.4 + pulse),
      Paint()
        ..color = heatColor.withValues(alpha: 0.10 + heat * 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
    );

    // ── Surge warning ring ────────────────────────────────────────────────
    if (surgeWarning > 0) {
      canvas.drawCircle(
        center,
        r + 12 + surgeWarning * 8,
        Paint()
          ..color = const Color(0xFFFF6D00).withValues(alpha: 0.5 * surgeWarning)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // ── Sfondo cerchio ────────────────────────────────────────────────────
    canvas.drawCircle(
      center, r,
      Paint()..color = Colors.white.withValues(alpha: 0.04),
    );

    // ── Arco calore ───────────────────────────────────────────────────────
    final sweep = heat * 2 * pi;
    if (sweep > 0.02) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r - 3),
        -pi / 2,
        sweep,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: -pi / 2,
            endAngle: -pi / 2 + sweep,
            colors: [
              heatColor.withValues(alpha: 0.5),
              heatColor,
              Color.lerp(heatColor, Colors.white, 0.2)!,
            ],
            stops: const [0.0, 0.7, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: r))
          ..strokeWidth = 22
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Anello outline ────────────────────────────────────────────────────
    canvas.drawCircle(
      center, r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // ── Marcatore soglia pericolo (80%) ───────────────────────────────────
    const dangerAngle = -pi / 2 + 0.80 * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r + 10),
      dangerAngle - 0.06,
      0.12,
      false,
      Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.8)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );

    // ── Inner glow (aumenta con calore) ──────────────────────────────────
    canvas.drawCircle(
      center,
      r * 0.55 * heat,
      Paint()
        ..color = heatColor.withValues(alpha: 0.25 * heat)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // ── Emoji centrale ────────────────────────────────────────────────────
    final emoji = heat > 0.75 ? '🔥' : (heat > 0.45 ? '🌡️' : '❄️');
    final fontSize = 46.0 + heat * 18;
    final tp = TextPainter(
      text: TextSpan(
          text: emoji, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_HeatPainter old) =>
      heat != old.heat ||
      heatColor != old.heatColor ||
      pulse != old.pulse ||
      surgeWarning != old.surgeWarning;
}

// ────────────────────────── Ember particle painter ──────────────────────────

class _EmberPainter extends CustomPainter {
  final List<_Ember> embers;
  final Size canvasSize;

  const _EmberPainter({required this.embers, required this.canvasSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in embers) {
      if (e.life <= 0) continue;
      final paint = Paint()
        ..color = e.color.withValues(alpha: e.life.clamp(0, 1))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, e.size * 0.6);
      canvas.drawCircle(
        Offset(e.x * size.width, e.y * size.height),
        e.size * e.life,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) => true;
}
// test
