import 'dart:async';

import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// Settings provider for managing app settings (locale, theme, etc.)
class SettingsProvider extends ChangeNotifier {
  Locale _locale;
  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  bool _isLoading = true;
  final Completer<void> _ready = Completer<void>();

  SettingsProvider({Locale? initialLocale})
      : _locale = SettingsService.resolveLocale(initialLocale);

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoading => _isLoading;
  Future<void> get ready => _ready.future;

  Future<void> ensureReady() => ready;

  void _markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Initialize settings from storage
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        SettingsService.getLocale(),
        SettingsService.getThemeMode(),
        SettingsService.getNotificationsEnabled(),
      ]).timeout(const Duration(seconds: 5)).then((results) async {
        _locale = SettingsService.resolveLocale(results[0] as Locale?);
        _themeMode = results[1] as ThemeMode;
        _notificationsEnabled = results[2] as bool;
        await SettingsService.applyToIntl(_locale);
      });
    } on TimeoutException {
      await SettingsService.applyToIntl(_locale);
    } catch (e) {
      await SettingsService.applyToIntl(_locale);
    } finally {
      _isLoading = false;
      _markReady();
      notifyListeners();
    }
  }

  /// Update locale
  Future<void> setLocale(Locale locale) async {
    try {
      final resolved = SettingsService.resolveLocale(locale);
      await SettingsService.setLocale(resolved);
      await SettingsService.applyToIntl(resolved);
      _locale = resolved;
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
