// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'models/comic_data.dart';
import 'models/game_state.dart';
import 'services/comic_loader.dart';
import 'services/engagement_service.dart';
import 'services/game_state_service.dart';
import 'services/onboarding_service.dart';
import 'services/audio_service.dart';
import 'services/progress_service.dart';
import 'services/settings_service.dart';
import 'l10n/app_strings.dart';
import 'pages/home_cover_page.dart';
import 'services/branch_history_service.dart';
import 'services/world_state_service.dart';
import 'pages/world_map_page.dart';
import 'widgets/choice_card.dart';
import 'widgets/comic_page_stage.dart';
import 'widgets/stats_hud_widget.dart';
import 'widgets/stats_intro_overlay.dart';
import 'widgets/minigame_lex_strike.dart';
import 'widgets/minigame_respira.dart';
import 'widgets/minigame_rincorsa_lex.dart';
import 'widgets/minigame_carmela_dialogo.dart';
import 'widgets/minigame_rincorsa.dart';
import 'widgets/minigame_schiva_lex.dart';

const String _kSentryDsn =
    'https://a0191b359e43ba940e6b2bc1107b81ec@o4511291384725504.ingest.de.sentry.io/4511291387543632';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.init();
  await GameStateService.instance.init();
  await WorldStateService.instance.init();
  await AudioService.instance.init();

  await SentryFlutter.init(
    (options) {
      options.dsn = _kSentryDsn;
      options.environment = kReleaseMode ? 'production' : 'debug';
      options.tracesSampleRate = 0.2;
      options.sendDefaultPii = false;
      // In debug evita di spammare Sentry durante lo sviluppo locale.
      options.beforeSend = (event, hint) {
        if (kDebugMode) return null;
        return event;
      };
    },
    appRunner: () => runApp(const MyApp()),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hook per future integrazioni al resume dell'app.
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: SettingsService.language,
      builder: (context, lang, _) {
        return MaterialApp(
          key: ValueKey('app-${lang.code}'),
          title: 'Favilla Blaze',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          locale: Locale(lang.code),
          supportedLocales: const [Locale('it'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppBootstrapPage(),
        );
      },
    );
  }
}

class AppBootstrapPage extends StatelessWidget {
  const AppBootstrapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ComicIndex>(
      future: ComicLoader.loadIndex(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Favilla Blaze'),
            ),
            body: Center(
              child: Text('Errore: ${snapshot.error}'),
            ),
          );
        }

        final comicIndex = snapshot.data!;

        return HomeCoverPage(
          comicIndex: comicIndex,
        );
      },
    );
  }
}

class EpisodeLoaderPage extends StatelessWidget {
  final ComicIndex comicIndex;
  final EpisodeSummary summary;
  final int initialPageIndex;
  final int initialVisibleBlocks;
  final String? initialBranchId;

  /// Branch di entry ripristinato da un salvataggio precedente.
  /// Se fornito, viene usato direttamente senza ri-valutare stat_entry,
  /// garantendo coerenza degli indici di pagina anche se le stat sono cambiate.
  final String? initialEntryBranchId;

  final Future<void> Function()? onEpisodeCompleted;

  const EpisodeLoaderPage({
    super.key,
    required this.comicIndex,
    required this.summary,
    this.initialPageIndex = 0,
    this.initialVisibleBlocks = 1,
    this.initialBranchId,
    this.initialEntryBranchId,
    this.onEpisodeCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EpisodeContent>(
      future: ComicLoader.loadEpisodeContent(summary.file),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              title: Text(summary.title),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(summary.title),
            ),
            body: Center(
              child: Text('Errore: ${snapshot.error}'),
            ),
          );
        }

        final content = snapshot.data!;

        // Risolve stat_entry: usa il branch salvato se presente (per coerenza
        // degli indici di pagina), altrimenti valuta le regole correnti.
        String? resolvedEntryBranchId = initialEntryBranchId;
        bool resolvedEntryBranchIsPrepend = false;
        if (resolvedEntryBranchId == null && content.statEntry.isNotEmpty) {
          final stats = GameStateService.instance.state.value.toStatsMap();
          final flags = GameStateService.instance.state.value.flags;
          resolvedEntryBranchId = content.resolveEntryBranch(stats, flags);
        }
        if (resolvedEntryBranchId != null) {
          resolvedEntryBranchIsPrepend =
              content.isEntryBranchPrepend(resolvedEntryBranchId);
        }

