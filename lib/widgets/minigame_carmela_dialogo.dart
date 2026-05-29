// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comic_data.dart';

/// Mini-game CARMELA_DIALOGO — conversazione rapida con Carmela.
///
/// Carmela fa 4 domande in sequenza. Il giocatore ha N secondi per rispondere.
/// Ogni risposta "safe" conta 1 punto. Il timer scaduto seleziona la risposta
/// peggiore automaticamente.
///
/// Tier (by safeCount):
///   safeCount ≥ 3 → branch_risposta_bene
///   safeCount 1-2 → branch_risposta_quasi
///   safeCount 0   → branch_risposta_disastro + carmela_ha_notato=true
class MinigameCarmelaDialogoScreen extends StatefulWidget {
  final MinigameConfig config;
  final void Function(
      Map<String, int> statEffects, String tierLabel, MinigameTier tier)
      onComplete;

  const MinigameCarmelaDialogoScreen(
      {super.key, required this.config, required this.onComplete});

  @override
  State<MinigameCarmelaDialogoScreen> createState() =>
      _MinigameCarmelaDialogoScreenState();
}

// ─── Data helpers ─────────────────────────────────────────────────────────────

class _CarmelaOption {
  final String label;
  final bool safe;
  _CarmelaOption({required this.label, required this.safe});
}

class _CarmelaQuestion {
  final String text;
  final double timer;
  final List<_CarmelaOption> options;
  final int timeoutIndex;

  _CarmelaQuestion({
    required this.text,
    required this.timer,
    required this.options,
    required this.timeoutIndex,
  });

  factory _CarmelaQuestion.fromJson(Map<String, dynamic> j) {
    final opts = (j['options'] as List<dynamic>)
        .map((o) => _CarmelaOption(
              label: o['label'] as String,
              safe: o['safe'] as bool? ?? false,
            ))
        .toList();
    return _CarmelaQuestion(
      text: j['text'] as String,
      timer: (j['timer'] as num).toDouble(),
      options: opts,
      timeoutIndex: j['timeout_index'] as int? ?? opts.length - 1,
    );
  }
}

// ─── States ────────────────────────────────────────────────────────────────────

enum _DialogoState { tutorial, intro, question, feedback, finished }

// ─── Widget State ─────────────────────────────────────────────────────────────

