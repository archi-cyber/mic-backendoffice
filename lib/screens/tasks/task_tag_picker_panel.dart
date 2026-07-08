import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';

/// Compact tag picker panel for anchored table dropdowns.
class TaskTagPickerPanel extends StatefulWidget {
  const TaskTagPickerPanel({
    super.key,
    required this.tags,
    this.currentTagId,
  });

  final List<Map<String, dynamic>> tags;
  final String? currentTagId;

  @override
  State<TaskTagPickerPanel> createState() => _TaskTagPickerPanelState();
}

class _TaskTagPickerPanelState extends State<TaskTagPickerPanel> {
  final _newTagController = TextEditingController();

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  void _select(String? tagId) {
    Navigator.of(context).pop(tagId);
  }

  void _createTag() {
    final name = _newTagController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop('create:$name');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentId = widget.currentTagId;

    return Padding(
      padding: EdgeInsets.all(AppDimensions.paddingSM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(
              shrinkWrap: true,
              children: [
                InkWell(
                  onTap: () => _select(''),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingSM,
                      vertical: AppDimensions.spacingSM,
                    ),
                    child: Text(
                      context.tr('No tag'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: currentId == null
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: currentId == null ? AppColors.primary : null,
                      ),
                    ),
                  ),
                ),
                ...widget.tags.map((tag) {
                  final id = tag['id']?.toString() ?? '';
                  final name = tag['name']?.toString() ?? '—';
                  final isSelected = id == currentId;
                  return InkWell(
                    onTap: () => _select(id),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingSM,
                        vertical: AppDimensions.spacingSM,
                      ),
                      child: Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          SizedBox(height: AppDimensions.spacingSM),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newTagController,
                  decoration: InputDecoration(
                    hintText: context.tr('Create tag'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingSM,
                      vertical: AppDimensions.spacingSM,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _createTag(),
                ),
              ),
              SizedBox(width: AppDimensions.spacingXS),
              IconButton(
                tooltip: context.tr('Create'),
                visualDensity: VisualDensity.compact,
                onPressed: _createTag,
                icon: const Icon(Icons.add, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
