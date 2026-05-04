import 'package:flutter/material.dart';
import '../models/comic_data.dart';
import '../l10n/app_strings.dart';
import '../services/settings_service.dart';
import '../services/tts/tts_service.dart';
import 'comic_page_image.dart';
import 'comic_text_block_widget.dart';

class ComicPageStage extends StatefulWidget {
  final ComicIndex comicIndex;
  final ComicPage page;
  final VoidCallback? onPageCompleted;
  final int initialVisibleBlocks;
  final ValueChanged<int>? onVisibleBlocksChanged;

  const ComicPageStage({
    super.key,
    required this.comicIndex,
    required this.page,
    this.onPageCompleted,
    this.initialVisibleBlocks = 1,
    this.onVisibleBlocksChanged,
  });

  @override
  State<ComicPageStage> createState() => ComicPageStageState();
}

class ComicPageStageState extends State<ComicPageStage> {
  late int visibleBlocks;

  @override
  void initState() {
    super.initState();
    visibleBlocks = _clampInitial(widget.initialVisibleBlocks);
    if (SettingsService.ttsEnabled.value && SettingsService.ttsAutoplay.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTts();
      });
    }
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  int _clampInitial(int value) {
    final total = widget.page.panels.isEmpty
        ? 1
        : widget.page.panels.first.textBlocks.length;
    if (total <= 0) return 1;
    if (value < 1) return 1;
    if (value > total) return total;
    return value;
  }

  @override
  void didUpdateWidget(covariant ComicPageStage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.page.index != widget.page.index) {
      visibleBlocks = _clampInitial(widget.initialVisibleBlocks);
      TtsService.instance.stop();
      if (SettingsService.ttsEnabled.value &&
          SettingsService.ttsAutoplay.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startTts();
        });
      }
    }
  }

  Future<void> _startTts() async {
    if (!mounted) return;
    final panel = widget.page.panels.isEmpty ? null : widget.page.panels.first;
    if (panel == null || panel.textBlocks.isEmpty) return;
    await TtsService.instance.speakBlocks(
      panel.textBlocks,
      language: SettingsService.language.value,
      onBlockStart: (index) {
        if (!mounted) return;
        if (index + 1 > visibleBlocks) {
          setState(() {
            visibleBlocks = index + 1;
          });
          widget.onVisibleBlocksChanged?.call(visibleBlocks);
        }
      },
    );
    if (!mounted) return;
    if (visibleBlocks >= panel.textBlocks.length) {
      widget.onPageCompleted?.call();
    }
  }

  void _toggleTts() {
    SettingsService.tapFeedback();
    if (TtsService.instance.isSpeaking.value) {
      TtsService.instance.stop();
    } else {
      _startTts();
    }
  }

  bool advance() {
    final totalBlocks = widget.page.panels.first.textBlocks.length;

    if (visibleBlocks < totalBlocks) {
      setState(() {
        visibleBlocks++;
      });
      widget.onVisibleBlocksChanged?.call(visibleBlocks);
      return true;
    }

    widget.onPageCompleted?.call();
    return false;
  }

  bool goBackBlock() {
    if (visibleBlocks > 1) {
      setState(() {
        visibleBlocks--;
      });
      widget.onVisibleBlocksChanged?.call(visibleBlocks);
      return true;
    }
    return false;
  }

  void _handleTap() {
    SettingsService.tapFeedback();
    advance();
  }

  @override
  Widget build(BuildContext context) {
    final panel = widget.page.panels.first;
    final visibleTextBlocks = panel.textBlocks.take(visibleBlocks).toList();
    final totalBlocks = panel.textBlocks.length;
    final isLastBlockVisible = visibleBlocks >= totalBlocks;

    return GestureDetector(
      onTap: _handleTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ComicPageImage(
                    assetPath: widget.page.background,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color.fromARGB(170, 0, 0, 0),
                            Color.fromARGB(220, 0, 0, 0),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: visibleTextBlocks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final block = entry.value;

                          return TweenAnimationBuilder<double>(
                            key: ValueKey(
                              '${widget.page.index}_${block.id.isNotEmpty ? block.id : index}',
                            ),
                            tween: Tween(begin: 0, end: 1),
                            duration: SettingsService.textAnimationSpeed.value.duration,
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 12),
                                  child: child,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ComicTextBlockWidget(
                                comicIndex: widget.comicIndex,
                                block: block,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Text(
                    'Pagina ${widget.page.index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: List.generate(totalBlocks, (index) {
                        final isVisible = index < visibleBlocks;

                        return Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: isVisible ? Colors.white : Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: SettingsService.ttsEnabled,
                    builder: (context, enabled, _) {
                      if (!enabled) return const SizedBox.shrink();
                      return ValueListenableBuilder<bool>(
                        valueListenable: TtsService.instance.isSpeaking,
                        builder: (context, speaking, _) {
                          return IconButton(
                            tooltip: speaking
                                ? AppStrings.ttsStopTooltip
                                : AppStrings.ttsPlayTooltip,
                            icon: Icon(
                              speaking
                                  ? Icons.stop_circle_outlined
                                  : Icons.volume_up_outlined,
                              size: 22,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: _toggleTts,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isLastBlockVisible
                        ? AppStrings.tapToContinue
                        : AppStrings.tapToContinue,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
