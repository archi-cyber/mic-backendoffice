import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_dimensions.dart';
import 'mic_theme.dart';

/// App theme configuration
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.textLight,
          primaryContainer: AppColors.peach,
          onPrimaryContainer: AppColors.chocolate,
          secondary: AppColors.secondary,
          onSecondary: AppColors.textLight,
          secondaryContainer: AppColors.secondaryLight.withValues(alpha: 0.35),
          onSecondaryContainer: AppColors.chocolate,
          tertiary: AppColors.accent,
          onTertiary: AppColors.textLight,
          tertiaryContainer: AppColors.accentLight.withValues(alpha: 0.35),
          onTertiaryContainer: AppColors.chocolate,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          surfaceContainerLowest: AppColors.background,
          surfaceContainerLow: AppColors.surfaceTint,
          surfaceContainer: AppColors.peach,
          surfaceContainerHigh: AppColors.surfaceTint,
          surfaceContainerHighest: AppColors.peach,
          error: AppColors.error,
          onError: AppColors.textLight,
          outline: AppColors.border,
          outlineVariant: AppColors.peach,
          shadow: AppColors.shadow,
        ),
        mic: MicTheme.light,
        scaffoldBackground: AppColors.background,
        appBar: AppBarTheme(
          elevation: AppDimensions.appBarElevation,
          centerTitle: true,
          backgroundColor: MicTheme.light.appBarBackground,
          foregroundColor: MicTheme.light.appBarForeground,
          surfaceTintColor: MicTheme.light.appBarBackground,
          titleTextStyle: AppTextStyles.titleLarge.copyWith(
            color: MicTheme.light.appBarForeground,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(color: AppColors.primary),
        ),
        cardColor: AppColors.surface,
        inputFill: AppColors.surface,
        chipBackground: AppColors.peach,
        chipLabel: AppColors.chocolate,
        chipSelected: AppColors.primary.withValues(alpha: 0.2),
        navIndicator: AppColors.peach,
        listTileSelected: AppColors.peach.withValues(alpha: 0.65),
        primaryButtonBg: AppColors.primary,
        primaryButtonFg: AppColors.textLight,
        textButtonFg: AppColors.primary,
        outlinedButtonFg: AppColors.primary,
        outlinedButtonBorder: AppColors.primary,
        fabBg: AppColors.accent,
        fabFg: AppColors.textLight,
        progress: AppColors.primary,
        divider: AppColors.divider,
      );

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryDarkMode,
          onPrimary: AppColors.chocolate,
          primaryContainer: AppColors.surfaceTintDark,
          onPrimaryContainer: AppColors.textPrimaryDark,
          secondary: AppColors.secondaryLight,
          onSecondary: AppColors.chocolate,
          secondaryContainer: AppColors.secondaryDark,
          onSecondaryContainer: AppColors.textPrimaryDark,
          tertiary: AppColors.accentLight,
          onTertiary: AppColors.chocolate,
          tertiaryContainer: AppColors.chipBackgroundDark,
          onTertiaryContainer: AppColors.textPrimaryDark,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.textPrimaryDark,
          onSurfaceVariant: AppColors.textSecondaryDark,
          surfaceContainerLowest: AppColors.backgroundDark,
          surfaceContainerLow: AppColors.surfaceElevatedDark,
          surfaceContainer: AppColors.surfaceTintDark,
          surfaceContainerHigh: AppColors.chipBackgroundDark,
          surfaceContainerHighest: AppColors.surfaceTintDark,
          error: AppColors.errorDark,
          onError: AppColors.textLight,
          outline: AppColors.borderDark,
          outlineVariant: AppColors.dividerDark,
          shadow: AppColors.shadowDark,
        ),
        mic: MicTheme.dark,
        scaffoldBackground: AppColors.backgroundDark,
        appBar: AppBarTheme(
          elevation: AppDimensions.appBarElevation,
          centerTitle: true,
          backgroundColor: MicTheme.dark.appBarBackground,
          foregroundColor: MicTheme.dark.appBarForeground,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: AppTextStyles.titleLarge.copyWith(
            color: MicTheme.dark.appBarForeground,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(color: AppColors.primaryDarkMode),
        ),
        cardColor: AppColors.surfaceDark,
        inputFill: AppColors.surfaceElevatedDark,
        chipBackground: AppColors.chipBackgroundDark,
        chipLabel: AppColors.textPrimaryDark,
        chipSelected: AppColors.primaryDarkMode.withValues(alpha: 0.22),
        navIndicator: AppColors.surfaceTintDark,
        listTileSelected: AppColors.surfaceTintDark,
        primaryButtonBg: AppColors.primaryDarkMode,
        primaryButtonFg: AppColors.chocolate,
        textButtonFg: AppColors.primaryDarkMode,
        outlinedButtonFg: AppColors.primaryDarkMode,
        outlinedButtonBorder: AppColors.primaryDarkMode,
        fabBg: AppColors.accent,
        fabFg: AppColors.chocolate,
        progress: AppColors.primaryDarkMode,
        divider: AppColors.dividerDark,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required MicTheme mic,
    required Color scaffoldBackground,
    required AppBarTheme appBar,
    required Color cardColor,
    required Color inputFill,
    required Color chipBackground,
    required Color chipLabel,
    required Color chipSelected,
    required Color navIndicator,
    required Color listTileSelected,
    required Color primaryButtonBg,
    required Color primaryButtonFg,
    required Color textButtonFg,
    required Color outlinedButtonFg,
    required Color outlinedButtonBorder,
    required Color fabBg,
    required Color fabFg,
    required Color progress,
    required Color divider,
  }) {
    final isDark = brightness == Brightness.dark;
    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;

    TextStyle tinted(TextStyle style) =>
        style.copyWith(color: isDark ? onSurface : style.color);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [mic],
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: appBar,
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : AppDimensions.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          side: isDark
              ? BorderSide(color: AppColors.borderDark.withValues(alpha: 0.65))
              : BorderSide.none,
        ),
        color: cardColor,
        surfaceTintColor: isDark ? Colors.transparent : AppColors.peach,
        margin: const EdgeInsets.all(AppDimensions.marginSM),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        labelStyle: TextStyle(color: onSurfaceVariant),
        hintStyle: TextStyle(color: onSurfaceVariant.withValues(alpha: 0.85)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputBorderRadius),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputBorderRadius),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputBorderRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.inputBorderRadius),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.all(AppDimensions.inputPadding),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryButtonBg,
          foregroundColor: primaryButtonFg,
          elevation: isDark ? 0 : 2,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingLG,
            vertical: AppDimensions.paddingMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryButtonBg,
          foregroundColor: primaryButtonFg,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingLG,
            vertical: AppDimensions.paddingMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textButtonFg,
          textStyle: AppTextStyles.button.copyWith(color: textButtonFg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: outlinedButtonFg,
          side: BorderSide(color: outlinedButtonBorder),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingLG,
            vertical: AppDimensions.paddingMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          textStyle: AppTextStyles.button.copyWith(color: outlinedButtonFg),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: fabBg,
        foregroundColor: fabFg,
        elevation: isDark ? 2 : 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chipBackground,
        selectedColor: chipSelected,
        labelStyle: AppTextStyles.labelMedium.copyWith(color: chipLabel),
        secondaryLabelStyle:
            AppTextStyles.labelMedium.copyWith(color: colorScheme.primary),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: isDark ? 0 : 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: navIndicator,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyles.labelMedium.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTextStyles.labelMedium.copyWith(color: onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return IconThemeData(color: onSurfaceVariant);
        }),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: mic.sidebar,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: listTileSelected,
        selectedColor: colorScheme.primary,
        iconColor: onSurfaceVariant,
        textColor: onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: progress),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceTintDark : AppColors.chocolate,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.textPrimaryDark : AppColors.peach,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          side: isDark
              ? BorderSide(color: AppColors.borderDark.withValues(alpha: 0.5))
              : BorderSide.none,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusLG),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          side: isDark
              ? BorderSide(color: AppColors.borderDark.withValues(alpha: 0.5))
              : BorderSide.none,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: tinted(AppTextStyles.displayLarge),
        displayMedium: tinted(AppTextStyles.displayMedium),
        displaySmall: tinted(AppTextStyles.displaySmall),
        headlineLarge: tinted(AppTextStyles.headlineLarge),
        headlineMedium: tinted(AppTextStyles.headlineMedium),
        headlineSmall: tinted(AppTextStyles.headlineSmall),
        titleLarge: tinted(AppTextStyles.titleLarge),
        titleMedium: tinted(AppTextStyles.titleMedium),
        titleSmall: tinted(AppTextStyles.titleSmall),
        bodyLarge: tinted(AppTextStyles.bodyLarge),
        bodyMedium: tinted(AppTextStyles.bodyMedium),
        bodySmall: tinted(AppTextStyles.bodySmall),
        labelLarge: tinted(AppTextStyles.labelLarge),
        labelMedium: tinted(AppTextStyles.labelMedium),
        labelSmall: tinted(AppTextStyles.labelSmall),
      ),
      cardColor: cardColor,
      dividerColor: divider,
      iconTheme: IconThemeData(color: onSurfaceVariant),
    );
  }
}
