import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'task_report_service.dart';
import 'department_service.dart';

/// Service for generating PDF reports for task completion
class TaskReportPdfService {
  /// Generate monthly task report for a department
  static Future<String?> generateMonthlyReport({
    required String departmentId,
    required int year,
    required int month,
  }) async {
    try {
      debugPrint(
        '[TaskReportPdfService] Generating monthly report for department: $departmentId, $year-$month',
      );

      // Get department info
      final department = await DepartmentService.getDepartmentById(
        departmentId,
      );
      final departmentName = department['name'] ?? 'Unknown Department';

      // Calculate date range for the month
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      // Get task statistics
      final statistics = await TaskReportService.getDepartmentTaskStatistics(
        departmentId: departmentId,
        startDate: startDate,
        endDate: endDate,
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            _buildHeader(
              '$departmentName - Monthly Task Report',
              DateFormat('MMMM yyyy').format(startDate),
            ),
            pw.SizedBox(height: 20),
            _buildSummarySection(statistics),
            pw.SizedBox(height: 20),
            _buildTasksList(
              (statistics['tasks_with_details'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [],
            ),
          ],
        ),
      );

      final fileName =
          'task_report_${departmentName.replaceAll(' ', '_')}_${year}_${month.toString().padLeft(2, '0')}';
      return await _savePdf(pdf, fileName);
    } catch (e) {
      debugPrint('[TaskReportPdfService] Error generating monthly report: $e');
      rethrow;
    }
  }

