// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/comic_data.dart';

/// Mini-game SCASSO — lockpicking a 3 pin.
///
/// Ogni pin ha un indicatore che si muove su/giù.
/// Tocca quando l'indicatore è nella zona verde per fissare il pin.
/// 3/3 pin → scasso perfetto | 2/3 → rumoroso | 0-1/3 → bloccato.
class MinigameLockpickScreen extends StatefulWidget {
  final MinigameConfig config;
  final void Function(
          Map<String, int> statEffects, String tierLabel, MinigameTier tier)
      onComplete;

  const MinigameLockpickScreen({
    super.key,
    required this.config,
    required this.onComplete,
  });

  @override
  State<MinigameLockpickScreen> createState() => _MinigameLockpickScreenState();
}

// ─── Config ──────────────────────────────────────────────────────────────────

const _kTotalPins = 3;
const _kTimerSeconds = 20;
const _kIndicatorRange = 100.0; // range verticale virtuale
const _kGreenZoneWidth = 18.0; // larghezza zona "ok"
// ─── State ───────────────────────────────────────────────────────────────────

class _MinigameLockpickScreenState extends State<MinigameLockpickScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timerCtrl;
  Timer? _moveTimer;

  final _pinPositions = <double>[50, 50, 50]; // posizione corrente di ogni pin
  final _pinSpeeds = <double>[1.0, 1.3, 0.9]; // velocità
  final _pinDirections = <int>[1, 1, 1]; // direzione: 1=su, -1=giù
  final _pinFixed = <bool>[false, false, false]; // pin già fissati
  final _greenZones = <double>[]; // centro zona verde per ogni pin (random)

  int _fixedCount = 0;
  bool _gameOver = false;
  bool _tutorialDone = false;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    for (var i = 0; i < _kTotalPins; i++) {
      _greenZones.add(20 + rng.nextDouble() * 60); // centro verde tra 20 e 80
    }
    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _kTimerSeconds),
    )..addListener(_onTimerTick);
    _timerCtrl.addStatusListener(_onTimerStatus);

    _moveTimer = Timer.periodic(const Duration(milliseconds: 16), _onTick);
    _timerCtrl.forward();
  }

  void _onTimerTick() {
    if (!_gameOver && mounted) setState(() {});
  }

  void _onTimerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_gameOver) {
      _endGame();
    }
  }

  void _onTick(Timer timer) {
    if (_gameOver) return;
    setState(() {
      for (var i = 0; i < _kTotalPins; i++) {
        if (_pinFixed[i]) continue;
        var pos = _pinPositions[i];
        pos += _pinSpeeds[i] * _pinDirections[i];
        if (pos > _kIndicatorRange) {
          pos = _kIndicatorRange;
          _pinDirections[i] = -1;
        } else if (pos < 0) {
          pos = 0;
          _pinDirections[i] = 1;
        }
        _pinPositions[i] = pos;
      }
    });
  }

  void _onPinTap(int index) {
    if (_gameOver || _pinFixed[index]) return;

    final pos = _pinPositions[index];
    final zone = _greenZones[index];
    final inGreen = (pos - zone).abs() <= _kGreenZoneWidth / 2;

    if (inGreen) {
      _pinFixed[index] = true;
      _fixedCount++;
      if (_fixedCount >= _kTotalPins) _endGame();
    }
    // Tap fuori zona: niente, l'indicatore continua a muoversi
  }

  void _endGame() {
    if (_gameOver) return;
    _gameOver = true;
    _moveTimer?.cancel();
    _timerCtrl.stop();

    final tier = _fixedCount >= 3
        ? widget.config.tierFor(3)
        : _fixedCount >= 2
            ? widget.config.tierFor(2)
            : widget.config.tierFor(1);

    widget.onComplete(tier.statEffects, tier.label, tier);
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    _timerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_tutorialDone) {
      return _buildTutorial();
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Scasso'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Timer bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _timerCtrl.value,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _timerCtrl.value > 0.5
                        ? Colors.pinkAccent
                        : Colors.redAccent,
                  ),
                ),
              ),
            ),
            Text(
              '${_fixedCount}/$_kTotalPins pin fissati',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Pin display
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_kTotalPins, (i) => _buildPinColumn(i)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tocca quando l\'indicatore è nella zona verde',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPinColumn(int index) {
    final pos = _pinPositions[index];
    final zone = _greenZones[index];
    final fixed = _pinFixed[index];
    final frac = pos / _kIndicatorRange;

    return GestureDetector(
      onTap: () => _onPinTap(index),
      child: Container(
        width: 60,
        height: 260,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: fixed ? Colors.greenAccent : Colors.white12,
            width: fixed ? 2 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            // Green zone indicator
            Positioned(
              top: (1 - (zone - _kGreenZoneWidth / 2) / _kIndicatorRange) *
                      240 +
                  10,
              left: 8,
              right: 8,
              height: (_kGreenZoneWidth / _kIndicatorRange) * 240,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Moving indicator
            Positioned(
              top: (1 - frac) * 240 + 10 - 6,
              left: 12,
              right: 12,
              height: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: fixed
                      ? Colors.greenAccent
                      : Colors.pinkAccent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: fixed
                      ? []
                      : [BoxShadow(
                          color: Colors.pinkAccent.withValues(alpha: 0.5),
                          blurRadius: 8,
                        )],
                ),
              ),
            ),
            // Pin number
            Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: fixed ? Colors.greenAccent : Colors.white38,
                  fontSize: 36,
                  fontWeight: FontWeight.w100,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorial() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '🔓 SCASSO',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.pinkAccent,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 200,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Stack(
                  clipBehavior: Clip.antiAlias,
                  children: [
                    Positioned(
                      top: 8,
                      left: 20,
                      right: 20,
                      height: 8,
                      child: Container(
                        color: Colors.greenAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    // Mini indicator that bounces
                    Positioned(
                      top: 35,
                      left: 8,
                      right: 8,
                      height: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ogni pin ha un indicatore che si muove.\n'
                'Tocca il pin quando è nella zona verde\n'
                'per fissarlo. Fissa tutti e 3 i pin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Hai ${_kTimerSeconds} secondi prima che\nl\'acqua arrivi sotto la porta.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 16),
                ),
                onPressed: () => setState(() => _tutorialDone = true),
                child: const Text('INIZIA'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
