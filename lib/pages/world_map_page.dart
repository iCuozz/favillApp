import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_state.dart';
import '../models/world_map.dart';
import '../services/game_state_service.dart';
import '../services/world_state_service.dart';
import '../widgets/stats_hud_widget.dart';
import '../widgets/comic_title.dart';
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
    final raw = await rootBundle.loadString('assets/data/world_map.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (!mounted) return;
    setState(() => _worldMap = WorldMap.fromJson(json));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Sfondo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D0D1A),
                  Color(0xFF1A0D2E),
                  Color(0xFF0D1A1A),
                ],
              ),
            ),
          ),
          // Griglia decorativa stile mappa
          CustomPaint(painter: _MapGridPainter()),
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
                          // Linee di connessione tra location sbloccate
                          CustomPaint(
                            size: Size(constraints.maxWidth,
                                constraints.maxHeight),
                            painter: _ConnectionPainter(
                              locations: _worldMap!.locations,
                              worldState: worldState,
                              canvasSize: Size(constraints.maxWidth,
                                  constraints.maxHeight),
                            ),
                          ),
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

class _LocationSheet extends StatelessWidget {
  final WorldLocation location;
  final ComicIndex comicIndex;
  final WorldMap worldMap;

  const _LocationSheet({
    required this.location,
    required this.comicIndex,
    required this.worldMap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WorldState>(
      valueListenable: WorldStateService.instance.state,
      builder: (context, worldState, _) {
        return ValueListenableBuilder<GameState>(
          valueListenable: GameStateService.instance.state,
          builder: (context, gameState, _) {
            final quests = location.quests;

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
                      Text(location.emoji,
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              location.description,
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
                        comicIndex: comicIndex,
                        worldMap: worldMap,
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
  final ComicIndex comicIndex;
  final WorldMap worldMap;

  const _QuestTile({
    required this.quest,
    required this.isAvailable,
    required this.isCompleted,
    required this.comicIndex,
    required this.worldMap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isAvailable && !isCompleted
            ? const Color(0xFF2A1A3A)
            : const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isAvailable && !isCompleted
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
                    : (isAvailable
                        ? Colors.pinkAccent.withValues(alpha: 0.5)
                        : Colors.white10),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle
                      : (isAvailable
                          ? Icons.play_circle_outline
                          : Icons.lock_outline),
                  color: isCompleted
                      ? Colors.green.shade400
                      : (isAvailable
                          ? Colors.pinkAccent
                          : Colors.grey.shade600),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: TextStyle(
                          color: isAvailable && !isCompleted
                              ? Colors.white
                              : Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
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
                if (isAvailable && !isCompleted)
                  const Icon(Icons.chevron_right, color: Colors.pinkAccent),
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
    return EpisodeLoaderPage(
      comicIndex: comicIndex,
      summary: summary,
      onEpisodeCompleted: () async {
        await WorldStateService.instance.completeQuest(
          questId,
          worldMap: worldMap,
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

// ─── Painters ─────────────────────────────────────────────────────────────────

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter oldDelegate) => false;
}

class _ConnectionPainter extends CustomPainter {
  final List<WorldLocation> locations;
  final WorldState worldState;
  final Size canvasSize;

  _ConnectionPainter({
    required this.locations,
    required this.worldState,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = Colors.pinkAccent.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final unlockedLocations =
        locations.where((l) => worldState.isLocationUnlocked(l)).toList();

    // Connetti ogni location sbloccata alle altre vicine
    for (int i = 0; i < unlockedLocations.length; i++) {
      for (int j = i + 1; j < unlockedLocations.length; j++) {
        final a = unlockedLocations[i];
        final b = unlockedLocations[j];
        final aPos =
            Offset(a.position.dx * size.width, a.position.dy * size.height);
        final bPos =
            Offset(b.position.dx * size.width, b.position.dy * size.height);
        final dist = (aPos - bPos).distance;
        if (dist < size.width * 0.55) {
          canvas.drawLine(aPos, bPos, paint);
        }
      }
    }

    // Linee tratteggiate verso location bloccate vicine
    final lockedLocations =
        locations.where((l) => !worldState.isLocationUnlocked(l)).toList();
    for (final locked in lockedLocations) {
      final lockedPos = Offset(
          locked.position.dx * size.width, locked.position.dy * size.height);
      for (final unlocked in unlockedLocations) {
        final unlockedPos = Offset(unlocked.position.dx * size.width,
            unlocked.position.dy * size.height);
        final dist = (lockedPos - unlockedPos).distance;
        if (dist < size.width * 0.45) {
          _drawDashedLine(canvas, unlockedPos, lockedPos, dashPaint);
          break;
        }
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 6.0;
    const gapLength = 5.0;
    final total = (end - start).distance;
    final dir = (end - start) / total;
    double drawn = 0;
    bool drawing = true;
    while (drawn < total) {
      final segLen =
          drawing ? math.min(dashLength, total - drawn) : math.min(gapLength, total - drawn);
      if (drawing) {
        canvas.drawLine(start + dir * drawn, start + dir * (drawn + segLen), paint);
      }
      drawn += segLen;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(_ConnectionPainter old) =>
      old.worldState != worldState;
}
