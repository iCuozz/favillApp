// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comic_data.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const List<String> _kSymbols = ['🐱', '🌙', '⭐', '🍕', '🚀', '🦋'];
const List<Color> _kSymbolColors = [
  Color(0xFFFF6B6B), // 🐱 coral
  Color(0xFF4ECDC4), // 🌙 teal
  Color(0xFFFFD93D), // ⭐ yellow
  Color(0xFFFF8C42), // 🍕 orange
  Color(0xFF6C5CE7), // 🚀 purple
  Color(0xFF55EFC4), // 🦋 mint
];
// Timers per row (seconds), decreasing pressure.
const List<double> _kRowTimers = [22.0, 18.0, 13.0, 10.0];
const int _kSlots = 4;
const int _kMaxAttempts = 4;

// ── Enums ─────────────────────────────────────────────────────────────────────

enum _GameState { tutorial, intro, playing, feedback, won, lost }

enum _FeedbackDot { correctPos, wrongPos, absent }

int _dotRank(_FeedbackDot d) {
  switch (d) {
    case _FeedbackDot.correctPos:
      return 0;
    case _FeedbackDot.wrongPos:
      return 1;
    case _FeedbackDot.absent:
      return 2;
  }
}

// ── Main widget ───────────────────────────────────────────────────────────────

/// Mini-game CRACK_PASSWORD — Baby Mastermind.
///
/// Lex deve indovinare la password di 4 simboli di Mallow (nessun ripetuto,
/// scelti da 6). Ogni tentativo mostra feedback ordinato: 🟢 simbolo e
/// posizione corretti, 🟡 simbolo presente ma posizione sbagliata, ⬛ assente.
///
/// Tier (by score):
///   score 2 → vinto entro 3 tentativi  → branch_genio  (segreto -5, lex_ha_un_piano=true)
///   score 1 → vinto al 4° tentativo    → branch_quasi  (legame +5)
///   score 0 → fallito tutti e 4        → branch_beccato (legame +10)
class MinigameCrackPasswordScreen extends StatefulWidget {
  final MinigameConfig config;
  final void Function(
      Map<String, int> statEffects, String tierLabel, MinigameTier tier)
      onComplete;

  const MinigameCrackPasswordScreen(
      {super.key, required this.config, required this.onComplete});

  @override
  State<MinigameCrackPasswordScreen> createState() =>
      _MinigameCrackPasswordScreenState();
}

