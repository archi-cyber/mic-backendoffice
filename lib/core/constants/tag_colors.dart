import 'package:flutter/material.dart';

/// Preset colors for tags (hex strings for DB, Color for UI).
class TagColors {
  TagColors._();

  /// Default color when none is set (neutral grey).
  static const String defaultHex = '#9CA3AF';

  /// Preset palette for tag color picker (hex).
  static const List<String> presetHex = [
    '#EF4444', // red
    '#F97316', // orange
    '#F59E0B', // amber
    '#EAB308', // yellow
    '#84CC16', // lime
    '#22C55E', // green
    '#10B981', // emerald
    '#14B8A6', // teal
    '#06B6D4', // cyan
    '#3B82F6', // blue
    '#6366F1', // indigo
    '#8B5CF6', // violet
    '#A855F7', // purple
    '#D946EF', // fuchsia
    '#EC4899', // pink
    '#9CA3AF', // gray
  ];

  /// Parse hex string to Color; returns grey if invalid.
  static Color colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF9CA3AF);
    String h = hex.startsWith('#') ? hex : '#$hex';
    if (h.length != 7) return const Color(0xFF9CA3AF);
    final n = int.tryParse(h.substring(1), radix: 16);
    if (n == null) return const Color(0xFF9CA3AF);
    return Color(0xFF000000 | n);
  }
}
