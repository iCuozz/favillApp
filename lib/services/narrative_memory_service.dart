// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

class NarrativeMemoryService {
  static final RegExp _memoryToken =
      RegExp(r'\{\{memory:([a-zA-Z0-9_.-]+)(?:\|([^}]*))?\}\}');

  /// Sostituisce token narrativi nel testo con valori salvati.
  ///
  /// Sintassi supportata:
  ///   {{memory:chiave}}
  ///   {{memory:chiave|fallback}}
  static String resolveText(String raw, Map<String, String> memories) {
    if (raw.isEmpty) return raw;
    return raw.replaceAllMapped(_memoryToken, (match) {
      final key = (match.group(1) ?? '').trim();
      final fallback = (match.group(2) ?? '').trim();
      if (key.isEmpty) return fallback;
      final value = memories[key]?.trim();
      if (value == null || value.isEmpty) return fallback;
      return value;
    });
  }
}
