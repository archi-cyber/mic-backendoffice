import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/teaching_service.dart';

/// Teachings list page
class TeachingsListPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const TeachingsListPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<TeachingsListPage> createState() => _TeachingsListPageState();
}

class _TeachingsListPageState extends State<TeachingsListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _teachings = [];
  bool _isLoading = true;
  bool _canEdit = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadTeachings();
  }

  Future<void> _checkPermissions() async {
    final canEdit = await PermissionHelper.canEdit('teachings');
    final canDelete = await PermissionHelper.canDelete('teachings');
    setState(() {
      _canEdit = canEdit;
      _canDelete = canDelete;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachings() async {
    setState(() => _isLoading = true);
    try {
      final teachings = await TeachingService.getTeachings(limit: 200);
      setState(() {
        _teachings = teachings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.errorLoadingTeaching ??
                  'Error loading teaching: $e',
            ),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTeachings {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _teachings;
    }
    return _teachings.where((teaching) {
      final title = (teaching['title'] ?? '').toString().toLowerCase();
      final description = (teaching['description'] ?? '')
          .toString()
          .toLowerCase();
      final speaker = (teaching['speaker'] ?? '').toString().toLowerCase();
      return title.contains(query) ||
          description.contains(query) ||
          speaker.contains(query);
    }).toList();
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> _deleteTeaching(String teachingId, String teachingTitle) async {
    final localizations = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.delete ?? 'Delete'),
        content: Text(
          localizations?.deleteTeachingConfirmWithTitle(teachingTitle) ??
              'Are you sure you want to delete "$teachingTitle"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(localizations?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await TeachingService.deleteTeaching(teachingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.teachingDeleted ??
                    'Teaching deleted successfully',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          _loadTeachings();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.errorDeletingTeaching ??
                    'Error deleting teaching: $e',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildTeachingCard(Map<String, dynamic> teaching) {
    final title = teaching['title']?.toString() ?? 'Untitled Teaching';
    final teachingDate = teaching['teaching_date'] != null
        ? DateTime.parse(teaching['teaching_date'])
        : null;
    final speaker = teaching['speaker']?.toString() ?? '';
    final description = teaching['description']?.toString() ?? '';
    final teachingId = teaching['id'].toString();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.spacingSM,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(RouteNames.teachingDetail.replaceAll(':id', teachingId));
        },
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_canEdit || _canDelete) ...[
                    if (_canEdit)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: AppColors.primary,
                        onPressed: () async {
                          final result = await Navigator.of(context).pushNamed(
                            RouteNames.editTeaching.replaceAll(
                              ':id',
                              teachingId,
                            ),
                          );
                          if (result == true) {
                            _loadTeachings();
                          }
                        },
                        tooltip: 'Edit Teaching',
                      ),
                    if (_canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        color: AppColors.error,
                        onPressed: () => _deleteTeaching(teachingId, title),
                        tooltip: 'Delete Teaching',
                      ),
                  ],
                ],
              ),
              if (teachingDate != null) ...[
                const SizedBox(height: AppDimensions.spacingXS),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppDimensions.spacingXS),
                    Text(
                      _formatDate(teachingDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (speaker.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingXS),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppDimensions.spacingXS),
                    Expanded(
                      child: Text(
                        speaker,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingXS),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(
                '${localizations?.teachings ?? 'Teachings'} (${_filteredTeachings.length})',
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadTeachings,
                  tooltip: localizations?.refresh ?? 'Refresh',
                ),
              ],
            ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    localizations?.searchTeachings ?? 'Search teachings...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Teachings list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTeachings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppDimensions.spacingMD),
                        Text(
                          _searchController.text.isNotEmpty
                              ? (localizations?.noTeachingsFound ??
                                    'No teachings found matching your search')
                              : (localizations?.noTeachings ??
                                    'No teachings yet'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTeachings,
                    child: ListView.builder(
                      itemCount: _filteredTeachings.length,
                      itemBuilder: (context, index) {
                        return _buildTeachingCard(_filteredTeachings[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: PermissionHelper.canCreate('teachings'),
        builder: (context, snapshot) {
          final canCreate = snapshot.data ?? false;
          if (!canCreate) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.of(
                context,
              ).pushNamed(RouteNames.addTeaching);
              if (result == true) {
                _loadTeachings();
              }
            },
            icon: const Icon(Icons.add),
            label: Text(localizations?.addTeaching ?? 'Add Teaching'),
          );
        },
      ),
    );
  }
}
