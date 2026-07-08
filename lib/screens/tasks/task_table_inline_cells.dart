import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';

/// Inline text field for desktop task table cells (title, description).
class TaskTableInlineTextCell extends StatefulWidget {
  const TaskTableInlineTextCell({
    super.key,
    required this.text,
    required this.hint,
    required this.onCommit,
    this.style,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String text;
  final String hint;
  final Future<void> Function(String value) onCommit;
  final TextStyle? style;
  final int maxLines;
  final bool enabled;

  @override
  State<TaskTableInlineTextCell> createState() =>
      _TaskTableInlineTextCellState();
}

class _TaskTableInlineTextCellState extends State<TaskTableInlineTextCell> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _editing = false;
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(TaskTableInlineTextCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _editing) {
      _commit();
    }
  }

  Future<void> _commit() async {
    if (_committing) return;
    final next = _controller.text.trim();
    final previous = widget.text.trim();
    setState(() => _editing = false);
    if (next == previous) return;

    _committing = true;
    try {
      await widget.onCommit(next);
    } finally {
      _committing = false;
    }
  }

  void _startEditing() {
    if (!widget.enabled || _editing) return;
    setState(() {
      _editing = true;
      _controller.text = widget.text;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Text(
        widget.text.isEmpty ? widget.hint : widget.text,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        style: widget.style,
      );
    }

    if (_editing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        style: widget.style,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          hintText: widget.hint,
        ),
        onSubmitted: (_) => _commit(),
      );
    }

    final display = widget.text.trim().isEmpty ? widget.hint : widget.text;
    final isPlaceholder = widget.text.trim().isEmpty;

    return InkWell(
      onTap: _startEditing,
      child: Text(
        display,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        style: widget.style?.copyWith(
          color: isPlaceholder
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)
              : widget.style?.color,
          fontStyle: isPlaceholder ? FontStyle.italic : null,
        ),
      ),
    );
  }
}

/// Tappable cell that shows a hover/focus ring for popup editors.
class TaskTableTappableCell extends StatelessWidget {
  const TaskTableTappableCell({
    super.key,
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXS),
          child: child,
        ),
      ),
    );
  }
}
