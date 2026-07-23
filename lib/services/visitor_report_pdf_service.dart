import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import 'supabase_service.dart';
import 'visitor_service.dart';

/// Service for generating PDF reports of church visitors.
class VisitorReportPdfService {
  static Future<String?> generateReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final visitors = await _fetchVisitorsWithServiceName(
      startDate: startDate,
      endDate: endDate,
    );

    if (visitors.isEmpty) {
      throw Exception('No visitors found for the selected period');
    }

    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM d, yyyy');
    final generatedAt =
        DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now());
    final periodText = startDate != null || endDate != null
        ? '${startDate != null ? dateFormat.format(startDate) : 'Start'} - ${endDate != null ? dateFormat.format(endDate) : 'End'}'
        : 'All records';

    final summary = _buildSummary(visitors);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Visitors Report',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                AppConfig.appName,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text('Period: $periodText', style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            'Generated: $generatedAt',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 14),
          summary,
          pw.SizedBox(height: 14),
          _buildVisitorsTable(visitors, dateFormat),
        ],
      ),
    );

    return _savePdf(pdf, 'visitors_report');
  }

  static Future<List<Map<String, dynamic>>> _fetchVisitorsWithServiceName({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = SupabaseService.client
          .from('visitors')
          .select('*, church_service:church_services(name)');

      if (startDate != null) {
        query = query.gte(
          'visit_date',
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
        );
      }
      if (endDate != null) {
        query = query.lte(
          'visit_date',
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
        );
      }

      final response = await query
          .order('visit_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(5000);

      return List<Map<String, dynamic>>.from(response)
          .where((r) => r['deleted_at'] == null)
          .toList();
    } catch (e) {
      final fallback = await VisitorService.getVisitors(
        fromDate: startDate,
        toDate: endDate,
        limit: 5000,
        orderBy: 'visit_date',
        ascending: false,
      );
      return fallback;
    }
  }

  static pw.Widget _buildSummary(List<Map<String, dynamic>> visitors) {
    final byService = <String, int>{};
    var onsite = 0;
    var online = 0;
    var absent = 0;

    for (final visitor in visitors) {
      final serviceName = _serviceNameFromVisitor(visitor);
      byService[serviceName] = (byService[serviceName] ?? 0) + 1;
      switch (visitor['attendance_type']?.toString()) {
        case 'onsite':
          onsite++;
        case 'online':
          online++;
        case 'absent':
          absent++;
      }
    }

    final serviceStats = byService.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _stat('Total Visitors', '${visitors.length}'),
              _stat('On-site', '$onsite'),
              _stat('Online', '$online'),
              _stat('Absent', '$absent'),
            ],
          ),
          if (serviceStats.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 12,
              runSpacing: 6,
              children: serviceStats
                  .map((entry) => _stat(entry.key, '${entry.value}'))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _stat(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  static pw.Widget _buildVisitorsTable(
    List<Map<String, dynamic>> visitors,
    DateFormat dateFormat,
  ) {
    pw.Widget cell(
      String text, {
      bool header = false,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Visitor Records',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.4),
            1: const pw.FlexColumnWidth(1.6),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(0.9),
            4: const pw.FlexColumnWidth(0.8),
            5: const pw.FlexColumnWidth(1.4),
            6: const pw.FlexColumnWidth(1),
            7: const pw.FlexColumnWidth(1.6),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                cell('#', header: true, align: pw.TextAlign.center),
                cell('Name', header: true),
                cell('Visit Date', header: true),
                cell('Service', header: true),
                cell('Attendance', header: true),
                cell('Email', header: true),
                cell('Phone', header: true),
                cell('Notes', header: true),
              ],
            ),
            ...visitors.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final visitor = entry.value;
              final name =
                  '${visitor['first_name'] ?? ''} ${visitor['last_name'] ?? ''}'
                      .trim();
              final visitDate = _parseVisitDate(visitor['visit_date']);
              return pw.TableRow(
                children: [
                  cell('$index', align: pw.TextAlign.center),
                  cell(name.isEmpty ? 'Unknown' : name),
                  cell(
                    visitDate != null ? dateFormat.format(visitDate) : '-',
                  ),
                  cell(_serviceNameFromVisitor(visitor)),
                  cell(
                    _attendanceLabel(visitor['attendance_type']?.toString()),
                  ),
                  cell(visitor['email']?.toString() ?? '-'),
                  cell(visitor['phone']?.toString() ?? '-'),
                  cell(visitor['notes']?.toString() ?? '-'),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static DateTime? _parseVisitDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final datePart = s.split('T').first;
    final parts = datePart.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return DateTime.tryParse(s);
  }

  static String _serviceNameFromVisitor(Map<String, dynamic> visitor) {
    final joined = visitor['church_service'];
    if (joined is Map) {
      final name = joined['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return '-';
  }

  static String _attendanceLabel(String? value) {
    switch (value) {
      case 'onsite':
        return 'On-site';
      case 'online':
        return 'Online';
      case 'absent':
        return 'Absent';
      default:
        return '-';
    }
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
      await Share.shareXFiles([XFile(file.path)], text: 'Visitors Report');
    }
    return file.path;
  }
}
