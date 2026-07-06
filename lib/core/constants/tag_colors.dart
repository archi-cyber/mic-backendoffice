import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Preset colors for tags (hex strings for DB, Color for UI).
class TagColors {
  TagColors._();

  /// Default color when none is set (neutral warm grey).
  static const String defaultHex = '#8A96A3';

  /// Preset palette aligned with MIC brand colors.
  static const List<String> presetHex = [
    '#C94A2E', // warm red
    '#FF8C00', // vibrant orange
    '#A65D26', // terracotta
    '#E67E00', // deep orange
    '#8FA17E', // sage
    '#6F8260', // dark sage
    '#4A6FA5', // slate blue
    '#2D3E4E', // charcoal
    '#3A2315', // chocolate
    '#FBE6D6', // peach
    '#D4A574', // sand
    '#C9A227', // gold
    '#B85C38', // rust
    '#7B9E6B', // moss
    '#5C7A8A', // steel
    '#8A96A3', // grey
  ];

  /// Parse hex string to Color; returns grey if invalid.
  static Color colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.textTertiary;
    String h = hex.startsWith('#') ? hex : '#$hex';
    if (h.length != 7) return AppColors.textTertiary;
    final n = int.tryParse(h.substring(1), radix: 16);
    if (n == null) return AppColors.textTertiary;
    return Color(0xFF000000 | n);
  }
}
