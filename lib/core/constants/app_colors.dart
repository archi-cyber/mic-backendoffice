import 'package:flutter/material.dart';

/// App-wide color constants — MIC brand palette (warm earth tones + vibrant accents).
class AppColors {
  AppColors._();

  // Brand palette (from MIC color guide)
  static const Color parchment = Color(0xFFFDF9F4);
  static const Color peach = Color(0xFFFBE6D6);
  static const Color terracotta = Color(0xFFA65D26);
  static const Color vibrantOrange = Color(0xFFFF8C00);
  static const Color charcoal = Color(0xFF2D3E4E);
  static const Color chocolate = Color(0xFF3A2315);
  static const Color sage = Color(0xFF8FA17E);

  // Primary — terracotta family
  static const Color primary = terracotta;
  static const Color primaryLight = vibrantOrange;
  static const Color primaryDark = chocolate;

  /// Brighter terracotta for dark-mode buttons and links.
  static const Color primaryDarkMode = Color(0xFFE8874A);

  // Secondary — sage green
  static const Color secondary = sage;
  static const Color secondaryLight = Color(0xFFA8B89A);
  static const Color secondaryDark = Color(0xFF6F8260);

  // Accent — vibrant orange highlights
  static const Color accent = vibrantOrange;
  static const Color accentLight = Color(0xFFFFB347);
  static const Color accentDark = Color(0xFFE67E00);

  // Backgrounds & surfaces — light
  static const Color background = parchment;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceTint = peach;
  static const Color sidebar = Color(0xFFFFF5EE);

  // Backgrounds & surfaces — dark (warm espresso / umber tones)
  static const Color backgroundDark = Color(0xFF16110E);
  static const Color surfaceDark = Color(0xFF221A16);
  static const Color surfaceElevatedDark = Color(0xFF2C221C);
  static const Color surfaceTintDark = Color(0xFF3A2E26);
  static const Color sidebarDark = Color(0xFF1A1410);
  static const Color chipBackgroundDark = Color(0xFF352A22);

  // Text — light
  static const Color textPrimary = charcoal;
  static const Color textSecondary = Color(0xFF5C6B7A);
  static const Color textTertiary = Color(0xFF8A96A3);
  static const Color textLight = Color(0xFFFFFFFF);

  // Text — dark (warm off-whites)
  static const Color textPrimaryDark = Color(0xFFF3EBE3);
  static const Color textSecondaryDark = Color(0xFFC9BAB0);
  static const Color textTertiaryDark = Color(0xFF948578);

  // Status
  static const Color success = sage;
  static const Color successDark = Color(0xFF9DB58C);
  static const Color warning = vibrantOrange;
  static const Color error = Color(0xFFC94A2E);
  static const Color errorDark = Color(0xFFE86B52);
  static const Color info = Color(0xFF4A6FA5);
  static const Color infoDark = Color(0xFF7BA3D4);

  // Borders & dividers
  static const Color border = Color(0xFFE8D4C4);
  static const Color borderDark = Color(0xFF4A3C32);

  static const Color divider = Color(0xFFE8D4C4);
  static const Color dividerDark = Color(0xFF3D3129);

  // App chrome — dark
  static const Color appBarDark = Color(0xFF2A2019);
  static const Color appBarForegroundDark = Color(0xFFF5E6D8);

  // Misc
  static const Color shadow = Color(0x1A3A2315);
  static const Color shadowDark = Color(0x66000000);
  static const Color overlay = Color(0x802D3E4E);
  static const Color overlayDark = Color(0xB316110E);
  static const Color disabled = Color(0xFFD4C4B8);
  static const Color disabledText = Color(0xFF9CA3AF);
  static const Color disabledTextDark = Color(0xFF6E625A);

  /// Subtle brand gradient for splash, headers, and hero areas.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [terracotta, vibrantOrange],
  );

  static const LinearGradient brandGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B4518), Color(0xFF3A2315), Color(0xFF1A1410)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient headerGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4A3828),
      Color(0xFF2C221C),
      Color(0xFF1E1814),
    ],
    stops: [0.0, 0.5, 1.0],
  );
}
