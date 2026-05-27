import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comic_data.dart';

enum _SchivaCPhase { tutorial, countdown, attacking, feedback, result }

/// Mini-game EP3 "Schiva Lex": 3 round di tentativi, swipe nella direzione
/// corretta per schivare. Risultato in 3 tier → ride / letto / letto peggio.
class MinigameSchivaSscreen extends StatefulWidget {
  final MinigameConfig config;
  final void Function(
          Map<String, int> statEffects, String tierLabel, MinigameTier tier)
      onComplete;

  const MinigameSchivaSscreen(
      {super.key, required this.config, required this.onComplete});

  @override
  State<MinigameSchivaSscreen> createState() =>
      _MinigameSchivaSscreenState();
}

class _MinigameSchivaSscreenState extends State<MinigameSchivaSscreen>
    with TickerProviderStateMixin {
  _SchivaCPhase _phase = _SchivaCPhase.tutorial;
  int _round = 0;
  int _dodgedCount = 0;
  bool _attackFromLeft = true;
  bool _lastDodged = false;
  final List<bool> _roundResults = [];
  final _rng = Random();

  Timer? _autoFailTimer;

  late AnimationController _attackSlide;
  late AnimationController _feedbackCtrl;
  late AnimationController _resultCtrl;
  late AnimationController _timerBarCtrl;

  int get _totalRounds => widget.config.rounds ?? 3;

  @override
  void initState() {
    super.initState();
    _attackSlide = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _feedbackCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _resultCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _timerBarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
  }

  void _startNextRound() {
    if (_round >= _totalRounds) {
      _finish();
      return;
    }
    _attackFromLeft = _rng.nextBool();
    setState(() => _phase = _SchivaCPhase.countdown);

    // Breve pausa poi attacco
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _phase = _SchivaCPhase.attacking);
      _attackSlide.forward(from: 0);
      _timerBarCtrl.forward(from: 0);

      // Auto-fail se nessuno swipe entro 1.1s
      _autoFailTimer?.cancel();
      _autoFailTimer = Timer(const Duration(milliseconds: 1100), () {
        if (mounted && _phase == _SchivaCPhase.attacking) {
          _registerResult(dodged: false);
        }
      });
    });
  }

  void _onSwipe(DragEndDetails details) {
    if (_phase != _SchivaCPhase.attacking) return;
    final vx = details.velocity.pixelsPerSecond.dx;
    if (vx.abs() < 150) return;
    final swipedRight = vx > 0;
    // Schiva = allontanarsi dall'attacco
    final correctDodge =
        (_attackFromLeft && swipedRight) || (!_attackFromLeft && !swipedRight);
    _autoFailTimer?.cancel();
    _registerResult(dodged: correctDodge);
  }

  void _registerResult({required bool dodged}) {
    if (_phase != _SchivaCPhase.attacking) return;
    _lastDodged = dodged;
    _roundResults.add(dodged);
    if (dodged) {
      _dodgedCount++;
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    _feedbackCtrl.forward(from: 0);
    setState(() => _phase = _SchivaCPhase.feedback);
    _round++;

    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      _startNextRound();
    });
  }

  void _finish() {
    setState(() => _phase = _SchivaCPhase.result);
    _resultCtrl.forward();
    if (_dodgedCount == _totalRounds) HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _autoFailTimer?.cancel();
    _attackSlide.dispose();
    _feedbackCtrl.dispose();
    _resultCtrl.dispose();
    _timerBarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0B04),
      body: SafeArea(
        child: switch (_phase) {
          _SchivaCPhase.tutorial => _buildTutorial(),
          _SchivaCPhase.result => _buildResult(),
          _ => _buildGame(context),
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
            const Text('👶', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            const Text(
              'Lex vuole vedere la camicia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.3),
            ),
            const SizedBox(height: 14),
            Text(
              'Schiva i suoi $_totalRounds tentativi!\nStriscia nella direzione indicata dalla freccia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 44),
            GestureDetector(
              onTap: () {
                setState(() => _phase = _SchivaCPhase.countdown);
                Future.delayed(const Duration(milliseconds: 300), _startNextRound);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 44, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4E342E), Color(0xFF6D4C41)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6D4C41).withValues(alpha: 0.5),
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

  Widget _buildGame(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: _onSwipe,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Round dots in cima
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalRounds, (i) {
                Color dotColor;
                if (i < _roundResults.length) {
                  dotColor = _roundResults[i] ? Colors.greenAccent : Colors.redAccent;
                } else {
                  dotColor = Colors.white24;
                }
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    boxShadow: i < _roundResults.length
                        ? [
                            BoxShadow(
                                color: dotColor.withValues(alpha: 0.5),
                                blurRadius: 6)
                          ]
                        : [],
                  ),
                );
              }),
            ),
          ),
          // Timer bar (sotto i dot)
          if (_phase == _SchivaCPhase.attacking)
            Positioned(
              top: 56,
              left: 40,
              right: 40,
              child: AnimatedBuilder(
                animation: _timerBarCtrl,
                builder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: 1.0 - _timerBarCtrl.value,
                    backgroundColor: Colors.white10,
                    color: Color.lerp(
                      Colors.greenAccent,
                      Colors.redAccent,
                      _timerBarCtrl.value,
                    ),
                    minHeight: 5,
                  ),
                ),
              ),
            ),
          // Numero round
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Round ${min(_round + 1, _totalRounds)} / $_totalRounds',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ),
          // Attacco in arrivo
          if (_phase == _SchivaCPhase.attacking)
            AnimatedBuilder(
              animation: _attackSlide,
              builder: (_, __) {
                final t = Curves.easeOut.transform(_attackSlide.value);
                final screenW = MediaQuery.of(context).size.width;
                final dx = _attackFromLeft
                    ? (-screenW * 0.6) + (screenW * 0.6) * t
                    : (screenW * 0.6) - (screenW * 0.6) * t;
                return Positioned(
                  top: MediaQuery.of(context).size.height * 0.28,
                  left: _attackFromLeft ? null : null,
                  right: null,
                  child: Transform.translate(
                    offset: Offset(
                      _attackFromLeft
                          ? dx + 32
                          : screenW - 100 + dx,
                      0,
                    ),
                    child: Text(
                      _attackFromLeft ? '👋' : '🤚',
                      style: const TextStyle(fontSize: 72),
                    ),
                  ),
                );
              },
            ),
          // Freccia direzione schivata
          if (_phase == _SchivaCPhase.attacking)
            Positioned(
              bottom: 180,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _attackSlide,
                child: Column(
                  children: [
                    Text(
                      _attackFromLeft ? 'Striscia →' : '← Striscia',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _attackFromLeft
                          ? 'Lex arriva da sinistra'
                          : 'Lex arriva da destra',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          // Feedback schivato/preso
          if (_phase == _SchivaCPhase.feedback)
            Center(
              child: FadeTransition(
                opacity: CurvedAnimation(
                    parent: _feedbackCtrl, curve: Curves.easeOut),
                child: Text(
                  _lastDodged ? '✅  Schivato!' : '❌  Preso!',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: _lastDodged ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ),
            ),
          // Lex in basso
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '👶',
                style: TextStyle(
                    fontSize: _phase == _SchivaCPhase.feedback && !_lastDodged
                        ? 72
                        : 52),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final tier = widget.config.tierFor(_dodgedCount);
    final isWin = _dodgedCount == _totalRounds;

    return ScaleTransition(
      scale: CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isWin
                    ? '🏆'
                    : (_dodgedCount > 0 ? '😅' : '😱'),
                style: const TextStyle(fontSize: 84),
              ),
              const SizedBox(height: 10),
              Text(
                '$_dodgedCount/$_totalRounds schivati',
                style: const TextStyle(color: Colors.white38, fontSize: 16),
              ),
              const SizedBox(height: 10),
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
                      colors: isWin
                          ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                          : [
                              const Color(0xFF4E342E),
                              const Color(0xFF6D4C41)
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
