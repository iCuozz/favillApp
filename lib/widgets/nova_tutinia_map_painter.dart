// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Disegna la mappa di Nova Tutinia: quartieri, strade, edifici, parchi e labels.
/// Usata come sfondo nella WorldMapPage.
class NovaTutiniaMapPainter extends CustomPainter {
  const NovaTutiniaMapPainter();

  // ─── Palette ──────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF080D14);

  // Zone
  static const _zoneResidential = Color(0xFF14101E);
  static const _zoneSchool = Color(0xFF0A1220);
  static const _zonePark = Color(0xFF081408);
  static const _zoneCommercial = Color(0xFF18100A);
  static const _zoneMall = Color(0xFF1E1008);
  static const _zoneCoast = Color(0xFF080E18);

  // Strade
  static const _road = Color(0xFF1E1E2E);
  static const _roadEdge = Color(0xFF2A2A3E);
  static const _roadCenter = Color(0xFF4A3A10);

  // Edifici per zona
  static const _buildResidential = Color(0xFF2A1E38);
  static const _buildResidentialLight = Color(0xFF3A2A50);
  static const _buildSchool = Color(0xFF0E1E38);
  static const _buildSchoolLight = Color(0xFF162840);
  static const _buildCommercial = Color(0xFF281808);
  static const _buildCommercialLight = Color(0xFF362010);

  // Alberi
  static const _treeDark = Color(0xFF0C1C0C);
  static const _treeMid = Color(0xFF122012);
  static const _treeLight = Color(0xFF1A301A);

  // Acqua
  static const _waterBase = Color(0xFF070F18);
  static const _waterFoam = Color(0xFF0D2030);

  // Labels
  static const _labelResidential = Color(0xFFB080FF);
  static const _labelSchool = Color(0xFF6090FF);
  static const _labelPark = Color(0xFF50B850);
  static const _labelCommercial = Color(0xFFD08030);
  static const _labelMall = Color(0xFFFF9030);
  static const _labelCoast = Color(0xFF30A0D0);
  static const _labelRiver = Color(0xFF3070A0);

