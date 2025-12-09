import 'supabase_service.dart';
import 'notification_service.dart';

/// Chat service for global announcements
class ChatService {
  static final _client = SupabaseService.client;

  /// Get announcements (global or filtered)
  /// GET /announcements
  static Future<List<Map<String, dynamic>>> getAnnouncements({
    int? limit,
    int? offset,
    DateTime? fromDate,
    bool? isGlobal,
    String? departmentId,
  }) async {
    try {
      // Build base query with filters
      var baseQuery = _client.from('announcements').select();

      // Filter by global status
      if (isGlobal != null) {
        baseQuery = baseQuery.eq('is_global', isGlobal);
      }

      // Filter by department
      if (departmentId != null) {
        baseQuery = baseQuery.eq('department_id', departmentId);
      }

      // Filter by date (before ordering)
      if (fromDate != null) {
        baseQuery = baseQuery.gte('created_at', fromDate.toIso8601String());
      }

      // Apply ordering and pagination
      var query = baseQuery.order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 10) - 1);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get announcements: $e');
    }
  }

  /// Get announcement by ID
  /// GET /announcements/:id
  static Future<Map<String, dynamic>> getAnnouncementById(
    String announcementId,
  ) async {
    try {
      final response = await _client
          .from('announcements')
          .select()
          .eq('id', announcementId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get announcement: $e');
    }
  }

  /// Create announcement (leaders/admins only)
  /// POST /announcements
  static Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String message,
    bool isGlobal = true,
    String? departmentId,
    List<String>? targetMemberIds,
  }) async {
    try {
      // Get the user ID from the users table (not auth.users)
      // The users table should have a reference to auth.users
      // Since created_by allows NULL (ON DELETE SET NULL), we can set it to null
      // if the user doesn't exist in the users table
      String? createdByUserId;
      final currentAuthUser = SupabaseService.currentUser;

      if (currentAuthUser != null && currentAuthUser.email != null) {
        try {
          // Try to find the user in the users table by email
          final user = await _client
              .from('users')
              .select('id')
              .eq('email', currentAuthUser.email!)
              .maybeSingle();

          if (user != null && user['id'] != null) {
            createdByUserId = user['id'].toString();
          }
        } catch (e) {
          // If user not found in users table or any error occurs,
          // set to null (foreign key constraint allows NULL)
          createdByUserId = null;
        }
      }

      final response = await _client
          .from('announcements')
          .insert({
            'title': title,
            'message': message,
            'is_global': isGlobal,
            'department_id': departmentId,
            'target_member_ids': targetMemberIds,
            'created_by':
                createdByUserId, // Can be null if user not in users table
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Create notifications for target members using NotificationService
      if (isGlobal) {
        // For global announcements, get all member IDs and create notifications
        try {
          final allMembers = await _client
              .from('members')
              .select('id')
              .limit(10000); // Large limit to get all members

          final allMemberIds = (allMembers as List)
              .map((m) => m['id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList();

          if (allMemberIds.isNotEmpty) {
            await NotificationService.createBulkNotifications(
              memberIds: allMemberIds,
              type: 'announcement',
              title: title,
              message: message,
              relatedId: response['id'],
              relatedType: 'announcement',
            );
          }
        } catch (e) {
          // Log error but don't fail announcement creation
          print(
            'Warning: Failed to create notifications for global announcement: $e',
          );
        }
      } else if (targetMemberIds != null && targetMemberIds.isNotEmpty) {
        // Create notifications for specific members
        await NotificationService.createBulkNotifications(
          memberIds: targetMemberIds,
          type: 'announcement',
          title: title,
          message: message,
          relatedId: response['id'],
          relatedType: 'announcement',
        );
      }

      return response;
    } catch (e) {
      throw Exception('Failed to create announcement: $e');
    }
  }

  /// Update announcement
  /// PATCH /announcements/:id
  static Future<Map<String, dynamic>> updateAnnouncement({
    required String announcementId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _client
          .from('announcements')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', announcementId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to update announcement: $e');
    }
  }

  /// Delete announcement
  /// DELETE /announcements/:id
  static Future<void> deleteAnnouncement(String announcementId) async {
    try {
      await _client.from('announcements').delete().eq('id', announcementId);
    } catch (e) {
      throw Exception('Failed to delete announcement: $e');
    }
  }
}
