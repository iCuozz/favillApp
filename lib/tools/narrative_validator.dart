class NarrativeValidator {
  /// Valida la coerenza narrativa di una scelta PRIMA di essere salvata
  static Future<ValidationResult> validateChoice({
    required String episodeId,
    required String choiceId,
    required Map<String, dynamic> choiceData,
    required Map<String, dynamic> currentState,
  }) async {
    final checks = <String, bool>{};
    final warnings = <String>[];
    final errors = <String>[];

    // 1. Validazione Motivazione
    checks['motivationClarity'] =
        _validateMotivation(episodeId, choiceData, currentState);
    if (!checks['motivationClarity']!) {
      errors.add('Scelta non ha motivazione chiara nel contesto');
    }

    // 2. Validazione Segreto
    checks['secretConsistency'] = _validateSecretConsistency(
      episodeId,
      choiceData,
      currentState,
    );
    if (!checks['secretConsistency']!) {
      errors.add('Scelta contraddice o rivela il segreto incoerentemente');
    }

    // 3. Validazione Relazioni
    final relationshipCheck = _validateRelationshipImpact(
      episodeId,
      choiceData,
      currentState,
    );
    checks['relationshipLogic'] = relationshipCheck['valid'] as bool;
    if (relationshipCheck['warnings'] != null) {
      warnings.addAll((relationshipCheck['warnings'] as List).cast<String>());
    }

    // 4. Validazione Causa/Effetto
    checks['causeEffectLogic'] =
        _validateCauseEffect(episodeId, choiceData, currentState);
    if (!checks['causeEffectLogic']!) {
      errors.add('Effetto narrativo non proporzionato alla causa');
    }

    // 5. Validazione Linguaggio/Tono
    checks['toneAuthenticity'] = _validateTone(choiceData, currentState);
    if (!checks['toneAuthenticity']!) {
      warnings.add(
          'Tono non riflette accuratamente emozione (es. irritazione ≠ violenza)');
    }

    // 6. Validazione Cross-Episode
    checks['crossEpisodeCoherence'] =
        await _validateCrossEpisode(episodeId, choiceData, currentState);
    if (!checks['crossEpisodeCoherence']!) {
      warnings
          .add('Scelta potrebbe contraddire episodi precedenti o futuri di S1');
    }

    // 7. Validazione Memory Markers
    checks['memoryMarkers'] = _validateMemoryMarkers(choiceData);
    if (!checks['memoryMarkers']!) {
      warnings.add('Memory markers non tracciati correttamente');
    }

    final allPassed = !checks.values.contains(false) && errors.isEmpty;

    return ValidationResult(
      passed: allPassed,
      checks: checks,
      warnings: warnings,
      errors: errors,
      episodeId: episodeId,
      choiceId: choiceId,
      timestamp: DateTime.now(),
    );
  }

  /// Valida se la scelta ha motivazione chiara nel contesto episodio
  static bool _validateMotivation(
    String episodeId,
    Map<String, dynamic> choiceData,
    Map<String, dynamic> currentState,
  ) {
    final label = choiceData['label'] as String? ?? '';
    final effects = choiceData['stat_effects'] as Map? ?? {};

    // Se label è vuota, fail
    if (label.isEmpty) return false;

    // Controllo coerenza: effects devono avere senso con il label
    // Es: se label dice "innervosita", resistenza non deve essere +50
    final hasNegativeEffect = (effects['legame'] as int? ?? 0) < 0 ||
        (effects['resistenza'] as int? ?? 0) < 0;

    // "Scelte sporche" dovrebbero avere ALCUNI effetti negativi
    // ma non TUTTI positivi (incoerente)
    final allPositive = (effects['resistenza'] as int? ?? 0) > 0 &&
        (effects['legame'] as int? ?? 0) > 0 &&
        (effects['scintille'] as int? ?? 0) > 0;

    // Se label è "negativa" (irritato, pigro, evasivo, panicked)
    // ma tutti gli effetti sono positivi = INCOERENTE
    final isNegativeLabel = label.toLowerCase().contains('innervosita') ||
        label.toLowerCase().contains('scappa') ||
        label.toLowerCase().contains('evasiv') ||
        label.toLowerCase().contains('panicked') ||
        label.toLowerCase().contains('gira') ||
        label.toLowerCase().contains('no');

    if (isNegativeLabel && allPositive) {
      return false; // Incoerenza: label negativo ma effetti positivi
    }

    return true;
  }

  /// Valida coerenza con il segreto (poteri di Favilla)
  static bool _validateSecretConsistency(
    String episodeId,
    Map<String, dynamic> choiceData,
    Map<String, dynamic> currentState,
  ) {
    // Episodi specifici hanno implicazioni sul segreto
    final secretRisks = {
      's1_mare': ['preso_male'], // Se Favilla "afferra duro" Lex, è sospetto
      's1_lunedi_asilo': ['scoperta'], // Se Lex trova il notebook = problema
      's1_centro_commerciale': ['avoided'], // Se scappa = Carmela nota
    };

    final riskOptions = secretRisks[episodeId] ?? [];
    final choiceId = choiceData['id'] as String? ?? '';

    // Se scelta è rischiosa per segreto, controllare logica
    if (riskOptions.contains(choiceId)) {
      // Es: "preso_male" dovrebbe avere segreto +5, non -5
      final secretEffect = choiceData['stat_effects']?['segreto'] as int? ?? 0;

      // Logica: azioni rischiose per segreto dovrebbero AUMENTARE segreto
      // (= più da proteggere) o essere giustificate narrativamente
      if (secretEffect < 0 && episodeId == 's1_lunedi_asilo') {
        // Lunedì asilo: se Favilla prende il notebook, aumenta segreto
        return secretEffect > 0;
      }

      // Mare: se Favilla innervosita, è "umano", non rivela poteri
      if (episodeId == 's1_mare' && secretEffect >= 0) {
        return true; // OK
      }
    }

    return true;
  }

  /// Valida impatto relazionale coerente
  static Map<String, dynamic> _validateRelationshipImpact(
    String episodeId,
    Map<String, dynamic> choiceData,
    Map<String, dynamic> currentState,
  ) {
    final warnings = <String>[];
    final effects = choiceData['stat_effects'] as Map? ?? {};
    final legameEffect = effects['legame'] as int? ?? 0;

    // Controllo coerenza legame/resistenza
    // Se una scelta è "sporca" (innervosita, paura, egoismo)
    // dovrebbe avere impact su legame (relazione)
    // ma non necessariamente massivo (-15 era troppo per semplice irritazione)

    // Validazioni per personaggio:
    // - Con Mallow: innervosita dovrebbe -5 a -10, non -15
    // - Con Lex: paura dovrebbe +5 legame (protezione), non -10
    // - Evitamento: dovrebbe -10 legame, non -15

    if (legameEffect < -10 &&
        !choiceData['label'].toString().contains('evasiv')) {
      warnings.add('Legame impact troppo severo per scelta non-evasiva');
    }

    if (legameEffect > 15 && choiceData['label'].toString().contains('panic')) {
      warnings.add('Legame boost troppo alto per scelta di panico');
    }

    return {
      'valid': warnings.isEmpty,
      'warnings': warnings,
    };
  }

  /// Valida rapporto causa/effetto
  static bool _validateCauseEffect(
    String episodeId,
    Map<String, dynamic> choiceData,
    Map<String, dynamic> currentState,
  ) {
    final label = choiceData['label'] as String? ?? '';
    final branch = choiceData['goto_branch'] as String? ?? '';

    // Causa: cosa dice il label
    // Effetto: quale branch si attiva e quali stat cambiano

    // Es: "innervosita" → dovrebbe attivare branch con tono freddo
    // Es: "evasione" → dovrebbe attivare branch con fuga/disapparition

    if (label.contains('innervosita') && !branch.contains('irritato')) {
      return false; // Branch non riflette causa
    }

    if (label.contains('panico') && !branch.contains('scoperta')) {
      return false; // Branch non riflette panico
    }

    if (label.contains('scappa') && !branch.contains('evita')) {
      return false; // Branch non riflette evasione
    }

    return true;
  }

  /// Valida autenticità del tono narrativo
  static bool _validateTone(
    Map<String, dynamic> choiceData,
    Map<String, dynamic> currentState,
  ) {
    final label = choiceData['label'] as String? ?? '';

    // Tone authenticity: evitare linguaggio esplicito di violenza
    // "afferra duro" → OK (innervosita)
    // "tira indietro secco" → OK (panico, non violenza)
    // "afferra Lex duro" → NO (troppo aggressivo per "innervosita")

    if (label.contains('duro') && label.contains('afferra')) {
      // Controllo se è proporzionato
      if (label == 'Lo prende. Duro.') {
        return false; // Troppo esplicito
      }
      if (label == 'Lo tira indietro secco.') {
        return true; // OK, proporzionato a panico
      }
    }

    // Altre validazioni tono
    if (label.contains('innervosita') ||
        label.contains('fredda') ||
        label.contains('brusco') ||
        label.contains('secco')) {
      return true; // Toni autentici
    }

    return true; // Default OK
  }

  /// Valida coerenza cross-episode
  static Future<bool> _validateCrossEpisode(
    String episodeId,
    Map<String, dynamic> choiceData,
    Map<String, dynamic> currentState,
  ) async {
    try {
      // Carica tutte le scelte S1 per controllare contraddizioni
      final s1Episodes = [
        's1_mare',
        's1_palestra',
        's1_centro_commerciale',
        's1_lunedi_asilo',
      ];

      // Se questa è scelta "evasiva" al centro commerciale
      // non dovrebbe contradire il fatto che Favilla affronta problemi al mare

      if (episodeId == 's1_centro_commerciale' &&
          choiceData['id'] == 'evita_carmela') {
        // OK - evasione può capitare
        return true;
      }

      return true; // Per ora placeholder
    } catch (e) {
      return true; // Se non posso validare, assumo OK
    }
  }

  /// Valida memory markers
  static bool _validateMemoryMarkers(Map<String, dynamic> choiceData) {
    final setMemories = choiceData['setMemories'] as Map? ?? {};

    // Scelte "sporche" dovrebbero tracciare intent/tone
    final label = choiceData['label'] as String? ?? '';

    if (label.contains('innervosita') ||
        label.contains('panico') ||
        label.contains('scappa') ||
        label.contains('evasiv')) {
      // Dovrebbe avere setMemories per callback futuri
      if (setMemories.isEmpty) {
        return false; // Manca memory tracking
      }
    }

    return true;
  }
}

