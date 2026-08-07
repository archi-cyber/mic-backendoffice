import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/error_message_helper.dart';
import '../../services/finance_service.dart';
import '../../services/report_service.dart';
import '../../services/member_service.dart';
import '../../services/teaching_service.dart';
import '../../services/church_attendance_service.dart';
import '../../widgets/church_attendance_presence_chart.dart';
import '../desktop/desktop_shell_scope.dart';

/// Dashboard with summary cards
class DashboardPage extends StatefulWidget {
  /// When true (e.g. desktop layout), no app bar or bottom nav is shown.
  final bool hideAppBarAndBottomNav;

  DashboardPage({super.key, this.hideAppBarAndBottomNav = false});

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

  /// Upcoming events list for desktop table.
  List<Map<String, dynamic>> _upcomingEventsList = [];

  /// Recent teachings (max 3) for desktop.
  List<Map<String, dynamic>> _recentTeachingsList = [];

  /// Upcoming birthdays (max 5) for desktop. Each: id, first_name, last_name, birthday.
  List<Map<String, dynamic>> _upcomingBirthdaysList = [];

  /// Newcomers (members with is_new_comer=true) for desktop table.
  List<Map<String, dynamic>> _newcomersList = [];

  /// Church attendance services for desktop trend charts.
  List<Map<String, dynamic>> _churchAttendanceServices = [];

