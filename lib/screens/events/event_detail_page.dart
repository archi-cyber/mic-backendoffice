import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/event_service.dart';
import '../../services/supabase_service.dart';
import '../../services/member_service.dart';
import '../../core/utils/permission_helper.dart';
import '../desktop/desktop_shell_scope.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/desktop/desktop_ui.dart';
import '../../widgets/phone_number_field.dart';

/// Event detail page with registration and leader management
class EventDetailPage extends StatefulWidget {
  final String eventId;

  /// When set (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  EventDetailPage({super.key, required this.eventId, this.onClose});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  Map<String, dynamic>? _event;
  bool _isLoading = true;
  bool _canEdit = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadEventData();
  }

  Future<void> _checkPermissions() async {
    final canEdit = await PermissionHelper.canEdit('events');
    final canDelete = await PermissionHelper.canDelete('events');
    if (!mounted) return;
    setState(() {
      _canEdit = canEdit;
      _canDelete = canDelete;
    });
  }

  Future<void> _loadEventData() async {
    setState(() => _isLoading = true);
    try {
      final event = await EventService.getEventById(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = event;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading event: $e'))),
        );
      }
    }
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete Event')),
        content: Text(
          context.tr('Are you sure you want to delete this event?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await EventService.deleteEvent(widget.eventId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Event deleted successfully')),
              backgroundColor: AppColors.success,
            ),
          );
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.of(context).pop(true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error deleting event: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _openEditEvent() {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.editEvent, widget.eventId);
    } else {
      Navigator.of(context)
          .pushNamed(
            RouteNames.editEvent.replaceAll(':id', widget.eventId),
          )
          .then((result) {
            if (result == true) _loadEventData();
          });
    }
  }

  String? _eventSubtitle(Map<String, dynamic> event) {
    final parts = <String>[];
    if (event['event_date'] != null) {
      final date = DateTime.parse(event['event_date']);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      parts.add('${months[date.month - 1]} ${date.day}, ${date.year}');
    }
    final eventTime = event['event_time']?.toString();
    if (eventTime != null) {
      parts.add(
        eventTime.length >= 5 ? eventTime.substring(0, 5) : eventTime,
      );
    }
    if (event['location'] != null) {
      parts.add(event['location'].toString());
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      leading: widget.onClose != null
          ? IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: widget.onClose,
            )
          : null,
      title: Text(_event!['title'] ?? context.tr('Event')),
      actions: [
        if (_canEdit)
          IconButton(icon: Icon(Icons.edit), onPressed: _openEditEvent),
        if (_canDelete)
          IconButton(icon: Icon(Icons.delete), onPressed: _deleteEvent),
      ],
      bottom: TabBar(
        tabs: [
          Tab(text: context.tr('Overview'), icon: Icon(Icons.info)),
          Tab(text: context.tr('Registrations'), icon: Icon(Icons.people)),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final event = _event!;
    final tabHeight = (MediaQuery.sizeOf(context).height - 300).clamp(420.0, 720.0);

    return DesktopPageShell(
      maxWidth: kDesktopContentMaxWidth,
      banner: DesktopHeroBanner(
        title: event['title']?.toString() ?? context.tr('Event'),
        subtitle: _eventSubtitle(event),
        icon: Icons.event,
        accent: AppColors.primary,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: context.tr('Edit'),
                onPressed: _openEditEvent,
              ),
            if (_canDelete)
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: context.tr('Delete'),
                onPressed: _deleteEvent,
              ),
          ],
        ),
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          side: BorderSide(color: context.mic.border.withValues(alpha: 0.75)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: context.mic.textSecondary,
              tabs: [
                Tab(text: context.tr('Overview'), icon: Icon(Icons.info_outline)),
                Tab(
                  text: context.tr('Registrations'),
                  icon: Icon(Icons.people_outline),
                ),
              ],
            ),
            SizedBox(
              height: tabHeight,
              child: TabBarView(
                children: [
                  _OverviewTab(event: event, isDesktop: true),
                  _RegistrationsTab(
                    eventId: widget.eventId,
                    isLeader: _canEdit || _canDelete,
                    onRegistrationsUpdated: _loadEventData,
                    isDesktop: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inShell = widget.onClose != null;
    final embedded = isDesktopEmbedded(context, inShell: inShell);

    if (_isLoading) {
      if (embedded) {
        return Scaffold(
          body: DesktopPageShell(
            isLoading: true,
            maxWidth: kDesktopContentMaxWidth,
            child: const SizedBox.shrink(),
          ),
        );
      }
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_event == null) {
      return Scaffold(
        appBar: embedded
            ? null
            : AppBar(
                title: Text(context.tr('Event')),
                leading: widget.onClose != null
                    ? IconButton(
                        icon: Icon(Icons.arrow_back),
                        onPressed: widget.onClose,
                      )
                    : null,
              ),
        body: Center(child: Text(context.tr('Event not found'))),
      );
    }

    if (embedded) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: null,
          body: _buildDesktopBody(context),
        ),
      );
    }

    final desktopMaxWidth =
        MediaQuery.sizeOf(context).width >= kDesktopEmbeddedBreakpoint
            ? 900.0
            : null;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _buildMobileAppBar(),
        body: TabBarView(
          children: [
            _OverviewTab(event: _event!, desktopMaxWidth: desktopMaxWidth),
            _RegistrationsTab(
              eventId: widget.eventId,
              isLeader: _canEdit || _canDelete,
              onRegistrationsUpdated: _loadEventData,
              desktopMaxWidth: desktopMaxWidth,
            ),
          ],
        ),
      ),
    );
  }
}

