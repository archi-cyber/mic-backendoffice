import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/chat_service.dart';
import '../../services/department_service.dart';
import 'add_announcement_page.dart';
import 'edit_announcement_page.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/permission_helper.dart';

/// Chat/Announcements page
class ChatPage extends StatefulWidget {
  /// When true (e.g. desktop layout), no app bar is shown.
  final bool hideAppBarAndBottomNav;

  ChatPage({super.key, this.hideAppBarAndBottomNav = false});

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

  /// Détermine si l'utilisateur peut publier une annonce.
  ///
  /// L'implémentation précédente terminait sa condition par `|| true`, ce qui
  /// accordait le droit à tout le monde — le commentaire annonçait d'ailleurs
  /// « restrict in production ». La permission est désormais réellement
  /// vérifiée.
  ///
  /// Ce contrôle ne sert qu'à masquer le bouton : le serveur refuse de toute
  /// façon une publication sans le droit `chat:create`.
  Future<void> _checkPermissions() async {
    try {
      final canCreate = await PermissionHelper.canCreate('chat');

      if (!mounted) return;
      setState(() => _canCreateAnnouncement = canCreate);
    } catch (e) {
      // En cas d'échec, on refuse : masquer un bouton légitime est une gêne,
      // en afficher un qui mènera à une erreur est pire.
      if (mounted) setState(() => _canCreateAnnouncement = false);
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
          SnackBar(
            content: Text(context.tr('Error loading announcements: $e')),
          ),
        );
      }
    }
  }

  Future<void> _deleteAnnouncement(String announcementId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete Announcement')),
        content: Text(
          context.tr('Are you sure you want to delete this announcement?'),
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
        await ChatService.deleteAnnouncement(announcementId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Announcement deleted successfully')),
              backgroundColor: AppColors.success,
            ),
          );
          _loadAnnouncements();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error deleting announcement: $e')),
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
          return context.tr('Just now');
        }
        return context.tr('{count}m ago', {'count': difference.inMinutes});
      }
      return context.tr('{count}h ago', {'count': difference.inHours});
    } else if (difference.inDays == 1) {
      return context.tr('Yesterday');
    } else if (difference.inDays < 7) {
      return context.tr('{count}d ago', {'count': difference.inDays});
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
      margin: EdgeInsets.only(bottom: AppDimensions.spacingMD),
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
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
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(context.tr('Edit')),
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
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppColors.error),
                            SizedBox(width: 8),
                            Text(context.tr('Delete')),
                          ],
                        ),
                        onTap: () =>
                            _deleteAnnouncement(announcement['id'].toString()),
                      ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingXS),
            Wrap(
              spacing: AppDimensions.spacingXS,
              runSpacing: AppDimensions.spacingXS,
              children: [
                if (isGlobal)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingSM,
                      vertical: AppDimensions.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSM,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        Icon(Icons.people, size: 14, color: AppColors.warning),
                        SizedBox(width: AppDimensions.spacingXS),
                        Text(
                          '$targetCount member(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (departmentId != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingSM,
                      vertical: AppDimensions.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: context.mic.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSM,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.group_work,
                          size: 14,
                          color: context.mic.textSecondary,
                        ),
                        SizedBox(width: AppDimensions.spacingXS),
                        Text(
                          _departments
                                  .firstWhere(
                                    (d) => d['id'].toString() == departmentId,
                                    orElse: () => <String, dynamic>{},
                                  )['name']
                                  ?.toString() ??
                              'Department',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mic.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingSM),
            Text(
              announcement['message'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (createdAt != null) ...[
              SizedBox(height: AppDimensions.spacingSM),
              Text(
                _formatDate(createdAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.mic.textSecondary),
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
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(context.tr('Announcements')),
              actions: [
                IconButton(
                  icon: Icon(Icons.filter_list),
                  onPressed: () => _showFilterDialog(),
                  tooltip: context.tr('Filter'),
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _loadAnnouncements,
                  tooltip: context.tr('Refresh'),
                ),
              ],
            ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign,
                    size: 64,
                    color: context.mic.textSecondary,
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  Text(context.tr('No announcements')),
                  if (_canCreateAnnouncement) ...[
                    SizedBox(height: AppDimensions.spacingMD),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddAnnouncementPage(),
                          ),
                        );
                        if (result == true) {
                          _loadAnnouncements();
                        }
                      },
                      icon: Icon(Icons.add),
                      label: Text(context.tr('Create Announcement')),
                    ),
                  ],
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAnnouncements,
              child: ListView.builder(
                padding: EdgeInsets.all(AppDimensions.paddingMD),
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
                  MaterialPageRoute(builder: (_) => AddAnnouncementPage()),
                );
                if (result == true) {
                  _loadAnnouncements();
                }
              },
              icon: Icon(Icons.add),
              label: Text(context.tr('New Announcement')),
            )
          : null,
    );
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Filter Announcements')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(context.tr('Global Only')),
                  subtitle: Text(context.tr('Show only global announcements')),
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
                  SizedBox(height: AppDimensions.spacingSM),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDepartmentFilter,
                    decoration: InputDecoration(
                      labelText: context.tr('Department'),
                      prefixIcon: Icon(Icons.group_work),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(context.tr('All Departments')),
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
              child: Text(context.tr('Reset')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadAnnouncements();
              },
              child: Text(context.tr('Apply')),
            ),
          ],
        ),
      ),
    );
  }
}