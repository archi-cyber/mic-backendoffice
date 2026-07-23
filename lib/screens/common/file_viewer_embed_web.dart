import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

final _registeredViewTypes = <String>{};

Widget? buildEmbeddedFileViewer({
  required String fileUrl,
  required String fileName,
  required bool isPdf,
  required bool isImage,
}) {
  final viewType = 'file-viewer-${fileUrl.hashCode}-${isPdf ? 'pdf' : isImage ? 'img' : 'doc'}';
  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      if (isImage) {
        final element = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center'
          ..style.backgroundColor = '#525252';
        final img = html.ImageElement()
          ..src = fileUrl
          ..alt = fileName
          ..style.maxWidth = '100%'
          ..style.maxHeight = '100%'
          ..style.objectFit = 'contain';
        element.append(img);
        return element;
      }

      final iframe = html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      if (isPdf) {
        iframe.src = fileUrl;
      } else {
        iframe.src =
            'https://docs.google.com/viewer?url=${Uri.encodeComponent(fileUrl)}&embedded=true';
      }
      return iframe;
    });
  }

  return HtmlElementView(viewType: viewType);
}
