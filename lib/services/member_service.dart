import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'new_comer_service.dart';
import 'user_management_service.dart';

/// Member service for member management operations
class MemberService {
  static final _client = SupabaseService.client;

  /// Create member (admin only) - auto-creates user (inactive) when email/phone provided
  /// POST /members
  /// Business Rule: When admin creates a member → user account is auto-created but active=false
  static Future<Map<String, dynamic>> createMember({
    required Map<String, dynamic> memberData,
  }) async {
    try {
      final email = memberData['email'] as String?;
      final phone = memberData['phone'] as String?;
      final hasContact =
          (email != null && email.isNotEmpty) ||
          (phone != null && phone.isNotEmpty);

      final isNewComer = memberData['is_new_comer'] == true;
      final newcomerIntention = memberData['newcomer_intention']?.toString();
      if (isNewComer && newcomerIntention == 'just_passing') {
        throw Exception(
          'New comers with "just passing" intention must be created as visitors, not members.',
        );
      }

      // Insert member
      final response = await _client
          .from('members')
          .insert({
            ...memberData,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final memberId = response['id'].toString();

      // Auto-create inactive user account when contact info is available.
      if (hasContact) {
        try {
          await UserManagementService.createInactiveUserForMember(
            memberId: memberId,
            email: email,
            phone: phone,
          );
        } catch (e) {
          // Log error but don't fail member creation
          debugPrint('Warning: Failed to create user account: $e');
        }
      }

      // Track newcomer creation in dedicated history table.
      await NewComerService.ensureRecordExistsForMember(member: response);

      return response;
    } catch (e) {
      throw Exception('Failed to create member: $e');
    }
  }

  /// Get members with optional filters
  /// GET /members
  static Future<List<Map<String, dynamic>>> getMembers({
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = true,
  }) async {
    try {
      // Build base query with filters
      var filterQuery = _client.from('members').select();

      // Apply filters
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
        // Default to alphabetical order by first_name, then last_name
        transformQuery = transformQuery
            .order('first_name', ascending: true)
            .order('last_name', ascending: true);
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
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get members: $e');
    }
  }

  /// Get member by ID
  /// GET /members/:id
  static Future<Map<String, dynamic>> getMemberById(String memberId) async {
    try {
      final response = await _client
          .from('members')
          .select()
          .eq('id', memberId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get member: $e');
    }
  }

  /// Update member
  /// PATCH /members/:id
  static Future<Map<String, dynamic>> updateMember({
    required String memberId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _client
          .from('members')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', memberId)
          .select()
          .single();

      // If this update marks member as newcomer, ensure history is tracked.
      await NewComerService.ensureRecordExistsForMember(member: response);

      return response;
    } catch (e) {
      throw Exception('Failed to update member: $e');
    }
  }

  /// Soft delete member
  /// DELETE /members/:id
  static Future<void> deleteMember(String memberId) async {
    try {
      await _client
          .from('members')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', memberId);
    } catch (e) {
      throw Exception('Failed to delete member: $e');
    }
  }
}
