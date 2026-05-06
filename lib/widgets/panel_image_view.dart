import 'dart:io';

import 'package:flutter/material.dart';

import '../services/ai/mission_generator_service.dart';
import '../services/ai/panel_image_service.dart';
import 'mission_panel_backdrop.dart';

/// Mostra l'immagine generata dall'AI per un pannello di missione.
///
/// Stati:
/// - in cache → la mostra subito
/// - non in cache + AI abilitata → shimmer placeholder, poi fade-in
/// - errore o AI disabilitata → fallback al [MissionPanelBackdrop] procedurale
///
/// Sempre clip-paddato con bordo nero stile vignetta. Il [child] passato
/// (caption pannello + bubble) viene messo sopra con un overlay scuro a
/// gradiente per leggibilità.
class PanelImageView extends StatefulWidget {
  final GeneratedMission mission;
  final int panelIndex;
  final int seed;
  final Widget child;

  const PanelImageView({
    super.key,
    required this.mission,
    required this.panelIndex,
    required this.seed,
    required this.child,
  });

  @override
  State<PanelImageView> createState() => _PanelImageViewState();
}

class _PanelImageViewState extends State<PanelImageView> {
  File? _imageFile;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scene = widget.mission.panels[widget.panelIndex].sceneDescription;
    if (scene == null || scene.isEmpty) {
      if (!mounted) return;
      setState(() {
        _failed = true;
      });
      return;
    }

    final cached = await PanelImageService.instance
        .cachedFile(widget.mission.id, widget.panelIndex);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _imageFile = cached;
      });
      return;
    }

    final fetched = await PanelImageService.instance.fetchAndCache(
      mission: widget.mission,
      panelIndex: widget.panelIndex,
    );
    if (!mounted) return;
    setState(() {
      _imageFile = fetched;
      _failed = fetched == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final panel = widget.mission.panels[widget.panelIndex];

    if (_imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black, width: 2.5),
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(_imageFile!, fit: BoxFit.cover),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(30),
                          Colors.black.withAlpha(180),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: widget.child,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_failed) {
      return MissionPanelBackdrop(
        panel: panel,
        seed: widget.seed,
        child: widget.child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 2.5),
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _ShimmerLoading(),
              Positioned.fill(
                child: Container(color: Colors.black.withAlpha(60)),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Disegnando il pannello…',
                      style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerLoading extends StatefulWidget {
  const _ShimmerLoading();

  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + t * 2, -1.0),
              end: Alignment(1.0 + t * 2, 1.0),
              colors: const [
                Color(0xFF2A2030),
                Color(0xFF40304A),
                Color(0xFF2A2030),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
