import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TextAnimationSpeed { slow, normal, fast, instant }

enum AppLanguage { italian, english }

extension AppLanguageX on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.italian:
        return 'it';
      case AppLanguage.english:
        return 'en';
    }
  }

  String get label {
    switch (this) {
      case AppLanguage.italian:
        return 'Italiano';
      case AppLanguage.english:
        return 'English';
    }
  }

  static AppLanguage fromCode(String? code) {
    switch (code) {
      case 'en':
        return AppLanguage.english;
      case 'it':
      default:
        return AppLanguage.italian;
    }
  }
}

extension TextAnimationSpeedX on TextAnimationSpeed {
  Duration get duration {
    switch (this) {
      case TextAnimationSpeed.slow:
        return const Duration(milliseconds: 380);
      case TextAnimationSpeed.normal:
        return const Duration(milliseconds: 220);
      case TextAnimationSpeed.fast:
        return const Duration(milliseconds: 120);
      case TextAnimationSpeed.instant:
        return Duration.zero;
    }
  }

  String labelFor(AppLanguage lang) {
    switch (this) {
      case TextAnimationSpeed.slow:
        return lang == AppLanguage.english ? 'Slow' : 'Lenta';
      case TextAnimationSpeed.normal:
        return lang == AppLanguage.english ? 'Normal' : 'Normale';
      case TextAnimationSpeed.fast:
        return lang == AppLanguage.english ? 'Fast' : 'Veloce';
      case TextAnimationSpeed.instant:
        return lang == AppLanguage.english ? 'Instant' : 'Istantanea';
    }
  }
}

class SettingsService {
  static const _kHapticsEnabled = 'settings.hapticsEnabled';
  static const _kFullscreenReading = 'settings.fullscreenReading';
  static const _kTextAnimationSpeed = 'settings.textAnimationSpeed';
  static const _kLanguage = 'settings.language';

  static final ValueNotifier<bool> hapticsEnabled = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> fullscreenReading =
      ValueNotifier<bool>(false);
  static final ValueNotifier<TextAnimationSpeed> textAnimationSpeed =
      ValueNotifier<TextAnimationSpeed>(TextAnimationSpeed.normal);
  static final ValueNotifier<AppLanguage> language =
      ValueNotifier<AppLanguage>(AppLanguage.italian);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    hapticsEnabled.value = prefs.getBool(_kHapticsEnabled) ?? true;
    fullscreenReading.value = prefs.getBool(_kFullscreenReading) ?? false;
    final speedIndex = prefs.getInt(_kTextAnimationSpeed) ??
        TextAnimationSpeed.normal.index;
    textAnimationSpeed.value =
        TextAnimationSpeed.values[speedIndex.clamp(0, TextAnimationSpeed.values.length - 1)];
    language.value = AppLanguageX.fromCode(prefs.getString(_kLanguage));
  }

  static Future<void> setHapticsEnabled(bool value) async {
    hapticsEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHapticsEnabled, value);
  }

  static Future<void> setFullscreenReading(bool value) async {
    fullscreenReading.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFullscreenReading, value);
  }

  static Future<void> setTextAnimationSpeed(TextAnimationSpeed value) async {
    textAnimationSpeed.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTextAnimationSpeed, value.index);
  }

  static Future<void> setLanguage(AppLanguage value) async {
    language.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, value.code);
  }

  static void tapFeedback() {
    if (!hapticsEnabled.value) return;
    HapticFeedback.selectionClick();
  }
}
