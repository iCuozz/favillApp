// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

// ─────────────────────────── Ripple tap ────────────────────────────────────
class _Ripple {
  double progress; // 0..1
  final Color color;
  _Ripple({required this.color}) : progress = 0;
}

// ─────────────────────────────── Widget ────────────────────────────────────

/// Mini-game EP1 "Respira": gauge del calore con surge randomici.
/// Meccanica: TAP RAPIDO per abbassare il calore (non più hold).
/// Streak bonus dopo 4 tap consecutivi entro 350ms.
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
  double _timeElapsed = 0;
  bool _success = false;
  Timer? _ticker;
  DateTime? _gameStartTime;

  // ── Tap mechanic ──────────────────────────────────────────────────────
  int _streak = 0;                         // tap consecutivi entro 350ms
  DateTime? _lastTapTime;
  final List<DateTime> _tapTimestamps = []; // finestra 1.2s per tap rate
  double _tapRate = 0;                      // tap/s
  final List<_Ripple> _ripples = [];

  // ── Rhythm beat bar (3 Hz = 333 ms period) ────────────────────────────
  // Posizione cursore 0..1 calcolata real-time da _gameStartTime
  double _beatCursor = 0.0;
  bool _lastTapWasOnBeat = false;
  static const _kBeatPeriodMs = 333.0;     // periodo beat in ms
  static const _kRhythmBonus = 0.020;      // extra cooling on-beat
  static const _kBeatSweetLo = 0.40;
  static const _kBeatSweetHi = 0.60;

  // ── Surge system ──────────────────────────────────────────────────────
  double _nextSurgeIn = 2.0;
  double _surgeProgress = 0.0;
  bool _inSurgeWarning = false;
  static const _kSurgeWarnDuration = 0.8;

  // ── Shake ─────────────────────────────────────────────────────────────
  final _rng = Random();
  double _shakeX = 0;
  double _shakeY = 0;

  // ── Ember particles ───────────────────────────────────────────────────
  final List<_Ember> _embers = [];

  // ── Parametri difficoltà ──────────────────────────────────────────────
  static const _kRiseRate = 0.148;       // calore passivo per secondo
  static const _kTapCool = 0.036;        // raffreddamento per singolo tap
  static const _kStreakBonus = 0.015;    // bonus per tap quando streak >= 4
  static const _kStreakMin = 4;          // soglia streak
  static const _kMinTapMs = 60;          // anti-spam (ignora tap < 60ms)
  static const _kStartHeat = 0.52;
  static const _kTickMs = 40;            // 25 fps

  late AnimationController _pulseCtrl;
  late AnimationController _resultCtrl;
  late AnimationController _surgeWarnCtrl;
  late AnimationController _tapBounceCtrl;
  late AnimationController _streakBurstCtrl;
  late AnimationController _tutorialDemoCtrl;
  int _prevStreak = 0; // per rilevare nuovo raggiungimento streak

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
    _tapBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _streakBurstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tutorialDemoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _loadTutorialPref();
  }

  Future<void> _loadTutorialPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _phase != _RespiraPhase.tutorial) return;
    if (prefs.getBool('tut_respira') ?? false) _startGame();
  }

  void _startGame() {
    SharedPreferences.getInstance()
        .then((p) => p.setBool('tut_respira', true));
    final duration = (widget.config.durationSeconds ?? 14).toDouble();
    setState(() {
      _phase = _RespiraPhase.playing;
      _heat = _kStartHeat;
      _timeLeft = duration;
      _timeElapsed = 0;
      _streak = 0;
      _prevStreak = 0;
      _lastTapTime = null;
      _tapTimestamps.clear();
      _tapRate = 0;
      _ripples.clear();
      _nextSurgeIn = 1.8 + _rng.nextDouble() * 1.5;
      _inSurgeWarning = false;
      _surgeProgress = 0;
      _beatCursor = 0.0;
      _lastTapWasOnBeat = false;
    });
    _gameStartTime = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: _kTickMs), _tick);
  }

  /// Chiamato ad ogni tap sul bottone.
  void _onTap() {
    if (_phase != _RespiraPhase.playing) return;
    final now = DateTime.now();

    // Anti-spam: scarta tap troppo ravvicinati
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < _kMinTapMs) { return; }

    // Aggiorna streak
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 350) {
      _streak++;
    } else {
      _streak = 1;
    }
    _lastTapTime = now;

    // Trigger burst animation quando si raggiunge la soglia streak
    if (_streak >= _kStreakMin && _prevStreak < _kStreakMin) {
      _streakBurstCtrl.forward(from: 0);
    }
    _prevStreak = _streak;

    // Calcola tap rate su finestra 1.2s
    _tapTimestamps.add(now);
    _tapTimestamps.removeWhere(
        (t) => now.difference(t).inMilliseconds > 1200);
    _tapRate = _tapTimestamps.length / 1.2;

    // Determina se tap è on-beat (sweet spot del beat bar)
    _lastTapWasOnBeat = _beatCursor >= _kBeatSweetLo && _beatCursor <= _kBeatSweetHi;

    // Raffreddamento: base + streak bonus + rhythm bonus
    final cool = _kTapCool
        + (_streak >= _kStreakMin ? _kStreakBonus : 0.0)
        + (_lastTapWasOnBeat ? _kRhythmBonus : 0.0);

    // Colore ripple: azzurro se in streak + on-beat, viola streak, bianco altrimenti
    final Color rippleColor;
    if (_lastTapWasOnBeat && _streak >= _kStreakMin) {
      rippleColor = const Color(0xFF40FFD0); // verde acqua
    } else if (_streak >= _kStreakMin) {
      rippleColor = const Color(0xFF80D8FF); // azzurro streak
    } else {
      rippleColor = const Color(0xFF9C8FFF); // viola base
    }

    HapticFeedback.lightImpact();
    _tapBounceCtrl.forward(from: 0);

    setState(() {
      _heat = (_heat - cool).clamp(0.0, 1.0);
      _ripples.add(_Ripple(color: rippleColor));
    });
  }

  void _tick(Timer _) {
    if (_phase != _RespiraPhase.playing) return;
    const dt = _kTickMs / 1000.0;
    final duration = (widget.config.durationSeconds ?? 14).toDouble();

    // Aggiorna beat cursor real-time (anti-drift)
    final elapsedMs = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inMilliseconds.toDouble()
        : 0.0;
    final newBeatCursor = (elapsedMs % _kBeatPeriodMs) / _kBeatPeriodMs;

    setState(() {
      _beatCursor = newBeatCursor;

      // Calore passivo
      _heat = (_heat + _kRiseRate * dt).clamp(0.0, 1.0);
      _timeLeft -= dt;
      _timeElapsed += dt;

      // Avanza ripple
      for (final r in _ripples) { r.progress += dt / 0.55; }
      _ripples.removeWhere((r) => r.progress >= 1.0);

      // Surge countdown — intervallo diminuisce nel tempo (escalation)
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
          final spike = 0.14 + _rng.nextDouble() * 0.14;
          _heat = (_heat + spike).clamp(0.0, 1.0);
          HapticFeedback.heavyImpact();
          _inSurgeWarning = false;
          _surgeProgress = 0;
          // Surge più frequenti col passare del tempo (da ~4s a ~0.8s)
          final baseInterval = 2.5 + _rng.nextDouble() * 1.5;
          final escalation = (_timeElapsed / duration) * 1.8;
          _nextSurgeIn = (baseInterval - escalation).clamp(0.8, 4.0);
        }
      }

      // Shake ad alta temperatura
      if (_heat > 0.72) {
        final intensity = (_heat - 0.72) / 0.28 * 6;
        _shakeX = (_rng.nextDouble() - 0.5) * intensity;
        _shakeY = (_rng.nextDouble() - 0.5) * intensity;
      } else {
        _shakeX = 0;
        _shakeY = 0;
      }

      _updateEmbers(dt);

      if (_heat >= 1.0) {
        _endGame(false);
      } else if (_timeLeft <= 0) {
        _endGame(true);
      }
    });
  }

  void _updateEmbers(double dt) {
    _embers.removeWhere((e) => e.life <= 0);
    for (final e in _embers) {
      e.y += e.vy * dt;
      e.x += e.vx * dt;
      e.life -= e.decay * dt;
    }
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
    HapticFeedback.heavyImpact();
    if (success) HapticFeedback.mediumImpact();
    setState(() => _phase = _RespiraPhase.result);
    _resultCtrl.forward();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseCtrl.dispose();
    _resultCtrl.dispose();
    _surgeWarnCtrl.dispose();
    _tapBounceCtrl.dispose();
    _streakBurstCtrl.dispose();
    _tutorialDemoCtrl.dispose();
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          children: [
            // ── Header narrativo ──────────────────────────────────────
            const Text('🔥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text(
              'Le mani si scaldano.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.3),
            ),
            const SizedBox(height: 6),
            const Text(
              'Senti il bruciore salire lungo le dita.\nDevi controllarlo prima che divampi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white38, fontSize: 14, height: 1.6),
            ),

            const SizedBox(height: 28),

            // ── Demo animata ──────────────────────────────────────────
            AnimatedBuilder(
              animation: _tutorialDemoCtrl,
              builder: (_, __) {
                final t = _tutorialDemoCtrl.value;
                // Ring 1: espande su tutto il ciclo
                final r1Scale = 0.45 + t * 1.1;
                final r1Alpha = (1.0 - t) * 0.75;
                // Ring 2: staccata di mezzo ciclo
                final t2 = (t + 0.5) % 1.0;
                final r2Scale = 0.45 + t2 * 1.1;
                final r2Alpha = (1.0 - t2) * 0.75;
                // Tap icon: bounce rapido all'inizio
                final iconScale = t < 0.18
                    ? (1.0 - 0.22 * sin(t / 0.18 * pi))
                    : 1.0;
                return SizedBox(
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ring 1 viola
                      Transform.scale(
                        scale: r1Scale,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF9C8FFF)
                                  .withValues(alpha: r1Alpha),
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                      // Ring 2 azzurro (streak)
                      Transform.scale(
                        scale: r2Scale,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF80D8FF)
                                  .withValues(alpha: r2Alpha),
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                      // Icona dito che batte
                      Transform.scale(
                        scale: iconScale,
                        child: const Text('👆',
                            style: TextStyle(fontSize: 46)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Text(
              'TAP  VELOCE',
              style: TextStyle(
                  color: Colors.white30,
                  fontSize: 11,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 20),

            // ── Regole ────────────────────────────────────────────────
            _ruleCard('💨', 'Tappa veloce',
                'Ogni tap raffredda il calore. Più veloce, meglio è.'),
            const SizedBox(height: 10),
            _ruleCard('⚡', 'Picchi improvvisi',
                'Un avviso ti avverte un attimo prima. Non fermarti.'),
            const SizedBox(height: 10),
            _ruleCard('❄️', 'Streak ×4',
                'Quattro tap ravvicinati: bonus raffreddamento extra.'),
            const SizedBox(height: 10),
            _ruleCard('⏱', '14 secondi',
                'Tieni il calore sotto controllo fino alla fine.'),

            const SizedBox(height: 36),

            // ── Start button ──────────────────────────────────────────
            GestureDetector(
              onTap: _startGame,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 52, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFFC62828)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFFC62828).withValues(alpha: 0.35),
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Card regola con icona, titolo e descrizione.
  Widget _ruleCard(String icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(desc,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.4)),
              ],
            ),
          ),
        ],
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
    final duration = (widget.config.durationSeconds ?? 14).toDouble();
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
                    final pulse = _pulseCtrl.value * 0.07 * _heat;
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

                // ── Tap button + ripple + tap rate ──────────────────────
                _buildTapButton(heatColor),

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
    } else if (_heat > 0.85) {
      text = '😱  TROPPO CALDO!';
      color = Colors.red[300]!;
      weight = FontWeight.bold;
    } else if (_lastTapWasOnBeat && _streak >= _kStreakMin && _tapRate >= 4) {
      text = '🎵  On beat! (+doppio bonus)';
      color = const Color(0xFF40FFD0);
      weight = FontWeight.bold;
    } else if (_streak >= _kStreakMin && _tapRate >= 4) {
      text = '❄️  In ritmo! (+bonus)';
      color = const Color(0xFF80D8FF);
      weight = FontWeight.bold;
    } else if (_tapRate >= 4) {
      text = '💨  Bene, continua!';
      color = Colors.white70;
    } else if (_tapRate >= 2) {
      text = '🔥  Più veloce!';
      color = const Color(0xFFFF8A65);
    } else {
      text = '⚡  TAP! TAP! TAP!';
      color = Colors.redAccent[100]!;
      weight = FontWeight.bold;
    }

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 150),
      style: TextStyle(color: color, fontSize: 16, fontWeight: weight),
      child: Text(text),
    );
  }

  Widget _buildTapButton(Color heatColor) {
    final inStreak = _streak >= _kStreakMin;
    const streakColor = Color(0xFF80D8FF);
    final inSweetSpot = _beatCursor >= _kBeatSweetLo && _beatCursor <= _kBeatSweetHi;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Streak burst banner ───────────────────────────────────────────
        AnimatedBuilder(
          animation: _streakBurstCtrl,
          builder: (_, __) {
            final t = _streakBurstCtrl.value;
            final alpha = t < 0.3 ? t / 0.3 : 1.0 - (t - 0.3) / 0.7;
            final scale = 0.7 + t * 0.5;
            if (t == 0 && !inStreak) return const SizedBox(height: 28);
            return SizedBox(
              height: 28,
              child: Opacity(
                opacity: alpha.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Text(
                    '❄️  STREAK ×$_streak',
                    style: const TextStyle(
                      color: Color(0xFF80D8FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Ripple rings ──────────────────────────────────────────
              ..._ripples.map((r) {
                final scale = 0.55 + r.progress * 0.9;
                final alpha = (1.0 - r.progress).clamp(0.0, 1.0);
                return IgnorePointer(
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: r.color.withValues(alpha: alpha * 0.75),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // ── Streak outer glow ─────────────────────────────────────
              if (inStreak)
                IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: streakColor.withValues(alpha: 0.30),
                          blurRadius: 28,
                          spreadRadius: 6,
                        )
                      ],
                    ),
                  ),
                ),

              // ── On-beat glow ──────────────────────────────────────────
              if (inSweetSpot)
                IgnorePointer(
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF40FFD0).withValues(alpha: 0.22),
                          blurRadius: 32,
                          spreadRadius: 8,
                        )
                      ],
                    ),
                  ),
                ),

              // ── Bottone tap ───────────────────────────────────────────
              AnimatedBuilder(
                animation: _tapBounceCtrl,
                builder: (_, __) {
                  final t = _tapBounceCtrl.value;
                  final scale = 1.0 - 0.14 * sin(t * pi);
                  return Transform.scale(
                    scale: scale,
                    child: GestureDetector(
                      onTap: _onTap,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        width: 162,
                        height: 162,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: inStreak
                              ? streakColor.withValues(alpha: 0.18)
                              : heatColor.withValues(alpha: 0.08),
                          border: Border.all(
                            color: inSweetSpot
                                ? const Color(0xFF40FFD0)
                                : (inStreak
                                    ? streakColor
                                    : (_inSurgeWarning
                                        ? const Color(0xFFFF6D00)
                                        : Colors.white30)),
                            width: inSweetSpot ? 3.5 : (inStreak ? 3.0 : (_inSurgeWarning ? 2.5 : 1.8)),
                          ),
                          boxShadow: [
                            if (_inSurgeWarning && !inStreak)
                              BoxShadow(
                                color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _heat > 0.8 ? '😰' : (inStreak ? '❄️' : '💨'),
                            style: const TextStyle(fontSize: 56),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // ── Beat bar ──────────────────────────────────────────────────────
        const SizedBox(height: 8),
        _buildBeatBar(inSweetSpot),

        // ── Tap rate indicator ────────────────────────────────────────────
        const SizedBox(height: 8),
        Text(
          _tapRate > 0
              ? '${_tapRate.toStringAsFixed(1)} tap/s'
                  '${_streak >= _kStreakMin ? "  🔥×$_streak" : ""}'
              : 'tap veloce!',
          style: TextStyle(
            color: _streak >= _kStreakMin
                ? const Color(0xFF80D8FF)
                : Colors.white30,
            fontSize: 13,
            fontWeight: _streak >= _kStreakMin
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Beat bar: indica il ritmo ottimale per il bonus on-beat.
  Widget _buildBeatBar(bool inSweetSpot) {
    const barW = 160.0;
    const barH = 10.0;
    final cursorX = _beatCursor * barW;
    const sweetStart = _kBeatSweetLo * barW;
    const sweetEnd = _kBeatSweetHi * barW;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: barW,
          height: barH + 16,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Barra di sfondo
              Positioned(
                top: 8,
                left: 0,
                child: Container(
                  width: barW,
                  height: barH,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              // Zona sweet spot (verde)
              Positioned(
                top: 8,
                left: sweetStart,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: sweetEnd - sweetStart,
                  height: barH,
                  decoration: BoxDecoration(
                    color: inSweetSpot
                        ? const Color(0xFF40FFD0).withValues(alpha: 0.55)
                        : const Color(0xFF40FFD0).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: inSweetSpot
                        ? [
                            BoxShadow(
                              color: const Color(0xFF40FFD0).withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                  ),
                ),
              ),
              // Cursore
              Positioned(
                top: 2,
                left: (cursorX - 11).clamp(0.0, barW - 22),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: inSweetSpot
                        ? const Color(0xFF40FFD0)
                        : Colors.white.withValues(alpha: 0.7),
                    boxShadow: [
                      BoxShadow(
                        color: (inSweetSpot
                                ? const Color(0xFF40FFD0)
                                : Colors.white)
                            .withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: inSweetSpot ? 3 : 0,
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          inSweetSpot ? '✦ ON BEAT' : 'batti sul verde',
          style: TextStyle(
            color: inSweetSpot
                ? const Color(0xFF40FFD0)
                : Colors.white24,
            fontSize: 10,
            letterSpacing: 1.8,
            fontWeight: inSweetSpot ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
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
