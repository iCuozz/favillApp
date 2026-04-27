import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'models/comic_data.dart';
import 'services/comic_loader.dart';
import 'services/engagement_service.dart';
import 'services/progress_service.dart';
import 'services/settings_service.dart';
import 'l10n/app_strings.dart';
import 'pages/home_cover_page.dart';
import 'pages/episodes_list_page.dart';
import 'widgets/comic_page_stage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: SettingsService.language,
      builder: (context, lang, _) {
        return MaterialApp(
          key: ValueKey('app-${lang.code}'),
          title: 'Favilla Blaze',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          locale: Locale(lang.code),
          supportedLocales: const [Locale('it'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppBootstrapPage(),
        );
      },
    );
  }
}

class AppBootstrapPage extends StatelessWidget {
  const AppBootstrapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ComicIndex>(
      future: ComicLoader.loadIndex(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Favilla Blaze'),
            ),
            body: Center(
              child: Text('Errore: ${snapshot.error}'),
            ),
          );
        }

        final comicIndex = snapshot.data!;

        return HomeCoverPage(
          comicIndex: comicIndex,
        );
      },
    );
  }
}

class EpisodeLoaderPage extends StatelessWidget {
  final ComicIndex comicIndex;
  final EpisodeSummary summary;
  final int initialPageIndex;
  final int initialVisibleBlocks;

  const EpisodeLoaderPage({
    super.key,
    required this.comicIndex,
    required this.summary,
    this.initialPageIndex = 0,
    this.initialVisibleBlocks = 1,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EpisodeContent>(
      future: ComicLoader.loadEpisodeContent(summary.file),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              title: Text(summary.title),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(summary.title),
            ),
            body: Center(
              child: Text('Errore: ${snapshot.error}'),
            ),
          );
        }

        final content = snapshot.data!;

        final episode = Episode(
          id: summary.id,
          title: summary.title,
          subtitle: summary.subtitle,
          thumbnail: summary.thumbnail,
          pages: content.pages,
        );

        return EpisodePage(
          comicIndex: comicIndex,
          episode: episode,
          initialPageIndex: initialPageIndex,
          initialVisibleBlocks: initialVisibleBlocks,
        );
      },
    );
  }
}

class EpisodePage extends StatefulWidget {
  final ComicIndex comicIndex;
  final Episode episode;
  final int initialPageIndex;
  final int initialVisibleBlocks;

  const EpisodePage({
    super.key,
    required this.comicIndex,
    required this.episode,
    this.initialPageIndex = 0,
    this.initialVisibleBlocks = 1,
  });

