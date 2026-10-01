import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app settings and preferences
class SettingsService {
  static const String _keyLocale = 'app_locale';
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyNotificationsEnabled = 'notifications_enabled';

  static const Locale defaultLocale = Locale('en');
  static const List<String> supportedLanguageCodes = ['en', 'fr', 'es'];

  /// Maps a stored or device locale to a language the app actually supports.
  static Locale resolveLocale(Locale? locale) {
    final code = locale?.languageCode;
    if (code != null && supportedLanguageCodes.contains(code)) {
      return Locale(code);
    }
    return defaultLocale;
  }

  /// Apply [locale] to intl/DateFormat so dates match Settings, not the OS.
  static Future<void> applyToIntl(Locale locale) async {
    final resolved = resolveLocale(locale);
    Intl.defaultLocale = resolved.languageCode;
    try {
      await initializeDateFormatting(resolved.languageCode);
    } catch (_) {
      // Date symbols may already be loaded.
    }
  }

  /// Load the Settings language, persist a default if none is saved, and
  /// apply it before the first frame.
  static Future<Locale> loadResolvedLocale() async {
    final saved = await getLocale();
    final resolved = resolveLocale(saved);
    if (saved == null || saved.languageCode != resolved.languageCode) {
      try {
        await setLocale(resolved);
      } catch (_) {}
    }
    await applyToIntl(resolved);
    return resolved;
  }

  /// Get saved locale
  static Future<Locale?> getLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeString = prefs.getString(_keyLocale);
      if (localeString != null && localeString.isNotEmpty) {
        return Locale(localeString);
      }
    } catch (e) {
      // Return null if error
    }
    return null;
  }

  /// Save locale preference
  static Future<void> setLocale(Locale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyLocale,
        resolveLocale(locale).languageCode,
      );
    } catch (e) {
      throw Exception('Failed to save locale: $e');
    }
  }

  /// Get saved theme mode
  static Future<ThemeMode> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString(_keyThemeMode);
      if (themeModeString != null) {
        switch (themeModeString) {
          case 'light':
            return ThemeMode.light;
          case 'dark':
            return ThemeMode.dark;
          case 'system':
            return ThemeMode.system;
        }
      }
    } catch (e) {
      // Return default
    }
    return ThemeMode.system;
  }

  /// Save theme mode preference
  static Future<void> setThemeMode(ThemeMode themeMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeModeString;
      switch (themeMode) {
        case ThemeMode.light:
          themeModeString = 'light';
          break;
        case ThemeMode.dark:
          themeModeString = 'dark';
          break;
        case ThemeMode.system:
          themeModeString = 'system';
          break;
      }
      await prefs.setString(_keyThemeMode, themeModeString);
    } catch (e) {
      throw Exception('Failed to save theme mode: $e');
    }
  }

  /// Get notifications enabled status
  static Future<bool> getNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyNotificationsEnabled) ?? true;
    } catch (e) {
      return true; // Default to enabled
    }
  }

  /// Set notifications enabled status
  static Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyNotificationsEnabled, enabled);
    } catch (e) {
      throw Exception('Failed to save notifications setting: $e');
    }
  }
}
