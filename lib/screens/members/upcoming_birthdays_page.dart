import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../services/member_service.dart';
import '../desktop/desktop_shell_scope.dart';

/// Page displaying members with upcoming birthdays (current month and next month)
class UpcomingBirthdaysPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  UpcomingBirthdaysPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<UpcomingBirthdaysPage> createState() => _UpcomingBirthdaysPageState();
}

const double _kBirthdaysDesktopBreakpoint = 700;
const double _kBirthdaysDesktopMaxWidth = 1000;

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
        final date = _parseBirthday(member['birthday']);
        if (date == null) return false;
        try {
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
          final dateA = _parseBirthday(a['birthday']);
          final dateB = _parseBirthday(b['birthday']);
          if (dateA == null || dateB == null) return 0;
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

      if (!mounted) return;
      setState(() {
        _members = upcomingBirthdays;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading birthdays: $e')),
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

  /// Calendar date only (no time-of-day), for consistent day comparisons.
  DateTime _calendarDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime? _parseBirthday(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return _calendarDate(value);
      return _calendarDate(DateTime.parse(value.toString()));
    } catch (_) {
      return null;
    }
  }

  /// Next birthday on or after [reference]'s calendar day (this year or next).
  DateTime _nextBirthdayOccurrence(DateTime birthday, DateTime reference) {
    final today = _calendarDate(reference);
    var next = DateTime(today.year, birthday.month, birthday.day);
    if (next.isBefore(today)) {
      next = DateTime(today.year + 1, birthday.month, birthday.day);
    }
    return next;
  }

  int _daysUntilNextBirthday(DateTime birthday, DateTime now) {
    final today = _calendarDate(now);
    return _nextBirthdayOccurrence(birthday, now).difference(today).inDays;
  }

  String _formatBirthday(DateTime birthday, DateTime now) {
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

    final next = _nextBirthdayOccurrence(birthday, now);
    final days = _daysUntilNextBirthday(birthday, now);

    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';

    return '${monthNames[next.month - 1]} ${next.day}';
  }

  String _getDaysUntilBirthday(DateTime birthday, DateTime now) {
    final days = _daysUntilNextBirthday(birthday, now);
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return '$days days';
  }

  void _openMemberDetail(Map<String, dynamic> member) {
    final memberId = member['id']?.toString();
    if (memberId == null) return;
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.memberDetail, memberId);
    } else {
      Navigator.of(
        context,
      ).pushNamed(RouteNames.memberDetail.replaceAll(':id', memberId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final now = DateTime.now();
    final isDesktop =
        widget.hideAppBarAndBottomNav &&
        MediaQuery.sizeOf(context).width >= _kBirthdaysDesktopBreakpoint;

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(localizations?.birthdays ?? 'Upcoming Birthdays'),
            ),
      body: isDesktop
          ? _buildDesktopBody(context, now)
          : _buildMobileBody(context, now),
    );
  }

  Widget _buildDesktopBody(BuildContext context, DateTime now) {
    final localizations = AppLocalizations.of(context);
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
    final currentMonth = now.month;
    final nextMonth = (now.month % 12) + 1;

    return RefreshIndicator(
      onRefresh: _loadUpcomingBirthdays,
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _kBirthdaysDesktopMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 400),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: localizations?.search ?? 'Search',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(width: AppDimensions.spacingMD),
                    IconButton(
                      icon: Icon(Icons.refresh),
                      onPressed: _isLoading ? null : _loadUpcomingBirthdays,
                      tooltip: context.tr('Refresh'),
                    ),
                  ],
                ),
                SizedBox(height: AppDimensions.spacingSM),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMD,
                    vertical: AppDimensions.spacingSM,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      SizedBox(width: AppDimensions.spacingSM),
                      Expanded(
                        child: Text(
                          'Showing birthdays from ${monthNames[currentMonth - 1]} ${now.day} to ${monthNames[nextMonth - 1]}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppDimensions.spacingMD),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _filteredMembers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cake_outlined,
                                size: 64,
                                color: context.mic.textSecondary,
                              ),
                              SizedBox(height: AppDimensions.spacingMD),
                              Text(
                                'No upcoming birthdays found',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: context.mic.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : Card(
                          clipBehavior: Clip.antiAlias,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
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
                                          label: Text(context.tr('Birthday')),
                                        ),
                                        DataColumn(
                                          label: Text(context.tr('Days')),
                                        ),
                                      ],
                                      rows: _filteredMembers.map((member) {
                                        final name =
                                            '${member['first_name']} ${member['last_name']}';
                                        final email =
                                            member['email']?.toString() ?? '';
                                        final birthday = _parseBirthday(
                                          member['birthday'],
                                        );
                                        final birthdayText = birthday != null
                                            ? _formatBirthday(birthday, now)
                                            : '—';
                                        final daysText = birthday != null
                                            ? _getDaysUntilBirthday(
                                                birthday,
                                                now,
                                              )
                                            : '—';
                                        return DataRow(
                                          onSelectChanged: (_) =>
                                              _openMemberDetail(member),
                                          cells: [
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor:
                                                        AppColors.primary,
                                                    child: Text(
                                                      name.isNotEmpty
                                                          ? name[0]
                                                                .toUpperCase()
                                                          : '?',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width:
                                                        AppDimensions.spacingSM,
                                                  ),
                                                  Text(name),
                                                ],
                                              ),
                                            ),
                                            DataCell(Text(email)),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.cake,
                                                    size: 18,
                                                    color: AppColors.accent,
                                                  ),
                                                  SizedBox(
                                                    width:
                                                        AppDimensions.spacingXS,
                                                  ),
                                                  Text(
                                                    birthdayText,
                                                    style: TextStyle(
                                                      color: AppColors.accent,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                daysText,
                                                style: TextStyle(
                                                  color:
                                                      context.mic.textSecondary,
                                                  fontSize: 13,
                                                ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context, DateTime now) {
    final localizations = AppLocalizations.of(context);
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
    final currentMonth = now.month;
    final nextMonth = (now.month % 12) + 1;

    return RefreshIndicator(
      onRefresh: _loadUpcomingBirthdays,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: localizations?.search ?? 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary),
                SizedBox(width: AppDimensions.spacingSM),
                Expanded(
                  child: Text(
                    'Showing birthdays from ${monthNames[currentMonth - 1]} ${now.day} to ${monthNames[nextMonth - 1]}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredMembers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cake_outlined,
                          size: 64,
                          color: context.mic.textSecondary,
                        ),
                        SizedBox(height: AppDimensions.spacingMD),
                        Text(
                          'No upcoming birthdays found',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: context.mic.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingMD,
                    ),
                    itemCount: _filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = _filteredMembers[index];
                      final name =
                          '${member['first_name']} ${member['last_name']}';
                      final email = member['email']?.toString() ?? '';
                      final birthday = _parseBirthday(member['birthday']);

                      return Card(
                        margin: EdgeInsets.only(
                          bottom: AppDimensions.spacingSM,
                        ),
                        child: InkWell(
                          onTap: () => _openMemberDetail(member),
                          child: Padding(
                            padding: EdgeInsets.all(AppDimensions.paddingMD),
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
                                SizedBox(width: AppDimensions.spacingMD),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (email.isNotEmpty) ...[
                                        SizedBox(
                                          height: AppDimensions.spacingXS,
                                        ),
                                        Text(
                                          email,
                                          style: TextStyle(
                                            color: context.mic.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                      if (birthday != null) ...[
                                        SizedBox(
                                          height: AppDimensions.spacingXS,
                                        ),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.cake,
                                              size: 16,
                                              color: AppColors.accent,
                                            ),
                                            SizedBox(
                                              width: AppDimensions.spacingXS,
                                            ),
                                            Text(
                                              _formatBirthday(birthday, now),
                                              style: TextStyle(
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(
                                              width: AppDimensions.spacingSM,
                                            ),
                                            Text(
                                              '(${_getDaysUntilBirthday(birthday, now)})',
                                              style: TextStyle(
                                                color: context.mic.textSecondary,
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
    );
  }
}
