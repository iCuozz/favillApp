import 'package:flutter/material.dart';
import '../models/comic_data.dart';
import '../widgets/episode_cover_card.dart';
import '../main.dart';

class EpisodesListPage extends StatelessWidget {
  final ComicData comicData;

  const EpisodesListPage({
    super.key,
    required this.comicData,
  });

  @override
  Widget build(BuildContext context) {
    final episodes = comicData.episodes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Episodi'),
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
                itemCount: episodes.length,
                itemBuilder: (context, index) {
                  final episode = episodes[index];

                  return EpisodeCoverCard(
                    episode: episode,
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