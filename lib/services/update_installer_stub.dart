Future<String> downloadUpdateFile(
  String url,
  String fileName, {
  void Function(double progress)? onProgress,
}) async {
  throw UnsupportedError('File download is not supported on this platform.');
}

Future<void> installDownloadedUpdate(String filePath) async {
  throw UnsupportedError('In-app updates are not supported on this platform.');
}

Future<void> reloadWebApp() async {}
