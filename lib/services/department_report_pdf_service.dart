import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'department_report_service.dart';
import 'department_service.dart';

/// Service for generating PDF reports for department reports
class DepartmentReportPdfService {
  /// Generate PDF for a single department report
  static Future<String?> generateReportPdf(String reportId) async {
    try {
      debugPrint(
        '[DepartmentReportPdfService] Generating PDF for report: $reportId',
      );
      final report = await DepartmentReportService.getReportById(reportId);
      debugPrint(
        '[DepartmentReportPdfService] Report fetched: ${report['title']}',
      );

      final department = await DepartmentService.getDepartmentById(
        report['department_id'],
      );
      debugPrint(
        '[DepartmentReportPdfService] Department fetched: ${department['name']}',
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            _buildHeader(department['name'] ?? 'Department'),
            pw.SizedBox(height: 20),
            _buildReportInfo(report),
            pw.SizedBox(height: 20),
            _buildSection(
              'Defined Objectives',
              report['defined_objectives'] ?? '',
            ),
            pw.SizedBox(height: 15),
            _buildSection('Positive Points', report['positive_points'] ?? ''),
            pw.SizedBox(height: 15),
            _buildSection(
              'Difficulties Encountered',
              report['difficulties_encountered'] ?? '',
            ),
            pw.SizedBox(height: 15),
            _buildSection('Suggestions', report['suggestions'] ?? ''),
            if (report['comments'] != null &&
                report['comments'].toString().isNotEmpty) ...[
              pw.SizedBox(height: 15),
              _buildSection('Comments', report['comments']),
            ],
            pw.SizedBox(height: 30),
            _buildFooter(report),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      debugPrint(
        '[DepartmentReportPdfService] PDF generated, size: ${pdfBytes.length} bytes',
      );

      final fileName =
          'department_report_${report['id']}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Let user choose where to save the PDF
      try {
        debugPrint(
          '[DepartmentReportPdfService] Prompting user to select save location...',
        );
        final result = await FilePicker.platform.saveFile(
          fileName: fileName,
          allowedExtensions: ['pdf'],
          bytes: pdfBytes,
          type: FileType.custom,
          dialogTitle: 'Save Department Report',
        );

        if (result != null) {
          debugPrint(
            '[DepartmentReportPdfService] PDF saved to user-selected location: $result',
          );

          // On mobile, also offer to share the file
          if (Platform.isAndroid || Platform.isIOS) {
            try {
              final file = File(result);
              if (await file.exists()) {
                await Share.shareXFiles([
                  XFile(result),
                ], text: 'Department Report');
                debugPrint(
                  '[DepartmentReportPdfService] PDF shared successfully',
                );
              }
            } catch (e) {
              debugPrint('[DepartmentReportPdfService] Error sharing file: $e');
              // Don't throw - file was saved successfully, sharing is optional
            }
          }

          return result;
        } else {
          debugPrint(
            '[DepartmentReportPdfService] User cancelled file save dialog',
          );
          throw Exception('Save cancelled by user');
        }
      } catch (e) {
        debugPrint(
          '[DepartmentReportPdfService] Error with FilePicker.saveFile: $e',
        );

        // Fallback: Save to default location and share
        try {
          debugPrint(
            '[DepartmentReportPdfService] Falling back to default save location...',
          );
          final directory = Platform.isAndroid || Platform.isIOS
              ? await getTemporaryDirectory()
              : await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(pdfBytes);
          debugPrint(
            '[DepartmentReportPdfService] PDF saved to fallback location: ${file.path}',
          );

          await Share.shareXFiles([
            XFile(file.path),
          ], text: 'Department Report');
          debugPrint('[DepartmentReportPdfService] PDF shared successfully');
          return file.path;
        } catch (fallbackError) {
          debugPrint(
            '[DepartmentReportPdfService] Error in fallback save: $fallbackError',
          );
          throw Exception('Failed to save PDF: $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[DepartmentReportPdfService] Error generating PDF: $e');
      debugPrint('[DepartmentReportPdfService] Stack trace: $stackTrace');
      throw Exception('Failed to generate PDF report: $e');
    }
  }

  /// Generate summary PDF for all department reports
  static Future<String?> generateSummaryPdf(String departmentId) async {
    try {
      debugPrint(
        '[DepartmentReportPdfService] Generating summary PDF for department: $departmentId',
      );
      final results = await Future.wait([
        DepartmentService.getDepartmentById(departmentId),
        DepartmentReportService.getAllDepartmentReportsForSummary(departmentId),
      ]);

      final department = results[0] as Map<String, dynamic>;
      final reports = results[1] as List<Map<String, dynamic>>;
      debugPrint(
        '[DepartmentReportPdfService] Found ${reports.length} reports',
      );

      if (reports.isEmpty) {
        throw Exception('No reports found to generate summary');
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            _buildHeader(
              '${department['name'] ?? 'Department'} - Summary Report',
            ),
            pw.SizedBox(height: 20),
            _buildSummaryInfo(department, reports),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),
            ...reports.asMap().entries.map((entry) {
              final index = entry.key;
              final report = entry.value;
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Report ${index + 1}: ${report['title'] ?? 'Untitled'}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Date: ${_formatDate(report['created_at'], format: 'MMM d, yyyy')}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 10),
                  _buildSummarySection(
                    'Objectives',
                    report['defined_objectives'] ?? '',
                  ),
                  pw.SizedBox(height: 8),
                  _buildSummarySection(
                    'Positive Points',
                    report['positive_points'] ?? '',
                  ),
                  pw.SizedBox(height: 8),
                  _buildSummarySection(
                    'Difficulties',
                    report['difficulties_encountered'] ?? '',
                  ),
                  pw.SizedBox(height: 8),
                  _buildSummarySection(
                    'Suggestions',
                    report['suggestions'] ?? '',
                  ),
                  if (index < reports.length - 1) ...[
                    pw.SizedBox(height: 20),
                    pw.Divider(),
                    pw.SizedBox(height: 20),
                  ],
                ],
              );
            }),
            pw.SizedBox(height: 30),
            _buildSummaryFooter(reports),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      debugPrint(
        '[DepartmentReportPdfService] Summary PDF generated, size: ${pdfBytes.length} bytes',
      );

      final fileName =
          'department_summary_${departmentId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Let user choose where to save the PDF
      try {
        debugPrint(
          '[DepartmentReportPdfService] Prompting user to select save location for summary...',
        );
        final result = await FilePicker.platform.saveFile(
          fileName: fileName,
          allowedExtensions: ['pdf'],
          bytes: pdfBytes,
          type: FileType.custom,
          dialogTitle: 'Save Summary Report',
        );

        if (result != null) {
          debugPrint(
            '[DepartmentReportPdfService] Summary PDF saved to user-selected location: $result',
          );

          // On mobile, also offer to share the file
          if (Platform.isAndroid || Platform.isIOS) {
            try {
              final file = File(result);
              if (await file.exists()) {
                await Share.shareXFiles([
                  XFile(result),
                ], text: 'Summary Report');
                debugPrint(
                  '[DepartmentReportPdfService] Summary PDF shared successfully',
                );
              }
            } catch (e) {
              debugPrint(
                '[DepartmentReportPdfService] Error sharing summary file: $e',
              );
              // Don't throw - file was saved successfully, sharing is optional
            }
          }

          return result;
        } else {
          debugPrint(
            '[DepartmentReportPdfService] User cancelled summary file save dialog',
          );
          throw Exception('Save cancelled by user');
        }
      } catch (e) {
        debugPrint(
          '[DepartmentReportPdfService] Error with FilePicker.saveFile for summary: $e',
        );

        // Fallback: Save to default location and share
        try {
          debugPrint(
            '[DepartmentReportPdfService] Falling back to default save location for summary...',
          );
          final directory = Platform.isAndroid || Platform.isIOS
              ? await getTemporaryDirectory()
              : await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(pdfBytes);
          debugPrint(
            '[DepartmentReportPdfService] Summary PDF saved to fallback location: ${file.path}',
          );

          await Share.shareXFiles([XFile(file.path)], text: 'Summary Report');
          debugPrint(
            '[DepartmentReportPdfService] Summary PDF shared successfully',
          );
          return file.path;
        } catch (fallbackError) {
          debugPrint(
            '[DepartmentReportPdfService] Error in fallback save for summary: $fallbackError',
          );
          throw Exception('Failed to save summary PDF: $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[DepartmentReportPdfService] Error generating summary PDF: $e',
      );
      debugPrint('[DepartmentReportPdfService] Stack trace: $stackTrace');
      throw Exception('Failed to generate summary PDF: $e');
    }
  }

  static pw.Widget _buildHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Generated on ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildReportInfo(Map<String, dynamic> report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Report: ${report['title'] ?? 'Untitled'}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Created: ${DateFormat('MMMM d, yyyy').format(DateTime.parse(report['created_at']))}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSection(String title, String content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Text(content, style: const pw.TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  static pw.Widget _buildSummarySection(String title, String content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(content, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildSummaryInfo(
    Map<String, dynamic> department,
    List<Map<String, dynamic>> reports,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Department: ${department['name'] ?? 'Unknown'}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Total Reports: ${reports.length}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Date Range: ${_formatDate(reports.first['created_at'], format: 'MMM d, yyyy')} - ${_formatDate(reports.last['created_at'], format: 'MMM d, yyyy')}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(Map<String, dynamic> report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        'Report ID: ${report['id']}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  static pw.Widget _buildSummaryFooter(List<Map<String, dynamic>> reports) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        'Summary of ${reports.length} report(s)',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  /// Helper function to safely format dates
  static String _formatDate(
    dynamic dateValue, {
    String format = 'MMMM d, yyyy',
  }) {
    try {
      if (dateValue == null) return 'Unknown date';

      DateTime date;
      if (dateValue is DateTime) {
        date = dateValue;
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Invalid date';
      }

      return DateFormat(format).format(date);
    } catch (e) {
      debugPrint('[DepartmentReportPdfService] Error formatting date: $e');
      return 'Invalid date';
    }
  }
}
