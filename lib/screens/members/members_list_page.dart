import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/member_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../services/member_service.dart';
import 'add_member_page.dart';
import 'edit_member_page.dart';
import 'member_form_ui.dart';
import 'member_profile_page.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Members list with search and filters
class MembersListPage extends StatefulWidget {
  /// When true (e.g. desktop layout), no app bar is shown.
  final bool hideAppBarAndBottomNav;

  MembersListPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<MembersListPage> createState() => _MembersListPageState();
}

class _MembersListPageState extends State<MembersListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _selectedDepartment;
  String? _selectedBirthdayMonth;
  bool? _isActiveFilter;
  String? _selectedRole;
  String? _selectedProfession;
  bool? _isNewcomerFilter;
  final int _membersRowsPerPage = 10;
  int _membersPage = 0;

  /// When set (desktop), member profile is shown as stack overlay instead of route.
  String? _selectedMemberId;

  /// When true (desktop), add member form is shown as stack overlay.
  bool _showAddMember = false;

  /// When set (desktop), edit member form is shown as stack overlay.
  String? _editMemberId;

  @override
  void initState() {
    super.initState();
    // If showing upcoming birthdays, we'll filter in _filteredMembers
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final filters = <String, dynamic>{};
      if (_selectedDepartment != null) {
        filters['department_id'] = _selectedDepartment;
      }
      if (_isActiveFilter != null) {
        filters['is_active'] = _isActiveFilter;
      }
      if (_selectedRole != null) {
        filters['role'] = _selectedRole;
      }
      if (_selectedProfession != null) {
        filters['profession'] = _selectedProfession;
      }
      if (_isNewcomerFilter != null) {
        filters['is_new_comer'] = _isNewcomerFilter;
      }

      final members = await MemberService.getMembers(filters: filters);
      setState(() {
        _members = members;
        _isLoading = false;
        _membersPage = 0;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading members: $e'))),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMembers {
    var filtered = _members;

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((member) {
        final name = '${member['first_name']} ${member['last_name']}'
            .toLowerCase();
        final email = (member['email'] ?? '').toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }

    // Birthday month filter
    if (_selectedBirthdayMonth != null) {
      // Single month filter (existing behavior)
      filtered = filtered.where((member) {
        final birthday = member['birthday'];
        if (birthday == null) return false;
        try {
          final date = DateTime.parse(birthday);
          final month = date.month.toString().padLeft(2, '0');
          return month == _selectedBirthdayMonth;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Role filter
    if (_selectedRole != null) {
      filtered = filtered.where((member) {
        return (member['role'] ?? 'member') == _selectedRole;
      }).toList();
    }

    // Profession filter
    if (_selectedProfession != null) {
      filtered = filtered.where((member) {
        return (member['profession'] ?? '') == _selectedProfession;
      }).toList();
    }

    // Newcomer filter
    if (_isNewcomerFilter != null) {
      filtered = filtered.where((member) {
        return (member['is_new_comer'] == true) == _isNewcomerFilter;
      }).toList();
    }

    // Sort alphabetically by first name, then last name
    filtered.sort((a, b) {
      final firstNameA = (a['first_name'] ?? '').toString().toLowerCase();
      final lastNameA = (a['last_name'] ?? '').toString().toLowerCase();
      final firstNameB = (b['first_name'] ?? '').toString().toLowerCase();
      final lastNameB = (b['last_name'] ?? '').toString().toLowerCase();

      // Compare by first name first
      final firstNameComparison = firstNameA.compareTo(firstNameB);
      if (firstNameComparison != 0) {
        return firstNameComparison;
      }
      // If first names are equal, compare by last name
      return lastNameA.compareTo(lastNameB);
    });

    return filtered;
  }

  int get _activeCount =>
      _members.where((m) => m['is_active'] == true).length;

  int get _newcomerCount =>
      _members.where((m) => m['is_new_comer'] == true).length;

  void _openMember(String memberId) {
    if (widget.hideAppBarAndBottomNav) {
      setState(() => _selectedMemberId = memberId);
    } else {
      Navigator.of(context).pushNamed(
        RouteNames.memberDetail.replaceAll(':id', memberId),
      );
    }
  }

  Widget _buildHeaderBanner(AppLocalizations? localizations) {
    return MemberFormUi.listHeaderBanner(
      context: context,
      title: localizations?.members ?? context.tr('Members'),
      subtitle: context.tr('Manage church members, roles, and profiles'),
      icon: Icons.people_outline,
      compactTop: widget.hideAppBarAndBottomNav,
    );
  }

  Widget _buildStatsRow() {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
        children: [
          MemberFormUi.statChip(
            context: context,
            label: context.tr('Total'),
            value: _isLoading ? '…' : '${_members.length}',
            icon: Icons.groups_outlined,
            color: AppColors.primary,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          MemberFormUi.statChip(
            context: context,
            label: context.tr('Active'),
            value: _isLoading ? '…' : '$_activeCount',
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          MemberFormUi.statChip(
            context: context,
            label: context.tr('Newcomers'),
            value: _isLoading ? '…' : '$_newcomerCount',
            icon: Icons.person_add_alt_1_outlined,
            color: AppColors.accent,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          MemberFormUi.statChip(
            context: context,
            label: context.tr('Showing'),
            value: _isLoading ? '…' : '${_filteredMembers.length}',
            icon: Icons.filter_list_outlined,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchToolbar(AppLocalizations? localizations) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        AppDimensions.spacingMD,
        AppDimensions.paddingMD,
        AppDimensions.spacingSM,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: localizations?.search ?? context.tr('Search members...'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: context.mic.surface,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _membersPage = 0;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  borderSide: BorderSide(color: context.mic.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  borderSide: BorderSide(color: context.mic.border),
                ),
              ),
              onChanged: (_) => setState(() => _membersPage = 0),
            ),
          ),
          SizedBox(width: AppDimensions.spacingSM),
          IconButton.filledTonal(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: context.tr('Filter'),
          ),
          SizedBox(width: AppDimensions.spacingSM),
          IconButton.filledTonal(
            onPressed: _isLoading ? null : _loadMembers,
            icon: const Icon(Icons.refresh),
            tooltip: localizations?.refresh ?? context.tr('Refresh'),
          ),
          if (widget.hideAppBarAndBottomNav) ...[
            SizedBox(width: AppDimensions.spacingSM),
            FilledButton.icon(
              onPressed: () => setState(() => _showAddMember = true),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(localizations?.addMember ?? context.tr('Add Member')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations? localizations) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.mic.surfaceTint.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              localizations?.noData ?? context.tr('No members found'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.mic.appBarForeground,
              ),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            if (!widget.hideAppBarAndBottomNav)
              FilledButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).pushNamed(
                    RouteNames.addMember,
                  );
                  if (result == true) _loadMembers();
                },
                icon: const Icon(Icons.add),
                label: Text(localizations?.addMember ?? context.tr('Add Member')),
              )
            else
              FilledButton.icon(
                onPressed: () => setState(() => _showAddMember = true),
                icon: const Icon(Icons.add),
                label: Text(localizations?.addMember ?? context.tr('Add Member')),
              ),
          ],
        ),
      ),
    );
  }

  String _memberInitials(String firstName, String lastName) {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    final initials = '$f$l';
    return initials.isEmpty ? 'M' : initials;
  }

  Widget _memberContactChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.mic.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final firstName = member['first_name']?.toString() ?? '';
    final lastName = member['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = member['email']?.toString() ?? '';
    final phone = member['phone']?.toString() ?? '';
    final role = member['role']?.toString() ?? 'member';
    final isActive = member['is_active'] == true;
    final isNewComer = member['is_new_comer'] == true;
    final memberId = member['id'].toString();
    final photoUrl = member['photo_url']?.toString();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final roleColor = MemberFormUi.roleColor(role);
    final initials = _memberInitials(firstName, lastName);

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        0,
        AppDimensions.paddingMD,
        AppDimensions.spacingSM,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            roleColor.withValues(alpha: 0.14),
            context.mic.surfaceTint.withValues(alpha: 0.35),
            context.mic.surface,
          ],
        ),
        border: Border.all(color: roleColor.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: roleColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openMember(memberId),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(color: roleColor, child: const SizedBox(width: 5)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingMD),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    roleColor,
                                    roleColor.withValues(alpha: 0.45),
                                  ],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: context.mic.surface,
                                backgroundImage:
                                    hasPhoto ? NetworkImage(photoUrl) : null,
                                child: hasPhoto
                                    ? null
                                    : Text(
                                        initials,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: roleColor,
                                        ),
                                      ),
                              ),
                            ),
                            if (isActive)
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: context.mic.surface,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 9,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: AppDimensions.spacingMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      fullName.isEmpty
                                          ? context.tr('Unnamed Member')
                                          : fullName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: context.mic.appBarForeground,
                                            letterSpacing: -0.2,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: roleColor.withValues(alpha: 0.7),
                                    size: 22,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  MemberFormUi.roleChip(context, role),
                                  if (isNewComer)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.accent
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.fiber_new_rounded,
                                            size: 14,
                                            color: AppColors.accent,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            context.tr('Newcomer'),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (!isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.error
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        context.tr('Inactive'),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (email.isNotEmpty || phone.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (email.isNotEmpty)
                                      _memberContactChip(
                                        icon: Icons.email_outlined,
                                        text: email,
                                        color: AppColors.info,
                                      ),
                                    if (phone.isNotEmpty)
                                      _memberContactChip(
                                        icon: Icons.phone_outlined,
                                        text: phone,
                                        color: AppColors.secondaryDark,
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopToolbar(AppLocalizations? localizations) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        side: BorderSide(color: context.mic.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      localizations?.search ?? context.tr('Search members...'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: context.mic.background,
                  isDense: true,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _membersPage = 0;
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMD),
                    borderSide: BorderSide(color: context.mic.border),
                  ),
                ),
                onChanged: (_) => setState(() => _membersPage = 0),
              ),
            ),
            SizedBox(width: AppDimensions.spacingSM),
            IconButton.filledTonal(
              onPressed: _showFilterDialog,
              icon: const Icon(Icons.tune),
              tooltip: context.tr('Filter'),
            ),
            SizedBox(width: AppDimensions.spacingSM),
            IconButton.filledTonal(
              onPressed: _isLoading ? null : _loadMembers,
              icon: const Icon(Icons.refresh),
              tooltip: localizations?.refresh ?? context.tr('Refresh'),
            ),
            SizedBox(width: AppDimensions.spacingSM),
            FilledButton.icon(
              onPressed: () => setState(() => _showAddMember = true),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(localizations?.addMember ?? context.tr('Add Member')),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _paginatedMembers {
    final members = _filteredMembers;
    final total = members.length;
    if (total == 0) return [];
    final maxPage = (total - 1) ~/ _membersRowsPerPage;
    final currentPage = _membersPage.clamp(0, maxPage);
    final startIndex = currentPage * _membersRowsPerPage;
    final endIndex = (startIndex + _membersRowsPerPage).clamp(0, total);
    return members.sublist(startIndex, endIndex);
  }

  int get _totalMemberPages {
    if (_filteredMembers.isEmpty) return 1;
    return (_filteredMembers.length / _membersRowsPerPage).ceil();
  }

  Widget _buildDesktopBody(AppLocalizations? localizations) {
    final theme = Theme.of(context);
    final pageItems = _paginatedMembers;

    return DesktopListWorkspace(
      isLoading: _isLoading,
      banner: DesktopHeroBanner(
        title: localizations?.members ?? context.tr('Members'),
        subtitle: context.tr('Manage church members, roles, and profiles'),
        icon: Icons.people_outline,
        accent: AppColors.primary,
        trailing: Text(
          '${_filteredMembers.length}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: context.mic.appBarForeground,
          ),
        ),
      ),
      stats: [
        DesktopStatChip(
          label: context.tr('Total'),
          value: _isLoading ? '…' : '${_members.length}',
          icon: Icons.groups_outlined,
        ),
        DesktopStatChip(
          label: context.tr('Active'),
          value: _isLoading ? '…' : '$_activeCount',
          icon: Icons.check_circle_outline,
          color: AppColors.success,
        ),
        DesktopStatChip(
          label: context.tr('Newcomers'),
          value: _isLoading ? '…' : '$_newcomerCount',
          icon: Icons.person_add_alt_1_outlined,
          color: AppColors.accent,
        ),
        DesktopStatChip(
          label: context.tr('Showing'),
          value: _isLoading ? '…' : '${_filteredMembers.length}',
          icon: Icons.filter_list_outlined,
          color: AppColors.secondary,
        ),
      ],
      toolbar: _buildDesktopToolbar(localizations),
      pagination: _filteredMembers.isEmpty
          ? null
          : DesktopPaginationBar(
              currentPage: _membersPage.clamp(0, _totalMemberPages - 1),
              totalPages: _totalMemberPages,
              itemLabel:
                  '${_filteredMembers.length} ${context.tr('Members').toLowerCase()}',
              onPrevious: _membersPage > 0
                  ? () => setState(() => _membersPage--)
                  : null,
              onNext: _membersPage < _totalMemberPages - 1
                  ? () => setState(() => _membersPage++)
                  : null,
            ),
      child: DesktopDataTableCard(
          emptyMessage: localizations?.noData ?? context.tr('No members found'),
          emptyIcon: Icons.people_outline,
          columns: [
            DataColumn(label: Text(context.tr('Member'))),
            DataColumn(label: Text(context.tr('Email'))),
            DataColumn(label: Text(context.tr('Phone'))),
            DataColumn(label: Text(context.tr('Role'))),
            DataColumn(label: Text(context.tr('Status'))),
            DataColumn(label: Text(context.tr('Actions'))),
          ],
          rows: pageItems.map((member) {
            final firstName = member['first_name']?.toString() ?? '';
            final lastName = member['last_name']?.toString() ?? '';
            final fullName = '$firstName $lastName'.trim();
            final email = member['email']?.toString() ?? '—';
            final phone = member['phone']?.toString() ?? '—';
            final role = member['role']?.toString() ?? 'member';
            final isActive = member['is_active'] == true;
            final memberId = member['id'].toString();
            final photoUrl = member['photo_url']?.toString();
            final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
            final roleColor = MemberFormUi.roleColor(role);
            final initials = _memberInitials(firstName, lastName);

            return DataRow(
              cells: [
                DataCell(
                  InkWell(
                    onTap: () => _openMember(memberId),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: roleColor.withValues(alpha: 0.15),
                          backgroundImage:
                              hasPhoto ? NetworkImage(photoUrl) : null,
                          child: hasPhoto
                              ? null
                              : Text(
                                  initials,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: roleColor,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                        SizedBox(width: AppDimensions.spacingSM),
                        Expanded(
                          child: Text(
                            fullName.isEmpty
                                ? context.tr('Unnamed member')
                                : fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(email, overflow: TextOverflow.ellipsis)),
                DataCell(Text(phone, overflow: TextOverflow.ellipsis)),
                DataCell(MemberFormUi.roleChip(context, role)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isActive ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isActive
                          ? context.tr('Active')
                          : context.tr('Inactive'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        tooltip: context.tr('View'),
                        onPressed: () => _openMember(memberId),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: context.tr('Edit'),
                        onPressed: () =>
                            setState(() => _editMemberId = memberId),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
    );
  }

  Widget _buildMobileBody(AppLocalizations? localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderBanner(localizations),
        SizedBox(height: AppDimensions.spacingMD),
        _buildStatsRow(),
        _buildSearchToolbar(localizations),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredMembers.isEmpty
              ? _buildEmptyState(localizations)
              : RefreshIndicator(
                  onRefresh: _loadMembers,
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: AppDimensions.spacingXL,
                    ),
                    itemCount: _filteredMembers.length,
                    itemBuilder: (context, index) =>
                        _buildMemberCard(_filteredMembers[index]),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDesktop = isDesktopEmbedded(
      context,
      hideAppBar: widget.hideAppBarAndBottomNav,
    );

    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(localizations?.members ?? context.tr('Members')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                  tooltip: context.tr('Filter'),
                ),
              ],
            ),
      body: Stack(
        children: [
          if (isDesktop)
            Positioned.fill(child: _buildDesktopBody(localizations))
          else
            _buildMobileBody(localizations),
          if (widget.hideAppBarAndBottomNav && _selectedMemberId != null)
            Positioned.fill(
              child: Material(
                elevation: 8,
                child: MemberProfilePage(
                  memberId: _selectedMemberId!,
                  onClose: (result) {
                    setState(() => _selectedMemberId = null);
                    if (result == true) _loadMembers();
                  },
                  onEditRequested: (memberId) {
                    setState(() => _editMemberId = memberId);
                  },
                ),
              ),
            ),
          if (widget.hideAppBarAndBottomNav && _showAddMember)
            Positioned.fill(
              child: Material(
                elevation: 8,
                child: AddMemberPage(
                  onClose: (result) {
                    setState(() => _showAddMember = false);
                    if (result == true) _loadMembers();
                  },
                ),
              ),
            ),
          if (widget.hideAppBarAndBottomNav && _editMemberId != null)
            Positioned.fill(
              child: Material(
                elevation: 8,
                child: EditMemberPage(
                  memberId: _editMemberId!,
                  onClose: (result) {
                    setState(() {
                      _editMemberId = null;
                      if (result == true) _selectedMemberId = null;
                    });
                    if (result == true) _loadMembers();
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: widget.hideAppBarAndBottomNav
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.of(
                  context,
                  rootNavigator: widget.hideAppBarAndBottomNav,
                ).pushNamed(RouteNames.addMember);
                if (result == true) _loadMembers();
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(localizations?.addMember ?? context.tr('Add Member')),
            ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Filter Members')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: Text(context.tr('Active Only')),
                  value: _isActiveFilter == true,
                  onChanged: (value) {
                    setDialogState(() {
                      _isActiveFilter = value == true ? true : null;
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text(context.tr('Newcomers Only')),
                  value: _isNewcomerFilter == true,
                  onChanged: (value) {
                    setDialogState(() {
                      _isNewcomerFilter = value == true ? true : null;
                    });
                  },
                ),
                Divider(),
                // Role filter
                ListTile(
                  title: Text(context.tr('Role')),
                  subtitle: Text(
                    _selectedRole != null
                        ? _selectedRole!.substring(0, 1).toUpperCase() +
                              _selectedRole!.substring(1)
                        : 'All roles',
                  ),
                  trailing: Icon(Icons.arrow_drop_down),
                  onTap: () {
                    _showRolePicker(context, setDialogState);
                  },
                ),
                if (_selectedRole != null)
                  ListTile(
                    leading: Icon(Icons.clear),
                    title: Text(context.tr('Clear Role Filter')),
                    onTap: () {
                      setDialogState(() {
                        _selectedRole = null;
                      });
                    },
                  ),
                Divider(),
                // Birthday month picker
                ListTile(
                  title: Text(context.tr('Birthday Month')),
                  subtitle: Text(
                    _selectedBirthdayMonth != null
                        ? _getMonthName(int.parse(_selectedBirthdayMonth!))
                        : 'All months',
                  ),
                  trailing: Icon(Icons.arrow_drop_down),
                  onTap: () {
                    _showBirthdayMonthPicker(context, setDialogState);
                  },
                ),
                if (_selectedBirthdayMonth != null)
                  ListTile(
                    leading: Icon(Icons.clear),
                    title: Text(context.tr('Clear Birthday Filter')),
                    onTap: () {
                      setDialogState(() {
                        _selectedBirthdayMonth = null;
                      });
                    },
                  ),
                Divider(),
                // Profession filter
                ListTile(
                  title: Text(context.tr('Profession')),
                  subtitle: Text(
                    _selectedProfession != null
                        ? MemberConstants.getProfessionLabel(
                            _selectedProfession,
                          )
                        : 'All professions',
                  ),
                  trailing: Icon(Icons.arrow_drop_down),
                  onTap: () {
                    _showProfessionPicker(context, setDialogState);
                  },
                ),
                if (_selectedProfession != null)
                  ListTile(
                    leading: Icon(Icons.clear),
                    title: Text(context.tr('Clear Profession Filter')),
                    onTap: () {
                      setDialogState(() {
                        _selectedProfession = null;
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDepartment = null;
                  _selectedBirthdayMonth = null;
                  _isActiveFilter = null;
                  _selectedRole = null;
                  _selectedProfession = null;
                  _isNewcomerFilter = null;
                });
                Navigator.pop(context);
                _loadMembers();
              },
              child: Text(context.tr('Clear All')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadMembers();
              },
              child: Text(context.tr('Apply')),
            ),
          ],
        ),
      ),
    );
  }

  void _showBirthdayMonthPicker(
    BuildContext context,
    StateSetter setDialogState,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Birthday Month',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = (index + 1).toString().padLeft(2, '0');
                final isSelected = _selectedBirthdayMonth == month;
                return InkWell(
                  onTap: () {
                    setDialogState(() {
                      _selectedBirthdayMonth = isSelected ? null : month;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : context.mic.background,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : context.mic.border,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSM,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getMonthName(index + 1),
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.textLight
                              : context.mic.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  void _showRolePicker(BuildContext context, StateSetter setDialogState) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Role',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            ListTile(
              title: Text(context.tr('All Roles')),
              leading: Icon(Icons.clear_all),
              onTap: () {
                setDialogState(() {
                  _selectedRole = null;
                });
                Navigator.pop(context);
              },
            ),
            Divider(),
            ListTile(
              title: Text(context.tr('Admin')),
              leading: Icon(Icons.admin_panel_settings, color: AppColors.error),
              trailing: _selectedRole == 'admin' ? Icon(Icons.check) : null,
              onTap: () {
                setDialogState(() {
                  _selectedRole = 'admin';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(context.tr('Leader')),
              leading: Icon(Icons.leaderboard, color: AppColors.warning),
              trailing: _selectedRole == 'leader' ? Icon(Icons.check) : null,
              onTap: () {
                setDialogState(() {
                  _selectedRole = 'leader';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(context.tr('Member')),
              leading: Icon(Icons.person, color: context.mic.textSecondary),
              trailing: _selectedRole == 'member' ? Icon(Icons.check) : null,
              onTap: () {
                setDialogState(() {
                  _selectedRole = 'member';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(context.tr('Worker')),
              leading: Icon(Icons.work, color: AppColors.primary),
              trailing: _selectedRole == 'worker' ? Icon(Icons.check) : null,
              onTap: () {
                setDialogState(() {
                  _selectedRole = 'worker';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(context.tr('Sympathiser')),
              leading: Icon(Icons.favorite, color: AppColors.accent),
              trailing: _selectedRole == 'sympathiser'
                  ? Icon(Icons.check)
                  : null,
              onTap: () {
                setDialogState(() {
                  _selectedRole = 'sympathiser';
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProfessionPicker(BuildContext context, StateSetter setDialogState) {
    final professionOptions = MemberConstants.getProfessionOptions();

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Profession',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            ListTile(
              title: Text(context.tr('All Professions')),
              leading: Icon(Icons.clear_all),
              onTap: () {
                setDialogState(() {
                  _selectedProfession = null;
                });
                Navigator.pop(context);
              },
            ),
            Divider(),
            ...professionOptions.map((option) {
              final value = option['value']!;
              final label = option['label']!;
              final isSelected = _selectedProfession == value;

              return ListTile(
                title: Text(label),
                leading: Icon(Icons.work_outline, color: AppColors.primary),
                trailing: isSelected ? Icon(Icons.check) : null,
                onTap: () {
                  setDialogState(() {
                    _selectedProfession = isSelected ? null : value;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
