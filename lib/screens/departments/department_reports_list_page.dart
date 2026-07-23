import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/department_report_service.dart';
import '../../services/department_service.dart';
import '../../services/department_report_pdf_service.dart';
import '../../core/localization/app_localizations.dart';

/// Department reports list page
class DepartmentReportsListPage extends StatefulWidget {
  final String departmentId;

  DepartmentReportsListPage({super.key, required this.departmentId});

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
              content: Text(context.tr('Failed to get department: $e')),
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
              duration: Duration(seconds: 5),
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
            content: Text(context.tr('Error loading data: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _generateSummaryReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Generating summary report...'))),
      );
      await DepartmentReportPdfService.generateSummaryPdf(widget.departmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Summary report generated successfully')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error generating report: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('{name} Reports', {
            'name': _department?['name']?.toString() ?? context.tr('Department'),
          }),
        ),
        actions: [
          if (_reports.isNotEmpty)
            IconButton(
              icon: Icon(Icons.summarize),
              onPressed: _generateSummaryReport,
              tooltip: context.tr('Generate Summary Report'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Add Report button
          Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
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
              icon: Icon(Icons.add),
              label: Text(context.tr('Create Report')),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(
                  double.infinity,
                  AppDimensions.buttonHeightMD,
                ),
              ),
            ),
          ),
          // Reports list
          Expanded(
            child: _reports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: context.mic.textSecondary,
                        ),
                        SizedBox(height: AppDimensions.spacingMD),
                        Text(context.tr('No reports yet')),
                        SizedBox(height: AppDimensions.spacingXS),
                        Text(
                          context.tr('Create your first report to get started'),
                          style: TextStyle(color: context.mic.textSecondary),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: EdgeInsets.all(AppDimensions.paddingMD),
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        return Card(
                          margin: EdgeInsets.only(
                            bottom: AppDimensions.spacingMD,
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.description,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              report['title'] ?? context.tr('Untitled Report'),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text(
                                  'Created: ${DateFormat('MMM d, yyyy').format(DateTime.parse(report['created_at']))}',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility, size: 20),
                                      SizedBox(width: 8),
                                      Text(context.tr('View')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'pdf',
                                  child: Row(
                                    children: [
                                      Icon(Icons.picture_as_pdf, size: 20),
                                      SizedBox(width: 8),
                                      Text(context.tr('Generate PDF')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text(context.tr('Edit')),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: AppColors.error,
                                      ),
                                      SizedBox(width: 8),
                                      Text(context.tr('Delete')),
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
                                      SnackBar(
                                        content: Text(
                                          context.tr('Generating PDF...'),
                                        ),
                                      ),
                                    );
                                    await DepartmentReportPdfService.generateReportPdf(
                                      report['id'],
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.tr('PDF generated successfully'),
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
                                          content: Text(
                                            context.tr('Error: $e'),
                                          ),
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
        title: Text(context.tr('Delete Report')),
        content: Text(
          context.tr('Are you sure you want to delete "{title}"?', {
            'title': report['title'],
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
        await DepartmentReportService.deleteReport(report['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Report deleted successfully')),
              backgroundColor: AppColors.success,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error deleting report: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
