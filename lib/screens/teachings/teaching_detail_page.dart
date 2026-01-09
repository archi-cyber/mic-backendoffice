import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/teaching_service.dart';

/// Teaching detail page with listeners management
class TeachingDetailPage extends StatefulWidget {
  final String teachingId;

  const TeachingDetailPage({super.key, required this.teachingId});

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
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.errorLoadingTeaching ?? 'Error loading teaching: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _loadListeners() async {
    setState(() => _isLoadingListeners = true);
    try {
      final listeners = await TeachingService.getTeachingListeners(widget.teachingId);
      setState(() {
        _listeners = listeners;
        _isLoadingListeners = false;
      });
    } catch (e) {
      setState(() => _isLoadingListeners = false);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.errorLoadingTeaching ?? 'Error loading listeners: $e',
            ),
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
      final count = await TeachingService.syncListenersFromAttendance(widget.teachingId);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.listenersSyncedWithCount(count) ??
                  'Synced $count listener(s) from church attendance',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadListeners();
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.errorSyncingListeners ?? 'Error syncing: $e',
            ),
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
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.listenerAdded ?? 'Listener added successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadListeners();
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.errorAddingListener ?? 'Error adding listener: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeListener(String listenerId, String memberName) async {
    final localizations = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.removeListener ?? 'Remove Listener'),
        content: Text(
          localizations?.removeListenerConfirmWithName(memberName) ??
              'Remove "$memberName" from listeners?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(localizations?.remove ?? 'Remove'),
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
              content: Text(
                localizations?.listenerRemoved ?? 'Listener removed successfully',
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
              content: Text(
                localizations?.errorRemovingListener ?? 'Error removing listener: $e',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteTeaching() async {
    final localizations = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.delete ?? 'Delete'),
        content: Text(
          localizations?.deleteTeachingConfirmWithTitle(
                _teaching!['title']?.toString() ?? '',
              ) ??
              'Are you sure you want to delete "${_teaching!['title']}"?',
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
        await TeachingService.deleteTeaching(widget.teachingId);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.errorDeletingTeaching ?? 'Error deleting teaching: $e',
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
    if (member == null) return const SizedBox.shrink();

    final firstName = member['first_name']?.toString() ?? '';
    final lastName = member['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final role = member['role']?.toString() ?? '';
    final listenerId = listener['id'].toString();

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingSM),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?'),
        ),
        title: Text(fullName.isEmpty ? 'Unknown' : fullName),
        subtitle: role.isNotEmpty ? Text(role.toUpperCase()) : null,
        trailing: _canEdit
            ? IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error),
                onPressed: () => _removeListener(listenerId, fullName),
                tooltip: 'Remove',
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (_isLoading || _teaching == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations?.teachingDetails ?? 'Teaching Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final title = _teaching!['title']?.toString() ?? 'Untitled Teaching';
    final teachingDate = _teaching!['teaching_date'] != null
        ? DateTime.parse(_teaching!['teaching_date'])
        : null;
    final speaker = _teaching!['speaker']?.toString() ?? '';
    final description = _teaching!['description']?.toString() ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (_canEdit) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final result = await Navigator.of(context).pushNamed(
                    RouteNames.editTeaching.replaceAll(':id', widget.teachingId),
                  );
                  if (result == true) {
                    _loadTeachingData();
                  }
                },
              ),
            ],
            if (_canDelete) ...[
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteTeaching,
              ),
            ],
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: localizations?.overview ?? 'Details'),
              Tab(text: localizations?.listeners ?? 'Listeners'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Details Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (teachingDate != null) ...[
                    _buildDetailRow(
                      icon: Icons.calendar_today,
                      label: localizations?.date ?? 'Date',
                      value: DateFormat('MMMM d, yyyy').format(teachingDate),
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                  ],
                  if (speaker.isNotEmpty) ...[
                    _buildDetailRow(
                      icon: Icons.person,
                      label: localizations?.speaker ?? 'Speaker',
                      value: speaker,
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                  ],
                  if (description.isNotEmpty) ...[
                    Text(
                      localizations?.description ?? 'Description',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSM),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
            // Listeners Tab
            Column(
              children: [
                // Sync button and search
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMD),
                  child: Column(
                    children: [
                      if (_canEdit)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _syncFromAttendance,
                            icon: const Icon(Icons.sync),
                            label: Text(
                              localizations?.syncFromAttendance ??
                                  'Sync from Church Attendance',
                            ),
                          ),
                        ),
                      if (_canEdit) const SizedBox(height: AppDimensions.spacingMD),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: localizations?.searchPotentialListeners ??
                              'Search potential listeners...',
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
                    ],
                  ),
                ),
                // Listeners list
                Expanded(
                  child: _isLoadingListeners
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.paddingMD,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${localizations?.listeners ?? 'Listeners'} (${_listeners.length})',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_canEdit)
                                    TextButton.icon(
                                      onPressed: () => _showAddListenerDialog(),
                                      icon: const Icon(Icons.add),
                                      label: Text(localizations?.addListener ?? 'Add'),
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
                                          const Icon(
                                            Icons.people_outline,
                                            size: 64,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(height: AppDimensions.spacingMD),
                                          Text(
                                            localizations?.noListeners ?? 'No listeners yet',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          if (_canEdit) ...[
                                            const SizedBox(height: AppDimensions.spacingSM),
                                            Text(
                                              localizations?.useSyncOrAdd ??
                                                  'Use "Sync from Church Attendance" or "Add" to add listeners',
                                              style: const TextStyle(color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(AppDimensions.paddingMD),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: AppDimensions.spacingSM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
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

    final localizations = AppLocalizations.of(context);
    if (availableListeners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.allListenersAdded ??
                'All potential listeners are already added',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.addListenerTitle ?? 'Add Listener'),
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
                title: Text(fullName.isEmpty ? 'Unknown' : fullName),
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
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
        ],
      ),
    );
  }
}
