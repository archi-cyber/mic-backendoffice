import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';

/// Shared MIC-themed layout widgets for member screens.
class MemberFormUi {
  MemberFormUi._();

  static const double desktopBreakpoint = 700;
  static const double desktopMaxWidth = 1000;
  static const double profileMaxWidth = 900;

  static Color roleColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.error;
      case 'leader':
        return AppColors.warning;
      case 'worker':
        return AppColors.primary;
      case 'sympathiser':
        return AppColors.info;
      default:
        return AppColors.secondaryDark;
    }
  }

  static String roleLabel(BuildContext context, String role) {
    switch (role) {
      case 'admin':
        return context.tr('Admin');
      case 'leader':
        return context.tr('Leader');
      case 'worker':
        return context.tr('Worker');
      case 'sympathiser':
        return context.tr('Sympathiser');
      default:
        return context.tr('Member');
    }
  }

  static IconData roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'leader':
        return Icons.leaderboard;
      case 'worker':
        return Icons.work;
      case 'sympathiser':
        return Icons.favorite;
      default:
        return Icons.person;
    }
  }

  static Widget heroBanner({
    required BuildContext context,
    required bool isEdit,
    required String title,
    String? subtitle,
    Color? accent,
  }) {
    final color = accent ?? AppColors.primary;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        gradient: context.mic.accentBanner(color),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: context.mic.accentBorder(color)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isEdit ? Icons.edit_note : Icons.person_add_alt_1,
              color: color,
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
    required IconData icon,
    Color accent = AppColors.primary,
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
            child: Icon(icon, color: accent, size: 30),
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
    required Color accent,
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
            color: accent.withValues(alpha: 0.06),
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
            color: accent.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accent),
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

  static Widget roleChip(BuildContext context, String role) {
    final color = roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(roleIcon(role), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            roleLabel(context, role),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Widget infoRow({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.mic.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.mic.appBarForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget profileHero({
    required BuildContext context,
    required String fullName,
    required String? email,
    required String role,
    required bool isActive,
    String? photoUrl,
    String? initials,
  }) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return Container(
      margin: EdgeInsets.all(AppDimensions.paddingMD),
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        gradient: context.mic.accentBanner(MemberFormUi.roleColor(role)),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(
          color: context.mic.accentBorder(MemberFormUi.roleColor(role)),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor:
                    MemberFormUi.roleColor(role).withValues(alpha: 0.15),
                backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                child: hasPhoto
                    ? null
                    : Text(
                        initials ?? 'M',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: MemberFormUi.roleColor(role),
                        ),
                      ),
              ),
              if (isActive)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.mic.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.mic.appBarForeground,
                  ),
                ),
                if (email != null && email.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.mic.textSecondary,
                    ),
                  ),
                ],
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    roleChip(context, role),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isActive ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isActive
                            ? context.tr('Active')
                            : context.tr('Inactive'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color:
                              isActive ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static TabBar coloredTabBar({
    required BuildContext context,
    required List<Tab> tabs,
  }) {
    return TabBar(
      tabs: tabs,
      labelColor: AppColors.primary,
      unselectedLabelColor: context.mic.textSecondary,
      indicatorColor: AppColors.accent,
      indicatorWeight: 3,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
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
