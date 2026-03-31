import 'package:flutter/material.dart';
import '../models/comic_data.dart';

class ComicTextBlockWidget extends StatelessWidget {
  final ComicIndex comicIndex;
  final TextBlock block;

  const ComicTextBlockWidget({
    super.key,
    required this.comicIndex,
    required this.block,
  });

  @override
  Widget build(BuildContext context) {
    final speakerId = block.speaker ?? '';
    final speakerName = comicIndex.getSpeakerName(block.speaker);

    if (block.isNarration) {
      return _NarrationBubble(text: block.text);
    }

    if (block.isSystem) {
      return _SystemBubble(
        speaker: speakerName,
        text: block.text,
      );
    }

    if (block.isThought) {
      return _ThoughtBubble(
        speaker: speakerName,
        text: block.text,
      );
    }

    if (speakerId == 'favilla' || speakerId == 'favilla_blaze') {
      return _FavillaBubble(
        speaker: speakerName,
        text: block.text,
      );
    }

    if (speakerId == 'sparkle_ale') {
      return _SparkleBubble(
        speaker: speakerName,
        text: block.text,
      );
    }

    if (speakerId == 'mallow_bellow') {
      return _MallowBubble(
        speaker: speakerName,
        text: block.text,
      );
    }

    return _DefaultDialogueBubble(
      speaker: speakerName,
      text: block.text,
    );
  }
}

class _NarrationBubble extends StatelessWidget {
  final String text;

  const _NarrationBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.35,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _SystemBubble extends StatelessWidget {
  final String speaker;
  final String text;

  const _SystemBubble({
    required this.speaker,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF12202B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.cyanAccent,
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (speaker.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                speaker.toUpperCase(),
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThoughtBubble extends StatelessWidget {
  final String speaker;
  final String text;

  const _ThoughtBubble({
    required this.speaker,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (speaker.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$speaker pensa',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavillaBubble extends StatelessWidget {
  final String speaker;
  final String text;

  const _FavillaBubble({
    required this.speaker,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3F8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFF6FAE),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (speaker.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  speaker.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFD63384),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            Text(
              text,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkleBubble extends StatelessWidget {
  final String speaker;
  final String text;

  const _SparkleBubble({
    required this.speaker,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7CC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFC107),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (speaker.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  speaker.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFB26A00),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            Text(
              text,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MallowBubble extends StatelessWidget {
  final String speaker;
  final String text;

  const _MallowBubble({
    required this.speaker,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F1FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF5B8DEF),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (speaker.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  speaker.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF2952A3),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            Text(
              text,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultDialogueBubble extends StatelessWidget {
  final String speaker;
  final String text;

  const _DefaultDialogueBubble({
    required this.speaker,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.black,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (speaker.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  speaker.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Text(
              text,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
