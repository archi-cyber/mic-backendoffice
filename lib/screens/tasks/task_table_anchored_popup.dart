import 'package:flutter/material.dart';
import '../../core/constants/app_dimensions.dart';

/// Shows a compact panel anchored below a table cell, like the status dropdown.
Future<T?> showTaskTableAnchoredPopup<T>({
  required BuildContext anchorContext,
  required Widget child,
  double width = 300,
}) async {
  final renderBox = anchorContext.findRenderObject() as RenderBox?;
  if (renderBox == null) return null;

  final overlay =
      Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
  final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
  final position = RelativeRect.fromLTRB(
    offset.dx,
    offset.dy + renderBox.size.height,
    offset.dx + renderBox.size.width,
    offset.dy + renderBox.size.height + 320,
  );

  return showMenu<T>(
    context: anchorContext,
    position: position,
    constraints: BoxConstraints(minWidth: width, maxWidth: width),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
    ),
    items: [
      PopupMenuItem<T>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: child,
      ),
    ],
  );
}
