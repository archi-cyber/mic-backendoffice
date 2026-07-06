import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';

/// Shared colorful layout widgets for add/edit visitor forms.
class VisitorFormUi {
  VisitorFormUi._();

  static const double desktopBreakpoint = 700;
  static const double desktopMaxWidth = 800;

  static DateTime? parseVisitDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final datePart = s.split('T').first;
    final parts = datePart.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return DateTime.tryParse(s);
  }

  static String formatVisitDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatVisitDateDisplay(DateTime date) {
    return DateFormat('EEE, MMM d, yyyy').format(date);
  }

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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            context.mic.surfaceTint,
            context.mic.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isEdit ? Icons.edit_note : Icons.person_add_alt_1,
              color: AppColors.primary,
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

  static Widget sectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color accent,
    required List<Widget> children,
  }) {
    return Container(
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

  static Widget desktopActionsBar({
    required BuildContext context,
    required bool isLoading,
    required String primaryLabel,
    required IconData primaryIcon,
    required VoidCallback onCancel,
    required VoidCallback onSave,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: isLoading ? null : onCancel, child: Text(context.tr('Cancel'))),
        SizedBox(width: AppDimensions.spacingSM),
        FilledButton.icon(
          onPressed: isLoading ? null : onSave,
          icon: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(primaryIcon, size: 20),
          label: Text(primaryLabel),
        ),
      ],
    );
  }

  static Widget mobileSaveButton({
    required BuildContext context,
    required bool isLoading,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        minimumSize: Size(double.infinity, AppDimensions.buttonHeightLG),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textLight,
              ),
            )
          : Text(label),
    );
  }

  static InputDecoration fieldDecoration({
    required String label,
    required IconData icon,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon),
    );
  }

  static Widget visitDateField({
    required BuildContext context,
    required DateTime? visitDate,
    required VoidCallback onTap,
    String? errorText,
  }) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.inputBorderRadius),
      child: InputDecorator(
        decoration: fieldDecoration(
          label: '${l?.visitDate ?? context.tr('Visit Date')} *',
          icon: Icons.calendar_today_outlined,
        ).copyWith(errorText: errorText),
        child: Text(
          visitDate != null
              ? formatVisitDateDisplay(visitDate)
              : (l?.visitDateRequired ?? context.tr('Select date')),
          style: TextStyle(
            color: visitDate != null
                ? Theme.of(context).textTheme.bodyLarge?.color
                : Theme.of(context).hintColor,
            fontWeight: visitDate != null ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  static Widget serviceTypeDropdown({
    required BuildContext context,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      initialValue: value,
      decoration: fieldDecoration(
        label: context.tr('Service (Optional)'),
        icon: Icons.church_outlined,
        helperText: context.tr('Sunday or Wednesday service, if known'),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(context.tr('Any / not specified')),
        ),
        DropdownMenuItem(
          value: 'sunday',
          child: Text(context.tr('Sunday')),
        ),
        DropdownMenuItem(
          value: 'wednesday',
          child: Text(context.tr('Wednesday')),
        ),
      ],
      onChanged: onChanged,
    );
  }

  static Widget attendanceTypeDropdown({
    required BuildContext context,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: fieldDecoration(
        label: context.tr('Attendance type'),
        icon: Icons.how_to_reg_outlined,
      ),
      items: [
        DropdownMenuItem(
          value: 'onsite',
          child: Text(context.tr('Onsite')),
        ),
        DropdownMenuItem(
          value: 'online',
          child: Text(context.tr('Online')),
        ),
        DropdownMenuItem(
          value: 'absent',
          child: Text(context.tr('Absent')),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
