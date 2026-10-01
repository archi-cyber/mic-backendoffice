import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<String> downloadUpdateFile(
  String url,
  String fileName, {
  void Function(double progress)? onProgress,
}) async {
  final client = http.Client();
  File? file;
  IOSink? sink;

  try {
    final uri = Uri.parse(url);
    final request = http.Request('GET', uri);
    request.headers.addAll(const {
      'Accept': '*/*',
      'Cache-Control': 'no-cache',
    });

    final response = await client.send(request).timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw TimeoutException(
        'Timed out connecting to the update server.',
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download failed: HTTP ${response.statusCode}');
    }

    // Prefer cache dir (FileProvider-friendly on Android) over temp.
    final dir = await getTemporaryDirectory();
    file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
    }

    sink = file.openWrite();
    final total = response.contentLength ?? 0;
    var received = 0;

    await for (final chunk in response.stream.timeout(
      const Duration(minutes: 15),
      onTimeout: (eventSink) {
        eventSink.addError(
          TimeoutException(
            'Download stalled. Check your connection and try again.',
          ),
        );
        eventSink.close();
      },
    )) {
      received += chunk.length;
      sink.add(chunk);
      if (onProgress != null) {
        if (total > 0) {
          onProgress(received / total);
        } else {
          // Indeterminate-ish pulse so UI knows bytes are flowing.
          onProgress((received % (5 * 1024 * 1024)) / (5 * 1024 * 1024));
        }
      }
    }

    await sink.flush();
    await sink.close();
    sink = null;

    final length = await file.length();
    if (length <= 0) {
      throw Exception('Downloaded file is empty.');
    }
    if (total > 0 && length < total) {
      throw Exception(
        'Download incomplete ($length of $total bytes). Try again.',
      );
    }

    onProgress?.call(1);
    return file.path;
  } catch (e) {
    try {
      await sink?.close();
    } catch (_) {}
    try {
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    rethrow;
  } finally {
    client.close();
  }
}

Future<void> installDownloadedUpdate(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw Exception('Update file not found. Please download again.');
  }

  if (defaultTargetPlatform == TargetPlatform.windows) {
    await Process.start(filePath, ['/SILENT'], runInShell: true);
    return;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    final result = await OpenFilex.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      final message = result.message.trim().isEmpty
          ? 'Could not open the installer.'
          : result.message;
      throw Exception(message);
    }
    return;
  }

  throw UnsupportedError('In-app updates are not supported on this platform.');
}

Future<void> reloadWebApp() async {}
