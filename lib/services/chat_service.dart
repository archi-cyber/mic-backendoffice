import 'package:flutter/foundation.dart';
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

      if (currentAuthUser != null) {
        try {
          // First try to find the user in the users table by auth.users.id
          // (if users.id matches auth.users.id)
          var user = await _client
              .from('users')
              .select('id')
              .eq('id', currentAuthUser.id)
              .maybeSingle();

          // If not found, try by email as fallback
          if (user == null && currentAuthUser.email != null) {
            user = await _client
                .from('users')
                .select('id')
                .eq('email', currentAuthUser.email!)
                .maybeSingle();
          }

          if (user != null && user['id'] != null) {
            createdByUserId = user['id'].toString();
            debugPrint('[ChatService] Found creator user ID: $createdByUserId');
          } else {
            debugPrint(
              '[ChatService] Creator user not found in users table (auth ID: ${currentAuthUser.id})',
            );
          }
        } catch (e) {
          debugPrint('[ChatService] Error getting creator user ID: $e');
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

      // Create notifications for all users when announcement is created
      debugPrint(
        '[ChatService] Creating notifications for announcement: ${response['id']}',
      );

      try {
        // Get current user's member_id to exclude them from notifications
        String? currentUserMemberId;
        if (currentAuthUser != null) {
          try {
            final currentUser = await _client
                .from('users')
                .select('member_id')
                .eq('id', currentAuthUser.id)
                .maybeSingle();
            currentUserMemberId = currentUser?['member_id']?.toString();
            debugPrint(
              '[ChatService] Current user member_id: $currentUserMemberId',
            );
          } catch (e) {
            debugPrint(
              '[ChatService] Could not get current user member_id: $e',
            );
          }
        }

        // Get all users and their member_ids
        // We need member_ids to create notifications
        final allUsers = await _client
            .from('users')
            .select('id, member_id, email, is_active')
            .eq('is_active', true)
            .limit(10000);

        debugPrint(
          '[ChatService] Found ${(allUsers as List).length} active users',
        );

        // Filter to get member_ids (only users who have a member profile)
        // Exclude the current user (announcement creator)
        final memberIds = <String>[];
        for (final user in allUsers) {
          final memberId = user['member_id']?.toString();
          if (memberId != null &&
              memberId.isNotEmpty &&
              memberId != currentUserMemberId) {
            memberIds.add(memberId);
          }
        }

        debugPrint(
          '[ChatService] Found ${memberIds.length} users with member_id (excluding creator)',
        );

        if (isGlobal) {
          // For global announcements, notify all users
          if (memberIds.isNotEmpty) {
            debugPrint(
              '[ChatService] Creating notifications for all ${memberIds.length} users',
            );
            await NotificationService.createBulkNotifications(
              memberIds: memberIds,
              type: 'announcement',
              title: title,
              message: message,
              relatedId: response['id']?.toString(),
              relatedType: 'announcement',
            );
            debugPrint(
              '[ChatService] Successfully created notifications for all users',
            );
          } else {
            debugPrint(
              '[ChatService] WARNING: No users with member_id found to notify',
            );
          }
        } else if (targetMemberIds != null && targetMemberIds.isNotEmpty) {
          // For targeted announcements, notify only selected members
          // Filter to only include member_ids that exist in our user list
          final validMemberIds = targetMemberIds
              .where((id) => memberIds.contains(id))
              .toList();

          if (validMemberIds.isNotEmpty) {
            debugPrint(
              '[ChatService] Creating notifications for ${validMemberIds.length} selected members',
            );
            await NotificationService.createBulkNotifications(
              memberIds: validMemberIds,
              type: 'announcement',
              title: title,
              message: message,
              relatedId: response['id']?.toString(),
              relatedType: 'announcement',
            );
            debugPrint(
              '[ChatService] Successfully created notifications for selected members',
            );
          } else {
            debugPrint(
              '[ChatService] WARNING: No valid member_ids found in target list',
            );
          }
        }
      } catch (e, stackTrace) {
        // Log error but don't fail announcement creation
        debugPrint(
          '[ChatService] ERROR: Failed to create notifications for announcement: $e',
        );
        debugPrint('[ChatService] Stack trace: $stackTrace');
        // Don't throw - announcement was created successfully, notifications are secondary
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
