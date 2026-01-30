import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/church_attendance_service.dart';
import '../../services/attendance_report_pdf_service.dart';
import '../desktop/desktop_shell_scope.dart';

/// Page showing list of church services with details
class ChurchAttendanceListPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const ChurchAttendanceListPage({
    super.key,
    this.hideAppBarAndBottomNav = false,
  });

  @override
  State<ChurchAttendanceListPage> createState() =>
      _ChurchAttendanceListPageState();
}

const double _kChurchAttendanceDesktopBreakpoint = 700;
const double _kChurchAttendanceDesktopMaxWidth = 1000;

class _ChurchAttendanceListPageState extends State<ChurchAttendanceListPage> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _filterServiceType;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      // Load services with filters
      final services = await ChurchAttendanceService.getAllServices(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
        limit: 200,
      );

      // Apply service type filter if set
      List<Map<String, dynamic>> filteredServices = services;
      if (_filterServiceType != null) {
        filteredServices = services
            .where((s) => s['service_type'] == _filterServiceType)
            .toList();
      }

      setState(() {
        _services = filteredServices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading services: $e'),
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
      _filterServiceType = null;
    });
    _loadServices();
  }

  bool get _hasActiveFilters {
    return _filterStartDate != null ||
        _filterEndDate != null ||
        _filterServiceType != null;
  }

  String _getServiceTypeLabel(String serviceType) {
    return serviceType == 'sunday' ? 'Sunday Service' : 'Wednesday Service';
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _viewServiceDetails(
    String serviceDate,
    String serviceType,
  ) async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(
        RouteNames.churchAttendance,
        '$serviceDate|$serviceType',
      );
    } else {
      final result = await Navigator.of(context).pushNamed(
        RouteNames.churchAttendance,
        arguments: {'serviceDate': serviceDate, 'serviceType': serviceType},
      );
      if (result == true) _loadServices();
    }
  }

  Future<void> _markNewAttendance() async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.churchAttendance, '');
    } else {
      final result = await Navigator.of(
        context,
      ).pushNamed(RouteNames.churchAttendance);
      if (result == true) _loadServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        widget.hideAppBarAndBottomNav &&
        MediaQuery.sizeOf(context).width >= _kChurchAttendanceDesktopBreakpoint;

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: const Text('Church Attendance'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.description),
                  onPressed: _generateReport,
                  tooltip: 'Generate Report',
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                  tooltip: 'Filter Services',
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _markNewAttendance,
                  tooltip: 'Mark New Attendance',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadServices,
                  tooltip: 'Refresh',
                ),
              ],
            ),
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(context),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _kChurchAttendanceDesktopMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_hasActiveFilters) ...[
                    Wrap(
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
                              _loadServices();
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
                              _loadServices();
                            },
                          ),
                        if (_filterServiceType != null)
                          Chip(
                            label: Text(
                              _getServiceTypeLabel(_filterServiceType!),
                            ),
                            onDeleted: () {
                              setState(() {
                                _filterServiceType = null;
                              });
                              _loadServices();
                            },
                          ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear All'),
                    ),
                    const SizedBox(width: AppDimensions.spacingMD),
                  ],
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _showFilterDialog,
                    tooltip: 'Filter Services',
                  ),
                  IconButton(
                    icon: const Icon(Icons.description),
                    onPressed: _generateReport,
                    tooltip: 'Generate Report',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _loadServices,
                    tooltip: 'Refresh',
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _markNewAttendance,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _services.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.church,
                              size: 64,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: AppDimensions.spacingMD),
                            Text(
                              'No services found',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppDimensions.spacingSM),
                            Text(
                              'Create a new service attendance to get started.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppDimensions.spacingLG),
                            FilledButton.icon(
                              onPressed: _markNewAttendance,
                              icon: const Icon(Icons.add),
                              label: const Text('Create'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadServices,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                theme.colorScheme.surfaceContainerHighest,
                              ),
                              columns: const [
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Service Type')),
                                DataColumn(label: Text('Attended')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _services.map((service) {
                                final serviceDate =
                                    service['service_date'] as String;
                                final serviceType =
                                    service['service_type'] as String;
                                final attendanceCount =
                                    service['attendance_count'] as int? ?? 0;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        _formatDate(serviceDate),
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            serviceType == 'sunday'
                                                ? Icons.wb_sunny
                                                : Icons.calendar_today,
                                            size: 18,
                                            color: serviceType == 'sunday'
                                                ? AppColors.primary
                                                : AppColors.secondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _getServiceTypeLabel(serviceType),
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '$attendanceCount ${attendanceCount == 1 ? 'member' : 'members'}',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    DataCell(
                                      TextButton(
                                        onPressed: () => _viewServiceDetails(
                                          serviceDate,
                                          serviceType,
                                        ),
                                        child: const Text('View'),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
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

  Widget _buildMobileBody(BuildContext context) {
    return Column(
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
                            _loadServices();
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
                            _loadServices();
                          },
                        ),
                      if (_filterServiceType != null)
                        Chip(
                          label: Text(
                            _getServiceTypeLabel(_filterServiceType!),
                          ),
                          onDeleted: () {
                            setState(() {
                              _filterServiceType = null;
                            });
                            _loadServices();
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
        // Services List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_services.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.church,
                              size: 64,
                              color: Theme.of(context).disabledColor,
                            ),
                            const SizedBox(height: AppDimensions.spacingMD),
                            Text(
                              'No services found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppDimensions.spacingSM),
                            Text(
                              'Tap the + button to mark attendance for a new service',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadServices,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(
                            AppDimensions.spacingMD,
                          ),
                          itemCount: _services.length,
                          itemBuilder: (context, index) {
                            final service = _services[index];
                            final serviceDate =
                                service['service_date'] as String;
                            final serviceType =
                                service['service_type'] as String;
                            final attendanceCount =
                                service['attendance_count'] as int? ?? 0;

                            return Card(
                              margin: const EdgeInsets.only(
                                bottom: AppDimensions.spacingMD,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: serviceType == 'sunday'
                                      ? AppColors.primary
                                      : AppColors.secondary,
                                  child: Icon(
                                    serviceType == 'sunday'
                                        ? Icons.wb_sunny
                                        : Icons.calendar_today,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  _getServiceTypeLabel(serviceType),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(serviceDate),
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
                                          '$attendanceCount ${attendanceCount == 1 ? 'member' : 'members'} attended',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _viewServiceDetails(
                                  serviceDate,
                                  serviceType,
                                ),
                              ),
                            );
                          },
                        ),
                      )),
        ),
      ],
    );
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
        serviceType: _filterServiceType,
        onApply: (startDate, endDate, serviceType) {
          setState(() {
            _filterStartDate = startDate;
            _filterEndDate = endDate;
            _filterServiceType = serviceType;
          });
          _loadServices();
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
        serviceType: _filterServiceType,
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
            await AttendanceReportPdfService.generateChurchAttendanceReport(
              startDate: result['startDate'] as DateTime?,
              endDate: result['endDate'] as DateTime?,
              serviceType: result['serviceType'] as String?,
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

class _ReportOptionsDialog extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? serviceType;

  const _ReportOptionsDialog({
    required this.startDate,
    required this.endDate,
    required this.serviceType,
  });

  @override
  State<_ReportOptionsDialog> createState() => _ReportOptionsDialogState();
}

class _ReportOptionsDialogState extends State<_ReportOptionsDialog> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late String? _serviceType;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _serviceType = widget.serviceType;
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
      title: const Text('Generate Church Attendance Report'),
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
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Service Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            RadioListTile<String?>(
              title: const Text('All Services'),
              value: null,
              groupValue: _serviceType,
              onChanged: (value) {
                setState(() {
                  _serviceType = value;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Sunday Service'),
              value: 'sunday',
              groupValue: _serviceType,
              onChanged: (value) {
                setState(() {
                  _serviceType = value;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Wednesday Service'),
              value: 'wednesday',
              groupValue: _serviceType,
              onChanged: (value) {
                setState(() {
                  _serviceType = value;
                });
              },
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
            Navigator.of(context).pop({
              'startDate': _startDate,
              'endDate': _endDate,
              'serviceType': _serviceType,
            });
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? serviceType;
  final Function(DateTime?, DateTime?, String?) onApply;

  const _FilterDialog({
    required this.startDate,
    required this.endDate,
    required this.serviceType,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late String? _serviceType;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _serviceType = widget.serviceType;
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
      title: const Text('Filter Services'),
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
            const Divider(),
            // Service Type
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Service Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            RadioListTile<String?>(
              title: const Text('All Services'),
              value: null,
              groupValue: _serviceType,
              onChanged: (value) {
                setState(() {
                  _serviceType = value;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Sunday Service'),
              value: 'sunday',
              groupValue: _serviceType,
              onChanged: (value) {
                setState(() {
                  _serviceType = value;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Wednesday Service'),
              value: 'wednesday',
              groupValue: _serviceType,
              onChanged: (value) {
                setState(() {
                  _serviceType = value;
                });
              },
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
            widget.onApply(_startDate, _endDate, _serviceType);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
