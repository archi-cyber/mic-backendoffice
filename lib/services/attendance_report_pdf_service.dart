import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../core/localization/app_localizations.dart';
import 'church_attendance_service.dart';
import 'church_attendance_report_builder.dart';
import 'member_service.dart';
import 'visitor_service.dart';
import 'sunday_school_attendance_service.dart';

/// Service for generating PDF reports for attendance
class AttendanceReportPdfService {
  /// Generate PDF report for church attendance
  static Future<String?> generateChurchAttendanceReport({
    DateTime? startDate,
    DateTime? endDate,
    String? serviceType,
    required AppLocalizations localizations,
  }) async {
    try {
      debugPrint(
        '[AttendanceReportPdfService] Generating church attendance report',
      );

      final allActiveMembers = await MemberService.getMembers(
        filters: {'is_active': true},
        orderBy: 'last_name',
        ascending: true,
      );

      // Get all services in the date range
      final services = await ChurchAttendanceService.getAllServices(
        startDate: startDate,
        endDate: endDate,
        limit: 1000,
      );

      // Filter by service type if specified
      List<Map<String, dynamic>> filteredServices = services;
      if (serviceType != null) {
        filteredServices = services
            .where((s) => s['service_type'] == serviceType)
            .toList();
      }

      if (filteredServices.isEmpty) {
        throw Exception('No attendance records found for the selected period');
      }

      // Get detailed attendance and visitors for each service
      final visitorsByDate = <String, List<Map<String, dynamic>>>{};
      final List<Map<String, dynamic>> detailedServices = [];
      for (final service in filteredServices) {
        final serviceDate = DateTime.parse(service['service_date'] as String);
        final serviceType = service['service_type'] as String;
        final dateKey = service['service_date'] as String;

        if (!visitorsByDate.containsKey(dateKey)) {
          try {
            visitorsByDate[dateKey] = await VisitorService.getVisitors(
              fromDate: serviceDate,
              toDate: serviceDate,
            );
          } catch (e) {
            debugPrint(
              '[AttendanceReportPdfService] Error loading visitors for $dateKey: $e',
            );
            visitorsByDate[dateKey] = [];
          }
        }

        final visitorsForService = visitorsByDate[dateKey]!
            .where((visitor) {
              final st = visitor['service_type']?.toString();
              if (st == null || st.isEmpty) return true;
              return st == serviceType;
            })
            .toList();

        final attendance = await ChurchAttendanceService.getServiceAttendance(
          serviceDate: serviceDate,
          serviceType: serviceType,
        );
        detailedServices.add({
          ...service,
          'attendance': attendance,
          'visitors': visitorsForService,
        });
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => [
            _buildChurchAttendanceHeader(
              localizations,
              startDate,
              endDate,
              serviceType,
            ),
            pw.SizedBox(height: 12),
            ...ChurchAttendanceReportBuilder.buildMonthlySections(
              detailedServices,
              allMembers: allActiveMembers,
              localizations: localizations,
            ),
          ],
        ),
      );

      return await _savePdf(pdf, 'church_attendance_report');
    } catch (e) {
      debugPrint(
        '[AttendanceReportPdfService] Error generating church attendance report: $e',
      );
      rethrow;
    }
  }

  /// Generate PDF report for Sunday school attendance
  static Future<String?> generateSundaySchoolReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint(
        '[AttendanceReportPdfService] Generating Sunday school attendance report',
      );

      // Get all sessions in the date range
      final sessions = await SundaySchoolAttendanceService.getAllSessions(
        startDate: startDate,
        endDate: endDate,
        limit: 1000,
      );

      if (sessions.isEmpty) {
        throw Exception('No attendance records found for the selected period');
      }

      // Get detailed attendance for each session
      final List<Map<String, dynamic>> detailedSessions = [];
      for (final session in sessions) {
        final attendance =
            await SundaySchoolAttendanceService.getDateAttendance(
              attendanceDate: DateTime.parse(
                session['attendance_date'] as String,
              ),
            );
        detailedSessions.add({...session, 'attendance': attendance});
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            _buildSundaySchoolHeader(startDate, endDate),
            pw.SizedBox(height: 20),
            ..._buildSundaySchoolContent(detailedSessions),
          ],
        ),
      );

      return await _savePdf(pdf, 'sunday_school_attendance_report');
    } catch (e) {
      debugPrint(
        '[AttendanceReportPdfService] Error generating Sunday school report: $e',
      );
      rethrow;
    }
  }

  /// Generate a single-service PDF containing members/visitors marked absent,
  /// along with their contact info (phone, email) and WhatsApp deep-link.
  static Future<String?> generateChurchAttendanceAbsentPeopleReport({
    required DateTime serviceDate,
    required String serviceType, // 'sunday' or 'wednesday'
    required AppLocalizations localizations,
  }) async {
    try {
      final localeTag = localizations.locale.toString();
      final df = DateFormat.yMMMd(localeTag);

      final allActiveMembers = await MemberService.getMembers(
        filters: {'is_active': true},
        orderBy: 'last_name',
        ascending: true,
      );

      final attendance = await ChurchAttendanceService.getServiceAttendance(
        serviceDate: serviceDate,
        serviceType: serviceType,
      );

      // "Absent" list = active members that are not onsite/online for this service.
      final attendedMemberIds = attendance
          .where((r) {
            final at = r['attendance_type']?.toString();
            return at == 'onsite' || at == 'online';
          })
          .map((r) => r['member_id']?.toString())
          .whereType<String>()
          .toSet();

      final absentMembers = allActiveMembers.where((m) {
        final id = m['id']?.toString();
        if (id == null || id.isEmpty) return false;
        return !attendedMemberIds.contains(id);
      }).toList();

      final visitors = await VisitorService.getVisitors(
        fromDate: serviceDate,
        toDate: serviceDate,
        limit: 1000,
      );

      // Match the UI logic:
      // - visitor.service_type is null/empty => match any service type
      // - otherwise it must equal the selected serviceType
      final visitorsForService = visitors.where((v) {
        final st = v['service_type']?.toString();
        if (st == null || st.isEmpty) return true;
        return st == serviceType;
      }).toList();

      // "Absent" visitors = visitors logged for this service that are not onsite/online.
      final absentVisitors = visitorsForService.where((v) {
        final at = v['attendance_type']?.toString();
        return at != 'onsite' && at != 'online';
      }).toList();

      String? whatsappUrlFromPhone(dynamic phone) {
        final raw = phone?.toString() ?? '';
        if (raw.trim().isEmpty) return null;
        final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isEmpty) return null;
        return 'https://wa.me/$digits';
      }

      String formatName(Map<String, dynamic> row) {
        final first = row['first_name']?.toString().trim() ?? '';
        final last = row['last_name']?.toString().trim() ?? '';
        final name = '$first $last'.trim();
        return name.isEmpty ? row['id']?.toString() ?? '-' : name;
      }

      // Local helper for language-specific label without adding new localization keys.
      String contextLabel(AppLocalizations l10n, String en, String other) {
        final code = l10n.locale.languageCode;
        if (code == 'fr' || code == 'es') return other; // best-effort
        return en;
      }

      final serviceLabel = serviceType == 'sunday'
          ? contextLabel(localizations, 'Sunday service', 'Service dominical')
          : contextLabel(
              localizations,
              'Wednesday service',
              'Service du mercredi',
            );

      pw.Widget cell(String t, {pw.TextStyle? style, pw.Alignment align = pw.Alignment.centerLeft}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(2),
          child: pw.Align(
            alignment: align,
            child: pw.Text(t, style: style),
          ),
        );
      }

      final headerStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
      final baseStyle = const pw.TextStyle(fontSize: 9);

      final rows = <pw.TableRow>[
        pw.TableRow(
          children: [
            cell(localizations.churchAttendance, style: headerStyle),
            cell('Type', style: headerStyle),
            cell('Phone', style: headerStyle),
            cell('Email', style: headerStyle),
            cell('WhatsApp', style: headerStyle),
          ],
        ),
      ];

      for (final m in absentMembers) {
        final phone = m['phone'];
        final email = m['email']?.toString();
        rows.add(
          pw.TableRow(
            children: [
              cell(formatName(m), style: baseStyle),
              cell('Member', style: baseStyle),
              cell(phone?.toString() ?? '-', style: baseStyle),
              cell(email != null && email.isNotEmpty ? email : '-', style: baseStyle),
              cell(whatsappUrlFromPhone(phone) ?? '-', style: baseStyle),
            ],
          ),
        );
      }

      for (final v in absentVisitors) {
        final phone = v['phone'];
        final email = v['email']?.toString();
        rows.add(
          pw.TableRow(
            children: [
              cell(formatName(v), style: baseStyle),
              cell('Visitor', style: baseStyle),
              cell(phone?.toString() ?? '-', style: baseStyle),
              cell(email != null && email.isNotEmpty ? email : '-', style: baseStyle),
              cell(whatsappUrlFromPhone(phone) ?? '-', style: baseStyle),
            ],
          ),
        );
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => [
            pw.Text(
              '${localizations.churchAttendance} - Absent people',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              '$serviceLabel - ${df.format(serviceDate)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.6),
                1: pw.FlexColumnWidth(0.6),
                2: pw.FlexColumnWidth(1.0),
                3: pw.FlexColumnWidth(1.2),
                4: pw.FlexColumnWidth(1.4),
              },
              children: rows,
            ),
          ],
        ),
      );

      return await _savePdf(pdf, 'church_attendance_absent_people_${serviceDate.toIso8601String().split('T').first}_${serviceType}');
    } catch (e) {
      debugPrint(
        '[AttendanceReportPdfService] Error generating absent people PDF: $e',
      );
      rethrow;
    }
  }

  static pw.Widget _buildChurchAttendanceHeader(
    AppLocalizations l10n,
    DateTime? startDate,
    DateTime? endDate,
    String? serviceType,
  ) {
    final localeTag = l10n.locale.toString();
    final df = DateFormat.yMMMd(localeTag);
    final dft = DateFormat.yMMMd(localeTag).add_jm();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          l10n.churchAttendanceReportPdfTitle,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          '${l10n.churchAttendanceReportPdfGenerated}: ${dft.format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        if (startDate != null || endDate != null) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            '${l10n.churchAttendanceReportPdfPeriod}: ${startDate != null ? df.format(startDate) : '—'} - ${endDate != null ? df.format(endDate) : '—'}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
        if (serviceType != null) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            '${l10n.churchAttendanceReportPdfServiceFilter}: ${serviceType == 'sunday' ? l10n.churchAttendanceReportPdfSundayService : l10n.churchAttendanceReportPdfWednesdayService}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildSundaySchoolHeader(
    DateTime? startDate,
    DateTime? endDate,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Sunday School Attendance Report',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Generated: ${DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        if (startDate != null || endDate != null) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            'Period: ${startDate != null ? DateFormat('MMM d, yyyy').format(startDate) : 'Start'} - ${endDate != null ? DateFormat('MMM d, yyyy').format(endDate) : 'End'}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ],
    );
  }

  static List<pw.Widget> _buildSundaySchoolContent(
    List<Map<String, dynamic>> sessions,
  ) {
    final widgets = <pw.Widget>[];

    // Summary statistics
    int totalSessions = sessions.length;
    int totalAttendance = sessions.fold<int>(
      0,
      (sum, session) => sum + (session['attendance_count'] as int? ?? 0),
    );
    final avgAttendance = totalSessions > 0
        ? totalAttendance / totalSessions
        : 0;

    widgets.add(
      pw.Container(
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
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildStatBox('Total Sessions', totalSessions.toString()),
                _buildStatBox('Total Attendance', totalAttendance.toString()),
                _buildStatBox('Average', avgAttendance.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
    );

    widgets.add(pw.SizedBox(height: 20));

    // Sessions list
    for (final session in sessions) {
      final sessionDate = DateTime.parse(session['attendance_date'] as String);
      final attendance = session['attendance'] as List<Map<String, dynamic>>;
      final attendanceCount = session['attendance_count'] as int? ?? 0;

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 15),
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Sunday School',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    DateFormat('MMM d, yyyy').format(sessionDate),
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Attendance: $attendanceCount children',
                style: const pw.TextStyle(fontSize: 11),
              ),
              if (attendance.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  'Attendees:',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                ...attendance.map((record) {
                  final member = record['member'] as Map<String, dynamic>?;
                  final firstName = member?['first_name'] ?? 'Unknown';
                  final lastName = member?['last_name'] ?? '';
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 10, bottom: 3),
                    child: pw.Text(
                      '• $firstName $lastName',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      );
    }

    return widgets;
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

  static Future<String?> _savePdf(pw.Document pdf, String fileName) async {
    final bytes = await pdf.save();
    final pdfFileName = '$fileName.pdf';

    try {
      final result = await FilePicker.platform.saveFile(
        fileName: pdfFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        dialogTitle: 'Save Attendance Report',
      );

      if (result != null) {
        debugPrint(
          '[AttendanceReportPdfService] PDF saved to user-selected location: $result',
        );
        return result;
      }

      debugPrint(
        '[AttendanceReportPdfService] User cancelled file save dialog',
      );
    } catch (e) {
      debugPrint(
        '[AttendanceReportPdfService] FilePicker.saveFile unavailable: $e',
      );
    }

    return _savePdfToFallbackLocation(bytes, pdfFileName);
  }

  static Future<String> _savePdfToFallbackLocation(
    List<int> bytes,
    String fileName,
  ) async {
    final directory = Platform.isAndroid || Platform.isIOS
        ? await getTemporaryDirectory()
        : await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    debugPrint(
      '[AttendanceReportPdfService] PDF saved to fallback location: ${file.path}',
    );

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Attendance Report',
        );
      } catch (e) {
        debugPrint('[AttendanceReportPdfService] Error sharing PDF: $e');
      }
    }

    return file.path;
  }
}
