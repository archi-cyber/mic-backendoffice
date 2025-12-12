import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/event_service.dart';
import '../../services/supabase_service.dart';
import '../../services/member_service.dart';

/// Event detail page with registration and leader management
class EventDetailPage extends StatefulWidget {
  final String eventId;

  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  Map<String, dynamic>? _event;
  bool _isLoading = true;
  bool _isLeader = false;

  @override
  void initState() {
    super.initState();
    _checkLeaderStatus();
    _loadEventData();
  }

  Future<void> _checkLeaderStatus() async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser != null) {
        final role = currentUser.userMetadata?['role']?.toString();
        setState(() {
          _isLeader =
              role == 'admin' || role == 'pastor' || role == 'leader' || false;
        });
      }
    } catch (e) {
      // If error, default to false
      setState(() => _isLeader = false);
    }
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
        content: const Text('Are you sure you want to delete this event?'),
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_event!['title'] ?? 'Event'),
          actions: [
            if (_isLeader) ...[
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
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteEvent,
              ),
            ],
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.info)),
              Tab(text: 'Registrations', icon: Icon(Icons.people)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(event: _event!),
            _RegistrationsTab(
              eventId: widget.eventId,
              isLeader: _isLeader,
              onRegistrationsUpdated: _loadEventData,
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
                          eventTime.length >= 5
                              ? eventTime.substring(0, 5)
                              : eventTime,
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

/// Registrations tab
class _RegistrationsTab extends StatefulWidget {
  final String eventId;
  final bool isLeader;
  final VoidCallback onRegistrationsUpdated;

  const _RegistrationsTab({
    required this.eventId,
    required this.isLeader,
    required this.onRegistrationsUpdated,
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
          const SnackBar(
            content: Text('Successfully registered for event'),
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
              'Successfully registered ${selectedMembers.length} member(s)',
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
            content: Text('Error registering members: $e'),
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
          const SnackBar(
            content: Text('Successfully registered guest'),
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
            content: Text('Error registering guest: $e'),
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
        title: const Text('Remove Registration'),
        content: const Text(
          'Are you sure you want to remove this registration?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
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
            const SnackBar(
              content: Text('Registration removed successfully'),
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
              content: Text('Error removing registration: $e'),
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
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Action buttons
        if (!_isRegistered && !widget.isLeader)
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRegistering ? null : _handleSelfRegistration,
                icon: _isRegistering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add),
                label: Text(
                  _isRegistering ? 'Registering...' : 'Register for Event',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    AppDimensions.buttonHeightLG,
                  ),
                ),
              ),
            ),
          ),
        if (widget.isLeader)
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _registerMembers,
                    icon: const Icon(Icons.people),
                    label: const Text('Register Members'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, AppDimensions.buttonHeightMD),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSM),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _registerGuest,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Register Guest'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, AppDimensions.buttonHeightMD),
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
                    padding: const EdgeInsets.all(AppDimensions.paddingMD),
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
                        margin: const EdgeInsets.only(
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
                                ? guestName ?? 'Guest'
                                : '${member['first_name']} ${member['last_name']}',
                          ),
                          subtitle: isGuest
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (guestEmail != null)
                                      Text('Email: $guestEmail'),
                                    if (guestPhone != null)
                                      Text('Phone: $guestPhone'),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withOpacity(
                                          0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Guest',
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
                                  icon: const Icon(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading members: $e')));
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
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search members...',
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
            const Divider(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
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
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_selectedMemberIds.length} selected'),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppDimensions.spacingSM),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, _selectedMemberIds),
                        child: const Text('Register'),
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
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Register Guest',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppDimensions.spacingMD),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter guest name';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppDimensions.spacingMD),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (Optional)',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppDimensions.spacingMD),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone (Optional)',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppDimensions.spacingXL),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSM),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.pop(context, {
                              'name': _nameController.text.trim(),
                              'email': _emailController.text.trim().isEmpty
                                  ? null
                                  : _emailController.text.trim(),
                              'phone': _phoneController.text.trim().isEmpty
                                  ? null
                                  : _phoneController.text.trim(),
                            });
                          }
                        },
                        child: const Text('Register'),
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
