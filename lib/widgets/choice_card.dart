import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../models/comic_data.dart';
import '../services/settings_service.dart';

/// Mostra il prompt di una `Choice` con i pulsanti per le opzioni.
/// Il parent gestisce il routing al branch corrispondente.
class ChoiceCard extends StatelessWidget {
  final Choice choice;
  final ValueChanged<ChoiceOption> onSelected;

  const ChoiceCard({
    super.key,
    required this.choice,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final prompt = choice.prompt.isNotEmpty
        ? choice.prompt
        : AppStrings.chooseYourPath;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.pinkAccent, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66FF4081),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: Colors.amberAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.chooseYourPath,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Colors.amberAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              prompt,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            ...choice.options.map((opt) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptionButton(
                  option: opt,
                  onTap: () {
                    SettingsService.tapFeedback();
                    onSelected(opt);
                  },
                ),
              );
            }),
            const SizedBox(height: 4),
            Text(
              AppStrings.branchLockedHint,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final ChoiceOption option;
  final VoidCallback onTap;

  const _OptionButton({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A1A24),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.55)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (option.hint != null && option.hint!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        option.hint!,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, color: Colors.pinkAccent),
            ],
          ),
        ),
      ),
    );
  }
}
