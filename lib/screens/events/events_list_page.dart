import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/event_service.dart';

/// Events list (visible to all members)
class EventsListPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const EventsListPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  bool _canEdit = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadEvents();
  }

  Future<void> _checkPermissions() async {
    final canEdit = await PermissionHelper.canEdit('events');
    final canDelete = await PermissionHelper.canDelete('events');
    setState(() {
      _canEdit = canEdit;
      _canDelete = canDelete;
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
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
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
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(RouteNames.eventDetail.replaceAll(':id', eventId));
        },
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
                        color: AppColors.primary.withOpacity(0.1),
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
                          Navigator.of(context)
                              .pushNamed(
                                RouteNames.editEvent.replaceAll(':id', eventId),
                              )
                              .then((result) {
                                if (result == true) {
                                  _loadEvents();
                                }
                              });
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
      body: Column(
        children: [
          // Search bar
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
          // Events list
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
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: PermissionHelper.canCreate('events'),
        builder: (context, snapshot) {
          final canCreate = snapshot.data ?? false;
          if (!canCreate) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.of(
                context,
              ).pushNamed(RouteNames.addEvent);
              if (result == true) {
                _loadEvents();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Event'),
          );
        },
      ),
    );
  }
}
