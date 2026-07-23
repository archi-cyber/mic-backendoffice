import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../../screens/desktop/desktop_shell_scope.dart';
import '../../services/storage_service.dart';
import '../routes/route_names.dart';

/// Opens a file in the in-app viewer, keeping the desktop sidebar when embedded.
class FileViewerNavigation {
  FileViewerNavigation._();

  static Future<void> open(
    BuildContext context, {
    required String fileUrl,
    required String fileName,
  }) async {
    try {
      var urlToOpen = fileUrl;
      try {
        urlToOpen = await StorageService.createSignedUrl(fileUrl);
      } catch (e) {
        debugPrint('Could not create signed URL, using original URL: $e');
      }

      if (!context.mounted) return;

      final scope = DesktopShellScope.maybeOf(context);
      if (scope != null) {
        scope.pushDetail(
          RouteNames.fileViewer,
          '',
          arguments: {'fileUrl': urlToOpen, 'fileName': fileName},
        );
        return;
      }

      await Navigator.of(context).pushNamed(
        RouteNames.fileViewer,
        arguments: {'fileUrl': urlToOpen, 'fileName': fileName},
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Error opening file: $e'))),
      );
    }
  }
}
