import 'supabase_service.dart';

/// Visitor service for visitor management operations
class VisitorService {
  static final _client = SupabaseService.client;

  /// Create visitor
  /// POST /visitors
  static Future<Map<String, dynamic>> createVisitor({
    required Map<String, dynamic> visitorData,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to create visitor');
      }

      final response = await _client
          .from('visitors')
          .insert({
            ...visitorData,
            'created_by': currentUser.id,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create visitor: $e');
    }
  }

  /// Get visitors with optional filters
  /// GET /visitors
  static String _dateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Future<List<Map<String, dynamic>>> getVisitors({
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = false,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Build base query with filters
      var filterQuery = _client.from('visitors').select();

      // Apply date filters
      if (fromDate != null) {
        filterQuery = filterQuery.gte('visit_date', _dateOnly(fromDate));
      }
      if (toDate != null) {
        filterQuery = filterQuery.lte('visit_date', _dateOnly(toDate));
      }

      // Apply other filters
      if (filters != null) {
        filters.forEach((key, value) {
          if (value != null) {
            filterQuery = filterQuery.eq(key, value);
          }
        });
      }

      // Apply ordering (returns PostgrestTransformBuilder)
      dynamic transformQuery = filterQuery;
      if (orderBy != null) {
        transformQuery = transformQuery.order(orderBy, ascending: ascending);
      } else {
        // Default to most recent visits first
        transformQuery = transformQuery.order('visit_date', ascending: false)
            .order('created_at', ascending: false);
      }

      // Apply pagination (on PostgrestTransformBuilder)
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
      final records = List<Map<String, dynamic>>.from(response);
      // Filter out deleted records
      return records.where((r) => r['deleted_at'] == null).toList();
    } catch (e) {
      throw Exception('Failed to get visitors: $e');
    }
  }

  /// Get visitor by ID
  /// GET /visitors/:id
  static Future<Map<String, dynamic>> getVisitorById(String visitorId) async {
    try {
      final response = await _client
          .from('visitors')
          .select()
          .eq('id', visitorId)
          .single();
      
      // Filter out deleted records
      if (response['deleted_at'] != null) {
        throw Exception('Visitor not found');
      }

      return response;
    } catch (e) {
      throw Exception('Failed to get visitor: $e');
    }
  }

  /// Update visitor
  /// PATCH /visitors/:id
  static Future<Map<String, dynamic>> updateVisitor({
    required String visitorId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _client
          .from('visitors')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', visitorId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to update visitor: $e');
    }
  }

  /// Delete visitor (soft delete)
  /// DELETE /visitors/:id
  static Future<void> deleteVisitor(String visitorId) async {
    try {
      await _client
          .from('visitors')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', visitorId);
    } catch (e) {
      throw Exception('Failed to delete visitor: $e');
    }
  }
}
