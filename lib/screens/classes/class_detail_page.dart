import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/class_service.dart';
import '../../services/member_service.dart';
import '../desktop/desktop_shell_scope.dart';
import 'attendance_page.dart';
import 'edit_class_page.dart';
import '../../core/localization/app_localizations.dart';

/// Training detail page with sessions and attendance
class ClassDetailPage extends StatefulWidget {
  final String classId;

  /// When set (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  const ClassDetailPage({super.key, required this.classId, this.onClose});

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

const double _kClassDetailDesktopBreakpoint = 700;
const double _kClassDetailDesktopMaxWidth = 1180;

class _ClassDetailPageState extends State<ClassDetailPage> {
  Map<String, dynamic>? _classData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClassData();
  }

  Future<void> _loadClassData() async {
    setState(() => _isLoading = true);
    try {
      final classData = await ClassService.getClassById(widget.classId);
      if (!mounted) return;
      setState(() {
        _classData = classData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading training: $e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        widget.onClose != null &&
        MediaQuery.sizeOf(context).width >= _kClassDetailDesktopBreakpoint;

    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_classData == null) {
      return Scaffold(
        appBar: isDesktop
            ? null
            : AppBar(
                title: Text(context.tr('Training')),
                leading: widget.onClose != null
                    ? IconButton(
                        icon: Icon(Icons.arrow_back),
                        onPressed: widget.onClose,
                      )
                    : null,
              ),
        body: Center(child: Text(context.tr('Training not found'))),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: isDesktop ? null : _buildMobileAppBar(),
        body: isDesktop
            ? _buildDesktopBody(context)
            : TabBarView(
                children: [
                  _SessionsTab(
                    classId: widget.classId,
                    onSessionsUpdated: _loadClassData,
                  ),
                  _MembersTab(classId: widget.classId),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      leading: widget.onClose != null
          ? IconButton(icon: Icon(Icons.arrow_back), onPressed: widget.onClose)
          : null,
      title: Text(_classData!['name'] ?? context.tr('Training')),
      actions: [
        IconButton(
          icon: Icon(Icons.edit),
          onPressed: _openEditClass,
          tooltip: context.tr('Edit Training'),
        ),
        PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Row(
                children: [
                  Icon(Icons.delete, color: AppColors.error),
                  SizedBox(width: 8),
                  Text(context.tr('Delete Class')),
                ],
              ),
              onTap: () => _deleteClass(),
            ),
          ],
        ),
      ],
      bottom: TabBar(
        tabs: [
          Tab(text: context.tr('Sessions')),
          Tab(text: context.tr('Members')),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final theme = Theme.of(context);
    final className = _classData!['name']?.toString() ?? context.tr('Training');
    final description = _classData!['description']?.toString();
    final isActive = _classData!['is_active'] == true;
    final startDate = _classData!['start_date']?.toString();
    final endDate = _classData!['end_date']?.toString();

    return Padding(
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _kClassDetailDesktopMaxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  child: _TrainingSummaryPanel(
                    className: className,
                    description: description,
                    isActive: isActive,
                    startDate: startDate,
                    endDate: endDate,
                    onEdit: _openEditClass,
                    onDelete: _deleteClass,
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.spacingLG),
              Expanded(
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusXL,
                      ),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppDimensions.paddingLG,
                            AppDimensions.paddingMD,
                            AppDimensions.paddingLG,
                            0,
                          ),
                          child: TabBar(
                            labelColor: AppColors.primary,
                            unselectedLabelColor: context.mic.textSecondary,
                            indicatorSize: TabBarIndicatorSize.tab,
                            tabs: [
                              Tab(
                                icon: Icon(Icons.event_note_outlined),
                                text: context.tr('Sessions'),
                              ),
                              Tab(
                                icon: Icon(Icons.people_outline),
                                text: context.tr('Members'),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _SessionsTab(
                                classId: widget.classId,
                                onSessionsUpdated: _loadClassData,
                              ),
                              _MembersTab(classId: widget.classId),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditClass() {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      showDialog<bool>(
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
              child: EditClassPage(
                classId: widget.classId,
                onClose: (result) => Navigator.of(dialogContext).pop(result),
              ),
            ),
          );
        },
      ).then((result) {
        if (result == true) _loadClassData();
      });
      return;
    }

    Navigator.of(context)
        .pushNamed(RouteNames.editClass.replaceAll(':id', widget.classId))
        .then((result) {
          if (result == true) _loadClassData();
        });
  }

  Future<void> _deleteClass() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete Class')),
        content: Text(
          'Are you sure you want to delete this class? This will deactivate it.',
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
        await ClassService.deleteClass(widget.classId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Training deleted successfully')),
              backgroundColor: AppColors.success,
            ),
          );
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
              content: Text(context.tr('Error deleting class: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

class _TrainingSummaryPanel extends StatelessWidget {
  final String className;
  final String? description;
  final bool isActive;
  final String? startDate;
  final String? endDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TrainingSummaryPanel({
    required this.className,
    required this.description,
    required this.isActive,
    required this.startDate,
    required this.endDate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
      child: Container(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
              ),
              child: Icon(Icons.school_outlined, color: AppColors.primary),
            ),
            SizedBox(height: AppDimensions.spacingLG),
            Text(
              className,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppDimensions.spacingSM),
            _TrainingStatusPill(isActive: isActive),
            if (description != null && description!.trim().isNotEmpty) ...[
              SizedBox(height: AppDimensions.spacingLG),
              Text(
                description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.mic.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            SizedBox(height: AppDimensions.spacingLG),
            _TrainingInfoTile(
              icon: Icons.play_circle_outline,
              label: context.tr('Start Date'),
              value: startDate == null || startDate!.isEmpty
                  ? context.tr('Not set')
                  : startDate!,
            ),
            SizedBox(height: AppDimensions.spacingSM),
            _TrainingInfoTile(
              icon: Icons.flag_outlined,
              label: context.tr('End Date'),
              value: endDate == null || endDate!.isEmpty
                  ? context.tr('Not set')
                  : endDate!,
            ),
            SizedBox(height: AppDimensions.spacingXL),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined),
                    label: Text(context.tr('Edit')),
                  ),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                IconButton.outlined(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline),
                  color: AppColors.error,
                  tooltip: context.tr('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingStatusPill extends StatelessWidget {
  final bool isActive;

  const _TrainingStatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : context.mic.textSecondary;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          SizedBox(width: 6),
          Text(
            isActive ? context.tr('Active') : context.tr('Inactive'),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TrainingInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TrainingInfoTile({
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

/// Sessions tab with on-demand generation
class _SessionsTab extends StatefulWidget {
  final String classId;
  final VoidCallback onSessionsUpdated;

  const _SessionsTab({required this.classId, required this.onSessionsUpdated});

  @override
  State<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<_SessionsTab> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isGenerating = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await ClassService.getClassSessions(widget.classId);
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(_SessionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _loadSessions();
    }
  }

  Future<void> _generateSessions() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _GenerateSessionsDialog(),
    );

    if (result == null) return;

    final numberOfSessions = result['sessions'] as int;
    final weeksBetween = result['weeksBetween'] as int?;

    setState(() => _isGenerating = true);

    try {
      await ClassService.generateSessions(
        classId: widget.classId,
        numberOfSessions: numberOfSessions,
        weeksBetweenSessions: weeksBetween,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Generated $numberOfSessions sessions')),
            backgroundColor: AppColors.success,
          ),
        );
        _loadSessions();
        widget.onSessionsUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error generating sessions: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Generate sessions button
        Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateSessions,
            icon: _isGenerating
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.add),
            label: Text(context.tr('Generate Next Sessions')),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, AppDimensions.buttonHeightMD),
            ),
          ),
        ),
        // Sessions list
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: context.mic.textSecondary,
                      ),
                      SizedBox(height: AppDimensions.spacingMD),
                      Text(context.tr('No sessions yet')),
                      SizedBox(height: AppDimensions.spacingSM),
                      TextButton(
                        onPressed: _generateSessions,
                        child: Text(context.tr('Generate Sessions')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final sessionDate = session['session_date'] != null
                          ? DateTime.parse(session['session_date'])
                          : null;
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingMD,
                          vertical: AppDimensions.spacingXS,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.1,
                            ),
                            child: Icon(Icons.event, color: AppColors.primary),
                          ),
                          title: Text(
                            sessionDate != null
                                ? _formatDate(sessionDate)
                                : 'Session ${index + 1}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: sessionDate != null
                              ? Text(
                                  _formatDateLong(sessionDate),
                                  style: Theme.of(context).textTheme.bodySmall,
                                )
                              : Text(context.tr('Date TBD')),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () => _navigateToAttendance(
                            context,
                            session['id'].toString(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _navigateToAttendance(
    BuildContext context,
    String sessionId,
  ) async {
    try {
      // Get training members for attendance
      final members = await ClassService.getClassMembers(widget.classId);
      final memberList = members
          .map((enrollment) => enrollment['members'] as Map<String, dynamic>?)
          .where((member) => member != null)
          .cast<Map<String, dynamic>>()
          .toList();

      if (!mounted) return;

      final scope = DesktopShellScope.maybeOf(context);
      if (scope != null) {
        scope.pushDetail(RouteNames.takeAttendance, sessionId);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              AttendancePage(sessionId: sessionId, members: memberList),
        ),
      );

      // Reload sessions after returning from attendance
      _loadSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading members: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateLong(DateTime date) {
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

/// Generate sessions dialog with flexible options
class _GenerateSessionsDialog extends StatefulWidget {
  @override
  State<_GenerateSessionsDialog> createState() =>
      _GenerateSessionsDialogState();
}

class _GenerateSessionsDialogState extends State<_GenerateSessionsDialog> {
  final _customSessionsController = TextEditingController();
  final _weeksBetweenController = TextEditingController(text: '1');
  int? _selectedPreset;
  bool _useCustom = false;

  @override
  void dispose() {
    _customSessionsController.dispose();
    _weeksBetweenController.dispose();
    super.dispose();
  }

  int? _getNumberOfSessions() {
    if (_useCustom) {
      final custom = int.tryParse(_customSessionsController.text);
      return custom;
    } else {
      return _selectedPreset;
    }
  }

  int? _getWeeksBetween() {
    final weeks = int.tryParse(_weeksBetweenController.text);
    return weeks;
  }

  bool _isValid() {
    final sessions = _getNumberOfSessions();
    if (sessions == null || sessions <= 0) return false;
    final weeks = _getWeeksBetween();
    if (weeks == null || weeks <= 0) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Generate Sessions')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How many sessions would you like to generate?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            // Preset options
            Wrap(
              spacing: AppDimensions.spacingSM,
              runSpacing: AppDimensions.spacingSM,
              children: [
                _PresetButton(
                  label: '4 weeks',
                  value: 4,
                  selected: _selectedPreset == 4 && !_useCustom,
                  onTap: () {
                    setState(() {
                      _selectedPreset = 4;
                      _useCustom = false;
                    });
                  },
                ),
                _PresetButton(
                  label: '8 weeks',
                  value: 8,
                  selected: _selectedPreset == 8 && !_useCustom,
                  onTap: () {
                    setState(() {
                      _selectedPreset = 8;
                      _useCustom = false;
                    });
                  },
                ),
                _PresetButton(
                  label: '12 weeks',
                  value: 12,
                  selected: _selectedPreset == 12 && !_useCustom,
                  onTap: () {
                    setState(() {
                      _selectedPreset = 12;
                      _useCustom = false;
                    });
                  },
                ),
                _PresetButton(
                  label: '16 weeks',
                  value: 16,
                  selected: _selectedPreset == 16 && !_useCustom,
                  onTap: () {
                    setState(() {
                      _selectedPreset = 16;
                      _useCustom = false;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            // Custom option
            Row(
              children: [
                Checkbox(
                  value: _useCustom,
                  onChanged: (value) {
                    setState(() {
                      _useCustom = value ?? false;
                      if (_useCustom) {
                        _selectedPreset = null;
                      }
                    });
                  },
                ),
                Expanded(
                  child: Text(context.tr('Enter custom number of sessions')),
                ),
              ],
            ),
            if (_useCustom) ...[
              SizedBox(height: AppDimensions.spacingSM),
              TextField(
                controller: _customSessionsController,
                decoration: InputDecoration(
                  labelText: context.tr('Number of Sessions'),
                  hintText: context.tr('e.g., 20'),
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ],
            SizedBox(height: AppDimensions.spacingMD),
            Divider(),
            SizedBox(height: AppDimensions.spacingMD),
            // Weeks between sessions
            Text(
              'Weeks between sessions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppDimensions.spacingSM),
            TextField(
              controller: _weeksBetweenController,
              decoration: InputDecoration(
                labelText: context.tr('Weeks'),
                hintText: '1',
                prefixIcon: Icon(Icons.calendar_view_week),
                helperText: context.tr('How many weeks between each session'),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        ElevatedButton(
          onPressed: _isValid()
              ? () {
                  final sessions = _getNumberOfSessions()!;
                  final weeks = _getWeeksBetween()!;
                  Navigator.pop(context, {
                    'sessions': sessions,
                    'weeksBetween': weeks,
                  });
                }
              : null,
          child: Text(context.tr('Generate')),
        ),
      ],
    );
  }
}

/// Preset button widget
class _PresetButton extends StatelessWidget {
  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMD,
          vertical: AppDimensions.paddingSM,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.primary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Members tab
class _MembersTab extends StatefulWidget {
  final String classId;

  const _MembersTab({required this.classId});

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await ClassService.getClassMembers(widget.classId);
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading members: $e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_members.isEmpty) {
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
            Text(context.tr('No members enrolled')),
            SizedBox(height: AppDimensions.spacingSM),
            ElevatedButton.icon(
              onPressed: _addMember,
              icon: Icon(Icons.person_add),
              label: Text(context.tr('Add Members')),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadMembers,
        child: ListView.builder(
          itemCount: _members.length,
          itemBuilder: (context, index) {
            final enrollment = _members[index];
            final member = enrollment['members'] as Map<String, dynamic>?;
            if (member == null) return SizedBox.shrink();

            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  member['first_name']?[0]?.toString().toUpperCase() ?? 'M',
                ),
              ),
              title: Text('${member['first_name']} ${member['last_name']}'),
              subtitle: Text(member['email']?.toString() ?? ''),
              trailing: IconButton(
                icon: Icon(Icons.close, color: AppColors.error),
                onPressed: () => _removeMember(member['id'].toString()),
                tooltip: context.tr('Remove from training'),
              ),
              onTap: () {
                Navigator.of(context).pushNamed(
                  RouteNames.memberDetail.replaceAll(
                    ':id',
                    member['id'].toString(),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMember,
        icon: Icon(Icons.person_add),
        label: Text(context.tr('Add Members')),
      ),
    );
  }

  Future<void> _addMember() async {
    try {
      // Get all members
      final allMembers = await MemberService.getMembers(
        filters: {'is_active': true},
        orderBy: 'first_name',
        ascending: true,
      );

      // Get currently enrolled member IDs
      final enrolledMemberIds = _members
          .map((e) => e['members']?['id']?.toString())
          .where((id) => id != null)
          .toSet();

      // Filter out already enrolled members
      final availableMembers = allMembers
          .where(
            (member) => !enrolledMemberIds.contains(member['id'].toString()),
          )
          .toList();

      if (availableMembers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('All members are already enrolled in this class'),
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      final selectedMemberIds = <String>{};

      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(context.tr('Add Members to Training')),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.tr('Select members to add:')),
                    SizedBox(height: AppDimensions.spacingMD),
                    // Select all / Deselect all buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              if (selectedMemberIds.length ==
                                  availableMembers.length) {
                                selectedMemberIds.clear();
                              } else {
                                selectedMemberIds.clear();
                                selectedMemberIds.addAll(
                                  availableMembers.map(
                                    (m) => m['id'].toString(),
                                  ),
                                );
                              }
                            });
                          },
                          child: Text(
                            selectedMemberIds.length == availableMembers.length
                                ? 'Deselect All'
                                : 'Select All',
                          ),
                        ),
                        Text(
                          '${selectedMemberIds.length} selected',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    SizedBox(height: AppDimensions.spacingSM),
                    // Member list with checkboxes
                    ...availableMembers.map((member) {
                      final memberId = member['id'].toString();
                      final isSelected = selectedMemberIds.contains(memberId);
                      return CheckboxListTile(
                        title: Text(
                          '${member['first_name']} ${member['last_name']}',
                        ),
                        subtitle: member['email'] != null
                            ? Text(member['email'].toString())
                            : null,
                        value: isSelected,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedMemberIds.add(memberId);
                            } else {
                              selectedMemberIds.remove(memberId);
                            }
                          });
                        },
                        dense: true,
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Cancel')),
              ),
              ElevatedButton(
                onPressed: selectedMemberIds.isEmpty
                    ? null
                    : () => Navigator.pop(context, true),
                child: Text(
                  selectedMemberIds.isEmpty
                      ? 'Add'
                      : 'Add ${selectedMemberIds.length}',
                ),
              ),
            ],
          ),
        ),
      );

      if (result == true && selectedMemberIds.isNotEmpty) {
        // Add all selected members
        int successCount = 0;
        int errorCount = 0;
        final errors = <String>[];

        for (final memberId in selectedMemberIds) {
          try {
            await ClassService.addMemberToClass(
              classId: widget.classId,
              memberId: memberId,
            );
            successCount++;
          } catch (e) {
            errorCount++;
            errors.add(e.toString());
          }
        }

        if (mounted) {
          _loadMembers();
          if (errorCount == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  successCount == 1
                      ? 'Member added successfully'
                      : '$successCount members added successfully',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$successCount members added, $errorCount failed',
                ),
                backgroundColor: AppColors.warning,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error adding members: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeMember(String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove Member')),
        content: Text(
          'Are you sure you want to remove this member from the class?',
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

    if (confirmed != true) return;

    try {
      await ClassService.removeMemberFromClass(
        classId: widget.classId,
        memberId: memberId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Member removed successfully')),
            backgroundColor: AppColors.success,
          ),
        );
        _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error removing member: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
