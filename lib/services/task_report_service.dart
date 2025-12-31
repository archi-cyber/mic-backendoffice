import 'package:flutter/foundation.dart' show debugPrint;
import 'supabase_service.dart';
import 'task_service.dart';
import 'department_service.dart';

/// Service for generating task reports and calculating completion percentages
class TaskReportService {
  static final _client = SupabaseService.client;

  /// Calculate task completion percentage for a department
  /// Returns a map with completion statistics
  static Future<Map<String, dynamic>> getDepartmentTaskCompletion({
    required String departmentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint(
        '[TaskReportService] Calculating task completion for department: $departmentId',
      );

      // Build query for tasks
      dynamic query = _client
          .from('tasks')
          .select('id, status, created_at, updated_at, due_date')
          .eq('department_id', departmentId);

      // Apply date filters if provided
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;
      final tasks = List<Map<String, dynamic>>.from(response);

      if (tasks.isEmpty) {
        return {
          'total_tasks': 0,
          'completed_tasks': 0,
          'pending_tasks': 0,
          'in_progress_tasks': 0,
          'completion_percentage': 0.0,
          'tasks': [],
        };
      }

      // Count tasks by status
      int completedCount = 0;
      int pendingCount = 0;
      int inProgressCount = 0;

      for (final task in tasks) {
        final status = task['status'] as String? ?? 'pending';
        switch (status.toLowerCase()) {
          case 'completed':
          case 'done':
          case 'finished':
            completedCount++;
            break;
          case 'in_progress':
          case 'in progress':
          case 'working':
            inProgressCount++;
            break;
          default:
            pendingCount++;
        }
      }

      final totalTasks = tasks.length;
      final completionPercentage = totalTasks > 0
          ? (completedCount / totalTasks) * 100
          : 0.0;

      debugPrint(
        '[TaskReportService] Completion: $completionPercentage% ($completedCount/$totalTasks)',
      );

      return {
        'total_tasks': totalTasks,
        'completed_tasks': completedCount,
        'pending_tasks': pendingCount,
        'in_progress_tasks': inProgressCount,
        'completion_percentage': completionPercentage,
        'tasks': tasks,
      };
    } catch (e) {
      debugPrint('[TaskReportService] Error calculating completion: $e');
      throw Exception('Failed to calculate task completion: $e');
    }
  }

  /// Get task completion for all departments
  static Future<List<Map<String, dynamic>>> getAllDepartmentsTaskCompletion({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint(
        '[TaskReportService] Calculating task completion for all departments',
      );

      // Get all departments
      final departments = await DepartmentService.getDepartments();

      // Calculate completion for each department
      final List<Map<String, dynamic>> results = [];
      for (final department in departments) {
        final departmentId = department['id']?.toString() ?? '';
        final completion = await getDepartmentTaskCompletion(
          departmentId: departmentId,
          startDate: startDate,
          endDate: endDate,
        );

        results.add({
          'department_id': departmentId,
          'department_name': department['name'] ?? 'Unknown',
          ...completion,
        });
      }

      // Sort by completion percentage (descending)
      results.sort((a, b) {
        final aPercent = a['completion_percentage'] as double;
        final bPercent = b['completion_percentage'] as double;
        return bPercent.compareTo(aPercent);
      });

      return results;
    } catch (e) {
      debugPrint(
        '[TaskReportService] Error calculating all departments completion: $e',
      );
      throw Exception('Failed to calculate all departments completion: $e');
    }
  }

  /// Get detailed task statistics for a department
  static Future<Map<String, dynamic>> getDepartmentTaskStatistics({
    required String departmentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Get completion data
      final completion = await getDepartmentTaskCompletion(
        departmentId: departmentId,
        startDate: startDate,
        endDate: endDate,
      );

      // Get all tasks with details
      final tasks = await TaskService.getAllTasks(departmentId: departmentId);

      // Filter by date if provided
      List<Map<String, dynamic>> filteredTasks = tasks;
      if (startDate != null || endDate != null) {
        filteredTasks = tasks.where((task) {
          final createdAt = task['created_at'];
          if (createdAt == null) return false;

          DateTime? taskDate;
          try {
            if (createdAt is String) {
              taskDate = DateTime.parse(createdAt);
            } else if (createdAt is DateTime) {
              taskDate = createdAt;
            }
          } catch (e) {
            return false;
          }

          if (taskDate == null) return false;

          if (startDate != null && taskDate.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && taskDate.isAfter(endDate)) {
            return false;
          }

          return true;
        }).toList();
      }

      // Get task assignments for detailed statistics
      final List<Map<String, dynamic>> tasksWithAssignments = [];
      for (final task in filteredTasks) {
        final taskId = task['id']?.toString() ?? '';
        final assignments = await TaskService.getTaskAssignments(taskId);

        tasksWithAssignments.add({
          ...task,
          'assignments': assignments,
          'assignment_count': assignments.length,
        });
      }

      return {...completion, 'tasks_with_details': tasksWithAssignments};
    } catch (e) {
      debugPrint('[TaskReportService] Error getting task statistics: $e');
      throw Exception('Failed to get task statistics: $e');
    }
  }
}
