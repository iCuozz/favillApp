import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/ai/ai_client.dart';
import '../../services/ai/ai_rate_limiter.dart';
import '../../services/ai/branch_service.dart';
import '../../services/settings_service.dart';

/// Pagina interattiva per la modalità "Storia a Bivio".
///
/// Flusso:
/// 1. Empty state con TextField per lo spunto + suggerimenti rapidi.
/// 2. Genera la prima scena via [BranchService.start].
/// 3. Mostra scena (sfondo dal tag + blocchi di testo) + bottoni-scelta.
/// 4. Tap su scelta → [BranchService.choose] → next scena.
/// 5. Quando `isEnding=true` mostra la card finale + bottone "Riparti".
class BranchPlayerPage extends StatefulWidget {
  const BranchPlayerPage({super.key});

  @override
  State<BranchPlayerPage> createState() => _BranchPlayerPageState();
}

class _BranchPlayerPageState extends State<BranchPlayerPage> {
  final _service = BranchService.instance;
  final _seedController = TextEditingController();

  BranchSession? _session;
  BranchNode? _node;
  bool _loading = false;
  String? _errorBanner;

  Future<void> _start([String? overrideText]) async {
    if (_loading) return;
    final seed = (overrideText ?? _seedController.text).trim();
    if (seed.length < 5) return;

    if (!AiClient.instance.enabled) {
      setState(() => _errorBanner = AppStrings.askFavillaDisabled);
      return;
    }

    SettingsService.tapFeedback();
    setState(() {
      _loading = true;
      _errorBanner = null;
    });

    try {
      final r = await _service.start(seed);
      if (!mounted) return;
      setState(() {
        _session = r.session;
        _node = r.node;
      });
    } on AiQuotaExceeded {
      if (!mounted) return;
      setState(() => _errorBanner = AppStrings.branchQuotaExceeded);
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() => _errorBanner = e.code == 'quota_exceeded'
          ? AppStrings.branchQuotaExceeded
          : AppStrings.branchError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickChoice(BranchChoice c) async {
    final session = _session;
    if (session == null || _loading) return;

    SettingsService.tapFeedback();
    setState(() {
      _loading = true;
      _errorBanner = null;
    });

    try {
      final node = await _service.choose(session, c);
      if (!mounted) return;
      setState(() => _node = node);
    } on AiQuotaExceeded {
      if (!mounted) return;
      setState(() => _errorBanner = AppStrings.branchQuotaExceeded);
    } on AiException {
      if (!mounted) return;
      setState(() => _errorBanner = AppStrings.branchError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _restart() {
    setState(() {
      _session = null;
      _node = null;
      _errorBanner = null;
      _seedController.clear();
    });
  }

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1126),
      appBar: AppBar(
        title: Text(AppStrings.branchTitle),
        actions: [
          if (_session != null)
            IconButton(
              tooltip: AppStrings.branchRestart,
              icon: const Icon(Icons.replay),
              onPressed: _restart,
            ),
        ],
      ),
      body: _node == null ? _buildEmptyState() : _buildPlayer(),
    );
  }

  Widget _buildEmptyState() {
    final suggestions = SettingsService.language.value == AppLanguage.english
        ? const [
            'Sparkle Ale found a tube of hot glue',
            'Power outage right before dinner',
            'Suspicious silence in the bathroom',
            'A cardboard box arrived. Sparkle Ale is inside.',
          ]
        : const [
            'Sparkle Ale ha trovato un tubetto di colla a caldo',
            'Black-out proprio prima di cena',
            'Silenzio sospetto in bagno',
            'È arrivato un pacco. Dentro c\'è Sparkle Ale.',
          ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.alt_route, size: 56, color: Colors.amberAccent),
            const SizedBox(height: 12),
            Text(
              AppStrings.branchIntro,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _seedController,
              maxLines: 3,
              minLines: 2,
              maxLength: 200,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: AppStrings.branchSeedHint,
                hintStyle: TextStyle(color: Colors.white.withAlpha(140)),
                filled: true,
                fillColor: Colors.white.withAlpha(20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .map((s) => ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        onPressed: () => _start(s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : () => _start(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amberAccent.shade100,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                _loading
                    ? AppStrings.branchLoading
                    : AppStrings.branchStart,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (_errorBanner != null) ...[
              const SizedBox(height: 16),
              _errorCard(_errorBanner!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    final node = _node!;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: _SceneCard(node: node),
            ),
          ),
          if (_errorBanner != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _errorCard(_errorBanner!),
            ),
          _buildFooter(node),
        ],
      ),
    );
  }

  Widget _buildFooter(BranchNode node) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.branchThinking,
              style: TextStyle(color: Colors.white.withAlpha(200)),
            ),
          ],
        ),
      );
    }

    if (node.isEnding) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withAlpha(30),
          border: Border(
            top: BorderSide(color: Colors.amber.shade300, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              node.endingTitle?.trim().isNotEmpty == true
                  ? '🏁 ${node.endingTitle}'
                  : '🏁 ${AppStrings.branchEnding}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.amber.shade100,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.replay),
              label: Text(AppStrings.branchRestart),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amberAccent.shade100,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              AppStrings.branchChoosePrompt,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(180),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
          ...node.choices.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => _pickChoice(c),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    side: BorderSide(color: Colors.amber.shade200, width: 1.5),
                    foregroundColor: Colors.amber.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_forward_ios, size: 14),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _errorCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.shade100),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

