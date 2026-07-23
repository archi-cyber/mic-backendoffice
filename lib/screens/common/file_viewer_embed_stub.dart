import 'package:flutter/material.dart';

/// Non-web platforms use other preview strategies (WebView, pdfrx, etc.).
Widget? buildEmbeddedFileViewer({
  required String fileUrl,
  required String fileName,
  required bool isPdf,
  required bool isImage,
}) {
  return null;
}
