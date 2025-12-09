import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Service for managing app settings and preferences
class SettingsService {
  static const String _keyLocale = 'app_locale';
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyNotificationsEnabled = 'notifications_enabled';

  /// Get saved locale
  static Future<Locale?> getLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeString = prefs.getString(_keyLocale);
      if (localeString != null) {
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
      await prefs.setString(_keyLocale, locale.languageCode);
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
