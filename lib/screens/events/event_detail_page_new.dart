import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/event_service.dart';
import '../../services/supabase_service.dart';

/// Event detail page with tabs for overview, sessions, registrations, and attendance
class EventDetailPage extends StatefulWidget {
  final String eventId;

  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  Map<String, dynamic>? _event;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEventData();
  }

  Future<void> _loadEventData() async {
    setState(() => _isLoading = true);
    try {
      final event = await EventService.getEventById(widget.eventId);
      setState(() {
        _event = event;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading event: $e')));
      }
    }
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
          'Are you sure you want to delete this event? This will deactivate it.',
        ),
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
        await EventService.deleteEvent(widget.eventId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event')),
        body: const Center(child: Text('Event not found')),
      );
    }

    final isRepeated = _event!['is_repeated'] == true;
    final tabCount = isRepeated
        ? 4
        : 3; // Sessions tab only for repeated events

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_event!['title'] ?? 'Event'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.of(context).pushNamed(
                  RouteNames.editEvent.replaceAll(':id', widget.eventId),
                );
                if (result == true) {
                  _loadEventData();
                }
              },
              tooltip: 'Edit Event',
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.delete, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Delete Event'),
                    ],
                  ),
                  onTap: () => _deleteEvent(),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Overview'),
              if (isRepeated) const Tab(text: 'Sessions'),
              const Tab(text: 'Registrations'),
              const Tab(text: 'Attendance'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(event: _event!),
            if (isRepeated)
              _SessionsTab(
                eventId: widget.eventId,
                onSessionsUpdated: _loadEventData,
              ),
            _RegistrationsTab(eventId: widget.eventId),
            _AttendanceTab(eventId: widget.eventId, isRepeated: isRepeated),
          ],
        ),
      ),
    );
  }
}

