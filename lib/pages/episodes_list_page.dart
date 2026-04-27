import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../models/comic_data.dart';
import '../services/progress_service.dart';
import '../widgets/episode_cover_card.dart';
import '../main.dart';
import 'settings_page.dart';

class EpisodesListPage extends StatefulWidget {
  final ComicIndex comicIndex;

  const EpisodesListPage({
    super.key,
    required this.comicIndex,
  });

  @override
  State<EpisodesListPage> createState() => _EpisodesListPageState();
}

class _EpisodesListPageState extends State<EpisodesListPage> {
  Set<String> _completed = <String>{};

  @override
  void initState() {
    super.initState();
    _refreshCompleted();
  }

  Future<void> _refreshCompleted() async {
    final completed = await ProgressService.loadCompleted();
    if (!mounted) return;
    setState(() {
      _completed = completed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final episodes = widget.comicIndex.episodes;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.episodesTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.settings,
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              ).then((_) => _refreshCompleted());
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Scegli il tuo episodio',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Il caos non si sconfigge da solo.',
                style: TextStyle(
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: episodes.length + 1,
                itemBuilder: (context, index) {
                  if (index == episodes.length) {
                    return const _ToBeContinuedCard();
                  }

                  final episode = episodes[index];

                  return EpisodeCoverCard(
                    episode: episode,
                    isCompleted: _completed.contains(episode.id),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EpisodeLoaderPage(
                            comicIndex: widget.comicIndex,
                            summary: episode,
                          ),
                        ),
                      ).then((_) => _refreshCompleted());
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToBeContinuedCard extends StatelessWidget {
  const _ToBeContinuedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 56,
                color: Colors.grey.shade500,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.toBeContinued,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade300,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.newEpisodesSoon,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