        final episode = Episode(
          id: summary.id,
          title: summary.title,
          subtitle: summary.subtitle,
          thumbnail: summary.thumbnail,
          pages: content.pages,
          branches: content.branches,
          epilogue: content.epilogue,
          audioTheme: content.audioTheme,
        );

        return EpisodePage(
          comicIndex: comicIndex,
          episode: episode,
          initialPageIndex: initialPageIndex,
          initialVisibleBlocks: initialVisibleBlocks,
          initialBranchId: initialBranchId,
          initialEntryBranchId: resolvedEntryBranchId,
          initialEntryBranchIsPrepend: resolvedEntryBranchIsPrepend,
          onEpisodeCompleted: onEpisodeCompleted,
        );
      },
    );
  }
}

class EpisodePage extends StatefulWidget {
  final ComicIndex comicIndex;
  final Episode episode;
  final int initialPageIndex;
  final int initialVisibleBlocks;

  /// Branch ripristinato da salvataggio progresso (scelta già fatta in precedenza).
  final String? initialBranchId;

  /// Branch imposto da stat_entry all'avvio: sostituisce le pagine main (replace)
  /// o vi si antepone (prepend). Immutabile dopo l'init.
  final String? initialEntryBranchId;

  /// Se true, il branch di entry è in modalità prepend (anteposto alle pagine main).
  /// Se false (default), sostituisce le pagine main.
  final bool initialEntryBranchIsPrepend;

  final Future<void> Function()? onEpisodeCompleted;

  const EpisodePage({
    super.key,
    required this.comicIndex,
    required this.episode,
    this.initialPageIndex = 0,
    this.initialVisibleBlocks = 1,
    this.initialBranchId,
    this.initialEntryBranchId,
    this.initialEntryBranchIsPrepend = false,
    this.onEpisodeCompleted,
  });

