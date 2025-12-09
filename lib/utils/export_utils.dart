import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Utility class for exporting data to CSV
class ExportUtils {
  /// Export member report to CSV
  static Future<void> exportMemberReportToCSV(
    Map<String, dynamic> report,
  ) async {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Member Report');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('');

    // Attendance section
    final attendance = report['attendance'] as Map<String, dynamic>?;
    if (attendance != null) {
      buffer.writeln('Attendance Summary');
      buffer.writeln('Total: ${attendance['total'] ?? 0}');
      buffer.writeln('');
      buffer.writeln('Date,Status,Notes');

      final records = attendance['records'] as List? ?? [];
      for (final record in records) {
        buffer.writeln(
          '${record['created_at'] ?? ''},'
          '${record['status'] ?? ''},'
          '${record['notes'] ?? ''}',
        );
      }
      buffer.writeln('');
    }

    // Giving section
    final giving = report['giving'] as Map<String, dynamic>?;
    if (giving != null) {
      buffer.writeln('Giving Summary');
      buffer.writeln(
        'Total: \$${giving['total']?.toStringAsFixed(2) ?? '0.00'}',
      );
      buffer.writeln('');
      buffer.writeln('Date,Amount,Type,Notes');

      final records = giving['records'] as List? ?? [];
      for (final record in records) {
        buffer.writeln(
          '${record['date'] ?? ''},'
          '\$${record['amount']?.toStringAsFixed(2) ?? '0.00'},'
          '${record['type'] ?? ''},'
          '${record['notes'] ?? ''}',
        );
      }
    }

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/member_report_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(buffer.toString());

    // Share file
    await Share.shareXFiles([XFile(file.path)], text: 'Member Report');
  }

  /// Export class report to CSV
  static Future<void> exportClassReportToCSV(
    Map<String, dynamic> report,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln('Class Report');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('');

    final sessions = report['sessions'] as Map<String, dynamic>?;
    if (sessions != null) {
      buffer.writeln('Sessions Summary');
      buffer.writeln('Total Sessions: ${sessions['total'] ?? 0}');
      buffer.writeln('');
    }

    final attendance = report['attendance'] as Map<String, dynamic>?;
    if (attendance != null) {
      buffer.writeln('Attendance Summary');
      buffer.writeln('Total Attendance: ${attendance['total'] ?? 0}');
      buffer.writeln('Unique Members: ${attendance['unique_members'] ?? 0}');
      buffer.writeln('');
      buffer.writeln('Session ID,Member ID,Status,Date');

      final records = attendance['records'] as List? ?? [];
      for (final record in records) {
        buffer.writeln(
          '${record['session_id'] ?? ''},'
          '${record['member_id'] ?? ''},'
          '${record['status'] ?? ''},'
          '${record['created_at'] ?? ''}',
        );
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/class_report_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(file.path)], text: 'Class Report');
  }
}
