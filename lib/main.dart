import 'package:flutter/material.dart';
import 'models/comic_data.dart';
import 'services/comic_loader.dart';
import 'widgets/comic_page_stage.dart';
import 'package:flutter/services.dart';
import 'widgets/home_cover_page.dart';
import 'widgets/episode_cover_card.dart';

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
    return FutureBuilder<ComicData>(
      future: ComicLoader.load(),
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

        final comicData = snapshot.data!;

        return HomeCoverPage(
          comicData: comicData,
        );
      },
    );
  }
}

class EpisodePage extends StatefulWidget {
  final ComicData comicData;
  final int initialEpisodeIndex;

  const EpisodePage({
    super.key,
    required this.comicData,
    required this.initialEpisodeIndex,
  });

  @override
  State<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends State<EpisodePage> {
  late final PageController _pageController;
  final FocusNode _focusNode = FocusNode();

  late int currentEpisodeIndex;
  int currentPageIndex = 0;

  Episode get currentEpisode => widget.comicData.episodes[currentEpisodeIndex];
  List<ComicPage> get currentPages => currentEpisode.pages;

  @override
  void initState() {
    super.initState();
    currentEpisodeIndex = widget.initialEpisodeIndex;
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

  void _goToNextPage() {
    if (currentPageIndex < currentPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _goToNextEpisode();
    }
  }

  void _goToPreviousPage() {
    if (currentPageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextEpisode() {
    final hasNextEpisode =
        currentEpisodeIndex < widget.comicData.episodes.length - 1;

    if (!hasNextEpisode) {
      return;
    }

    setState(() {
      currentEpisodeIndex++;
      currentPageIndex = 0;
    });

    _pageController.jumpToPage(0);
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _goToNextPage();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goToPreviousPage();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final episode = currentEpisode;
    final pages = currentPages;
    final isLastPageOfEpisode = currentPageIndex == pages.length - 1;
    final hasNextEpisode =
        currentEpisodeIndex < widget.comicData.episodes.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(episode.title),
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
                    'Pagina ${currentPageIndex + 1} / ${pages.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: pages.isEmpty
                          ? 0
                          : (currentPageIndex + 1) / pages.length,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.pinkAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() {
                    currentPageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = pages[index];

                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: ComicPageStage(
                      key: ValueKey('${currentEpisodeIndex}_${page.index}'),
                      comicData: widget.comicData,
                      page: page,
                      isLastPageOfEpisode: index == pages.length - 1,
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
                      onPressed:
                          currentPageIndex > 0 ? _goToPreviousPage : null,
                      child: const Text('Indietro'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLastPageOfEpisode
                          ? (hasNextEpisode ? _goToNextEpisode : null)
                          : _goToNextPage,
                      child: Text(
                        isLastPageOfEpisode
                            ? (hasNextEpisode ? 'Episodio successivo' : 'Fine')
                            : 'Avanti',
                      ),
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