  static const double _kDesktopMaxWidth = 1200;
  static const int _kUpcomingEventsLimit = 10;
  static const int _kRecentTeachingsLimit = 3;
  static const int _kUpcomingBirthdaysLimit = 5;
  static const int _kNewcomersLimit = 5;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigator.consumePendingNotificationsNavigation();
    });
  }

  /// Charge les données du tableau de bord.
  ///
  /// Une seule requête remplace les huit précédentes. Les décomptes et le tri
  /// des anniversaires sont faits en SQL côté serveur : l'ancienne version
  /// chargeait toute la table des membres sur l'appareil pour la filtrer,
  /// ce qui devenait coûteux dès quelques centaines de fiches.
  ///
  /// Deux appels subsistent en parallèle — enseignements récents et cultes —
  /// qui relèvent de leurs services propres.
  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final errors = <Object>[];
    final now = DateTime.now();

    var upcomingSessions = 0;
    var upcomingEvents = 0;
    var tasks = 0;
    var birthdays = 0;
    var members = 0;
    var upcomingEventsList = <Map<String, dynamic>>[];
    var recentTeachingsList = <Map<String, dynamic>>[];
    var upcomingBirthdaysList = <Map<String, dynamic>>[];
    var newcomersList = <Map<String, dynamic>>[];
    var churchAttendanceServices = <Map<String, dynamic>>[];

    await Future.wait([
      () async {
        try {
          final dashboard = await ReportService.getDashboard();

          final membersBlock =
              (dashboard['members'] as Map?)?.cast<String, dynamic>() ??
                  const <String, dynamic>{};
          final tasksBlock =
              (dashboard['tasks'] as Map?)?.cast<String, dynamic>() ??
                  const <String, dynamic>{};

          members = membersBlock['total'] as int? ?? 0;
          tasks = tasksBlock['open'] as int? ?? 0;

          upcomingEventsList =
              ((dashboard['upcoming_events'] as List?) ?? const [])
                  .map((e) => (e as Map).cast<String, dynamic>())
                  .take(_kUpcomingEventsLimit)
                  .toList();
          upcomingEvents = upcomingEventsList.length;

          upcomingSessions =
              ((dashboard['upcoming_sessions'] as List?) ?? const []).length;

          // Les anniversaires arrivent triés par jour du mois : le serveur
          // s'en charge, ce qui évite de reproduire cette logique de tri.
          final monthBirthdays =
              ((dashboard['birthdays_this_month'] as List?) ?? const [])
                  .map((e) => (e as Map).cast<String, dynamic>())
                  .toList();

          // Le compteur ne retient que les anniversaires restant à venir dans
          // le mois : afficher ceux déjà passés n'apporterait rien.
          birthdays = monthBirthdays.where((m) {
            final raw = m['birthday'];
            if (raw == null) return false;
            try {
              return DateTime.parse(raw.toString()).day >= now.day;
            } catch (_) {
              return false;
            }
          }).length;

          upcomingBirthdaysList =
              monthBirthdays.take(_kUpcomingBirthdaysLimit).toList();
        } catch (e) {
          errors.add(e);
        }
      }(),
      () async {
        try {
          newcomersList = await MemberService.getMembers(
            filters: {'is_new_comer': true, 'is_active': true},
            limit: _kNewcomersLimit,
            orderBy: 'createdAt',
            ascending: false,
          );
        } catch (e) {
          errors.add(e);
        }
      }(),
      () async {
        try {
          final teachings = await TeachingService.getTeachings(
            limit: _kRecentTeachingsLimit,
          );
          recentTeachingsList = teachings
              .take(_kRecentTeachingsLimit)
              .map((t) => Map<String, dynamic>.from(t))
              .toList();
        } catch (e) {
          errors.add(e);
        }
      }(),
      () async {
        try {
          churchAttendanceServices =
              await ChurchAttendanceService.getAllServices(
            startDate: now.subtract(const Duration(days: 90)),
          );
        } catch (e) {
          errors.add(e);
        }
      }(),
    ]);

    if (!mounted) return;
    setState(() {
      _upcomingSessions = upcomingSessions;
      _upcomingEvents = upcomingEvents;
      _tasks = tasks;
      _birthdays = birthdays;
      _members = members;
      _upcomingEventsList = upcomingEventsList;
      _recentTeachingsList = recentTeachingsList;
      _upcomingBirthdaysList = upcomingBirthdaysList;
      _newcomersList = newcomersList;
      _churchAttendanceServices = churchAttendanceServices;
      _isLoading = false;
    });

    if (errors.isNotEmpty && mounted) {
      ErrorMessageHelper.showErrorSnackBar(
        context,
        errors.first,
        title: AppLocalizations.of(context)?.errorLoadingDashboard ??
            'Error loading dashboard',
      );
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
                  icon: Icon(Icons.notifications_outlined),
                  onPressed: () {
                    Navigator.of(context).pushNamed(RouteNames.notifications);
                  },
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: widget.hideAppBarAndBottomNav
            ? _buildDesktopBody(context, localizations, theme)
            : _buildMobileBody(context, localizations, theme),
      ),
      bottomNavigationBar: widget.hideAppBarAndBottomNav
          ? null
          : _BottomNavigationBar(),
    );
  }

  static String _formatBirthdayShort(DateTime birthday, DateTime now) {
    if (birthday.month == now.month && birthday.day == now.day) {
      return 'Today';
    }
    final tomorrow = now.add(Duration(days: 1));
    if (birthday.month == tomorrow.month && birthday.day == tomorrow.day) {
      return 'Tomorrow';
    }
    return DateFormat('MMM d').format(birthday);
  }

  Widget _buildDesktopBody(
    BuildContext context,
    AppLocalizations? localizations,
    ThemeData theme,
  ) {
    final l = localizations;
    final dateFormat = DateFormat('MMM d, yyyy');
    final scope = DesktopShellScope.maybeOf(context);
    final now = DateTime.now();

    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _kDesktopMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stats row: four equal-width chips covering full width
              Row(
                children: [
                  Expanded(
                    child: _DesktopStatChip(
                      label: l?.upcomingSessions ?? 'Upcoming Sessions',
                      value: _isLoading ? '...' : '$_upcomingSessions',
                      icon: Icons.event_outlined,
                      color: AppColors.primary,
                      onTap: () {
                        if (scope != null) {
                          scope.pushList(RouteNames.desktopTrainings);
                        } else {
                          Navigator.of(
                            context,
                          ).pushReplacementNamed(RouteNames.desktopTrainings);
                        }
                      },
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    child: _DesktopStatChip(
                      label: l?.upcomingEvents ?? 'Upcoming Events',
                      value: _isLoading ? '...' : '$_upcomingEvents',
                      icon: Icons.calendar_today_outlined,
                      color: AppColors.secondary,
                      onTap: () {
                        if (scope != null) {
                          scope.pushList(RouteNames.desktopEvents);
                        } else {
                          Navigator.of(
                            context,
                          ).pushReplacementNamed(RouteNames.desktopEvents);
                        }
                      },
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    child: _DesktopStatChip(
                      label: l?.tasks ?? 'Tasks',
                      value: _isLoading ? '...' : '$_tasks',
                      icon: Icons.task_outlined,
                      color: AppColors.warning,
                      onTap: () {
                        if (scope != null) {
                          scope.pushList(RouteNames.desktopTasks);
                        } else {
                          Navigator.of(
                            context,
                          ).pushReplacementNamed(RouteNames.desktopTasks);
                        }
                      },
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    child: _DesktopStatChip(
                      label: l?.birthdays ?? 'Birthdays',
                      value: _isLoading ? '...' : '$_birthdays',
                      icon: Icons.cake_outlined,
                      color: AppColors.accent,
                      onTap: () {
                        if (scope != null) {
                          scope.pushList(RouteNames.desktopBirthdays);
                        } else {
                          Navigator.of(
                            context,
                          ).pushReplacementNamed(RouteNames.desktopBirthdays);
                        }
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingXL),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ChurchAttendancePresenceChart(
                      title: context.tr('Church attendance'),
                      serviceLineLabel: context.tr('Daily presence'),
                      totalLineLabel: context.tr('dashboardChurchWeeklyAttendance'),
                      services: _churchAttendanceServices,
                      isLoading: _isLoading,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingXL),
              // Two equal-width cards: Upcoming events table + Quick access
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingMD),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l?.upcomingEvents ?? 'Upcoming Events',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    if (scope != null) {
                                      scope.pushList(RouteNames.desktopEvents);
                                    } else {
                                      Navigator.of(
                                        context,
                                      ).pushReplacementNamed(
                                        RouteNames.desktopEvents,
                                      );
                                    }
                                  },
                                  icon: Icon(Icons.open_in_new, size: 18),
                                  label: Text(context.tr('View all')),
                                ),
                              ],
                            ),
                            SizedBox(height: AppDimensions.spacingSM),
                            if (_isLoading)
                              Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_upcomingEventsList.isEmpty)
                              Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: Text(
                                    l?.noData ?? 'No upcoming events',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: context.mic.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                            ),
                                        columns: [
                                          DataColumn(
                                            label: Text(context.tr('Event')),
                                          ),
                                          DataColumn(
                                            label: Text(context.tr('Date')),
                                          ),
                                          DataColumn(
                                            label: Text(context.tr('Action')),
                                          ),
                                        ],
                                        rows: _upcomingEventsList.map((event) {
                                          final id =
                                              event['id']?.toString() ?? '';
                                          final name =
                                              event['title']?.toString() ??
                                              'Unnamed';
                                          final dateStr = event['event_date'];
                                          final dateFormatted = dateStr != null
                                              ? dateFormat.format(
                                                  DateTime.parse(dateStr),
                                                )
                                              : '—';
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              DataCell(Text(dateFormatted)),
                                              DataCell(
                                                TextButton(
                                                  onPressed: () {
                                                    if (scope != null) {
                                                      scope.pushDetail(
                                                        RouteNames.eventDetail,
                                                        id,
                                                      );
                                                    } else {
                                                      Navigator.of(
                                                        context,
                                                        rootNavigator: true,
                                                      ).pushNamed(
                                                        RouteNames.eventDetail
                                                            .replaceAll(
                                                              ':id',
                                                              id,
                                                            ),
                                                      );
                                                    }
                                                  },
                                                  child: Text(
                                                    context.tr('View'),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingLG),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingMD),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l?.teachings ?? 'Recent Teachings',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    if (scope != null) {
                                      scope.pushList(
                                        RouteNames.desktopTeachings,
                                      );
                                    } else {
                                      Navigator.of(
                                        context,
                                      ).pushReplacementNamed(
                                        RouteNames.desktopTeachings,
                                      );
                                    }
                                  },
                                  icon: Icon(Icons.open_in_new, size: 18),
                                  label: Text(context.tr('View all')),
                                ),
                              ],
                            ),
                            SizedBox(height: AppDimensions.spacingSM),
                            if (_isLoading)
                              Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_recentTeachingsList.isEmpty)
                              Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: Text(
                                    l?.noData ?? 'No recent teachings',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: context.mic.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                            ),
                                        columns: [
                                          DataColumn(
                                            label: Text(context.tr('Title')),
                                          ),
                                          DataColumn(
                                            label: Text(context.tr('Date')),
                                          ),
                                          DataColumn(
                                            label: Text(context.tr('Speaker')),
                                          ),
                                          DataColumn(
                                            label: Text(context.tr('Action')),
                                          ),
                                        ],
                                        rows: _recentTeachingsList.map((
                                          teaching,
                                        ) {
                                          final id =
                                              teaching['id']?.toString() ?? '';
                                          final title =
                                              teaching['title']?.toString() ??
                                              'Untitled';
                                          final dateStr =
                                              teaching['teaching_date'];
                                          final dateFormatted = dateStr != null
                                              ? dateFormat.format(
                                                  DateTime.parse(dateStr),
                                                )
                                              : '—';
                                          final speaker =
                                              teaching['speaker']?.toString() ??
                                              '—';
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  title,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                              DataCell(Text(dateFormatted)),
                                              DataCell(
                                                Text(
                                                  speaker,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                              DataCell(
                                                TextButton(
                                                  onPressed: () {
                                                    if (id.isNotEmpty) {
                                                      if (scope != null) {
                                                        scope.pushDetail(
                                                          RouteNames
                                                              .teachingDetail,
                                                          id,
                                                        );
                                                      } else {
                                                        Navigator.of(
                                                          context,
                                                          rootNavigator: true,
                                                        ).pushNamed(
                                                          RouteNames
                                                              .teachingDetail
                                                              .replaceAll(
                                                                ':id',
                                                                id,
                                                              ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  child: Text(
                                                    context.tr('View'),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingXL),
              // Row: Upcoming Birthdays (max 5) + Newcomers table
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingMD),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l?.birthdays ?? 'Upcoming Birthdays',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    if (scope != null) {
                                      scope.pushList(
                                        RouteNames.desktopBirthdays,
                                      );
                                    } else {
                                      Navigator.of(
                                        context,
                                      ).pushReplacementNamed(
                                        RouteNames.desktopBirthdays,
                                      );
                                    }
                                  },
                                  icon: Icon(Icons.open_in_new, size: 18),
                                  label: Text(context.tr('View all')),
                                ),
                              ],
                            ),
                            SizedBox(height: AppDimensions.spacingSM),
                            if (_isLoading)
                              Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_upcomingBirthdaysList.isEmpty)
                              Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: Text(
                                    l?.noData ?? 'No upcoming birthdays',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: context.mic.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                            ),
                                        columns: [
                                          DataColumn(
                                            label: Text(context.tr('Name')),
                                          ),
                                          DataColumn(
                                            label: Text(context.tr('Birthday')),
                                          ),
                                          DataColumn(
                                            label: Text(context.tr('Action')),
                                          ),
                                        ],
                                        rows: _upcomingBirthdaysList.map((
                                          member,
                                        ) {
                                          final memberId =
                                              member['id']?.toString() ?? '';
                                          final name =
                                              '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'
                                                  .trim();
                                          final displayName = name.isEmpty
                                              ? '—'
                                              : name;
                                          final birthdayStr = member['birthday']
                                              ?.toString();
                                          final birthdayFormatted =
                                              birthdayStr != null
                                              ? _formatBirthdayShort(
                                                  DateTime.parse(birthdayStr),
                                                  now,
                                                )
                                              : '—';
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(displayName)),
                                              DataCell(Text(birthdayFormatted)),
                                              DataCell(
                                                TextButton(
                                                  onPressed: () {
                                                    if (memberId.isNotEmpty) {
                                                      if (scope != null) {
                                                        scope.pushDetail(
                                                          RouteNames
                                                              .memberDetail,
                                                          memberId,
                                                        );
                                                      } else {
                                                        Navigator.of(
                                                          context,
                                                          rootNavigator: true,
                                                        ).pushNamed(
                                                          RouteNames
                                                              .memberDetail
                                                              .replaceAll(
                                                                ':id',
                                                                memberId,
                                                              ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  child: Text(
                                                    context.tr('View'),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingLG),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingMD),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Newcomers',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    if (scope != null) {
                                      scope.pushList(RouteNames.desktopMembers);
                                    } else {
                                      Navigator.of(
                                        context,
                                      ).pushReplacementNamed(
                                        RouteNames.desktopMembers,
                                      );
                                    }
                                  },
                                  icon: Icon(Icons.open_in_new, size: 18),
                                  label: Text(context.tr('View all')),
                                ),
                              ],
                            ),
                            SizedBox(height: AppDimensions.spacingSM),
                            if (_isLoading)
                              Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_newcomersList.isEmpty)
                              Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: Text(
                                    l?.noData ?? 'No newcomers',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: context.mic.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: DataTable(
                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                            ),
                                        columns: [
                                          DataColumn(
                                            label: Text(context.tr('Name')),
                                          ),
                                          DataColumn(
                                            label: Text(context.tr('Phone')),
                                          ),
                                          DataColumn(
                                            label: Text(context.tr('Action')),
                                          ),
                                        ],
                                        rows: _newcomersList.map((member) {
                                          final id =
                                              member['id']?.toString() ?? '';
                                          final firstName =
                                              member['first_name']
                                                  ?.toString() ??
                                              '';
                                          final lastName =
                                              member['last_name']?.toString() ??
                                              '';
                                          final name = [firstName, lastName]
                                              .where((s) => s.isNotEmpty)
                                              .join(' ')
                                              .trim();
                                          final displayName = name.isEmpty
                                              ? '—'
                                              : name;
                                          final phone =
                                              member['phone']?.toString() ??
                                              '—';
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(displayName)),
                                              DataCell(Text(phone)),
                                              DataCell(
                                                TextButton(
                                                  onPressed: () {
                                                    if (id.isNotEmpty) {
                                                      if (scope != null) {
                                                        scope.pushDetail(
                                                          RouteNames
                                                              .memberDetail,
                                                          id,
                                                        );
                                                      } else {
                                                        Navigator.of(
                                                          context,
                                                          rootNavigator: true,
                                                        ).pushNamed(
                                                          RouteNames
                                                              .memberDetail
                                                              .replaceAll(
                                                                ':id',
                                                                id,
                                                              ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  child: Text(
                                                    context.tr('View'),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBody(
    BuildContext context,
    AppLocalizations? localizations,
    ThemeData theme,
  ) {
    final l = localizations;
    final now = DateTime.now();
    final dateFormat = DateFormat('MMM d, yyyy');
    final todayLabel = DateFormat('EEEE, MMMM d').format(now);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MobileWelcomeBanner(
            title: l?.dashboard ?? 'Dashboard',
            subtitle: todayLabel,
          ),
          SizedBox(height: AppDimensions.spacingMD),
          SizedBox(
            height: 112,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMD,
              ),
              children: [
                _MobileStatTile(
                  label: l?.upcomingSessions ?? 'Sessions',
                  value: _isLoading ? '…' : '$_upcomingSessions',
                  icon: Icons.event_outlined,
                  color: AppColors.primary,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.classes),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                _MobileStatTile(
                  label: l?.upcomingEvents ?? 'Events',
                  value: _isLoading ? '…' : '$_upcomingEvents',
                  icon: Icons.calendar_today_outlined,
                  color: AppColors.secondary,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.events),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                _MobileStatTile(
                  label: l?.tasks ?? 'Tasks',
                  value: _isLoading ? '…' : '$_tasks',
                  icon: Icons.task_alt_outlined,
                  color: AppColors.accent,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.tasks),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                _MobileStatTile(
                  label: l?.birthdays ?? 'Birthdays',
                  value: _isLoading ? '…' : '$_birthdays',
                  icon: Icons.cake_outlined,
                  color: AppColors.terracotta,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(RouteNames.upcomingBirthdays),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                _MobileStatTile(
                  label: l?.members ?? 'Members',
                  value: _isLoading ? '…' : '$_members',
                  icon: Icons.people_outlined,
                  color: AppColors.info,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.members),
                ),
              ],
            ),
          ),
          SizedBox(height: AppDimensions.spacingLG),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
            child: Text(
              l?.quickActions ?? 'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.mic.appBarForeground,
              ),
            ),
          ),
          SizedBox(height: AppDimensions.spacingSM),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
            child: _MobileQuickAccessGrid(
              actions: [
                _MobileQuickAction(
                  label: l?.members ?? 'Members',
                  icon: Icons.people_outlined,
                  color: AppColors.primary,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.members),
                ),
                _MobileQuickAction(
                  label: l?.departments ?? 'Departments',
                  icon: Icons.business_outlined,
                  color: AppColors.secondaryDark,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.departments),
                ),
                _MobileQuickAction(
                  label: l?.classes ?? 'Trainings',
                  icon: Icons.school_outlined,
                  color: AppColors.info,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.classes),
                ),
                _MobileQuickAction(
                  label: l?.reports ?? 'Reports',
                  icon: Icons.assessment_outlined,
                  color: context.mic.appBarForeground,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.reports),
                ),
                _MobileQuickAction(
                  label: l?.churchAttendance ?? 'Church Attendance',
                  icon: Icons.church,
                  color: AppColors.terracotta,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(RouteNames.churchAttendanceList),
                ),
                _MobileQuickAction(
                  label: l?.sundaySchool ?? 'Sunday School',
                  icon: Icons.child_care_outlined,
                  color: AppColors.accent,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(RouteNames.sundaySchoolAttendanceList),
                ),
                _MobileQuickAction(
                  label: l?.visitors ?? 'Visitors',
                  icon: Icons.person_add_outlined,
                  color: AppColors.primaryLight,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.visitors),
                ),
                _MobileQuickAction(
                  label: l?.teachings ?? 'Teachings',
                  icon: Icons.menu_book_outlined,
                  color: AppColors.secondary,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.teachings),
                ),
              ],
            ),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
            child: _MobileSectionCard(
              title: l?.birthdays ?? 'Upcoming Birthdays',
              icon: Icons.cake_outlined,
              iconColor: AppColors.accent,
              onViewAll: () => Navigator.of(
                context,
              ).pushNamed(RouteNames.upcomingBirthdays),
              isLoading: _isLoading,
              isEmpty: _upcomingBirthdaysList.isEmpty,
              emptyMessage: l?.noData ?? 'No upcoming birthdays',
              child: Column(
                children: _upcomingBirthdaysList.take(4).map((member) {
                  final memberId = member['id']?.toString() ?? '';
                  final name =
                      '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'
                          .trim();
                  final birthdayStr = member['birthday']?.toString();
                  final when = birthdayStr != null
                      ? _formatBirthdayShort(DateTime.parse(birthdayStr), now)
                      : '—';
                  return _MobileActivityTile(
                    title: name.isEmpty ? '—' : name,
                    subtitle: when,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.cake_outlined,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    onTap: memberId.isEmpty
                        ? null
                        : () => Navigator.of(context).pushNamed(
                            RouteNames.memberDetail.replaceAll(':id', memberId),
                          ),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
            child: _MobileSectionCard(
              title: l?.teachings ?? 'Recent Teachings',
              icon: Icons.menu_book_outlined,
              iconColor: AppColors.secondary,
              onViewAll: () =>
                  Navigator.of(context).pushNamed(RouteNames.teachings),
              isLoading: _isLoading,
              isEmpty: _recentTeachingsList.isEmpty,
              emptyMessage: l?.noData ?? 'No recent teachings',
              child: Column(
                children: _recentTeachingsList.take(3).map((teaching) {
                  final id = teaching['id']?.toString() ?? '';
                  final title = teaching['title']?.toString() ?? 'Untitled';
                  final speaker = teaching['speaker']?.toString();
                  final dateStr = teaching['teaching_date'];
                  final dateFormatted = dateStr != null
                      ? dateFormat.format(DateTime.parse(dateStr))
                      : null;
                  final subtitle = [
                    if (speaker != null && speaker.isNotEmpty) speaker,
                    if (dateFormatted != null) dateFormatted,
                  ].join(' · ');
                  return _MobileActivityTile(
                    title: title,
                    subtitle: subtitle.isEmpty ? '—' : subtitle,
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.secondary.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.menu_book_outlined,
                        color: AppColors.secondaryDark,
                        size: 20,
                      ),
                    ),
                    onTap: id.isEmpty
                        ? null
                        : () => Navigator.of(context).pushNamed(
                            RouteNames.teachingDetail.replaceAll(':id', id),
                          ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (_newcomersList.isNotEmpty || _isLoading) ...[
            SizedBox(height: AppDimensions.spacingMD),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
              child: _MobileSectionCard(
                title: context.tr('Newcomers'),
                icon: Icons.person_add_alt_1_outlined,
                iconColor: AppColors.primaryLight,
                onViewAll: () =>
                    Navigator.of(context).pushNamed(RouteNames.members),
                isLoading: _isLoading,
                isEmpty: _newcomersList.isEmpty,
                emptyMessage: l?.noData ?? 'No newcomers',
                child: Column(
                  children: _newcomersList.take(3).map((member) {
                    final id = member['id']?.toString() ?? '';
                    final name =
                        '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'
                            .trim();
                    final phone = member['phone']?.toString();
                    return _MobileActivityTile(
                      title: name.isEmpty ? '—' : name,
                      subtitle: phone ?? context.tr('No phone'),
                      leading: CircleAvatar(
                        backgroundColor:
                            context.mic.surfaceTint.withValues(alpha: 0.9),
                        child: Icon(
                          Icons.person_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      onTap: id.isEmpty
                          ? null
                          : () => Navigator.of(context).pushNamed(
                              RouteNames.memberDetail.replaceAll(':id', id),
                            ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          SizedBox(height: AppDimensions.spacingMD),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
            child: _MobileSectionCard(
              title: l?.upcomingEvents ?? 'Upcoming Events',
              icon: Icons.event,
              iconColor: AppColors.primary,
              onViewAll: () =>
                  Navigator.of(context).pushNamed(RouteNames.events),
              isLoading: _isLoading,
              isEmpty: _upcomingEventsList.isEmpty,
              emptyMessage: l?.noData ?? 'No upcoming events',
              child: Column(
                children: _upcomingEventsList.take(4).map((event) {
                  final id = event['id']?.toString() ?? '';
                  final name = event['title']?.toString() ?? 'Unnamed';
                  final dateStr = event['event_date'];
                  final dateFormatted = dateStr != null
                      ? dateFormat.format(DateTime.parse(dateStr))
                      : '—';
                  return _MobileActivityTile(
                    title: name,
                    subtitle: dateFormatted,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.event,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    onTap: id.isEmpty
                        ? null
                        : () => Navigator.of(context).pushNamed(
                            RouteNames.eventDetail.replaceAll(':id', id),
                          ),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: AppDimensions.spacingXL),
        ],
      ),
    );
  }
}

class _MobileWelcomeBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MobileWelcomeBanner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        AppDimensions.paddingSM,
        AppDimensions.paddingMD,
        0,
      ),
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        gradient: context.mic.brandGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        boxShadow: [
          BoxShadow(
            color: AppColors.terracotta.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            decoration: BoxDecoration(
              color: AppColors.textLight.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.church,
              color: AppColors.textLight,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MobileStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingSM + 4,
              vertical: AppDimensions.paddingSM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.mic.textSecondary,
                    height: 1.1,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onViewAll;
  final bool isLoading;
  final bool isEmpty;
  final String emptyMessage;
  final Widget child;

  const _MobileSectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onViewAll,
    required this.isLoading,
    required this.isEmpty,
    required this.emptyMessage,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: context.mic.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        side: BorderSide(color: context.mic.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                SizedBox(width: AppDimensions.spacingSM),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.mic.appBarForeground,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingSM,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(context.tr('View all')),
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingSM),
            if (isLoading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingLG),
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingMD),
                child: Text(
                  emptyMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              )
            else
              child,
          ],
        ),
      ),
    );
  }
}

class _MobileActivityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback? onTap;

  const _MobileActivityTile({
    required this.title,
    required this.subtitle,
    required this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingSM),
          child: Row(
            children: [
              leading,
              SizedBox(width: AppDimensions.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: context.mic.textTertiary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileQuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MobileQuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _MobileQuickAccessGrid extends StatelessWidget {
  final List<_MobileQuickAction> actions;

  const _MobileQuickAccessGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Hauteur fixe plutôt que ratio.
      //
      // `childAspectRatio` calcule la hauteur à partir de la largeur : sur un
      // écran large, quatre colonnes donnent des cellules de 450 px, donc
      // 577 px de haut, pour un contenu qui en occupe cent. D'où les vides
      // considérables entre les rangées.
      //
      // `maxCrossAxisExtent` fixe une largeur maximale et laisse Flutter
      // choisir le nombre de colonnes : quatre sur un téléphone, davantage sur
      // un écran large. `mainAxisExtent` impose la hauteur réelle du contenu,
      // qui ne dépend pas de la largeur disponible.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        mainAxisExtent: 96,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(action.icon, color: action.color, size: 24),
              ),
              SizedBox(height: AppDimensions.spacingXS),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  height: 1.15,
                  color: context.mic.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Desktop stat chip (compact stat + link)
class _DesktopStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _DesktopStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingLG,
            vertical: AppDimensions.paddingMD,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(icon, color: color, size: 28),
              SizedBox(width: AppDimensions.spacingMD),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.mic.textSecondary,
                    ),
                  ),
                ],
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
  _BottomNavigationBar();

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
      return SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context);

    // Build navigation items based on finance access
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: localizations?.home ?? 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.people_outlined),
        activeIcon: Icon(Icons.people),
        label: localizations?.members ?? 'Members',
      ),
      if (_isFinanceLeader)
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined),
          activeIcon: Icon(Icons.account_balance_wallet),
          label: localizations?.finance ?? 'Finance',
        ),
      BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble_outline),
        activeIcon: Icon(Icons.chat_bubble),
        label: localizations?.chat ?? 'Chat',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.settings_outlined),
        activeIcon: Icon(Icons.settings),
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