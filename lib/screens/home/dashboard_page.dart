import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';

/// Dashboard with summary cards
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
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
        onRefresh: () async {
          // Refresh dashboard data
          await Future.delayed(const Duration(seconds: 1));
        },
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
                      title: 'Upcoming Sessions',
                      value: '5',
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
                      title: 'Upcoming Events',
                      value: '3',
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
                      title: 'Tasks',
                      value: '8',
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
                      title: 'Birthdays',
                      value: '2',
                      icon: Icons.cake_outlined,
                      color: AppColors.accent,
                      onTap: () {
                        // Navigate to members with birthday filter
                        Navigator.of(context).pushNamed(RouteNames.members);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingXL),
              // Quick Actions
              Text('Quick Actions', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppDimensions.spacingMD),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppDimensions.spacingMD,
                mainAxisSpacing: AppDimensions.spacingMD,
                childAspectRatio: 1.5,
                children: [
                  _QuickActionCard(
                    title: 'Members',
                    icon: Icons.people_outlined,
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.members);
                    },
                  ),
                  _QuickActionCard(
                    title: 'Departments',
                    icon: Icons.business_outlined,
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.departments);
                    },
                  ),
                  _QuickActionCard(
                    title: 'Classes',
                    icon: Icons.class_outlined,
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.classes);
                    },
                  ),
                  _QuickActionCard(
                    title: 'Reports',
                    icon: Icons.assessment_outlined,
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.reports);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNavigationBar(),
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
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
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
              Icon(icon, size: 40, color: AppColors.primary),
              const SizedBox(height: AppDimensions.spacingSM),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation bar
class _BottomNavigationBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outlined),
          activeIcon: Icon(Icons.people),
          label: 'Members',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
      onTap: (index) {
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
      },
    );
  }
}
