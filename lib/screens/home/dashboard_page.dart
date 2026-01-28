import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../services/supabase_service.dart';
import '../../services/finance_service.dart';

/// Dashboard with summary cards
class DashboardPage extends StatefulWidget {
  /// When true (e.g. desktop layout), no app bar or bottom nav is shown.
  final bool hideAppBarAndBottomNav;

  const DashboardPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _upcomingSessions = 0;
  int _upcomingEvents = 0;
  int _tasks = 0;
  int _birthdays = 0;
  int _members = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();

      // Load upcoming sessions from trainings (next 5 weeks = 35 days)
      final sessionsEndDate = now.add(const Duration(days: 35));
      final sessions = await SupabaseService.client
          .from('sessions')
          .select()
          .not('class_id', 'is', null) // Only sessions from trainings
          .gte('session_date', now.toIso8601String())
          .lte('session_date', sessionsEndDate.toIso8601String());
      final upcomingSessionsCount = (sessions as List).length;

      // Load upcoming events (all events after current date)
      // Filter for active events where event_date is after today
      // Use tomorrow's start to exclude today's events
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrowStart = todayStart.add(const Duration(days: 1));
      final events = await SupabaseService.client
          .from('events')
          .select()
          .eq('is_active', true)
          .gte('event_date', tomorrowStart.toIso8601String());
      final upcomingEventsCount = (events as List).length;

      // Load task count (pending/in-progress) - only select id for efficiency
      final tasksList = await SupabaseService.client
          .from('tasks')
          .select('id')
          .inFilter('status', ['pending', 'in_progress']);
      final tasksCount = (tasksList as List).length;

      // Load total active members count - only select id for efficiency
      final membersList = await SupabaseService.client
          .from('members')
          .select('id')
          .eq('is_active', true);
      final membersCount = (membersList as List).length;

      // Load upcoming birthdays (current month, day >= today)
      // Get all members with birthdays (active and inactive) and filter by month and day
      final allMembers = await SupabaseService.client
          .from('members')
          .select('id, birthday')
          .not('birthday', 'is', null);

      // Filter to only include birthdays where:
      // - birthday month matches current month
      // - birthday day is >= current day
      final upcomingBirthdays = (allMembers as List).where((member) {
        if (member['birthday'] == null) return false;
        try {
          final birthdayStr = member['birthday'].toString();
          // Parse the birthday date (format: YYYY-MM-DD)
          final birthday = DateTime.parse(birthdayStr);
          // Check if birthday month matches current month
          // and birthday day is >= current day
          return birthday.month == now.month && birthday.day >= now.day;
        } catch (e) {
          return false;
        }
      }).toList();
      final birthdaysCount = upcomingBirthdays.length;