/// Card che renderizza la scena: sfondo (asset o gradiente fallback) +
/// blocchi di testo sopra.
class _SceneCard extends StatelessWidget {
  final BranchNode node;
  const _SceneCard({required this.node});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: _gradientForTag(node.sceneTag),
          border: Border.all(color: Colors.black, width: 2.5),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🎬 ${node.sceneTag}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...node.blocks.map((b) => _buildBlock(b)),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(BranchBlock b) {
    final isNarration = b.type == 'narration';
    final isThought = b.type == 'thought';
    if (isNarration) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withAlpha(40),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade300, width: 1),
        ),
        child: Text(
          b.text,
          style: TextStyle(
            color: Colors.amber.shade100,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      );
    }
    final name = _speakerName(b.speaker);
    final color = _speakerColor(b.speaker);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(180)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isThought ? '$name 💭' : name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            b.text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
              fontStyle: isThought ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _speakerName(String id) {
    switch (id) {
      case 'favilla':
        return 'Favilla';
      case 'sparkle_ale':
        return 'Sparkle Ale';
      case 'mallow_bellow':
        return 'Mallow Bellow';
      default:
        return id;
    }
  }

  Color _speakerColor(String id) {
    switch (id) {
      case 'favilla':
        return Colors.pinkAccent.shade100;
      case 'sparkle_ale':
        return Colors.lightBlueAccent.shade100;
      case 'mallow_bellow':
        return Colors.tealAccent.shade100;
      default:
        return Colors.grey.shade300;
    }
  }

  /// Mappa tag → gradiente atmosferico (fallback finché non ci sono asset reali).
  /// Quando metterai i .webp in `assets/branch/scenes/<tag>.webp`, basta
  /// sostituire il body con `Image.asset(...)`.
  LinearGradient _gradientForTag(String tag) {
    switch (tag) {
      case 'kitchen_calm':
        return const LinearGradient(
          colors: [Color(0xFF8C5A3C), Color(0xFF3E2A1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'kitchen_chaos':
        return const LinearGradient(
          colors: [Color(0xFFC2410C), Color(0xFF7C2D12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'living_calm':
        return const LinearGradient(
          colors: [Color(0xFF4338CA), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'living_chaos':
        return const LinearGradient(
          colors: [Color(0xFFBE185D), Color(0xFF4A044E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'bedroom_night':
        return const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF0C0A1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'bathroom':
        return const LinearGradient(
          colors: [Color(0xFF0E7490), Color(0xFF164E63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'street':
        return const LinearGradient(
          colors: [Color(0xFF52525B), Color(0xFF18181B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'supermarket':
        return const LinearGradient(
          colors: [Color(0xFF15803D), Color(0xFF064E3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'blaze_aura':
        return const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'victory_glow':
        return const LinearGradient(
          colors: [Color(0xFFFCD34D), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'sad_rain':
        return const LinearGradient(
          colors: [Color(0xFF475569), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'funny_explosion':
        return const LinearGradient(
          colors: [Color(0xFFFB923C), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF4B5563), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}
