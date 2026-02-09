import 'supabase_service.dart';

/// Tag service for department-scoped task tags (CRUD).
class TagService {
  static final _client = SupabaseService.client;

  /// Create a tag in a department (name unique per department).
  /// [color] optional hex string (e.g. #FF5733).
  static Future<Map<String, dynamic>> createTag({
    required String name,
    required String departmentId,
    String? color,
  }) async {
    try {
      final response = await _client
          .from('tags')
          .insert({
            'name': name.trim(),
            'department_id': departmentId,
            if (color != null && color.isNotEmpty) 'color': color,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create tag: $e');
    }
  }

  /// Get tags for a department.
  static Future<List<Map<String, dynamic>>> getTags({
    required String departmentId,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _client
          .from('tags')
          .select()
          .eq('department_id', departmentId)
          .order('name', ascending: true);
      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 50) - 1);
      }
      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get tags: $e');
    }
  }

  /// Get tag by ID
  static Future<Map<String, dynamic>> getTagById(String tagId) async {
    try {
      final response = await _client
          .from('tags')
          .select()
          .eq('id', tagId)
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to get tag: $e');
    }
  }

  /// Update tag name and/or color
  static Future<Map<String, dynamic>> updateTag({
    required String tagId,
    String? name,
    String? color,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name.trim();
      if (color != null) updates['color'] = color.isEmpty ? null : color;
      if (updates.isEmpty) return await getTagById(tagId);
      final response = await _client
          .from('tags')
          .update(updates)
          .eq('id', tagId)
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to update tag: $e');
    }
  }

  /// Delete tag (removes from task_tags via CASCADE)
  static Future<void> deleteTag(String tagId) async {
    try {
      await _client.from('tags').delete().eq('id', tagId);
    } catch (e) {
      throw Exception('Failed to delete tag: $e');
    }
  }
}
