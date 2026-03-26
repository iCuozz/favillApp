import 'package:flutter/material.dart';

class ComicPageImage extends StatelessWidget {
  final String assetPath;
  final double height;

  const ComicPageImage({
    super.key,
    required this.assetPath,
    this.height = 600,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: height,
          width: double.infinity,
          color: Colors.grey.shade900,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_not_supported,
                size: 40,
                color: Colors.white70,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Immagine non disponibile\n$assetPath',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}