/// Overview tab
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> event;

  const _OverviewTab({required this.event});

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

  @override
  Widget build(BuildContext context) {
    final eventDate = event['event_date'] != null
        ? DateTime.parse(event['event_date'])
        : null;
    final eventTime = event['event_time']?.toString();
    final isRepeated = event['is_repeated'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] ?? 'Event',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  if (eventDate != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: AppDimensions.spacingSM),
                        Text(
                          _formatDate(eventDate),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingSM),
                  ],
                  if (eventTime != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 20),
                        const SizedBox(width: AppDimensions.spacingSM),
                        Text(
                          eventTime.substring(0, 5), // HH:mm format
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingSM),
                  ],
                  if (event['location'] != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 20),
                        const SizedBox(width: AppDimensions.spacingSM),
                        Expanded(
                          child: Text(
                            event['location'],
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingSM),
                  ],
                  if (isRepeated) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.repeat,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppDimensions.spacingSM),
                        Text(
                          'Repeated Event',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMD),
          // Description
          if (event['description'] != null) ...[
            Text('Description', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimensions.spacingSM),
            Text(
              event['description'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// Sessions tab (for repeated events)
class _SessionsTab extends StatefulWidget {
  final String eventId;
  final VoidCallback onSessionsUpdated;

  const _SessionsTab({required this.eventId, required this.onSessionsUpdated});

  @override
  State<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<_SessionsTab> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isGenerating = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await EventService.getEventSessions(widget.eventId);
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading sessions: $e')));
      }
    }
  }

  Future<void> _generateSessions() async {
    // Similar to class sessions generation dialog
    // For now, show a simple dialog
    final numberOfSessions = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Sessions'),
        content: const Text('Enter number of sessions to generate'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 4),
            child: const Text('Generate 4'),
          ),
        ],
      ),
    );

    if (numberOfSessions == null) return;

    setState(() => _isGenerating = true);
    try {
      await EventService.generateEventSessions(
        eventId: widget.eventId,
        numberOfSessions: numberOfSessions,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessions generated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadSessions();
        widget.onSessionsUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating sessions: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Event Sessions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateSessions,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Generate Sessions'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _sessions.isEmpty
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
                      const Text('No sessions generated yet'),
                      const SizedBox(height: AppDimensions.spacingSM),
                      ElevatedButton(
                        onPressed: _generateSessions,
                        child: const Text('Generate Sessions'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final sessionDate = session['session_date'] != null
                          ? DateTime.parse(session['session_date'])
                          : null;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingMD,
                          vertical: AppDimensions.paddingSM,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(
                            sessionDate != null
                                ? _formatDate(sessionDate)
                                : 'Session ${index + 1}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: AppColors.error,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Session'),
                                  content: const Text(
                                    'Are you sure you want to delete this session?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                try {
                                  await EventService.deleteEventSession(
                                    eventId: widget.eventId,
                                    sessionId: session['id'].toString(),
                                  );
                                  if (mounted) {
                                    _loadSessions();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error deleting session: $e',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// Registrations tab
class _RegistrationsTab extends StatefulWidget {
  final String eventId;

  const _RegistrationsTab({required this.eventId});

  @override
  State<_RegistrationsTab> createState() => _RegistrationsTabState();
}

class _RegistrationsTabState extends State<_RegistrationsTab> {
  List<Map<String, dynamic>> _registrations = [];
  bool _isLoading = true;
  bool _isRegistered = false;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        EventService.getEventRegistrations(widget.eventId),
        _checkRegistrationStatus(),
      ]);

      setState(() {
        _registrations = results[0] as List<Map<String, dynamic>>;
        _isRegistered = results[1] as bool;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading registrations: $e')),
        );
      }
    }
  }

  Future<bool> _checkRegistrationStatus() async {
    try {
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId == null) return false;

      final registrations = await SupabaseService.client
          .from('event_registrations')
          .select()
          .eq('event_id', widget.eventId)
          .eq('member_id', currentUserId)
          .maybeSingle();

      return registrations != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleRegistration() async {
    setState(() => _isRegistering = true);
    try {
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      if (_isRegistered) {
        await EventService.unregisterFromEvent(
          eventId: widget.eventId,
          memberId: currentUserId,
        );
      } else {
        await EventService.registerForEvent(
          eventId: widget.eventId,
          memberId: currentUserId,
        );
      }

      if (mounted) {
        setState(() {
          _isRegistered = !_isRegistered;
          _isRegistering = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isRegistered
                  ? 'Successfully registered for event'
                  : 'Successfully unregistered from event',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      setState(() => _isRegistering = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRegistering ? null : _handleRegistration,
              icon: _isRegistering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isRegistered ? Icons.cancel : Icons.check),
              label: Text(_isRegistered ? 'Unregister' : 'Register for Event'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  AppDimensions.buttonHeightLG,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _registrations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppDimensions.spacingMD),
                      const Text('No registrations yet'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    itemCount: _registrations.length,
                    itemBuilder: (context, index) {
                      final registration = _registrations[index];
                      final member =
                          registration['members'] as Map<String, dynamic>?;

                      if (member == null) return const SizedBox.shrink();

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingMD,
                          vertical: AppDimensions.paddingSM,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member['first_name']?[0]
                                      ?.toString()
                                      .toUpperCase() ??
                                  'M',
                            ),
                          ),
                          title: Text(
                            '${member['first_name']} ${member['last_name']}',
                          ),
                          subtitle: Text(member['email']?.toString() ?? ''),
                          trailing: Text(
                            registration['registered_at'] != null
                                ? DateTime.parse(
                                    registration['registered_at'],
                                  ).toString().split(' ')[0]
                                : '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// Attendance tab
class _AttendanceTab extends StatelessWidget {
  final String eventId;
  final bool isRepeated;

  const _AttendanceTab({required this.eventId, required this.isRepeated});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppDimensions.spacingMD),
          Text(
            isRepeated
                ? 'Attendance is tracked per session'
                : 'Attendance tracking coming soon',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
