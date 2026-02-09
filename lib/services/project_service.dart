import 'supabase_service.dart';

/// Project service for project CRUD and progression (computed in app).
class ProjectService {
  static final _client = SupabaseService.client;

  /// Create a project
  static Future<Map<String, dynamic>> createProject({
    required Map<String, dynamic> projectData,
  }) async {
    try {
      final response = await _client
          .from('projects')
          .insert({
            ...projectData,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create project: $e');
    }
  }

  /// Get all projects (optionally by department)
  static Future<List<Map<String, dynamic>>> getProjects({
    String? departmentId,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _client.from('projects').select(
            '*, departments(id, name), members!projects_person_in_charge_id_fkey(id, first_name, last_name, email)',
          );

      if (departmentId != null) {
        query = query.eq('department_id', departmentId);
      }

      dynamic transformQuery = query.order('created_at', ascending: false);
      if (limit != null) {
        transformQuery = transformQuery.limit(limit);
      }
      if (offset != null) {
        transformQuery = transformQuery.range(
          offset,
          offset + (limit ?? 10) - 1,
        );
      }

      final response = await transformQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get projects: $e');
    }
  }

  /// Get project by ID
  static Future<Map<String, dynamic>> getProjectById(String projectId) async {
    try {
      final response = await _client
          .from('projects')
          .select(
            '*, departments(id, name), members!projects_person_in_charge_id_fkey(id, first_name, last_name, email)',
          )
          .eq('id', projectId)
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to get project: $e');
    }
  }

  /// Update project
  static Future<Map<String, dynamic>> updateProject({
    required String projectId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _client
          .from('projects')
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', projectId)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update project: $e');
    }
  }

  /// Delete project (tasks.project_id will be set to null via ON DELETE SET NULL if you use that; we defined SET NULL)
  static Future<void> deleteProject(String projectId) async {
    try {
      await _client.from('projects').delete().eq('id', projectId);
    } catch (e) {
      throw Exception('Failed to delete project: $e');
    }
  }

  /// Compute progression for a project: (completed tasks / total tasks) * 100
  /// Returns a map with total, completed, and percentage (0-100).
  static Future<Map<String, dynamic>> getProjectProgression(
    String projectId,
  ) async {
    try {
      final tasks = await _client
          .from('tasks')
          .select('id, status')
          .eq('project_id', projectId);

      final list = List<Map<String, dynamic>>.from(tasks);
      final total = list.length;
      final completed =
          list.where((t) => t['status']?.toString() == 'completed').length;
      final percentage = total > 0 ? (completed / total * 100).round() : 0;

      return {
        'total': total,
        'completed': completed,
        'percentage': percentage,
      };
    } catch (e) {
      throw Exception('Failed to get project progression: $e');
    }
  }
}
