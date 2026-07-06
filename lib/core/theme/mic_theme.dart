import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Semantic MIC palette — use [MicTheme.of] / [context.mic] in widgets so
/// light and dark mode share the same API.
@immutable
class MicTheme extends ThemeExtension<MicTheme> {
  const MicTheme({
    required this.background,
    required this.surface,
    required this.surfaceTint,
    required this.sidebar,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.divider,
    required this.brandGradient,
    required this.headerGradient,
    required this.chipBackground,
    required this.appBarBackground,
    required this.appBarForeground,
  });

  final Color background;
  final Color surface;
  final Color surfaceTint;
  final Color sidebar;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color divider;
  final LinearGradient brandGradient;
  final LinearGradient headerGradient;
  final Color chipBackground;
  final Color appBarBackground;
  final Color appBarForeground;

  static const MicTheme light = MicTheme(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceTint: AppColors.surfaceTint,
    sidebar: AppColors.sidebar,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: AppColors.textTertiary,
    border: AppColors.border,
    divider: AppColors.divider,
    brandGradient: AppColors.brandGradient,
    headerGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.info,
        AppColors.peach,
        AppColors.surface,
      ],
      stops: [0.0, 0.45, 1.0],
    ),
    chipBackground: AppColors.peach,
    appBarBackground: AppColors.peach,
    appBarForeground: AppColors.chocolate,
  );

  static const MicTheme dark = MicTheme(
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    surfaceTint: AppColors.surfaceTintDark,
    sidebar: AppColors.sidebarDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textTertiaryDark,
    border: AppColors.borderDark,
    divider: AppColors.dividerDark,
    brandGradient: AppColors.brandGradientDark,
    headerGradient: AppColors.headerGradientDark,
    chipBackground: AppColors.chipBackgroundDark,
    appBarBackground: AppColors.appBarDark,
    appBarForeground: AppColors.appBarForegroundDark,
  );

  factory MicTheme.of(BuildContext context) {
    return Theme.of(context).extension<MicTheme>() ?? MicTheme.light;
  }

  bool get isDark => identical(this, dark);

  /// Hero / form page banners — warm brand gradient in dark mode.
  LinearGradient accentBanner(Color accent) {
    if (isDark) return brandGradient;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accent.withValues(alpha: 0.2),
        surfaceTint,
        surface,
      ],
    );
  }

  Color accentBorder(Color accent) {
    if (isDark) return border.withValues(alpha: 0.8);
    return accent.withValues(alpha: 0.2);
  }

  Color accentIconBackground(Color accent) {
    if (isDark) return surfaceTint;
    return accent.withValues(alpha: 0.15);
  }

  @override
  MicTheme copyWith({
    Color? background,
    Color? surface,
    Color? surfaceTint,
    Color? sidebar,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    Color? divider,
    LinearGradient? brandGradient,
    LinearGradient? headerGradient,
    Color? chipBackground,
    Color? appBarBackground,
    Color? appBarForeground,
  }) {
    return MicTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceTint: surfaceTint ?? this.surfaceTint,
      sidebar: sidebar ?? this.sidebar,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      brandGradient: brandGradient ?? this.brandGradient,
      headerGradient: headerGradient ?? this.headerGradient,
      chipBackground: chipBackground ?? this.chipBackground,
      appBarBackground: appBarBackground ?? this.appBarBackground,
      appBarForeground: appBarForeground ?? this.appBarForeground,
    );
  }

  @override
  MicTheme lerp(ThemeExtension<MicTheme>? other, double t) {
    if (other is! MicTheme) return this;
    return MicTheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceTint: Color.lerp(surfaceTint, other.surfaceTint, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      brandGradient: t < 0.5 ? brandGradient : other.brandGradient,
      headerGradient: t < 0.5 ? headerGradient : other.headerGradient,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      appBarBackground:
          Color.lerp(appBarBackground, other.appBarBackground, t)!,
      appBarForeground:
          Color.lerp(appBarForeground, other.appBarForeground, t)!,
    );
  }
}

extension MicThemeContext on BuildContext {
  MicTheme get mic => MicTheme.of(this);
}
