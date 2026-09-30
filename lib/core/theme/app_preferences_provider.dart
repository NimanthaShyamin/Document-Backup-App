import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_language.dart';

// Keys for SharedPreferences
const String _keyThemeMode = 'pref_theme_mode';
const String _keyLiquidGlass = 'pref_liquid_glass';
const String _keyCategorizedView = 'pref_categorized_view';
const String _keyLanguage = 'pref_language';
const String _keyBiometricDelete = 'pref_biometric_delete';
const String keyGeminiApiKey = 'pref_gemini_api_key';
const String _keyGeminiApiKey = keyGeminiApiKey;

/// Global synchronous SharedPreferences provider (overridden in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Manages App Theme (System, Light, Dark)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences? _prefs;

  ThemeModeNotifier([this._prefs])
      : super(_parseMode(_prefs?.getString(_keyThemeMode))) {
    if (_prefs == null) _loadFromPrefs();
  }

  static ThemeMode _parseMode(String? modeStr) {
    if (modeStr == 'light') return ThemeMode.light;
    if (modeStr == 'dark') return ThemeMode.dark;
    if (modeStr == 'system') return ThemeMode.system;
    return ThemeMode.dark;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_keyThemeMode);
      if (modeStr != null) {
        state = _parseMode(modeStr);
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      String val = 'system';
      if (mode == ThemeMode.light) val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      await prefs.setString(_keyThemeMode, val);
    } catch (_) {}
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

/// Manages Liquid Glass Styling ON / OFF
class LiquidGlassNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  LiquidGlassNotifier([this._prefs])
      : super(_prefs?.getBool(_keyLiquidGlass) ?? true) {
    if (_prefs == null) _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_keyLiquidGlass);
      if (enabled != null) {
        state = enabled;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    set(!state);
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(_keyLiquidGlass, enabled);
    } catch (_) {}
  }
}

final liquidGlassEnabledProvider = StateNotifierProvider<LiquidGlassNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LiquidGlassNotifier(prefs);
});

/// Manages Document Categorized View ON / OFF
class CategorizedViewNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  CategorizedViewNotifier([this._prefs])
      : super(_prefs?.getBool(_keyCategorizedView) ?? true) {
    if (_prefs == null) _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_keyCategorizedView);
      if (enabled != null) {
        state = enabled;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    set(!state);
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(_keyCategorizedView, enabled);
    } catch (_) {}
  }
}

final categorizedViewProvider = StateNotifierProvider<CategorizedViewNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CategorizedViewNotifier(prefs);
});

/// Manages Language Preference (English, Sinhala, Singlish)
class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  final SharedPreferences? _prefs;

  AppLanguageNotifier([this._prefs])
      : super(_parseLang(_prefs?.getString(_keyLanguage))) {
    if (_prefs == null) _loadFromPrefs();
  }

  static AppLanguage _parseLang(String? code) {
    if (code != null) return AppLanguage.fromCode(code);
    return AppLanguage.english;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_keyLanguage);
      if (code != null) {
        state = _parseLang(code);
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_keyLanguage, language.code);
    } catch (_) {}
  }
}

final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppLanguageNotifier(prefs);
});

/// Manages requirement of biometrics/passcode for document deletion.
/// Defaults to TRUE (On by default).
class BiometricDeleteNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefs;

  BiometricDeleteNotifier([this._prefs])
      : super(_prefs?.getBool(_keyBiometricDelete) ?? true) {
    if (_prefs == null) _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final required = prefs.getBool(_keyBiometricDelete);
      if (required != null) {
        state = required;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    set(!state);
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(_keyBiometricDelete, enabled);
    } catch (_) {}
  }
}

final biometricDeleteRequiredProvider = StateNotifierProvider<BiometricDeleteNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BiometricDeleteNotifier(prefs);
});

/// Manages user-configured Gemini API Key for auto-extracting document details.
class GeminiApiKeyNotifier extends StateNotifier<String> {
  final SharedPreferences? _prefs;

  GeminiApiKeyNotifier([this._prefs])
      : super(_prefs?.getString(_keyGeminiApiKey)?.trim() ??
            const String.fromEnvironment('GEMINI_API_KEY')) {
    if (_prefs == null) _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_keyGeminiApiKey);
      if (key != null && key.trim().isNotEmpty && state.isEmpty) {
        state = key.trim();
      }
    } catch (_) {}
  }

  Future<void> setKey(String apiKey) async {
    state = apiKey.trim();
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_keyGeminiApiKey, state);
    } catch (_) {}
  }
}

final geminiApiKeyProvider = StateNotifierProvider<GeminiApiKeyNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GeminiApiKeyNotifier(prefs);
});

/// Transient provider controlling search bar visibility (triggered by dock swipe-down).
final searchVisibleProvider = StateProvider<bool>((ref) => false);
