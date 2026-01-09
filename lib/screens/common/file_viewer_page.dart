import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';

/// Webview page to display files (PDFs, images, etc.)
class FileViewerPage extends StatefulWidget {
  final String fileUrl;
  final String fileName;

  const FileViewerPage({
    super.key,
    required this.fileUrl,
    required this.fileName,
  });

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  bool _isPdfFile() {
    final fileName = widget.fileName.toLowerCase();
    final fileUrl = widget.fileUrl.toLowerCase();
    return fileName.endsWith('.pdf') || fileUrl.contains('.pdf');
  }

  bool _isImageFile() {
    final fileName = widget.fileName.toLowerCase();
    final fileUrl = widget.fileUrl.toLowerCase();
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
    return imageExtensions.any((ext) => 
      fileName.endsWith(ext) || fileUrl.contains(ext));
  }

  String _getHtmlContent() {
    if (_isPdfFile()) {
      // Use Google Docs Viewer for PDFs to ensure inline display
      // This is more reliable than direct iframe embedding
      final encodedUrl = Uri.encodeComponent(widget.fileUrl);
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      margin: 0;
      padding: 0;
      overflow: hidden;
      background-color: #525252;
    }
    iframe {
      width: 100%;
      height: 100vh;
      border: none;
    }
  </style>
</head>
<body>
  <iframe src="https://docs.google.com/viewer?url=$encodedUrl&embedded=true"></iframe>
</body>
</html>
''';
    } else if (_isImageFile()) {
      // Display image directly
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      background-color: #525252;
    }
    img {
      max-width: 100%;
      max-height: 100vh;
      object-fit: contain;
    }
  </style>
</head>
<body>
  <img src="${widget.fileUrl}" alt="${widget.fileName}">
</body>
</html>
''';
    } else {
      // For other file types, try to display in iframe or use Google Docs Viewer
      return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      margin: 0;
      padding: 0;
      overflow: hidden;
      background-color: #525252;
    }
    iframe {
      width: 100%;
      height: 100vh;
      border: none;
    }
  </style>
</head>
<body>
  <iframe src="https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.fileUrl)}&embedded=true"></iframe>
</body>
</html>
''';
    }
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.grey[850]!)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _error = error.description;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow navigation to the file URL and Google Docs Viewer
            if (request.url == widget.fileUrl || 
                request.url.contains('docs.google.com/viewer') ||
                request.url.startsWith('data:') ||
                request.url.contains(widget.fileUrl)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    // Load HTML content that embeds the file
    if (_isPdfFile() || _isImageFile()) {
      _controller.loadHtmlString(
        _getHtmlContent(),
        baseUrl: widget.fileUrl,
      );
    } else {
      // For other files, use Google Docs Viewer
      _controller.loadHtmlString(_getHtmlContent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading file',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      _error ?? 'Unknown error',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isLoading = true;
                      });
                      _controller.reload();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
    );
  }
}
