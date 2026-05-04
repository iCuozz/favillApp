import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/ai/mission_generator_service.dart';

/// Sfondo procedurale "comic-book" per un pannello di missione AI.
/// Niente immagini, niente chiamate AI: solo CustomPainter.
///
/// Look:
/// - Gradiente diagonale colorato in base al personaggio "dominante"
///   del pannello (Favilla / Sparkle Ale / Mallow Bellow / narrazione).
/// - Pattern halftone (puntini) sovrapposto in trasparenza.
/// - Raggi "burst" da uno degli angoli per dare energia.
/// - Bordo nero spesso stile vignetta.
class MissionPanelBackdrop extends StatelessWidget {
  final GeneratedPanel panel;
  final int seed;
  final Widget child;

  const MissionPanelBackdrop({
    super.key,
    required this.panel,
    required this.seed,
    required this.child,
  });

  String get _dominantSpeaker {
    String pick = 'narrator';
    int bestScore = -1;
    final counts = <String, int>{};
    for (final b in panel.textBlocks) {
      counts[b.speaker] = (counts[b.speaker] ?? 0) + 1;
    }
    counts.forEach((id, n) {
      final priority = id == 'favilla'
          ? 3
          : (id == 'sparkle_ale' || id == 'mallow_bellow')
              ? 2
              : 1;
      final score = n * 10 + priority;
      if (score > bestScore) {
        bestScore = score;
        pick = id;
      }
    });
    return pick;
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(_dominantSpeaker);
    final rng = math.Random(seed);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 2.5),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BackdropPainter(palette: palette, rng: rng),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withAlpha(0),
                      Colors.black.withAlpha(110),
                    ],
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  static _Palette _paletteFor(String speaker) {
    switch (speaker) {
      case 'favilla':
        return const _Palette(
          start: Color(0xFFFF4B8B),
          end: Color(0xFF6A1B9A),
          dot: Color(0xFFFFD8E8),
          burst: Color(0xFFFFEB3B),
        );
      case 'sparkle_ale':
        return const _Palette(
          start: Color(0xFF40C4FF),
          end: Color(0xFF1A237E),
          dot: Color(0xFFB3E5FC),
          burst: Color(0xFFFFF176),
        );
      case 'mallow_bellow':
        return const _Palette(
          start: Color(0xFF1DE9B6),
          end: Color(0xFF004D40),
          dot: Color(0xFFB2DFDB),
          burst: Color(0xFFFFF59D),
        );
      case 'narrator':
      default:
        return const _Palette(
          start: Color(0xFFFFC107),
          end: Color(0xFF4E342E),
          dot: Color(0xFFFFE082),
          burst: Color(0xFFFFFFFF),
        );
    }
  }
}

class _Palette {
  final Color start;
  final Color end;
  final Color dot;
  final Color burst;

  const _Palette({
    required this.start,
    required this.end,
    required this.dot,
    required this.burst,
  });
}

class _BackdropPainter extends CustomPainter {
  final _Palette palette;
  final math.Random rng;

  _BackdropPainter({required this.palette, required this.rng});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Gradiente diagonale di base.
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [palette.start, palette.end],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Halftone dots.
    final dotPaint = Paint()..color = palette.dot.withAlpha(70);
    const spacing = 14.0;
    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final offsetX = (y.isEven ? 0.0 : spacing / 2) + x * spacing;
        final cy = y * spacing;
        // Far decadere i puntini verso il centro per evitare uniformità.
        final dx = (offsetX - size.width / 2) / size.width;
        final dy = (cy - size.height / 2) / size.height;
        final dist = math.sqrt(dx * dx + dy * dy);
        final radius = (1.6 - dist).clamp(0.4, 1.6);
        canvas.drawCircle(Offset(offsetX, cy), radius, dotPaint);
      }
    }

    // Burst rays da uno dei 4 angoli (deterministico via seed).
    final corner = rng.nextInt(4);
    final origin = switch (corner) {
      0 => const Offset(-30, -30),
      1 => Offset(size.width + 30, -30),
      2 => Offset(-30, size.height + 30),
      _ => Offset(size.width + 30, size.height + 30),
    };
    final burstPaint = Paint()
      ..color = palette.burst.withAlpha(36)
      ..style = PaintingStyle.fill;
    final maxLen = math.sqrt(size.width * size.width + size.height * size.height) * 1.4;
    const rayCount = 14;
    for (var i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * math.pi / 2 +
          (corner == 1 || corner == 2 ? math.pi / 2 : 0) +
          (corner == 3 ? math.pi : 0);
      final spread = 0.04 + rng.nextDouble() * 0.025;
      final p1 = origin +
          Offset(math.cos(angle - spread) * maxLen,
              math.sin(angle - spread) * maxLen);
      final p2 = origin +
          Offset(math.cos(angle + spread) * maxLen,
              math.sin(angle + spread) * maxLen);
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(path, burstPaint);
    }

    // Vignettatura ai bordi per leggibilità.
    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 0.95,
      colors: [Colors.transparent, Colors.black.withAlpha(80)],
      stops: const [0.6, 1.0],
    );
    canvas.drawRect(
      rect,
      Paint()..shader = vignette.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.palette != palette;
}
