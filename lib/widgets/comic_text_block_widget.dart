import 'package:flutter/material.dart';
import '../models/comic_data.dart';

class ComicTextBlockWidget extends StatelessWidget {
  final ComicData comicData;
  final TextBlock block;

  const ComicTextBlockWidget({
    super.key,
    required this.comicData,
    required this.block,
  });

  @override
  Widget build(BuildContext context) {
    final speakerName = comicData.getSpeakerName(block.speaker);

    if (block.isNarration) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          block.text,
          style: const TextStyle(
            color: Colors.white,
            fontStyle: FontStyle.italic,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      );
    }

    if (block.isSystem) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent),
        ),
        child: Text(
          '${speakerName.isNotEmpty ? "$speakerName: " : ""}${block.text}',
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      );
    }

    if (block.isThought) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
          ),
          child: Text(
            '${speakerName.isNotEmpty ? "$speakerName pensa: " : ""}${block.text}',
            style: const TextStyle(
              color: Colors.white,
              fontStyle: FontStyle.italic,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Text(
          '${speakerName.isNotEmpty ? "$speakerName: " : ""}${block.text}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
