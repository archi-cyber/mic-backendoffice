import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../desktop/desktop_shell_scope.dart';
import '../../services/member_account_service.dart';
import '../../services/role_service.dart';
import '../../services/supabase_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Member accounts management page (admin only).
/// Admins can create login accounts for members and manage their access.
/// Members with accounts can log in; default is view-only unless admin grants access.
class MemberAccountsPage extends StatefulWidget {
  /// When provided (e.g. desktop stack), back button calls this instead of Navigator.pop.
  final VoidCallback? onClose;

  MemberAccountsPage({super.key, this.onClose});

  @override
  State<MemberAccountsPage> createState() => _MemberAccountsPageState();
}

class _MemberAccountsPageState extends State<MemberAccountsPage> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String _filter = 'all'; // 'all', 'with_account', 'without_account'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  Future<void> _checkAdminAndLoad() async {
    final isAdmin = await RoleService.isCurrentUserAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
    });
    if (isAdmin) {
      await _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await MemberAccountService.getMembersWithAccountStatus();
      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading members: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMembers {
    // First apply account-status filter
    Iterable<Map<String, dynamic>> items = _members;
    switch (_filter) {
      case 'with_account':
        items = items.where((m) => m['has_account'] == true);
        break;
      case 'without_account':
        items = items.where((m) => m['has_account'] != true);
        break;
      default:
        break;
    }

    // Then apply search filter (by name or email)
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((m) {
        final name = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'
            .toLowerCase();
        final email = (m['email']?.toString() ?? '').toLowerCase();
        final userEmail = (m['user_email']?.toString() ?? '').toLowerCase();
        return name.contains(q) ||
            email.contains(q) ||
            userEmail.contains(q) ||
            (m['id']?.toString() ?? '').toLowerCase().contains(q);
      });
    }

    return items.toList();
  }

  Future<void> _createAccount(Map<String, dynamic> member) async {
    final memberId = member['id']?.toString();
    var email = (member['email']?.toString() ?? '').trim();
    if (memberId == null) return;

    // If member has no email, prompt admin to add one and update the member record
    if (email.isEmpty) {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('Add email for member')),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.tr('Email'),
              hintText: context.tr('member@example.com'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Save & create account')),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      final newEmail = controller.text.trim();
      if (newEmail.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Email cannot be empty.')),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Optionally do a very simple email format check
      if (!newEmail.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Please enter a valid email address.')),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      try {
        // Update member email in the database
        await SupabaseService.client
            .from('members')
            .update({
              'email': newEmail,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', memberId);

        // Update local copy so UI stays in sync until reload
        member['email'] = newEmail;
        email = newEmail;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Failed to update member email: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Create account')),
        content: Text(
          'Create a login account for ${member['first_name']} ${member['last_name']}?\n\n'
          'Email: $email\n'
          'Default password: ${MemberAccountService.defaultPassword}\n\n'
          'They will be required to change their password on first login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Create')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await MemberAccountService.createAccountForMember(
        memberId: memberId,
        email: email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Account created. Member can now log in.'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _manageAccess(Map<String, dynamic> member) {
    // Navigate to Leader Access page; user can select this member's user from the list
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.leaderAccess, '');
    } else {
      Navigator.of(context).pushNamed(RouteNames.leaderAccess);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          leading: widget.onClose != null
              ? IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: widget.onClose,
                )
              : null,
          title: Text(context.tr('Member Accounts')),
        ),
        body: Center(
          child: Text(
            context.tr('You do not have permission to access this page.'),
          ),
        ),
      );
    }

    final isDesktop = isDesktopEmbedded(
      context,
      inShell: widget.onClose != null,
    );

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onClose,
                    )
                  : null,
              title: Text(context.tr('Member Accounts')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _loadMembers,
                  tooltip: context.tr('Refresh'),
                ),
              ],
            ),
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(context),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return DesktopPageShell(
      maxWidth: kDesktopContentMaxWidth,
      banner: DesktopHeroBanner(
        title: context.tr('Member Accounts'),
        subtitle: context.tr(
          'Create login accounts for members and manage their access',
        ),
        icon: Icons.manage_accounts_outlined,
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _isLoading ? null : _loadMembers,
          tooltip: context.tr('Refresh'),
        ),
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height - 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopSectionCard(
              title: context.tr('Filter members'),
              icon: Icons.filter_list_outlined,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'all',
                          label: Text(context.tr('All')),
                        ),
                        ButtonSegment(
                          value: 'with_account',
                          label: Text(context.tr('With account')),
                        ),
                        ButtonSegment(
                          value: 'without_account',
                          label: Text(context.tr('No account')),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (Set<String> selected) {
                        setState(() => _filter = selected.first);
                      },
                    ),
                    SizedBox(width: AppDimensions.spacingMD),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: context.tr('Search by name or email'),
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMembers.isEmpty
                  ? Center(
                      child: Text(
                        _filter == 'all'
                            ? 'No members found.'
                            : _filter == 'with_account'
                            ? 'No members with accounts.'
                            : 'No members without accounts.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.mic.textSecondary,
                        ),
                      ),
                    )
                  : DesktopSectionCard(
                      title: context.tr('Members'),
                      icon: Icons.people_outline,
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height - 460,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth,
                                    ),
                                    child: DataTable(
                                      columns: [
                                        DataColumn(
                                          label: Text(context.tr('Name')),
                                        ),
                                        DataColumn(
                                          label: Text(context.tr('Email')),
                                        ),
                                        DataColumn(
                                          label: Text(context.tr('Status')),
                                        ),
                                        DataColumn(
                                          label: Text(context.tr('Actions')),
                                        ),
                                      ],
                                      rows: _filteredMembers.map((m) {
                                        final hasAccount =
                                            m['has_account'] == true;
                                        final name =
                                            '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'
                                                .trim();
                                        final displayName = name.isEmpty
                                            ? 'Unnamed member'
                                            : name;
                                        final email =
                                            m['email']?.toString() ?? '';
                                        final statusText = hasAccount
                                            ? 'Account'
                                            : email.isEmpty
                                            ? 'No email'
                                            : 'No account';
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(displayName)),
                                            DataCell(Text(email)),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    hasAccount
                                                        ? Icons.check_circle
                                                        : Icons
                                                              .person_off_outlined,
                                                    size: 18,
                                                    color: hasAccount
                                                        ? AppColors.success
                                                        : context
                                                              .mic
                                                              .textSecondary,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(statusText),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              hasAccount
                                                  ? TextButton.icon(
                                                      icon: const Icon(
                                                        Icons.settings,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Manage access',
                                                      ),
                                                      onPressed: () =>
                                                          _manageAccess(m),
                                                    )
                                                  : TextButton.icon(
                                                      icon: const Icon(
                                                        Icons
                                                            .person_add_alt_1_outlined,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Create account',
                                                      ),
                                                      onPressed: () =>
                                                          _createAccount(m),
                                                    ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'all',
                          label: Text(context.tr('All')),
                        ),
                        ButtonSegment(
                          value: 'with_account',
                          label: Text(context.tr('With account')),
                        ),
                        ButtonSegment(
                          value: 'without_account',
                          label: Text(context.tr('No account')),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (Set<String> selected) {
                        setState(() => _filter = selected.first);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingSM),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: context.tr('Search members by name or email'),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _filteredMembers.isEmpty
              ? Center(
                  child: Text(
                    _filter == 'all'
                        ? 'No members found.'
                        : _filter == 'with_account'
                        ? 'No members with accounts.'
                        : 'No members without accounts.',
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMD,
                  ),
                  itemCount: _filteredMembers.length,
                  itemBuilder: (context, index) {
                    final theme = Theme.of(context);
                    final m = _filteredMembers[index];
                    final hasAccount = m['has_account'] == true;
                    final name =
                        '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'
                            .trim();
                    final displayName = name.isEmpty ? 'Unnamed member' : name;
                    final email = m['email']?.toString() ?? '';
                    final statusText = hasAccount
                        ? 'Account: ${m['user_email'] ?? email}'
                        : email.isEmpty
                        ? 'No email – tap “Create account” to add email and enable login'
                        : 'No account – tap “Create account” to enable login';

                    return Card(
                      margin: EdgeInsets.only(bottom: AppDimensions.paddingSM),
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingMD),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: hasAccount
                                      ? AppColors.success.withValues(
                                          alpha: 0.12,
                                        )
                                      : context.mic.textSecondary.withValues(
                                          alpha: 0.08,
                                        ),
                                  child: Icon(
                                    hasAccount
                                        ? Icons.person
                                        : Icons.person_outline,
                                    color: hasAccount
                                        ? AppColors.success
                                        : context.mic.textSecondary,
                                  ),
                                ),
                                SizedBox(width: AppDimensions.spacingMD),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (email.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Text(
                                            email,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      context.mic.textSecondary,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: AppDimensions.spacingSM),
                            Text(
                              statusText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.mic.textSecondary,
                              ),
                            ),
                            SizedBox(height: AppDimensions.spacingSM),
                            Align(
                              alignment: Alignment.centerRight,
                              child: hasAccount
                                  ? TextButton.icon(
                                      icon: Icon(Icons.settings, size: 18),
                                      label: Text(context.tr('Manage access')),
                                      onPressed: () => _manageAccess(m),
                                    )
                                  : TextButton.icon(
                                      icon: Icon(
                                        Icons.person_add_alt_1_outlined,
                                        size: 18,
                                      ),
                                      label: Text(context.tr('Create account')),
                                      onPressed: () => _createAccount(m),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
