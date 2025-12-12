import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'member_service.dart';
import 'department_service.dart';
import 'class_service.dart';
import 'event_service.dart';
import 'task_service.dart';
import 'supabase_service.dart';

/// Service for exporting all app data
class DataExportService {
  /// Export all data to JSON
  static Future<File> exportAllDataToJson() async {
    try {
      final data = <String, dynamic>{};

      // Export members
      try {
        final members = await MemberService.getMembers(limit: 10000);
        data['members'] = members;
      } catch (e) {
        data['members'] = [];
        data['members_error'] = e.toString();
      }

      // Export departments
      try {
        final departments = await DepartmentService.getDepartments(
          limit: 10000,
        );
        data['departments'] = departments;
      } catch (e) {
        data['departments'] = [];
        data['departments_error'] = e.toString();
      }

      // Export classes
      try {
        final classes = await ClassService.getClasses(limit: 10000);
        data['classes'] = classes;
      } catch (e) {
        data['classes'] = [];
        data['classes_error'] = e.toString();
      }

      // Export events
      try {
        final events = await EventService.getEvents(limit: 10000);
        data['events'] = events;
      } catch (e) {
        data['events'] = [];
        data['events_error'] = e.toString();
      }

      // Export tasks
      try {
        final tasks = await TaskService.getAllTasks(limit: 10000);
        data['tasks'] = tasks;
      } catch (e) {
        data['tasks'] = [];
        data['tasks_error'] = e.toString();
      }

      // Add metadata
      data['export_metadata'] = {
        'exported_at': DateTime.now().toIso8601String(),
        'exported_by': SupabaseService.currentUser?.id,
        'version': '1.0.0',
      };

      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/mic_backoffice_export_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(jsonString);

      return file;
    } catch (e) {
      throw Exception('Failed to export data: $e');
    }
  }

  /// Export all data and share
  static Future<void> exportAndShareAllData() async {
    try {
      final file = await exportAllDataToJson();
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Church Management System - Data Export');
    } catch (e) {
      throw Exception('Failed to share exported data: $e');
    }
  }

