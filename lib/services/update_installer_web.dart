import 'dart:html' as html;

Future<String> downloadUpdateFile(
  String url,
  String fileName, {
  void Function(double progress)? onProgress,
}) async {
  throw UnsupportedError('File download is not used on web.');
}

Future<void> installDownloadedUpdate(String filePath) async {
  throw UnsupportedError('File-based install is not used on web.');
}

Future<void> reloadWebApp() async {
  html.window.location.reload();
}
