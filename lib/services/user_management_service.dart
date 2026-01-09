import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'role_service.dart';

/// Service for managing user accounts linked to members
/// Handles business rules for user activation/deactivation based on leadership roles
class UserManagementService {
  static final _client = SupabaseService.client;

  /// Create inactive user account for a member
  /// Called when admin creates a member
  /// If user already exists (by email), returns existing user ID instead of creating duplicate
  static Future<String?> createInactiveUserForMember({
    required String memberId,
    required String? email,
    required String? phone,
  }) async {
    try {
      // Use email or phone as identifier
      final identifier = email ?? phone;
      if (identifier == null) {
        throw Exception('Email or phone required');
      }

      // Check if user already exists by email
      if (email != null && email.isNotEmpty) {
        final existingUser = await _client
            .from('users')
            .select('id, member_id')
            .eq('email', email as Object)
            .limit(1)
            .maybeSingle();

        if (existingUser != null) {
          final existingUserId = existingUser['id']?.toString();
          if (existingUserId == null) return null;

          // Update member_id if it's not set or different
          if (existingUser['member_id'] == null ||
              existingUser['member_id'].toString() != memberId) {
            await _client
                .from('users')
                .update({
                  'member_id': memberId,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', existingUserId);
          }

          // Ensure mic@mic.com has admin privileges
          if (email == RoleService.superAdminEmail) {
            await RoleService.ensureSuperAdminPrivileges(email);
          }

          return existingUserId;
        }
      }

      // Check if user exists by phone (if email not provided)
      if (phone != null &&
          phone.isNotEmpty &&
          (email == null || email.isEmpty)) {
        final existingUser = await _client
            .from('users')
            .select('id, member_id')
            .eq('phone', phone as Object)
            .limit(1)
            .maybeSingle();

        if (existingUser != null) {
          final existingUserId = existingUser['id']?.toString();
          if (existingUserId == null) return null;

          // Update member_id if it's not set or different
          if (existingUser['member_id'] == null ||
              existingUser['member_id'].toString() != memberId) {
            await _client
                .from('users')
                .update({
                  'member_id': memberId,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', existingUserId);
          }

          return existingUserId;
        }
      }

      // User doesn't exist, create new one
      final userData = {
        'email': email,
        'phone': phone,
        'member_id': memberId,
        'is_active': false,
        'role': 'member',
        'must_change_password': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert into users table (if using custom users table)
      // Or use Supabase Admin API to create auth user
      final response = await _client
          .from('users')
          .insert(userData)
          .select()
          .single();

      final userId = response['id']?.toString();

      // Ensure mic@mic.com has admin privileges
      if (email != null && email == RoleService.superAdminEmail) {
        await RoleService.ensureSuperAdminPrivileges(email);
      }

      return userId;
    } catch (e) {
      // If it's a duplicate key error, try to find the existing user
      if (e.toString().contains('duplicated key') ||
          e.toString().contains('unique constraint')) {
        try {
          // Try to find existing user by email
          if (email != null && email.isNotEmpty) {
            final existingUser = await _client
                .from('users')
                .select('id, member_id')
                .eq('email', email)
                .limit(1)
                .maybeSingle();

            if (existingUser != null) {
              final existingUserId = existingUser['id']?.toString();
              if (existingUserId == null) return null;

              // Update member_id if needed
              if (existingUser['member_id'] == null ||
                  existingUser['member_id'].toString() != memberId) {
                await _client
                    .from('users')
                    .update({
                      'member_id': memberId,
                      'updated_at': DateTime.now().toIso8601String(),
                    })
                    .eq('id', existingUserId);
              }

              return existingUserId;
            }
          }
        } catch (findError) {
          // If finding existing user also fails, throw original error
          throw Exception('Failed to create account');
        }
      }
      throw Exception('Failed to create account');
    }
  }

  /// Activate user and set as leader when assigned leadership role
  /// Sets default password and must_change_password=true
  /// Also creates Supabase Auth user if one doesn't exist
  static Future<void> activateUserAsLeader({
    required String userId,
    String? defaultPassword,
  }) async {
    try {
      // Get current user to check if password exists and get email/phone
      final user = await _client
          .from('users')
          .select('email, phone, encrypted_password')
          .eq('id', userId)
          .maybeSingle();

      if (user == null) {
        throw Exception('User not found');
      }

      final email = user['email'] as String?;
      final hasPassword = user['encrypted_password'] != null;
      final password = defaultPassword ?? 'Password123';

      // Always ensure Supabase Auth user exists for leaders with email
      // This ensures every leader has an auth account with default password
      if (email != null && email.isNotEmpty) {
        try {
          // Try to sign up the user with default password
          // This will create the auth account if it doesn't exist
          final signUpResponse = await _client.auth.signUp(
            email: email,
            password: password,
            data: {'must_change_password': true, 'role': 'leader'},
            emailRedirectTo: null, // No redirect URL for backoffice
          );

          // If sign up was successful but email confirmation is required,
          // the user will need to confirm their email before logging in
          if (signUpResponse.user != null && signUpResponse.session == null) {
            print(
              'Info: Auth account created for $email. '
              'Email confirmation may be required depending on Supabase settings.',
            );
          } else if (signUpResponse.session != null) {
            print('Success: Auth account created and confirmed for $email');
          }
        } on AuthException catch (e) {
          // If user already exists, try to update password if needed
          if (e.message.toLowerCase().contains('already registered') ||
              e.message.toLowerCase().contains('already exists') ||
              e.message.toLowerCase().contains('user already registered')) {
            // User already exists in Supabase Auth
            print('Auth account already exists for $email');

            // Try to sign in to verify the account works
            // If it fails, we know the password might be different
            try {
              await _client.auth.signInWithPassword(
                email: email,
                password: password,
              );
              print('Verified: Auth account password is correct for $email');
            } catch (signInError) {
              // Password might be different, but that's okay
              // The user can use forgot password if needed
              print(
                'Note: Auth account exists but password may differ. '
                'User can use forgot password if needed.',
              );
            }
          } else {
            // Other auth errors - log but don't fail
            print(
              'Warning: Could not create/verify Supabase Auth user: ${e.message}',
            );
          }
        } catch (e) {
          // Other errors - log but continue with users table update
          print('Warning: Could not create Supabase Auth user: $e');
        }
      } else if (email == null || email.isEmpty) {
        print(
          'Warning: Cannot create auth account for leader - email is required. '
          'User ID: $userId',
        );
      }

      // Update user: activate, set role, set default password if needed
      final updates = <String, dynamic>{
        'is_active': true,
        'role': 'leader',
        'must_change_password': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Only set default password if user doesn't have one
      if (!hasPassword && password.isNotEmpty) {
        // Note: In production, hash password server-side
        // For now, we'll set a flag that password needs to be set
        updates['encrypted_password'] = password; // Should be hashed
      }

      await _client.from('users').update(updates).eq('id', userId);

      // Ensure mic@mic.com has admin privileges
      if (email != null && email == RoleService.superAdminEmail) {
        await RoleService.ensureSuperAdminPrivileges(email);
      }
    } catch (e) {
      throw Exception('Failed to activate user');
    }
  }

  /// Check if member has any leadership roles
  static Future<bool> hasLeadershipRole(String memberId) async {
    try {
      final leadershipRoles = await _client
          .from('department_members')
          .select()
          .eq('member_id', memberId)
          .inFilter('role', ['leader', 'subleader']);

      return (leadershipRoles as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Deactivate user when no longer has leadership roles
  /// Preserves password
  static Future<void> deactivateUserIfNoLeadership({
    required String userId,
    required String memberId,
  }) async {
    try {
      final hasLeadership = await hasLeadershipRole(memberId);

      if (!hasLeadership) {
        // Deactivate user but preserve password
        await _client
            .from('users')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
              // Note: Do NOT clear password or role
            })
            .eq('id', userId);
      }
    } catch (e) {
      throw Exception('Failed to deactivate user');
    }
  }

  /// Reactivate user when re-assigned as leader
  /// Preserves existing password unless admin forced reset
  /// Ensures auth account exists
  static Future<void> reactivateUserAsLeader({required String userId}) async {
    try {
      // Get user email to ensure auth account exists
      final user = await _client
          .from('users')
          .select('email')
          .eq('id', userId)
          .maybeSingle();

      final email = user?['email'] as String?;
      final defaultPassword = 'Password123';

      // Ensure Supabase Auth account exists when reactivating
      if (email != null && email.isNotEmpty) {
        try {
          // Try to create auth account if it doesn't exist
          await _client.auth.signUp(
            email: email,
            password: defaultPassword,
            data: {'must_change_password': true, 'role': 'leader'},
            emailRedirectTo: null,
          );
          print('Info: Auth account created for reactivated leader: $email');
        } on AuthException catch (e) {
          // If user already exists, that's fine - account is already there
          if (e.message.toLowerCase().contains('already registered') ||
              e.message.toLowerCase().contains('already exists') ||
              e.message.toLowerCase().contains('user already registered')) {
            print(
              'Info: Auth account already exists for reactivated leader: $email',
            );
          } else {
            print(
              'Warning: Could not verify/create auth account: ${e.message}',
            );
          }
        } catch (e) {
          print('Warning: Could not verify/create auth account: $e');
        }
      }

      // Reactivate and set role, but preserve password
      await _client
          .from('users')
          .update({
            'is_active': true,
            'role': 'leader',
            // Keep must_change_password as is (only set if admin forced reset)
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to reactivate user');
    }
  }

  /// Get user ID for a member
  /// First checks by member_id, then by member's email if not found
  static Future<String?> getUserIdForMember(String memberId) async {
    try {
      // First try to find by member_id
      var user = await _client
          .from('users')
          .select('id')
          .eq('member_id', memberId)
          .limit(1)
          .maybeSingle();

      if (user != null) {
        return user['id']?.toString();
      }

      // If not found by member_id, try to find by member's email
      final member = await _client
          .from('members')
          .select('email')
          .eq('id', memberId)
          .maybeSingle();

      if (member != null && member['email'] != null) {
        final email = member['email'] as String;
        user = await _client
            .from('users')
            .select('id, member_id')
            .eq('email', email as Object)
            .limit(1)
            .maybeSingle();

        if (user != null) {
          final userId = user['id']?.toString();
          if (userId == null) return null;

          // Update member_id if it's not set
          if (user['member_id'] == null) {
            await _client
                .from('users')
                .update({
                  'member_id': memberId,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', userId);
          }

          return userId;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
