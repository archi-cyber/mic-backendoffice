import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/leader_access_service.dart';

/// Leader access management page (admin only)
/// Allows admins to define feature access for each leader
class LeaderAccessPage extends StatefulWidget {
  const LeaderAccessPage({super.key});

  @override
  State<LeaderAccessPage> createState() => _LeaderAccessPageState();
}

class _LeaderAccessPageState extends State<LeaderAccessPage> {
  List<Map<String, dynamic>> _leaders = [];
  Map<String, Map<String, dynamic>> _leaderAccessMap = {}; // Original loaded data
  Map<String, Map<String, dynamic>> _pendingChanges = {}; // Local changes not yet saved
  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedLeaderId;
  final List<String> _features = LeaderAccessService.getAvailableFeatures();

  @override
  void initState() {
    super.initState();
    _loadLeaders();
  }

  Future<void> _loadLeaders() async {
    setState(() => _isLoading = true);
    try {
      final leaders = await LeaderAccessService.getLeaders();
      setState(() {
        _leaders = leaders;
        _selectedLeaderId = leaders.isNotEmpty ? leaders.first['id'].toString() : null;
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
            content: Text('Error loading leaders: $e'),
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
            content: Text('Error loading access: $e'),
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
          const SnackBar(
            content: Text('All access permissions saved successfully'),
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
            content: Text('Error saving access: $e'),
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
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingMD),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getFeatureDisplayName(featureName),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('View'),
                    value: canView,
                    onChanged: _isSaving ? null : (value) {
                      _updatePendingChange(featureName, 'can_view', value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Create'),
                    value: canCreate,
                    onChanged: _isSaving ? null : (value) {
                      _updatePendingChange(featureName, 'can_create', value ?? false);
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
                    title: const Text('Edit'),
                    value: canEdit,
                    onChanged: _isSaving ? null : (value) {
                      _updatePendingChange(featureName, 'can_edit', value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Delete'),
                    value: canDelete,
                    onChanged: _isSaving ? null : (value) {
                      _updatePendingChange(featureName, 'can_delete', value ?? false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leader Access Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leaders.isEmpty
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
                        'No leaders found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppDimensions.spacingSM),
                      const Text(
                        'Leaders must have role "leader" in the users table',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Leader selector
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingMD),
                      color: Theme.of(context).cardColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Leader',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingSM),
                          DropdownButtonFormField<String>(
                            value: _selectedLeaderId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            items: _leaders.map((leader) {
                              final id = leader['id'].toString();
                              final displayName = _getLeaderDisplayName(leader);
                              return DropdownMenuItem(
                                value: id,
                                child: Text(
                                  displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              if (value != null) {
                                setState(() => _selectedLeaderId = value);
                                await _loadLeaderAccess(value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    // Access permissions list
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(AppDimensions.paddingMD),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppDimensions.spacingSM,
                                    vertical: AppDimensions.spacingXS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: 14,
                                        color: AppColors.warning,
                                      ),
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
                          const SizedBox(height: AppDimensions.spacingMD),
                          ..._features.map((feature) => _buildFeatureAccessCard(feature)),
                          const SizedBox(height: AppDimensions.spacingXL),
                        ],
                      ),
                    ),
                    // Save button
                    if (_hasUnsavedChanges)
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingMD),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveAllChanges,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(
                                  double.infinity,
                                  AppDimensions.buttonHeightLG,
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Save All Changes'),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
