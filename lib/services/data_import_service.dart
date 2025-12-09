import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'member_service.dart';
import 'supabase_service.dart';

/// Service for importing data
class DataImportService {
  /// Import data from JSON file
  static Future<Map<String, dynamic>> importFromJsonFile() async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        throw Exception('No file selected');
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return data;
    } catch (e) {
      throw Exception('Failed to import data: $e');
    }
  }

  /// Import members from JSON data
  static Future<Map<String, dynamic>> importMembers(
    List<dynamic> membersData,
  ) async {
    int successCount = 0;
    int errorCount = 0;
    final errors = <String>[];

    for (final memberData in membersData) {
      try {
        // Skip if member already exists (by email or ID)
        if (memberData['email'] != null) {
          final existing = await SupabaseService.client
              .from('members')
              .select('id')
              .eq('email', memberData['email'])
              .maybeSingle();

          if (existing != null) {
            errors.add(
              'Member with email ${memberData['email']} already exists',
            );
            errorCount++;
            continue;
          }
        }

        await MemberService.createMember(
          memberData: Map<String, dynamic>.from(memberData),
        );
        successCount++;
      } catch (e) {
        errorCount++;
        errors.add('Error importing member ${memberData['id']}: $e');
      }
    }

    return {
      'success_count': successCount,
      'error_count': errorCount,
      'errors': errors,
    };
  }

  /// Import all data from JSON
  static Future<Map<String, dynamic>> importAllData(
    Map<String, dynamic> data,
  ) async {
    final results = <String, dynamic>{};

    // Import members
    if (data['members'] != null) {
      try {
        results['members'] = await importMembers(
          data['members'] as List<dynamic>,
        );
      } catch (e) {
        results['members'] = {'error': e.toString()};
      }
    }

    // Note: Other data types (departments, classes, etc.) can be added similarly
    // For now, we'll focus on members as the primary import

    return results;
  }

  /// Import data from file and process
  static Future<Map<String, dynamic>> importFromFile() async {
    try {
      final data = await importFromJsonFile();
      final results = await importAllData(data);
      return results;
    } catch (e) {
      throw Exception('Failed to import data: $e');
    }
  }
}
