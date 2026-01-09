import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// Settings provider for managing app settings (locale, theme, etc.)
class SettingsProvider extends ChangeNotifier {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  bool _isLoading = true;

  Locale? get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoading => _isLoading;

  /// Initialize settings from storage
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        SettingsService.getLocale(),
        SettingsService.getThemeMode(),
        SettingsService.getNotificationsEnabled(),
      ]);

      _locale = results[0] as Locale?;
      _themeMode = results[1] as ThemeMode;
      _notificationsEnabled = results[2] as bool;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update locale
  Future<void> setLocale(Locale locale) async {
    try {
      await SettingsService.setLocale(locale);
      _locale = locale;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Update theme mode
  Future<void> setThemeMode(ThemeMode themeMode) async {
    try {
      await SettingsService.setThemeMode(themeMode);
      _themeMode = themeMode;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Update notifications enabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      await SettingsService.setNotificationsEnabled(enabled);
      _notificationsEnabled = enabled;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
