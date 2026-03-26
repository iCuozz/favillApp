import 'package:flutter/material.dart';
import 'models/comic_data.dart';
import 'services/comic_loader.dart';
import 'widgets/comic_page_stage.dart';
import 'package:flutter/services.dart';
import 'widgets/home_cover_page.dart';

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
  final Episode episode;

  const EpisodePage({
    super.key,
    required this.comicData,
    required this.episode,
  });

  @override
  State<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends State<EpisodePage> {
  late final PageController _pageController;
  final FocusNode _focusNode = FocusNode();

  int currentIndex = 0;

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

  void _goToNextPage() {
    final pages = widget.episode.pages;

    if (currentIndex < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
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
                          Colors.pinkAccent),
                    ),
                  ),
                  const SizedBox(height: 8)
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
                },
                itemBuilder: (context, index) {
                  final page = pages[index];

                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: ComicPageStage(
                      key: ValueKey(page.index),
                      comicData: widget.comicData,
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
                      onPressed: currentIndex > 0 ? _goToPreviousPage : null,
                      child: const Text('Indietro'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: currentIndex < pages.length - 1
                          ? _goToNextPage
                          : null,
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
