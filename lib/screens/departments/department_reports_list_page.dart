import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/department_report_service.dart';
import '../../services/department_service.dart';
import '../../services/department_report_pdf_service.dart';

/// Department reports list page
class DepartmentReportsListPage extends StatefulWidget {
  final String departmentId;

  const DepartmentReportsListPage({super.key, required this.departmentId});

  @override
  State<DepartmentReportsListPage> createState() =>
      _DepartmentReportsListPageState();
}

class _DepartmentReportsListPageState extends State<DepartmentReportsListPage> {
  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic>? _department;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      debugPrint(
        '[DepartmentReportsListPage] Loading data for department: ${widget.departmentId}',
      );
      // Load department first
      Map<String, dynamic> department;
      try {
        department = await DepartmentService.getDepartmentById(
          widget.departmentId,
        );
        debugPrint(
          '[DepartmentReportsListPage] Department loaded: ${department['name']}',
        );
      } catch (e) {
        debugPrint('[DepartmentReportsListPage] Error loading department: $e');
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to get department: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Load reports (this might fail if table doesn't exist yet)
      List<Map<String, dynamic>> reports = [];
      try {
        reports = await DepartmentReportService.getDepartmentReports(
          departmentId: widget.departmentId,
        );
      } catch (e) {
        // If reports fail to load, show warning but continue
        debugPrint('Warning: Failed to load reports: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Department loaded but reports failed to load. Make sure the department_reports table exists. Error: $e',
              ),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      setState(() {
        _department = department;
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _generateSummaryReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating summary report...')),
      );
      await DepartmentReportPdfService.generateSummaryPdf(widget.departmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Summary report generated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_department?['name'] ?? 'Department'} Reports'),
        actions: [
          if (_reports.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.summarize),
              onPressed: _generateSummaryReport,
              tooltip: 'Generate Summary Report',
            ),
        ],
      ),
      body: Column(
        children: [
          // Add Report button
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).pushNamed(
                  RouteNames.addDepartmentReport,
                  arguments: widget.departmentId,
                );
                if (result == true) {
                  _loadData();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Report'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  AppDimensions.buttonHeightMD,
                ),
              ),
            ),
          ),
          // Reports list
          Expanded(
            child: _reports.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: AppDimensions.spacingMD),
                        Text('No reports yet'),
                        SizedBox(height: AppDimensions.spacingXS),
                        Text(
                          'Create your first report to get started',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppDimensions.paddingMD),
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: AppDimensions.spacingMD,
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.description,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              report['title'] ?? 'Untitled Report',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Created: ${DateFormat('MMM d, yyyy').format(DateTime.parse(report['created_at']))}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility, size: 20),
                                      SizedBox(width: 8),
                                      Text('View'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'pdf',
                                  child: Row(
                                    children: [
                                      Icon(Icons.picture_as_pdf, size: 20),
                                      SizedBox(width: 8),
                                      Text('Generate PDF'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: AppColors.error,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) async {
                                if (value == 'view') {
                                  await Navigator.of(context).pushNamed(
                                    RouteNames.departmentReportDetail,
                                    arguments: report['id'],
                                  );
                                  _loadData();
                                } else if (value == 'pdf') {
                                  try {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Generating PDF...'),
                                      ),
                                    );
                                    await DepartmentReportPdfService.generateReportPdf(
                                      report['id'],
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'PDF generated successfully',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                } else if (value == 'edit') {
                                  final result = await Navigator.of(context)
                                      .pushNamed(
                                        RouteNames.editDepartmentReport,
                                        arguments: report['id'],
                                      );
                                  if (result == true) {
                                    _loadData();
                                  }
                                } else if (value == 'delete') {
                                  _deleteReport(report);
                                }
                              },
                            ),
                            onTap: () async {
                              await Navigator.of(context).pushNamed(
                                RouteNames.editDepartmentReport.replaceAll(
                                  ':id',
                                  report['id'].toString(),
                                ),
                              );
                              _loadData();
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text('Are you sure you want to delete "${report['title']}"?'),
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
        await DepartmentReportService.deleteReport(report['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting report: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
