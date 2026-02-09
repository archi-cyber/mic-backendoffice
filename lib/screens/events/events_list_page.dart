import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/event_service.dart';
import '../desktop/desktop_shell_scope.dart';

/// Events list (visible to all members)
class EventsListPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const EventsListPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

const double _kEventsDesktopBreakpoint = 700;
const double _kEventsDesktopMaxWidth = 1000;
const int _kEventsRowsPerPage = 10;

class _EventsListPageState extends State<EventsListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canCreate = false;
  int _eventsPage = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadEvents();
  }

  Future<void> _checkPermissions() async {
    final canEdit = await PermissionHelper.canEdit('events');
    final canDelete = await PermissionHelper.canDelete('events');
    final canCreate = await PermissionHelper.canCreate('events');
    if (!mounted) return;
    setState(() {
      _canEdit = canEdit;
      _canDelete = canDelete;
      _canCreate = canCreate;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final events = await EventService.getEvents(
        fromDate: DateTime.now().subtract(const Duration(days: 30)),
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _events = events;
        _isLoading = false;
        _eventsPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading events: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredEvents {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _events;
    }
    return _events
        .where(
          (event) =>
              (event['title']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (event['description']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (event['location']?.toString().toLowerCase().contains(query) ??
                  false),
        )
        .toList();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  int get _totalEventsPages {
    if (_filteredEvents.isEmpty) return 1;
    return (_filteredEvents.length / _kEventsRowsPerPage).ceil();
  }

  List<Map<String, dynamic>> get _paginatedEvents {
    final start = _eventsPage * _kEventsRowsPerPage;
    final end = (start + _kEventsRowsPerPage).clamp(0, _filteredEvents.length);
    if (start >= _filteredEvents.length) return [];
    return _filteredEvents.sublist(start, end);
  }

  void _openEventDetail(String eventId) {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.eventDetail, eventId);
    } else {
      Navigator.of(
        context,
      ).pushNamed(RouteNames.eventDetail.replaceAll(':id', eventId));
    }
  }

  bool _isUpcomingEvent(Map<String, dynamic> event) {
    if (event['event_date'] == null) return false;
    try {
      final eventDate = DateTime.parse(event['event_date']);
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final eventDateStart = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
      );
      return eventDateStart.isAfter(todayStart) ||
          eventDateStart.isAtSameMomentAs(todayStart);
    } catch (e) {
      return false;
    }
  }

  Future<void> _deleteEvent(String eventId, String eventTitle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "$eventTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await EventService.deleteEvent(eventId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadEvents();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting event: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final eventDate = event['event_date'] != null
        ? DateTime.parse(event['event_date'])
        : null;
    final isRepeated = event['is_repeated'] == true;
    final isUpcoming = _isUpcomingEvent(event);
    final eventId = event['id'].toString();
    final eventTitle = event['title'] ?? 'Event';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.paddingSM,
      ),
      child: InkWell(
        onTap: () => _openEventDetail(eventId),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      eventTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (isRepeated)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingSM,
                        vertical: AppDimensions.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSM,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.repeat,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: AppDimensions.spacingXS),
                          Text(
                            'Repeated',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Edit and Delete buttons for upcoming events
                  if (isUpcoming && (_canEdit || _canDelete)) ...[
                    const SizedBox(width: AppDimensions.spacingXS),
                    if (_canEdit)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: AppColors.primary,
                        onPressed: () {
                          final scope = DesktopShellScope.maybeOf(context);
                          if (scope != null) {
                            scope.pushDetail(RouteNames.editEvent, eventId);
                          } else {
                            Navigator.of(context)
                                .pushNamed(
                                  RouteNames.editEvent.replaceAll(
                                    ':id',
                                    eventId,
                                  ),
                                )
                                .then((result) {
                                  if (result == true) {
                                    _loadEvents();
                                  }
                                });
                          }
                        },
                        tooltip: 'Edit Event',
                      ),
                    if (_canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        color: AppColors.error,
                        onPressed: () {
                          _deleteEvent(eventId, eventTitle);
                        },
                        tooltip: 'Delete Event',
                      ),
                  ],
                ],
              ),
              if (eventDate != null) ...[
                const SizedBox(height: AppDimensions.spacingSM),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppDimensions.spacingXS),
                    Text(
                      _formatDate(eventDate),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              if (event['location'] != null) ...[
                const SizedBox(height: AppDimensions.spacingXS),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppDimensions.spacingXS),
                    Expanded(
                      child: Text(
                        event['location'],
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDesktop =
        widget.hideAppBarAndBottomNav &&
        MediaQuery.sizeOf(context).width >= _kEventsDesktopBreakpoint;

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(localizations?.events ?? 'Events'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadEvents,
                  tooltip: 'Refresh',
                ),
              ],
            ),
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(context),
      floatingActionButton: isDesktop
          ? null
          : FutureBuilder<bool>(
              future: PermissionHelper.canCreate('events'),
              builder: (context, snapshot) {
                final canCreate = snapshot.data ?? false;
                if (!canCreate) return const SizedBox.shrink();
                return FloatingActionButton.extended(
                  onPressed: () async {
                    final scope = DesktopShellScope.maybeOf(context);
                    if (scope != null) {
                      scope.pushDetail(RouteNames.addEvent, '');
                    } else {
                      final result = await Navigator.of(
                        context,
                      ).pushNamed(RouteNames.addEvent);
                      if (result == true) {
                        _loadEvents();
                      }
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Event'),
                );
              },
            ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kEventsDesktopMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search events...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => setState(() {
                        _eventsPage = 0;
                      }),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMD),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _loadEvents,
                    tooltip: 'Refresh',
                  ),
                  const Spacer(),
                  if (_canCreate)
                    FilledButton.icon(
                      onPressed: () {
                        final scope = DesktopShellScope.maybeOf(context);
                        if (scope != null) {
                          scope.pushDetail(RouteNames.addEvent, '');
                        } else {
                          Navigator.of(
                            context,
                          ).pushNamed(RouteNames.addEvent).then((result) {
                            if (result == true) _loadEvents();
                          });
                        }
                      },
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Event'),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.event_busy,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: AppDimensions.spacingMD),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No events found matching your search'
                                  : 'No events found',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEvents,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      theme.colorScheme.surfaceContainerHighest,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('Title')),
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Location')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _paginatedEvents.map((event) {
                                final id = event['id']?.toString() ?? '';
                                final title =
                                    event['title']?.toString() ?? 'Event';
                                final dateStr = event['event_date'];
                                final dateFormatted = dateStr != null
                                    ? _formatDate(DateTime.parse(dateStr))
                                    : '—';
                                final location =
                                    event['location']?.toString() ?? '—';
                                final isUpcoming = _isUpcomingEvent(event);
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      InkWell(
                                        onTap: () => _openEventDetail(id),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            title,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(dateFormatted)),
                                    DataCell(
                                      Text(
                                        location,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                _openEventDetail(id),
                                            child: const Text('View'),
                                          ),
                                          if (_canEdit && isUpcoming) ...[
                                            const SizedBox(width: 4),
                                            TextButton(
                                              onPressed: () {
                                                final scope =
                                                    DesktopShellScope.maybeOf(
                                                      context,
                                                    );
                                                if (scope != null) {
                                                  scope.pushDetail(
                                                    RouteNames.editEvent,
                                                    id,
                                                  );
                                                } else {
                                                  Navigator.of(context)
                                                      .pushNamed(
                                                        RouteNames.editEvent
                                                            .replaceAll(
                                                              ':id',
                                                              id,
                                                            ),
                                                      )
                                                      .then((result) {
                                                        if (result == true) {
                                                          _loadEvents();
                                                        }
                                                      });
                                                }
                                              },
                                              child: const Text('Edit'),
                                            ),
                                          ],
                                          if (_canDelete && isUpcoming) ...[
                                            const SizedBox(width: 4),
                                            TextButton(
                                              onPressed: () =>
                                                  _deleteEvent(id, title),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.error,
                                              ),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ],
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
                        ),
                      ),
              ),
              if (_filteredEvents.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingSM),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rows per page: $_kEventsRowsPerPage',
                      style: theme.textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        Text(
                          'Page ${_eventsPage + 1} of $_totalEventsPages',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: AppDimensions.spacingSM),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _eventsPage > 0
                              ? () => setState(
                                  () => _eventsPage = _eventsPage - 1,
                                )
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _eventsPage < _totalEventsPages - 1
                              ? () => setState(
                                  () => _eventsPage = _eventsPage + 1,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search events...',
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppDimensions.spacingMD),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'No events found matching your search'
                            : 'No events found',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  child: ListView.builder(
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      return _buildEventCard(_filteredEvents[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
