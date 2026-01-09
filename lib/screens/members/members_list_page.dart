import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/member_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../services/member_service.dart';

/// Members list with search and filters
class MembersListPage extends StatefulWidget {
  const MembersListPage({super.key});

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
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading members: $e')));
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

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final firstName = member['first_name']?.toString() ?? '';
    final lastName = member['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = member['email']?.toString() ?? '';
    final role = member['role']?.toString() ?? 'member';
    final isActive = member['is_active'] == true;
    final memberId = member['id'].toString();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.spacingSM,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(RouteNames.memberDetail.replaceAll(':id', memberId));
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Row(
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _getRoleColor(role).withValues(alpha: 0.2),
                    child: Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : 'M',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(role),
                      ),
                    ),
                  ),
                  // Active status indicator
                  if (isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppDimensions.spacingMD),
              // Member info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and role
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fullName.isEmpty ? 'Unnamed Member' : fullName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingXS),
                    // Contact info
                    if (email.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 8),

                    if (!isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              _buildRoleChip(role),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.error;
      case 'leader':
        return AppColors.warning;
      case 'worker':
        return AppColors.primary;
      case 'sympathiser':
        return AppColors.textSecondary;
      case 'member':
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildRoleChip(String role) {
    Color chipColor;
    String label;
    IconData icon;
    switch (role) {
      case 'admin':
        chipColor = AppColors.error;
        label = 'Admin';
        icon = Icons.admin_panel_settings;
        break;
      case 'leader':
        chipColor = AppColors.warning;
        label = 'Leader';
        icon = Icons.leaderboard;
        break;
      case 'worker':
        chipColor = AppColors.primary;
        label = 'Worker';
        icon = Icons.work;
        break;
      case 'sympathiser':
        chipColor = AppColors.textSecondary;
        label = 'Sympathiser';
        icon = Icons.favorite;
        break;
      case 'member':
      default:
        chipColor = AppColors.textSecondary;
        label = 'Member';
        icon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    final memberCount = _filteredMembers.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${localizations?.members ?? 'Members'} ($memberCount)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: localizations?.search ?? 'Search members...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Members list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMembers.isEmpty
                ? Center(
                    child: Text(localizations?.noData ?? 'No members found'),
                  )
                : ListView.builder(
                    itemCount: _filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = _filteredMembers[index];
                      return _buildMemberCard(member);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate to add member page and wait for result
          final result = await Navigator.of(
            context,
          ).pushNamed(RouteNames.addMember);
          // If member was created (result is true), reload the list
          if (result == true) {
            _loadMembers();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Members'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('Active Only'),
                  value: _isActiveFilter == true,
                  onChanged: (value) {
                    setDialogState(() {
                      _isActiveFilter = value == true ? true : null;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Newcomers Only'),
                  value: _isNewcomerFilter == true,
                  onChanged: (value) {
                    setDialogState(() {
                      _isNewcomerFilter = value == true ? true : null;
                    });
                  },
                ),
                const Divider(),
                // Role filter
                ListTile(
                  title: const Text('Role'),
                  subtitle: Text(
                    _selectedRole != null
                        ? _selectedRole!.substring(0, 1).toUpperCase() +
                              _selectedRole!.substring(1)
                        : 'All roles',
                  ),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () {
                    _showRolePicker(context, setDialogState);
                  },
                ),
                if (_selectedRole != null)
                  ListTile(
                    leading: const Icon(Icons.clear),
                    title: const Text('Clear Role Filter'),
                    onTap: () {
                      setDialogState(() {
                        _selectedRole = null;
                      });
                    },
                  ),
                const Divider(),
                // Birthday month picker
                ListTile(
                  title: const Text('Birthday Month'),
                  subtitle: Text(
                    _selectedBirthdayMonth != null
                        ? _getMonthName(int.parse(_selectedBirthdayMonth!))
                        : 'All months',
                  ),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () {
                    _showBirthdayMonthPicker(context, setDialogState);
                  },
                ),
                if (_selectedBirthdayMonth != null)
                  ListTile(
                    leading: const Icon(Icons.clear),
                    title: const Text('Clear Birthday Filter'),
                    onTap: () {
                      setDialogState(() {
                        _selectedBirthdayMonth = null;
                      });
                    },
                  ),
                const Divider(),
                // Profession filter
                ListTile(
                  title: const Text('Profession'),
                  subtitle: Text(
                    _selectedProfession != null
                        ? MemberConstants.getProfessionLabel(
                            _selectedProfession,
                          )
                        : 'All professions',
                  ),
                  trailing: const Icon(Icons.arrow_drop_down),
                  onTap: () {
                    _showProfessionPicker(context, setDialogState);
                  },
                ),
                if (_selectedProfession != null)
                  ListTile(
                    leading: const Icon(Icons.clear),
                    title: const Text('Clear Profession Filter'),
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
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadMembers();
              },
              child: const Text('Apply'),
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
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Birthday Month',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.background,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
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
                              : AppColors.textPrimary,
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
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Role',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            ListTile(
              title: const Text('All Roles'),
              leading: const Icon(Icons.clear_all),
              onTap: () {
                setDialogState(() {
                  _selectedRole = null;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('Admin'),
              leading: const Icon(
                Icons.admin_panel_settings,
                color: AppColors.error,
              ),
              trailing: _selectedRole == 'admin'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                setDialogState(() {
                  _selectedRole = 'admin';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Leader'),
              leading: const Icon(Icons.leaderboard, color: AppColors.warning),
              trailing: _selectedRole == 'leader'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                setDialogState(() {
                  _selectedRole = 'leader';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Member'),
              leading: const Icon(Icons.person, color: AppColors.textSecondary),
              trailing: _selectedRole == 'member'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                setDialogState(() {
                  _selectedRole = 'member';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Worker'),
              leading: const Icon(Icons.work, color: AppColors.primary),
              trailing: _selectedRole == 'worker'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                setDialogState(() {
                  _selectedRole = 'worker';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Sympathiser'),
              leading: const Icon(Icons.favorite, color: AppColors.accent),
              trailing: _selectedRole == 'sympathiser'
                  ? const Icon(Icons.check)
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
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Profession',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            ListTile(
              title: const Text('All Professions'),
              leading: const Icon(Icons.clear_all),
              onTap: () {
                setDialogState(() {
                  _selectedProfession = null;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ...professionOptions.map((option) {
              final value = option['value']!;
              final label = option['label']!;
              final isSelected = _selectedProfession == value;

              return ListTile(
                title: Text(label),
                leading: const Icon(
                  Icons.work_outline,
                  color: AppColors.primary,
                ),
                trailing: isSelected ? const Icon(Icons.check) : null,
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
