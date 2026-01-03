import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'finance_service.dart';
import '../config/app_config.dart';

/// Service for generating finance reports as PDF
class FinancePdfService {
  /// Generate a PDF report of all finance records
  /// Parameters:
  /// - fromDate: Optional start date filter
  /// - toDate: Optional end date filter
  /// Returns: Path to the generated PDF file
  static Future<String> generateFinanceReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Fetch all giving records
      final records = await FinanceService.getAllGivingRecords(
        fromDate: fromDate,
        toDate: toDate,
      );

      // Create PDF document
      final pdf = pw.Document();

      // Format dates for display
      final dateFormat = DateFormat('MMM dd, yyyy');
      final dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');
      final periodText = fromDate != null && toDate != null
          ? '${dateFormat.format(fromDate)} - ${dateFormat.format(toDate)}'
          : fromDate != null
              ? 'From ${dateFormat.format(fromDate)}'
              : toDate != null
                  ? 'Until ${dateFormat.format(toDate)}'
                  : 'All Records';

      // Calculate statistics
      double totalIncome = 0.0;
      double totalExpenses = 0.0;
      final tagTotals = <String, double>{};
      final typeTotals = <String, double>{};

      for (final record in records) {
        final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
        final tag = record['tag']?.toString() ?? 'other';
        final type = record['type']?.toString() ?? 'unknown';

        if (amount > 0) {
          totalIncome += amount;
        } else {
          totalExpenses += amount.abs();
        }

        tagTotals[tag] = (tagTotals[tag] ?? 0.0) + amount.abs();
        typeTotals[type] = (typeTotals[type] ?? 0.0) + amount.abs();
      }

      final netBalance = totalIncome - totalExpenses;

      // Build PDF content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Finance Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      AppConfig.appName,
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Period and generation info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Period: $periodText',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Generated: ${dateTimeFormat.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Summary Statistics
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Summary',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Records:', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text(
                          '${records.length}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Income:', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text(
                          '\$${totalIncome.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Expenses:', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text(
                          '\$${totalExpenses.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Net Balance:',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '\$${netBalance.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: netBalance >= 0 ? PdfColors.green700 : PdfColors.red700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Tag breakdown
              if (tagTotals.isNotEmpty) ...[
                pw.Text(
                  'Breakdown by Category',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Category',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Amount',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    ...tagTotals.entries.map((entry) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(_formatTag(entry.key)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '\$${entry.value.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],

              // Transactions Table
              pw.Text(
                'Transactions',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Giver Name',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Date',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Type',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Category',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Amount',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...records.map((record) {
                    final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
                    final isExpense = amount < 0;
                    final dateStr = record['date']?.toString() ?? '';
                    String formattedDate = dateStr;
                    try {
                      if (dateStr.isNotEmpty) {
                        final date = DateTime.parse(dateStr);
                        formattedDate = dateFormat.format(date);
                      }
                    } catch (e) {
                      // Keep original string if parsing fails
                    }

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            record['giver_name']?.toString() ?? 'Unknown',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            formattedDate,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            record['type']?.toString().toUpperCase() ?? 'N/A',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            _formatTag(record['tag']?.toString() ?? 'other'),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '\$${amount.abs().toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: isExpense ? PdfColors.red700 : PdfColors.green700,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ];
          },
        ),
      );

      // Save PDF to temporary directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/finance_report_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());

      return file.path;
    } catch (e) {
      throw Exception('Failed to generate finance report: $e');
    }
  }

  /// Generate and save the PDF report to a user-selected location
  static Future<void> generateAndSaveReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Generate PDF bytes
      final pdfBytes = await _generateFinanceReportBytes(
        fromDate: fromDate,
        toDate: toDate,
      );

      // Create filename with date range
      final dateFormat = DateFormat('yyyyMMdd');
      String fileName = 'finance_report';
      if (fromDate != null && toDate != null) {
        fileName = 'finance_report_${dateFormat.format(fromDate)}_${dateFormat.format(toDate)}';
      } else if (fromDate != null) {
        fileName = 'finance_report_from_${dateFormat.format(fromDate)}';
      } else if (toDate != null) {
        fileName = 'finance_report_until_${dateFormat.format(toDate)}';
      } else {
        fileName = 'finance_report_all';
      }

      // Let user choose save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Finance Report',
        fileName: '$fileName.pdf',
        bytes: pdfBytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) {
        // User cancelled
        return;
      }

      // File is already saved by FilePicker, no need to write again
    } catch (e) {
      throw Exception('Failed to save finance report: $e');
    }
  }

