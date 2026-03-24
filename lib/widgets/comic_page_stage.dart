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
                  height: 420,
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
                          duration: const Duration(milliseconds: 220),
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                'Pagina ${widget.page.index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                visibleBlocks < panel.textBlocks.length
                    ? 'Tocca per continuare'
                    : 'Tocca per passare alla pagina successiva',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}