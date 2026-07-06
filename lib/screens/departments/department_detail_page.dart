import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../desktop/desktop_shell_scope.dart';
import '../../services/department_service.dart';
import '../../services/task_service.dart';
import '../../services/member_service.dart';
import '../../services/department_report_service.dart';
import '../../services/department_report_pdf_service.dart';
import '../../services/task_report_pdf_service.dart';
import '../../services/task_report_service.dart';
import '../../services/storage_service.dart';
import 'edit_department_page.dart';
import 'department_form_ui.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Department detail with members, docs, tasks, and reports
class DepartmentDetailPage extends StatefulWidget {
  final String departmentId;

  /// When set (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  DepartmentDetailPage({super.key, required this.departmentId, this.onClose});

  @override
  State<DepartmentDetailPage> createState() => _DepartmentDetailPageState();
}

class _DepartmentDetailPageState extends State<DepartmentDetailPage> {
  Map<String, dynamic>? _department;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  bool _canEdit = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _loadDepartmentData();
  }

  Future<void> _loadDepartmentData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final department = await DepartmentService.getDepartmentById(
        widget.departmentId,
      );
      final departmentMembers = await DepartmentService.getDepartmentMembers(
        widget.departmentId,
      );
      final departmentTasks = await TaskService.getDepartmentTasks(
        departmentId: widget.departmentId,
        limit: 100,
      );

      // Load reports (might fail if table doesn't exist, so catch separately)
      List<Map<String, dynamic>> departmentReports = [];
      try {
        departmentReports = await DepartmentReportService.getDepartmentReports(
          departmentId: widget.departmentId,
        );
      } catch (e) {
        // Reports table might not exist yet, that's okay
        debugPrint('Could not load reports: $e');
      }

      // Check if user can edit this department (admin, leader, or subleader)
      final canEdit = await DepartmentService.canEditDepartment(
        widget.departmentId,
      );

      // Check if user can delete this department (admin or leader only, not subleader)
      final canDelete = await DepartmentService.canDeleteDepartment(
        widget.departmentId,
      );

      if (!mounted) return;
      setState(() {
        _department = department;
        // Store full department_members data (includes role)
        _members = departmentMembers;
        _tasks = departmentTasks;
        _reports = departmentReports;
        _canEdit = canEdit;
        _canDelete = canDelete;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading department: $e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.mic.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_department == null) {
      return Scaffold(
        backgroundColor: context.mic.background,
        appBar: AppBar(title: Text(context.tr('Department'))),
        body: Center(child: Text(context.tr('Department not found'))),
      );
    }

    final isDesktop = isDesktopEmbedded(
      context,
      inShell: widget.onClose != null,
    );

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: context.mic.background,
        appBar: isDesktop
            ? null
            : AppBar(
                leading: widget.onClose != null
                    ? IconButton(
                        icon: Icon(Icons.arrow_back),
                        onPressed: widget.onClose,
                      )
                    : null,
                title: Text(_department!['name'] ?? 'Department'),
                actions: [
                  if (_canEdit)
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _openEditDepartment(context),
                      tooltip: context.tr('Edit Department'),
                    ),
                  if (_canDelete)
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: AppColors.error),
                              SizedBox(width: 8),
                              Text(context.tr('Delete Department')),
                            ],
                          ),
                          onTap: () => _deleteDepartment(),
                        ),
                      ],
                    ),
                ],
                bottom: DepartmentFormUi.coloredTabBar(
                  context: context,
                  tabs: [
                    Tab(text: localizations?.overview ?? 'Overview'),
                    Tab(text: localizations?.members ?? 'Members'),
                    Tab(text: localizations?.tasks ?? 'Tasks'),
                    Tab(text: localizations?.reports ?? 'Reports'),
                  ],
                ),
              ),
        body: isDesktop
            ? _buildDesktopBody(context, localizations)
            : TabBarView(
                children: [
                  _OverviewTab(
                    department: _department!,
                    memberCount: _members.length,
                    taskCount: _tasks.length,
                    onDepartmentUpdated: _loadDepartmentData,
                    isDesktop: false,
                  ),
                  _MembersTab(
                    departmentId: widget.departmentId,
                    onMembersUpdated: _loadDepartmentData,
                    isDesktop: false,
                  ),
                  _TasksTab(
                    departmentId: widget.departmentId,
                    tasks: _tasks,
                    onTasksUpdated: _loadDepartmentData,
                    isDesktop: false,
                  ),
                  _ReportsTab(
                    departmentId: widget.departmentId,
                    reports: _reports,
                    onReportsUpdated: _loadDepartmentData,
                    isDesktop: false,
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _openEditDepartment(BuildContext context) async {
    final isDesktop = isDesktopEmbedded(
      context,
      inShell: widget.onClose != null,
    );

    if (isDesktop) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            clipBehavior: Clip.antiAlias,
            insetPadding: EdgeInsets.all(AppDimensions.paddingLG),
            child: SizedBox(
              width: 920,
              height: MediaQuery.sizeOf(dialogContext).height * 0.88,
              child: EditDepartmentPage(
                departmentId: widget.departmentId,
                onClose: (result) => Navigator.of(dialogContext).pop(result),
              ),
            ),
          );
        },
      );
      if (result == true && mounted) _loadDepartmentData();
      return;
    }

    final result = await Navigator.of(context).pushNamed(
      RouteNames.editDepartment.replaceAll(':id', widget.departmentId),
    );
    if (result == true && mounted) _loadDepartmentData();
  }

  Widget _buildDesktopBody(
    BuildContext context,
    AppLocalizations? localizations,
  ) {
    final theme = Theme.of(context);
    final name = _department!['name']?.toString() ?? 'Department';
    final description = _department!['description']?.toString().trim();
    final isActive = _department!['is_active'] == true;
    final leaderNames = _departmentLeaderNames;
    final completedTasks = _tasks.where((task) {
      return task['status']?.toString() == 'completed';
    }).length;
    final viewportHeight = MediaQuery.sizeOf(context).height;

    return DesktopPageShell(
      maxWidth: kDesktopContentMaxWidth,
      banner: DesktopHeroBanner(
        title: name,
        subtitle: description?.isNotEmpty == true ? description : null,
        icon: Icons.apartment_outlined,
        accent: DepartmentFormUi.accent,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _openEditDepartment(context),
                tooltip: context.tr('Edit Department'),
              ),
            if (_canDelete)
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: _deleteDepartment,
                tooltip: context.tr('Delete Department'),
              ),
          ],
        ),
      ),
      child: SizedBox(
        height: viewportHeight - 280,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 320,
              child: _DepartmentDesktopSummary(
                name: name,
                description: description,
                isActive: isActive,
                leaderNames: leaderNames,
                memberCount: _members.length,
                taskCount: _tasks.length,
                completedTaskCount: completedTasks,
                canEdit: _canEdit,
                canDelete: _canDelete,
                onEdit: () => _openEditDepartment(context),
                onDelete: _deleteDepartment,
              ),
            ),
            SizedBox(width: AppDimensions.spacingLG),
            Expanded(
              child: Material(
                color: theme.colorScheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                  side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.45),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        AppDimensions.paddingLG,
                        AppDimensions.paddingMD,
                        AppDimensions.paddingLG,
                        0,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        border: Border(
                          bottom: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: DepartmentFormUi.coloredTabBar(
                        context: context,
                        tabs: [
                          Tab(text: localizations?.overview ?? 'Overview'),
                          Tab(text: localizations?.members ?? 'Members'),
                          Tab(text: localizations?.tasks ?? 'Tasks'),
                          Tab(text: localizations?.reports ?? 'Reports'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingLG),
                        child: TabBarView(
                          children: [
                            _OverviewTab(
                              department: _department!,
                              memberCount: _members.length,
                              taskCount: _tasks.length,
                              onDepartmentUpdated: _loadDepartmentData,
                              isDesktop: true,
                            ),
                            _MembersTab(
                              departmentId: widget.departmentId,
                              onMembersUpdated: _loadDepartmentData,
                              isDesktop: true,
                            ),
                            _TasksTab(
                              departmentId: widget.departmentId,
                              tasks: _tasks,
                              onTasksUpdated: _loadDepartmentData,
                              isDesktop: true,
                            ),
                            _ReportsTab(
                              departmentId: widget.departmentId,
                              reports: _reports,
                              onReportsUpdated: _loadDepartmentData,
                              isDesktop: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _departmentLeaderNames {
    final leaders = _members
        .where((entry) {
          return entry['role']?.toString() == 'leader';
        })
        .map((entry) {
          final member = entry['members'];
          if (member is! Map<String, dynamic>) return '';
          final firstName = member['first_name']?.toString() ?? '';
          final lastName = member['last_name']?.toString() ?? '';
          return '$firstName $lastName'.trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();

    return leaders.isEmpty ? '—' : leaders.join(', ');
  }

  Future<void> _deleteDepartment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete Department')),
        content: Text(
          'Are you sure you want to delete this department? This will deactivate it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DepartmentService.deleteDepartment(widget.departmentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Department deleted successfully')),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error deleting department: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSM,
        vertical: AppDimensions.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DepartmentDesktopSummary extends StatelessWidget {
  final String name;
  final String? description;
  final bool isActive;
  final String leaderNames;
  final int memberCount;
  final int taskCount;
  final int completedTaskCount;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  _DepartmentDesktopSummary({
    required this.name,
    required this.description,
    required this.isActive,
    required this.leaderNames,
    required this.memberCount,
    required this.taskCount,
    required this.completedTaskCount,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: DepartmentFormUi.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.groups_2_outlined,
                color: DepartmentFormUi.accent,
                size: 32,
              ),
            ),
            SizedBox(height: AppDimensions.spacingLG),
            Text(
              name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            SizedBox(height: AppDimensions.spacingSM),
            _StatusPill(
              label: isActive ? 'Active department' : 'Inactive department',
              color: isActive ? AppColors.success : AppColors.error,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              description?.isNotEmpty == true
                  ? description!
                  : 'No description provided for this department.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.mic.textSecondary,
                height: 1.45,
              ),
            ),
            SizedBox(height: AppDimensions.spacingLG),
            Wrap(
              spacing: AppDimensions.spacingSM,
              runSpacing: AppDimensions.spacingSM,
              children: [
                _DepartmentMetricPill(
                  icon: Icons.person_outline,
                  label: 'Leader',
                  value: leaderNames,
                ),
                _DepartmentMetricPill(
                  icon: Icons.people_outline,
                  label: 'Members',
                  value: '$memberCount',
                ),
                _DepartmentMetricPill(
                  icon: Icons.task_alt_outlined,
                  label: 'Tasks',
                  value: '$taskCount',
                ),
                _DepartmentMetricPill(
                  icon: Icons.check_circle_outline,
                  label: 'Done',
                  value: '$completedTaskCount',
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingLG),
            if (canEdit)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined),
                  label: Text(context.tr('Edit department')),
                ),
              ),
            if (canDelete) ...[
              SizedBox(height: AppDimensions.spacingSM),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline),
                  label: Text(context.tr('Delete department')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DepartmentMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  _DepartmentMetricPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 132,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingSM,
          vertical: AppDimensions.paddingSM,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              ),
              child: Icon(icon, size: 17, color: AppColors.primary),
            ),
            SizedBox(width: AppDimensions.spacingXS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.mic.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentContentPanel extends StatelessWidget {
  final Widget child;

  _DepartmentContentPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: child,
      ),
    );
  }
}

class _DepartmentSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  _DepartmentSectionTitle({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        SizedBox(width: AppDimensions.spacingSM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Overview tab
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> department;
  final int memberCount;
  final int taskCount;
  final VoidCallback onDepartmentUpdated;
  final bool isDesktop;

  _OverviewTab({
    required this.department,
    required this.memberCount,
    required this.taskCount,
    required this.onDepartmentUpdated,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _buildDesktopOverview(context);
    }

    final content = ListView(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      children: [
        DepartmentFormUi.sectionCard(
          context: context,
          title: context.tr('Description'),
          icon: Icons.description_outlined,
          accentColor: DepartmentFormUi.accent,
          children: [
            Text(
              department['description']?.toString() ??
                  context.tr('No description'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        SizedBox(height: AppDimensions.spacingMD),
        DepartmentFormUi.sectionCard(
          context: context,
          title: context.tr('Department Files'),
          icon: Icons.folder_open_outlined,
          accentColor: AppColors.accent,
          children: [
            if (_hasDocuments(department)) ...[
                  if (department['document_1_name'] != null)
                    _buildDocumentTile(
                      context,
                      department['document_1_name'].toString(),
                      department['document_1_url']?.toString(),
                    ),
                  if (department['document_2_name'] != null)
                    _buildDocumentTile(
                      context,
                      department['document_2_name'].toString(),
                      department['document_2_url']?.toString(),
                    ),
                  if (department['document_3_name'] != null)
                    _buildDocumentTile(
                      context,
                      department['document_3_name'].toString(),
                      department['document_3_url']?.toString(),
                    ),
                  if (department['document_4_name'] != null)
                    _buildDocumentTile(
                      context,
                      department['document_4_name'].toString(),
                      department['document_4_url']?.toString(),
                    ),
                ] else
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      context.tr('No files uploaded'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  ),
          ],
        ),
        SizedBox(height: AppDimensions.spacingMD),
        // Stats cards
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Members',
                value: memberCount.toString(),
                icon: Icons.people,
              ),
            ),
            SizedBox(width: AppDimensions.spacingMD),
            Expanded(
              child: _StatCard(
                title: 'Tasks',
                value: taskCount.toString(),
                icon: Icons.task,
              ),
            ),
          ],
        ),
      ],
    );
    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 900),
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _buildDesktopOverview(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: _DepartmentContentPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DepartmentSectionTitle(
              icon: Icons.folder_outlined,
              title: 'Department files',
              subtitle: 'Documents attached to this department',
            ),
            SizedBox(height: AppDimensions.spacingLG),
            if (_hasDocuments(department)) ...[
              if (department['document_1_name'] != null)
                _buildDocumentTile(
                  context,
                  department['document_1_name'].toString(),
                  department['document_1_url']?.toString(),
                ),
              if (department['document_2_name'] != null)
                _buildDocumentTile(
                  context,
                  department['document_2_name'].toString(),
                  department['document_2_url']?.toString(),
                ),
              if (department['document_3_name'] != null)
                _buildDocumentTile(
                  context,
                  department['document_3_name'].toString(),
                  department['document_3_url']?.toString(),
                ),
              if (department['document_4_name'] != null)
                _buildDocumentTile(
                  context,
                  department['document_4_name'].toString(),
                  department['document_4_url']?.toString(),
                ),
            ] else
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppDimensions.paddingLG),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_off_outlined,
                      size: 42,
                      color: context.mic.textSecondary.withValues(alpha: 0.7),
                    ),
                    SizedBox(height: AppDimensions.spacingSM),
                    Text(
                      'No files uploaded',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: AppDimensions.spacingXS),
                    Text(
                      'Use edit department to attach documents.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _hasDocuments(Map<String, dynamic> department) {
    return department['document_1_name'] != null ||
        department['document_2_name'] != null ||
        department['document_3_name'] != null ||
        department['document_4_name'] != null;
  }

  Widget _buildDocumentTile(
    BuildContext context,
    String fileName,
    String? fileUrl,
  ) {
    return ListTile(
      leading: Icon(Icons.insert_drive_file, color: AppColors.primary),
      title: Text(fileName),
      trailing: fileUrl != null
          ? IconButton(
              icon: Icon(Icons.open_in_new),
              onPressed: () => _openDocument(context, fileUrl, fileName),
              tooltip: context.tr('Open file'),
            )
          : null,
      onTap: fileUrl != null
          ? () => _openDocument(context, fileUrl, fileName)
          : null,
    );
  }

  Future<void> _openDocument(
    BuildContext context,
    String fileUrl,
    String fileName,
  ) async {
    try {
      // Try to create a signed URL first (works for both public and private buckets)
      String urlToOpen = fileUrl;

      try {
        // Create a signed URL that's valid for 1 hour
        // This ensures the file can be accessed even if the bucket is private
        urlToOpen = await StorageService.createSignedUrl(fileUrl);
      } catch (e) {
        // If creating signed URL fails, try using the original URL
        // This might work if the bucket is public
        debugPrint('Could not create signed URL, using original URL: $e');
      }

      // Navigate to webview to display the file
      if (context.mounted) {
        Navigator.of(context).pushNamed(
          RouteNames.fileViewer,
          arguments: {'fileUrl': urlToOpen, 'fileName': fileName},
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error opening file: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

/// Members tab
class _MembersTab extends StatefulWidget {
  final String departmentId;
  final VoidCallback onMembersUpdated;
  final bool isDesktop;

  _MembersTab({
    required this.departmentId,
    required this.onMembersUpdated,
    this.isDesktop = false,
  });

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final members = await DepartmentService.getDepartmentMembers(
        widget.departmentId,
      );
      // Sort members alphabetically by first name, then last name
      members.sort((a, b) {
        final memberA = a['members'] as Map<String, dynamic>?;
        final memberB = b['members'] as Map<String, dynamic>?;
        if (memberA == null && memberB == null) return 0;
        if (memberA == null) return 1;
        if (memberB == null) return -1;

        final firstNameA = (memberA['first_name'] ?? '')
            .toString()
            .toLowerCase();
        final lastNameA = (memberA['last_name'] ?? '').toString().toLowerCase();
        final firstNameB = (memberB['first_name'] ?? '')
            .toString()
            .toLowerCase();
        final lastNameB = (memberB['last_name'] ?? '').toString().toLowerCase();

        final firstNameComparison = firstNameA.compareTo(firstNameB);
        if (firstNameComparison != 0) {
          return firstNameComparison;
        }
        return lastNameA.compareTo(lastNameB);
      });
      if (!mounted) return;
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading members: $e'))),
        );
      }
    }
  }

  Future<void> _showAddMemberDialog() async {
    try {
      // Get all members
      final allMembers = await MemberService.getMembers(limit: 1000);

      // Get current member IDs in department
      final currentMemberIds = _members
          .map((dm) => dm['member_id']?.toString())
          .where((id) => id != null)
          .toSet();

      // Filter out members already in department
      final availableMembers = allMembers
          .where((m) => !currentMemberIds.contains(m['id']?.toString()))
          .toList();

      // Sort alphabetically by first name, then last name
      availableMembers.sort((a, b) {
        final firstNameA = (a['first_name'] ?? '').toString().toLowerCase();
        final lastNameA = (a['last_name'] ?? '').toString().toLowerCase();
        final firstNameB = (b['first_name'] ?? '').toString().toLowerCase();
        final lastNameB = (b['last_name'] ?? '').toString().toLowerCase();

        final firstNameComparison = firstNameA.compareTo(firstNameB);
        if (firstNameComparison != 0) {
          return firstNameComparison;
        }
        return lastNameA.compareTo(lastNameB);
      });

      if (availableMembers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('All members are already in this department'),
              ),
            ),
          );
        }
        return;
      }

      final isDesktopDialog =
          MediaQuery.sizeOf(context).width >= 700 && widget.isDesktop;
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _MultiSelectMemberDialog(
          availableMembers: availableMembers,
          narrowForDesktop: isDesktopDialog,
        ),
      );

      if (result != null) {
        final selectedMemberIds = result['memberIds'] as List<String>;
        final selectedRole = result['role'] as String;

        if (selectedMemberIds.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.tr('Please select at least one member')),
                backgroundColor: AppColors.warning,
              ),
            );
          }
          return;
        }

        // Add all selected members
        bool allSuccess = true;
        int successCount = 0;
        String? errorMessage;

        for (final memberId in selectedMemberIds) {
          try {
            await DepartmentService.addMemberToDepartment(
              departmentId: widget.departmentId,
              memberId: memberId,
              role: selectedRole,
            );
            successCount++;
          } catch (e) {
            allSuccess = false;
            errorMessage = e.toString();
            break;
          }
        }

        if (mounted) {
          if (allSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  successCount == 1
                      ? 'Member added successfully'
                      : '$successCount members added successfully',
                ),
                backgroundColor: AppColors.success,
              ),
            );
            _loadMembers();
            widget.onMembersUpdated();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage ?? 'Error adding members'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error adding member: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _changeMemberRole(String memberId, String currentRole) async {
    String? selectedRole = currentRole;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Change Role')),
          content: DropdownButtonFormField<String>(
            initialValue: selectedRole,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Role'),
              prefixIcon: Icon(Icons.badge),
            ),
            items: [
              DropdownMenuItem(
                value: 'member',
                child: Text(context.tr('Member')),
              ),
              DropdownMenuItem(
                value: 'subleader',
                child: Text(context.tr('Subleader')),
              ),
              DropdownMenuItem(
                value: 'leader',
                child: Text(context.tr('Leader')),
              ),
            ],
            onChanged: (value) {
              setDialogState(() {
                selectedRole = value;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Update')),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedRole != null && selectedRole != currentRole) {
      try {
        await DepartmentService.addMemberToDepartment(
          departmentId: widget.departmentId,
          memberId: memberId,
          role: selectedRole!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Role updated successfully')),
              backgroundColor: AppColors.success,
            ),
          );
          _loadMembers();
          widget.onMembersUpdated();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error updating role: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove Member')),
        content: Text(
          'Are you sure you want to remove $memberName from this department?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Remove')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DepartmentService.removeMemberFromDepartment(
          departmentId: widget.departmentId,
          memberId: memberId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Member removed successfully')),
              backgroundColor: AppColors.success,
            ),
          );
          _loadMembers();
          widget.onMembersUpdated();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error removing member: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildRoleChip(String role) {
    Color color;
    IconData icon;

    switch (role) {
      case 'leader':
        color = AppColors.error;
        icon = Icons.star;
        break;
      case 'subleader':
        color = AppColors.primary;
        icon = Icons.star_border;
        break;
      default:
        color = context.mic.textSecondary;
        icon = Icons.person;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    final addButton = Padding(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      child: widget.isDesktop
          ? Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _showAddMemberDialog,
                icon: Icon(Icons.person_add),
                label: Text(context.tr('Add Member')),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(0, AppDimensions.buttonHeightMD),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: _showAddMemberDialog,
              icon: Icon(Icons.person_add),
              label: Text(context.tr('Add Member')),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(
                  double.infinity,
                  AppDimensions.buttonHeightMD,
                ),
              ),
            ),
    );

    Widget listContent;
    if (_members.isEmpty) {
      listContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: context.mic.textSecondary,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Text(context.tr('No members in this department')),
          ],
        ),
      );
    } else if (widget.isDesktop) {
      listContent = RefreshIndicator(
        onRefresh: _loadMembers,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(context.tr('Member'))),
                    DataColumn(label: Text(context.tr('Email'))),
                    DataColumn(label: Text(context.tr('Role'))),
                    DataColumn(label: Text(context.tr('Actions'))),
                  ],
                  rows: _members.map((dm) {
                    final member = dm['members'] as Map<String, dynamic>?;
                    if (member == null) {
                      return DataRow(
                        cells: [
                          DataCell(Text('—')),
                          DataCell(Text('—')),
                          DataCell(Text('—')),
                          DataCell(SizedBox.shrink()),
                        ],
                      );
                    }
                    final role = dm['role']?.toString() ?? 'member';
                    final memberId = dm['member_id']?.toString() ?? '';
                    final memberName =
                        '${member['first_name']} ${member['last_name']}';
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                child: Text(
                                  member['first_name']?[0]
                                          ?.toString()
                                          .toUpperCase() ??
                                      'M',
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  memberName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              RouteNames.memberDetail.replaceAll(
                                ':id',
                                member['id'].toString(),
                              ),
                            );
                          },
                        ),
                        DataCell(
                          Text(
                            member['email']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(_buildRoleChip(role)),
                        DataCell(
                          PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: Row(
                                  children: [
                                    Icon(Icons.badge, size: 20),
                                    SizedBox(width: 8),
                                    Text(context.tr('Change Role')),
                                  ],
                                ),
                                onTap: () => _changeMemberRole(memberId, role),
                              ),
                              PopupMenuItem(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.remove_circle,
                                      color: AppColors.error,
                                    ),
                                    SizedBox(width: 8),
                                    Text(context.tr('Remove')),
                                  ],
                                ),
                                onTap: () =>
                                    _removeMember(memberId, memberName),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      );
    } else {
      listContent = RefreshIndicator(
        onRefresh: _loadMembers,
        child: ListView.builder(
          itemCount: _members.length,
          itemBuilder: (context, index) {
            final departmentMember = _members[index];
            final member = departmentMember['members'] as Map<String, dynamic>?;
            if (member == null) return SizedBox.shrink();

            final role = departmentMember['role']?.toString() ?? 'member';
            final memberId = departmentMember['member_id']?.toString() ?? '';
            final memberName = '${member['first_name']} ${member['last_name']}';

            return Card(
              margin: EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMD,
                vertical: AppDimensions.spacingXS,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    member['first_name']?[0]?.toString().toUpperCase() ?? 'M',
                  ),
                ),
                title: Text(
                  memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  member['email']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRoleChip(role),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(Icons.badge, size: 20),
                              SizedBox(width: 8),
                              Text(context.tr('Change Role')),
                            ],
                          ),
                          onTap: () => _changeMemberRole(memberId, role),
                        ),
                        PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(Icons.remove_circle, color: AppColors.error),
                              SizedBox(width: 8),
                              Text(context.tr('Remove')),
                            ],
                          ),
                          onTap: () => _removeMember(memberId, memberName),
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    RouteNames.memberDetail.replaceAll(
                      ':id',
                      member['id'].toString(),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    }

    return Column(
      children: [
        addButton,
        Expanded(child: listContent),
      ],
    );
  }
}