  // ─── Entry point ──────────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _drawBase(canvas, size);
    _drawRiver(canvas, w, h);
    _drawZones(canvas, w, h);
    _drawBuildings(canvas, w, h);
    _drawParkTrees(canvas, w, h);
    _drawRoads(canvas, w, h);
    _drawRoadMarkings(canvas, w, h);
    _drawTrainTracks(canvas, w, h);
    _drawLabels(canvas, w, h);
    _drawVignette(canvas, size);
  }

  // ─── Base ─────────────────────────────────────────────────────────────────
  void _drawBase(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _bg,
    );
  }

  // ─── Fiume ────────────────────────────────────────────────────────────────
  void _drawRiver(Canvas canvas, double w, double h) {
    // Torrente che attraversa il lato destro in diagonale
    final path = Path();
    path.moveTo(w * 0.88, 0);
    path.cubicTo(
      w * 0.92, h * 0.15,
      w * 0.85, h * 0.30,
      w * 0.87, h * 0.45,
    );
    path.cubicTo(
      w * 0.89, h * 0.58,
      w * 0.93, h * 0.70,
      w * 0.90, h,
    );
    path.lineTo(w * 0.96, h);
    path.cubicTo(
      w * 0.99, h * 0.70,
      w * 0.95, h * 0.58,
      w * 0.93, h * 0.45,
    );
    path.cubicTo(
      w * 0.91, h * 0.30,
      w * 0.98, h * 0.15,
      w * 0.96, 0,
    );
    path.close();

    canvas.drawPath(path, Paint()..color = _waterBase);

    // Shimmer interno
    final shimmer = Path();
    shimmer.moveTo(w * 0.89, 0);
    shimmer.cubicTo(
      w * 0.93, h * 0.18,
      w * 0.87, h * 0.32,
      w * 0.89, h * 0.46,
    );
    shimmer.cubicTo(
      w * 0.91, h * 0.60,
      w * 0.94, h * 0.72,
      w * 0.91, h,
    );
    shimmer.lineTo(w * 0.92, h);
    shimmer.cubicTo(
      w * 0.95, h * 0.72,
      w * 0.92, h * 0.60,
      w * 0.90, h * 0.46,
    );
    shimmer.cubicTo(
      w * 0.88, h * 0.32,
      w * 0.94, h * 0.18,
      w * 0.90, 0,
    );
    shimmer.close();
    canvas.drawPath(shimmer, Paint()..color = _waterFoam);
  }

  // ─── Quartieri ────────────────────────────────────────────────────────────
  void _drawZones(Canvas canvas, double w, double h) {
    const rr = Radius.circular(8);

    // Zona Residenziale (CASA): centro-destra
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.43, h * 0.46, w * 0.82, h * 0.80, rr),
      Paint()..color = _zoneResidential,
    );

    // Zona Scolastica (SCUOLA): alto-sinistra
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.06, h * 0.18, w * 0.40, h * 0.50, rr),
      Paint()..color = _zoneSchool,
    );

    // Parco Centrale (PARCO): alto-destra
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.52, h * 0.10, w * 0.84, h * 0.44, rr),
      Paint()..color = _zonePark,
    );

    // Zona Commerciale (SUPERMERCATO): basso-sinistra
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.06, h * 0.58, w * 0.40, h * 0.88, rr),
      Paint()..color = _zoneCommercial,
    );

    // GalaxiaMall (CENTRO_COMMERCIALE): basso-sinistra, sotto supermercato
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.06, h * 0.90, w * 0.32, h * 0.97, rr),
      Paint()..color = _zoneMall,
    );

    // Zona Costiera (MARE): basso-destra, oltre il residenziale
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.65, h * 0.82, w * 0.97, h * 0.97, rr),
      Paint()..color = _zoneCoast,
    );
  }

  // ─── Edifici ──────────────────────────────────────────────────────────────
  void _drawBuildings(Canvas canvas, double w, double h) {
    // --- Residenziale ---
    final rp = Paint()..color = _buildResidential;
    final rpl = Paint()..color = _buildResidentialLight;
    final buildings = <Rect>[
      Rect.fromLTWH(w * 0.46, h * 0.49, w * 0.06, h * 0.07),
      Rect.fromLTWH(w * 0.54, h * 0.49, w * 0.08, h * 0.05),
      Rect.fromLTWH(w * 0.64, h * 0.49, w * 0.05, h * 0.08),
      Rect.fromLTWH(w * 0.71, h * 0.49, w * 0.07, h * 0.06),
      Rect.fromLTWH(w * 0.46, h * 0.60, w * 0.07, h * 0.06),
      Rect.fromLTWH(w * 0.55, h * 0.61, w * 0.09, h * 0.07),
      Rect.fromLTWH(w * 0.66, h * 0.60, w * 0.06, h * 0.09),
      Rect.fromLTWH(w * 0.74, h * 0.61, w * 0.05, h * 0.06),
      Rect.fromLTWH(w * 0.46, h * 0.72, w * 0.08, h * 0.05),
      Rect.fromLTWH(w * 0.56, h * 0.72, w * 0.06, h * 0.06),
      Rect.fromLTWH(w * 0.64, h * 0.73, w * 0.09, h * 0.05),
      Rect.fromLTWH(w * 0.75, h * 0.72, w * 0.05, h * 0.07),
    ];
    const rr = Radius.circular(2);
    for (int i = 0; i < buildings.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(buildings[i], rr),
        i % 3 == 0 ? rpl : rp,
      );
    }

    // --- Zona Scolastica ---
    final sp = Paint()..color = _buildSchool;
    final spl = Paint()..color = _buildSchoolLight;
    final schoolBuildings = <Rect>[
      Rect.fromLTWH(w * 0.09, h * 0.21, w * 0.10, h * 0.08), // edificio scuola principale
      Rect.fromLTWH(w * 0.21, h * 0.21, w * 0.07, h * 0.09),
      Rect.fromLTWH(w * 0.30, h * 0.22, w * 0.07, h * 0.06),
      Rect.fromLTWH(w * 0.09, h * 0.34, w * 0.06, h * 0.07),
      Rect.fromLTWH(w * 0.17, h * 0.35, w * 0.09, h * 0.06),
      Rect.fromLTWH(w * 0.28, h * 0.34, w * 0.08, h * 0.07),
      Rect.fromLTWH(w * 0.09, h * 0.44, w * 0.07, h * 0.04),
      Rect.fromLTWH(w * 0.18, h * 0.44, w * 0.05, h * 0.04),
      Rect.fromLTWH(w * 0.25, h * 0.44, w * 0.08, h * 0.04),
    ];
    for (int i = 0; i < schoolBuildings.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(schoolBuildings[i], rr),
        i % 4 == 0 ? spl : sp,
      );
    }

    // --- Zona Commerciale ---
    final cp = Paint()..color = _buildCommercial;
    final cpl = Paint()..color = _buildCommercialLight;
    final commBuildings = <Rect>[
      Rect.fromLTWH(w * 0.09, h * 0.62, w * 0.12, h * 0.06),
      Rect.fromLTWH(w * 0.23, h * 0.62, w * 0.08, h * 0.07),
      Rect.fromLTWH(w * 0.33, h * 0.62, w * 0.05, h * 0.06),
      Rect.fromLTWH(w * 0.09, h * 0.73, w * 0.08, h * 0.08),
      Rect.fromLTWH(w * 0.19, h * 0.74, w * 0.12, h * 0.06),
      Rect.fromLTWH(w * 0.33, h * 0.73, w * 0.05, h * 0.09),
      Rect.fromLTWH(w * 0.09, h * 0.84, w * 0.10, h * 0.04),
      Rect.fromLTWH(w * 0.21, h * 0.84, w * 0.07, h * 0.03),
    ];
    for (int i = 0; i < commBuildings.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(commBuildings[i], rr),
        i % 3 == 1 ? cpl : cp,
      );
    }
  }

  // ─── Alberi (Parco) ───────────────────────────────────────────────────────
  void _drawParkTrees(Canvas canvas, double w, double h) {
    final rand = math.Random(42); // seed fisso per risultato deterministico
    final treePaints = [
      Paint()..color = _treeDark,
      Paint()..color = _treeMid,
      Paint()..color = _treeLight,
    ];

    // Area parco: x 0.53-0.83, y 0.11-0.43
    for (int i = 0; i < 55; i++) {
      final tx = w * (0.53 + rand.nextDouble() * 0.30);
      final ty = h * (0.11 + rand.nextDouble() * 0.32);
      final radius = w * (0.012 + rand.nextDouble() * 0.015);
      canvas.drawCircle(
        Offset(tx, ty),
        radius,
        treePaints[i % treePaints.length],
      );
    }

    // Alberi sparsi intorno al parco (per dargli profondità)
    for (int i = 0; i < 20; i++) {
      final tx = w * (0.55 + rand.nextDouble() * 0.25);
      final ty = h * (0.12 + rand.nextDouble() * 0.28);
      final radius = w * (0.008 + rand.nextDouble() * 0.010);
      canvas.drawCircle(
        Offset(tx, ty),
        radius,
        treePaints[(i + 1) % treePaints.length],
      );
    }
  }

  // ─── Strade ───────────────────────────────────────────────────────────────
  void _drawRoads(Canvas canvas, double w, double h) {
    final roadPaint = Paint()
      ..color = _road
      ..style = PaintingStyle.stroke;

    final edgePaint = Paint()
      ..color = _roadEdge
      ..style = PaintingStyle.stroke;

    // Larghezze strade
    const mainW = 18.0;
    const secW = 12.0;
    const alleyW = 7.0;

    // Via Garibaldi — arteria principale orizzontale (y=0.50)
    _drawRoad(canvas, roadPaint, edgePaint,
        Offset(0, h * 0.50), Offset(w * 0.86, h * 0.50), mainW);

    // Corso Principale — arteria verticale (x=0.44)
    _drawRoad(canvas, roadPaint, edgePaint,
        Offset(w * 0.44, 0), Offset(w * 0.44, h), mainW);

    // Via della Scuola — orizzontale alta (y=0.35) da x=0 a x=0.44
    _drawRoad(canvas, roadPaint, edgePaint,
        Offset(0, h * 0.35), Offset(w * 0.44, h * 0.35), secW);

    // Viale del Parco — orizzontale (y=0.27) da x=0.44 a x=0.84
    _drawRoad(canvas, roadPaint, edgePaint,
        Offset(w * 0.44, h * 0.27), Offset(w * 0.84, h * 0.27), secW);

    // Raccordo Parco — verticale (x=0.68) da y=0.27 a y=0.50
    _drawRoad(canvas, roadPaint, edgePaint,
        Offset(w * 0.68, h * 0.27), Offset(w * 0.68, h * 0.50), secW);

    // Via del Mercato — verticale (x=0.26) da y=0.50 a y=0.88
    _drawRoad(canvas, roadPaint, edgePaint,
        Offset(w * 0.26, h * 0.50), Offset(w * 0.26, h * 0.88), secW);

    // Via Lex — verticale residenziale (x=0.56) da y=0.50 a y=0.80
    _drawRoad(canvas, roadPaint, edgePaint,
        Offset(w * 0.56, h * 0.50), Offset(w * 0.56, h * 0.80), alleyW);

    // Via Mallow — orizzontale residenziale (y=0.62) da x=0.44 a x=0.82
    _drawRoad(canvas, roadPaint, edgePaint,
        Offset(w * 0.44, h * 0.62), Offset(w * 0.82, h * 0.62), alleyW);

    // Via Secondaria scolastica — (y=0.44) da x=0.06 a x=0.44
    _drawRoad(canvas, roadPaint, edgePaint,
        Offset(w * 0.06, h * 0.44), Offset(w * 0.44, h * 0.44), alleyW);

    // Via Commerciale trasversale — (y=0.73) da x=0.06 a x=0.44
    _drawRoad(canvas, roadPaint, edgePaint,
        Offset(w * 0.06, h * 0.73), Offset(w * 0.44, h * 0.73), alleyW);
  }

  void _drawRoad(Canvas canvas, Paint fill, Paint edge,
      Offset start, Offset end, double width) {
    edge.strokeWidth = width + 3;
    fill.strokeWidth = width;
    canvas.drawLine(start, end, edge);
    canvas.drawLine(start, end, fill);
  }

  // ─── Segnaletica ─────────────────────────────────────────────────────────
  void _drawRoadMarkings(Canvas canvas, double w, double h) {
    final dash = Paint()
      ..color = _roadCenter
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Tratteggio Via Garibaldi
    _drawDashedLine(canvas, Offset(0, h * 0.50),
        Offset(w * 0.86, h * 0.50), dash, 12, 8);

    // Tratteggio Corso Principale
    _drawDashedLine(canvas, Offset(w * 0.44, 0),
        Offset(w * 0.44, h), dash, 12, 8);

    // Strisce pedonali (incroci principali)
    _drawCrosswalk(canvas, w * 0.44, h * 0.50, true);   // incrocio principale
    _drawCrosswalk(canvas, w * 0.26, h * 0.50, false);  // via mercato
    _drawCrosswalk(canvas, w * 0.44, h * 0.35, true);   // via scuola
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end,
      Paint paint, double dashLen, double gapLen) {
    final dir = (end - start);
    final total = dir.distance;
    final unit = dir / total;
    double pos = 0;
    bool drawing = true;
    while (pos < total) {
      final segLen = drawing
          ? math.min(dashLen, total - pos)
          : math.min(gapLen, total - pos);
      if (drawing) {
        canvas.drawLine(start + unit * pos, start + unit * (pos + segLen), paint);
      }
      pos += segLen;
      drawing = !drawing;
    }
  }

  void _drawCrosswalk(Canvas canvas, double cx, double cy, bool horizontal) {
    final p = Paint()
      ..color = const Color(0xFF2A2A42)
      ..strokeWidth = 2;
    for (int i = -3; i <= 3; i++) {
      final Offset a, b;
      if (horizontal) {
        a = Offset(cx + i * 4.0, cy - 10);
        b = Offset(cx + i * 4.0, cy + 10);
      } else {
        a = Offset(cx - 10, cy + i * 4.0);
        b = Offset(cx + 10, cy + i * 4.0);
      }
      canvas.drawLine(a, b, p);
    }
  }

  // ─── Binari (bordo nord) ──────────────────────────────────────────────────
  void _drawTrainTracks(Canvas canvas, double w, double h) {
    // Binario che corre sul bordo nord della mappa
    final railPaint = Paint()
      ..color = const Color(0xFF252535)
      ..strokeWidth = 2;
    final tiePaint = Paint()
      ..color = const Color(0xFF1A1A28)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // Due rotaie parallele a y=0.07 e y=0.09
    canvas.drawLine(Offset(0, h * 0.07), Offset(w * 0.84, h * 0.07), railPaint);
    canvas.drawLine(Offset(0, h * 0.09), Offset(w * 0.84, h * 0.09), railPaint);

    // Traversine
    for (double x = 0; x < w * 0.84; x += w * 0.025) {
      canvas.drawLine(Offset(x, h * 0.065), Offset(x, h * 0.095), tiePaint);
    }
  }

  // ─── Labels ───────────────────────────────────────────────────────────────
  void _drawLabels(Canvas canvas, double w, double h) {
    _drawLabel(canvas, 'QUARTIERE', Offset(w * 0.61, h * 0.54),
        _labelResidential, 8, true);
    _drawLabel(canvas, 'RESIDENZIALE', Offset(w * 0.61, h * 0.57),
        _labelResidential, 7.5, true);

    _drawLabel(canvas, 'ZONA', Offset(w * 0.20, h * 0.24),
        _labelSchool, 8, true);
    _drawLabel(canvas, 'SCOLASTICA', Offset(w * 0.20, h * 0.27),
        _labelSchool, 7.5, true);

    _drawLabel(canvas, 'PARCO', Offset(w * 0.68, h * 0.17),
        _labelPark, 8, true);
    _drawLabel(canvas, 'CENTRALE', Offset(w * 0.68, h * 0.20),
        _labelPark, 7.5, true);

    _drawLabel(canvas, 'ZONA', Offset(w * 0.19, h * 0.65),
        _labelCommercial, 8, true);
    _drawLabel(canvas, 'COMMERCIALE', Offset(w * 0.19, h * 0.68),
        _labelCommercial, 7, true);

    _drawLabel(canvas, 'TORRENTE', Offset(w * 0.91, h * 0.50),
        _labelRiver, 7, false, rotate: true);

    _drawLabel(canvas, 'GALAXIAMALL', Offset(w * 0.17, h * 0.93),
        _labelMall, 7.5, true);

    _drawLabel(canvas, 'SPIAGGIA', Offset(w * 0.82, h * 0.90),
        _labelCoast, 7.5, true);

    // Nomi strade
    _drawLabel(canvas, 'VIA GARIBALDI', Offset(w * 0.16, h * 0.48),
        const Color(0xFF3A3A55), 7, false);
    _drawLabel(canvas, 'CORSO PRINCIPALE', Offset(w * 0.45, h * 0.10),
        const Color(0xFF3A3A55), 7, false, rotate: true);

    // Stazione (bordo nord)
    _drawLabel(canvas, '⊙ STAZIONE NOVA TUTINIA', Offset(w * 0.20, h * 0.05),
        const Color(0xFF505070), 7, false);
  }

  void _drawLabel(Canvas canvas, String text, Offset center,
      Color color, double fontSize, bool bold, {bool rotate = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: 0.75),
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotate) canvas.rotate(-math.pi / 2);
    canvas.translate(-tp.width / 2, -tp.height / 2);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  // ─── Vignette ─────────────────────────────────────────────────────────────
  void _drawVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(NovaTutiniaMapPainter oldDelegate) => false;
}
