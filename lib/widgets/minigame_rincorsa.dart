// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/comic_data.dart';

/// Mini-game RINCORSA — insegui il ladro nel boschetto.
///
/// Il giocatore tappa rapidamente per chiudere la distanza.
/// Il ladro avanza automaticamente nel tempo.
/// Score: 2 = presa, 1 = quasi, 0 = perso / trasformazione.
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

class _MinigameRincorsaScreenState extends State<MinigameRincorsaScreen>
    with SingleTickerProviderStateMixin {
  // gap: 0.0 = caught, 1.0 = lost
  static const double _initialGap = 0.80;
  static const double _thiefSpeedPerSecond = 0.018;
  static const double _playerSpeedPerTap = 0.028;

  double _gap = _initialGap;
  int _secondsLeft = 0;
  bool _finished = false;

  Timer? _ticker;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.config.durationSeconds ?? 15;

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    _ticker = Timer.periodic(const Duration(milliseconds: 100), _tick);
  }

  void _tick(Timer t) {
    if (_finished) return;
    setState(() {
      // Thief advances 1/10th of per-second value every 100ms
      _gap = (_gap + _thiefSpeedPerSecond / 10).clamp(0.0, 1.0);
      if (t.tick % 10 == 0) {
        _secondsLeft = (_secondsLeft - 1).clamp(0, 999);
        if (_secondsLeft <= 0) _finish();
      }
    });
  }

  void _onTap() {
    if (_finished) return;
    setState(() {
      _gap = (_gap - _playerSpeedPerTap).clamp(0.0, 1.0);
      if (_gap <= 0.0) _finish();
    });
    _shakeController.forward(from: 0);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();

    // score: 2 = gap ≤ 0.30, 1 = gap ≤ 0.65, 0 = gap > 0.65
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
    _ticker?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - _gap; // 0 = start, 1 = caught
    final timeProgress = _secondsLeft / (widget.config.durationSeconds ?? 15);
    final isClosing = _gap <= 0.45;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (_) => _onTap(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // Background forest texture hint
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0D1F0D), Color(0xFF1A1A1A)],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    // Title
                    Text(
                      'RINCORRILO!',
                      style: TextStyle(
                        fontFamily: 'Bangers',
                        fontSize: 36,
                        color: isClosing
                            ? const Color(0xFFFFD700)
                            : Colors.white,
                        letterSpacing: 4,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TAPPA VELOCEMENTE',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Timer bar
                    _TimerBar(progress: timeProgress),

                    const SizedBox(height: 8),
                    Text(
                      '$_secondsLeft s',
                      style: TextStyle(
                        color: _secondsLeft <= 5
                            ? Colors.red
                            : Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Chase track
                    _ChaseTrack(
                      progress: progress,
                      shake: _shakeAnim,
                    ),

                    const SizedBox(height: 32),

                    // Distance label
                    Text(
                      _distanceLabel(_gap),
                      style: TextStyle(
                        fontSize: 16,
                        color: isClosing
                            ? const Color(0xFFFFD700)
                            : Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),

                    const Spacer(),

                    // Big tap area
                    AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (ctx, child) => Transform.translate(
                        offset: Offset(_shakeAnim.value, 0),
                        child: child,
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isClosing
                              ? const Color(0xFFFFD700).withOpacity(0.15)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isClosing
                                ? const Color(0xFFFFD700).withOpacity(0.6)
                                : Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '👟  TAP  👟',
                            style: TextStyle(
                              fontSize: 28,
                              color: isClosing
                                  ? const Color(0xFFFFD700)
                                  : Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _distanceLabel(double gap) {
    if (gap <= 0.15) return 'CI SEI QUASI!';
    if (gap <= 0.35) return 'Lo stai raggiungendo...';
    if (gap <= 0.55) return 'Continua a correre!';
    if (gap <= 0.75) return 'È veloce. Non mollare.';
    return 'Si sta allontanando!';
  }
}

class _TimerBar extends StatelessWidget {
  final double progress;
  const _TimerBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final color = progress > 0.5
        ? Colors.greenAccent
        : progress > 0.25
            ? Colors.orange
            : Colors.red;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        backgroundColor: Colors.white.withOpacity(0.1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _ChaseTrack extends StatelessWidget {
  final double progress; // 0 = start, 1 = caught
  final Animation<double> shake;

  const _ChaseTrack({required this.progress, required this.shake});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final trackW = constraints.maxWidth;
      const iconSize = 36.0;

      // Favilla position: starts left, moves right as progress increases
      final favillaX = progress * (trackW - iconSize * 2);
      // Thief is always slightly ahead
      final thiefX = (favillaX + iconSize * 1.6).clamp(0.0, trackW - iconSize);

      return SizedBox(
        height: 60,
        child: Stack(
          children: [
            // Track line
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Thief icon
            Positioned(
              left: thiefX,
              top: 12,
              child: const Text('🏃', style: TextStyle(fontSize: 32)),
            ),
            // Favilla icon (shakes on tap)
            AnimatedBuilder(
              animation: shake,
              builder: (ctx, child) => Positioned(
                left: favillaX,
                top: 10 - shake.value / 3,
                child: child!,
              ),
              child: const Text('⚡', style: TextStyle(fontSize: 36)),
            ),
          ],
        ),
      );
    });
  }
}