/// Overview tab
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> event;
  final double? desktopMaxWidth;
  final bool isDesktop;

  _OverviewTab({
    required this.event,
    this.desktopMaxWidth,
    this.isDesktop = false,
  });

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

  Widget _buildDesktopContent(BuildContext context) {
    final eventDate = event['event_date'] != null
        ? DateTime.parse(event['event_date'])
        : null;
    final eventTime = event['event_time']?.toString();
    final isRepeated = event['is_repeated'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesktopSectionCard(
          title: context.tr('Event information'),
          icon: Icons.info_outline,
          children: [
            if (eventDate != null) ...[
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
                  SizedBox(width: AppDimensions.spacingSM),
                  Text(
                    _formatDate(eventDate),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingSM),
            ],
            if (eventTime != null) ...[
              Row(
                children: [
                  Icon(Icons.access_time, size: 20, color: AppColors.primary),
                  SizedBox(width: AppDimensions.spacingSM),
                  Text(
                    eventTime.length >= 5
                        ? eventTime.substring(0, 5)
                        : eventTime,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingSM),
            ],
            if (event['location'] != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, size: 20, color: AppColors.primary),
                  SizedBox(width: AppDimensions.spacingSM),
                  Expanded(
                    child: Text(
                      event['location'],
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingSM),
            ],
            if (isRepeated)
              Row(
                children: [
                  Icon(Icons.repeat, size: 20, color: AppColors.primary),
                  SizedBox(width: AppDimensions.spacingSM),
                  Text(
                    context.tr('Repeated Event'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (event['description'] != null) ...[
          SizedBox(height: AppDimensions.spacingMD),
          DesktopSectionCard(
            title: context.tr('Description'),
            icon: Icons.description_outlined,
            accent: AppColors.info,
            children: [
              Text(
                event['description'],
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final eventDate = event['event_date'] != null
        ? DateTime.parse(event['event_date'])
        : null;
    final eventTime = event['event_time']?.toString();
    final isRepeated = event['is_repeated'] == true;

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'] ?? context.tr('Event'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  if (eventDate != null) ...[
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 20),
                        SizedBox(width: AppDimensions.spacingSM),
                        Text(
                          _formatDate(eventDate),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    SizedBox(height: AppDimensions.spacingSM),
                  ],
                  if (eventTime != null) ...[
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 20),
                        SizedBox(width: AppDimensions.spacingSM),
                        Text(
                          eventTime.length >= 5
                              ? eventTime.substring(0, 5)
                              : eventTime,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    SizedBox(height: AppDimensions.spacingSM),
                  ],
                  if (event['location'] != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, size: 20),
                        SizedBox(width: AppDimensions.spacingSM),
                        Expanded(
                          child: Text(
                            event['location'],
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppDimensions.spacingSM),
                  ],
                  if (isRepeated) ...[
                    Row(
                      children: [
                        Icon(Icons.repeat, size: 20, color: AppColors.primary),
                        SizedBox(width: AppDimensions.spacingSM),
                        Text(
                          context.tr('Repeated Event'),
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
          SizedBox(height: AppDimensions.spacingMD),
          if (event['description'] != null) ...[
            Text(context.tr('Description'), style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: AppDimensions.spacingSM),
            Text(
              event['description'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: _buildDesktopContent(context),
      );
    }
    if (desktopMaxWidth != null) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktopMaxWidth!),
          child: _buildContent(context),
        ),
      );
    }
    return _buildContent(context);
  }
}

/// Registrations tab
class _RegistrationsTab extends StatefulWidget {
  final String eventId;
  final bool isLeader;
  final VoidCallback onRegistrationsUpdated;
  final double? desktopMaxWidth;
  final bool isDesktop;

  _RegistrationsTab({
    required this.eventId,
    required this.isLeader,
    required this.onRegistrationsUpdated,
    this.desktopMaxWidth,
    this.isDesktop = false,
  });

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

      if (!mounted) return;
      setState(() {
        _registrations = results[0] as List<Map<String, dynamic>>;
        _isRegistered = results[1] as bool;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading registrations: $e')),
          ),
        );
      }
    }
  }

  Future<bool> _checkRegistrationStatus() async {
    try {
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId == null) return false;

      // Get current user's member ID from users table
      final user = await SupabaseService.client
          .from('users')
          .select('member_id')
          .eq('id', currentUserId)
          .maybeSingle();

      if (user == null || user['member_id'] == null) return false;

      final memberId = user['member_id'].toString();

      final registration = await SupabaseService.client
          .from('event_registrations')
          .select()
          .eq('event_id', widget.eventId)
          .eq('member_id', memberId)
          .maybeSingle();

      return registration != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleSelfRegistration() async {
    setState(() => _isRegistering = true);
    try {
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's member ID from users table
      final user = await SupabaseService.client
          .from('users')
          .select('member_id')
          .eq('id', currentUserId)
          .maybeSingle();

      if (user == null || user['member_id'] == null) {
        throw Exception('Member profile not found');
      }

      final memberId = user['member_id'].toString();

      await EventService.registerForEvent(
        eventId: widget.eventId,
        memberId: memberId,
      );

      if (mounted) {
        setState(() {
          _isRegistered = true;
          _isRegistering = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Successfully registered for event')),
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
            content: Text(context.tr('Registration failed: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _registerMembers() async {
    final selectedMembers = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _MemberSelectionDialog(),
    );

    if (selectedMembers == null || selectedMembers.isEmpty) return;

    try {
      await EventService.registerMembersForEvent(
        eventId: widget.eventId,
        memberIds: selectedMembers.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Successfully registered {count} member(s)', {
                'count': selectedMembers.length,
              }),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
        widget.onRegistrationsUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error registering members: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _registerGuest() async {
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => _GuestRegistrationDialog(),
    );

    if (result == null) return;

    try {
      await EventService.registerGuestForEvent(
        eventId: widget.eventId,
        guestName: result['name']!,
        guestEmail: result['email'],
        guestPhone: result['phone'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Successfully registered guest')),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
        widget.onRegistrationsUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error registering guest: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeRegistration(String registrationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove Registration')),
        content: Text(
          context.tr('Are you sure you want to remove this registration?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Remove')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await EventService.removeRegistration(
          eventId: widget.eventId,
          registrationId: registrationId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Registration removed successfully')),
              backgroundColor: AppColors.success,
            ),
          );
          _loadData();
          widget.onRegistrationsUpdated();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error removing registration: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildRegistrationsContent(BuildContext context) {
    return Column(
      children: [
        // Action buttons
        if (!_isRegistered && !widget.isLeader)
          Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRegistering ? null : _handleSelfRegistration,
                icon: _isRegistering
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.person_add),
                label: Text(
                  _isRegistering
                      ? context.tr('Registering...')
                      : context.tr('Register for Event'),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(
                    double.infinity,
                    AppDimensions.buttonHeightLG,
                  ),
                ),
              ),
            ),
          ),
        if (widget.isLeader)
          Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _registerMembers,
                    icon: Icon(Icons.people),
                    label: Text(context.tr('Register Members')),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(0, AppDimensions.buttonHeightMD),
                    ),
                  ),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _registerGuest,
                    icon: Icon(Icons.person_add),
                    label: Text(context.tr('Register Guest')),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(0, AppDimensions.buttonHeightMD),
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Registrations list
        Expanded(
          child: _registrations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: context.mic.textSecondary,
                      ),
                      SizedBox(height: AppDimensions.spacingMD),
                      Text(context.tr('No registrations yet')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: EdgeInsets.all(AppDimensions.paddingMD),
                    itemCount: _registrations.length,
                    itemBuilder: (context, index) {
                      final registration = _registrations[index];
                      final member =
                          registration['members'] as Map<String, dynamic>?;
                      final guestName = registration['guest_name'] as String?;
                      final guestEmail = registration['guest_email'] as String?;
                      final guestPhone = registration['guest_phone'] as String?;
                      final isGuest = member == null;

                      return Card(
                        margin: EdgeInsets.only(
                          bottom: AppDimensions.spacingMD,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isGuest
                                ? AppColors.warning
                                : AppColors.primary,
                            child: Icon(
                              isGuest ? Icons.person : Icons.person_outline,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            isGuest
                                ? guestName ?? context.tr('Guest')
                                : '${member['first_name']} ${member['last_name']}',
                          ),
                          subtitle: isGuest
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (guestEmail != null)
                                      Text(context.tr('Email: $guestEmail')),
                                    if (guestPhone != null)
                                      Text(context.tr('Phone: $guestPhone')),
                                    SizedBox(height: 4),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        context.tr('Guest'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(member['email']?.toString() ?? ''),
                          trailing: widget.isLeader
                              ? IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () => _removeRegistration(
                                    registration['id'].toString(),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    final content = _buildRegistrationsContent(context);
    if (widget.isDesktop) {
      return Padding(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: content,
      );
    }
    if (widget.desktopMaxWidth != null) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.desktopMaxWidth!),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Member selection dialog
class _MemberSelectionDialog extends StatefulWidget {
  @override
  State<_MemberSelectionDialog> createState() => _MemberSelectionDialogState();
}

class _MemberSelectionDialogState extends State<_MemberSelectionDialog> {
  List<Map<String, dynamic>> _allMembers = [];
  final _searchController = TextEditingController();
  final Set<String> _selectedMemberIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await MemberService.getMembers(limit: 1000);
      setState(() {
        _allMembers = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading members: $e'))),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMembers {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _allMembers;
    }
    return _allMembers
        .where(
          (member) =>
              (member['first_name']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (member['last_name']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (member['email']?.toString().toLowerCase().contains(query) ??
                  false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.tr('Search members...'),
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
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
            Divider(),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        final memberId = member['id'].toString();
                        final isSelected = _selectedMemberIds.contains(
                          memberId,
                        );

                        return CheckboxListTile(
                          title: Text(
                            '${member['first_name']} ${member['last_name']}',
                          ),
                          subtitle: Text(member['email']?.toString() ?? ''),
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedMemberIds.add(memberId);
                              } else {
                                _selectedMemberIds.remove(memberId);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            Divider(),
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('${_selectedMemberIds.length} selected')),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.tr('Cancel')),
                      ),
                      SizedBox(width: AppDimensions.spacingSM),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, _selectedMemberIds),
                        child: Text(context.tr('Register')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guest registration dialog
class _GuestRegistrationDialog extends StatefulWidget {
  @override
  State<_GuestRegistrationDialog> createState() =>
      _GuestRegistrationDialogState();
}

class _GuestRegistrationDialogState extends State<_GuestRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneInput = PhoneNumberInputController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: 500),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('Register Guest'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: AppDimensions.spacingMD),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: context.tr('Full Name *'),
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('Please enter guest name');
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: AppDimensions.spacingMD),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: context.tr('Email (Optional)'),
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: AppDimensions.spacingMD),
                PhoneNumberField(
                  controller: _phoneInput,
                  optional: true,
                  decoration: InputDecoration(
                    labelText: context.tr('Phone (Optional)'),
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXL),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.tr('Cancel')),
                      ),
                    ),
                    SizedBox(width: AppDimensions.spacingSM),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.pop(context, {
                              'name': _nameController.text.trim(),
                              'email': _emailController.text.trim().isEmpty
                                  ? null
                                  : _emailController.text.trim(),
                              'phone': _phoneInput.storedValue,
                            });
                          }
                        },
                        child: Text(context.tr('Register')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
