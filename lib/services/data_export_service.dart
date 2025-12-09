import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
}
