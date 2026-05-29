// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_state.dart';
import '../models/world_map.dart';
import '../services/game_state_service.dart';
import '../services/progress_service.dart';
import '../services/world_state_service.dart';
import '../widgets/stats_hud_widget.dart';
import '../widgets/comic_title.dart';
import '../widgets/nova_tutinia_map_painter.dart';
import '../main.dart';
import '../models/comic_data.dart';

class WorldMapPage extends StatefulWidget {
  final ComicIndex comicIndex;

  const WorldMapPage({super.key, required this.comicIndex});

  @override
  State<WorldMapPage> createState() => _WorldMapPageState();
}

class _WorldMapPageState extends State<WorldMapPage>
    with TickerProviderStateMixin {
  WorldMap? _worldMap;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _loadWorldMap();
  }

  Future<void> _loadWorldMap() async {
    try {
      final raw = await rootBundle.loadString('assets/data/world_map.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _worldMap = WorldMap.fromJson(json));
    } catch (e, st) {
      debugPrint('❌ _loadWorldMap failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onLocationTap(WorldLocation loc) {
    final worldState = WorldStateService.instance.state.value;
    if (!worldState.isLocationUnlocked(loc)) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LocationSheet(
        location: loc,
        comicIndex: widget.comicIndex,
        worldMap: _worldMap!,
      ),
    );
  }

  void _openDevEpisodePicker() {
    // Lista statica di tutti gli episodi disponibili nel progetto
    const episodes = [
      (id: 'prologo',            title: 'Prologo',                    file: 'assets/data/quests/prologo.json'),
      (id: 's1_mattina_dopo',    title: 'EP1 · Mattina dopo',         file: 'assets/data/quests/s1/s1_mattina_dopo.json'),
      (id: 's1_scuola_1',        title: 'EP2 · La Corvi',             file: 'assets/data/quests/s1/s1_scuola_1.json'),
      (id: 's1_ritorno_casa',    title: 'EP3 · Ritorno a casa',       file: 'assets/data/quests/s1/s1_ritorno_casa.json'),
      (id: 's1_spesa_sabato',    title: 'EP4 · La Spesa del Sabato',  file: 'assets/data/quests/s1/s1_spesa_sabato.json'),
      (id: 's1_domenica_parco',  title: 'EP5 · La Domenica al Parco', file: 'assets/data/quests/s1/s1_domenica_parco.json'),
      (id: 's1_mare',            title: 'EP6 · Un Giorno al Mare',    file: 'assets/data/quests/s1/s1_mare.json'),
      (id: 's1_centro_commerciale', title: 'EP6alt · GalaxiaMall',     file: 'assets/data/quests/s1/s1_centro_commerciale.json'),
      (id: 's1_lunedi_asilo',      title: 'EP7 · Lunedì all\'Asilo',   file: 'assets/data/quests/s1/s1_lunedi_asilo.json'),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.developer_mode, color: Colors.pinkAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Dev — Salta a episodio',
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                ...episodes.map((ep) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_circle_outline, color: Colors.pinkAccent),
                  title: Text(ep.title,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    final summary = EpisodeSummary(
                      id: ep.id,
                      title: ep.title,
                      subtitle: '',
                      thumbnail: '',
                      file: ep.file,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuestLoaderPage(
                          comicIndex: widget.comicIndex,
                          summary: summary,
                          questId: ep.id,
                          worldMap: _worldMap!,
                        ),
                      ),
                    );
                  },
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: kDebugMode
          ? FloatingActionButton.small(
              heroTag: 'dev-picker',
              backgroundColor: Colors.black54,
              foregroundColor: Colors.pinkAccent,
              tooltip: 'Dev: salta episodio',
              onPressed: _worldMap != null ? _openDevEpisodePicker : null,
              child: const Icon(Icons.developer_mode, size: 18),
            )
          : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Sfondo mappa di Nova Tutinia
          CustomPaint(
            painter: const NovaTutiniaMapPainter(),
            child: Container(),
          ),
          // Location nodes
          if (_worldMap != null)
            ValueListenableBuilder<WorldState>(
              valueListenable: WorldStateService.instance.state,
              builder: (context, worldState, _) {
                return ValueListenableBuilder<GameState>(
                  valueListenable: GameStateService.instance.state,
                  builder: (context, gameState, _) {
                    return LayoutBuilder(builder: (context, constraints) {
                      return Stack(
                        children: [
                          // Nodi location
                          for (final loc in _worldMap!.locations)
                            _LocationNode(
                              location: loc,
                              isUnlocked: worldState.isLocationUnlocked(loc),
                              hasActiveQuest: loc.quests.any(
                                (q) => !worldState.isQuestCompleted(q.id) &&
                                    worldState.isQuestAvailable(
                                        q, gameState.toMap()),
                              ),
                              pulseAnim: _pulseCtrl,
                              canvasSize: Size(constraints.maxWidth,
                                  constraints.maxHeight),
                              onTap: () => _onLocationTap(loc),
                            ),
                        ],
                      );
                    });
                  },
                );
              },
            ),
          // Overlay superiore: titolo + HUD
          const SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ComicTitle(
                          text: 'NOVA TUTINIA',
                          fontSize: 22,
                        ),
                      ),
                      StatsHudWidget(),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SeasonLabel(),
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

// ─── Nodo location ────────────────────────────────────────────────────────────

class _LocationNode extends StatelessWidget {
  final WorldLocation location;
  final bool isUnlocked;
  final bool hasActiveQuest;
  final AnimationController pulseAnim;
  final Size canvasSize;
  final VoidCallback onTap;

  const _LocationNode({
    required this.location,
    required this.isUnlocked,
    required this.hasActiveQuest,
    required this.pulseAnim,
    required this.canvasSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final x = location.position.dx * canvasSize.width;
    final y = location.position.dy * canvasSize.height;

    return Positioned(
      left: x - 40,
      top: y - 40,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Alone pulsante per quest attive
              if (isUnlocked && hasActiveQuest)
                AnimatedBuilder(
                  animation: pulseAnim,
                  builder: (_, __) => Container(
                    width: 70 + pulseAnim.value * 14,
                    height: 70 + pulseAnim.value * 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.pinkAccent
                          .withValues(alpha: 0.15 + pulseAnim.value * 0.1),
                    ),
                  ),
                ),
              // Cerchio principale
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnlocked
                      ? const Color(0xFF2A1A3A)
                      : const Color(0xFF1A1A1A),
                  border: Border.all(
                    color: isUnlocked
                        ? (hasActiveQuest
                            ? Colors.pinkAccent
                            : Colors.white24)
                        : Colors.white10,
                    width: isUnlocked && hasActiveQuest ? 2.5 : 1.5,
                  ),
                  boxShadow: isUnlocked && hasActiveQuest
                      ? [
                          const BoxShadow(
                            color: Color(0x55FF4081),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: isUnlocked
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(location.emoji,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(height: 2),
                            Text(
                              location.name,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : const Text('?',
                          style: TextStyle(
                              fontSize: 22, color: Colors.white24)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sheet location ───────────────────────────────────────────────────────────

class _LocationSheet extends StatefulWidget {
  final WorldLocation location;
  final ComicIndex comicIndex;
  final WorldMap worldMap;

  const _LocationSheet({
    required this.location,
    required this.comicIndex,
    required this.worldMap,
  });

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  String? _currentEpisodeId;

  @override
  void initState() {
    super.initState();
    ProgressService.loadCurrent().then((p) {
      if (!mounted) return;
      setState(() => _currentEpisodeId = p?.episodeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorldState>(
      valueListenable: WorldStateService.instance.state,
      builder: (context, worldState, _) {
        return ValueListenableBuilder<GameState>(
          valueListenable: GameStateService.instance.state,
          builder: (context, gameState, _) {
            final quests = widget.location.quests;

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                    top: BorderSide(color: Colors.white12)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header
                  Row(
                    children: [
                      Text(widget.location.emoji,
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.location.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              widget.location.description,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Quest list
                  if (quests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Nessuna missione disponibile per ora. Torna presto.',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ...quests.map((q) {
                      final available = worldState.isQuestAvailable(
                          q, gameState.toMap());
                      final completed = worldState.isQuestCompleted(q.id);
                      return _QuestTile(
                        quest: q,
                        isAvailable: available,
                        isCompleted: completed,
                        isInProgress: _currentEpisodeId == q.id,
                        comicIndex: widget.comicIndex,
                        worldMap: widget.worldMap,
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Tile singola quest ────────────────────────────────────────────────────────

class _QuestTile extends StatelessWidget {
  final WorldQuest quest;
  final bool isAvailable;
  final bool isCompleted;
  final bool isInProgress;
  final ComicIndex comicIndex;
  final WorldMap worldMap;

  const _QuestTile({
    required this.quest,
    required this.isAvailable,
    required this.isCompleted,
    required this.isInProgress,
    required this.comicIndex,
    required this.worldMap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = isAvailable && !isCompleted;
    final IconData leadIcon;
    final Color iconColor;
    if (isCompleted) {
      leadIcon = Icons.check_circle;
      iconColor = Colors.green.shade400;
    } else if (isInProgress) {
      leadIcon = Icons.pause_circle_outline;
      iconColor = Colors.orangeAccent;
    } else if (isAvailable) {
      leadIcon = Icons.play_circle_outline;
      iconColor = Colors.pinkAccent;
    } else {
      leadIcon = Icons.lock_outline;
      iconColor = Colors.grey.shade600;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isActive
            ? const Color(0xFF2A1A3A)
            : const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isActive
              ? () {
                  Navigator.pop(context);
                  _startQuest(context);
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCompleted
                    ? Colors.white10
                    : (isInProgress
                        ? Colors.orangeAccent.withValues(alpha: 0.5)
                        : (isAvailable
                            ? Colors.pinkAccent.withValues(alpha: 0.5)
                            : Colors.white10)),
              ),
            ),
            child: Row(
              children: [
                Icon(leadIcon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              quest.title,
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isInProgress)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.orangeAccent
                                        .withValues(alpha: 0.5)),
                              ),
                              child: const Text(
                                'IN CORSO',
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (quest.subtitle.isNotEmpty)
                        Text(
                          quest.subtitle,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                      Text(
                        'Stagione ${quest.season}',
                        style: TextStyle(
                            color: Colors.pinkAccent.withValues(alpha: 0.6),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Icon(Icons.chevron_right,
                      color: isInProgress
                          ? Colors.orangeAccent
                          : Colors.pinkAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startQuest(BuildContext context) {
    final summary = EpisodeSummary(
      id: quest.id,
      title: quest.title,
      subtitle: quest.subtitle,
      thumbnail: quest.thumbnail,
      file: quest.file,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestLoaderPage(
          comicIndex: comicIndex,
          summary: summary,
          questId: quest.id,
          worldMap: worldMap,
        ),
      ),
    );
  }
}

// ─── Loader quest (con completamento automatico) ───────────────────────────────

class QuestLoaderPage extends StatelessWidget {
  final ComicIndex comicIndex;
  final EpisodeSummary summary;
  final String questId;
  final WorldMap worldMap;

  const QuestLoaderPage({
    super.key,
    required this.comicIndex,
    required this.summary,
    required this.questId,
    required this.worldMap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReadingProgress?>(
      future: ProgressService.loadCurrent(),
      builder: (context, snapshot) {
        // Schermata nera mentre SharedPreferences carica (milliseconds)
        if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D1A),
            body: SizedBox.shrink(),
          );
        }
        final saved = snapshot.data;
        final resume = saved?.episodeId == questId;
        return EpisodeLoaderPage(
          comicIndex: comicIndex,
          summary: summary,
          initialPageIndex: resume ? saved!.pageIndex : 0,
          initialVisibleBlocks: resume ? saved!.visibleBlocks : 1,
          initialBranchId: resume ? saved!.branchId : null,
          initialEntryBranchId: resume ? saved!.entryBranchId : null,
          onEpisodeCompleted: () async {
            await WorldStateService.instance.completeQuest(
              questId,
              worldMap: worldMap,
              currentStats: GameStateService.instance.state.value.toMap(),
            );
          },
        );
      },
    );
  }
}

// ─── Label stagione ────────────────────────────────────────────────────────────

class _SeasonLabel extends StatelessWidget {
  const _SeasonLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.pinkAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Colors.pinkAccent.withValues(alpha: 0.3)),
      ),
      child: const Text(
        'STAGIONE 1 — Alba Strana',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.pinkAccent,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
