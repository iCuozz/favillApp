import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../services/game_state_service.dart';

/// HUD compatto con le 4 stat RPG di Favilla, mostrato in overlay nell'episodio.
class StatsHudWidget extends StatelessWidget {
  const StatsHudWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameState>(
      valueListenable: GameStateService.instance.state,
      builder: (context, state, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatPill(
                emoji: '🔒',
                label: 'Segreto',
                value: state.segreto,
                color: const Color(0xFF7C83FD),
              ),
              const SizedBox(width: 10),
              _StatPill(
                emoji: '❤️',
                label: 'Legame',
                value: state.legame,
                color: const Color(0xFFFF6B8A),
              ),
              const SizedBox(width: 10),
              _StatPill(
                emoji: '⚡',
                label: 'Scintille',
                value: state.scintille,
                color: const Color(0xFFFFD166),
              ),
              const SizedBox(width: 10),
              _StatPill(
                emoji: '😤',
                label: 'Resistenza',
                value: state.resistenza,
                color: const Color(0xFF06D6A0),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatPill extends StatelessWidget {
  final String emoji;
  final String label;
  final int value;
  final Color color;

  const _StatPill({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label: $value/100',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          SizedBox(
            width: 36,
            height: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value / 100,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay animato che mostra temporaneamente gli effetti di una scelta sulle stat.
class StatEffectToast extends StatefulWidget {
  final Map<String, int> effects;
  final VoidCallback onDone;

  const StatEffectToast({
    super.key,
    required this.effects,
    required this.onDone,
  });

  @override
  State<StatEffectToast> createState() => _StatEffectToastState();
}

class _StatEffectToastState extends State<StatEffectToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _opacity = CurvedAnimation(
      parent: ReverseAnimation(_ctrl),
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );
    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _labels = {
    'segreto': ('🔒', 'Segreto'),
    'legame': ('❤️', 'Legame'),
    'scintille': ('⚡', 'Scintille'),
    'resistenza': ('😤', 'Resistenza'),
  };

  @override
  Widget build(BuildContext context) {
    final rows = widget.effects.entries
        .where((e) => e.value != 0)
        .map((e) {
          final info = _labels[e.key];
          if (info == null) return const SizedBox.shrink();
          final sign = e.value > 0 ? '+' : '';
          final color =
              e.value > 0 ? const Color(0xFF06D6A0) : const Color(0xFFFF6B8A);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${info.$1} ${info.$2}  $sign${e.value}',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        })
        .toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }
}
