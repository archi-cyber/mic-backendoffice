import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/teaching_service.dart';
import '../desktop/desktop_shell_scope.dart';
import 'edit_teaching_page.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Teaching detail page with listeners management
class TeachingDetailPage extends StatefulWidget {
  final String teachingId;

  /// When set (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  const TeachingDetailPage({super.key, required this.teachingId, this.onClose});

  @override
  State<TeachingDetailPage> createState() => _TeachingDetailPageState();
}

class _TeachingDetailPageState extends State<TeachingDetailPage> {
  Map<String, dynamic>? _teaching;
  List<Map<String, dynamic>> _listeners = [];
  List<Map<String, dynamic>> _potentialListeners = [];
  bool _isLoading = true;
  bool _isLoadingListeners = false;
  bool _canEdit = false;
  bool _canDelete = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadTeachingData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final canEdit = await PermissionHelper.canEdit('teachings');
    final canDelete = await PermissionHelper.canDelete('teachings');
    setState(() {
      _canEdit = canEdit;
      _canDelete = canDelete;
    });
  }

  Future<void> _loadTeachingData() async {
    setState(() => _isLoading = true);
    try {
      final teaching = await TeachingService.getTeachingById(widget.teachingId);
      setState(() {
        _teaching = teaching;
        _isLoading = false;
      });
      await _loadListeners();
      await _loadPotentialListeners();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading teaching: {error}', {
              'error': '$e',
            })),
            backgroundColor: AppColors.error,
          ),
        );
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _loadListeners() async {
    setState(() => _isLoadingListeners = true);
    try {
      final listeners = await TeachingService.getTeachingListeners(
        widget.teachingId,
      );
      setState(() {
        _listeners = listeners;
        _isLoadingListeners = false;
      });
    } catch (e) {
      setState(() => _isLoadingListeners = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading listeners: {error}', {
              'error': '$e',
            })),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadPotentialListeners() async {
    try {
      final potential = await TeachingService.getPotentialListeners();
      setState(() {
        _potentialListeners = potential;
      });
    } catch (e) {
      // Silently fail - not critical
    }
  }

  Future<void> _syncFromAttendance() async {
    try {
      final count = await TeachingService.syncListenersFromAttendance(
        widget.teachingId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Synced {count} listener(s) from church attendance', {
                'count': count,
              }),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadListeners();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error syncing: {error}', {'error': '$e'})),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _addListener(String memberId) async {
    try {
      await TeachingService.addListener(
        teachingId: widget.teachingId,
        memberId: memberId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Listener added successfully')),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadListeners();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Error adding listener: {error}', {'error': '$e'}),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeListener(String listenerId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove Listener')),
        content: Text(
          context.tr('Remove "{name}" from listeners?', {'name': memberName}),
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
        await TeachingService.removeListener(listenerId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Listener removed successfully')),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadListeners();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('Error removing listener: {error}', {'error': '$e'}),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteTeaching() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete')),
        content: Text(
          context.tr('Are you sure you want to delete "{title}"?', {
            'title': _teaching!['title'],
          }),
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
        await TeachingService.deleteTeaching(widget.teachingId);
        if (mounted) {
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.of(context).pop(true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('Error deleting teaching: {error}', {'error': '$e'}),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPotentialListeners {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _potentialListeners;
    }
    return _potentialListeners.where((member) {
      final firstName = (member['first_name'] ?? '').toString().toLowerCase();
      final lastName = (member['last_name'] ?? '').toString().toLowerCase();
      final email = (member['email'] ?? '').toString().toLowerCase();
      final fullName = '$firstName $lastName';
      return fullName.contains(query) || email.contains(query);
    }).toList();
  }

  Set<String> get _listenerMemberIds {
    return _listeners
        .map((l) => l['members']?['id']?.toString())
        .whereType<String>()
        .toSet();
  }

  Widget _buildListenerCard(Map<String, dynamic> listener) {
    final member = listener['members'] as Map<String, dynamic>?;
    if (member == null) return SizedBox.shrink();

    final firstName = member['first_name']?.toString() ?? '';
    final lastName = member['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final role = member['role']?.toString() ?? '';
    final listenerId = listener['id'].toString();

    return Card(
      margin: EdgeInsets.only(bottom: AppDimensions.spacingSM),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?'),
        ),
        title: Text(fullName.isEmpty ? context.tr('Unknown') : fullName),
        subtitle: role.isNotEmpty ? Text(role.toUpperCase()) : null,
        trailing: _canEdit
            ? IconButton(
                icon: Icon(Icons.delete, color: AppColors.error),
                onPressed: () => _removeListener(listenerId, fullName),
                tooltip: context.tr('Remove'),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final embedded = isDesktopEmbedded(
      context,
      inShell: widget.onClose != null,
    );

    if (_isLoading || _teaching == null) {
      return Scaffold(
        appBar: embedded
            ? null
            : AppBar(
                leading: widget.onClose != null
                    ? IconButton(
                        icon: Icon(Icons.arrow_back),
                        onPressed: widget.onClose,
                      )
                    : null,
                title: Text(context.tr('Teaching Details')),
              ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final title = _teaching!['title']?.toString() ?? context.tr('Untitled Teaching');
    final teachingDate = _teaching!['teaching_date'] != null
        ? DateTime.parse(_teaching!['teaching_date'])
        : null;
    final speaker = _teaching!['speaker']?.toString() ?? '';
    final description = _teaching!['description']?.toString() ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: embedded ? null : _buildMobileAppBar(localizations, title),
        body: embedded
            ? _buildDesktopBody(
                localizations: localizations,
                title: title,
                teachingDate: teachingDate,
                speaker: speaker,
                description: description,
              )
            : TabBarView(
                children: [
                  _buildOverviewTab(
                    localizations,
                    teachingDate,
                    speaker,
                    description,
                  ),
                  _buildListenersTab(localizations),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(
    AppLocalizations? localizations,
    String title,
  ) {
    return AppBar(
      leading: widget.onClose != null
          ? IconButton(icon: Icon(Icons.arrow_back), onPressed: widget.onClose)
          : null,
      title: Text(title),
      actions: [
        if (_canEdit)
          IconButton(icon: Icon(Icons.edit), onPressed: _openEditTeaching),
        if (_canDelete)
          IconButton(icon: Icon(Icons.delete), onPressed: _deleteTeaching),
      ],
      bottom: TabBar(
        tabs: [
          Tab(text: context.tr('Details')),
          Tab(text: context.tr('Listeners')),
        ],
      ),
    );
  }

  Widget _buildDesktopBody({
    required AppLocalizations? localizations,
    required String title,
    required DateTime? teachingDate,
    required String speaker,
    required String description,
  }) {
    final subtitle = teachingDate != null
        ? DateFormat('MMMM d, yyyy').format(teachingDate)
        : (speaker.isNotEmpty ? speaker : null);

    return DesktopPageShell(
      maxWidth: kDesktopContentMaxWidth,
      isLoading: _isLoading,
      padding: EdgeInsets.zero,
      banner: DesktopHeroBanner(
        title: title,
        subtitle: subtitle,
        icon: Icons.menu_book_outlined,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canEdit)
              IconButton(
                onPressed: _openEditTeaching,
                icon: const Icon(Icons.edit_outlined),
                tooltip: context.tr('Edit'),
              ),
            if (_canDelete)
              IconButton(
                onPressed: _deleteTeaching,
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: context.tr('Delete'),
              ),
            if (widget.onClose != null)
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
                tooltip: context.tr('Close'),
              ),
          ],
        ),
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height - 220,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: DesktopSectionCard(
                  title: context.tr('Overview'),
                  icon: Icons.info_outline,
                  children: [
                    _TeachingBadge(label: context.tr('Teaching')),
                    SizedBox(height: AppDimensions.spacingMD),
                    _TeachingInfoTile(
                      icon: Icons.calendar_today_outlined,
                      label: context.tr('Date'),
                      value: teachingDate == null
                          ? context.tr('Not set')
                          : DateFormat('MMMM d, yyyy').format(teachingDate),
                    ),
                    SizedBox(height: AppDimensions.spacingSM),
                    _TeachingInfoTile(
                      icon: Icons.person_outline,
                      label: context.tr('Speaker'),
                      value: speaker.isEmpty ? context.tr('Not set') : speaker,
                    ),
                    SizedBox(height: AppDimensions.spacingSM),
                    DesktopStatChip(
                      label: context.tr('Listeners'),
                      value: _listeners.length.toString(),
                      icon: Icons.people_outline,
                    ),
                    if (_canEdit) ...[
                      SizedBox(height: AppDimensions.spacingMD),
                      FilledButton.icon(
                        onPressed: _openEditTeaching,
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(context.tr('Edit')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(width: AppDimensions.spacingLG),
            Expanded(
              child: DesktopSectionCard(
                title: context.tr('Teaching Details'),
                icon: Icons.article_outlined,
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height - 320,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: AppColors.primary,
                          unselectedLabelColor: context.mic.textSecondary,
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: [
                            Tab(
                              icon: const Icon(Icons.article_outlined),
                              text: context.tr('Details'),
                            ),
                            Tab(
                              icon: const Icon(Icons.people_outline),
                              text: context.tr('Listeners'),
                            ),
                          ],
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildOverviewTab(
                                localizations,
                                teachingDate,
                                speaker,
                                description,
                              ),
                              _buildListenersTab(localizations),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildOverviewTab(
    AppLocalizations? localizations,
    DateTime? teachingDate,
    String speaker,
    String description,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (teachingDate != null) ...[
            _buildDetailRow(
              icon: Icons.calendar_today,
              label: context.tr('Date'),
              value: DateFormat('MMMM d, yyyy').format(teachingDate),
            ),
            SizedBox(height: AppDimensions.spacingMD),
          ],
          if (speaker.isNotEmpty) ...[
            _buildDetailRow(
              icon: Icons.person,
              label: context.tr('Speaker'),
              value: speaker,
            ),
            SizedBox(height: AppDimensions.spacingMD),
          ],
          if (description.isNotEmpty) ...[
            Text(
              context.tr('Description'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppDimensions.spacingSM),
            Text(description, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }

  Widget _buildListenersTab(AppLocalizations? localizations) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            children: [
              if (_canEdit)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _syncFromAttendance,
                    icon: Icon(Icons.sync),
                    label: Text(
                      context.tr('Sync from Church Attendance'),
                    ),
                  ),
                ),
              if (_canEdit) SizedBox(height: AppDimensions.spacingMD),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.tr('Search potential listeners...'),
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
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingListeners
              ? Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingMD,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${context.tr('Listeners')} (${_listeners.length})',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_canEdit)
                            TextButton.icon(
                              onPressed: () => _showAddListenerDialog(),
                              icon: Icon(Icons.add),
                              label: Text(context.tr('Add')),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _listeners.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: context.mic.textSecondary,
                                  ),
                                  SizedBox(height: AppDimensions.spacingMD),
                                  Text(
                                    context.tr('No listeners yet'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  if (_canEdit) ...[
                                    SizedBox(height: AppDimensions.spacingSM),
                                    Text(
                                      context.tr(
                                        'Use "Sync from Church Attendance" or "Add" to add listeners',
                                      ),
                                      style: TextStyle(
                                        color: context.mic.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(AppDimensions.paddingMD),
                              itemCount: _listeners.length,
                              itemBuilder: (context, index) {
                                return _buildListenerCard(_listeners[index]);
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _openEditTeaching() async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final height = MediaQuery.sizeOf(dialogContext).height;
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingXL,
              vertical: AppDimensions.paddingLG,
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 760,
              height: height * 0.86,
              child: EditTeachingPage(
                teachingId: widget.teachingId,
                onClose: (result) => Navigator.of(dialogContext).pop(result),
              ),
            ),
          );
        },
      );
      if (result == true) _loadTeachingData();
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.editTeaching.replaceAll(':id', widget.teachingId));
    if (result == true) {
      _loadTeachingData();
    }
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.mic.textSecondary),
        SizedBox(width: AppDimensions.spacingSM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.mic.textSecondary),
              ),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAddListenerDialog() async {
    final listenerIds = _listenerMemberIds;
    final availableListeners = _filteredPotentialListeners
        .where((member) => !listenerIds.contains(member['id'].toString()))
        .toList();

    if (availableListeners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('All potential listeners are already added'),
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Add Listener')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableListeners.length,
            itemBuilder: (context, index) {
              final member = availableListeners[index];
              final firstName = member['first_name']?.toString() ?? '';
              final lastName = member['last_name']?.toString() ?? '';
              final fullName = '$firstName $lastName'.trim();
              final role = member['role']?.toString() ?? '';
              final memberId = member['id'].toString();

              return ListTile(
                title: Text(fullName.isEmpty ? context.tr('Unknown') : fullName),
                subtitle: role.isNotEmpty ? Text(role.toUpperCase()) : null,
                onTap: () {
                  Navigator.pop(context);
                  _addListener(memberId);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
        ],
      ),
    );
  }
}

class _TeachingBadge extends StatelessWidget {
  final String label;

  const _TeachingBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TeachingInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TeachingInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