      setState(() {
        _upcomingSessions = upcomingSessionsCount;
        _upcomingEvents = upcomingEventsCount;
        _tasks = tasksCount;
        _birthdays = birthdaysCount;
        _members = membersCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.errorLoadingDashboard ??
                  'Error loading dashboard: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(localizations?.dashboard ?? 'Dashboard'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    Navigator.of(context).pushNamed(RouteNames.notifications);
                  },
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards Row
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title:
                          localizations?.upcomingSessions ??
                          'Upcoming Sessions',
                      value: _isLoading ? '...' : '$_upcomingSessions',
                      icon: Icons.event_outlined,
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.of(context).pushNamed(RouteNames.classes);
                      },
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    child: _SummaryCard(
                      title: localizations?.upcomingEvents ?? 'Upcoming Events',
                      value: _isLoading ? '...' : '$_upcomingEvents',
                      icon: Icons.calendar_today_outlined,
                      color: AppColors.secondary,
                      onTap: () {
                        Navigator.of(context).pushNamed(RouteNames.events);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: localizations?.tasks ?? 'Tasks',
                      value: _isLoading ? '...' : '$_tasks',
                      icon: Icons.task_outlined,
                      color: AppColors.warning,
                      onTap: () {
                        Navigator.of(context).pushNamed(RouteNames.tasks);
                      },
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    child: _SummaryCard(
                      title: localizations?.birthdays ?? 'Birthdays',
                      value: _isLoading ? '...' : '$_birthdays',
                      icon: Icons.cake_outlined,
                      color: AppColors.accent,
                      onTap: () {
                        // Navigate to upcoming birthdays page
                        Navigator.of(
                          context,
                        ).pushNamed(RouteNames.upcomingBirthdays);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingXL),
              // Quick Actions
              Text(
                localizations?.quickActions ?? 'Quick Actions',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppDimensions.spacingMD,
                mainAxisSpacing: AppDimensions.spacingMD,
                childAspectRatio: 1.4,
                children: [
                  _QuickActionCard(
                    title: localizations?.members ?? 'Members',
                    icon: Icons.people_outlined,
                    value: _isLoading ? '...' : '$_members',
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.members);
                    },
                  ),
                  _QuickActionCard(
                    title: localizations?.departments ?? 'Departments',
                    icon: Icons.business_outlined,
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.departments);
                    },
                  ),
                  _QuickActionCard(
                    title: localizations?.classes ?? 'Trainings',
                    icon: Icons.class_outlined,
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.classes);
                    },
                  ),
                  _QuickActionCard(
                    title: localizations?.reports ?? 'Reports',
                    icon: Icons.assessment_outlined,
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.reports);
                    },
                  ),
                  _QuickActionCard(
                    title:
                        localizations?.churchAttendance ?? 'Church Attendance',
                    icon: Icons.church,
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushNamed(RouteNames.churchAttendanceList);
                    },
                  ),
                  _QuickActionCard(
                    title: localizations?.sundaySchool ?? 'Sunday School',
                    icon: Icons.school,
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushNamed(RouteNames.sundaySchoolAttendanceList);
                    },
                  ),
                  _QuickActionCard(
                    title: localizations?.visitors ?? 'Visitors',
                    icon: Icons.person_add_outlined,
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.visitors);
                    },
                  ),
                  _QuickActionCard(
                    title: localizations?.teachings ?? 'Teachings',
                    icon: Icons.menu_book_outlined,
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.teachings);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.hideAppBarAndBottomNav
          ? null
          : _BottomNavigationBar(),
    );
  }
}

/// Summary card widget
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 32),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick action card widget
class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? value;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: AppColors.primary),
                  if (value != null) ...[
                    const SizedBox(width: AppDimensions.spacingSM),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        value!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 13),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation bar
class _BottomNavigationBar extends StatefulWidget {
  const _BottomNavigationBar();

  @override
  State<_BottomNavigationBar> createState() => _BottomNavigationBarState();
}

class _BottomNavigationBarState extends State<_BottomNavigationBar> {
  bool _isFinanceLeader = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFinanceAccess();
  }

  Future<void> _checkFinanceAccess() async {
    final isFinanceLeader = await FinanceService.isFinanceLeader();
    if (mounted) {
      setState(() {
        _isFinanceLeader = isFinanceLeader;
        _isLoading = false;
      });
    }
  }

  void _handleNavigation(int index) {
    if (_isFinanceLeader) {
      // With finance: Home, Members, Finance, Chat, Settings
      switch (index) {
        case 0:
          Navigator.of(context).pushReplacementNamed(RouteNames.dashboard);
          break;
        case 1:
          Navigator.of(context).pushNamed(RouteNames.members);
          break;
        case 2:
          Navigator.of(context).pushNamed(RouteNames.giving);
          break;
        case 3:
          Navigator.of(context).pushNamed(RouteNames.chat);
          break;
        case 4:
          Navigator.of(context).pushNamed(RouteNames.settings);
          break;
      }
    } else {
      // Without finance: Home, Members, Chat, Settings
      switch (index) {
        case 0:
          Navigator.of(context).pushReplacementNamed(RouteNames.dashboard);
          break;
        case 1:
          Navigator.of(context).pushNamed(RouteNames.members);
          break;
        case 2:
          Navigator.of(context).pushNamed(RouteNames.chat);
          break;
        case 3:
          Navigator.of(context).pushNamed(RouteNames.settings);
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context);

    // Build navigation items based on finance access
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: localizations?.home ?? 'Home',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.people_outlined),
        activeIcon: const Icon(Icons.people),
        label: localizations?.members ?? 'Members',
      ),
      if (_isFinanceLeader)
        BottomNavigationBarItem(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          activeIcon: const Icon(Icons.account_balance_wallet),
          label: localizations?.finance ?? 'Finance',
        ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.chat_bubble_outline),
        activeIcon: const Icon(Icons.chat_bubble),
        label: localizations?.chat ?? 'Chat',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.settings_outlined),
        activeIcon: const Icon(Icons.settings),
        label: localizations?.settings ?? 'Settings',
      ),
    ];

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: items,
      onTap: _handleNavigation,
    );
  }
}
