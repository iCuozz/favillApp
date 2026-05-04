import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../models/comic_data.dart';
import '../services/progress_service.dart';
import '../main.dart';
import '../services/ai/ai_client.dart';
import 'ai/ai_hub_page.dart';
import 'episodes_list_page.dart';
import 'settings_page.dart';
import '../widgets/comic_title.dart';

class HomeCoverPage extends StatefulWidget {
  final ComicIndex comicIndex;

  const HomeCoverPage({
    super.key,
    required this.comicIndex,
  });

  @override
  State<HomeCoverPage> createState() => _HomeCoverPageState();
}

class _HomeCoverPageState extends State<HomeCoverPage> with WidgetsBindingObserver {
  ReadingProgress? _progress;
  EpisodeSummary? _progressEpisode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshProgress();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProgress();
    }
  }

  Future<void> _refreshProgress() async {
    final progress = await ProgressService.loadCurrent();
    if (!mounted) return;

    EpisodeSummary? episode;
    if (progress != null) {
      for (final e in widget.comicIndex.episodes) {
        if (e.id == progress.episodeId) {
          episode = e;
          break;
        }
      }
    }

    setState(() {
      _progress = progress;
      _progressEpisode = episode;
    });
  }

  void _openEpisodesList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EpisodesListPage(
          comicIndex: widget.comicIndex,
        ),
      ),
    ).then((_) => _refreshProgress());
  }

  void _continueReading() {
    final progress = _progress;
    final episode = _progressEpisode;
    if (progress == null || episode == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EpisodeLoaderPage(
          comicIndex: widget.comicIndex,
          summary: episode,
          initialPageIndex: progress.pageIndex,
          initialVisibleBlocks: progress.visibleBlocks,
        ),
      ),
    ).then((_) => _refreshProgress());
  }

  @override
  Widget build(BuildContext context) {
    final hasProgress = _progress != null && _progressEpisode != null;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2A0D1F),
                  Color(0xFF120812),
                  Color(0xFF050505),
                ],
              ),
            ),
          ),
          Image.asset(
            'assets/cover/copertina.webp',
            fit: BoxFit.contain,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      if (AiClient.instance.enabled)
                        IconButton(
                          tooltip: AppStrings.aiHubTitle,
                          icon: const Icon(Icons.auto_awesome,
                              color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AiHubPage(),
                              ),
                            );
                          },
                        ),
                      IconButton(
                        tooltip: AppStrings.settings,
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsPage(),
                            ),
                          ).then((_) => _refreshProgress());
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Spacer(),
                  const ComicTitle(
                    text: 'FAVILLA\nBLAZE',
                    fontSize: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.appTagline,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: Colors.grey.shade200,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (hasProgress) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.pinkAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _continueReading,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          AppStrings.continueLabel(_progressEpisode!.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.white54),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _openEpisodesList,
                        child: Text(AppStrings.episodesTitle),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _openEpisodesList,
                        child: Text(AppStrings.tapToStart),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 20),
                ],
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
