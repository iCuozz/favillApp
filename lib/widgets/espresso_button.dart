// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'package:flutter/material.dart';

/// Bottone espresso top-right per il Punto 5 coffee system.
/// Disponibile ogni 3 episodi a partire dal 3.
/// 
/// +10 resistenza / -15 scintille
class EspressoButton extends StatelessWidget {
  final int currentEpisode;
  final int? lastCaffeEpisode;
  final VoidCallback onPressed;
  final bool isAvailable;

  const EspressoButton({
    required this.currentEpisode,
    required this.lastCaffeEpisode,
    required this.onPressed,
    this.isAvailable = true,
    super.key,
  }) : super();

  /// Calcola se l'espresso è disponibile.
  /// Regola: primo uso episodio 3, poi ogni 3 episodi dopo.
  bool get _isEspressoAvailable {
    if (currentEpisode < 3) return false;
    if (lastCaffeEpisode == null) return true;
    return currentEpisode - lastCaffeEpisode! >= 3;
  }

  int get _nextAvailableEpisode {
    if (lastCaffeEpisode == null) return 3;
    return lastCaffeEpisode! + 3;
  }

  @override
  Widget build(BuildContext context) {
    final available = _isEspressoAvailable && isAvailable;

    return Tooltip(
      message: available
          ? 'Espresso (+10 res, -15 scin)'
          : 'Prossimo espresso: episodio $_nextAvailableEpisode',
      child: Opacity(
        opacity: available ? 1.0 : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: available ? onPressed : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: available
                    ? Colors.amber.shade700
                    : Colors.amber.shade200,
                borderRadius: BorderRadius.circular(12),
                boxShadow: available
                    ? [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: const Text(
                '☕',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
