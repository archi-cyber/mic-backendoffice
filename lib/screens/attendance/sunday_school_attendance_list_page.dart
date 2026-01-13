import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/sunday_school_attendance_service.dart';
import '../../services/attendance_report_pdf_service.dart';

/// Page showing list of Sunday school sessions with details
class SundaySchoolAttendanceListPage extends StatefulWidget {
  const SundaySchoolAttendanceListPage({super.key});

  @override
  State<SundaySchoolAttendanceListPage> createState() =>
      _SundaySchoolAttendanceListPageState();
}

class _SundaySchoolAttendanceListPageState
    extends State<SundaySchoolAttendanceListPage> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await SundaySchoolAttendanceService.getAllSessions(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
        limit: 200,
      );

      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sessions: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
    });
    _loadSessions();
  }

  bool get _hasActiveFilters {
    return _filterStartDate != null || _filterEndDate != null;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _viewSessionDetails(String sessionDate) async {
    final result = await Navigator.of(context).pushNamed(
      RouteNames.sundaySchoolAttendance,
      arguments: {'sessionDate': sessionDate},
    );
    if (result == true) {
      _loadSessions();
    }
  }

  Future<void> _markNewAttendance() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.sundaySchoolAttendance);
    if (result == true) {
      _loadSessions();
    }
  }

  Future<void> _deleteSession(String sessionDate) async {
    final sessionDateObj = DateTime.parse(sessionDate);
    final formattedDate = _formatDate(sessionDate);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Are you sure you want to delete the Sunday school session on $formattedDate? This will remove all attendance records for this session and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SundaySchoolAttendanceService.deleteSession(sessionDateObj);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadSessions(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting session: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sunday School Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: _generateReport,
            tooltip: 'Generate Report',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Sessions',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _markNewAttendance,
            tooltip: 'Mark New Attendance',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Summary Bar
          if (_hasActiveFilters)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingMD,
                vertical: AppDimensions.spacingSM,
              ),
              color: AppColors.primary.withOpacity(0.1),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppDimensions.spacingSM,
                      runSpacing: AppDimensions.spacingXS,
                      children: [
                        if (_filterStartDate != null)
                          Chip(
                            label: Text(
                              'From: ${_formatDate(_filterStartDate!.toIso8601String().split('T')[0])}',
                            ),
                            onDeleted: () {
                              setState(() {
                                _filterStartDate = null;
                              });
                              _loadSessions();
                            },
                          ),
                        if (_filterEndDate != null)
                          Chip(
                            label: Text(
                              'To: ${_formatDate(_filterEndDate!.toIso8601String().split('T')[0])}',
                            ),
                            onDeleted: () {
                              setState(() {
                                _filterEndDate = null;
                              });
                              _loadSessions();
                            },
                          ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
            ),
          // Sessions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.school,
                                size: 64,
                                color: Theme.of(context).disabledColor,
                              ),
                              const SizedBox(height: AppDimensions.spacingMD),
                              Text(
                                'No sessions found',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppDimensions.spacingSM),
                              Text(
                                'Tap the + button to mark attendance for a new session',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadSessions,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(
                              AppDimensions.spacingMD,
                            ),
                            itemCount: _sessions.length,
                            itemBuilder: (context, index) {
                              final session = _sessions[index];
                              final sessionDate =
                                  session['attendance_date'] as String;
                              final attendanceCount =
                                  session['attendance_count'] as int? ?? 0;

                              return Card(
                                margin: const EdgeInsets.only(
                                  bottom: AppDimensions.spacingMD,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.accent,
                                    child: const Icon(
                                      Icons.school,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    'Sunday School',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(sessionDate),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.people,
                                            size: 16,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$attendanceCount ${attendanceCount == 1 ? 'child' : 'children'} attended',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.error,
                                        ),
                                        onPressed: () => _deleteSession(sessionDate),
                                        tooltip: 'Delete Session',
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: () => _viewSessionDetails(sessionDate),
                                ),
                              );
                            },
                          ),
                        )),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
        onApply: (startDate, endDate) {
          setState(() {
            _filterStartDate = startDate;
            _filterEndDate = endDate;
          });
          _loadSessions();
        },
      ),
    );
  }

  Future<void> _generateReport() async {
    // Show dialog to select report options
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ReportOptionsDialog(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
      ),
    );

    if (result != null) {
      try {
        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
        }

        final filePath =
            await AttendanceReportPdfService.generateSundaySchoolReport(
              startDate: result['startDate'] as DateTime?,
              endDate: result['endDate'] as DateTime?,
            );

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report generated successfully: $filePath'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating report: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

class _FilterDialog extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?, DateTime?) onApply;

  const _FilterDialog({
    required this.startDate,
    required this.endDate,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late DateTime? _startDate;
  late DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Start Date',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select End Date',
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Sessions'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start Date
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Start Date'),
              subtitle: Text(
                _startDate != null
                    ? DateFormat('MMM d, yyyy').format(_startDate!)
                    : 'No date selected',
              ),
              trailing: IconButton(
                icon: _startDate != null
                    ? const Icon(Icons.clear)
                    : const Icon(Icons.arrow_forward),
                onPressed: _startDate != null
                    ? () {
                        setState(() {
                          _startDate = null;
                        });
                      }
                    : _selectStartDate,
              ),
              onTap: _selectStartDate,
            ),
            // End Date
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('End Date'),
              subtitle: Text(
                _endDate != null
                    ? DateFormat('MMM d, yyyy').format(_endDate!)
                    : 'No date selected',
              ),
              trailing: IconButton(
                icon: _endDate != null
                    ? const Icon(Icons.clear)
                    : const Icon(Icons.arrow_forward),
                onPressed: _endDate != null
                    ? () {
                        setState(() {
                          _endDate = null;
                        });
                      }
                    : _selectEndDate,
              ),
              onTap: _selectEndDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_startDate, _endDate);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _ReportOptionsDialog extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;

  const _ReportOptionsDialog({required this.startDate, required this.endDate});

  @override
  State<_ReportOptionsDialog> createState() => _ReportOptionsDialogState();
}

class _ReportOptionsDialogState extends State<_ReportOptionsDialog> {
  late DateTime? _startDate;
  late DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Start Date',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select End Date',
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Sunday School Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Start Date'),
              subtitle: Text(
                _startDate != null
                    ? DateFormat('MMM d, yyyy').format(_startDate!)
                    : 'No date selected',
              ),
              trailing: IconButton(
                icon: _startDate != null
                    ? const Icon(Icons.clear)
                    : const Icon(Icons.arrow_forward),
                onPressed: _startDate != null
                    ? () {
                        setState(() {
                          _startDate = null;
                        });
                      }
                    : _selectStartDate,
              ),
              onTap: _selectStartDate,
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('End Date'),
              subtitle: Text(
                _endDate != null
                    ? DateFormat('MMM d, yyyy').format(_endDate!)
                    : 'No date selected',
              ),
              trailing: IconButton(
                icon: _endDate != null
                    ? const Icon(Icons.clear)
                    : const Icon(Icons.arrow_forward),
                onPressed: _endDate != null
                    ? () {
                        setState(() {
                          _endDate = null;
                        });
                      }
                    : _selectEndDate,
              ),
              onTap: _selectEndDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop({'startDate': _startDate, 'endDate': _endDate});
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
