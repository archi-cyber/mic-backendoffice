import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/leader_access_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Leader access management page (admin only)
/// Allows admins to define feature access for each leader
class LeaderAccessPage extends StatefulWidget {
  /// When provided (e.g. desktop stack), back button calls this instead of Navigator.pop.
  final VoidCallback? onClose;

  LeaderAccessPage({super.key, this.onClose});

  @override
  State<LeaderAccessPage> createState() => _LeaderAccessPageState();
}

class _LeaderAccessPageState extends State<LeaderAccessPage> {
  List<Map<String, dynamic>> _leaders = [];
  Map<String, Map<String, dynamic>> _leaderAccessMap =
      {}; // Original loaded data
  Map<String, Map<String, dynamic>> _pendingChanges =
      {}; // Local changes not yet saved
  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedLeaderId;
  final List<String> _features = LeaderAccessService.getAvailableFeatures();

  @override
  void initState() {
    super.initState();
    _loadLeaders();
  }

  Future<void> _openLeaderPicker() async {
    if (_leaders.isEmpty) return;

    final selectedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            final lower = query.trim().toLowerCase();
            final filtered = lower.isEmpty
                ? _leaders
                : _leaders.where((leader) {
                    final name = _getLeaderDisplayName(leader).toLowerCase();
                    final email = (leader['email']?.toString() ?? '')
                        .toLowerCase();
                    final id = (leader['id']?.toString() ?? '').toLowerCase();
                    return name.contains(lower) ||
                        email.contains(lower) ||
                        id.contains(lower);
                  }).toList();

            return AlertDialog(
              title: Text(context.tr('Select Leader or Member')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: context.tr('Search by name, email, or ID'),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setStateDialog(() => query = value);
                    },
                  ),
                  SizedBox(height: AppDimensions.spacingSM),
                  SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('No matching leaders or members'),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final leader = filtered[index];
                              final id = leader['id'].toString();
                              final displayName = _getLeaderDisplayName(leader);
                              final isSelected = id == _selectedLeaderId;
                              return ListTile(
                                leading: Icon(Icons.person),
                                title: Text(
                                  displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  leader['email']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check,
                                        color: AppColors.primary,
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.of(dialogContext).pop(id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selectedId != null) {
      setState(() => _selectedLeaderId = selectedId);
      await _loadLeaderAccess(selectedId);
    }
  }

  Future<void> _loadLeaders() async {
    setState(() => _isLoading = true);
    try {
      final leaders = await LeaderAccessService.getLeaders();
      setState(() {
        _leaders = leaders;
        _selectedLeaderId = leaders.isNotEmpty
            ? leaders.first['id'].toString()
            : null;
        _isLoading = false;
      });
      if (_selectedLeaderId != null) {
        await _loadLeaderAccess(_selectedLeaderId!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading leaders: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadLeaderAccess(String userId) async {
    try {
      final accessList = await LeaderAccessService.getLeaderAccess(userId);
      final accessMap = <String, Map<String, dynamic>>{};

      for (var access in accessList) {
        accessMap[access['feature_name'] as String] = access;
      }

      setState(() {
        _leaderAccessMap = accessMap;
        _pendingChanges = {}; // Clear pending changes when loading new leader
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading access: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _updatePendingChange(String featureName, String permission, bool value) {
    setState(() {
      if (!_pendingChanges.containsKey(featureName)) {
        // Initialize with current values
        final current = _leaderAccessMap[featureName];
        _pendingChanges[featureName] = {
          'can_view': current?['can_view'] == true,
          'can_create': current?['can_create'] == true,
          'can_edit': current?['can_edit'] == true,
          'can_delete': current?['can_delete'] == true,
        };
      }
      _pendingChanges[featureName]![permission] = value;
    });
  }

  Future<void> _saveAllChanges() async {
    if (_selectedLeaderId == null || _pendingChanges.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save all pending changes
      for (var entry in _pendingChanges.entries) {
        final featureName = entry.key;
        final permissions = entry.value;

        await LeaderAccessService.setLeaderAccess(
          userId: _selectedLeaderId!,
          featureName: featureName,
          canView: permissions['can_view'] == true,
          canCreate: permissions['can_create'] == true,
          canEdit: permissions['can_edit'] == true,
          canDelete: permissions['can_delete'] == true,
        );
      }

      // Update the original map with saved changes
      setState(() {
        for (var entry in _pendingChanges.entries) {
          _leaderAccessMap[entry.key] = {
            'can_view': entry.value['can_view'],
            'can_create': entry.value['can_create'],
            'can_edit': entry.value['can_edit'],
            'can_delete': entry.value['can_delete'],
          };
        }
        _pendingChanges = {}; // Clear pending changes
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('All access permissions saved successfully'),
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error saving access: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  bool get _hasUnsavedChanges => _pendingChanges.isNotEmpty;

  String _getFeatureDisplayName(String featureName) {
    final names = {
      'members': 'Members',
      'departments': 'Departments',
      'trainings': 'Trainings',
      'events': 'Events',
      'tasks': 'Tasks',
      'reports': 'Reports',
      'church_attendance': 'Church Attendance',
      'sunday_school_attendance': 'Sunday School Attendance',
      'visitors': 'Visitors',
      'giving': 'Giving',
      'chat': 'Chat',
      'teachings': 'Teachings',
    };
    return names[featureName] ?? featureName;
  }

  String _getLeaderDisplayName(Map<String, dynamic> leader) {
    final member = leader['members'];
    String? firstName;
    String? lastName;

    if (member != null) {
      if (member is List && member.isNotEmpty) {
        final memberData = member[0];
        firstName = memberData['first_name']?.toString();
        lastName = memberData['last_name']?.toString();
      } else if (member is Map) {
        firstName = member['first_name']?.toString();
        lastName = member['last_name']?.toString();
      }
    }

    if (firstName != null || lastName != null) {
      final name = '$firstName $lastName'.trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    // Fallback to email if name is not available
    return leader['email']?.toString() ?? 'Unknown';
  }

  Widget _buildFeatureAccessCard(String featureName) {
    // Use pending changes if available, otherwise use original data
    final pending = _pendingChanges[featureName];
    final access = pending ?? _leaderAccessMap[featureName];
    final canView = access?['can_view'] == true;
    final canCreate = access?['can_create'] == true;
    final canEdit = access?['can_edit'] == true;
    final canDelete = access?['can_delete'] == true;

    return Card(
      margin: EdgeInsets.only(bottom: AppDimensions.spacingMD),
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getFeatureDisplayName(featureName),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text(context.tr('View')),
                    value: canView,
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            _updatePendingChange(
                              featureName,
                              'can_view',
                              value ?? false,
                            );
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: Text(context.tr('Create')),
                    value: canCreate,
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            _updatePendingChange(
                              featureName,
                              'can_create',
                              value ?? false,
                            );
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text(context.tr('Edit')),
                    value: canEdit,
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            _updatePendingChange(
                              featureName,
                              'can_edit',
                              value ?? false,
                            );
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: Text(context.tr('Delete')),
                    value: canDelete,
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            _updatePendingChange(
                              featureName,
                              'can_delete',
                              value ?? false,
                            );
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopEmbedded(
      context,
      inShell: widget.onClose != null,
    );

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onClose,
                    )
                  : null,
              title: Text(context.tr('Leader Access Management')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadLeaders,
                  tooltip: context.tr('Refresh'),
                ),
              ],
            ),
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(context),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_leaders.isEmpty) {
      return DesktopPageShell(
        banner: DesktopHeroBanner(
          title: context.tr('Leader Access Management'),
          subtitle: context.tr('Define feature access for each leader'),
          icon: Icons.admin_panel_settings_outlined,
        ),
        child: Center(
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
                'No leaders found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: AppDimensions.spacingSM),
              Text(
                'Leaders must have role "leader" in the users table',
                style: TextStyle(color: context.mic.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return DesktopPageShell(
      isLoading: _isSaving,
      maxWidth: kDesktopContentMaxWidth,
      banner: DesktopHeroBanner(
        title: context.tr('Leader Access Management'),
        subtitle: context.tr('Define feature access for each leader'),
        icon: Icons.admin_panel_settings_outlined,
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadLeaders,
          tooltip: context.tr('Refresh'),
        ),
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height - 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopSectionCard(
              title: context.tr('Select Leader or Member'),
              icon: Icons.person_search_outlined,
              children: [
                InkWell(
                  onTap: _openLeaderPicker,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      _selectedLeaderId == null
                          ? 'Tap to select'
                          : _getLeaderDisplayName(
                              _leaders.firstWhere(
                                (l) =>
                                    l['id'].toString() == _selectedLeaderId,
                                orElse: () => const {'email': 'Unknown'},
                              ),
                            ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            if (_hasUnsavedChanges) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingSM,
                  vertical: AppDimensions.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 14, color: AppColors.warning),
                    SizedBox(width: AppDimensions.spacingXS),
                    Text(
                      'Unsaved changes',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppDimensions.spacingSM),
            ],
            Expanded(
              child: DesktopSectionCard(
                title: context.tr('Feature Access Permissions'),
                icon: Icons.security_outlined,
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height - 480,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: DataTable(
                              columns: [
                                DataColumn(label: Text(context.tr('Feature'))),
                                DataColumn(label: Text(context.tr('View'))),
                                DataColumn(label: Text(context.tr('Create'))),
                                DataColumn(label: Text(context.tr('Edit'))),
                                DataColumn(label: Text(context.tr('Delete'))),
                              ],
                              rows: _features.map((featureName) {
                                final pending = _pendingChanges[featureName];
                                final access =
                                    pending ?? _leaderAccessMap[featureName];
                                final canView = access?['can_view'] == true;
                                final canCreate =
                                    access?['can_create'] == true;
                                final canEdit = access?['can_edit'] == true;
                                final canDelete =
                                    access?['can_delete'] == true;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        _getFeatureDisplayName(featureName),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                    DataCell(
                                      Checkbox(
                                        value: canView,
                                        onChanged: _isSaving
                                            ? null
                                            : (value) {
                                                _updatePendingChange(
                                                  featureName,
                                                  'can_view',
                                                  value ?? false,
                                                );
                                              },
                                      ),
                                    ),
                                    DataCell(
                                      Checkbox(
                                        value: canCreate,
                                        onChanged: _isSaving
                                            ? null
                                            : (value) {
                                                _updatePendingChange(
                                                  featureName,
                                                  'can_create',
                                                  value ?? false,
                                                );
                                              },
                                      ),
                                    ),
                                    DataCell(
                                      Checkbox(
                                        value: canEdit,
                                        onChanged: _isSaving
                                            ? null
                                            : (value) {
                                                _updatePendingChange(
                                                  featureName,
                                                  'can_edit',
                                                  value ?? false,
                                                );
                                              },
                                      ),
                                    ),
                                    DataCell(
                                      Checkbox(
                                        value: canDelete,
                                        onChanged: _isSaving
                                            ? null
                                            : (value) {
                                                _updatePendingChange(
                                                  featureName,
                                                  'can_delete',
                                                  value ?? false,
                                                );
                                              },
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_hasUnsavedChanges) ...[
              SizedBox(height: AppDimensions.spacingMD),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveAllChanges,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save All Changes'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_leaders.isEmpty) {
      return Center(
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
              'No leaders found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: AppDimensions.spacingSM),
            Text(
              'Leaders must have role "leader" in the users table',
              style: TextStyle(color: context.mic.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          color: Theme.of(context).cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Leader or Member',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AppDimensions.spacingSM),
              InkWell(
                onTap: _openLeaderPicker,
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    _selectedLeaderId == null
                        ? 'Tap to select'
                        : _getLeaderDisplayName(
                            _leaders.firstWhere(
                              (l) => l['id'].toString() == _selectedLeaderId,
                              orElse: () => const {'email': 'Unknown'},
                            ),
                          ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Feature Access Permissions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_hasUnsavedChanges)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingSM,
                        vertical: AppDimensions.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSM,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 14, color: AppColors.warning),
                          SizedBox(width: AppDimensions.spacingXS),
                          Text(
                            'Unsaved changes',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingMD),
              ..._features.map((feature) => _buildFeatureAccessCard(feature)),
              SizedBox(height: AppDimensions.spacingXL),
            ],
          ),
        ),
        if (_hasUnsavedChanges)
          Container(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAllChanges,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(
                      double.infinity,
                      AppDimensions.buttonHeightLG,
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr('Save All Changes')),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