class _MinigameCrackPasswordScreenState
    extends State<MinigameCrackPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _rng = Random();

  late final List<int> _password;
  final List<List<int?>> _attempts =
      List.generate(_kMaxAttempts, (_) => List.filled(_kSlots, null));
  final List<List<_FeedbackDot>> _feedbacks = [];

  int _currentRow = 0;
  int _activeSlot = 0;
  _GameState _gameState = _GameState.tutorial;
  bool _isSubmitting = false;

  double _timeLeft = _kRowTimers[0];
  Timer? _tickTimer;

  late final AnimationController _introCtrl;
  late final Animation<double> _introAnim;

  // ── Init ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _password = _generatePassword();

    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _introAnim = CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);
    _introCtrl.forward();

    _loadTutorialPref();
  }

  Future<void> _loadTutorialPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _gameState != _GameState.tutorial) return;
    if (prefs.getBool('tut_crack_password') ?? false) _startGame();
  }

  void _startGame() {
    SharedPreferences.getInstance()
        .then((p) => p.setBool('tut_crack_password', true));
    setState(() => _gameState = _GameState.intro);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _startRow(0);
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _introCtrl.dispose();
    super.dispose();
  }

  // ── Password generation ───────────────────────────────────────────────────

  List<int> _generatePassword() {
    final pool = List.generate(_kSymbols.length, (i) => i)..shuffle(_rng);
    return pool.sublist(0, _kSlots);
  }

  // ── Row management ────────────────────────────────────────────────────────

  void _startRow(int row) {
    if (!mounted) return;
    setState(() {
      _currentRow = row;
      _activeSlot = 0;
      _gameState = _GameState.playing;
      _timeLeft = _kRowTimers[row.clamp(0, _kRowTimers.length - 1)];
      _isSubmitting = false;
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
        _onTimerExpired();
      }
    });
  }

  void _onTimerExpired() {
    if (_isSubmitting || _gameState != _GameState.playing) return;
    // Auto-fill remaining empty slots using only unused symbols (no repeats).
    final used = _attempts[_currentRow].whereType<int>().toSet();
    final available = List.generate(_kSymbols.length, (i) => i)
        .where((i) => !used.contains(i))
        .toList()
      ..shuffle(_rng);
    int fillIdx = 0;
    for (int i = 0; i < _kSlots; i++) {
      if (_attempts[_currentRow][i] == null) {
        setState(() => _attempts[_currentRow][i] = available[fillIdx++]);
      }
    }
    _submitAttempt();
  }

  // ── Interaction ───────────────────────────────────────────────────────────

  void _tapSlot(int slotIdx) {
    if (_gameState != _GameState.playing) return;
    setState(() {
      // Tap a filled slot → clear it and select it.
      // Tap an empty slot → just select it.
      _attempts[_currentRow][slotIdx] = null;
      _activeSlot = slotIdx;
    });
    HapticFeedback.selectionClick();
  }

  void _tapSymbol(int symbolIdx) {
    if (_gameState != _GameState.playing) return;
    final row = _attempts[_currentRow];
    // Enforce no repeats in current row.
    if (row.contains(symbolIdx)) return;
    setState(() {
      row[_activeSlot] = symbolIdx;
      // Auto-advance active slot to next empty slot.
      for (int i = 1; i <= _kSlots; i++) {
        final next = (_activeSlot + i) % _kSlots;
        if (row[next] == null) {
          _activeSlot = next;
          break;
        }
      }
    });
    HapticFeedback.selectionClick();
  }

  bool get _canSubmit {
    if (_gameState != _GameState.playing || _isSubmitting) return false;
    return _attempts[_currentRow].every((s) => s != null);
  }

  void _submitAttempt() {
    if (_isSubmitting || _gameState != _GameState.playing) return;
    _isSubmitting = true;
    _tickTimer?.cancel();

    final row = List<int>.from(
        _attempts[_currentRow].map((s) => s ?? 0)); // nulls auto-filled above
    final feedback = _checkAttempt(row);
    setState(() {
      _feedbacks.add(feedback);
      _gameState = _GameState.feedback;
    });
    HapticFeedback.lightImpact();

    final won = feedback.every((d) => d == _FeedbackDot.correctPos);
    final completedRow = _currentRow;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (won) {
        _endGame(won: true, completedRow: completedRow);
      } else if (completedRow >= _kMaxAttempts - 1) {
        _endGame(won: false, completedRow: completedRow);
      } else {
        _startRow(completedRow + 1);
      }
    });
  }

  // ── Check algorithm ───────────────────────────────────────────────────────

  // Standard Mastermind algorithm. Feedback is sorted (correctPos first,
  // wrongPos next, absent last) to avoid leaking position information.
  List<_FeedbackDot> _checkAttempt(List<int> attempt) {
    assert(attempt.length == _kSlots);
    final result = List.filled(_kSlots, _FeedbackDot.absent);
    final passwordUsed = List.filled(_kSlots, false);
    final attemptUsed = List.filled(_kSlots, false);

    // Pass 1: correct symbol, correct position.
    for (int i = 0; i < _kSlots; i++) {
      if (attempt[i] == _password[i]) {
        result[i] = _FeedbackDot.correctPos;
        passwordUsed[i] = true;
        attemptUsed[i] = true;
      }
    }
    // Pass 2: correct symbol, wrong position.
    for (int i = 0; i < _kSlots; i++) {
      if (attemptUsed[i]) continue;
      for (int j = 0; j < _kSlots; j++) {
        if (!passwordUsed[j] && attempt[i] == _password[j]) {
          result[i] = _FeedbackDot.wrongPos;
          passwordUsed[j] = true;
          break;
        }
      }
    }
    result.sort((a, b) => _dotRank(a).compareTo(_dotRank(b)));
    return result;
  }

  // ── Game end ──────────────────────────────────────────────────────────────

  void _endGame({required bool won, required int completedRow}) {
    final int score;
    if (!won) {
      score = 0;
    } else if (completedRow <= 2) {
      score = 2; // won on row 0, 1, or 2 (≤3 attempts)
    } else {
      score = 1; // won on row 3 (4th attempt)
    }
    setState(() => _gameState = won ? _GameState.won : _GameState.lost);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final tier = widget.config.tierFor(score);
      widget.onComplete(tier.statEffects, tier.label, tier);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      body: SafeArea(
        child: FadeTransition(
          opacity: _introAnim,
          child: _gameState == _GameState.tutorial
              ? _buildTutorial()
              : Column(
                  children: [
                    _buildHintBar(),
                    Expanded(child: _buildLaptop()),
                    _buildSymbolPalette(),
                    _buildSubmitButton(),
                    const SizedBox(height: 16),
                  ],
                ),
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
          const Text('💻', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          const Text(
            'Il notebook di Mallow è aperto.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF2D2448),
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.3),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lex vede la schermata di login.\nPassword: ● ● ● ●\nRiesce a decifrarla?',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF6B5E8A), fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 28),
          _buildTutorialDemo(),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFDDD0F0)),
          const SizedBox(height: 20),
          _ruleCard('🎯', '4 simboli, nessun ripetuto',
              'La password è una sequenza di 4 simboli diversi scelti tra 6. Devi indovinarla.'),
          const SizedBox(height: 10),
          _ruleCard('🟢', 'Verde — simbolo e posizione giusti',
              'Quel simbolo è nella posizione corretta.'),
          const SizedBox(height: 10),
          _ruleCard('🟡', 'Giallo — simbolo presente, posizione sbagliata',
              'Quel simbolo fa parte della password, ma va in un\'altra posizione.'),
          const SizedBox(height: 10),
          _ruleCard('⬛', 'Grigio — simbolo assente',
              'Quel simbolo non è nella password.'),
          const SizedBox(height: 10),
          _ruleCard('⏱', 'Timer decrescente',
              'Ogni tentativo ha meno tempo del precedente. I slot vuoti vengono riempiti automaticamente allo scadere.'),
          const SizedBox(height: 36),
          GestureDetector(
            onTap: _startGame,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 52, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D2448),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
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
    // Static preview: one example attempt row with mixed feedback.
    final exampleSymbols = [0, 2, 4, 1]; // 🐱 ⭐ 🚀 🌙
    final exampleFeedback = [
      _FeedbackDot.correctPos,
      _FeedbackDot.wrongPos,
      _FeedbackDot.absent,
      _FeedbackDot.wrongPos,
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF252A48)),
      ),
      child: Row(
        children: [
          ...List.generate(
            _kSlots,
            (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F3A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2E3355), width: 1.5),
                  ),
                  child: Center(
                    child: Text(_kSymbols[exampleSymbols[i]],
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            height: 44,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              children: exampleFeedback.map((d) {
                final Color c;
                switch (d) {
                  case _FeedbackDot.correctPos:
                    c = const Color(0xFF4CAF50);
                    break;
                  case _FeedbackDot.wrongPos:
                    c = const Color(0xFFFFD93D);
                    break;
                  case _FeedbackDot.absent:
                    c = Colors.white12;
                    break;
                }
                return Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleCard(String icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2448).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D2448).withValues(alpha: 0.2)),
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
                        color: Color(0xFF2D2448),
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(desc,
                    style: const TextStyle(
                        color: Color(0xFF6B5E8A),
                        fontSize: 13,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hint bar ──────────────────────────────────────────────────────────────

  Widget _buildHintBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2448),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🔐 4 simboli · nessun ripetuto · tocca uno slot per pulirlo',
              style: TextStyle(
                  color: Colors.white70, fontSize: 11, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Laptop ────────────────────────────────────────────────────────────────

  Widget _buildLaptop() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Screen housing (silver, rounded top).
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFCDD4DA), Color(0xFFADB5BD)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              border: Border.all(color: const Color(0xFF8A9199), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            child: Column(
              children: [
                // Camera notch.
                Container(
                  width: 34,
                  height: 7,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(3.5),
                  ),
                ),
                const SizedBox(height: 6),
                // Screen panel.
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0E1C),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF252A48), width: 1),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _buildAttemptGrid(),
                      const SizedBox(height: 10),
                      _buildTimerBar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Hinge.
          Container(
              height: 5,
              color: const Color(0xFF8A9199),
              margin: const EdgeInsets.symmetric(horizontal: 2)),
          // Keyboard base.
          Container(
            height: 48,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFBEC5CD), Color(0xFFA8B0B8)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              border: Border(
                left: BorderSide(color: Color(0xFF8A9199), width: 1.5),
                right: BorderSide(color: Color(0xFF8A9199), width: 1.5),
                bottom: BorderSide(color: Color(0xFF8A9199), width: 1.5),
              ),
            ),
            child: _buildKeyboardDecoration(),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardDecoration() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      child: Column(
        children: [
          _keyRow(13, 3.0),
          const SizedBox(height: 3),
          _keyRow(11, 3.0),
          const SizedBox(height: 3),
          _keyRow(9, 3.0),
          const SizedBox(height: 3),
          _keyRow(7, 3.0),
        ],
      ),
    );
  }

  Widget _keyRow(int count, double h) {
    return Row(
      children: List.generate(count * 2 - 1, (i) {
        if (i.isOdd) return const SizedBox(width: 2);
        return Expanded(
          child: Container(
            height: h,
            decoration: BoxDecoration(
              color: const Color(0xFF9AA0A8),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        );
      }),
    );
  }

  // ── Attempt grid ──────────────────────────────────────────────────────────

  Widget _buildAttemptGrid() {
    return Column(
      children: List.generate(
          _kMaxAttempts,
          (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _buildAttemptRow(row),
              )),
    );
  }

  Widget _buildAttemptRow(int row) {
    final hasData = row < _feedbacks.length;
    final isActive = row == _currentRow && _gameState == _GameState.playing;

    return Row(
      children: [
        // 4 symbol slots.
        ...List.generate(
            _kSlots,
            (slot) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: _buildSlot(row, slot, isActive: isActive),
                  ),
                )),
        const SizedBox(width: 8),
        // Feedback dots (4 pips, right side).
        SizedBox(
          width: 36,
          height: 44,
          child:
              hasData ? _buildFeedbackDots(_feedbacks[row]) : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildSlot(int row, int slot, {required bool isActive}) {
    final value = _attempts[row][slot];
    final isActiveSlot = isActive && slot == _activeSlot;
    final isFuture = row > _currentRow ||
        (_gameState != _GameState.playing && _gameState != _GameState.feedback &&
            _gameState != _GameState.intro &&
            row == _currentRow &&
            _gameState != _GameState.won &&
            _gameState != _GameState.lost);

    Color bgColor = isFuture
        ? const Color(0xFF10132A)
        : const Color(0xFF1A1F3A);
    Color borderColor;
    if (isActiveSlot) {
      borderColor = const Color(0xFFFFD93D);
    } else if (isActive) {
      borderColor = const Color(0xFF3A4060);
    } else if (isFuture) {
      borderColor = Colors.white10;
    } else {
      borderColor = const Color(0xFF2E3355);
    }

    return GestureDetector(
      onTap: isActive ? () => _tapSlot(slot) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: borderColor, width: isActiveSlot ? 2.0 : 1.5),
          boxShadow: isActiveSlot
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD93D).withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: value != null
              ? Text(_kSymbols[value],
                  style: const TextStyle(fontSize: 22))
              : isActiveSlot
                  ? Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD93D),
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
        ),
      ),
    );
  }

  Widget _buildFeedbackDots(List<_FeedbackDot> dots) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      children: dots.map((d) {
        final Color c;
        switch (d) {
          case _FeedbackDot.correctPos:
            c = const Color(0xFF4CAF50);
            break;
          case _FeedbackDot.wrongPos:
            c = const Color(0xFFFFD93D);
            break;
          case _FeedbackDot.absent:
            c = Colors.white12;
            break;
        }
        return Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
      }).toList(),
    );
  }

  // ── Timer bar ─────────────────────────────────────────────────────────────

  Widget _buildTimerBar() {
    if (_gameState != _GameState.playing) {
      return const SizedBox(height: 6);
    }
    final maxTime =
        _kRowTimers[_currentRow.clamp(0, _kRowTimers.length - 1)];
    final frac = (_timeLeft / maxTime).clamp(0.0, 1.0);
    final barColor = frac > 0.5
        ? Color.lerp(const Color(0xFFFFD93D), const Color(0xFF4CAF50),
            (frac - 0.5) * 2)!
        : Color.lerp(const Color(0xFFE53935), const Color(0xFFFFD93D),
            frac * 2)!;

    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(
            '${_timeLeft.clamp(0.0, 99.0).toStringAsFixed(1)}s',
            style: TextStyle(color: barColor, fontSize: 10),
          ),
        ]),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 4,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  // ── Symbol palette ────────────────────────────────────────────────────────

  Widget _buildSymbolPalette() {
    final usedInCurrentRow = _gameState == _GameState.playing
        ? _attempts[_currentRow].whereType<int>().toSet()
        : <int>{};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_kSymbols.length, (i) {
          final isUsed = usedInCurrentRow.contains(i);
          final isActive = _gameState == _GameState.playing;
          return GestureDetector(
            onTap: isActive && !isUsed ? () => _tapSymbol(i) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isUsed
                    ? _kSymbolColors[i].withValues(alpha: 0.12)
                    : _kSymbolColors[i].withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isUsed
                      ? Colors.white10
                      : _kSymbolColors[i],
                  width: 1.5,
                ),
                boxShadow: isUsed
                    ? []
                    : [
                        BoxShadow(
                          color: _kSymbolColors[i].withValues(alpha: 0.45),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Center(
                child: Opacity(
                  opacity: isUsed ? 0.25 : 1.0,
                  child: Text(_kSymbols[i],
                      style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    final ready = _canSubmit;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: ready ? _submitAttempt : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: ready
                ? const Color(0xFF2D2448)
                : const Color(0xFF18152A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ready
                  ? const Color(0xFF6C5CE7)
                  : Colors.white10,
              width: 1.5,
            ),
            boxShadow: ready
                ? [
                    BoxShadow(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              ready ? '🔑  Tenta' : '— — — —',
              style: TextStyle(
                color: ready ? Colors.white : Colors.white24,
                fontSize: 16,
                fontWeight:
                    ready ? FontWeight.w600 : FontWeight.normal,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
