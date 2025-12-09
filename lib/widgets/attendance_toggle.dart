import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_dimensions.dart';

/// Fast toggle widget for attendance status
class AttendanceToggle extends StatelessWidget {
  final String memberId;
  final String memberName;
  final String? currentStatus; // 'present', 'absent', 'late', null
  final Function(String memberId, String status) onStatusChanged;

  const AttendanceToggle({
    super.key,
    required this.memberId,
    required this.memberName,
    this.currentStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: AppDimensions.spacingXS,
        horizontal: AppDimensions.spacingSM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingSM),
        child: Row(
          children: [
            // Member name
            Expanded(
              child: Text(
                memberName,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            // Status buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusButton(
                  label: 'P',
                  status: 'present',
                  isSelected: currentStatus == 'present',
                  color: AppColors.success,
                  onTap: () => onStatusChanged(memberId, 'present'),
                ),
                const SizedBox(width: AppDimensions.spacingXS),
                _StatusButton(
                  label: 'L',
                  status: 'late',
                  isSelected: currentStatus == 'late',
                  color: AppColors.warning,
                  onTap: () => onStatusChanged(memberId, 'late'),
                ),
                const SizedBox(width: AppDimensions.spacingXS),
                _StatusButton(
                  label: 'A',
                  status: 'absent',
                  isSelected: currentStatus == 'absent',
                  color: AppColors.error,
                  onTap: () => onStatusChanged(memberId, 'absent'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Status button widget
class _StatusButton extends StatelessWidget {
  final String label;
  final String status;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.status,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.textLight : color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
