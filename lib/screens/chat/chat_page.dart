import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_service.dart';
import '../../services/department_service.dart';
import 'add_announcement_page.dart';
import 'edit_announcement_page.dart';

/// Chat/Announcements page
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;
  bool _canCreateAnnouncement = false;
  String? _selectedDepartmentFilter;
  bool _showGlobalOnly = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadDepartments();
    _loadAnnouncements();
  }

  Future<void> _loadDepartments() async {
    try {
      final departments = await DepartmentService.getDepartments(limit: 100);
      setState(() {
        _departments = departments;
      });
    } catch (e) {
      // Ignore error, departments filter is optional
    }
  }

  Future<void> _checkPermissions() async {
    // Check if user is admin, pastor, or leader
    // For now, we'll allow all authenticated users to create announcements
    // In production, this should check user role from database
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser != null) {
        // Check user role from metadata or database
        final role = currentUser.userMetadata?['role']?.toString();
        setState(() {
          _canCreateAnnouncement =
              role == 'admin' ||
              role == 'pastor' ||
              role == 'leader' ||
              true; // Allow for now, restrict in production
        });
      }
    } catch (e) {
      // If error, default to false
      setState(() => _canCreateAnnouncement = false);
    }
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final announcements = await ChatService.getAnnouncements(
        isGlobal: _showGlobalOnly ? true : null,
        departmentId: _selectedDepartmentFilter,
        limit: 100,
      );
      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading announcements: $e')),
        );
      }
    }
  }

  Future<void> _deleteAnnouncement(String announcementId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: const Text(
          'Are you sure you want to delete this announcement?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChatService.deleteAnnouncement(announcementId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Announcement deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadAnnouncements();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting announcement: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final createdAt = announcement['created_at'] != null
        ? DateTime.parse(announcement['created_at'])
        : null;
    final isGlobal = announcement['is_global'] == true;
    final departmentId = announcement['department_id']?.toString();
    final targetMemberIds = announcement['target_member_ids'];
    final targetCount = targetMemberIds is List ? targetMemberIds.length : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingMD),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    announcement['title'] ?? 'Announcement',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_canCreateAnnouncement)
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.edit, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                        onTap: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditAnnouncementPage(
                                announcementId: announcement['id'].toString(),
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadAnnouncements();
                          }
                        },
                      ),
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.delete, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                        onTap: () =>
                            _deleteAnnouncement(announcement['id'].toString()),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXS),
            Wrap(
              spacing: AppDimensions.spacingXS,
              runSpacing: AppDimensions.spacingXS,
              children: [
                if (isGlobal)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingSM,
                      vertical: AppDimensions.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSM,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.public, size: 14, color: AppColors.primary),
                        SizedBox(width: AppDimensions.spacingXS),
                        Text(
                          'Global',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!isGlobal && targetCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingSM,
                      vertical: AppDimensions.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSM,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppDimensions.spacingXS),
                        Text(
                          '$targetCount member(s)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (departmentId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingSM,
                      vertical: AppDimensions.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSM,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.group_work,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppDimensions.spacingXS),
                        Text(
                          _departments
                                  .firstWhere(
                                    (d) => d['id'].toString() == departmentId,
                                    orElse: () => <String, dynamic>{},
                                  )['name']
                                  ?.toString() ??
                              'Department',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSM),
            Text(
              announcement['message'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (createdAt != null) ...[
              const SizedBox(height: AppDimensions.spacingSM),
              Text(
                _formatDate(createdAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnnouncements,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.campaign,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  const Text('No announcements'),
                  if (_canCreateAnnouncement) ...[
                    const SizedBox(height: AppDimensions.spacingMD),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddAnnouncementPage(),
                          ),
                        );
                        if (result == true) {
                          _loadAnnouncements();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Announcement'),
                    ),
                  ],
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAnnouncements,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppDimensions.paddingMD),
                itemCount: _announcements.length,
                itemBuilder: (context, index) {
                  return _buildAnnouncementCard(_announcements[index]);
                },
              ),
            ),
      floatingActionButton: _canCreateAnnouncement
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddAnnouncementPage(),
                  ),
                );
                if (result == true) {
                  _loadAnnouncements();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('New Announcement'),
            )
          : null,
    );
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Announcements'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Global Only'),
                  subtitle: const Text('Show only global announcements'),
                  value: _showGlobalOnly,
                  onChanged: (value) {
                    setDialogState(() {
                      _showGlobalOnly = value;
                      if (value) {
                        _selectedDepartmentFilter = null;
                      }
                    });
                  },
                ),
                if (!_showGlobalOnly) ...[
                  const SizedBox(height: AppDimensions.spacingSM),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDepartmentFilter,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      prefixIcon: Icon(Icons.group_work),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Departments'),
                      ),
                      ..._departments.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept['id'].toString(),
                          child: Text(dept['name']?.toString() ?? 'Unnamed'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedDepartmentFilter = value;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _showGlobalOnly = true;
                  _selectedDepartmentFilter = null;
                });
                Navigator.pop(context);
                _loadAnnouncements();
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadAnnouncements();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
