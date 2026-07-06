import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../desktop/desktop_shell_scope.dart';
import 'members_report_page.dart';
import 'trainings_report_page.dart';
import 'new_comer_report_page.dart';

/// Reports hub with links to member, training, and newcomer reports.
class ReportsPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const ReportsPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(title: Text(context.tr('Statistics'))),
      body: ListView(
        padding: EdgeInsets.only(bottom: AppDimensions.paddingXL),
        children: [
          _buildHeaderBanner(),
          SizedBox(height: AppDimensions.spacingLG),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;
                final cards = _reportCards(context);

                if (isWide) {
                  return Wrap(
                    spacing: AppDimensions.spacingMD,
                    runSpacing: AppDimensions.spacingMD,
                    children: cards
                        .map(
                          (card) => SizedBox(
                            width: (constraints.maxWidth -
                                    AppDimensions.spacingMD) /
                                2,
                            child: card,
                          ),
                        )
                        .toList(),
                  );
                }

                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i < cards.length - 1)
                        SizedBox(height: AppDimensions.spacingMD),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _reportCards(BuildContext context) {
    return [
      _ReportTypeCard(
        title: context.tr('Member Report'),
        description: context.tr(
          'Weekly, monthly, yearly and custom reports for all members',
        ),
        icon: Icons.groups_outlined,
        color: AppColors.primary,
        onTap: () => _openMembersReport(context),
      ),
      _ReportTypeCard(
        title: context.tr('Training Report'),
        description: context.tr(
          'Review training summaries and open detailed reports',
        ),
        icon: Icons.school_outlined,
        color: AppColors.secondaryDark,
        onTap: () => _openTrainingsReport(context),
      ),
      _ReportTypeCard(
        title: context.tr('New Comers Report'),
        description: context.tr(
          'Weekly, monthly, yearly and custom newcomer reports',
        ),
        icon: Icons.fiber_new_rounded,
        color: AppColors.accent,
        onTap: () => _openNewComerReport(context),
      ),
    ];
  }

  Widget _buildHeaderBanner() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        widget.hideAppBarAndBottomNav ? 0 : AppDimensions.spacingSM,
        AppDimensions.paddingMD,
        0,
      ),
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        gradient: context.mic.headerGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: context.mic.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Statistics'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.mic.appBarForeground,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  context.tr('Insights and attendance reports for your church'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insights_outlined,
              color: AppColors.info,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  void _openNewComerReport(BuildContext context) {
    final scope = DesktopShellScope.maybeOf(context);
    final openAsStack = scope != null && widget.hideAppBarAndBottomNav;
    if (openAsStack) {
      scope.pushDetail(RouteNames.newComerReport, '');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewComerReportPage()),
    );
  }

  void _openMembersReport(BuildContext context) {
    final scope = DesktopShellScope.maybeOf(context);
    final openAsStack = scope != null && widget.hideAppBarAndBottomNav;
    if (openAsStack) {
      scope.pushDetail(RouteNames.membersReport, '');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MembersReportPage()),
    );
  }

  void _openTrainingsReport(BuildContext context) {
    final scope = DesktopShellScope.maybeOf(context);
    final openAsStack = scope != null && widget.hideAppBarAndBottomNav;
    if (openAsStack) {
      scope.pushDetail(RouteNames.trainingsReport, '');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TrainingsReportPage()),
    );
  }
}

class _ReportTypeCard extends StatelessWidget {
  const _ReportTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        child: Ink(
          decoration: BoxDecoration(
            color: context.mic.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            border: Border.all(color: color.withValues(alpha: 0.22)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                context.mic.surface,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.paddingLG),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.mic.appBarForeground,
                        ),
                      ),
                      SizedBox(height: AppDimensions.spacingXS),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.mic.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
