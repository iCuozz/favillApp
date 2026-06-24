// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comic_data.dart';

/// Mini-game SFONDA — mash button per sfondare la porta.
///
/// TAP rapido per riempire la barra di progresso.
/// La soglia scala con la Resistenza: più resistenza = più facile.
class MinigameMashDoorScreen extends StatefulWidget {
  final MinigameConfig config;
  final int resistenza;
  final void Function(
          Map<String, int> statEffects, String tierLabel, MinigameTier tier)
      onComplete;

  const MinigameMashDoorScreen({
    super.key,
    required this.config,
    required this.resistenza,
    required this.onComplete,
  });

  @override
  State<MinigameMashDoorScreen> createState() => _MinigameMashDoorScreenState();
}

const _kTimerSeconds = 12;
const _kBaseThreshold = 35;

class _MinigameMashDoorScreenState extends State<MinigameMashDoorScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timerCtrl;
  int _taps = 0;
  bool _gameOver = false;
  bool _tutorialDone = false;

  int get _threshold {
    // Più resistenza = meno tap necessari
    if (widget.resistenza >= 50) return 15;
    if (widget.resistenza >= 35) return 22;
    if (widget.resistenza >= 20) return 28;
    return _kBaseThreshold;
  }

  @override
  void initState() {
    super.initState();
    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _kTimerSeconds),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _timerCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_gameOver) _endGame();
    });
    _timerCtrl.forward();
  }

  void _onTap() {
    if (_gameOver) return;
    _taps++;
    HapticFeedback.lightImpact();
    if (_taps >= _threshold) _endGame();
    setState(() {});
  }

  void _endGame() {
    if (_gameOver) return;
    _gameOver = true;
    _timerCtrl.stop();

    final ratio = _taps / _threshold;
    final tier = ratio >= 1.0
        ? widget.config.tierFor(3)
        : ratio >= 0.6
            ? widget.config.tierFor(2)
            : widget.config.tierFor(1);

    widget.onComplete(tier.statEffects, tier.label, tier);
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_tutorialDone) return _buildTutorial();
    final progress = (_taps / _threshold).clamp(0.0, 1.0);
    final remaining = _kTimerSeconds - (_timerCtrl.value * _kTimerSeconds);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Sfondare la porta'),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Timer
            Text(
              '${remaining.toInt()}s',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w100,
                color: remaining > 5 ? Colors.white70 : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 20),
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 28,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.orangeAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_taps/$_threshold colpi',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Soglia: ${widget.resistenza >= 50 ? "facile" : widget.resistenza >= 35 ? "media" : widget.resistenza >= 20 ? "dura" : "molto dura"}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 40),
            // Mash area
            GestureDetector(
              onTap: _onTap,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2A1A3A),
                  border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pan_tool_rounded,
                      size: 48,
                      color: Colors.orangeAccent.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'TAP TAP TAP!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white54,
                      ),
                    ),
                  ],
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
              const Text('🚪 SFONDA',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.orangeAccent)),
              const SizedBox(height: 24),
              Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pan_tool_rounded,
                        size: 40,
                        color: Colors.orangeAccent.withValues(alpha: 0.6)),
                    const SizedBox(height: 8),
                    Container(
                        height: 40,
                        width: 8,
                        decoration: BoxDecoration(
                            color: Colors.orangeAccent,
                            borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Tocca rapidamente per riempire la barra.\nPiù tap fai, più forza metti.\nLa tua Resistenza determina quanto è difficile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Soglia base: $_threshold tap | Tempo: ${_kTimerSeconds}s',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 16)),
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
