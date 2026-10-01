import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_update_info.dart';
import '../services/android_install_permission.dart';
import '../services/update_installer.dart';
import '../services/update_service.dart';

enum AppUpdatePhase {
  idle,
  checking,
  downloading,
  awaitingInstallPermission,
  installing,
  completed,
  error,
}

/// App-wide OTA download/install state so progress survives navigation.
class AppUpdateProvider extends ChangeNotifier {
  AppUpdatePhase _phase = AppUpdatePhase.idle;
  double? _progress;
  String? _errorMessage;
  AppUpdateInfo? _activeUpdate;
  String? _downloadedPath;
  bool _busy = false;
  DateTime? _lastProgressNotify;

  AppUpdatePhase get phase => _phase;
  double? get progress => _progress;
  String? get errorMessage => _errorMessage;
  AppUpdateInfo? get activeUpdate => _activeUpdate;
  bool get isBusy => _busy;
  bool get isDownloading => _phase == AppUpdatePhase.downloading;
  bool get showsProgressUi =>
      _phase == AppUpdatePhase.checking ||
      _phase == AppUpdatePhase.downloading ||
      _phase == AppUpdatePhase.awaitingInstallPermission ||
      _phase == AppUpdatePhase.installing;

  Future<AppUpdateInfo?> checkForUpdate({bool force = true}) async {
    if (_busy) return _activeUpdate;
    _phase = AppUpdatePhase.checking;
    _progress = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final update = await UpdateService.checkForUpdate(force: force);
      _phase = AppUpdatePhase.idle;
      if (update != null) _activeUpdate = update;
      notifyListeners();
      return update;
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  /// Downloads (if needed) then installs. Safe to call while navigating away.
  Future<void> startUpdate(AppUpdateInfo update) async {
    if (_busy ||
        _phase == AppUpdatePhase.downloading ||
        _phase == AppUpdatePhase.installing ||
        _phase == AppUpdatePhase.awaitingInstallPermission) {
      return;
    }
    _busy = true;
    _activeUpdate = update;
    _errorMessage = null;
    _downloadedPath = null;
    notifyListeners();

    try {
      if (kIsWeb) {
        _phase = AppUpdatePhase.installing;
        _progress = null;
        notifyListeners();
        await UpdateService.applyUpdate(update);
        _phase = AppUpdatePhase.completed;
        notifyListeners();
        return;
      }

      final asset = update.resolvedDownloadUrl;
      if (asset == null || asset.isEmpty) {
        throw Exception('No download URL for this platform.');
      }

      _phase = AppUpdatePhase.downloading;
      _progress = 0;
      notifyListeners();

      final fileName = _apkFileName(asset);
      final filePath = await downloadUpdateFile(
        asset,
        fileName,
        onProgress: _onDownloadProgress,
      );
      _downloadedPath = filePath;
      _progress = 1;
      notifyListeners();

      await _installDownloaded(filePath);
    } catch (e) {
      _fail(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Called when the app returns to foreground (e.g. after install permission).
  Future<void> onAppResumed() async {
    if (_phase != AppUpdatePhase.awaitingInstallPermission) return;
    final path = _downloadedPath;
    if (path == null || path.isEmpty || _busy) return;

    _busy = true;
    notifyListeners();
    try {
      final allowed = await AndroidInstallPermission.canInstallPackages();
      if (!allowed) return;
      await _installDownloaded(path);
    } catch (e) {
      _fail(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> openInstallPermissionSettings() async {
    await AndroidInstallPermission.openInstallPermissionSettings();
  }

  void clearError() {
    if (_phase == AppUpdatePhase.error || _phase == AppUpdatePhase.completed) {
      _phase = AppUpdatePhase.idle;
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> _installDownloaded(String filePath) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final allowed = await AndroidInstallPermission.canInstallPackages();
      if (!allowed) {
        _phase = AppUpdatePhase.awaitingInstallPermission;
        _progress = null;
        notifyListeners();
        await AndroidInstallPermission.openInstallPermissionSettings();
        return;
      }
    }

    _phase = AppUpdatePhase.installing;
    _progress = null;
    notifyListeners();
    await installDownloadedUpdate(filePath);
    _phase = AppUpdatePhase.completed;
    notifyListeners();
  }

  void _onDownloadProgress(double value) {
    _progress = value.clamp(0.0, 1.0);
    final now = DateTime.now();
    if (_lastProgressNotify == null ||
        now.difference(_lastProgressNotify!) >=
            const Duration(milliseconds: 120)) {
      _lastProgressNotify = now;
      notifyListeners();
    }
  }

  void _fail(Object e) {
    debugPrint('App update failed: $e');
    _phase = AppUpdatePhase.error;
    _errorMessage = e.toString();
    _busy = false;
    notifyListeners();
  }

  static String _apkFileName(String url) {
    final uri = Uri.parse(url);
    var name = uri.pathSegments.isEmpty
        ? 'systemic-update.apk'
        : uri.pathSegments.last;
    if (!name.toLowerCase().endsWith('.apk') &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      name = '$name.apk';
    }
    return name;
  }
}
