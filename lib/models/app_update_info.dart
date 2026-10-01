/// Describes an available app update from the release manifest.
class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final bool forceUpdate;
  final String? minVersion;
  final String? releaseNotes;
  final String? downloadUrl;
  final String platformKey;

  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.forceUpdate,
    required this.platformKey,
    this.minVersion,
    this.releaseNotes,
    this.downloadUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json, String platformKey) {
    final assets = json['assets'];
    String? assetName;
    if (assets is Map) {
      assetName = assets[platformKey]?.toString();
    }

    return AppUpdateInfo(
      version: json['version']?.toString() ?? '0.0.0',
      buildNumber: _parseInt(json['build_number']),
      forceUpdate: json['force_update'] == true,
      minVersion: json['min_version']?.toString(),
      releaseNotes: sanitizeReleaseNotes(json['release_notes']?.toString()),
      platformKey: platformKey,
      downloadUrl: assetName,
    );
  }
}

int _parseInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Keeps release notes short and strips noise like Co-authored-by trailers.
String? sanitizeReleaseNotes(String? raw) {
  if (raw == null) return null;
  final lines = raw
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) => !line.toLowerCase().startsWith('co-authored-by:'));
  final text = lines.join(' ').trim();
  if (text.isEmpty) return null;
  if (text.length <= 140) return text;
  return '${text.substring(0, 137).trimRight()}...';
}

/// Semver + build number comparison (e.g. 1.2.3+4).
class AppVersion {
  final int major;
  final int minor;
  final int patch;
  final int build;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build = 0,
  });

  factory AppVersion.parse(String raw) {
    var value = raw.trim();
    if (value.startsWith('v')) {
      value = value.substring(1);
    }

    final plusParts = value.split('+');
    final semver = plusParts.first.split('.');
    final build = plusParts.length > 1 ? int.tryParse(plusParts[1]) ?? 0 : 0;

    return AppVersion(
      major: int.tryParse(semver.elementAtOrNull(0) ?? '0') ?? 0,
      minor: int.tryParse(semver.elementAtOrNull(1) ?? '0') ?? 0,
      patch: int.tryParse(semver.elementAtOrNull(2) ?? '0') ?? 0,
      build: build,
    );
  }

  bool isNewerThan(AppVersion other) {
    if (major != other.major) return major > other.major;
    if (minor != other.minor) return minor > other.minor;
    if (patch != other.patch) return patch > other.patch;
    return build > other.build;
  }

  bool isOlderThan(AppVersion other) => other.isNewerThan(this);

  @override
  String toString() =>
      build > 0 ? '$major.$minor.$patch+$build' : '$major.$minor.$patch';
}

extension _ListElementAtOrNull<T> on List<T> {
  T? elementAtOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }
}
