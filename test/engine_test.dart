// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:favilla_app/models/game_state.dart';
import 'package:favilla_app/models/comic_data.dart';
import 'package:favilla_app/services/game_state_service.dart';

void main() {
  // ─── GameState ──────────────────────────────────────────────────────────

  group('GameState', () {
    test('valori di default', () {
      const gs = GameState();
      expect(gs.segreto, 50);
      expect(gs.legame, 50);
      expect(gs.scintille, 50);
      expect(gs.resistenza, 50);
      expect(gs.flags, isEmpty);
    });

    test('applyChoice aggiorna le stat', () {
      const gs = GameState(segreto: 50, resistenza: 50);
      final next = gs.applyChoice(effects: {'segreto': 10, 'resistenza': -5});
      expect(next.segreto, 60);
      expect(next.resistenza, 45);
    });

    test('applyChoice clamp al massimo (100)', () {
      const gs = GameState(segreto: 95);
      final next = gs.applyChoice(effects: {'segreto': 20});
      expect(next.segreto, 100);
    });

    test('applyChoice clamp al minimo (minValues)', () {
      // segreto min = 5
      const gs = GameState(segreto: 6);
      final next = gs.applyChoice(effects: {'segreto': -10});
      expect(next.segreto, 5);
    });

    test('applyChoice preserva i flags esistenti', () {
      const gs = GameState(flags: const {'shirt_in_backpack': true});
      final next = gs.applyChoice(effects: {'segreto': 5});
      expect(next.flags['shirt_in_backpack'], isTrue);
      expect(next.segreto, 55);
    });

    test('applyChoice aggiorna i flags specificati', () {
      const gs = GameState(flags: const {'shirt_in_backpack': true});
      final next = gs.applyChoice(newFlags: {'shirt_in_backpack': false});
      expect(next.flags['shirt_in_backpack'], isFalse);
    });

    test('applyChoice flags e stat insieme atomicamente', () {
      const gs = GameState(segreto: 50);
      final next = gs.applyChoice(
        effects: {'segreto': -15},
        newFlags: {'shirt_in_backpack': false},
      );
      expect(next.segreto, 35);
      expect(next.flags['shirt_in_backpack'], isFalse);
    });

    test('applyEffects retrocompatibilità preserva i flags', () {
      const gs = GameState(flags: const {'mio_flag': true});
      final next = gs.applyEffects({'legame': 10});
      expect(next.flags['mio_flag'], isTrue);
      expect(next.legame, 60);
    });

    test('toStatsMap restituisce solo le stat', () {
      const gs = GameState(segreto: 70, flags: const {'x': true});
      final map = gs.toStatsMap();
      expect(map['segreto'], 70);
      expect(map.containsKey('x'), isFalse);
    });

    test('fromMaps costruisce correttamente', () {
      final gs = GameState.fromMaps(
        stats: {'segreto': 30, 'legame': 60, 'scintille': 40, 'resistenza': 80},
        flags: {'shirt_in_backpack': true},
      );
      expect(gs.segreto, 30);
      expect(gs.flags['shirt_in_backpack'], isTrue);
    });

    test('flag assente vale false', () {
      const gs = GameState();
      expect(gs.flags['shirt_in_backpack'], isNull); // assente
    });
  });

  // ─── StatCondition ──────────────────────────────────────────────────────

  group('StatCondition', () {
    test('lt', () {
      const c = StatCondition(stat: 'segreto', op: 'lt', value: 50);
      expect(c.matches({'segreto': 49}), isTrue);
      expect(c.matches({'segreto': 50}), isFalse);
    });

    test('gte', () {
      const c = StatCondition(stat: 'resistenza', op: 'gte', value: 55);
      expect(c.matches({'resistenza': 55}), isTrue);
      expect(c.matches({'resistenza': 54}), isFalse);
    });

    test('stat assente vale 0', () {
      const c = StatCondition(stat: 'segreto', op: 'lt', value: 10);
      expect(c.matches({}), isTrue); // 0 < 10
    });
  });

  // ─── FlagCondition ──────────────────────────────────────────────────────

  group('FlagCondition', () {
    test('flag true corrisponde', () {
      const fc = FlagCondition(flag: 'shirt_in_backpack', expectedValue: true);
      expect(fc.matches({'shirt_in_backpack': true}), isTrue);
      expect(fc.matches({'shirt_in_backpack': false}), isFalse);
    });

    test('flag assente equivale a false', () {
      const fc = FlagCondition(flag: 'shirt_in_backpack', expectedValue: false);
      expect(fc.matches({}), isTrue);
    });

    test('fromJson', () {
      final fc =
          FlagCondition.fromJson({'flag': 'shirt_in_backpack', 'is': true});
      expect(fc.flag, 'shirt_in_backpack');
      expect(fc.expectedValue, isTrue);
    });
  });

  // ─── StatEntryRule ──────────────────────────────────────────────────────

  group('StatEntryRule', () {
    test('singola stat', () {
      const rule = StatEntryRule(
        stat: 'segreto',
        op: 'lt',
        value: 50,
        gotoBranch: 'branch_a',
      );
      expect(rule.matches({'segreto': 40}, {}), isTrue);
      expect(rule.matches({'segreto': 50}, {}), isFalse);
    });

    test('all_of AND logica', () {
      const rule = StatEntryRule(
        stat: '',
        op: 'lt',
        value: 0,
        gotoBranch: 'branch_b',
        allOf: [
          StatCondition(stat: 'segreto', op: 'lt', value: 50),
          StatCondition(stat: 'resistenza', op: 'gte', value: 55),
        ],
      );
      expect(rule.matches({'segreto': 40, 'resistenza': 60}, {}), isTrue);
      expect(rule.matches({'segreto': 40, 'resistenza': 50}, {}), isFalse);
      expect(rule.matches({'segreto': 55, 'resistenza': 60}, {}), isFalse);
    });

    test('flag_conditions con stat', () {
      const rule = StatEntryRule(
        stat: 'segreto',
        op: 'lt',
        value: 50,
        gotoBranch: 'intro_indosso',
        flagConditions: [
          FlagCondition(flag: 'shirt_in_backpack', expectedValue: false)
        ],
      );
      // shirt on body + low segreto → match
      expect(
          rule.matches({'segreto': 35}, {'shirt_in_backpack': false}), isTrue);
      // shirt in backpack + low segreto → no match
      expect(
          rule.matches({'segreto': 35}, {'shirt_in_backpack': true}), isFalse);
      // shirt on body + high segreto → no match (stat fails)
      expect(
          rule.matches({'segreto': 60}, {'shirt_in_backpack': false}), isFalse);
    });

    test('ordine regole: prima match vince', () {
      final rules = [
        const StatEntryRule(
          stat: 'segreto',
          op: 'lt',
          value: 50,
          gotoBranch: 'indosso',
          flagConditions: [
            FlagCondition(flag: 'shirt_in_backpack', expectedValue: false)
          ],
        ),
        const StatEntryRule(
            stat: 'segreto', op: 'lt', value: 50, gotoBranch: 'zaino'),
      ];
      final stats = {'segreto': 35};
      final flagsIndosso = {'shirt_in_backpack': false};
      final flagsZaino = {'shirt_in_backpack': true};

      // Primo check: shirt on body → prima regola vince
      String? result;
      for (final r in rules) {
        if (r.matches(stats, flagsIndosso)) {
          result = r.gotoBranch;
          break;
        }
      }
      expect(result, 'indosso');

      // Secondo check: shirt in backpack → seconda regola vince
      result = null;
      for (final r in rules) {
        if (r.matches(stats, flagsZaino)) {
          result = r.gotoBranch;
          break;
        }
      }
      expect(result, 'zaino');
    });

    test('fromJson con flag_conditions', () {
      final rule = StatEntryRule.fromJson({
        'stat': 'segreto',
        'op': 'lt',
        'value': 50,
        'goto_branch': 'intro_indosso',
        'flag_conditions': [
          {'flag': 'shirt_in_backpack', 'is': false}
        ],
      });
      expect(rule.gotoBranch, 'intro_indosso');
      expect(rule.flagConditions.length, 1);
      expect(rule.flagConditions.first.flag, 'shirt_in_backpack');
      expect(rule.flagConditions.first.expectedValue, isFalse);
    });
  });

  // ─── ChoiceOption ────────────────────────────────────────────────────────

  group('ChoiceOption', () {
    test('parsing base', () {
      final opt = ChoiceOption.fromJson({
        'id': 'bagno',
        'label': 'Corre in bagno.',
        'goto_branch': 'branch_bagno',
        'stat_effects': {'segreto': 15, 'resistenza': -10},
      });
      expect(opt.id, 'bagno');
      expect(opt.statEffects['segreto'], 15);
      expect(opt.setFlags, isEmpty);
    });

    test('parsing set_flags', () {
      final opt = ChoiceOption.fromJson({
        'id': 'bagno',
        'label': 'Corre in bagno.',
        'goto_branch': 'branch_bagno',
        'stat_effects': {'segreto': 15},
        'set_flags': {'shirt_in_backpack': true},
      });
      expect(opt.setFlags['shirt_in_backpack'], isTrue);
    });

    test('set_flags vuoti se non presenti', () {
      final opt = ChoiceOption.fromJson({
        'id': 'finge_niente',
        'label': 'Rimane.',
        'goto_branch': 'branch_finge',
      });
      expect(opt.setFlags, isEmpty);
    });
  });

  // ─── EpisodeContent.resolveEntryBranch ─────────────────────────────────

  group('EpisodeContent.resolveEntryBranch', () {
    final ep = EpisodeContent(
      id: 'test_ep',
      pages: [],
      statEntry: [
        const StatEntryRule(
          stat: 'segreto',
          op: 'lt',
          value: 50,
          gotoBranch: 'intro_indosso',
          flagConditions: [
            FlagCondition(flag: 'shirt_in_backpack', expectedValue: false)
          ],
        ),
        const StatEntryRule(
            stat: 'segreto', op: 'lt', value: 50, gotoBranch: 'intro_zaino'),
      ],
    );

    test('camicia addosso → intro_indosso', () {
      expect(
        ep.resolveEntryBranch({'segreto': 35}, {'shirt_in_backpack': false}),
        'intro_indosso',
      );
    });

    test('camicia in zaino → intro_zaino', () {
      expect(
        ep.resolveEntryBranch({'segreto': 35}, {'shirt_in_backpack': true}),
        'intro_zaino',
      );
    });

    test('segreto alto → nessun entry branch', () {
      expect(
        ep.resolveEntryBranch({'segreto': 60}, {}),
        isNull,
      );
    });

    test('flag assente = false → intro_indosso', () {
      // Nessun flag impostato = shirt_in_backpack non presente = false
      expect(
        ep.resolveEntryBranch({'segreto': 35}, {}),
        'intro_indosso',
      );
    });
  });

  // ─── GameStateService persistenza ──────────────────────────────────────

  group('GameStateService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('init con valori vuoti → stato default', () async {
      await GameStateService.instance.init();
      final gs = GameStateService.instance.state.value;
      expect(gs.segreto, 50);
      expect(gs.flags, isEmpty);
    });

    test('applyChoice persiste stat e flags', () async {
      await GameStateService.instance.init();
      await GameStateService.instance.applyChoice(
        effects: {'segreto': -20},
        newFlags: {'shirt_in_backpack': true},
      );
      final gs = GameStateService.instance.state.value;
      expect(gs.segreto, 30);
      expect(gs.flags['shirt_in_backpack'], isTrue);
    });

    test('init ricarica stat e flags salvati', () async {
      SharedPreferences.setMockInitialValues({
        'game_state.segreto': 35,
        'game_state.legame': 60,
        'game_state.scintille': 50,
        'game_state.resistenza': 45,
        'game_state.flags': '{"shirt_in_backpack":true}',
      });
      await GameStateService.instance.init();
      final gs = GameStateService.instance.state.value;
      expect(gs.segreto, 35);
      expect(gs.flags['shirt_in_backpack'], isTrue);
    });

    test('reset azzera stat e rimuove flags', () async {
      await GameStateService.instance.init();
      await GameStateService.instance.applyChoice(
        effects: {'segreto': 20},
        newFlags: {'shirt_in_backpack': true},
      );
      await GameStateService.instance.reset();
      final gs = GameStateService.instance.state.value;
      expect(gs.segreto, 50);
      expect(gs.flags, isEmpty);

      // Verifica anche che SharedPreferences sia pulito
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('game_state.flags'), isNull);
    });

    test('applyEffects retrocompatibilità preserva flags', () async {
      await GameStateService.instance.init();
      await GameStateService.instance
          .applyChoice(newFlags: {'shirt_in_backpack': true});
      await GameStateService.instance.applyEffects({'legame': 10});
      final gs = GameStateService.instance.state.value;
      expect(gs.flags['shirt_in_backpack'], isTrue); // non perso
      expect(gs.legame, 60);
    });
  });
}
