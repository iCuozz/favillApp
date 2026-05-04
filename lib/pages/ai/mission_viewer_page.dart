import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_strings.dart';
import '../../models/comic_data.dart';
import '../../services/ai/mission_generator_service.dart';
import '../../services/settings_service.dart';
import '../../services/tts/tts_service.dart';
import '../../widgets/mission_panel_backdrop.dart';

/// Visualizza una missione già salvata in modalità sola lettura.
class MissionViewerPage extends StatelessWidget {
  final GeneratedMission mission;

  const MissionViewerPage({super.key, required this.mission});

  Future<void> _readAloud() async {
    if (TtsService.instance.isSpeaking.value) {
      await TtsService.instance.stop();
      return;
    }
    final blocks = <TextBlock>[];
    for (final p in mission.panels) {
      for (final b in p.textBlocks) {
        blocks.add(TextBlock(
          id: '${blocks.length}',
          type: b.type,
          speaker: b.speaker,
          text: b.text,
        ));
      }
    }
    await TtsService.instance.speakBlocks(
      blocks,
      language: SettingsService.language.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          mission.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService.ttsEnabled,
            builder: (context, ttsOn, _) {
              if (!ttsOn) return const SizedBox.shrink();
              return ValueListenableBuilder<bool>(
                valueListenable: TtsService.instance.isSpeaking,
                builder: (context, speaking, _) {
                  return IconButton(
                    tooltip: speaking
                        ? AppStrings.ttsStopTooltip
                        : AppStrings.ttsPlayTooltip,
                    icon: Icon(speaking
                        ? Icons.stop_circle_outlined
                        : Icons.volume_up_outlined),
                    onPressed: () {
                      SettingsService.tapFeedback();
                      _readAloud();
                    },
                  );
                },
              );
            },
          ),
          IconButton(
            tooltip: AppStrings.share,
            icon: const Icon(Icons.share),
            onPressed: () {
              SettingsService.tapFeedback();
              Share.share(mission.toShareText());
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((mission.subtitle ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  mission.subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            Text(
              AppStrings.missionFromSituation(mission.situation),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(mission.panels.length, (i) {
              return _MissionViewerPanel(
                index: i + 1,
                total: mission.panels.length,
                panel: mission.panels[i],
                seed: mission.id.hashCode ^ i,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MissionViewerPanel extends StatelessWidget {
  final int index;
  final int total;
  final GeneratedPanel panel;
  final int seed;

  const _MissionViewerPanel({
    required this.index,
    required this.total,
    required this.panel,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MissionPanelBackdrop(
        panel: panel,
        seed: seed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(180),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppStrings.missionPanelLabel(index, total),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...panel.textBlocks.map((b) => _ViewerBlock(block: b)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerBlock extends StatelessWidget {
  final GeneratedTextBlock block;
  const _ViewerBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final isNarration = block.type == 'narration';
    final isThought = block.type == 'thought';

    if (isNarration) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.amber.withAlpha(40),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.shade300, width: 1),
        ),
        child: Text(
          block.text,
          style: TextStyle(
            color: Colors.amber.shade100,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );
    }

    final speakerName = _speakerName(block.speaker);
    final color = _speakerColor(block.speaker);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(140)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isThought ? '$speakerName 💭' : speakerName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            block.text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
              fontStyle: isThought ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _speakerName(String id) {
    switch (id) {
      case 'favilla':
        return 'Favilla Blaze';
      case 'sparkle_ale':
        return 'Sparkle Ale';
      case 'mallow_bellow':
        return 'Mallow Bellow';
      case 'narrator':
        return '';
      default:
        return id;
    }
  }

  Color _speakerColor(String id) {
    switch (id) {
      case 'favilla':
        return Colors.pinkAccent.shade100;
      case 'sparkle_ale':
        return Colors.lightBlueAccent.shade100;
      case 'mallow_bellow':
        return Colors.tealAccent.shade100;
      default:
        return Colors.grey.shade300;
    }
  }
}