/// Tasks tab
class _TasksTab extends StatefulWidget {
  final String departmentId;
  final List<Map<String, dynamic>> tasks;
  final VoidCallback? onTasksUpdated;
  final bool isDesktop;

  _TasksTab({
    required this.departmentId,
    required this.tasks,
    this.onTasksUpdated,
    this.isDesktop = false,
  });

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  Map<String, dynamic>? _completionStats;

  @override
  void initState() {
    super.initState();
    _loadCompletionStats();
  }

  Future<void> _loadCompletionStats() async {
    try {
      final stats = await TaskReportService.getDepartmentTaskCompletion(
        departmentId: widget.departmentId,
      );
      if (!mounted) return;
      setState(() {
        _completionStats = stats;
      });
    } catch (e) {
      debugPrint('Error loading completion stats: $e');
    }
  }

  Future<void> _generateReport() async {
    // Show dialog to select report type and period
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TaskReportOptionsDialog(),
    );

    if (result != null) {
      try {
        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(child: CircularProgressIndicator()),
          );
        }

        final reportType = result['reportType'] as String;
        final year = result['year'] as int;
        final month = result['month'] as int?;

        String? filePath;
        if (reportType == 'monthly' && month != null) {
          filePath = await TaskReportPdfService.generateMonthlyReport(
            departmentId: widget.departmentId,
            year: year,
            month: month,
          );
        } else if (reportType == 'yearly') {
          filePath = await TaskReportPdfService.generateYearlyReport(
            departmentId: widget.departmentId,
            year: year,
          );
        }

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('Report generated successfully: $filePath'),
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error generating report: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openTaskDetail(Map<String, dynamic> task) async {
    final id = task['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null && widget.isDesktop) {
      scope.pushDetail(RouteNames.taskDetail, id);
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.taskDetail.replaceAll(':id', id));
    if (result == true && widget.onTasksUpdated != null) {
      widget.onTasksUpdated!();
    }
  }

