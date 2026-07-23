import 'package:flutter/material.dart';

import '../core/constants/tag_colors.dart';

/// Compact palette picker for tag colors.
class TagColorPicker extends StatelessWidget {
  const TagColorPicker({
    super.key,
    required this.selectedHex,
    required this.onChanged,
    this.swatchSize = 28,
  });

  final String selectedHex;
  final ValueChanged<String> onChanged;
  final double swatchSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TagColors.presetHex.map((hex) {
        final selected = selectedHex.toUpperCase() == hex.toUpperCase();
        return GestureDetector(
          onTap: () => onChanged(hex),
          child: Container(
            width: swatchSize,
            height: swatchSize,
            decoration: BoxDecoration(
              color: TagColors.colorFromHex(hex),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.dividerColor.withValues(alpha: 0.4),
                width: selected ? 3 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
