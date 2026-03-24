import 'package:flutter/material.dart';
import 'models/comic_data.dart';
import 'services/comic_loader.dart';
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
      home: const ComicHomePage(),
    );
  }
}

class ComicHomePage extends StatelessWidget {
  const ComicHomePage({super.key});

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
        final episodes = comicData.episodes;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Favilla Blaze'),
          ),
          body: ListView.builder(
            itemCount: episodes.length,
            itemBuilder: (context, index) {
              final episode = episodes[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: SizedBox(
                    width: 60,
                    height: 60,
                    child: Image.asset(
                      episode.thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade800,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                    ),
                  ),
                  title: Text(episode.title),
                  subtitle: Text(episode.subtitle),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EpisodePage(
                          comicData: comicData,
                          episode: episode,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
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
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final pages = widget.episode.pages;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.episode.title),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.black26,
            child: Text(
              'Pagina ${currentIndex + 1} / ${pages.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
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
    );
  }
}