  /// Export members to CSV
  static Future<File> exportMembersToCSV() async {
    try {
      final members = await MemberService.getMembers(limit: 10000);
      final buffer = StringBuffer();

      // Header
      buffer.writeln(
        'ID,First Name,Last Name,Email,Phone,Date of Birth,Role,Is Active,Created At',
      );

      // Data rows
      for (final member in members) {
        buffer.writeln(
          '${member['id']},'
          '${member['first_name'] ?? ''},'
          '${member['last_name'] ?? ''},'
          '${member['email'] ?? ''},'
          '${member['phone'] ?? ''},'
          '${member['date_of_birth'] ?? ''},'
          '${member['role'] ?? ''},'
          '${member['is_active'] ?? false},'
          '${member['created_at'] ?? ''}',
        );
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/members_export_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(buffer.toString());

      return file;
    } catch (e) {
      throw Exception('Failed to export members: $e');
    }
  }

  /// Export all users report (comprehensive)
  static Future<File> exportAllUsersReport() async {
    try {
      final buffer = StringBuffer();

      // Header
      buffer.writeln('Church Management System - All Users Report');
      buffer.writeln('Generated: ${DateTime.now()}');
      buffer.writeln('');
      buffer.writeln('=' * 80);
      buffer.writeln('');

      // Get all members
      final members = await MemberService.getMembers(limit: 10000);

      // Summary
      buffer.writeln('SUMMARY');
      buffer.writeln('-' * 80);
      buffer.writeln('Total Members: ${members.length}');
      final activeMembers = members.where((m) => m['is_active'] == true).length;
      buffer.writeln('Active Members: $activeMembers');
      buffer.writeln('Inactive Members: ${members.length - activeMembers}');

      // Count by role
      final roleCounts = <String, int>{};
      for (final member in members) {
        final role = member['role']?.toString() ?? 'member';
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;
      }
      buffer.writeln('');
      buffer.writeln('Members by Role:');
      roleCounts.forEach((role, count) {
        buffer.writeln('  $role: $count');
      });

      buffer.writeln('');
      buffer.writeln('=' * 80);
      buffer.writeln('');

      // Detailed member list
      buffer.writeln('DETAILED MEMBER LIST');
      buffer.writeln('-' * 80);
      buffer.writeln('');

      for (final member in members) {
        buffer.writeln('Member ID: ${member['id']}');
        buffer.writeln('Name: ${member['first_name']} ${member['last_name']}');
        buffer.writeln('Email: ${member['email'] ?? 'N/A'}');
        buffer.writeln('Phone: ${member['phone'] ?? 'N/A'}');
        buffer.writeln('Date of Birth: ${member['date_of_birth'] ?? 'N/A'}');
        buffer.writeln('Role: ${member['role'] ?? 'member'}');
        buffer.writeln(
          'Status: ${member['is_active'] == true ? 'Active' : 'Inactive'}',
        );
        buffer.writeln('Created: ${member['created_at'] ?? 'N/A'}');
        buffer.writeln('');
        buffer.writeln('-' * 80);
        buffer.writeln('');
      }

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/all_users_report_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(buffer.toString());

      return file;
    } catch (e) {
      throw Exception('Failed to generate users report: $e');
    }
  }

  /// Export all users report and share
  static Future<void> exportAndShareAllUsersReport() async {
    try {
      final file = await exportAllUsersReport();
      await Share.shareXFiles([XFile(file.path)], text: 'All Users Report');
    } catch (e) {
      throw Exception('Failed to share users report: $e');
    }
  }

  /// Export all users report as PDF with file picker
  static Future<String?> exportAllUsersReportAsPdf() async {
    try {
      // Get all members first
      final members = await MemberService.getMembers(limit: 10000);
      final activeMembers = members.where((m) => m['is_active'] == true).length;
      final inactiveMembers = members.length - activeMembers;

      // Count by role
      final roleCounts = <String, int>{};
      for (final member in members) {
        final role = member['role']?.toString() ?? 'member';
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;
      }

      // Create PDF
      final pdf = pw.Document();

      // Add summary page
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Title
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Church Management System',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'All Users Report',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Generated: ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Summary
              pw.Text(
                'SUMMARY',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Total Members: ${members.length}'),
              pw.SizedBox(height: 5),
              pw.Text('Active Members: $activeMembers'),
              pw.SizedBox(height: 5),
              pw.Text('Inactive Members: $inactiveMembers'),
              pw.SizedBox(height: 15),

              // Members by Role
              pw.Text(
                'Members by Role:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              ...roleCounts.entries.map(
                (entry) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 20),
                  child: pw.Text('${entry.key}: ${entry.value}'),
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Detailed member list
              pw.Text(
                'DETAILED MEMBER LIST',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              // Member details
              ...members.map((member) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'ID: ${member['id']}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              'Email: ${member['email'] ?? 'N/A'}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              'Phone: ${member['phone'] ?? 'N/A'}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              'Date of Birth: ${member['date_of_birth'] ?? 'N/A'}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              'Role: ${member['role'] ?? 'member'}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              'Status: ${member['is_active'] == true ? 'Active' : 'Inactive'}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              'Created: ${member['created_at'] ?? 'N/A'}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Divider(),
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();

      // Let user select save location (with bytes for mobile platforms)
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save All Users Report',
        fileName:
            'all_users_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes, // Required for Android and iOS
      );

      if (outputPath == null) {
        return null; // User cancelled
      }

      // On desktop platforms, we may need to write the file ourselves
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final file = File(outputPath);
        await file.writeAsBytes(pdfBytes);
      }

      return outputPath;
    } catch (e) {
      throw Exception('Failed to generate PDF report: $e');
    }
  }

  /// Export all data as JSON with file picker
  static Future<String?> exportAllDataAsJson() async {
    try {
      // Collect all data first
      final data = <String, dynamic>{};

      // Export members
      try {
        final members = await MemberService.getMembers(limit: 10000);
        data['members'] = members;
      } catch (e) {
        data['members'] = [];
        data['members_error'] = e.toString();
      }

      // Export departments
      try {
        final departments = await DepartmentService.getDepartments(
          limit: 10000,
        );
        data['departments'] = departments;
      } catch (e) {
        data['departments'] = [];
        data['departments_error'] = e.toString();
      }

      // Export classes
      try {
        final classes = await ClassService.getClasses(limit: 10000);
        data['classes'] = classes;
      } catch (e) {
        data['classes'] = [];
        data['classes_error'] = e.toString();
      }

      // Export events
      try {
        final events = await EventService.getEvents(limit: 10000);
        data['events'] = events;
      } catch (e) {
        data['events'] = [];
        data['events_error'] = e.toString();
      }

      // Export tasks
      try {
        final tasks = await TaskService.getAllTasks(limit: 10000);
        data['tasks'] = tasks;
      } catch (e) {
        data['tasks'] = [];
        data['tasks_error'] = e.toString();
      }

      // Add metadata
      data['export_metadata'] = {
        'exported_at': DateTime.now().toIso8601String(),
        'exported_by': SupabaseService.currentUser?.id,
        'version': '1.0.0',
      };

      // Convert to JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final jsonBytes = utf8.encode(jsonString);

      // Let user select save location (with bytes for mobile platforms)
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Data Export',
        fileName:
            'mic_backoffice_export_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(jsonBytes), // Required for Android and iOS
      );

      if (outputPath == null) {
        return null; // User cancelled
      }

      // On desktop platforms, we may need to write the file ourselves
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final file = File(outputPath);
        await file.writeAsString(jsonString);
      }

      return outputPath;
    } catch (e) {
      throw Exception('Failed to generate JSON export: $e');
    }
  }

