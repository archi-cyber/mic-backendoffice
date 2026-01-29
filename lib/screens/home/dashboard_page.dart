import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../services/supabase_service.dart';
import '../../services/finance_service.dart';
import '../../services/teaching_service.dart';
import '../desktop/desktop_shell_scope.dart';

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

  /// Upcoming events list for desktop table.
  List<Map<String, dynamic>> _upcomingEventsList = [];

  /// Recent teachings (max 3) for desktop.
  List<Map<String, dynamic>> _recentTeachingsList = [];

  /// Upcoming trainings/sessions (max 5) for desktop. Each: id, session_date, class_id, class name.
  List<Map<String, dynamic>> _upcomingTrainingsList = [];

  /// Newcomers (members with is_new_comer=true) for desktop table.
  List<Map<String, dynamic>> _newcomersList = [];

  static const double _kDesktopMaxWidth = 1200;
  static const int _kUpcomingEventsLimit = 10;
  static const int _kRecentTeachingsLimit = 3;
  static const int _kUpcomingTrainingsLimit = 5;
  static const int _kNewcomersLimit = 5;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final errors = <String>[];

    try {
      final now = DateTime.now();

      // Load upcoming sessions from trainings (next 5 weeks = 35 days)
      try {
        final sessionsEndDate = now.add(const Duration(days: 35));
        final sessions = await SupabaseService.client
            .from('sessions')
            .select()
            .not('class_id', 'is', null)
            .gte('session_date', now.toIso8601String())
            .lte('session_date', sessionsEndDate.toIso8601String());
        _upcomingSessions = (sessions as List).length;
      } catch (e) {
        errors.add('Sessions: $e');
      }

      // Load upcoming events (all events after current date)
      try {
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        final dateStr =
            '${tomorrowStart.year}-${tomorrowStart.month.toString().padLeft(2, '0')}-${tomorrowStart.day.toString().padLeft(2, '0')}';
        final events = await SupabaseService.client
            .from('events')
            .select('id, title, event_date')
            .eq('is_active', true)
            .gte('event_date', dateStr)
            .order('event_date', ascending: true);
        final eventsList = events as List;
        _upcomingEvents = eventsList.length;
        _upcomingEventsList = eventsList
            .take(_kUpcomingEventsLimit)
            .map(
              (e) =>
                  e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{},
            )
            .where((m) => m.isNotEmpty)
            .toList();
      } catch (e) {
        errors.add('Events: $e');
        _upcomingEventsList = [];
      }

      // Load task count
      try {
        final tasksList = await SupabaseService.client
            .from('tasks')
            .select('id')
            .inFilter('status', ['pending', 'in_progress']);
        _tasks = (tasksList as List).length;
      } catch (e) {
        errors.add('Tasks: $e');
      }

      // Load total active members count
      try {
        final membersList = await SupabaseService.client
            .from('members')
            .select('id')
            .eq('is_active', true);
        _members = (membersList as List).length;
      } catch (e) {
        errors.add('Members: $e');
      }

      // Load upcoming birthdays
      try {
        final allMembers = await SupabaseService.client
            .from('members')
            .select('id, birthday')
            .not('birthday', 'is', null);
        final list = allMembers as List;
        final upcomingBirthdays = list.where((member) {
          if (member is! Map || member['birthday'] == null) return false;
          try {
            final birthday = DateTime.parse(member['birthday'].toString());
            return birthday.month == now.month && birthday.day >= now.day;
          } catch (_) {
            return false;
          }
        }).toList();
        _birthdays = upcomingBirthdays.length;
      } catch (e) {
        errors.add('Birthdays: $e');
      }

      // Load recent teachings (max 3)
      try {
        final teachings = await TeachingService.getTeachings(
          limit: _kRecentTeachingsLimit,
        );
        _recentTeachingsList = teachings
            .take(_kRecentTeachingsLimit)
            .map((t) => Map<String, dynamic>.from(t))
            .toList();
      } catch (e) {
        errors.add('Teachings: $e');
        _recentTeachingsList = [];
      }

      // Load upcoming trainings/sessions (max 5) with class name
      try {
        final sessionsResponse = await SupabaseService.client
            .from('sessions')
            .select('id, session_date, class_id, classes(name)')
            .not('class_id', 'is', null)
            .gte('session_date', now.toIso8601String().split('T')[0])
            .order('session_date', ascending: true)
            .limit(_kUpcomingTrainingsLimit);
        final sessionsList = sessionsResponse as List;
        _upcomingTrainingsList = sessionsList
            .take(_kUpcomingTrainingsLimit)
            .map((s) {
              final m = Map<String, dynamic>.from(s as Map);
              // Flatten classes(name) -> class_name for display
              final classes = m['classes'];
              if (classes is Map) {
                m['class_name'] = classes['name']?.toString() ?? '';
              } else {
                m['class_name'] = '';
              }
              return m;
            })
            .toList();
      } catch (e) {
        errors.add('Trainings: $e');
        _upcomingTrainingsList = [];
      }

      // Load newcomers (members with is_new_comer = true)
      try {
        final newcomersResponse = await SupabaseService.client
            .from('members')
            .select('id, first_name, last_name, phone')
            .eq('is_new_comer', true)
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(_kNewcomersLimit);
        final list = newcomersResponse as List;
        _newcomersList = list
            .map(
              (m) =>
                  m is Map ? Map<String, dynamic>.from(m) : <String, dynamic>{},
            )
            .where((m) => m.isNotEmpty)
            .toList();
      } catch (e) {
        errors.add('Newcomers: $e');
        _newcomersList = [];
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (errors.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)?.errorLoadingDashboard ?? 'Error loading dashboard'}: ${errors.join('; ')}',
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.errorLoadingDashboard ?? 'Error loading dashboard'}: $e',
            ),
            duration: const Duration(seconds: 6),
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
        child: widget.hideAppBarAndBottomNav
            ? _buildDesktopBody(context, localizations, theme)
            : _buildMobileBody(context, localizations, theme),
      ),
      bottomNavigationBar: widget.hideAppBarAndBottomNav
          ? null
          : _BottomNavigationBar(),
    );
  }

  Widget _buildDesktopBody(
    BuildContext context,
    AppLocalizations? localizations,
    ThemeData theme,
  ) {
    final l = localizations;
    final dateFormat = DateFormat('MMM d, yyyy');
    final scope = DesktopShellScope.maybeOf(context);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kDesktopMaxWidth),
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
                  const SizedBox(width: AppDimensions.spacingMD),
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
                  const SizedBox(width: AppDimensions.spacingMD),
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
                  const SizedBox(width: AppDimensions.spacingMD),
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
              const SizedBox(height: AppDimensions.spacingXL),
              // Two equal-width cards: Upcoming events table + Quick access
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingMD),
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
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  label: const Text('View all'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.spacingSM),
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_upcomingEventsList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: Text(
                                    l?.noData ?? 'No upcoming events',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    theme.colorScheme.surfaceContainerHighest,
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Event')),
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Action')),
                                  ],
                                  rows: _upcomingEventsList.map((event) {
                                    final id = event['id']?.toString() ?? '';
                                    final name =
                                        event['title']?.toString() ?? 'Unnamed';
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
                                            overflow: TextOverflow.ellipsis,
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
                                                      .replaceAll(':id', id),
                                                );
                                              }
                                            },
                                            child: const Text('View'),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingLG),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingMD),
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
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  label: const Text('View all'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.spacingSM),
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_recentTeachingsList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: Text(
                                    l?.noData ?? 'No recent teachings',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ..._recentTeachingsList.map((teaching) {
                                final id = teaching['id']?.toString() ?? '';
                                final title =
                                    teaching['title']?.toString() ?? 'Untitled';
                                final dateStr = teaching['teaching_date'];
                                final dateFormatted = dateStr != null
                                    ? dateFormat.format(DateTime.parse(dateStr))
                                    : '—';
                                return ListTile(
                                  title: Text(
                                    title,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  subtitle: Text(dateFormatted),
                                  trailing: TextButton(
                                    onPressed: () {
                                      if (scope != null) {
                                        scope.pushDetail(
                                          RouteNames.teachingDetail,
                                          id,
                                        );
                                      } else {
                                        Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ).pushNamed(
                                          RouteNames.teachingDetail.replaceAll(
                                            ':id',
                                            id,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('View'),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingXL),
              // Row: Upcoming Trainings (max 5) + Newcomers table
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingMD),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l?.classes ?? 'Upcoming Trainings',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    if (scope != null) {
                                      scope.pushList(
                                        RouteNames.desktopTrainings,
                                      );
                                    } else {
                                      Navigator.of(
                                        context,
                                      ).pushReplacementNamed(
                                        RouteNames.desktopTrainings,
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  label: const Text('View all'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.spacingSM),
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_upcomingTrainingsList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: Text(
                                    l?.noData ?? 'No upcoming trainings',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    theme.colorScheme.surfaceContainerHighest,
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Training')),
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Action')),
                                  ],
                                  rows: _upcomingTrainingsList.map((session) {
                                    final classId =
                                        session['class_id']?.toString() ?? '';
                                    final className =
                                        session['class_name']?.toString() ??
                                        '—';
                                    final dateStr = session['session_date'];
                                    final dateFormatted = dateStr != null
                                        ? dateFormat.format(
                                            DateTime.parse(dateStr),
                                          )
                                        : '—';
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(className)),
                                        DataCell(Text(dateFormatted)),
                                        DataCell(
                                          TextButton(
                                            onPressed: () {
                                              if (classId.isNotEmpty) {
                                                if (scope != null) {
                                                  scope.pushDetail(
                                                    RouteNames.classDetail,
                                                    classId,
                                                  );
                                                } else {
                                                  Navigator.of(
                                                    context,
                                                    rootNavigator: true,
                                                  ).pushNamed(
                                                    RouteNames.classDetail
                                                        .replaceAll(
                                                          ':id',
                                                          classId,
                                                        ),
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text('View'),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingLG),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingMD),
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
                                  icon: const Icon(Icons.open_in_new, size: 18),
                                  label: const Text('View all'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.spacingSM),
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_newcomersList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(
                                  AppDimensions.spacingLG,
                                ),
                                child: Center(
                                  child: Text(
                                    l?.noData ?? 'No newcomers',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    theme.colorScheme.surfaceContainerHighest,
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('Name')),
                                    DataColumn(label: Text('Phone')),
                                    DataColumn(label: Text('Action')),
                                  ],
                                  rows: _newcomersList.map((member) {
                                    final id = member['id']?.toString() ?? '';
                                    final firstName =
                                        member['first_name']?.toString() ?? '';
                                    final lastName =
                                        member['last_name']?.toString() ?? '';
                                    final name = [firstName, lastName]
                                        .where((s) => s.isNotEmpty)
                                        .join(' ')
                                        .trim();
                                    final displayName = name.isEmpty
                                        ? '—'
                                        : name;
                                    final phone =
                                        member['phone']?.toString() ?? '—';
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
                                                    RouteNames.memberDetail,
                                                    id,
                                                  );
                                                } else {
                                                  Navigator.of(
                                                    context,
                                                    rootNavigator: true,
                                                  ).pushNamed(
                                                    RouteNames.memberDetail
                                                        .replaceAll(':id', id),
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text('View'),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: l?.upcomingSessions ?? 'Upcoming Sessions',
                  value: _isLoading ? '...' : '$_upcomingSessions',
                  icon: Icons.event_outlined,
                  color: AppColors.primary,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.classes),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMD),
              Expanded(
                child: _SummaryCard(
                  title: l?.upcomingEvents ?? 'Upcoming Events',
                  value: _isLoading ? '...' : '$_upcomingEvents',
                  icon: Icons.calendar_today_outlined,
                  color: AppColors.secondary,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.events),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMD),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: l?.tasks ?? 'Tasks',
                  value: _isLoading ? '...' : '$_tasks',
                  icon: Icons.task_outlined,
                  color: AppColors.warning,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.tasks),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMD),
              Expanded(
                child: _SummaryCard(
                  title: l?.birthdays ?? 'Birthdays',
                  value: _isLoading ? '...' : '$_birthdays',
                  icon: Icons.cake_outlined,
                  color: AppColors.accent,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(RouteNames.upcomingBirthdays),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXL),
          Text(
            l?.quickActions ?? 'Quick Actions',
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
                title: l?.members ?? 'Members',
                icon: Icons.people_outlined,
                value: _isLoading ? null : '$_members',
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.members),
              ),
              _QuickActionCard(
                title: l?.departments ?? 'Departments',
                icon: Icons.business_outlined,
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.departments),
              ),
              _QuickActionCard(
                title: l?.classes ?? 'Trainings',
                icon: Icons.class_outlined,
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.classes),
              ),
              _QuickActionCard(
                title: l?.reports ?? 'Reports',
                icon: Icons.assessment_outlined,
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.reports),
              ),
              _QuickActionCard(
                title: l?.churchAttendance ?? 'Church Attendance',
                icon: Icons.church,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.churchAttendanceList),
              ),
              _QuickActionCard(
                title: l?.sundaySchool ?? 'Sunday School',
                icon: Icons.school,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.sundaySchoolAttendanceList),
              ),
              _QuickActionCard(
                title: l?.visitors ?? 'Visitors',
                icon: Icons.person_add_outlined,
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.visitors),
              ),
              _QuickActionCard(
                title: l?.teachings ?? 'Teachings',
                icon: Icons.menu_book_outlined,
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.teachings),
              ),
            ],
          ),
        ],
      ),
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

  const _DesktopStatChip({
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingLG,
            vertical: AppDimensions.paddingMD,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: AppDimensions.spacingMD),
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
                      color: AppColors.textSecondary,
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