  /// Generate yearly task report for a department
  static Future<String?> generateYearlyReport({
    required String departmentId,
    required int year,
  }) async {
    try {
      debugPrint(
        '[TaskReportPdfService] Generating yearly report for department: $departmentId, $year',
      );

      // Get department info
      final department = await DepartmentService.getDepartmentById(
        departmentId,
      );
      final departmentName = department['name'] ?? 'Unknown Department';

      // Calculate date range for the year
      final startDate = DateTime(year, 1, 1);
      final endDate = DateTime(year, 12, 31, 23, 59, 59);

      // Get monthly breakdown
      final List<Map<String, dynamic>> monthlyData = [];
      for (int month = 1; month <= 12; month++) {
        final monthStart = DateTime(year, month, 1);
        final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);

        final monthStats = await TaskReportService.getDepartmentTaskCompletion(
          departmentId: departmentId,
          startDate: monthStart,
          endDate: monthEnd,
        );

        monthlyData.add({
          'month': month,
          'month_name': DateFormat('MMMM').format(monthStart),
          ...monthStats,
        });
      }

      // Get overall statistics
      final overallStats = await TaskReportService.getDepartmentTaskStatistics(
        departmentId: departmentId,
        startDate: startDate,
        endDate: endDate,
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            _buildHeader(
              '$departmentName - Yearly Task Report',
              year.toString(),
            ),
            pw.SizedBox(height: 20),
            _buildSummarySection(overallStats),
            pw.SizedBox(height: 20),
            _buildMonthlyBreakdown(monthlyData),
            pw.SizedBox(height: 20),
            _buildTasksList(
              (overallStats['tasks_with_details'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [],
            ),
          ],
        ),
      );

      final fileName =
          'task_report_${departmentName.replaceAll(' ', '_')}_$year';
      return await _savePdf(pdf, fileName);
    } catch (e) {
      debugPrint('[TaskReportPdfService] Error generating yearly report: $e');
      rethrow;
    }
  }

  /// Generate report for all departments
  static Future<String?> generateAllDepartmentsReport({
    required int year,
    int? month,
  }) async {
    try {
      debugPrint(
        '[TaskReportPdfService] Generating report for all departments, $year${month != null ? '-$month' : ''}',
      );

      DateTime startDate;
      DateTime endDate;
      String periodLabel;

      if (month != null) {
        startDate = DateTime(year, month, 1);
        endDate = DateTime(year, month + 1, 0, 23, 59, 59);
        periodLabel = DateFormat('MMMM yyyy').format(startDate);
      } else {
        startDate = DateTime(year, 1, 1);
        endDate = DateTime(year, 12, 31, 23, 59, 59);
        periodLabel = year.toString();
      }

      // Get completion for all departments
      final departmentsCompletion =
          await TaskReportService.getAllDepartmentsTaskCompletion(
            startDate: startDate,
            endDate: endDate,
          );

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            _buildHeader('All Departments - Task Report', periodLabel),
            pw.SizedBox(height: 20),
            _buildAllDepartmentsSummary(departmentsCompletion),
          ],
        ),
      );

      final fileName =
          'task_report_all_departments_$year${month != null ? '_${month.toString().padLeft(2, '0')}' : ''}';
      return await _savePdf(pdf, fileName);
    } catch (e) {
      debugPrint(
        '[TaskReportPdfService] Error generating all departments report: $e',
      );
      rethrow;
    }
  }

  static pw.Widget _buildHeader(String title, String period) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Period: $period', style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 5),
        pw.Text(
          'Generated: ${DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  static pw.Widget _buildSummarySection(Map<String, dynamic> statistics) {
    final totalTasks = statistics['total_tasks'] as int? ?? 0;
    final completedTasks = statistics['completed_tasks'] as int? ?? 0;
    final pendingTasks = statistics['pending_tasks'] as int? ?? 0;
    final inProgressTasks = statistics['in_progress_tasks'] as int? ?? 0;
    final completionPercentage =
        statistics['completion_percentage'] as double? ?? 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatBox('Total Tasks', totalTasks.toString()),
              _buildStatBox('Completed', completedTasks.toString()),
              _buildStatBox('Pending', pendingTasks.toString()),
              _buildStatBox('In Progress', inProgressTasks.toString()),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Completion Percentage:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${completionPercentage.toStringAsFixed(1)}%',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _getCompletionColor(completionPercentage),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMonthlyBreakdown(
    List<Map<String, dynamic>> monthlyData,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Monthly Breakdown',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Month', isHeader: true),
                  _buildTableCell('Total', isHeader: true),
                  _buildTableCell('Completed', isHeader: true),
                  _buildTableCell('Pending', isHeader: true),
                  _buildTableCell('Completion %', isHeader: true),
                ],
              ),
              // Data rows
              ...monthlyData.map((monthData) {
                final monthName = monthData['month_name'] as String? ?? '';
                final total = monthData['total_tasks'] as int? ?? 0;
                final completed = monthData['completed_tasks'] as int? ?? 0;
                final pending = monthData['pending_tasks'] as int? ?? 0;
                final percentage =
                    monthData['completion_percentage'] as double? ?? 0.0;

                return pw.TableRow(
                  children: [
                    _buildTableCell(monthName),
                    _buildTableCell(total.toString()),
                    _buildTableCell(completed.toString()),
                    _buildTableCell(pending.toString()),
                    _buildTableCell('${percentage.toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAllDepartmentsSummary(
    List<Map<String, dynamic>> departments,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Department Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Department', isHeader: true),
                  _buildTableCell('Total Tasks', isHeader: true),
                  _buildTableCell('Completed', isHeader: true),
                  _buildTableCell('Pending', isHeader: true),
                  _buildTableCell('Completion %', isHeader: true),
                ],
              ),
              // Data rows
              ...departments.map((dept) {
                final deptName = dept['department_name'] as String? ?? '';
                final total = dept['total_tasks'] as int? ?? 0;
                final completed = dept['completed_tasks'] as int? ?? 0;
                final pending = dept['pending_tasks'] as int? ?? 0;
                final percentage =
                    dept['completion_percentage'] as double? ?? 0.0;

                return pw.TableRow(
                  children: [
                    _buildTableCell(deptName),
                    _buildTableCell(total.toString()),
                    _buildTableCell(completed.toString()),
                    _buildTableCell(pending.toString()),
                    _buildTableCell('${percentage.toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTasksList(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(15),
        child: pw.Text(
          'No tasks found for this period',
          style: const pw.TextStyle(fontSize: 12),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Tasks Details',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          ...tasks.take(50).map((task) {
            // Limit to 50 tasks to avoid PDF being too large
            final title = task['title'] ?? 'Untitled Task';
            final status = task['status'] ?? 'pending';
            final description = task['description'] ?? '';
            final createdAt = task['created_at'];
            final dueDate = task['due_date'];
            final assignmentCount = task['assignment_count'] as int? ?? 0;

            String dateStr = '';
            try {
              if (createdAt != null) {
                final date = DateTime.parse(createdAt.toString());
                dateStr = DateFormat('MMM d, yyyy').format(date);
              }
            } catch (e) {
              // Ignore
            }

            String dueDateStr = '';
            try {
              if (dueDate != null) {
                final date = DateTime.parse(dueDate.toString());
                dueDateStr = DateFormat('MMM d, yyyy').format(date);
              }
            } catch (e) {
              // Ignore
            }

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey200),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          title,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Text(
                        status.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: status == 'completed'
                              ? PdfColors.green
                              : status == 'in_progress'
                              ? PdfColors.orange
                              : PdfColors.red,
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    pw.Text(
                      description,
                      style: const pw.TextStyle(fontSize: 10),
                      maxLines: 2,
                    ),
                  ],
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      if (dateStr.isNotEmpty)
                        pw.Text(
                          'Created: $dateStr',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      if (dueDateStr.isNotEmpty) ...[
                        pw.SizedBox(width: 10),
                        pw.Text(
                          'Due: $dueDateStr',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                      pw.Spacer(),
                      pw.Text(
                        'Assignments: $assignmentCount',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          if (tasks.length > 50)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                '... and ${tasks.length - 50} more tasks',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatBox(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static PdfColor _getCompletionColor(double percentage) {
    if (percentage >= 80) {
      return PdfColors.green;
    } else if (percentage >= 50) {
      return PdfColors.orange;
    } else {
      return PdfColors.red;
    }
  }

  static Future<String?> _savePdf(pw.Document pdf, String fileName) async {
    try {
      // Try to let user select save location
      final bytes = await pdf.save();
      final result = await FilePicker.platform.saveFile(
        fileName: '$fileName.pdf',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        debugPrint(
          '[TaskReportPdfService] PDF saved to user-selected location: $result',
        );
        return result;
      }

      // Fallback: save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName.pdf');
      await file.writeAsBytes(bytes);
      debugPrint(
        '[TaskReportPdfService] PDF saved to temporary directory: ${file.path}',
      );

      // Try to share the file
      if (Platform.isAndroid || Platform.isIOS) {
        final xFile = XFile(file.path);
        await Share.shareXFiles([xFile], text: 'Task Report');
      }

      return file.path;
    } catch (e) {
      debugPrint('[TaskReportPdfService] Error saving PDF: $e');
      rethrow;
    }
  }
}
