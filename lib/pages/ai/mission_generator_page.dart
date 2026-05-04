import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_strings.dart';
import '../../models/comic_data.dart';
import '../../services/ai/ai_client.dart';
import '../../services/ai/ai_rate_limiter.dart';
import '../../services/ai/mission_generator_service.dart';
import '../../services/settings_service.dart';
import '../../services/tts/tts_service.dart';
import '../../widgets/mission_panel_backdrop.dart';
import 'my_missions_page.dart';

class MissionGeneratorPage extends StatefulWidget {
  const MissionGeneratorPage({super.key});

  @override
  State<MissionGeneratorPage> createState() => _MissionGeneratorPageState();
}

class _MissionGeneratorPageState extends State<MissionGeneratorPage> {
  final TextEditingController _controller = TextEditingController();
  final MissionGeneratorService _service = MissionGeneratorService.instance;

  GeneratedMission? _mission;
  bool _generating = false;
  bool _saved = false;
  String? _errorBanner;
  int _remaining = 5;

  @override
  void initState() {
    super.initState();
    _refreshQuota();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshQuota() async {
    final r = await _service.limiter.remaining();
    if (!mounted) return;
    setState(() => _remaining = r);
  }

  Future<void> _generate([String? overrideText]) async {
    if (_generating) return;
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty) return;

    if (!AiClient.instance.enabled) {
      setState(() => _errorBanner = AppStrings.askFavillaDisabled);
      return;
    }

    SettingsService.tapFeedback();
    setState(() {
      _generating = true;
      _errorBanner = null;
      _mission = null;
      _saved = false;
      if (overrideText != null) _controller.text = overrideText;
    });

    try {
      final m = await _service.generate(text);
      if (!mounted) return;
      setState(() => _mission = m);
    } on AiQuotaExceeded {
      if (!mounted) return;
      setState(() => _errorBanner = AppStrings.missionQuotaExceeded);
    } on AiException catch (e) {
      if (!mounted) return;
      String banner;
      if (e.code == 'ai_disabled') {
        banner = AppStrings.askFavillaDisabled;
      } else if (e.code == 'quota_exceeded') {
        banner = AppStrings.missionQuotaExceeded;
      } else if (e.code == 'too_short' || e.code == 'situation_too_short') {
        banner = AppStrings.missionSituationTooShort;
      } else {
        banner = AppStrings.missionError;
        assert(() {
          banner = '${AppStrings.missionError}\n[debug: ${e.code} '
              '${e.status ?? ''} ${e.message}]';
          return true;
        }());
      }
      setState(() => _errorBanner = banner);
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
      await _refreshQuota();
    }
  }

  Future<void> _save() async {
    final m = _mission;
    if (m == null || _saved) return;
    SettingsService.tapFeedback();
    await _service.save(m);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.missionSaved)),
    );
  }

  Future<void> _share() async {
    final m = _mission;
    if (m == null) return;
    SettingsService.tapFeedback();
    await Share.share(m.toShareText());
  }

  Future<void> _readAloud() async {
    final m = _mission;
    if (m == null) return;
    SettingsService.tapFeedback();
    if (TtsService.instance.isSpeaking.value) {
      await TtsService.instance.stop();
      return;
    }
    final blocks = <TextBlock>[];
    for (final p in m.panels) {
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
        title: Text(AppStrings.missionTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.missionMyCollection,
            icon: const Icon(Icons.collections_bookmark_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyMissionsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_errorBanner != null) _buildBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildIntro(),
                    const SizedBox(height: 12),
                    _buildInput(),
                    const SizedBox(height: 8),
                    _buildSuggestions(),
                    const SizedBox(height: 12),
                    _buildGenerateButton(),
                    const SizedBox(height: 8),
                    _buildQuotaText(),
                    const SizedBox(height: 16),
                    if (_generating) const _GeneratingPlaceholder(),
                    if (_mission != null) _buildMission(_mission!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: Colors.redAccent.withAlpha(40),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorBanner!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() => _errorBanner = null),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Text(
      AppStrings.missionIntro,
      style: TextStyle(color: Colors.grey.shade300, height: 1.4),
    );
  }

  Widget _buildInput() {
    final canType = !_generating && AiClient.instance.enabled;
    return TextField(
      controller: _controller,
      enabled: canType,
      minLines: 2,
      maxLines: 5,
      maxLength: 400,
      decoration: InputDecoration(
        hintText: AppStrings.missionInputHint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _service.suggestions().map((s) {
        return ActionChip(
          label: Text(s),
          onPressed: _generating ? null : () => _generate(s),
        );
      }).toList(),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
      ),
      onPressed: (_generating || !AiClient.instance.enabled)
          ? null
          : () => _generate(),
      icon: _generating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_fix_high),
      label: Text(_generating
          ? AppStrings.missionGenerating
          : AppStrings.missionGenerate),
    );
  }

  Widget _buildQuotaText() {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        AppStrings.missionQuotaLeft(_remaining),
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
    );
  }

  Widget _buildMission(GeneratedMission m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          m.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if ((m.subtitle ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            m.subtitle!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 16),
        ...List.generate(m.panels.length, (i) {
          return _MissionPanelCard(
            index: i + 1,
            total: m.panels.length,
            panel: m.panels[i],
            seed: m.id.hashCode ^ i,
          );
        }),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saved ? null : _save,
                icon: Icon(_saved ? Icons.check : Icons.bookmark_add_outlined),
                label: Text(_saved
                    ? AppStrings.missionSavedShort
                    : AppStrings.missionSave),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: SettingsService.ttsEnabled,
              builder: (context, ttsOn, _) {
                if (!ttsOn) return const SizedBox.shrink();
                return ValueListenableBuilder<bool>(
                  valueListenable: TtsService.instance.isSpeaking,
                  builder: (context, speaking, _) {
                    return IconButton.outlined(
                      tooltip: speaking
                          ? AppStrings.ttsStopTooltip
                          : AppStrings.ttsPlayTooltip,
                      onPressed: _readAloud,
                      icon: Icon(speaking
                          ? Icons.stop_circle_outlined
                          : Icons.volume_up_outlined),
                    );
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: AppStrings.share,
              onPressed: _share,
              icon: const Icon(Icons.share),
            ),
          ],
        ),
      ],
    );
  }
}

class _MissionPanelCard extends StatelessWidget {
  final int index;
  final int total;
  final GeneratedPanel panel;
  final int seed;

  const _MissionPanelCard({
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
              ...panel.textBlocks.map((b) => _MissionBlock(block: b)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionBlock extends StatelessWidget {
  final GeneratedTextBlock block;

  const _MissionBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final isNarration = block.type == 'narration';
    final isThought = block.type == 'thought';
    final speakerName = _speakerName(block.speaker);

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

class _GeneratingPlaceholder extends StatelessWidget {
  const _GeneratingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            AppStrings.missionGenerating,
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