  Color _taskStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.error;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  Color _taskPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'low':
        return context.mic.textSecondary;
      case 'medium':
      default:
        return AppColors.primary;
    }
  }

  Widget _taskChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDesktopTaskCard(
    BuildContext context,
    Map<String, dynamic> task,
    double width,
  ) {
    final theme = Theme.of(context);
    final title = task['title']?.toString() ?? 'Task';
    final description = task['description']?.toString().trim() ?? '';
    final status = task['status']?.toString() ?? 'pending';
    final priority = task['priority']?.toString() ?? 'medium';

    return SizedBox(
      width: width,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          onTap: () => _openTaskDetail(task),
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _taskStatusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMD,
                        ),
                      ),
                      child: Icon(
                        Icons.task_alt_outlined,
                        size: 20,
                        color: _taskStatusColor(status),
                      ),
                    ),
                    SizedBox(width: AppDimensions.spacingSM),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.mic.textSecondary),
                  ],
                ),
                SizedBox(height: AppDimensions.spacingSM),
                Text(
                  description.isEmpty
                      ? 'No description provided.'
                      : description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingMD),
                Wrap(
                  spacing: AppDimensions.spacingXS,
                  runSpacing: AppDimensions.spacingXS,
                  children: [
                    _taskChip(status, _taskStatusColor(status)),
                    _taskChip(priority, _taskPriorityColor(priority)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Completion Stats Card
        if (_completionStats != null)
          Container(
            margin: EdgeInsets.all(AppDimensions.paddingMD),
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Task Completion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(_completionStats!['completion_percentage'] as double? ?? 0.0).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            (_completionStats!['completion_percentage']
                                        as double? ??
                                    0.0) >=
                                80
                            ? AppColors.success
                            : (_completionStats!['completion_percentage']
                                          as double? ??
                                      0.0) >=
                                  50
                            ? AppColors.warning
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppDimensions.spacingSM),
                Wrap(
                  spacing: AppDimensions.spacingLG,
                  runSpacing: AppDimensions.spacingSM,
                  children: [
                    _buildStatItem(
                      'Total',
                      '${_completionStats!['total_tasks'] ?? 0}',
                    ),
                    _buildStatItem(
                      'Completed',
                      '${_completionStats!['completed_tasks'] ?? 0}',
                    ),
                    _buildStatItem(
                      'Pending',
                      '${_completionStats!['pending_tasks'] ?? 0}',
                    ),
                    _buildStatItem(
                      'In Progress',
                      '${_completionStats!['in_progress_tasks'] ?? 0}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        // Quick actions: Manage Tasks, Manage Projects, Generate Report
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMD,
            vertical: AppDimensions.paddingSM,
          ),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final useCompact = width < 400;
                      return Wrap(
                        spacing: AppDimensions.spacingSM,
                        runSpacing: AppDimensions.spacingSM,
                        children: [
                          _TaskActionTile(
                            icon: Icons.task_alt_outlined,
                            label: 'Manage Tasks',
                            onTap: () async {
                              final scope = DesktopShellScope.maybeOf(context);
                              if (scope != null) {
                                scope.pushDetail(
                                  RouteNames.tasks,
                                  widget.departmentId,
                                );
                              } else {
                                final result = await Navigator.of(context)
                                    .pushNamed(
                                      RouteNames.tasks,
                                      arguments: widget.departmentId,
                                    );
                                if (result == true &&
                                    widget.onTasksUpdated != null) {
                                  widget.onTasksUpdated!();
                                }
                              }
                            },
                            compact: useCompact,
                          ),
                          _TaskActionTile(
                            icon: Icons.folder_outlined,
                            label: 'Manage Projects',
                            onTap: () async {
                              final scope = DesktopShellScope.maybeOf(context);
                              if (scope != null) {
                                scope.pushDetail(
                                  RouteNames.manageProjects,
                                  widget.departmentId,
                                );
                              } else {
                                final result = await Navigator.of(context)
                                    .pushNamed(
                                      RouteNames.manageProjects,
                                      arguments: widget.departmentId,
                                    );
                                if (result == true &&
                                    widget.onTasksUpdated != null) {
                                  widget.onTasksUpdated!();
                                }
                              }
                            },
                            compact: useCompact,
                          ),
                          _TaskActionTile(
                            icon: Icons.label_outlined,
                            label: 'Manage Tags',
                            onTap: () async {
                              final scope = DesktopShellScope.maybeOf(context);
                              if (scope != null) {
                                scope.pushDetail(
                                  RouteNames.manageTags,
                                  widget.departmentId,
                                );
                              } else {
                                final result = await Navigator.of(context)
                                    .pushNamed(
                                      RouteNames.manageTags,
                                      arguments: widget.departmentId,
                                    );
                                if (result == true &&
                                    widget.onTasksUpdated != null) {
                                  widget.onTasksUpdated!();
                                }
                              }
                            },
                            compact: useCompact,
                          ),
                          _TaskActionTile(
                            icon: Icons.description_outlined,
                            label: 'Generate Report',
                            onTap: _generateReport,
                            compact: useCompact,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        // Tasks list
        Expanded(
          child: widget.tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_outlined,
                        size: 64,
                        color: context.mic.textSecondary,
                      ),
                      SizedBox(height: AppDimensions.spacingMD),
                      Text(context.tr('No tasks in this department')),
                    ],
                  ),
                )
              : widget.isDesktop
              ? SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final cardWidth = availableWidth >= 760
                          ? (availableWidth - AppDimensions.spacingMD) / 2
                          : availableWidth;
                      return Wrap(
                        spacing: AppDimensions.spacingMD,
                        runSpacing: AppDimensions.spacingMD,
                        children: widget.tasks
                            .map(
                              (task) => _buildDesktopTaskCard(
                                context,
                                task,
                                cardWidth,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                )
              : ListView.builder(
                  itemCount: widget.tasks.length,
                  itemBuilder: (context, index) {
                    final task = widget.tasks[index];
                    return Card(
                      margin: EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingMD,
                        vertical: AppDimensions.spacingXS,
                      ),
                      child: ListTile(
                        leading: Icon(Icons.task),
                        title: Text(task['title'] ?? 'Task'),
                        subtitle: Text(task['description'] ?? ''),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () async {
                          final result = await Navigator.of(context).pushNamed(
                            RouteNames.taskDetail.replaceAll(
                              ':id',
                              task['id'].toString(),
                            ),
                          );
                          if (result == true && widget.onTasksUpdated != null) {
                            widget.onTasksUpdated!();
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Reports tab
class _ReportsTab extends StatefulWidget {
  final String departmentId;
  final List<Map<String, dynamic>> reports;
  final VoidCallback onReportsUpdated;
  final bool isDesktop;

  _ReportsTab({
    required this.departmentId,
    required this.reports,
    required this.onReportsUpdated,
    this.isDesktop = false,
  });

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _reports = widget.reports;
  }

  @override
  void didUpdateWidget(_ReportsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reports != widget.reports) {
      _reports = widget.reports;
    }
  }

  Future<void> _loadReports() async {
    try {
      final reports = await DepartmentReportService.getDepartmentReports(
        departmentId: widget.departmentId,
      );
      if (!mounted) return;
      setState(() {
        _reports = reports;
      });
      widget.onReportsUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading reports: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _createReport() async {
    final result = await Navigator.of(context).pushNamed(
      RouteNames.addDepartmentReport.replaceAll(':id', widget.departmentId),
    );
    if (result == true) {
      _loadReports();
    }
  }

  Future<void> _generateSummaryReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Generating summary report...'))),
      );
      await DepartmentReportPdfService.generateSummaryPdf(widget.departmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Summary report generated successfully')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error generating report: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _generateReportPdf(String reportId) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Generating PDF...'))));
      await DepartmentReportPdfService.generateReportPdf(reportId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('PDF generated successfully')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _editReport(String reportId) async {
    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.editDepartmentReport.replaceAll(':id', reportId));
    if (result == true) {
      _loadReports();
    }
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete Report')),
        content: Text('Are you sure you want to delete "${report['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DepartmentReportService.deleteReport(report['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Report deleted successfully')),
              backgroundColor: AppColors.success,
            ),
          );
          _loadReports();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error deleting report: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Create Report button
        Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createReport,
                  icon: Icon(Icons.add),
                  label: Text(context.tr('Create Report')),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(
                      double.infinity,
                      AppDimensions.buttonHeightMD,
                    ),
                  ),
                ),
              ),
              if (_reports.isNotEmpty) ...[
                SizedBox(width: AppDimensions.spacingMD),
                IconButton(
                  icon: Icon(Icons.summarize),
                  onPressed: _generateSummaryReport,
                  tooltip: context.tr('Generate Summary Report'),
                ),
              ],
            ],
          ),
        ),
        // Reports list
        Expanded(
          child: _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: context.mic.textSecondary,
                      ),
                      SizedBox(height: AppDimensions.spacingMD),
                      Text(context.tr('No reports yet')),
                      SizedBox(height: AppDimensions.spacingXS),
                      Text(
                        'Create your first report to get started',
                        style: TextStyle(color: context.mic.textSecondary),
                      ),
                    ],
                  ),
                )
              : widget.isDesktop
              ? RefreshIndicator(
                  onRefresh: _loadReports,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppDimensions.paddingMD),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            columns: [
                              DataColumn(label: Text(context.tr('Report'))),
                              DataColumn(label: Text(context.tr('Created'))),
                              DataColumn(label: Text(context.tr('Actions'))),
                            ],
                            rows: _reports.map((report) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.description,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          report['title'] ?? 'Untitled Report',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _editReport(report['id']),
                                  ),
                                  DataCell(
                                    Text(
                                      DateFormat('MMM d, yyyy').format(
                                        DateTime.parse(report['created_at']),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    PopupMenuButton(
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'pdf',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.picture_as_pdf,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(context.tr('Generate PDF')),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 8),
                                              Text(context.tr('Edit')),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                size: 20,
                                                color: AppColors.error,
                                              ),
                                              SizedBox(width: 8),
                                              Text(context.tr('Delete')),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) async {
                                        if (value == 'pdf') {
                                          await _generateReportPdf(
                                            report['id'],
                                          );
                                        } else if (value == 'edit') {
                                          await _editReport(report['id']);
                                        } else if (value == 'delete') {
                                          _deleteReport(report);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.builder(
                    padding: EdgeInsets.all(AppDimensions.paddingMD),
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return Card(
                        margin: EdgeInsets.only(
                          bottom: AppDimensions.spacingMD,
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.description,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            report['title'] ?? 'Untitled Report',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(
                                'Created: ${DateFormat('MMM d, yyyy').format(DateTime.parse(report['created_at']))}',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'pdf',
                                child: Row(
                                  children: [
                                    Icon(Icons.picture_as_pdf, size: 20),
                                    SizedBox(width: 8),
                                    Text(context.tr('Generate PDF')),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20),
                                    SizedBox(width: 8),
                                    Text(context.tr('Edit')),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: AppColors.error,
                                    ),
                                    SizedBox(width: 8),
                                    Text(context.tr('Delete')),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'pdf') {
                                await _generateReportPdf(report['id']);
                              } else if (value == 'edit') {
                                await _editReport(report['id']);
                              } else if (value == 'delete') {
                                _deleteReport(report);
                              }
                            },
                          ),
                          onTap: () => _editReport(report['id']),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            SizedBox(height: AppDimensions.spacingSM),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Multi-select member dialog with search
class _MultiSelectMemberDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableMembers;

  /// When true (desktop), dialog width is constrained to 480px.
  final bool narrowForDesktop;

  _MultiSelectMemberDialog({
    required this.availableMembers,
    this.narrowForDesktop = false,
  });

  @override
  State<_MultiSelectMemberDialog> createState() =>
      _MultiSelectMemberDialogState();
}

class _MultiSelectMemberDialogState extends State<_MultiSelectMemberDialog> {
  final _searchController = TextEditingController();
  final Set<String> _selectedMemberIds = {};
  String _selectedRole = 'member';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredMembers {
    final query = _searchController.text.toLowerCase();
    List<Map<String, dynamic>> members;
    if (query.isEmpty) {
      members = widget.availableMembers;
    } else {
      members = widget.availableMembers
          .where(
            (member) =>
                (member['first_name']?.toString().toLowerCase().contains(
                      query,
                    ) ??
                    false) ||
                (member['last_name']?.toString().toLowerCase().contains(
                      query,
                    ) ??
                    false) ||
                (member['email']?.toString().toLowerCase().contains(query) ??
                    false),
          )
          .toList();
    }

    // Sort alphabetically by first name, then last name
    members.sort((a, b) {
      final firstNameA = (a['first_name'] ?? '').toString().toLowerCase();
      final lastNameA = (a['last_name'] ?? '').toString().toLowerCase();
      final firstNameB = (b['first_name'] ?? '').toString().toLowerCase();
      final lastNameB = (b['last_name'] ?? '').toString().toLowerCase();

      final firstNameComparison = firstNameA.compareTo(firstNameB);
      if (firstNameComparison != 0) {
        return firstNameComparison;
      }
      return lastNameA.compareTo(lastNameB);
    });

    return members;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: widget.narrowForDesktop ? 480 : double.maxFinite,
        constraints: BoxConstraints(
          maxWidth: widget.narrowForDesktop ? 480 : double.infinity,
          maxHeight: 600,
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                children: [
                  Text(
                    'Add Members',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            // Search bar
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.tr('Search members...'),
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                ),
              ),
            ),
            // Role selection
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMD,
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('Role'),
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'member',
                    child: Text(context.tr('Member')),
                  ),
                  DropdownMenuItem(
                    value: 'subleader',
                    child: Text(context.tr('Subleader')),
                  ),
                  DropdownMenuItem(
                    value: 'leader',
                    child: Text(context.tr('Leader')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value ?? 'member';
                  });
                },
              ),
            ),
            SizedBox(height: AppDimensions.spacingSM),
            Divider(height: 1),
            // Members list
            Expanded(
              child: _filteredMembers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: context.mic.textSecondary,
                          ),
                          SizedBox(height: AppDimensions.spacingSM),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No members available'
                                : 'No members found',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        final memberId = member['id'].toString();
                        final isSelected = _selectedMemberIds.contains(
                          memberId,
                        );
                        final memberName =
                            '${member['first_name']} ${member['last_name']}';
                        final memberEmail = member['email']?.toString() ?? '';

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedMemberIds.add(memberId);
                              } else {
                                _selectedMemberIds.remove(memberId);
                              }
                            });
                          },
                          title: Text(
                            memberName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: memberEmail.isNotEmpty
                              ? Text(
                                  memberEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          secondary: CircleAvatar(
                            child: Text(
                              member['first_name']?[0]
                                      ?.toString()
                                      .toUpperCase() ??
                                  'M',
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Divider(height: 1),
            // Footer with actions
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedMemberIds.length} selected',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.tr('Cancel')),
                      ),
                      SizedBox(width: AppDimensions.spacingSM),
                      ElevatedButton(
                        onPressed: _selectedMemberIds.isEmpty
                            ? null
                            : () {
                                Navigator.pop(context, {
                                  'memberIds': _selectedMemberIds.toList(),
                                  'role': _selectedRole,
                                });
                              },
                        child: Text(context.tr('Add Selected')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskReportOptionsDialog extends StatefulWidget {
  _TaskReportOptionsDialog();

  @override
  State<_TaskReportOptionsDialog> createState() =>
      _TaskReportOptionsDialogState();
}

class _TaskReportOptionsDialogState extends State<_TaskReportOptionsDialog> {
  String _reportType = 'monthly';
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Generate Task Report')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Type
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Report Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            RadioListTile<String>(
              title: Text(context.tr('Monthly Report')),
              value: 'monthly',
              groupValue: _reportType,
              onChanged: (value) {
                setState(() {
                  _reportType = value ?? 'monthly';
                });
              },
            ),
            RadioListTile<String>(
              title: Text(context.tr('Yearly Report')),
              value: 'yearly',
              groupValue: _reportType,
              onChanged: (value) {
                setState(() {
                  _reportType = value ?? 'yearly';
                  if (_reportType == 'yearly') {
                    _selectedMonth = null;
                  } else {
                    _selectedMonth = DateTime.now().month;
                  }
                });
              },
            ),
            Divider(),
            // Year Selection
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text(context.tr('Year')),
              subtitle: Text(_selectedYear.toString()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove),
                    onPressed: () {
                      setState(() {
                        _selectedYear--;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        _selectedYear++;
                      });
                    },
                  ),
                ],
              ),
            ),
            // Month Selection (only for monthly reports)
            if (_reportType == 'monthly')
              ListTile(
                leading: Icon(Icons.calendar_month),
                title: Text(context.tr('Month')),
                subtitle: Text(
                  _selectedMonth != null
                      ? DateFormat(
                          'MMMM',
                        ).format(DateTime(_selectedYear, _selectedMonth!))
                      : 'Select month',
                ),
                trailing: IconButton(
                  icon: Icon(Icons.arrow_forward),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(_selectedYear, _selectedMonth ?? 1),
                      firstDate: DateTime(_selectedYear, 1),
                      lastDate: DateTime(_selectedYear, 12),
                      helpText: 'Select Month',
                      initialDatePickerMode: DatePickerMode.year,
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedMonth = picked.month;
                        _selectedYear = picked.year;
                      });
                    }
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            if (_reportType == 'monthly' && _selectedMonth == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('Please select a month')),
                  backgroundColor: AppColors.warning,
                ),
              );
              return;
            }
            Navigator.of(context).pop({
              'reportType': _reportType,
              'year': _selectedYear,
              'month': _selectedMonth,
            });
          },
          child: Text(context.tr('Generate')),
        ),
      ],
    );
  }
}

/// Compact tile for task-tab quick actions.
class _TaskActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  _TaskActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingSM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
