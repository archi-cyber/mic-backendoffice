import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'new_comer_service.dart';

class NewComerReportPdfService {
  static Future<String?> generateReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final report = await NewComerService.getReport(
      startDate: startDate,
      endDate: endDate,
    );
    final records =
        List<Map<String, dynamic>>.from(report['records'] as List? ?? const []);
    final statusSummary = Map<String, dynamic>.from(
      report['status_summary'] as Map? ?? const {},
    );
    final intentionSummary = Map<String, dynamic>.from(
      report['intention_outcome_summary'] as Map? ?? const {},
    );

    final pdf = pw.Document();
    final df = DateFormat('MMM d, yyyy');
    final generatedAt = DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now());
    final periodText = startDate != null || endDate != null
        ? '${startDate != null ? df.format(startDate) : 'Start'} - ${endDate != null ? df.format(endDate) : 'End'}'
        : 'All records';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            'New Comers Outcomes Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Period: $periodText', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Generated: $generatedAt', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 14),
          _buildTopSummary(statusSummary, records.length),
          pw.SizedBox(height: 14),
          _buildIntentionOutcomeTable(intentionSummary),
          pw.SizedBox(height: 14),
          _buildIntentionOutcomeBars(intentionSummary),
          pw.SizedBox(height: 14),
          _buildRecordsTable(records),
        ],
      ),
    );

    return _savePdf(pdf, 'new_comers_report');
  }

  static pw.Widget _buildTopSummary(Map<String, dynamic> statusSummary, int total) {
    final newComers = statusSummary['new_comer'] ?? 0;
    final members = statusSummary['member'] ?? 0;
    final visitors = statusSummary['visitor'] ?? 0;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _stat('Total', '$total'),
          _stat('Current New Comers', '$newComers'),
          _stat('Became Members', '$members'),
          _stat('Became Visitors', '$visitors'),
        ],
      ),
    );
  }

  static pw.Widget _stat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  static pw.Widget _buildIntentionOutcomeTable(
    Map<String, dynamic> intentionSummary,
  ) {
    int getCount(String intention, String status) {
      final map = intentionSummary[intention] as Map?;
      return (map?[status] as int?) ?? 0;
    }

    pw.Widget cell(String text, {bool header = false, pw.TextAlign align = pw.TextAlign.left}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Intention vs Current Outcome',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                cell('Initial Intention', header: true),
                cell('Now Member', header: true, align: pw.TextAlign.center),
                cell('Still New Comer', header: true, align: pw.TextAlign.center),
                cell('Now Visitor', header: true, align: pw.TextAlign.center),
                cell('Total', header: true, align: pw.TextAlign.center),
              ],
            ),
            ...[
              ('wants_to_stay', 'Wants to stay'),
              ('does_not_know_yet', 'Does not know yet'),
              ('just_passing', 'Just passing'),
            ].map((row) {
              final m = getCount(row.$1, 'member');
              final n = getCount(row.$1, 'new_comer');
              final v = getCount(row.$1, 'visitor');
              return pw.TableRow(
                children: [
                  cell(row.$2),
                  cell('$m', align: pw.TextAlign.center),
                  cell('$n', align: pw.TextAlign.center),
                  cell('$v', align: pw.TextAlign.center),
                  cell('${m + n + v}', align: pw.TextAlign.center),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildIntentionOutcomeBars(
    Map<String, dynamic> intentionSummary,
  ) {
    int getCount(String intention, String status) {
      final map = intentionSummary[intention] as Map?;
      return (map?[status] as int?) ?? 0;
    }

    final intentions = [
      ('wants_to_stay', 'Wants to stay'),
      ('does_not_know_yet', 'Does not know yet'),
      ('just_passing', 'Just passing'),
    ];
    final maxVal = intentions
        .map((i) => getCount(i.$1, 'member') + getCount(i.$1, 'new_comer') + getCount(i.$1, 'visitor'))
        .fold<int>(1, (a, b) => a > b ? a : b);

    pw.Widget barLine(String title, int value, PdfColor color) {
      final width = (value / maxVal) * 260;
      return pw.Row(
        children: [
          pw.SizedBox(width: 110, child: pw.Text(title, style: const pw.TextStyle(fontSize: 8))),
          pw.Container(width: width, height: 8, color: color),
          pw.SizedBox(width: 8),
          pw.Text('$value', style: const pw.TextStyle(fontSize: 8)),
        ],
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Outcome Graphs by Intention',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...intentions.map((i) {
            final member = getCount(i.$1, 'member');
            final newcomer = getCount(i.$1, 'new_comer');
            final visitor = getCount(i.$1, 'visitor');
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(i.$2, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  barLine('-> Member', member, PdfColors.green),
                  pw.SizedBox(height: 2),
                  barLine('-> Still New Comer', newcomer, PdfColors.blue),
                  pw.SizedBox(height: 2),
                  barLine('-> Visitor', visitor, PdfColors.orange),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildRecordsTable(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return pw.Text('No records in selected period.');
    }

    pw.Widget cell(String text, {bool header = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    final rows = records.take(150).toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detailed Records',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.4),
            2: const pw.FlexColumnWidth(1.4),
            3: const pw.FlexColumnWidth(1.4),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                cell('Name', header: true),
                cell('Join Date', header: true),
                cell('Intention', header: true),
                cell('Current Status', header: true),
              ],
            ),
            ...rows.map((record) {
              final name =
                  '${record['first_name'] ?? ''} ${record['last_name'] ?? ''}'.trim();
              final intention =
                  (record['newcomer_intention'] ?? '-').toString().replaceAll('_', ' ');
              final status =
                  (record['current_status'] ?? '-').toString().replaceAll('_', ' ');
              return pw.TableRow(
                children: [
                  cell(name.isEmpty ? 'Unknown' : name),
                  cell(record['newcomer_join_date']?.toString() ?? '-'),
                  cell(intention),
                  cell(status),
                ],
              );
            }),
          ],
        ),
        if (records.length > rows.length)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Text(
              'Showing first ${rows.length} of ${records.length} records.',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
      ],
    );
  }

  static Future<String?> _savePdf(pw.Document pdf, String fileName) async {
    final bytes = await pdf.save();
    final result = await FilePicker.platform.saveFile(
      fileName: '$fileName.pdf',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) return result;

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName.pdf');
    await file.writeAsBytes(bytes);
    if (Platform.isAndroid || Platform.isIOS) {
      await Share.shareXFiles([XFile(file.path)], text: 'New Comers Report');
    }
    return file.path;
  }
}
