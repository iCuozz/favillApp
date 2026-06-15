// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import '../models/comic_data.dart';
import 'package:flutter/material.dart';

/// Minigame Costruzione — Lex's detector assembly.
///
/// Drag 3 components (clothespin, rubber band, LED) into correct positions
/// on a base blueprint. 15s total. Each correct placement counts as 1 point.
class MinigameCostruzioneScreen extends StatefulWidget {
  final MinigameConfig config;
  final void Function(Map<String, int> effects, String label, MinigameTier tier) onComplete;

  const MinigameCostruzioneScreen({
    super.key,
    required this.config,
    required this.onComplete,
  });

  @override
  State<MinigameCostruzioneScreen> createState() => _MinigameCostruzioneScreenState();
}

class _MinigameCostruzioneScreenState extends State<MinigameCostruzioneScreen> {
  static const int _totalParts = 3;
  int _partsPlaced = 0;
  bool _completed = false;

  /// Which slots are filled (index 0=clothespin, 1=rubber_band, 2=led)
  final List<bool> _slotFilled = [false, false, false];

  final List<String> _partLabels = ['Molletta', 'Elastico', 'LED'];
  final List<String> _partIcons = ['🧷', '🌀', '💡'];
  final List<String> _slotLabels = ['Base', 'Ponte', 'Sensore'];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(Duration(seconds: widget.config.durationSeconds ?? 15), () {
      if (!_completed && mounted) {
        _finishGame();
      }
    });
  }

  void _placePart(int index) {
    if (_completed || _slotFilled[index]) return;
    setState(() {
      _slotFilled[index] = true;
      _partsPlaced++;
    });
    if (_partsPlaced >= _totalParts && !_completed) {
      _completed = true;
      Future.delayed(const Duration(milliseconds: 400), _finishGame);
    }
  }

  void _finishGame() {
    if (!mounted) return;
    final tier = widget.config.tierFor(_partsPlaced);
    widget.onComplete(
      tier.statEffects,
      tier.label,
      tier,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('🔧 Costruzione Rilevatore'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header narrativo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Lex ha il progetto. Aiutalo ad assemblare il rilevatore!\nTrascina ogni componente nel suo posto.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Punteggio
            Text(
              '$_partsPlaced / $_totalParts montati',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Barra progresso
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _partsPlaced / _totalParts,
                backgroundColor: const Color(0xFF2A2A4E),
                color: const Color(0xFF4CAF50),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 32),

            // Area costruzione (slot)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2A2A4E)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '📐 Schema di Lex',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(_totalParts, (i) => _buildSlot(i)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Componenti disponibili
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_totalParts, (i) => _buildPartChip(i)),
            ),
            const SizedBox(height: 8),

            // Istruzione
            Text(
              'Tocca un componente, poi tocca lo slot dove va montato',
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(int index) {
    final filled = _slotFilled[index];
    return GestureDetector(
      onTap: filled ? null : () => _placePart(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF2E7D32) : const Color(0xFF2A2A4E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? const Color(0xFF4CAF50) : const Color(0xFF3A3A5E),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              filled ? _partIcons[index] : '⬜',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Text(
              filled ? _partLabels[index] : _slotLabels[index],
              style: TextStyle(
                color: filled ? Colors.white : Colors.white38,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartChip(int index) {
    final placed = _slotFilled[index];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: placed ? const Color(0xFF2E7D32) : const Color(0xFF0D47A1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_partIcons[index], style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            placed ? '✅' : _partLabels[index],
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
