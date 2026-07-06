import 'member_service.dart';
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

  /// Convert a visitor into a member, then soft-delete the visitor record.
  static Future<Map<String, dynamic>> convertToMember({
    required String visitorId,
    required DateTime birthday,
    required String role,
    bool isNewComer = true,
    String? newcomerIntention,
  }) async {
    if (isNewComer && newcomerIntention == 'just_passing') {
      throw Exception(
        'Cannot convert visitor to member with "just passing" intention.',
      );
    }

    final visitor = await getVisitorById(visitorId);
    final firstName = visitor['first_name']?.toString().trim() ?? '';
    final lastName = visitor['last_name']?.toString().trim() ?? '';
    if (firstName.isEmpty || lastName.isEmpty) {
      throw Exception('Visitor must have a first and last name to convert.');
    }

    final visitDate = visitor['visit_date']?.toString();
    final newcomerJoinDate = visitDate != null && visitDate.isNotEmpty
        ? visitDate
        : DateTime.now().toIso8601String().split('T')[0];

    final memberData = <String, dynamic>{
      'first_name': firstName,
      'last_name': lastName,
      'email': visitor['email'],
      'phone': visitor['phone'],
      'address': visitor['address'],
      'birthday': birthday.toIso8601String().split('T')[0],
      'role': role,
      'is_active': true,
      'is_new_comer': isNewComer,
      if (isNewComer) ...{
        'newcomer_join_date': newcomerJoinDate,
        'newcomer_intention': newcomerIntention ?? 'wants_to_stay',
      },
    };

    final member = await MemberService.createMember(memberData: memberData);
    await deleteVisitor(visitorId);
    return member;
  }

  /// Soft-delete visitors logged for a specific church service.
  static Future<void> deleteVisitorsForService({
    required String visitDate,
    required String serviceType,
  }) async {
    try {
      final deletedAt = DateTime.now().toIso8601String();
      await _client
          .from('visitors')
          .update({
            'deleted_at': deletedAt,
            'updated_at': deletedAt,
          })
          .eq('visit_date', visitDate)
          .eq('service_type', serviceType)
          .isFilter('deleted_at', null);
    } catch (e) {
      throw Exception('Failed to delete visitors for service: $e');
    }
  }
}
