import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/localization/app_localizations.dart';
import '../services/member_account_service.dart';

/// Result of ensuring a member has a login account (e.g. before task assign).
class EnsureMemberAccountResult {
  const EnsureMemberAccountResult._({
    required this.status,
    this.email,
    this.warningMessage,
    this.warningParams = const {},
  });

  final EnsureMemberAccountStatus status;
  final String? email;

  /// English key for [context.tr]; set when assignment should continue with a warning.
  final String? warningMessage;
  final Map<String, Object?> warningParams;

  bool get created => status == EnsureMemberAccountStatus.created;
  bool get shouldWarn => warningMessage != null && warningMessage!.isNotEmpty;

  factory EnsureMemberAccountResult.alreadyHadAccount() =>
      const EnsureMemberAccountResult._(
        status: EnsureMemberAccountStatus.alreadyHadAccount,
      );

  factory EnsureMemberAccountResult.created({required String email}) =>
      EnsureMemberAccountResult._(
        status: EnsureMemberAccountStatus.created,
        email: email,
      );

  factory EnsureMemberAccountResult.failed(
    String warningMessage, [
    Map<String, Object?> params = const {},
  ]) =>
      EnsureMemberAccountResult._(
        status: EnsureMemberAccountStatus.failed,
        warningMessage: warningMessage,
        warningParams: params,
      );

  factory EnsureMemberAccountResult.skipped(String warningMessage) =>
      EnsureMemberAccountResult._(
        status: EnsureMemberAccountStatus.skipped,
        warningMessage: warningMessage,
      );
}

enum EnsureMemberAccountStatus {
  alreadyHadAccount,
  created,
  failed,
  skipped,
}

/// Prompts for email if needed, creates a login account, emails credentials.
class MemberAccountEnsureHelper {
  MemberAccountEnsureHelper._();

  /// Ensures [memberId] can log in. Never blocks the caller’s main action:
  /// on failure/cancel, returns a [warningMessage] instead.
  static Future<EnsureMemberAccountResult> ensureForTaskAssignment(
    BuildContext context, {
    required String memberId,
    Map<String, dynamic>? member,
  }) async {
    try {
      final hasAccount = await MemberAccountService.memberHasActiveAccount(
        memberId,
      );
      if (hasAccount) {
        return EnsureMemberAccountResult.alreadyHadAccount();
      }

      var memberRow = member;
      if (memberRow == null || memberRow['id']?.toString() != memberId) {
        memberRow = await _loadMember(memberId);
      }
      if (memberRow == null) {
        return EnsureMemberAccountResult.failed(
          'Could not create login account: member not found.',
        );
      }

      var email = (memberRow['email']?.toString() ?? '').trim();
      final firstName = memberRow['first_name']?.toString() ?? '';
      final lastName = memberRow['last_name']?.toString() ?? '';
      final displayName = '$firstName $lastName'.trim();

      if (email.isEmpty) {
        if (!context.mounted) {
          return EnsureMemberAccountResult.skipped(
            'Task assigned, but login was not created (no email).',
          );
        }
        final prompted = await _promptForEmail(
          context,
          memberName: displayName.isEmpty ? null : displayName,
        );
        if (prompted == null) {
          return EnsureMemberAccountResult.skipped(
            'Task assigned, but login was not created (no email).',
          );
        }
        email = prompted;
        // Le serveur enregistre l'adresse sur la fiche en créant le compte.
        memberRow['email'] = email;
      }

      try {
        await MemberAccountService.createAccountForAssignee(
          memberId: memberId,
          email: email,
        );
      } catch (e) {
        final detail = e.toString().replaceFirst('Exception: ', '');
        return EnsureMemberAccountResult.failed(
          'Task assigned, but login was not created: {error}',
          {'error': detail},
        );
      }

      if (context.mounted) {
        await _showAccountCreatedDialog(
          context,
          memberName: displayName.isEmpty ? email : displayName,
          email: email,
        );
      }

      return EnsureMemberAccountResult.created(email: email);
    } catch (e) {
      final detail = e.toString().replaceFirst('Exception: ', '');
      return EnsureMemberAccountResult.failed(
        'Task assigned, but login was not created: {error}',
        {'error': detail},
      );
    }
  }

  static Future<Map<String, dynamic>?> _loadMember(String memberId) async {
    try {
      final status = await MemberAccountService.getAssigneeAccount(memberId);
      final member = status['member'];
      return member is Map ? Map<String, dynamic>.from(member) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _promptForEmail(
    BuildContext context, {
    String? memberName,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Add email for member')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              memberName == null || memberName.isEmpty
                  ? dialogContext.tr(
                      'This member has no email. Enter one to create a login account.',
                    )
                  : dialogContext.tr(
                      '{name} has no email. Enter one to create a login account.',
                      {'name': memberName},
                    ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: dialogContext.tr('Email'),
                hintText: dialogContext.tr('member@example.com'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Save & create account')),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;
    final email = controller.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Please enter a valid email address.')),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }
    return email;
  }

  static Future<void> _showAccountCreatedDialog(
    BuildContext context, {
    required String memberName,
    required String email,
  }) async {
    final password = MemberAccountService.defaultPassword;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Account created')),
        content: Text(
          dialogContext.tr(
            'A login account was created for {name}.\n\n'
            'Email: {email}\n'
            'Default password: {password}\n\n'
            'They must change their password on first login. '
            'An email with these credentials has been sent.',
            {
              'name': memberName,
              'email': email,
              'password': password,
            },
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('OK')),
          ),
        ],
      ),
    );
  }
}