class _MinigameCarmelaDialogoScreenState
    extends State<MinigameCarmelaDialogoScreen>
    with SingleTickerProviderStateMixin {
  late final List<_CarmelaQuestion> _questions;

  int _qIndex = 0;
  int _safeCount = 0;
  _DialogoState _state = _DialogoState.tutorial;
  int? _selectedIndex;
  bool _wasTimeout = false;

  // Timer
  late double _timeLeft;
  Timer? _tickTimer;

  // Intro / tutorial animation
  late AnimationController _introCtrl;
  late Animation<double> _introAnim;

  @override
  void initState() {
    super.initState();
    _questions = (widget.config.extra['questions'] as List<dynamic>)
        .map((q) => _CarmelaQuestion.fromJson(q as Map<String, dynamic>))
        .toList();

    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _introAnim = CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);
    _introCtrl.forward();

    _loadTutorialPref();
  }

  Future<void> _loadTutorialPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _state != _DialogoState.tutorial) return;
    if (prefs.getBool('tut_carmela_dialogo') ?? false) _startGame();
  }

  void _startGame() {
    SharedPreferences.getInstance()
        .then((p) => p.setBool('tut_carmela_dialogo', true));
    setState(() => _state = _DialogoState.intro);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _startQuestion();
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _introCtrl.dispose();
    super.dispose();
  }

  // ── Game logic ────────────────────────────────────────────────────────────

  void _startQuestion() {
    if (!mounted) return;
    final q = _questions[_qIndex];
    setState(() {
      _state = _DialogoState.question;
      _timeLeft = q.timer;
      _selectedIndex = null;
      _wasTimeout = false;
    });
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timeLeft -= 0.05);
      if (_timeLeft <= 0) {
        t.cancel();
        _selectOption(_questions[_qIndex].timeoutIndex, timeout: true);
      }
    });
  }

  void _selectOption(int idx, {bool timeout = false}) {
    _tickTimer?.cancel();
    final q = _questions[_qIndex];
    final safe = q.options[idx].safe;
    HapticFeedback.lightImpact();
    setState(() {
      _state = _DialogoState.feedback;
      _selectedIndex = idx;
      _wasTimeout = timeout;
      if (safe) _safeCount++;
    });
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      if (_qIndex < _questions.length - 1) {
        setState(() => _qIndex++);
        _startQuestion();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    setState(() => _state = _DialogoState.finished);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final tier = widget.config.tierFor(_safeCount);
      widget.onComplete(tier.statEffects, tier.label, tier);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1530),
      body: SafeArea(
        child: FadeTransition(
          opacity: _introAnim,
          child: _state == _DialogoState.tutorial
              ? _buildTutorial()
              : _buildContent(),
        ),
      ),
    );
  }

  // ── Tutorial ──────────────────────────────────────────────────────────────

  Widget _buildTutorial() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        children: [
          const Text('👵', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          const Text(
            'Carmela è alla cassa.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.3),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ha già alzato lo sguardo.\nRispondi bene — o si insospettisce.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 28),
          // Demo: timer bar che si svuota
          _buildTutorialDemo(),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),
          _ruleCard('⏱', 'Timer decrescente',
              'Ogni domanda ha un timer. Più si va avanti, meno tempo hai.'),
          const SizedBox(height: 10),
          _ruleCard('✅', 'Rispondi senza tradire',
              'Scegli la risposta che non svela nulla. Le opzioni pericolose sono una trappola.'),
          const SizedBox(height: 10),
          _ruleCard('🔇', 'Tempo scaduto = peggiore opzione',
              'Se il timer finisce, viene selezionata automaticamente la risposta più rischiosa.'),
          const SizedBox(height: 10),
          _ruleCard('🎯', '4 domande',
              'Quante risposte sicure riesci a dare? Da questo dipende quanto Carmela ha capito.'),
          const SizedBox(height: 36),
          GestureDetector(
            onTap: _startGame,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF3D2E5E), Color(0xFF6A1B9A)]),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6A1B9A).withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text('Inizia',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTutorialDemo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2448),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF5A4880), width: 1),
          ),
          child: const Text(
            '«Hai qualcosa di luminoso oggi, cara...»',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        // Static timer bar (half empty, in warning orange)
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: const LinearProgressIndicator(
            value: 0.35,
            minHeight: 6,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8C42)),
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('2.0s', style: TextStyle(color: Color(0xFFFF8C42), fontSize: 10)),
            Text('tempo che scorre →',
                style: TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _ruleCard(String icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(desc,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_state == _DialogoState.intro || _state == _DialogoState.finished) {
      return const Center(child: CircularProgressIndicator(color: Colors.white24));
    }
    final q = _questions[_qIndex];
    return Column(
      children: [
        _buildProgressDots(),
        Expanded(flex: 4, child: _buildCarmelaZone(q.text)),
        _buildTimerBar(q.timer),
        const SizedBox(height: 12),
        Expanded(flex: 5, child: _buildOptions(q)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildProgressDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_questions.length, (i) {
          Color c;
          if (i < _qIndex) {
            c = Colors.greenAccent.withValues(alpha: 0.8);
          } else if (i == _qIndex) {
            c = Colors.white;
          } else {
            c = Colors.white24;
          }
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: i == _qIndex ? 12 : 8,
            height: i == _qIndex ? 12 : 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c),
          );
        }),
      ),
    );
  }

  Widget _buildCarmelaZone(String questionText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3D2E5E),
              border: Border.all(color: const Color(0xFF7C5CBF), width: 2),
            ),
            child: const Center(
              child: Text('👵', style: TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Carmela',
            style: TextStyle(
                color: Color(0xFFB8A0E0), fontSize: 13, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          // Speech bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2448),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5A4880), width: 1),
            ),
            child: Text(
              questionText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.45,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar(double maxTime) {
    final frac = (_timeLeft / maxTime).clamp(0.0, 1.0);
    final Color barColor = frac > 0.5
        ? Color.lerp(const Color(0xFFFFD966), const Color(0xFF66CC99), (frac - 0.5) * 2)!
        : Color.lerp(const Color(0xFFE53935), const Color(0xFFFFD966), frac * 2)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${_timeLeft.clamp(0.0, 99.0).toStringAsFixed(1)}s',
                style: TextStyle(color: barColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(_CarmelaQuestion q) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(q.options.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: _buildOptionButton(q.options[i], i),
          );
        }),
      ),
    );
  }

  Widget _buildOptionButton(_CarmelaOption opt, int idx) {
    Color bgColor = const Color(0xFF2A2045);
    Color borderColor = const Color(0xFF4A3F70);
    Color textColor = Colors.white;

    if (_state == _DialogoState.feedback) {
      if (idx == _selectedIndex) {
        if (opt.safe) {
          bgColor = const Color(0xFF1B4D2E);
          borderColor = const Color(0xFF4CAF50);
          textColor = const Color(0xFFB9F6CA);
        } else {
          bgColor = const Color(0xFF5C1A1A);
          borderColor = const Color(0xFFE53935);
          textColor = const Color(0xFFFFCDD2);
        }
      } else {
        bgColor = const Color(0xFF1A1530).withValues(alpha: 0.5);
        borderColor = Colors.white10;
        textColor = Colors.white30;
      }
    }

    final tappable = _state == _DialogoState.question;

    return GestureDetector(
      onTap: tappable ? () => _selectOption(idx) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            if (_state == _DialogoState.feedback && idx == _selectedIndex)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  opt.safe ? '✓' : '✗',
                  style: TextStyle(
                      color: opt.safe ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            Expanded(
              child: Text(
                _wasTimeout && idx == _selectedIndex
                    ? '${opt.label}   ⏱'
                    : opt.label,
                style: TextStyle(color: textColor, fontSize: 14.5, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
