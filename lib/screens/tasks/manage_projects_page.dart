import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/project_service.dart';
import 'add_project_page.dart';
import 'edit_project_page.dart';
import '../../core/localization/app_localizations.dart';

/// Manage projects page: list projects, add new, edit existing.
/// When [departmentId] is set (e.g. from department detail), list is filtered and Add project preselects that department.
class ManageProjectsPage extends StatefulWidget {
  /// When set (e.g. from department detail → Manage projects), filter projects and pass to Add project.
  final String? departmentId;

  final void Function(bool? result)? onClose;

  ManageProjectsPage({super.key, this.departmentId, this.onClose});

  @override
  State<ManageProjectsPage> createState() => _ManageProjectsPageState();
}

class _ManageProjectsPageState extends State<ManageProjectsPage> {
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final projects = await ProjectService.getProjects(
        departmentId: widget.departmentId,
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _projects = projects;
        if (_selectedProjectId == null ||
            !projects.any((p) => p['id']?.toString() == _selectedProjectId)) {
          _selectedProjectId = projects.isEmpty
              ? null
              : projects.first['id']?.toString();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Error loading projects: $e'))),
      );
    }
  }

  bool get _isDesktopShell =>
      widget.onClose != null &&
      MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

  Future<void> _openAddProject() async {
    if (_isDesktopShell) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          clipBehavior: Clip.antiAlias,
          insetPadding: EdgeInsets.all(AppDimensions.paddingLG),
          child: SizedBox(
            width: 760,
            height: MediaQuery.sizeOf(dialogContext).height * 0.86,
            child: AddProjectPage(
              departmentId: widget.departmentId,
              onClose: (result) => Navigator.of(dialogContext).pop(result),
            ),
          ),
        ),
      );
      if (result == true && mounted) _loadProjects();
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddProjectPage(departmentId: widget.departmentId),
      ),
    );
    if (result == true && mounted) _loadProjects();
  }

  Future<void> _openEditProject(String projectId) async {
    if (_isDesktopShell) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          clipBehavior: Clip.antiAlias,
          insetPadding: EdgeInsets.all(AppDimensions.paddingLG),
          child: SizedBox(
            width: 760,
            height: MediaQuery.sizeOf(dialogContext).height * 0.86,
            child: EditProjectPage(
              projectId: projectId,
              onClose: (result) => Navigator.of(dialogContext).pop(result),
            ),
          ),
        ),
      );
      if (result == true && mounted) _loadProjects();
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditProjectPage(projectId: projectId)),
    );
    if (result == true && mounted) _loadProjects();
  }

  static const double _kDesktopBreakpoint = 700;
  static const double _kDesktopMaxWidth = 1180;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

    return Scaffold(
      appBar: _isDesktopShell
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () => widget.onClose!(null),
                    )
                  : null,
              title: Text(
                widget.departmentId != null
                    ? 'Manage projects (department)'
                    : 'Manage projects',
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _loadProjects,
                  tooltip: context.tr('Refresh'),
                ),
                if (isDesktop)
                  Padding(
                    padding: EdgeInsets.only(right: AppDimensions.paddingSM),
                    child: FilledButton.icon(
                      onPressed: _openAddProject,
                      icon: Icon(Icons.add, size: 20),
                      label: Text(context.tr('Add project')),
                    ),
                  ),
              ],
            ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildBody(context, isDesktop),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton(
              onPressed: _openAddProject,
              tooltip: context.tr('Add project'),
              child: Icon(Icons.add),
            ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop) {
    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              'No projects yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: AppDimensions.spacingSM),
            FilledButton.icon(
              onPressed: _openAddProject,
              icon: Icon(Icons.add),
              label: Text(context.tr('Add project')),
            ),
          ],
        ),
      );
    }

    if (isDesktop) {
      return _buildDesktopBody(context);
    }

    final listContent = RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView.builder(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final p = _projects[index];
          final title = p['title']?.toString() ?? 'Unnamed';
          final dept = p['departments'] is Map
              ? (p['departments'] as Map)['name']?.toString()
              : null;
          final person = p['members'] is Map
              ? '${(p['members'] as Map)['first_name']} ${(p['members'] as Map)['last_name']}'
              : null;
          final projectId = p['id'].toString();
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(Icons.folder_outlined),
              title: Text(title, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  if (dept != null) dept,
                  if (person != null) person,
                ].join(' · '),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              trailing: IconButton(
                icon: Icon(Icons.edit_outlined),
                onPressed: () => _openEditProject(projectId),
                tooltip: context.tr('Edit project'),
              ),
              onTap: () => _openEditProject(projectId),
            ),
          );
        },
      ),
    );

    return listContent;
  }

  Widget _buildDesktopBody(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _projects.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p?['id']?.toString() == _selectedProjectId,
      orElse: () => _projects.first,
    );

    return Padding(
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _kDesktopMaxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 390,
                child: _ProjectsListPanel(
                  projects: _projects,
                  selectedProjectId: _selectedProjectId,
                  onSelect: (id) => setState(() => _selectedProjectId = id),
                  onAdd: _openAddProject,
                  onRefresh: _loadProjects,
                ),
              ),
              SizedBox(width: AppDimensions.spacingLG),
              Expanded(
                child: selected == null
                    ? Material(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusXL,
                        ),
                        child: Center(
                          child: Text(context.tr('Select a project')),
                        ),
                      )
                    : _ProjectDetailsPanel(
                        project: selected,
                        onEdit: () =>
                            _openEditProject(selected['id'].toString()),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectsListPanel extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  final String? selectedProjectId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  _ProjectsListPanel({
    required this.projects,
    required this.selectedProjectId,
    required this.onSelect,
    required this.onAdd,
    required this.onRefresh,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(AppDimensions.paddingLG),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Projects',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon: Icon(Icons.refresh),
                  tooltip: context.tr('Refresh'),
                ),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: Icon(Icons.add, size: 18),
                  label: Text(context.tr('Add')),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                padding: EdgeInsets.all(AppDimensions.paddingMD),
                itemCount: projects.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: AppDimensions.spacingSM),
                itemBuilder: (context, index) {
                  final project = projects[index];
                  final id = project['id']?.toString() ?? '';
                  final selected = id == selectedProjectId;
                  final title = project['title']?.toString() ?? 'Unnamed';
                  final dept = project['departments'] is Map
                      ? (project['departments'] as Map)['name']?.toString()
                      : null;
                  return Material(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          ),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusLG,
                      ),
                      onTap: () => onSelect(id),
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingMD),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMD,
                                ),
                              ),
                              child: Icon(
                                Icons.folder_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: AppDimensions.spacingSM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (dept != null)
                                    Text(
                                      dept,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: context.mic.textSecondary,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectDetailsPanel extends StatelessWidget {
  final Map<String, dynamic> project;
  final VoidCallback onEdit;

  _ProjectDetailsPanel({required this.project, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = project['title']?.toString() ?? 'Project';
    final description = project['description']?.toString().trim() ?? '';
    final dept = project['departments'] is Map
        ? (project['departments'] as Map)['name']?.toString()
        : '—';
    final person = project['members'] is Map
        ? '${(project['members'] as Map)['first_name']} ${(project['members'] as Map)['last_name']}'
        : '—';
    final priority = project['priority']?.toString() ?? 'medium';
    final endDate = project['end_date']?.toString();

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.folder_special_outlined,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined),
                  label: Text(context.tr('Edit')),
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingLG),
            Wrap(
              spacing: AppDimensions.spacingMD,
              runSpacing: AppDimensions.spacingMD,
              children: [
                _ProjectInfoTile(
                  icon: Icons.business_outlined,
                  label: 'Department',
                  value: dept ?? '—',
                ),
                _ProjectInfoTile(
                  icon: Icons.person_outline,
                  label: 'Person in charge',
                  value: person,
                ),
                _ProjectInfoTile(
                  icon: Icons.flag_outlined,
                  label: 'Priority',
                  value: priority,
                ),
                _ProjectInfoTile(
                  icon: Icons.event_outlined,
                  label: 'End date',
                  value: endDate ?? '—',
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingLG),
            Text(
              'Description',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppDimensions.spacingSM),
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
              child: Text(
                description.isEmpty ? 'No description provided.' : description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  _ProjectInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 210,
      child: Container(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            SizedBox(height: AppDimensions.spacingSM),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.mic.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppDimensions.spacingXS),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