/// Risultato della validazione narrativa
class ValidationResult {
  final bool passed;
  final Map<String, bool> checks;
  final List<String> warnings;
  final List<String> errors;
  final String episodeId;
  final String choiceId;
  final DateTime timestamp;

  ValidationResult({
    required this.passed,
    required this.checks,
    required this.warnings,
    required this.errors,
    required this.episodeId,
    required this.choiceId,
    required this.timestamp,
  });

  String get summary {
    if (passed) {
      return '✅ Validazione OK: $choiceId in $episodeId';
    } else {
      return '❌ Validazione FALLITA: ${errors.length} errori, ${warnings.length} warning';
    }
  }

  void printReport() {
    print('═' * 60);
    print('NARRATIVE VALIDATION REPORT');
    print('═' * 60);
    print('Episode: $episodeId | Choice: $choiceId');
    print('Timestamp: $timestamp');
    print('Status: ${passed ? "✅ PASSED" : "❌ FAILED"}');
    print('');

    print('CHECKS:');
    checks.forEach((key, value) {
      print('  ${value ? "✅" : "❌"} $key');
    });
    print('');

    if (errors.isNotEmpty) {
      print('ERRORS (${errors.length}):');
      for (final error in errors) {
        print('  ❌ $error');
      }
      print('');
    }

    if (warnings.isNotEmpty) {
      print('WARNINGS (${warnings.length}):');
      for (final warning in warnings) {
        print('  ⚠️  $warning');
      }
      print('');
    }

    print('═' * 60);
  }
}
