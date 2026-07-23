import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/tag_colors.dart';
import '../../services/tag_service.dart';
import '../../services/department_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/tag_color_picker.dart';

/// Manage tags page (tags are per department). Pass [departmentId] or select one.
class ManageTagsPage extends StatefulWidget {
  /// When set (e.g. from department context), tags are scoped to this department.
  final String? departmentId;

  final void Function(bool? result)? onClose;

  ManageTagsPage({super.key, this.departmentId, this.onClose});

  @override
  State<ManageTagsPage> createState() => _ManageTagsPageState();
}

class _ManageTagsPageState extends State<ManageTagsPage> {
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _departments = [];
  String? _selectedDepartmentId;
  String? _selectedTagId;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingDepts = true;

  @override
  void initState() {
    super.initState();
    _selectedDepartmentId = widget.departmentId;
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDepts = true);
    try {
      final depts = await DepartmentService.getDepartments(limit: 200);
      if (!mounted) return;
      setState(() {
        _departments = depts;
        _isLoadingDepts = false;
        if (_selectedDepartmentId == null && depts.isNotEmpty) {
          _selectedDepartmentId = depts.first['id'].toString();
        }
      });
      if (_selectedDepartmentId != null) _loadTags();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingDepts = false);
    }
  }

  Future<void> _loadTags() async {
    if (_selectedDepartmentId == null) return;
    setState(() => _isLoading = true);
    try {
      final tags = await TagService.getTags(
        departmentId: _selectedDepartmentId!,
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _tags = tags;
        if (_selectedTagId == null ||
            !tags.any((tag) => tag['id']?.toString() == _selectedTagId)) {
          _selectedTagId = tags.isEmpty ? null : tags.first['id']?.toString();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Error loading tags: $e'))),
      );
    }
  }

  Future<Map<String, String>?> _showTagEditorDialog({
    Map<String, dynamic>? tag,
  }) async {
    final nameController = TextEditingController();
    nameController.text = tag?['name']?.toString() ?? '';
    String selectedColor =
        tag?['color']?.toString() ?? TagColors.presetHex.first;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(tag == null ? context.tr('Create tag') : context.tr('Edit tag')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: context.tr('Tag name'),
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    textCapitalization: TextCapitalization.none,
                  ),
                  SizedBox(height: 16),
                  Text(
                    context.tr('Color'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  SizedBox(height: 8),
                  TagColorPicker(
                    selectedHex: selectedColor,
                    onChanged: (hex) =>
                        setDialogState(() => selectedColor = hex),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) return;
                  Navigator.pop(context, {
                    'name': nameController.text.trim(),
                    'color': selectedColor,
                  });
                },
                child: Text(tag == null ? context.tr('Create') : context.tr('Update')),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();
    return result;
  }

  Future<void> _addTag() async {
    if (_selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Select a department first'))),
      );
      return;
    }
    final result = await _showTagEditorDialog();
    if (result == null || !mounted) return;
    final name = result['name']!;
    final color = result['color'];
    setState(() => _isSaving = true);
    try {
      await TagService.createTag(
        name: name,
        departmentId: _selectedDepartmentId!,
        color: color,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Tag added')),
          backgroundColor: AppColors.success,
        ),
      );
      _loadTags();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editTag(Map<String, dynamic> tag) async {
    final result = await _showTagEditorDialog(tag: tag);
    if (result == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await TagService.updateTag(
        tagId: tag['id'].toString(),
        name: result['name'],
        color: result['color'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Tag updated')),
          backgroundColor: AppColors.success,
        ),
      );
      _loadTags();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTag(Map<String, dynamic> tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete tag?')),
        content: Text(
          context.tr(
            'Remove tag "{name}"? Tasks will no longer have this tag.',
            {'name': tag['name']?.toString() ?? ''},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await TagService.deleteTag(tag['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Tag removed')),
          backgroundColor: AppColors.success,
        ),
      );
      _loadTags();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static const double _kDesktopBreakpoint = 700;
  static const double _kDesktopMaxWidth = 1180;

  bool get _isDesktopShell =>
      widget.onClose != null &&
      MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

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
              title: Text(context.tr('Manage tags')),
              actions: [
                if (isDesktop)
                  Padding(
                    padding: EdgeInsets.only(right: AppDimensions.paddingSM),
                    child: FilledButton.icon(
                      onPressed: _selectedDepartmentId == null || _isSaving
                          ? null
                          : _addTag,
                      icon: Icon(Icons.add, size: 20),
                      label: Text(context.tr('Add tag')),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: _selectedDepartmentId == null || _isSaving
                        ? null
                        : _addTag,
                    tooltip: context.tr('Add tag'),
                  ),
              ],
            ),
      body: _isLoadingDepts
          ? Center(child: CircularProgressIndicator())
          : _buildBody(context, isDesktop),
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop) {
    if (isDesktop) {
      return _buildDesktopBody(context);
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedDepartmentId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Department'),
              border: OutlineInputBorder(),
            ),
            items: _departments
                .map(
                  (d) => DropdownMenuItem<String>(
                    value: d['id'].toString(),
                    child: Text(d['name']?.toString() ?? ''),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => _selectedDepartmentId = v);
              _loadTags();
            },
          ),
        ),
        Expanded(
          child: _selectedDepartmentId == null
              ? Center(child: Text(context.tr('Select a department')))
              : _isLoading
              ? Center(child: CircularProgressIndicator())
              : _tags.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.label_off_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      SizedBox(height: AppDimensions.spacingMD),
                      Text(
                        context.tr('No tags in this department'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: AppDimensions.spacingSM),
                      FilledButton.icon(
                        onPressed: _addTag,
                        icon: Icon(Icons.add),
                        label: Text(context.tr('Add tag')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTags,
                  child: ListView.builder(
                    padding: EdgeInsets.all(AppDimensions.paddingMD),
                    itemCount: _tags.length,
                    itemBuilder: (context, index) {
                      final tag = _tags[index];
                      final color = TagColors.colorFromHex(
                        tag['color']?.toString(),
                      );
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color.computeLuminance() > 0.5
                                    ? Colors.black26
                                    : Colors.white24,
                                width: 1,
                              ),
                            ),
                          ),
                          title: Text(tag['name']?.toString() ?? ''),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline),
                            onPressed: () => _deleteTag(tag),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );

    return column;
  }

  Widget _buildDesktopBody(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTag = _tags.cast<Map<String, dynamic>?>().firstWhere(
      (tag) => tag?['id']?.toString() == _selectedTagId,
      orElse: () => _tags.isEmpty ? null : _tags.first,
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
                child: _TagsListPanel(
                  departments: _departments,
                  tags: _tags,
                  selectedDepartmentId: _selectedDepartmentId,
                  selectedTagId: _selectedTagId,
                  isLoading: _isLoading,
                  isSaving: _isSaving,
                  onDepartmentChanged: (value) {
                    setState(() {
                      _selectedDepartmentId = value;
                      _selectedTagId = null;
                    });
                    _loadTags();
                  },
                  onSelectTag: (id) => setState(() => _selectedTagId = id),
                  onAddTag: _selectedDepartmentId == null || _isSaving
                      ? null
                      : _addTag,
                  onRefresh: _selectedDepartmentId == null ? null : _loadTags,
                ),
              ),
              SizedBox(width: AppDimensions.spacingLG),
              Expanded(
                child: selectedTag == null
                    ? Material(
                        color: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusXL,
                          ),
                          side: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _selectedDepartmentId == null
                                ? context.tr('Select a department')
                                : context.tr('Select a tag'),
                          ),
                        ),
                      )
                    : _TagDetailsPanel(
                        tag: selectedTag,
                        onEdit: () => _editTag(selectedTag),
                        onDelete: () => _deleteTag(selectedTag),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagsListPanel extends StatelessWidget {
  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> tags;
  final String? selectedDepartmentId;
  final String? selectedTagId;
  final bool isLoading;
  final bool isSaving;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<String> onSelectTag;
  final VoidCallback? onAddTag;
  final Future<void> Function()? onRefresh;

  _TagsListPanel({
    required this.departments,
    required this.tags,
    required this.selectedDepartmentId,
    required this.selectedTagId,
    required this.isLoading,
    required this.isSaving,
    required this.onDepartmentChanged,
    required this.onSelectTag,
    required this.onAddTag,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('Tags'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onRefresh == null ? null : () => onRefresh!(),
                      icon: Icon(Icons.refresh),
                      tooltip: context.tr('Refresh'),
                    ),
                    FilledButton.icon(
                      onPressed: onAddTag,
                      icon: Icon(Icons.add, size: 18),
                      label: Text(context.tr('Add')),
                    ),
                  ],
                ),
                SizedBox(height: AppDimensions.spacingMD),
                DropdownButtonFormField<String>(
                  initialValue: selectedDepartmentId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('Department'),
                    border: OutlineInputBorder(),
                  ),
                  items: departments
                      .map(
                        (department) => DropdownMenuItem<String>(
                          value: department['id'].toString(),
                          child: Text(
                            department['name']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isSaving ? null : onDepartmentChanged,
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: selectedDepartmentId == null
                ? Center(child: Text(context.tr('Select a department')))
                : isLoading
                ? Center(child: CircularProgressIndicator())
                : tags.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppDimensions.paddingLG),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.label_off_outlined,
                            size: 48,
                            color: theme.colorScheme.outline,
                          ),
                          SizedBox(height: AppDimensions.spacingMD),
                          Text(
                            context.tr('No tags yet'),
                            style: theme.textTheme.titleMedium,
                          ),
                          SizedBox(height: AppDimensions.spacingSM),
                          FilledButton.icon(
                            onPressed: onAddTag,
                            icon: Icon(Icons.add),
                            label: Text(context.tr('Create tag')),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: onRefresh ?? () async {},
                    child: ListView.separated(
                      padding: EdgeInsets.all(AppDimensions.paddingMD),
                      itemCount: tags.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: AppDimensions.spacingSM),
                      itemBuilder: (context, index) {
                        final tag = tags[index];
                        final id = tag['id']?.toString() ?? '';
                        final color = TagColors.colorFromHex(
                          tag['color']?.toString(),
                        );
                        final selected = id == selectedTagId;
                        return Material(
                          color: selected
                              ? color.withValues(alpha: 0.14)
                              : theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusLG,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusLG,
                            ),
                            onTap: () => onSelectTag(id),
                            child: Padding(
                              padding: EdgeInsets.all(AppDimensions.paddingMD),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: color.computeLuminance() > 0.5
                                            ? Colors.black26
                                            : Colors.white24,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: AppDimensions.spacingSM),
                                  Expanded(
                                    child: Text(
                                      tag['name']?.toString() ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
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

class _TagDetailsPanel extends StatelessWidget {
  final Map<String, dynamic> tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  _TagDetailsPanel({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = TagColors.colorFromHex(tag['color']?.toString());
    final name = tag['name']?.toString() ?? context.tr('Tag');

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
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.computeLuminance() > 0.5
                          ? Colors.black26
                          : Colors.white24,
                      width: 2,
                    ),
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: AppDimensions.spacingXS),
                      Text(
                        tag['color']?.toString() ?? context.tr('Default color'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.mic.textSecondary,
                        ),
                      ),
                    ],
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
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppDimensions.paddingLG),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Text(
                context.tr(
                  'Use this tag to classify tasks inside the selected department.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
            SizedBox(height: AppDimensions.spacingLG),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline),
              label: Text(context.tr('Delete tag')),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}
