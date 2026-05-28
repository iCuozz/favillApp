// Copyright © 2026 Andrea Cuozzo. All rights reserved.
// Favilla Blaze — proprietà intellettuale riservata.
// See LICENSE file in the project root for full license information.

import 'package:shared_preferences/shared_preferences.dart';

/// Tiene traccia di cosa è già stato mostrato all'utente la prima volta.
class OnboardingService {
  OnboardingService._();
  static final instance = OnboardingService._();

  static const _kStatsIntroSeen = 'onboarding.stats_intro_seen';

  Future<bool> hasSeenStatsIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kStatsIntroSeen) ?? false;
  }

  Future<void> markStatsIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStatsIntroSeen, true);
  }
}
