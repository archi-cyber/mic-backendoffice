import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';

/// Shared MIC-themed layout widgets for department screens.
class DepartmentFormUi {
  DepartmentFormUi._();

  static const double desktopBreakpoint = 700;
  static const double desktopMaxWidth = 920;
  static const Color accent = AppColors.info;

  static Widget heroBanner({
    required BuildContext context,
    required bool isEdit,
    required String title,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        gradient: context.mic.accentBanner(accent),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: context.mic.accentBorder(accent)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.mic.accentIconBackground(accent),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isEdit ? Icons.edit_note : Icons.add_business_outlined,
              color: accent,
              size: 28,
            ),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.mic.appBarForeground,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: AppDimensions.spacingXS),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.mic.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget listHeaderBanner({
    required BuildContext context,
    required String title,
    required String subtitle,
    bool compactTop = false,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        compactTop ? 0 : AppDimensions.spacingSM,
        AppDimensions.paddingMD,
        0,
      ),
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        gradient: context.mic.accentBanner(accent),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: context.mic.accentBorder(accent)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.mic.appBarForeground,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.groups_outlined, color: accent, size: 30),
          ),
        ],
      ),
    );
  }

  static Widget statChip({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 118,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingSM + 4,
          vertical: AppDimensions.paddingSM,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.mic.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget sectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: AppDimensions.spacingLG),
      decoration: BoxDecoration(
        color: context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: context.mic.border),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMD,
              vertical: AppDimensions.spacingSM,
            ),
            color: accentColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                SizedBox(width: AppDimensions.spacingSM),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.mic.appBarForeground,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  static Widget departmentListTile({
    required BuildContext context,
    required String name,
    String? description,
    required String leaderName,
    required int taskCount,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        0,
        AppDimensions.paddingMD,
        AppDimensions.spacingSM,
      ),
      decoration: BoxDecoration(
        color: context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: context.mic.border),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.apartment, color: accent),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.mic.appBarForeground,
                        ),
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.mic.textSecondary,
                          ),
                        ),
                      ],
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _miniChip(
                            context,
                            Icons.person_outline,
                            leaderName,
                            AppColors.primary,
                          ),
                          _miniChip(
                            context,
                            Icons.task_alt_outlined,
                            '$taskCount',
                            AppColors.accent,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (isActive
                                      ? AppColors.success
                                      : AppColors.error)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive
                                  ? context.tr('Active')
                                  : context.tr('Inactive'),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: isActive
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.mic.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _miniChip(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.mic.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  static TabBar coloredTabBar({
    required BuildContext context,
    required List<Tab> tabs,
    TabController? controller,
  }) {
    return _segmentedTabBar(
      context: context,
      tabs: tabs,
      controller: controller,
    );
  }

  /// Segmented tab bar with a filled indicator for the selected tab.
  static Widget listPageTabBar({
    required BuildContext context,
    required List<Tab> tabs,
    TabController? controller,
    EdgeInsetsGeometry margin = const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingMD,
    ),
    Color? selectedColor,
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: context.mic.border.withValues(alpha: 0.45)),
      ),
      child: _segmentedTabBar(
        context: context,
        tabs: tabs,
        controller: controller,
        selectedColor: selectedColor,
      ),
    );
  }

  static TabBar _segmentedTabBar({
    required BuildContext context,
    required List<Tab> tabs,
    TabController? controller,
    Color? selectedColor,
  }) {
    final accentColor = selectedColor ?? DepartmentFormUi.accent;
    final theme = Theme.of(context);

    return TabBar(
      controller: controller,
      tabs: tabs,
      indicator: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: accentColor,
      unselectedLabelColor: context.mic.textSecondary,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
    );
  }

  static Color departmentsTabTint(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Color.alphaBlend(accent.withValues(alpha: 0.025), surface);
  }

  static Color workersTabTint(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Color.alphaBlend(AppColors.secondary.withValues(alpha: 0.025), surface);
  }

  static InputDecoration fieldDecoration({
    required BuildContext context,
    required String label,
    required IconData icon,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: context.mic.surface,
    );
  }
}
