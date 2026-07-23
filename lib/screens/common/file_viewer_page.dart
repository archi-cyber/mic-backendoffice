import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/localization/app_localizations.dart';
import 'file_viewer_embed.dart';

/// Webview page to display files (PDFs, images, etc.)
class FileViewerPage extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final bool hideAppBarAndBottomNav;
  final VoidCallback? onClose;

  FileViewerPage({
    super.key,
    required this.fileUrl,
    required this.fileName,
    this.hideAppBarAndBottomNav = false,
    this.onClose,
  });

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_canUseWebView) {
      _initializeWebView();
    } else {
      _isLoading = false;
    }
  }

  bool get _canUseWebView {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  bool get _canUsePdfViewer {
    if (kIsWeb || !_isPdfFile()) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
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
    return imageExtensions.any(
      (ext) => fileName.endsWith(ext) || fileUrl.contains(ext),
    );
  }

  String _getHtmlContent() {
    if (_isPdfFile()) {
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
    final controller = WebViewController()
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

    if (_isPdfFile() || _isImageFile()) {
      controller.loadHtmlString(_getHtmlContent(), baseUrl: widget.fileUrl);
    } else {
      controller.loadHtmlString(_getHtmlContent());
    }
    _controller = controller;
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.fileUrl);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Invalid file URL')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Could not open file')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildToolbarActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: _openExternally,
          tooltip: context.tr('Open file'),
        ),
        if (_isLoading && _canUseWebView)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildPdfDesktopViewer() {
    final uri = Uri.tryParse(widget.fileUrl);
    if (uri == null) {
      return _buildOpenExternallyFallback(context);
    }

    return PdfViewer.uri(uri);
  }

  Widget _buildEmbeddedViewer() {
    final embedded = buildEmbeddedFileViewer(
      fileUrl: widget.fileUrl,
      fileName: widget.fileName,
      isPdf: _isPdfFile(),
      isImage: _isImageFile(),
    );
    if (embedded != null) {
      return embedded;
    }

    if (_canUsePdfViewer) {
      return _buildPdfDesktopViewer();
    }

    return _buildFallbackViewer(context);
  }

  Widget _buildFallbackViewer(BuildContext context) {
    if (_isImageFile()) {
      return Container(
        color: Colors.grey[850],
        alignment: Alignment.center,
        child: InteractiveViewer(
          child: Image.network(
            widget.fileUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildOpenExternallyFallback(context);
            },
          ),
        ),
      );
    }

    return _buildOpenExternallyFallback(context);
  }

  Widget _buildOpenExternallyFallback(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.open_in_new, size: 64, color: context.mic.textSecondary),
            const SizedBox(height: 16),
            Text(
              context.tr('Preview unavailable in this browser'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Open the file in a new tab to view or download it.'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.mic.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_new),
              label: Text(context.tr('Open file')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              context.tr('Error loading file'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.mic.textSecondary,
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
                _controller?.reload();
              },
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('Retry')),
            ),
          ],
        ),
      );
    }

    if (_canUseWebView) {
      return Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return _buildEmbeddedViewer();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildViewerBody();

    if (widget.hideAppBarAndBottomNav) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.onClose != null ? 0 : 16,
              8,
              8,
              0,
            ),
            child: Row(
              children: [
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onClose,
                    tooltip: context.tr('Back'),
                  ),
                Expanded(
                  child: Text(
                    widget.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildToolbarActions(),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [_buildToolbarActions()],
      ),
      body: body,
    );
  }
}
