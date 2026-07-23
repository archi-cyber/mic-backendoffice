import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/mic_theme.dart';
import '../../services/department_service.dart';
import '../../services/service_schedule_service.dart';
import '../tasks/task_assignee_picker.dart';
import 'service_schedule_constants.dart';

class ServiceSchedulePage extends StatefulWidget {
  const ServiceSchedulePage({
    super.key,
    required this.departmentId,
    this.hideAppBarAndBottomNav = false,
    this.onClose,
  });

  final String departmentId;
  final bool hideAppBarAndBottomNav;
  final VoidCallback? onClose;

  @override
  State<ServiceSchedulePage> createState() => _ServiceSchedulePageState();
}

class _ServiceSchedulePageState extends State<ServiceSchedulePage> {
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _canEdit = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ServiceScheduleService.getSchedules(departmentId: widget.departmentId),
        DepartmentService.getDepartmentMembers(widget.departmentId),
        DepartmentService.canEditDepartment(widget.departmentId),
      ]);
      if (!mounted) return;
      final memberRows = List<Map<String, dynamic>>.from(results[1] as List);
      final members = memberRows
          .map((row) {
            final member = row['members'];
            if (member is Map) {
              return Map<String, dynamic>.from(member);
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
      setState(() {
        _schedules = List<Map<String, dynamic>>.from(results[0] as List);
        _members = members;
        _canEdit = results[2] as bool;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) return value ?? '—';
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat('EEE, d MMM y', locale).format(parsed);
  }

  List<Map<String, dynamic>> _roleAssignments(
    Map<String, dynamic> schedule,
    String role,
  ) {
    final rows = schedule['service_schedule_assignments'];
    if (rows is! List) return [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['role']?.toString() == role)
        .toList();
  }

  Future<void> _addServiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null || !mounted) return;

    try {
      await ServiceScheduleService.createSchedule(
        departmentId: widget.departmentId,
        serviceDate: picked,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Service date added')),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteSchedule(Map<String, dynamic> schedule) async {
    final id = schedule['id']?.toString();
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Delete service date?')),
        content: Text(
          context.tr('This will remove all assignments for {date}.', {
            'date': _formatDate(schedule['service_date']?.toString()),
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ServiceScheduleService.deleteSchedule(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _editNotes(Map<String, dynamic> schedule) async {
    if (!_canEdit) return;
    final id = schedule['id']?.toString();
    if (id == null) return;

    final controller = TextEditingController(
      text: schedule['notes']?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Notes')),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: context.tr('Add notes for this service…'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('Save')),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;

    try {
      await ServiceScheduleService.updateNotes(
        scheduleId: id,
        notes: controller.text,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openRoleEditor({
    required Map<String, dynamic> schedule,
    required String role,
  }) async {
    if (!_canEdit) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return _RoleEditorSheet(
          schedule: schedule,
          role: role,
          roleLabel: context.tr(ServiceScheduleRoles.labelKey(role)),
          members: _members,
          serviceDateLabel: _formatDate(schedule['service_date']?.toString()),
          onChanged: _load,
        );
      },
    );
  }

  Future<void> _toggleDone({
    required String assignmentId,
    required bool isDone,
  }) async {
    if (!_canEdit) return;
    try {
      await ServiceScheduleService.setAssignmentDone(
        assignmentId: assignmentId,
        isDone: isDone,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingLG),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  SizedBox(height: AppDimensions.spacingMD),
                  Text(_error!, textAlign: TextAlign.center),
                  SizedBox(height: AppDimensions.spacingMD),
                  FilledButton(
                    onPressed: _load,
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
          )
        : _schedules.isEmpty
        ? _buildEmptyState(theme)
        : RefreshIndicator(onRefresh: _load, child: _buildTable(theme));

    if (widget.hideAppBarAndBottomNav) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onClose != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onClose,
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.paddingMD,
              0,
              AppDimensions.paddingMD,
              AppDimensions.spacingSM,
            ),
            child: _buildHeader(theme),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Service schedule')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: context.tr('Refresh'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            child: _buildHeader(theme),
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: _addServiceDate,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Add service date')),
            )
          : null,
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            theme.colorScheme.surface,
          ],
        ),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Media service schedule'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  _canEdit
                      ? context.tr(
                          'Assign up to 3 members per role and track completion.',
                        )
                      : context.tr('View service assignments and completion.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: AppDimensions.spacingXL * 2),
        Icon(
          Icons.calendar_month_outlined,
          size: 72,
          color: context.mic.textSecondary,
        ),
        SizedBox(height: AppDimensions.spacingMD),
        Center(
          child: Text(
            context.tr('No service dates yet'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: AppDimensions.spacingSM),
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingXL),
            child: Text(
              context.tr('Add a service date to start assigning roles.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.mic.textSecondary,
              ),
            ),
          ),
        ),
        if (_canEdit) ...[
          SizedBox(height: AppDimensions.spacingLG),
          Center(
            child: FilledButton.icon(
              onPressed: _addServiceDate,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Add service date')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTable(ThemeData theme) {
    final borderColor = theme.dividerColor.withValues(alpha: 0.45);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: context.mic.textSecondary,
    );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        0,
        AppDimensions.paddingMD,
        AppDimensions.paddingXL * 2,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Material(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            side: BorderSide(color: borderColor),
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            dataRowMinHeight: 72,
            dataRowMaxHeight: 140,
            columnSpacing: 20,
            horizontalMargin: 16,
            columns: [
              DataColumn(
                label: Text(context.tr('Service date'), style: headerStyle),
              ),
              for (final role in ServiceScheduleRoles.all)
                DataColumn(
                  label: SizedBox(
                    width: 148,
                    child: Text(
                      context.tr(ServiceScheduleRoles.labelKey(role)),
                      style: headerStyle,
                    ),
                  ),
                ),
              DataColumn(label: Text(context.tr('Notes'), style: headerStyle)),
              if (_canEdit)
                DataColumn(
                  label: Text(context.tr('Actions'), style: headerStyle),
                ),
            ],
            rows: _schedules.map((schedule) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      _formatDate(schedule['service_date']?.toString()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final role in ServiceScheduleRoles.all)
                    DataCell(_buildRoleCell(theme, schedule, role)),
                  DataCell(_buildNotesCell(theme, schedule)),
                  if (_canEdit)
                    DataCell(
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                        ),
                        tooltip: context.tr('Delete'),
                        onPressed: () => _deleteSchedule(schedule),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCell(
    ThemeData theme,
    Map<String, dynamic> schedule,
    String role,
  ) {
    final assignments = _roleAssignments(schedule, role);
    final canAdd =
        _canEdit && assignments.length < ServiceScheduleRoles.maxMembersPerRole;

    return InkWell(
      onTap: _canEdit
          ? () => _openRoleEditor(schedule: schedule, role: role)
          : null,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
      child: Container(
        width: 148,
        constraints: const BoxConstraints(minHeight: 56),
        padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (assignments.isEmpty)
              Text(
                context.tr('Unassigned'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.mic.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...assignments.map((assignment) {
                final member = assignment['members'];
                final name = member is Map
                    ? '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'
                          .trim()
                    : '—';
                final assignmentId = assignment['id']?.toString();
                final isDone = assignment['is_done'] == true;
                return Padding(
                  padding: EdgeInsets.only(bottom: AppDimensions.spacingXS),
                  child: Row(
                    children: [
                      if (_canEdit && assignmentId != null)
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Checkbox(
                            value: isDone,
                            activeColor: AppColors.success,
                            onChanged: (value) => _toggleDone(
                              assignmentId: assignmentId,
                              isDone: value ?? false,
                            ),
                          ),
                        )
                      else
                        Icon(
                          isDone
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: isDone
                              ? AppColors.success
                              : context.mic.textSecondary,
                        ),
                      Expanded(
                        child: Text(
                          name.isEmpty ? context.tr('Unnamed member') : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: isDone ? context.mic.textSecondary : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (canAdd)
              Text(
                context.tr('Tap to assign'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCell(ThemeData theme, Map<String, dynamic> schedule) {
    final notes = schedule['notes']?.toString().trim() ?? '';
    return InkWell(
      onTap: _canEdit ? () => _editNotes(schedule) : null,
      child: SizedBox(
        width: 180,
        child: Text(
          notes.isEmpty ? context.tr('Add notes…') : notes,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: notes.isEmpty ? context.mic.textSecondary : null,
            fontStyle: notes.isEmpty ? FontStyle.italic : null,
          ),
        ),
      ),
    );
  }
}

class _RoleEditorSheet extends StatefulWidget {
  const _RoleEditorSheet({
    required this.schedule,
    required this.role,
    required this.roleLabel,
    required this.members,
    required this.serviceDateLabel,
    required this.onChanged,
  });

  final Map<String, dynamic> schedule;
  final String role;
  final String roleLabel;
  final List<Map<String, dynamic>> members;
  final String serviceDateLabel;
  final Future<void> Function() onChanged;

  @override
  State<_RoleEditorSheet> createState() => _RoleEditorSheetState();
}

class _RoleEditorSheetState extends State<_RoleEditorSheet> {
  late List<Map<String, dynamic>> _assignments;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _assignments = _loadAssignments();
  }

  List<Map<String, dynamic>> _loadAssignments() {
    final rows = widget.schedule['service_schedule_assignments'];
    if (rows is! List) return [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['role']?.toString() == widget.role)
        .toList();
  }

  String _memberName(Map<String, dynamic>? member) {
    if (member == null) return context.tr('Unnamed member');
    final name = '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'
        .trim();
    return name.isEmpty ? context.tr('Unnamed member') : name;
  }

  Set<String> get _assignedMemberIds => _assignments
      .map((row) => row['member_id']?.toString())
      .whereType<String>()
      .toSet();

  List<Map<String, dynamic>> get _availableMembers => widget.members
      .where((member) => !_assignedMemberIds.contains(member['id']?.toString()))
      .toList();

  Future<void> _addMember() async {
    if (_assignments.length >= ServiceScheduleRoles.maxMembersPerRole) return;
    if (_availableMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('No members available to assign'))),
      );
      return;
    }

    final memberId = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: TaskAssigneePickerPanel(members: _availableMembers),
      ),
    );
    if (memberId == null || memberId.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final created = await ServiceScheduleService.addAssignment(
        schedule: widget.schedule,
        role: widget.role,
        memberId: memberId,
        serviceDateLabel: widget.serviceDateLabel,
      );
      setState(() {
        _assignments = [..._assignments, created];
        final rows = widget.schedule['service_schedule_assignments'];
        if (rows is List) {
          rows.add(created);
        } else {
          widget.schedule['service_schedule_assignments'] = [created];
        }
        _busy = false;
      });
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _remove(String assignmentId) async {
    setState(() => _busy = true);
    try {
      await ServiceScheduleService.removeAssignment(assignmentId);
      setState(() {
        _assignments.removeWhere(
          (row) => row['id']?.toString() == assignmentId,
        );
        final rows = widget.schedule['service_schedule_assignments'];
        if (rows is List) {
          rows.removeWhere((row) => row['id']?.toString() == assignmentId);
        }
        _busy = false;
      });
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAdd =
        _assignments.length < ServiceScheduleRoles.maxMembersPerRole && !_busy;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingLG,
        AppDimensions.spacingSM,
        AppDimensions.paddingLG,
        AppDimensions.paddingLG + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.roleLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            widget.serviceDateLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.mic.textSecondary,
            ),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          if (_assignments.isEmpty)
            Text(
              context.tr('No members assigned yet'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.mic.textSecondary,
              ),
            )
          else
            ..._assignments.map((assignment) {
              final id = assignment['id']?.toString();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    _memberName(
                          assignment['members'] as Map<String, dynamic>?,
                        ).isNotEmpty
                        ? _memberName(
                            assignment['members'] as Map<String, dynamic>?,
                          )[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  _memberName(assignment['members'] as Map<String, dynamic>?),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: id == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.person_remove_outlined),
                        color: AppColors.error,
                        onPressed: _busy ? null : () => _remove(id),
                      ),
              );
            }),
          SizedBox(height: AppDimensions.spacingSM),
          FilledButton.icon(
            onPressed: canAdd ? _addMember : null,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1_outlined),
            label: Text(
              context.tr('Add member ({count}/{max})', {
                'count': '${_assignments.length}',
                'max': '${ServiceScheduleRoles.maxMembersPerRole}',
              }),
            ),
          ),
        ],
      ),
    );
  }
}