  /// Generate and share the PDF report
  static Future<void> generateAndShareReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final pdfPath = await generateFinanceReport(
        fromDate: fromDate,
        toDate: toDate,
      );

      // Share the PDF file
      await Share.shareXFiles(
        [XFile(pdfPath)],
        subject: 'Finance Report - ${AppConfig.appName}',
        text: 'Finance Report',
      );
    } catch (e) {
      throw Exception('Failed to generate and share finance report: $e');
    }
  }

  /// Generate PDF report and return as bytes (internal method)
  static Future<Uint8List> _generateFinanceReportBytes({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Fetch all giving records
      final records = await FinanceService.getAllGivingRecords(
        fromDate: fromDate,
        toDate: toDate,
      );

      // Create PDF document
      final pdf = pw.Document();

      // Format dates for display
      final dateFormat = DateFormat('MMM dd, yyyy');
      final dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');
      final periodText = fromDate != null && toDate != null
          ? '${dateFormat.format(fromDate)} - ${dateFormat.format(toDate)}'
          : fromDate != null
              ? 'From ${dateFormat.format(fromDate)}'
              : toDate != null
                  ? 'Until ${dateFormat.format(toDate)}'
                  : 'All Records';

      // Calculate statistics
      double totalIncome = 0.0;
      double totalExpenses = 0.0;
      final tagTotals = <String, double>{};
      final typeTotals = <String, double>{};

      for (final record in records) {
        final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
        final tag = record['tag']?.toString() ?? 'other';
        final type = record['type']?.toString() ?? 'unknown';

        if (amount > 0) {
          totalIncome += amount;
        } else {
          totalExpenses += amount.abs();
        }

        tagTotals[tag] = (tagTotals[tag] ?? 0.0) + amount.abs();
        typeTotals[type] = (typeTotals[type] ?? 0.0) + amount.abs();
      }

      final netBalance = totalIncome - totalExpenses;

      // Build PDF content (same as generateFinanceReport)
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Finance Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      AppConfig.appName,
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Period and generation info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Period: $periodText',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Generated: ${dateTimeFormat.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Summary Statistics
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Summary',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Records:', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text(
                          '${records.length}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Income:', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text(
                          '\$${totalIncome.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Expenses:', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text(
                          '\$${totalExpenses.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Net Balance:',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '\$${netBalance.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: netBalance >= 0 ? PdfColors.green700 : PdfColors.red700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Tag breakdown
              if (tagTotals.isNotEmpty) ...[
                pw.Text(
                  'Breakdown by Category',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Category',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Amount',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    ...tagTotals.entries.map((entry) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(_formatTag(entry.key)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '\$${entry.value.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],

              // Transactions Table
              pw.Text(
                'Transactions',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Giver Name',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Date',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Type',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Category',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Amount',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...records.map((record) {
                    final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
                    final isExpense = amount < 0;
                    final dateStr = record['date']?.toString() ?? '';
                    String formattedDate = dateStr;
                    try {
                      if (dateStr.isNotEmpty) {
                        final date = DateTime.parse(dateStr);
                        formattedDate = dateFormat.format(date);
                      }
                    } catch (e) {
                      // Keep original string if parsing fails
                    }

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            record['giver_name']?.toString() ?? 'Unknown',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            formattedDate,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            record['type']?.toString().toUpperCase() ?? 'N/A',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            _formatTag(record['tag']?.toString() ?? 'other'),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '\$${amount.abs().toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: isExpense ? PdfColors.red700 : PdfColors.green700,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      // Return PDF bytes
      return await pdf.save();
    } catch (e) {
      throw Exception('Failed to generate finance report: $e');
    }
  }

  /// Format tag for display
  static String _formatTag(String tag) {
    switch (tag.toLowerCase()) {
      case 'construction':
        return 'Construction';
      case 'special_op':
        return 'Special Operation';
      case 'tithe':
        return 'Tithe';
      case 'offering':
        return 'Offering';
      case 'gift':
        return 'Gift';
      case 'other':
        return 'Other';
      default:
        return tag;
    }
  }
}

