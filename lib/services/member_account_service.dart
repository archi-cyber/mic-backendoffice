import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'leader_access_service.dart';

/// Service for admins to create login accounts for members and manage their access.
/// Members with accounts can log in; default is view-only unless admin grants access.
class MemberAccountService {
  static final _client = SupabaseService.client;
  static const String defaultPassword = 'Password123';

  /// Get members with account status (has_account, user_id if any)
  static Future<List<Map<String, dynamic>>>
  getMembersWithAccountStatus() async {
    try {
      final members = await _client
          .from('members')
          .select('id, first_name, last_name, email, phone, role, is_active')
          .eq('is_active', true)
          .order('first_name');

      final list = List<Map<String, dynamic>>.from(members);

      // Get all users linked to members
      final users = await _client
          .from('users')
          .select('id, email, member_id, role, is_active')
          .not('member_id', 'is', null);

      final userByMemberId = <String, Map<String, dynamic>>{};
      for (final u in users as List) {
        final mid = u['member_id']?.toString();
        if (mid != null) {
          userByMemberId[mid] = Map<String, dynamic>.from(u);
        }
      }

      for (final m in list) {
        final memberId = m['id']?.toString();
        final user = memberId != null ? userByMemberId[memberId] : null;
        m['has_account'] = user != null && user['is_active'] == true;
        m['user_id'] = user?['id']?.toString();
        m['user_email'] = user?['email']?.toString();
      }

      return list;
    } catch (e) {
      throw Exception('Failed to get members: $e');
    }
  }

  /// Create login account for a member (admin only).
  /// Member must have email. Creates Supabase auth user + users row with role='member'.
  /// Seeds leader_access with view-only for all features; admin can then grant more.
  /// Does not switch the current session: the admin (caller) stays logged in.
  static Future<void> createAccountForMember({
    required String memberId,
    required String email,
    String? password,
  }) async {
    // Save current user's session so we can restore it after signUp (which may switch session to the new user).
    final previousSession = _client.auth.currentSession;
    final previousRefreshToken = previousSession?.refreshToken;

    try {
      final pwd = password ?? defaultPassword;
      final emailTrimmed = email.trim();
      if (emailTrimmed.isEmpty) {
        throw Exception('Member must have an email to create an account.');
      }

      // Check if a users row already exists for this member
      final existingUser = await _client
          .from('users')
          .select('id, is_active')
          .eq('member_id', memberId)
          .maybeSingle();

      if (existingUser != null) {
        final existingUserId = existingUser['id']?.toString();
        final isActive = existingUser['is_active'] == true;

        if (isActive) {
          // There is already an active account linked to this member
          throw Exception('This member already has an active account.');
        }

        // Inactive placeholder user exists (created when member was added).
        // Remove it so we can create a proper auth user and a synced users row.
        if (existingUserId != null) {
          try {
            await _client.from('users').delete().eq('id', existingUserId);
            debugPrint(
              '[MemberAccountService] Removed inactive placeholder user $existingUserId for member $memberId',
            );
          } catch (e) {
            debugPrint(
              '[MemberAccountService] Warning: failed to remove placeholder user $existingUserId: $e',
            );
            // Continue anyway – insert below may fail if constraints conflict
          }
        }
      }

      // Check if email already used by another auth user
      final existingByEmail = await _client
          .from('users')
          .select('id, member_id')
          .eq('email', emailTrimmed)
          .maybeSingle();

      if (existingByEmail != null) {
        final existingMemberId = existingByEmail['member_id']?.toString();
        if (existingMemberId != null && existingMemberId != memberId) {
          throw Exception('This email is already used by another account.');
        }
      }

      String? authUserId;
      try {
        final authResponse = await _client.auth.signUp(
          email: emailTrimmed,
          password: pwd,
          data: {
            'must_change_password': true,
            'role': 'member',
            'member_id': memberId,
          },
        );
        if (authResponse.user != null) {
          authUserId = authResponse.user!.id;
        }
      } on Exception catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('already registered') ||
            msg.contains('already exists')) {
          // Auth user exists; try to get id from users table by email
          final u = await _client
              .from('users')
              .select('id')
              .eq('email', emailTrimmed)
              .maybeSingle();
          if (u != null) {
            authUserId = u['id']?.toString();
            if (authUserId != null) {
              await _client
                  .from('users')
                  .update({
                    'member_id': memberId,
                    'is_active': true,
                    'role': 'member',
                    'must_change_password': true,
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', authUserId);
              await _seedMemberAccess(authUserId);
              return;
            }
          }
        }
        rethrow;
      }

      if (authUserId == null) {
        throw Exception(
          'Could not create auth user. Email confirmation may be required.',
        );
      }

      // Insert or update users table
      final userRow = await _client
          .from('users')
          .select('id')
          .eq('id', authUserId)
          .maybeSingle();

      if (userRow != null) {
        await _client
            .from('users')
            .update({
              'member_id': memberId,
              'email': emailTrimmed,
              'role': 'member',
              'is_active': true,
              'must_change_password': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', authUserId);
      } else {
        await _client.from('users').insert({
          'id': authUserId,
          'email': emailTrimmed,
          'member_id': memberId,
          'role': 'member',
          'is_active': true,
          'must_change_password': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await _seedMemberAccess(authUserId);
      debugPrint('[MemberAccountService] Created account for member $memberId');
    } catch (e) {
      throw Exception('Failed to create account: $e');
    } finally {
      // Restore the admin's session so the current user stays logged in (signUp may have switched session to the new member).
      if (previousRefreshToken != null && previousRefreshToken.isNotEmpty) {
        try {
          await _client.auth.setSession(previousRefreshToken);
        } catch (e) {
          debugPrint(
            '[MemberAccountService] Could not restore previous session: $e',
          );
        }
      }
    }
  }

  /// Seed leader_access for a member with view-only on all features
  static Future<void> _seedMemberAccess(String userId) async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return;

    for (final feature in LeaderAccessService.getAvailableFeatures()) {
      try {
        await LeaderAccessService.setLeaderAccess(
          userId: userId,
          featureName: feature,
          canView: true,
          canCreate: false,
          canEdit: false,
          canDelete: false,
        );
      } catch (e) {
        debugPrint('[MemberAccountService] Seed access for $feature: $e');
      }
    }
  }

  /// Deactivate a member's account (admin only). They can no longer log in.
  static Future<void> deactivateMemberAccount(String userId) async {
    try {
      await _client
          .from('users')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to deactivate account: $e');
    }
  }
}
