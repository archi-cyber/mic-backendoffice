import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service for syncing users and members
/// - Creates a member for every user
/// - Creates a user (with default password) for every leader member
class UserMemberSyncService {
  static final _client = SupabaseService.client;
  static const String defaultPassword = 'Password123';

  /// Sync all users to members
  /// For every user in auth.users, create a corresponding member
  static Future<Map<String, dynamic>> syncUsersToMembers() async {
    try {
      debugPrint('[UserMemberSync] Starting sync: Users -> Members');

      // Get all users from users table (which should be synced with auth.users)
      final users = await _client
          .from('users')
          .select('id, email, phone, role, created_at')
          .order('created_at', ascending: true);

      debugPrint('[UserMemberSync] Found ${(users as List).length} users');

      int created = 0;
      int skipped = 0;
      int errors = 0;
      final errorsList = <String>[];

      for (final user in users) {
        try {
          final userId = user['id']?.toString();
          final email = user['email']?.toString();
          final phone = user['phone']?.toString();

          if (userId == null) {
            debugPrint('[UserMemberSync] Skipping user with null ID: $user');
            skipped++;
            continue;
          }

          // Check if member already exists for this user (via users.member_id)
          final existingUser = await _client
              .from('users')
              .select('member_id')
              .eq('id', userId)
              .maybeSingle();

          if (existingUser != null && existingUser['member_id'] != null) {
            debugPrint(
              '[UserMemberSync] Member already exists for user $userId (member_id: ${existingUser['member_id']})',
            );
            skipped++;
            continue;
          }

          // Extract name from email if possible, or use defaults
          String firstName = 'User';
          String lastName = '';

          if (email != null && email.isNotEmpty) {
            final emailParts = email.split('@')[0].split('.');
            if (emailParts.isNotEmpty) {
              firstName = emailParts[0];
              if (emailParts.length > 1) {
                lastName = emailParts.sublist(1).join(' ');
              }
            }
          }

          // Create member
          final memberData = {
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'phone': phone,
            'is_active': true,
            'role': user['role'] ?? 'member',
            'created_at':
                user['created_at'] ?? DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          final member = await _client
              .from('members')
              .insert(memberData)
              .select('id')
              .single();

          // Update users table to link member_id
          await _client
              .from('users')
              .update({
                'member_id': member['id'],
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', userId);

          debugPrint('[UserMemberSync] Created member for user $userId');
          created++;
        } catch (e) {
          debugPrint(
            '[UserMemberSync] Error creating member for user ${user['id']}: $e',
          );
          errors++;
          errorsList.add('User ${user['id']}: $e');
        }
      }

      debugPrint(
        '[UserMemberSync] Sync completed: $created created, $skipped skipped, $errors errors',
      );

      return {
        'created': created,
        'skipped': skipped,
        'errors': errors,
        'error_details': errorsList,
      };
    } catch (e, stackTrace) {
      debugPrint('[UserMemberSync] ERROR in syncUsersToMembers: $e');
      debugPrint('[UserMemberSync] Stack trace: $stackTrace');
      throw Exception('Failed to sync users to members: $e');
    }
  }

  /// Sync all leaders to users
  /// For every member with role='leader', create a user with default password
  /// Note: Creating auth users requires Supabase Admin API (server-side)
  /// This will create the user record in the users table and set must_change_password=true
  static Future<Map<String, dynamic>> syncLeadersToUsers() async {
    try {
      debugPrint('[UserMemberSync] Starting sync: Leaders -> Users');

      // Get all members with role='leader'
      final leaders = await _client
          .from('members')
          .select('id, first_name, last_name, email, phone, role')
          .eq('role', 'leader')
          .eq('is_active', true);

      debugPrint(
        '[UserMemberSync] Found ${(leaders as List).length} leader members',
      );

      int created = 0;
      int skipped = 0;
      int errors = 0;
      final errorsList = <String>[];

      for (final leader in leaders) {
        try {
          final memberId = leader['id']?.toString();
          final email = leader['email']?.toString();
          final phone = leader['phone']?.toString();
          final firstName = leader['first_name']?.toString() ?? '';
          final lastName = leader['last_name']?.toString() ?? '';

          if (memberId == null) {
            debugPrint(
              '[UserMemberSync] Skipping leader with null ID: $leader',
            );
            skipped++;
            continue;
          }

          // Check if user already exists for this member
          final existingUser = await _client
              .from('users')
              .select('id')
              .eq('member_id', memberId)
              .maybeSingle();

          if (existingUser != null) {
            debugPrint(
              '[UserMemberSync] User already exists for leader $memberId',
            );
            skipped++;
            continue;
          }

          // Check if we have email or phone
          if (email == null && phone == null) {
            debugPrint(
              '[UserMemberSync] Skipping leader $memberId: no email or phone',
            );
            skipped++;
            continue;
          }

          // Try to create auth user first using Supabase Auth
          // Note: This requires the user to have proper permissions or Admin API
          String? authUserId;
          try {
            if (email != null && email.isNotEmpty) {
              // Attempt to sign up the user with default password
              // This will create the auth user
              final authResponse = await _client.auth.signUp(
                email: email,
                password: defaultPassword,
                data: {
                  'must_change_password': true,
                  'role': 'leader',
                  'member_id': memberId,
                  'first_name': firstName,
                  'last_name': lastName,
                },
              );

              if (authResponse.user != null) {
                authUserId = authResponse.user!.id;
                debugPrint(
                  '[UserMemberSync] Created auth user for leader $memberId',
                );
              }
            }
          } catch (authError) {
            debugPrint(
              '[UserMemberSync] Warning: Could not create auth user for leader $memberId: $authError. '
              'This may require Admin API access. Will create user record in users table only.',
            );
            // Continue - we'll still create the users table record
          }

          // Create user in users table
          // Note: If auth user was created, use its ID. Otherwise, let the database generate one
          final userData = {
            if (authUserId != null) 'id': authUserId,
            'email': email,
            'phone': phone,
            'member_id': memberId,
            'role': 'leader',
            'is_active': true,
            'must_change_password': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          await _client.from('users').insert(userData);

          debugPrint('[UserMemberSync] Created user for leader $memberId');
          created++;
        } catch (e) {
          debugPrint(
            '[UserMemberSync] Error creating user for leader ${leader['id']}: $e',
          );
          errors++;
          errorsList.add('Leader ${leader['id']}: $e');
        }
      }

      debugPrint(
        '[UserMemberSync] Sync completed: $created created, $skipped skipped, $errors errors',
      );

      return {
        'created': created,
        'skipped': skipped,
        'errors': errors,
        'error_details': errorsList,
      };
    } catch (e, stackTrace) {
      debugPrint('[UserMemberSync] ERROR in syncLeadersToUsers: $e');
      debugPrint('[UserMemberSync] Stack trace: $stackTrace');
      throw Exception('Failed to sync leaders to users: $e');
    }
  }

  /// Ensure every active user in the `users` table has a corresponding auth account.
  /// For each active user with an email:
  /// - Try to sign them up with the default password.
  /// - If the auth user already exists, Supabase will return an \"already registered\" error, which we ignore.
  /// - If signUp succeeds, we have created an auth user that can log in.
  static Future<Map<String, dynamic>> ensureAuthAccountsForActiveUsers() async {
    try {
      debugPrint('[UserMemberSync] Ensuring auth accounts for active users...');

      final users = await _client
          .from('users')
          .select('id, email, is_active, role')
          .eq('is_active', true);

      int created = 0;
      int skipped = 0;
      int errors = 0;
      final errorsList = <String>[];

      for (final user in users as List) {
        final email = user['email']?.toString();
        final role = user['role']?.toString() ?? 'member';

        // We can only create auth accounts for users with an email
        if (email == null || email.isEmpty) {
          skipped++;
          continue;
        }

        try {
          // Attempt to sign up the user with the default password.
          // If the auth user already exists, Supabase will throw an error we can safely ignore.
          final authResponse = await _client.auth.signUp(
            email: email,
            password: defaultPassword,
            data: {'must_change_password': true, 'role': role},
          );

          if (authResponse.user != null) {
            debugPrint(
              '[UserMemberSync] Created auth user for existing user with email $email',
            );
            created++;
          } else {
            // No user returned (e.g. email confirmation required) – still consider this a success for now
            debugPrint(
              '[UserMemberSync] signUp did not return user for $email (email confirmation may be required)',
            );
            skipped++;
          }
        } catch (e) {
          final msg = e.toString().toLowerCase();
          if (msg.contains('already registered') ||
              msg.contains('already exists')) {
            // Auth user already exists – nothing to do
            debugPrint(
              '[UserMemberSync] Auth user already exists for $email, skipping',
            );
            skipped++;
            continue;
          }

          debugPrint(
            '[UserMemberSync] Error ensuring auth account for $email: $e',
          );
          errors++;
          errorsList.add('$email: $e');
        }
      }

      debugPrint(
        '[UserMemberSync] ensureAuthAccountsForActiveUsers completed: $created created, $skipped skipped, $errors errors',
      );

      return {
        'created': created,
        'skipped': skipped,
        'errors': errors,
        'error_details': errorsList,
      };
    } catch (e, stackTrace) {
      debugPrint(
        '[UserMemberSync] ERROR in ensureAuthAccountsForActiveUsers: $e',
      );
      debugPrint('[UserMemberSync] Stack trace: $stackTrace');
      throw Exception('Failed to ensure auth accounts for active users: $e');
    }
  }

  /// Run both syncs
  static Future<Map<String, dynamic>> syncAll() async {
    try {
      debugPrint('[UserMemberSync] Starting full sync...');

      final usersToMembers = await syncUsersToMembers();
      final leadersToUsers = await syncLeadersToUsers();
      final ensuredAuthAccounts = await ensureAuthAccountsForActiveUsers();

      debugPrint('[UserMemberSync] Full sync completed');

      return {
        'users_to_members': usersToMembers,
        'leaders_to_users': leadersToUsers,
        'auth_accounts': ensuredAuthAccounts,
      };
    } catch (e, stackTrace) {
      debugPrint('[UserMemberSync] ERROR in syncAll: $e');
      debugPrint('[UserMemberSync] Stack trace: $stackTrace');
      throw Exception('Failed to sync all: $e');
    }
  }
}
