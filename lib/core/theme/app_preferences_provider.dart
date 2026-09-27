import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_language.dart';

// Keys for SharedPreferences
const String _keyThemeMode = 'pref_theme_mode';
const String _keyLiquidGlass = 'pref_liquid_glass';
const String _keyCategorizedView = 'pref_categorized_view';
const String _keyLanguage = 'pref_language';

/// Manages App Theme (System, Light, Dark)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_keyThemeMode);
      if (modeStr != null) {
        if (modeStr == 'light') state = ThemeMode.light;
        if (modeStr == 'dark') state = ThemeMode.dark;
        if (modeStr == 'system') state = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'system';
      if (mode == ThemeMode.light) val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      await prefs.setString(_keyThemeMode, val);
    } catch (_) {}
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Manages Liquid Glass Styling ON / OFF
class LiquidGlassNotifier extends StateNotifier<bool> {
  LiquidGlassNotifier() : super(true) {
    _loadFromPrefs();
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyLiquidGlass, enabled);
    } catch (_) {}
  }
}

final liquidGlassEnabledProvider = StateNotifierProvider<LiquidGlassNotifier, bool>((ref) {
  return LiquidGlassNotifier();
});

/// Manages Document Categorized View ON / OFF
class CategorizedViewNotifier extends StateNotifier<bool> {
  CategorizedViewNotifier() : super(true) {
    _loadFromPrefs();
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyCategorizedView, enabled);
    } catch (_) {}
  }
}

final categorizedViewProvider = StateNotifierProvider<CategorizedViewNotifier, bool>((ref) {
  return CategorizedViewNotifier();
});

/// Manages Language Preference (English, Sinhala, Singlish)
class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.english) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_keyLanguage);
      if (code != null) {
        state = AppLanguage.fromCode(code);
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLanguage, language.code);
    } catch (_) {}
  }
}

final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier();
});
