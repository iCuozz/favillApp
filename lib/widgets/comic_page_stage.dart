import 'package:flutter/material.dart';
import '../models/comic_data.dart';
import 'comic_page_image.dart';
import 'comic_text_block_widget.dart';

class ComicPageStage extends StatefulWidget {
  final ComicData comicData;
  final ComicPage page;
  final VoidCallback? onPageCompleted;

  const ComicPageStage({
    super.key,
    required this.comicData,
    required this.page,
    this.onPageCompleted,
  });

  @override
  State<ComicPageStage> createState() => _ComicPageStageState();
}

class _ComicPageStageState extends State<ComicPageStage> {
  int visibleBlocks = 1;

  @override
  void didUpdateWidget(covariant ComicPageStage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.page.index != widget.page.index) {
      setState(() {
        visibleBlocks = 1;
      });
    }
  }

  void _handleTap() {
    final panel = widget.page.panels.first;
    final totalBlocks = panel.textBlocks.length;

    if (visibleBlocks < totalBlocks) {
      setState(() {
        visibleBlocks++;
      });
    } else {
      widget.onPageCompleted?.call();
    }
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
            Stack(
              children: [
                ComicPageImage(
                  assetPath: widget.page.background,
                  height: 650,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color.fromARGB(150, 0, 0, 0),
                          Color.fromARGB(210, 0, 0, 0),
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
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 10),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ComicTextBlockWidget(
                              comicData: widget.comicData,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              child: Text(
                'Pagina ${widget.page.index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(totalBlocks, (index) {
                      final isVisible = index < visibleBlocks;

                      return Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: isVisible ? Colors.white : Colors.white24,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isLastBlockVisible
                        ? 'Tocca per pagina successiva'
                        : 'Tocca per proseguire',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.0,
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
