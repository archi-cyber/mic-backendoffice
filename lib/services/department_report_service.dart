import 'package:flutter/foundation.dart' show debugPrint;
import 'supabase_service.dart';

/// Service for managing department reports
class DepartmentReportService {
  static final _client = SupabaseService.client;

  /// Create a new department report
  static Future<Map<String, dynamic>> createReport({
    required String departmentId,
    required String title,
    required String definedObjectives,
    required String positivePoints,
    required String difficultiesEncountered,
    required String suggestions,
    String? comments,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to create reports');
      }

      final response = await _client
          .from('department_reports')
          .insert({
            'department_id': departmentId,
            'created_by': currentUser.id,
            'title': title,
            'defined_objectives': definedObjectives,
            'positive_points': positivePoints,
            'difficulties_encountered': difficultiesEncountered,
            'suggestions': suggestions,
            'comments': comments,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create report: $e');
    }
  }

  /// Get all reports for a department
  static Future<List<Map<String, dynamic>>> getDepartmentReports({
    required String departmentId,
    int? limit,
    int? offset,
  }) async {
    try {
      debugPrint(
        '[DepartmentReportService] Fetching reports for department: $departmentId',
      );
      var query = _client
          .from('department_reports')
          .select('*')
          .eq('department_id', departmentId)
          .order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 10) - 1);
      }

      final response = await query;
      debugPrint(
        '[DepartmentReportService] Fetched ${response.length} reports',
      );
      final reports = List<Map<String, dynamic>>.from(response);
      // Filter out deleted reports in application
      final activeReports = reports
          .where((r) => r['deleted_at'] == null)
          .toList();
      debugPrint(
        '[DepartmentReportService] Returning ${activeReports.length} active reports',
      );
      return activeReports;
    } catch (e, stackTrace) {
      debugPrint('[DepartmentReportService] Error fetching reports: $e');
      debugPrint('[DepartmentReportService] Stack trace: $stackTrace');
      throw Exception('Failed to get department reports: $e');
    }
  }

  /// Get a single report by ID
  static Future<Map<String, dynamic>> getReportById(String reportId) async {
    try {
      final response = await _client
          .from('department_reports')
          .select('*')
          .eq('id', reportId)
          .single();

      // Check if report is deleted
      if (response['deleted_at'] != null) {
        throw Exception('Report not found or has been deleted');
      }

      return response;
    } catch (e) {
      throw Exception('Failed to get report: $e');
    }
  }

  /// Update a department report
  static Future<Map<String, dynamic>> updateReport({
    required String reportId,
    required String title,
    required String definedObjectives,
    required String positivePoints,
    required String difficultiesEncountered,
    required String suggestions,
    String? comments,
  }) async {
    try {
      final response = await _client
          .from('department_reports')
          .update({
            'title': title,
            'defined_objectives': definedObjectives,
            'positive_points': positivePoints,
            'difficulties_encountered': difficultiesEncountered,
            'suggestions': suggestions,
            'comments': comments,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to update report: $e');
    }
  }

  /// Delete a department report (soft delete)
  static Future<void> deleteReport(String reportId) async {
    try {
      await _client
          .from('department_reports')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to delete report: $e');
    }
  }

  /// Get all reports for generating summary (no pagination)
  static Future<List<Map<String, dynamic>>> getAllDepartmentReportsForSummary(
    String departmentId,
  ) async {
    try {
      final response = await _client
          .from('department_reports')
          .select('*')
          .eq('department_id', departmentId)
          .order('created_at', ascending: true);

      final reports = List<Map<String, dynamic>>.from(response);
      // Filter out deleted reports in application
      return reports.where((r) => r['deleted_at'] == null).toList();
    } catch (e) {
      throw Exception('Failed to get reports for summary: $e');
    }
  }
}
