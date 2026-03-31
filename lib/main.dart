import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/comic_data.dart';
import 'services/comic_loader.dart';
import 'pages/home_cover_page.dart';
import 'pages/episodes_list_page.dart';
import 'widgets/comic_page_stage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Favilla Blaze',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const AppBootstrapPage(),
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

  const EpisodeLoaderPage({
    super.key,
    required this.comicIndex,
    required this.summary,
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
        );
      },
    );
  }
}

class EpisodePage extends StatefulWidget {
  final ComicIndex comicIndex;
  final Episode episode;

  const EpisodePage({
    super.key,
    required this.comicIndex,
    required this.episode,
  });

  @override
  State<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends State<EpisodePage> {
  late final PageController _pageController;
  final FocusNode _focusNode = FocusNode();

  int currentIndex = 0;
  final Map<int, GlobalKey<ComicPageStageState>> _stageKeys = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  GlobalKey<ComicPageStageState> _keyForPage(int pageIndex) {
    return _stageKeys.putIfAbsent(
      pageIndex,
      () => GlobalKey<ComicPageStageState>(),
    );
  }

  void _goToNextEpisodeOrFinish() {
    final episodes = widget.comicIndex.episodes;
    final currentEpisodeId = widget.episode.id;

    final currentEpisodeIndex =
        episodes.indexWhere((e) => e.id == currentEpisodeId);

    if (currentEpisodeIndex == -1) {
      _showEpisodeCompletedDialog();
      return;
    }

    final hasNextEpisode = currentEpisodeIndex < episodes.length - 1;

    if (hasNextEpisode) {
      final nextSummary = episodes[currentEpisodeIndex + 1];

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
      _showEpisodeCompletedDialog();
    }
  }

  void _showEpisodeCompletedDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Missione completata'),
          content: Text(
            'Hai completato "${widget.episode.title}".',
          ),
          actions: [
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
              child: const Text('Torna agli episodi'),
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _goToNextEpisodeOrFinish();
    }
  }

  void _goToPreviousPage() {
    if (currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _advanceCurrentStageOrPage() {
    final stageKey = _keyForPage(currentIndex);
    final stageState = stageKey.currentState;

    if (stageState != null) {
      stageState.advance();
    } else {
      _goToNextPage();
    }
  }

  void _goBackBlockOrPage() {
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
                    'Pagina ${currentIndex + 1} / ${pages.length}',
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
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                  });

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _focusNode.requestFocus();
                    }
                  });
                },
                itemBuilder: (context, index) {
                  final page = pages[index];
                  final stageKey = _keyForPage(index);

                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: ComicPageStage(
                      key: stageKey,
                      comicIndex: widget.comicIndex,
                      page: page,
                      onPageCompleted: _goToNextPage,
                    ),
                  );
                },
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
