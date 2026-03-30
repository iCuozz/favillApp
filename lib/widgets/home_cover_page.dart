import 'package:flutter/material.dart';
import '../models/comic_data.dart';
import 'episodes_list_page.dart';

class HomeCoverPage extends StatelessWidget {
  final ComicData comicData;

  const HomeCoverPage({
    super.key,
    required this.comicData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/cover/copertina.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
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
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  const Text(
                    'FAVILLA\nBLAZE',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'La supermamma che combatte il caos quotidiano tra scuola, pannolini, bug domestici e missioni impossibili.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: Colors.grey.shade200,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EpisodesListPage(
                              comicData: comicData,
                            ),
                          ),
                        );
                      },
                      child: const Text('Inizia'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
