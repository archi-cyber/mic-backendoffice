import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/tag_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/tag_color_picker.dart';

/// Result of [TaskTagPickerPanel].
class TaskTagPickerResult {
  const TaskTagPickerResult.select(this.tagId)
    : name = null,
      color = null,
      isCreate = false;

  const TaskTagPickerResult.create({
    required this.name,
    required this.color,
  }) : tagId = null,
       isCreate = true;

  final String? tagId;
  final String? name;
  final String? color;
  final bool isCreate;
}

/// Compact tag picker panel for anchored table dropdowns.
class TaskTagPickerPanel extends StatefulWidget {
  const TaskTagPickerPanel({super.key, required this.tags, this.currentTagId});

  final List<Map<String, dynamic>> tags;
  final String? currentTagId;

  @override
  State<TaskTagPickerPanel> createState() => _TaskTagPickerPanelState();
}

class _TaskTagPickerPanelState extends State<TaskTagPickerPanel> {
  final _newTagController = TextEditingController();
  String _selectedColor = TagColors.presetHex.first;

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  void _select(String? tagId) {
    Navigator.of(context).pop(TaskTagPickerResult.select(tagId));
  }

  void _createTag() {
    final name = _newTagController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      TaskTagPickerResult.create(name: name, color: _selectedColor),
    );
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
            constraints: const BoxConstraints(maxHeight: 180),
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
                  final color = TagColors.colorFromHex(
                    tag['color']?.toString(),
                  );
                  final isSelected = id == currentId;
                  return InkWell(
                    onTap: () => _select(id),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingSM,
                        vertical: AppDimensions.spacingSM,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected ? AppColors.primary : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          SizedBox(height: AppDimensions.spacingSM),
          Text(
            context.tr('Color'),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppDimensions.spacingXS),
          TagColorPicker(
            selectedHex: _selectedColor,
            swatchSize: 24,
            onChanged: (hex) => setState(() => _selectedColor = hex),
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
                icon: Icon(Icons.add, size: 20, color: TagColors.colorFromHex(_selectedColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