  /// Export all data as PDF with file picker
  static Future<String?> exportAllDataAsPdf() async {
    try {
      // Collect all data first
      final data = <String, dynamic>{};

      // Export members
      try {
        final members = await MemberService.getMembers(limit: 10000);
        data['members'] = members;
      } catch (e) {
        data['members'] = [];
        data['members_error'] = e.toString();
      }

      // Export departments
      try {
        final departments = await DepartmentService.getDepartments(
          limit: 10000,
        );
        data['departments'] = departments;
      } catch (e) {
        data['departments'] = [];
        data['departments_error'] = e.toString();
      }

      // Export classes
      try {
        final classes = await ClassService.getClasses(limit: 10000);
        data['classes'] = classes;
      } catch (e) {
        data['classes'] = [];
        data['classes_error'] = e.toString();
      }

      // Export events
      try {
        final events = await EventService.getEvents(limit: 10000);
        data['events'] = events;
      } catch (e) {
        data['events'] = [];
        data['events_error'] = e.toString();
      }

      // Export tasks
      try {
        final tasks = await TaskService.getAllTasks(limit: 10000);
        data['tasks'] = tasks;
      } catch (e) {
        data['tasks'] = [];
        data['tasks_error'] = e.toString();
      }

      // Add metadata
      data['export_metadata'] = {
        'exported_at': DateTime.now().toIso8601String(),
        'exported_by': SupabaseService.currentUser?.id,
        'version': '1.0.0',
      };

      // Create PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Title
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Church Management System',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Complete Data Export',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Exported: ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Summary
              pw.Text(
                'EXPORT SUMMARY',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Members: ${(data['members'] as List).length}'),
              pw.SizedBox(height: 5),
              pw.Text('Departments: ${(data['departments'] as List).length}'),
              pw.SizedBox(height: 5),
              pw.Text('Classes: ${(data['classes'] as List).length}'),
              pw.SizedBox(height: 5),
              pw.Text('Events: ${(data['events'] as List).length}'),
              pw.SizedBox(height: 5),
              pw.Text('Tasks: ${(data['tasks'] as List).length}'),
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Members Section
              pw.Text(
                'MEMBERS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...(data['members'] as List).take(50).map((member) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    '${member['first_name'] ?? ''} ${member['last_name'] ?? ''} (${member['email'] ?? 'N/A'})',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                );
              }),
              if ((data['members'] as List).length > 50)
                pw.Text(
                  '... and ${(data['members'] as List).length - 50} more members',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Departments Section
              pw.Text(
                'DEPARTMENTS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...(data['departments'] as List).map((dept) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    '${dept['name'] ?? 'N/A'}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                );
              }),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Classes Section
              pw.Text(
                'CLASSES',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...(data['classes'] as List).map((cls) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    '${cls['name'] ?? 'N/A'}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                );
              }),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Events Section
              pw.Text(
                'EVENTS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...(data['events'] as List).take(20).map((event) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    '${event['name'] ?? 'N/A'} - ${event['event_date'] ?? 'N/A'}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                );
              }),
              if ((data['events'] as List).length > 20)
                pw.Text(
                  '... and ${(data['events'] as List).length - 20} more events',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Tasks Section
              pw.Text(
                'TASKS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...(data['tasks'] as List).take(20).map((task) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    '${task['title'] ?? 'N/A'} - ${task['status'] ?? 'N/A'}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                );
              }),
              if ((data['tasks'] as List).length > 20)
                pw.Text(
                  '... and ${(data['tasks'] as List).length - 20} more tasks',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),

              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Note: This is a summary export. For complete data, use the JSON export option.',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ];
          },
        ),
      );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();

      // Let user select save location (with bytes for mobile platforms)
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Data Export',
        fileName:
            'mic_backoffice_export_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes, // Required for Android and iOS
      );

      if (outputPath == null) {
        return null; // User cancelled
      }

      // On desktop platforms, we may need to write the file ourselves
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final file = File(outputPath);
        await file.writeAsBytes(pdfBytes);
      }

      return outputPath;
    } catch (e) {
      throw Exception('Failed to generate PDF export: $e');
    }
  }
}
