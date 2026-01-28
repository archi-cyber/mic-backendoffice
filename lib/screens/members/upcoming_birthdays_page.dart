import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../services/member_service.dart';

/// Page displaying members with upcoming birthdays (current month and next month)
class UpcomingBirthdaysPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const UpcomingBirthdaysPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<UpcomingBirthdaysPage> createState() => _UpcomingBirthdaysPageState();
}

class _UpcomingBirthdaysPageState extends State<UpcomingBirthdaysPage> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUpcomingBirthdays();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUpcomingBirthdays() async {
    setState(() => _isLoading = true);
    try {
      // Load all members with birthdays
      final allMembers = await MemberService.getMembers();

      // Filter for upcoming birthdays (current month from today, and next month)
      final now = DateTime.now();
      final currentMonth = now.month;
      final nextMonth = (now.month % 12) + 1;
      final currentDay = now.day;

      final upcomingBirthdays = allMembers.where((member) {
        final birthday = member['birthday'];
        if (birthday == null) return false;
        try {
          final date = DateTime.parse(birthday.toString());
          final birthdayMonth = date.month;
          final birthdayDay = date.day;

          // Current month: show birthdays from today onward
          if (birthdayMonth == currentMonth) {
            return birthdayDay >= currentDay;
          }
          // Next month: show all birthdays
          if (birthdayMonth == nextMonth) {
            return true;
          }
          return false;
        } catch (e) {
          return false;
        }
      }).toList();

      // Sort by birthday (day of month), then alphabetically by name
      upcomingBirthdays.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['birthday'].toString());
          final dateB = DateTime.parse(b['birthday'].toString());
          // First sort by month, then by day
          if (dateA.month != dateB.month) {
            return dateA.month.compareTo(dateB.month);
          }
          final dayComparison = dateA.day.compareTo(dateB.day);
          if (dayComparison != 0) {
            return dayComparison;
          }
          // If same birthday, sort alphabetically by name
          final firstNameA = (a['first_name'] ?? '').toString().toLowerCase();
          final lastNameA = (a['last_name'] ?? '').toString().toLowerCase();
          final firstNameB = (b['first_name'] ?? '').toString().toLowerCase();
          final lastNameB = (b['last_name'] ?? '').toString().toLowerCase();

          final firstNameComparison = firstNameA.compareTo(firstNameB);
          if (firstNameComparison != 0) {
            return firstNameComparison;
          }
          return lastNameA.compareTo(lastNameB);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        _members = upcomingBirthdays;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading birthdays: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchController.text.isEmpty) {
      return _members;
    }

    final query = _searchController.text.toLowerCase();
    return _members.where((member) {
      final name = '${member['first_name']} ${member['last_name']}'
          .toLowerCase();
      final email = (member['email'] ?? '').toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  String _formatBirthday(DateTime birthday, DateTime now) {
    final month = birthday.month;
    final day = birthday.day;
    final monthNames = [
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

    // If birthday is today
    if (month == now.month && day == now.day) {
      return 'Today';
    }

    // If birthday is tomorrow
    final tomorrow = now.add(const Duration(days: 1));
    if (month == tomorrow.month && day == tomorrow.day) {
      return 'Tomorrow';
    }

    return '${monthNames[month - 1]} $day';
  }

  String _getDaysUntilBirthday(DateTime birthday, DateTime now) {
    // Calculate next occurrence of birthday
    var nextBirthday = DateTime(now.year, birthday.month, birthday.day);
    if (nextBirthday.isBefore(now) || nextBirthday.isAtSameMomentAs(now)) {
      nextBirthday = DateTime(now.year + 1, birthday.month, birthday.day);
    }

    final difference = nextBirthday.difference(now).inDays;
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else {
      return '$difference days';
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final now = DateTime.now();
    final currentMonth = now.month;
    final nextMonth = (now.month % 12) + 1;
    final monthNames = [
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

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(localizations?.birthdays ?? 'Upcoming Birthdays'),
            ),
      body: RefreshIndicator(
        onRefresh: _loadUpcomingBirthdays,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: localizations?.search ?? 'Search',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            // Info banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMD,
              ),
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: AppDimensions.spacingSM),
                  Expanded(
                    child: Text(
                      'Showing birthdays from ${monthNames[currentMonth - 1]} ${now.day} to ${monthNames[nextMonth - 1]}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            // Members list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMembers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cake_outlined,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: AppDimensions.spacingMD),
                          Text(
                            'No upcoming birthdays found',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingMD,
                      ),
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        final name =
                            '${member['first_name']} ${member['last_name']}';
                        final email = member['email']?.toString() ?? '';
                        final birthdayStr = member['birthday']?.toString();
                        DateTime? birthday;
                        if (birthdayStr != null) {
                          try {
                            birthday = DateTime.parse(birthdayStr);
                          } catch (e) {
                            birthday = null;
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: AppDimensions.spacingSM,
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                RouteNames.memberDetail.replaceAll(
                                  ':id',
                                  member['id'].toString(),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(
                                AppDimensions.paddingMD,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary,
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                    ),
                                  ),
                                  const SizedBox(
                                    width: AppDimensions.spacingMD,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (email.isNotEmpty) ...[
                                          const SizedBox(
                                            height: AppDimensions.spacingXS,
                                          ),
                                          Text(
                                            email,
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                        if (birthday != null) ...[
                                          const SizedBox(
                                            height: AppDimensions.spacingXS,
                                          ),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.cake,
                                                size: 16,
                                                color: AppColors.accent,
                                              ),
                                              const SizedBox(
                                                width: AppDimensions.spacingXS,
                                              ),
                                              Text(
                                                _formatBirthday(birthday, now),
                                                style: TextStyle(
                                                  color: AppColors.accent,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppDimensions.spacingSM,
                                              ),
                                              Text(
                                                '(${_getDaysUntilBirthday(birthday, now)})',
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
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
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
