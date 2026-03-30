import 'package:flutter/material.dart';

class ComicTitle extends StatelessWidget {
  final String text;
  final double fontSize;

  const ComicTitle({
    super.key,
    required this.text,
    this.fontSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontFamily: 'ComicHero',
            fontSize: fontSize,
            height: 0.95,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8
              ..color = Colors.black,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFF176),
                Color(0xFFFF9800),
                Color(0xFFE91E63),
              ],
            ).createShader(bounds);
          },
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              height: 0.95,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Color(0xAA000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
