// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';

/// Overlay a schermo intero mostrato UNA SOLA VOLTA alla prima apertura
/// di un episodio con l'HUD attivo. Spiega cosa sono le 4 stat di Favilla.
class StatsIntroOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const StatsIntroOverlay({super.key, required this.onDismiss});

  @override
  State<StatsIntroOverlay> createState() => _StatsIntroOverlayState();
}

class _StatsIntroOverlayState extends State<StatsIntroOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    OnboardingService.instance.markStatsIntroSeen();
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: GestureDetector(
        onTap: _dismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.88),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '📊 Le tue stat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ogni scelta che fai cambia Favilla.\nQueste 4 stat tengono il conto.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ..._kStatDescriptions.map((s) => _StatRow(
                        emoji: s.emoji,
                        name: s.name,
                        color: s.color,
                        desc: s.desc,
                      )),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B2B),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'Capito, andiamo!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tocca ovunque per continuare',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatInfo {
  final String emoji, name, desc;
  final Color color;
  const _StatInfo(this.emoji, this.name, this.color, this.desc);
}

const _kStatDescriptions = [
  _StatInfo('🔒', 'Segreto', Color(0xFF7C83FD),
      'Quanto il segreto dei poteri è al sicuro. Se crolla troppo, qualcuno potrebbe scoprire la verità.'),
  _StatInfo('❤️', 'Legame', Color(0xFFFF6B8A),
      'La forza del rapporto con Mallow e Lex. Influenzerà i finali di stagione.'),
  _StatInfo('⚡', 'Scintille', Color(0xFFFFD166),
      'L\'energia dei poteri di Favilla. Sotto stress si esaurisce — e lei perde il controllo.'),
  _StatInfo('😤', 'Resistenza', Color(0xFF06D6A0),
      'La capacità di reggere il caos quotidiano. Quando tocca zero, i poteri esplodono da soli.'),
];

class _StatRow extends StatelessWidget {
  final String emoji, name, desc;
  final Color color;

  const _StatRow(
      {required this.emoji,
      required this.name,
      required this.color,
      required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(desc,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
