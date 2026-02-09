import 'package:flutter/material.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/project_service.dart';
import '../desktop/desktop_shell_scope.dart';
import 'add_project_page.dart';
import 'edit_project_page.dart';

/// Manage projects page: list projects, add new, edit existing.
/// When [departmentId] is set (e.g. from department detail), list is filtered and Add project preselects that department.
class ManageProjectsPage extends StatefulWidget {
  /// When set (e.g. from department detail → Manage projects), filter projects and pass to Add project.
  final String? departmentId;

  final void Function(bool? result)? onClose;

  const ManageProjectsPage({super.key, this.departmentId, this.onClose});

  @override
  State<ManageProjectsPage> createState() => _ManageProjectsPageState();
}

class _ManageProjectsPageState extends State<ManageProjectsPage> {
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;

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
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading projects: $e')),
      );
    }
  }

  void _openAddProject() async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(
          RouteNames.addProject, widget.departmentId ?? '');
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddProjectPage(departmentId: widget.departmentId),
        ),
      );
    }
    _loadProjects();
  }

  void _openEditProject(String projectId) async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.editProject.replaceAll(':id', projectId), projectId);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EditProjectPage(projectId: projectId),
        ),
      );
    }
    _loadProjects();
  }

  static const double _kDesktopBreakpoint = 700;
  static const double _kDesktopMaxWidth = 720;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadProjects,
            tooltip: 'Refresh',
          ),
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: AppDimensions.paddingSM),
              child: FilledButton.icon(
                onPressed: _openAddProject,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add project'),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, isDesktop),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton(
              onPressed: _openAddProject,
              tooltip: 'Add project',
              child: const Icon(Icons.add),
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
            const SizedBox(height: AppDimensions.spacingMD),
            Text(
              'No projects yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingSM),
            FilledButton.icon(
              onPressed: _openAddProject,
              icon: const Icon(Icons.add),
              label: const Text('Add project'),
            ),
          ],
        ),
      );
    }

    final listContent = RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
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
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(
                title,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  if (dept != null) dept,
                  if (person != null) person,
                ].join(' · '),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _openEditProject(projectId),
                tooltip: 'Edit project',
              ),
              onTap: () => _openEditProject(projectId),
            ),
          );
        },
      ),
    );

    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kDesktopMaxWidth),
          child: listContent,
        ),
      );
    }
    return listContent;
  }
}