  @override
  State<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends State<EpisodePage> {
  late final PageController _pageController;
  final FocusNode _focusNode = FocusNode();

  late int currentIndex;
  late int _maxVisitedIndex;
  final Map<int, GlobalKey<ComicPageStageState>> _stageKeys = {};
  final Map<int, int> _visibleBlocksByPage = {};

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.episode.pages.isEmpty
        ? 0
        : widget.episode.pages.length - 1;
    currentIndex = widget.initialPageIndex.clamp(0, maxIndex);
    _maxVisitedIndex = currentIndex;
    _visibleBlocksByPage[currentIndex] = widget.initialVisibleBlocks;
    _pageController = PageController(initialPage: currentIndex);

    _saveProgress();
    _applyFullscreen(SettingsService.fullscreenReading.value);
    SettingsService.fullscreenReading.addListener(_onFullscreenChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _precacheNeighbors(currentIndex);
      }
    });
  }

  void _precacheNeighbors(int index) {
    final pages = widget.episode.pages;
    for (final offset in const [1, -1, 2]) {
      final neighbor = index + offset;
      if (neighbor >= 0 && neighbor < pages.length) {
        final asset = pages[neighbor].background;
        if (asset.isNotEmpty) {
          precacheImage(AssetImage(asset), context);
        }
      }
    }
  }

  void _onFullscreenChanged() {
    _applyFullscreen(SettingsService.fullscreenReading.value);
  }

  void _applyFullscreen(bool enabled) {
    if (enabled) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  @override
  void dispose() {
    SettingsService.fullscreenReading.removeListener(_onFullscreenChanged);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveProgress() {
    final blocks = _visibleBlocksByPage[currentIndex] ?? 1;
    ProgressService.saveCurrent(
      episodeId: widget.episode.id,
      pageIndex: currentIndex,
      visibleBlocks: blocks,
    );
  }

  void _handleVisibleBlocksChanged(int pageIndex, int blocks) {
    _visibleBlocksByPage[pageIndex] = blocks;
    if (pageIndex == currentIndex) {
      _saveProgress();
    }
  }

  GlobalKey<ComicPageStageState> _keyForPage(int pageIndex) {
    return _stageKeys.putIfAbsent(
      pageIndex,
      () => GlobalKey<ComicPageStageState>(),
    );
  }

  void _goToNextEpisodeOrFinish() {
    ProgressService.markCompleted(widget.episode.id);
    EngagementService.onEpisodeCompleted();

    final episodes = widget.comicIndex.episodes;
    final currentEpisodeId = widget.episode.id;

    final currentEpisodeIndex =
        episodes.indexWhere((e) => e.id == currentEpisodeId);

    if (currentEpisodeIndex == -1) {
      ProgressService.clearCurrent();
      _showEpisodeCompletedDialog();
      return;
    }

    final hasNextEpisode = currentEpisodeIndex < episodes.length - 1;

    if (hasNextEpisode) {
      final nextSummary = episodes[currentEpisodeIndex + 1];

      ProgressService.saveCurrent(
        episodeId: nextSummary.id,
        pageIndex: 0,
        visibleBlocks: 1,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EpisodeLoaderPage(
            comicIndex: widget.comicIndex,
            summary: nextSummary,
          ),
        ),
      );
    } else {
      ProgressService.clearCurrent();
      _showEpisodeCompletedDialog();
    }
  }

  void _showEpisodeCompletedDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppStrings.episodeCompletedTitle),
          content: Text(
            AppStrings.episodeCompletedBody(widget.episode.title),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                EngagementService.shareEpisode(widget.episode.title);
              },
              icon: const Icon(Icons.share, size: 18),
              label: Text(AppStrings.share),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EpisodesListPage(
                      comicIndex: widget.comicIndex,
                    ),
                  ),
                  (route) => route.isFirst,
                );
              },
              child: Text(AppStrings.backToEpisodes),
            ),
          ],
        );
      },
    );
  }

  void _goToNextPage() {
    final pages = widget.episode.pages;

    if (currentIndex < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _goToNextEpisodeOrFinish();
    }
  }

  void _goToPreviousPage() {
    if (currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _advanceCurrentStageOrPage() {
    SettingsService.tapFeedback();
    final stageKey = _keyForPage(currentIndex);
    final stageState = stageKey.currentState;

    if (stageState != null) {
      stageState.advance();
    } else {
      _goToNextPage();
    }
  }

  void _goBackBlockOrPage() {
    SettingsService.tapFeedback();
    final stageKey = _keyForPage(currentIndex);
    final stageState = stageKey.currentState;

    if (stageState != null) {
      final handled = stageState.goBackBlock();
      if (!handled) {
        _goToPreviousPage();
      }
    } else {
      _goToPreviousPage();
    }
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    const minVelocity = 250.0;
    final velocity = details.primaryVelocity ?? 0;

    if (velocity < -minVelocity) {
      _advanceCurrentStageOrPage();
    } else if (velocity > minVelocity) {
      _goBackBlockOrPage();
    }
  }

  void _openPageJumpSheet() {
    SettingsService.tapFeedback();
    final pages = widget.episode.pages;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.grid_view, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.jumpToPage,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_maxVisitedIndex + 1} / ${pages.length}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2 / 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      final isUnlocked = index <= _maxVisitedIndex;
                      final isCurrent = index == currentIndex;

                      return _PageThumb(
                        pageIndex: index,
                        background: page.background,
                        isUnlocked: isUnlocked,
                        isCurrent: isCurrent,
                        onTap: isUnlocked
                            ? () {
                                Navigator.pop(context);
                                SettingsService.tapFeedback();
                                _pageController.animateToPage(
                                  index,
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _advanceCurrentStageOrPage();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goBackBlockOrPage();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.episode.pages;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.episode.title),
        actions: [
          IconButton(
            tooltip: AppStrings.jumpToPage,
            icon: const Icon(Icons.grid_view),
            onPressed: _openPageJumpSheet,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService.hapticsEnabled,
            builder: (context, enabled, _) {
              return IconButton(
                tooltip: AppStrings.hapticsTooltip,
                icon: Icon(
                  enabled ? Icons.vibration : Icons.do_not_disturb_on_outlined,
                ),
                onPressed: () {
                  SettingsService.setHapticsEnabled(!enabled);
                  if (!enabled) {
                    HapticFeedback.selectionClick();
                  }
                },
              );
            },
          ),
          IconButton(
            tooltip: AppStrings.share,
            icon: const Icon(Icons.share),
            onPressed: () {
              SettingsService.tapFeedback();
              EngagementService.shareEpisode(widget.episode.title);
            },
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.black26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.pageOf(currentIndex + 1, pages.length),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value:
                          pages.isEmpty ? 0 : (currentIndex + 1) / pages.length,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.pinkAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: _handleHorizontalSwipe,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                    if (index > _maxVisitedIndex) {
                      _maxVisitedIndex = index;
                    }
                  });
                  _visibleBlocksByPage.putIfAbsent(index, () => 1);
                  _saveProgress();
                  _precacheNeighbors(index);

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _focusNode.requestFocus();
                    }
                  });
                },
                itemBuilder: (context, index) {
                  final page = pages[index];
                  final stageKey = _keyForPage(index);
                  final initialBlocks = _visibleBlocksByPage[index] ?? 1;

                  final stage = Padding(
                    padding: const EdgeInsets.all(12),
                    child: ComicPageStage(
                      key: stageKey,
                      comicIndex: widget.comicIndex,
                      page: page,
                      initialVisibleBlocks: initialBlocks,
                      onVisibleBlocksChanged: (blocks) =>
                          _handleVisibleBlocksChanged(index, blocks),
                      onPageCompleted: _goToNextPage,
                    ),
                  );

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double delta = 0;
                      if (_pageController.position.haveDimensions) {
                        delta = (_pageController.page ?? index.toDouble()) - index;
                      }
                      final clamped = delta.clamp(-1.0, 1.0);
                      final rotation = clamped * 0.9;
                      final scale = 1 - (clamped.abs() * 0.18);
                      final opacity = (1 - clamped.abs() * 0.7).clamp(0.0, 1.0);

                      return Transform(
                        alignment: clamped >= 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0015)
                          ..rotateY(rotation)
                          ..scaleByDouble(scale, scale, 1.0, 1.0),
                        child: Opacity(
                          opacity: opacity,
                          child: child,
                        ),
                      );
                    },
                    child: stage,
                  );
                },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _goBackBlockOrPage,
                      child: const Text('Indietro'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _advanceCurrentStageOrPage,
                      child: const Text('Avanti'),
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

class _PageThumb extends StatelessWidget {
  final int pageIndex;
  final String background;
  final bool isUnlocked;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _PageThumb({
    required this.pageIndex,
    required this.background,
    required this.isUnlocked,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(
              color: isCurrent ? Colors.pinkAccent : Colors.white12,
              width: isCurrent ? 2.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isUnlocked)
                Image.asset(
                  background,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900),
                )
              else
                Container(
                  color: Colors.grey.shade900,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock,
                    color: Colors.grey.shade600,
                    size: 28,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.black.withOpacity(0.55),
                  child: Text(
                    '${pageIndex + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
