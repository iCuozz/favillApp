import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../models/comic_data.dart';
import '../services/progress_service.dart';
import '../services/world_state_service.dart';
import '../main.dart';
import 'world_map_page.dart';
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
  static const _kPrologoSummary = _PrologoSummary();

  bool _hasProgress = false;

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
    setState(() {
      _hasProgress = progress != null;
    });
  }

  void _openWorldMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorldMapPage(comicIndex: widget.comicIndex),
      ),
    ).then((_) => _refreshProgress());
  }

  void _startPrologo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EpisodeLoaderPage(
          comicIndex: widget.comicIndex,
          summary: _kPrologoSummary,
          onEpisodeCompleted: () =>
              WorldStateService.instance.completeQuest('prologo'),
        ),
      ),
    ).then((_) => _refreshProgress());
  }

  Future<void> _continuePrologo() async {
    final progress = await ProgressService.loadCurrent();
    if (!mounted || progress == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EpisodeLoaderPage(
          comicIndex: widget.comicIndex,
          summary: _kPrologoSummary,
          initialPageIndex: progress.pageIndex,
          initialVisibleBlocks: progress.visibleBlocks,
          initialBranchId: progress.branchId,
          initialEntryBranchId: progress.entryBranchId,
          onEpisodeCompleted: () =>
              WorldStateService.instance.completeQuest('prologo'),
        ),
      ),
    ).then((_) => _refreshProgress());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: WorldStateService.instance.state,
      builder: (context, worldState, _) {
        final prologoCompleted = worldState.isQuestCompleted('prologo');

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
                  if (prologoCompleted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.pinkAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _openWorldMap,
                        icon: const Icon(Icons.map),
                        label: const Text('Esplora Nova Tutinia'),
                      ),
                    )
                  else if (_hasProgress)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.pinkAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _continuePrologo,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          AppStrings.continueLabel('Prologo'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _startPrologo,
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
      },
    );
  }
}

class _PrologoSummary extends EpisodeSummary {
  const _PrologoSummary()
      : super(
          id: 'prologo',
          title: "L'ombra della fiamma",
          subtitle: 'La doppia vita di Favilla',
          thumbnail: 'assets/episodes/prologo/thumb.webp',
          file: 'assets/data/quests/prologo.json',
        );
}
