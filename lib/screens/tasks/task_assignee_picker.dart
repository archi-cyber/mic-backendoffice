import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/mic_theme.dart';

/// Compact searchable assignee panel for anchored table dropdowns.
class TaskAssigneePickerPanel extends StatefulWidget {
  const TaskAssigneePickerPanel({
    super.key,
    required this.members,
    this.currentMemberId,
  });

  final List<Map<String, dynamic>> members;
  final String? currentMemberId;

  @override
  State<TaskAssigneePickerPanel> createState() => _TaskAssigneePickerPanelState();
}

class _TaskAssigneePickerPanelState extends State<TaskAssigneePickerPanel> {
  final _searchController = TextEditingController();
  late List<Map<String, dynamic>> _filteredMembers;

  @override
  void initState() {
    super.initState();
    _filteredMembers = _sortedMembers(widget.members);
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _sortedMembers(List<Map<String, dynamic>> members) {
    final sorted = [...members];
    sorted.sort((a, b) {
      final na = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim();
      final nb = '${b['first_name'] ?? ''} ${b['last_name'] ?? ''}'.trim();
      return na.toLowerCase().compareTo(nb.toLowerCase());
    });
    return sorted;
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _sortedMembers(widget.members);
        return;
      }
      _filteredMembers = _sortedMembers(widget.members).where((member) {
        final firstName = member['first_name']?.toString().toLowerCase() ?? '';
        final lastName = member['last_name']?.toString().toLowerCase() ?? '';
        final email = member['email']?.toString().toLowerCase() ?? '';
        final fullName = '$firstName $lastName'.trim();
        return firstName.contains(query) ||
            lastName.contains(query) ||
            fullName.contains(query) ||
            email.contains(query);
      }).toList();
    });
  }

  String _memberName(Map<String, dynamic> member) {
    final name = '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'
        .trim();
    return name.isEmpty ? context.tr('Unnamed member') : name;
  }

  void _select(String? memberId) {
    Navigator.of(context).pop(memberId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentId = widget.currentMemberId;

    return Padding(
      padding: EdgeInsets.all(AppDimensions.paddingSM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: context.tr('Search members...'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _searchController.clear,
                    ),
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingSM,
                vertical: AppDimensions.spacingSM,
              ),
            ),
            textInputAction: TextInputAction.search,
          ),
          SizedBox(height: AppDimensions.spacingSM),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
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
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 18,
                          color: context.mic.textSecondary,
                        ),
                        SizedBox(width: AppDimensions.spacingSM),
                        Expanded(
                          child: Text(
                            context.tr('Unassigned'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: currentId == null
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: currentId == null
                                  ? AppColors.primary
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_filteredMembers.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppDimensions.paddingMD,
                      horizontal: AppDimensions.paddingSM,
                    ),
                    child: Text(
                      _searchController.text.isEmpty
                          ? context.tr('No members found in this department')
                          : context.tr('No members found'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  )
                else
                  ..._filteredMembers.map((member) {
                    final id = member['id']?.toString() ?? '';
                    final isBlocked = member['is_assignment_blocked'] == true;
                    final isSelected = id == currentId;
                    return InkWell(
                      onTap: isBlocked ? null : () => _select(id),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingSM,
                          vertical: AppDimensions.spacingSM,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: isBlocked
                                  ? AppColors.error.withValues(alpha: 0.12)
                                  : AppColors.primary.withValues(alpha: 0.12),
                              child: Text(
                                _memberName(member)[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isBlocked
                                      ? AppColors.error
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                            SizedBox(width: AppDimensions.spacingSM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _memberName(member),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.primary
                                          : isBlocked
                                          ? context.mic.textSecondary
                                          : null,
                                    ),
                                  ),
                                  if (isBlocked)
                                    Text(
                                      context.tr(
                                        'Blocked from new task assignments',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.error,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
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
        ],
      ),
    );
  }
}
