import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/platform/platform_capabilities.dart';
import '../models/app_update_info.dart';
import 'update_installer.dart';

/// Checks the API-hosted release manifest for newer builds.
class UpdateService {
  UpdateService._();

  static const _lastCheckKey = 'update_last_check_ms';
  static const _skippedVersionKey = 'update_skipped_version';
  static const _checkInterval = Duration(hours: 6);

  static String get _platformKey {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.windows:
        return 'windows';
      default:
        return 'unknown';
    }
  }

  static Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    if (!PlatformCapabilities.supportsAppUpdates) return null;

    if (!force && !await _shouldCheckNow()) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final current = AppVersion.parse(
        '${packageInfo.version}+${packageInfo.buildNumber}',
      );

      final response = await http
          .get(
            Uri.parse(AppConfig.updateManifestUrl),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('Update check failed: HTTP ${response.statusCode}');
        return null;
      }

      final json = _decodeManifest(response.body);
      if (json == null) return null;
      final update = AppUpdateInfo.fromJson(json, _platformKey);
      final latest = AppVersion.parse(
        update.buildNumber > 0
            ? '${update.version}+${update.buildNumber}'
            : update.version,
      );

      await _markChecked();

      if (update.minVersion != null) {
        final minimum = AppVersion.parse(update.minVersion!);
        if (current.isOlderThan(minimum)) {
          return _withForceUpdate(update);
        }
      }

      if (!latest.isNewerThan(current)) return null;

      if (!kIsWeb && update.resolvedDownloadUrl == null) {
        debugPrint('Update available but no asset for $_platformKey');
        return null;
      }

      if (!force && !update.forceUpdate) {
        final prefs = await SharedPreferences.getInstance();
        final skipped = prefs.getString(_skippedVersionKey);
        if (skipped == latest.toString()) return null;
      }

      return update;
    } catch (e) {
      debugPrint('Update check error: $e');
      return null;
    }
  }

  static Future<void> skipVersion(AppUpdateInfo update) async {
    final prefs = await SharedPreferences.getInstance();
    final version = update.buildNumber > 0
        ? '${update.version}+${update.buildNumber}'
        : update.version;
    await prefs.setString(_skippedVersionKey, version);
  }

  static Future<void> applyUpdate(
    AppUpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      await reloadWebApp();
      return;
    }

    final asset = update.resolvedDownloadUrl;
    if (asset == null || asset.isEmpty) {
      throw Exception('No download URL for this platform.');
    }

    final fileName = _fileNameFromUrl(asset);
    final filePath = await downloadUpdateFile(
      asset,
      fileName,
      onProgress: onProgress,
    );
    await installDownloadedUpdate(filePath);
  }

  static Future<String> getCurrentVersionLabel() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version} (${packageInfo.buildNumber})';
  }

  /// Parses the OTA manifest, tolerating unescaped newlines in release notes
  /// that older CI jobs accidentally published.
  static Map<String, dynamic>? _decodeManifest(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        // L'API enveloppe ses réponses dans `data`.
        final data = decoded['data'];
        if (data is Map<String, dynamic>) return data;
        return decoded;
      }
      return null;
    } on FormatException catch (e) {
      debugPrint('Update manifest JSON repair attempt: $e');
      final repaired = body.replaceAllMapped(
        RegExp(r'("release_notes"\s*:\s*")([\s\S]*?)("\s*,\s*"assets")'),
        (match) {
          final raw = match.group(2) ?? '';
          final escaped = raw
              .replaceAll(r'\', r'\\')
              .replaceAll('"', r'\"')
              .replaceAll('\r\n', r'\n')
              .replaceAll('\n', r'\n')
              .replaceAll('\r', r'\n')
              .replaceAll('\t', r'\t');
          return '${match.group(1)}$escaped${match.group(3)}';
        },
      );
      try {
        final decoded = jsonDecode(repaired);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (repairError) {
        debugPrint('Update manifest repair failed: $repairError');
      }
      return null;
    }
  }

  static Future<bool> _shouldCheckNow() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastCheckKey);
    if (lastMs == null) return true;
    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(lastCheck) >= _checkInterval;
  }

  static Future<void> _markChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  static AppUpdateInfo _withForceUpdate(AppUpdateInfo update) {
    return AppUpdateInfo(
      version: update.version,
      buildNumber: update.buildNumber,
      forceUpdate: true,
      minVersion: update.minVersion,
      releaseNotes: update.releaseNotes,
      downloadUrl: update.downloadUrl,
      platformKey: update.platformKey,
    );
  }

  static String _fileNameFromUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    if (segments.isEmpty) return 'mic_backoffice-update';
    return segments.last;
  }
}

extension AppUpdateInfoX on AppUpdateInfo {
  String? get resolvedDownloadUrl {
    final asset = downloadUrl;
    if (asset == null || asset.isEmpty) return null;
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      return asset;
    }
    return AppConfig.releaseAssetUrl(asset);
  }

  String get displayVersion =>
      buildNumber > 0 ? '$version ($buildNumber)' : version;
}