  @override
  State<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends State<EpisodePage> {
  late final PageController _pageController;
  final FocusNode _focusNode = FocusNode();

  late int currentIndex;
  late int _maxVisitedIndex;

  /// Branch imposto da stat_entry: sostituisce o antepone le pagine main. Immutabile.
  String? _entryBranchId;

  /// Se true, il branch di entry è in modalità prepend.
  bool _entryBranchIsPrepend = false;

  /// Branch attivato dalla prima scelta del giocatore.
  String? _activeBranchId;

  /// Branch attivato dalla seconda scelta (es. nell'epilogo).
  String? _secondBranchId;

  final Set<int> _resolvedChoiceIndices = {};
  bool _choiceSheetOpen = false;
  bool _showStatsIntro = false;
  Map<String, int>? _pendingStatEffects;
  final Map<int, GlobalKey<ComicPageStageState>> _stageKeys = {};
  final Map<int, int> _visibleBlocksByPage = {};

  /// Ritorna le pagine effettive da renderizzare nel PageView.
  ///
  /// Modalità entry branch replace (stat_entry, prepend: false):
  ///   entryBranch.pages + [choiceBranch.pages] + [epilogue.pages if choiceBranch]
  ///
  /// Modalità entry branch prepend (stat_entry, prepend: true):
  ///   entryBranch.pages + episode.pages + [choiceBranch.pages] + [epilogue.pages] + [secondBranch.pages]
  ///
  /// Modalità normale:
  ///   episode.pages + [choiceBranch.pages] + [epilogue.pages] + [secondBranch.pages]
  List<ComicPage> get _effectivePages {
    final ep = widget.episode;

    if (_entryBranchId != null) {
      final entryBranch = ep.branches[_entryBranchId!];
      if (entryBranch == null) return ep.pages;

      if (_entryBranchIsPrepend) {
        // Modalità prepend: entry branch anteposto, poi flusso normale
        final branch =
            _activeBranchId != null ? ep.branches[_activeBranchId!] : null;
        if (branch == null) {
          return [...entryBranch.pages, ...ep.pages];
        }
        final secondBranch =
            _secondBranchId == null ? null : ep.branches[_secondBranchId];
        return [
          ...entryBranch.pages,
          ...ep.pages,
          ...branch.pages,
          if (ep.epilogue != null && !(branch.skipsEpilogue)) ...ep.epilogue!.pages,
          if (secondBranch != null) ...secondBranch.pages,
        ];
      }

      // Modalità replace: entry branch sostituisce le pagine main
      final choiceBranch =
          _activeBranchId != null ? ep.branches[_activeBranchId!] : null;
      return [
        ...entryBranch.pages,
        if (choiceBranch != null) ...choiceBranch.pages,
        if (choiceBranch != null && ep.epilogue != null && !(choiceBranch.skipsEpilogue))
          ...ep.epilogue!.pages,
      ];
    }

    if (!ep.hasBranches) return ep.pages;
    final branch =
        _activeBranchId != null ? ep.branches[_activeBranchId!] : null;
    if (branch == null) return ep.pages;

    // Scelta normale: branch appeso dopo le pagine main
    final secondBranch =
        _secondBranchId == null ? null : ep.branches[_secondBranchId];

    return [
      ...ep.pages,
      ...branch.pages,
      if (ep.epilogue != null && !branch.skipsEpilogue) ...ep.epilogue!.pages,
      if (secondBranch != null) ...secondBranch.pages,
    ];
  }

  @override
  void initState() {
    super.initState();
    _entryBranchId = widget.initialEntryBranchId;
    _entryBranchIsPrepend = widget.initialEntryBranchIsPrepend;
    _activeBranchId = widget.initialBranchId;
    final pages = _effectivePages;
    final maxIndex = pages.isEmpty ? 0 : pages.length - 1;
    currentIndex = widget.initialPageIndex.clamp(0, maxIndex);
    _maxVisitedIndex = currentIndex;
    _visibleBlocksByPage[currentIndex] = widget.initialVisibleBlocks;
    _pageController = PageController(initialPage: currentIndex);

    _saveProgress();
    _applyFullscreen(SettingsService.fullscreenReading.value);
    SettingsService.fullscreenReading.addListener(_onFullscreenChanged);

    // Mostra tutorial stat la prima volta (non nel prologo)
    if (widget.episode.id != 'prologo') {
      OnboardingService.instance.hasSeenStatsIntro().then((seen) {
        if (!seen && mounted) setState(() => _showStatsIntro = true);
      });
    }

    // Avvia musica ambientale dell'episodio
    AudioService.instance.playAmbient(widget.episode.audioTheme);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _precacheNeighbors(currentIndex);
      }
    });
  }

  void _precacheNeighbors(int index) {
    final pages = _effectivePages;
    for (final offset in const [1, -1, 2]) {
      final neighbor = index + offset;
      if (neighbor >= 0 && neighbor < pages.length) {
        final asset = pages[neighbor].background;
        if (asset.isNotEmpty) {
          precacheImage(AssetImage(asset), context);
        }
      }
    }
  }

  void _onFullscreenChanged() {
    _applyFullscreen(SettingsService.fullscreenReading.value);
  }

  void _applyFullscreen(bool enabled) {
    if (enabled) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  @override
  void dispose() {
    SettingsService.fullscreenReading.removeListener(_onFullscreenChanged);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _pageController.dispose();
    _focusNode.dispose();
    AudioService.instance.stopAmbient();
    super.dispose();
  }

  void _saveProgress() {
    final blocks = _visibleBlocksByPage[currentIndex] ?? 1;
    ProgressService.saveCurrent(
      episodeId: widget.episode.id,
      pageIndex: currentIndex,
      visibleBlocks: blocks,
      branchId: _activeBranchId,
      entryBranchId: _entryBranchId,
    );
  }

  void _handleVisibleBlocksChanged(int pageIndex, int blocks) {
    _visibleBlocksByPage[pageIndex] = blocks;
    if (pageIndex == currentIndex) {
      _saveProgress();
    }
  }

  GlobalKey<ComicPageStageState> _keyForPage(int pageIndex) {
    return _stageKeys.putIfAbsent(
      pageIndex,
      () => GlobalKey<ComicPageStageState>(),
    );
  }

  void _goToNextEpisodeOrFinish() {
    ProgressService.markCompleted(widget.episode.id);
    EngagementService.onEpisodeCompleted();

    // Chiama il callback custom (es. WorldStateService.completeQuest per le quest)
    if (widget.onEpisodeCompleted != null) {
      widget.onEpisodeCompleted!().then((_) => _afterCompletion());
    } else {
      _afterCompletion();
    }
  }

  void _afterCompletion() {
    ProgressService.clearCurrent();
    _goToWorldMap();
  }

  void _goToWorldMap() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => WorldMapPage(comicIndex: widget.comicIndex),
      ),
      (route) => route.isFirst,
    );
  }

  void _goToNextPage() {
    final pages = _effectivePages;

    // Se la pagina corrente propone una scelta non ancora risolta,
    // blocchiamo l'avanzamento e mostriamo la card di scelta.
    if (currentIndex < pages.length) {
      final currentPage = pages[currentIndex];
      if (currentPage.choice != null &&
          !_resolvedChoiceIndices.contains(currentIndex)) {
        _promptChoice(currentPage.choice!);
        return;
      }
    }

    if (currentIndex < pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _goToNextEpisodeOrFinish();
    }
  }

  void _promptChoice(Choice choice) {
    if (_choiceSheetOpen) return;
    _choiceSheetOpen = true;
    SettingsService.tapFeedback();

    // Filtra le opzioni che porterebbero una stat sotto il suo floor.
    // Garantisce che i floor non vengano mai violati tramite scelta del giocatore.
    // Regola narrativa: ogni scelta deve avere SEMPRE almeno un'opzione sicura.
    final currentStats = GameStateService.instance.state.value;
    final safeOptions = choice.options.where((opt) {
      for (final entry in opt.statEffects.entries) {
        final floor = StatKey.minValues[entry.key] ?? 0;
        if (currentStats[entry.key] + entry.value < floor) return false;
      }
      return true;
    }).toList();
    // Safety net: se tutte le opzioni violano i floor (errore di authoring),
    // mostra comunque tutto per evitare un dead end.
    final filteredChoice = Choice(
      id: choice.id,
      prompt: choice.prompt,
      options: safeOptions.isNotEmpty ? safeOptions : choice.options,
    );

    // Auto-avvio: se c'è una sola opzione con minigame, salta lo sheet e
    // lancia direttamente il minigame (narrativa lineare, nessuna scelta esplicita).
    if (filteredChoice.options.length == 1 &&
        filteredChoice.options.first.minigame != null) {
      _choiceSheetOpen = false;
      _handleChoiceSelected(filteredChoice.options.first);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ChoiceCard(
              choice: filteredChoice,
              onSelected: (option) {
                Navigator.of(sheetContext).pop();
                _handleChoiceSelected(option);
              },
            ),
          ),
        );
      },
    ).whenComplete(() {
      _choiceSheetOpen = false;
    });
  }

  void _handleChoiceSelected(ChoiceOption option) {
    AudioService.instance.playSfx(SfxEvent.choiceSelect);
    if (option.minigame == null) {
      _applyEffectsAndNavigate(option);
      return;
    }
    final cfg = option.minigame!;
    switch (cfg.type) {
      case 'lex_strike':
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => MinigameLexStrikeScreen(
              config: cfg,
              onComplete: (effects, label, tier) {
                Navigator.of(context).pop();
                final branch = tier.gotoBranch.isNotEmpty ? tier.gotoBranch : null;
                final isSuccess = tier.minProducts > 0;
                AudioService.instance.playSfx(isSuccess ? SfxEvent.minigameSuccess : SfxEvent.minigameFail);
                _applyEffectsAndNavigate(option,
                    overrideEffects: effects, overrideBranch: branch);
              },
            ),
          ),
        );
      case 'respira':
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => MinigameRespiraScreen(
              config: cfg,
              onComplete: (effects, label, tier) {
                Navigator.of(context).pop();
                final branch = tier.gotoBranch.isNotEmpty ? tier.gotoBranch : null;
                final isSuccess = tier.minProducts > 0;
                AudioService.instance.playSfx(isSuccess ? SfxEvent.minigameSuccess : SfxEvent.minigameFail);
                _applyEffectsAndNavigate(option,
                    overrideEffects: effects, overrideBranch: branch);
              },
            ),
          ),
        );
      case 'schiva_lex':
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => MinigameSchivaSscreen(
              config: cfg,
              onComplete: (effects, label, tier) {
                Navigator.of(context).pop();
                final branch = tier.gotoBranch.isNotEmpty ? tier.gotoBranch : null;
                final isSuccess = tier.minProducts > 0;
                AudioService.instance.playSfx(isSuccess ? SfxEvent.minigameSuccess : SfxEvent.minigameFail);
                _applyEffectsAndNavigate(option,
                    overrideEffects: effects, overrideBranch: branch);
              },
            ),
          ),
        );
      case 'carmela_dialogo':
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => MinigameCarmelaDialogoScreen(
              config: cfg,
              onComplete: (effects, label, tier) {
                Navigator.of(context).pop();
                final branch = tier.gotoBranch.isNotEmpty ? tier.gotoBranch : null;
                final flags = tier.setFlags.isNotEmpty ? tier.setFlags : null;
                final isSuccess = tier.minProducts >= 2;
                AudioService.instance.playSfx(
                    isSuccess ? SfxEvent.minigameSuccess : SfxEvent.minigameFail);
                _applyEffectsAndNavigate(option,
                    overrideEffects: effects,
                    overrideBranch: branch,
                    overrideFlags: flags);
              },
            ),
          ),
        );
      case 'rincorsa_lex':
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => MinigameRincorsaLexScreen(
              config: cfg,
              onComplete: (effects, label, tier) {
                Navigator.of(context).pop();
                final branch =
                    tier.gotoBranch.isNotEmpty ? tier.gotoBranch : null;
                final isSuccess = tier.minProducts >= 3;
                AudioService.instance.playSfx(
                    isSuccess ? SfxEvent.minigameSuccess : SfxEvent.minigameFail);
                _applyEffectsAndNavigate(option,
                    overrideEffects: effects, overrideBranch: branch);
              },
            ),
          ),
        );
      case 'rincorsa':
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => MinigameRincorsaScreen(
              config: cfg,
              onComplete: (effects, label, tier) {
                Navigator.of(context).pop();
                // Se tier 0 (trasformazione forzata), la trasformazione accade
                // solo se la resistenza è già sotto soglia critica.
                // Con resistenza >= 30, il fallimento totale resta grave ma
                // non supera il limite — Favilla non trasforma.
                var effectiveTier = tier;
                if (tier.minProducts == 0) {
                  final currentResistenza =
                      GameStateService.instance.state.value.resistenza;
                  if (currentResistenza >= 30) {
                    effectiveTier = cfg.tierFor(1); // scala a tier "quasi"
                  }
                }
                final branch = effectiveTier.gotoBranch.isNotEmpty
                    ? effectiveTier.gotoBranch
                    : null;
                final flags = effectiveTier.setFlags.isNotEmpty
                    ? effectiveTier.setFlags
                    : null;
                final isSuccess = effectiveTier.minProducts > 0;
                AudioService.instance
                    .playSfx(isSuccess ? SfxEvent.minigameSuccess : SfxEvent.minigameFail);
                _applyEffectsAndNavigate(option,
                    overrideEffects: effectiveTier.statEffects,
                    overrideBranch: branch,
                    overrideFlags: flags);
              },
            ),
          ),
        );
      default:
        // Tipo sconosciuto: applica effetti base dell'opzione
        _applyEffectsAndNavigate(option);
    }
  }

  void _applyEffectsAndNavigate(ChoiceOption option,
      {Map<String, int>? overrideEffects,
      String? overrideBranch,
      Map<String, bool>? overrideFlags}) {
    final episodeId = widget.episode.id;
    final branchId = overrideBranch ?? option.gotoBranch;
    final effects = overrideEffects ?? option.statEffects;
    final newFlags = overrideFlags ?? option.setFlags;

    // Applica effetti stat + world flags atomicamente.
    if (effects.isNotEmpty || newFlags.isNotEmpty) {
      GameStateService.instance.applyChoice(effects: effects, newFlags: newFlags);
      if (effects.isNotEmpty) setState(() => _pendingStatEffects = effects);
    }

    setState(() {
      _resolvedChoiceIndices.add(currentIndex);
      if (branchId.isNotEmpty) {
        if (_activeBranchId == null) {
          _activeBranchId = branchId;
        } else if (_entryBranchId == null || _entryBranchIsPrepend) {
          // Seconda scelta: consentita in modalità normale e in modalità prepend
          _secondBranchId = branchId;
        }
        // In modalità entry branch replace una sola scelta è supportata
        _visibleBlocksByPage.removeWhere((k, _) => k > currentIndex);
        _stageKeys.removeWhere((k, _) => k > currentIndex);
        if (_maxVisitedIndex < currentIndex) _maxVisitedIndex = currentIndex;
      }
    });

    if (branchId.isNotEmpty) {
      BranchHistoryService.markUnlocked(episodeId, branchId);
      _saveProgress();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pages = _effectivePages;
        if (currentIndex < pages.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  void _goToPreviousPage() {
    if (currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _advanceCurrentStageOrPage() {
    SettingsService.tapFeedback();
    AudioService.instance.playSfx(SfxEvent.tapPanel);
    final stageKey = _keyForPage(currentIndex);
    final stageState = stageKey.currentState;

    if (stageState != null) {
      stageState.advance();
    } else {
      _goToNextPage();
    }
  }

  void _goBackBlockOrPage() {
    SettingsService.tapFeedback();
    final stageKey = _keyForPage(currentIndex);
    final stageState = stageKey.currentState;

    if (stageState != null) {
      final handled = stageState.goBackBlock();
      if (!handled) {
        _goToPreviousPage();
      }
    } else {
      _goToPreviousPage();
    }
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    const minVelocity = 250.0;
    final velocity = details.primaryVelocity ?? 0;

    if (velocity < -minVelocity) {
      _advanceCurrentStageOrPage();
    } else if (velocity > minVelocity) {
      _goBackBlockOrPage();
    }
  }


  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _advanceCurrentStageOrPage();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goBackBlockOrPage();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _effectivePages;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.episode.title),
        actions: [
          IconButton(
            tooltip: AppStrings.hapticsTooltip,
            icon: ValueListenableBuilder<bool>(
              valueListenable: SettingsService.hapticsEnabled,
              builder: (context, enabled, _) {
                return Icon(
                  enabled ? Icons.vibration : Icons.do_not_disturb_on_outlined,
                );
              },
            ),
            onPressed: () {
              final enabled = SettingsService.hapticsEnabled.value;
              SettingsService.setHapticsEnabled(!enabled);
              if (!enabled) {
                HapticFeedback.selectionClick();
              }
            },
          ),
          IconButton(
            tooltip: AppStrings.share,
            icon: const Icon(Icons.share),
            onPressed: () {
              SettingsService.tapFeedback();
              EngagementService.shareEpisode(widget.episode.title);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.black26,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.pageOf(currentIndex + 1, pages.length),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value:
                          pages.isEmpty ? 0 : (currentIndex + 1) / pages.length,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.pinkAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(child: StatsHudWidget()),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: _handleHorizontalSwipe,
                    child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                    if (index > _maxVisitedIndex) {
                      _maxVisitedIndex = index;
                    }
                  });
                  _visibleBlocksByPage.putIfAbsent(index, () => 1);
                  _saveProgress();
                  _precacheNeighbors(index);

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _focusNode.requestFocus();
                    }
                  });
                },
                itemBuilder: (context, index) {
                  final page = pages[index];
                  final stageKey = _keyForPage(index);
                  final initialBlocks = _visibleBlocksByPage[index] ?? 1;

                  final stage = Padding(
                    padding: const EdgeInsets.all(12),
                    child: ComicPageStage(
                      key: stageKey,
                      comicIndex: widget.comicIndex,
                      page: page,
                      pageViewIndex: index,
                      initialVisibleBlocks: initialBlocks,
                      onVisibleBlocksChanged: (blocks) =>
                          _handleVisibleBlocksChanged(index, blocks),
                      onPageCompleted: _goToNextPage,
                    ),
                  );

                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double delta = 0;
                      if (_pageController.position.haveDimensions) {
                        delta = (_pageController.page ?? index.toDouble()) - index;
                      }
                      final clamped = delta.clamp(-1.0, 1.0);
                      final rotation = clamped * 0.9;
                      final scale = 1 - (clamped.abs() * 0.18);
                      final opacity = (1 - clamped.abs() * 0.7).clamp(0.0, 1.0);

                      return Transform(
                        alignment: clamped >= 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0015)
                          ..rotateY(rotation)
                          ..scaleByDouble(scale, scale, 1.0, 1.0),
                        child: Opacity(
                          opacity: opacity,
                          child: child,
                        ),
                      );
                    },
                    child: stage,
                  );
                },
                ),
              ),
              // Toast degli effetti stat dopo una scelta
              if (_pendingStatEffects != null)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: StatEffectToast(
                      key: ValueKey(_pendingStatEffects.hashCode),
                      effects: _pendingStatEffects!,
                      onDone: () => setState(() => _pendingStatEffects = null),
                    ),
                  ),
                ),
            ],
          ),
        ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _goBackBlockOrPage,
                      child: const Text('Indietro'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _advanceCurrentStageOrPage,
                      child: const Text('Avanti'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
          // Overlay onboarding stat — mostrato una sola volta al primo episodio
          if (_showStatsIntro)
            Positioned.fill(
              child: StatsIntroOverlay(
                onDismiss: () => setState(() => _showStatsIntro = false),
              ),
            ),
        ],
      ),
    );
  }
}

