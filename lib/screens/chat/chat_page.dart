import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/mic_theme.dart';
import '../../services/chat_service.dart';
import '../../services/chat_video_service.dart';
import '../../services/department_service.dart';
import '../../services/member_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/desktop/desktop_ui.dart';
import 'add_announcement_page.dart';
import 'chat_video_call_page.dart';
import 'edit_announcement_page.dart';
import '../../core/utils/permission_helper.dart';

const String _kEveryoneId = 'everyone';
const String _kDirectId = 'direct';

class _ChatChannel {
  const _ChatChannel({
    required this.id,
    required this.name,
    required this.icon,
    this.departmentId,
    this.isDirect = false,
    this.isEveryone = false,
    this.lastPreview,
    this.lastAt,
    this.count = 0,
  });

  final String id;
  final String name;
  final IconData icon;
  final String? departmentId;
  final bool isDirect;
  final bool isEveryone;
  final String? lastPreview;
  final DateTime? lastAt;
  final int count;
}

class _EmbeddedVideoCall {
  const _EmbeddedVideoCall({
    required this.roomName,
    required this.roomTitle,
    required this.displayName,
  });

  final String roomName;
  final String roomTitle;
  final String displayName;
}

/// Chat messaging view: conversation list + thread, adapted for desktop and mobile.
class ChatPage extends StatefulWidget {
  /// When true (e.g. desktop layout), no app bar is shown.
  final bool hideAppBarAndBottomNav;

  ChatPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocus = FocusNode();

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _allMembers = [];
  List<String> _directRecipientIds = [];

  bool _isLoading = true;
  bool _isSending = false;
  bool _canCreateAnnouncement = false;
  String? _currentUserId;
  String? _selectedChannelId;
  AnnouncementSubscription? _realtimeChannel;
  Timer? _reloadDebounce;
  bool _showAddAnnouncement = false;
  _EmbeddedVideoCall? _embeddedVideoCall;

  @override
  void initState() {
    super.initState();
    _currentUserId = SupabaseService.currentUser?.id;
    _checkPermissions();
    _loadDepartments();
    _loadAnnouncements();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _composerController.dispose();
    _composerFocus.dispose();
    _reloadDebounce?.cancel();
    _realtimeChannel?.cancel();
    super.dispose();
  }

  bool get _isWideLayout {
    return isDesktopEmbedded(
      context,
      hideAppBar: widget.hideAppBarAndBottomNav,
    );
  }

  void _subscribeRealtime() {
    try {
      _realtimeChannel = ChatService.subscribeToAnnouncements(() {
        _reloadDebounce?.cancel();
        _reloadDebounce = Timer(const Duration(milliseconds: 350), () {
          if (mounted) _loadAnnouncements(silent: true);
        });
      });
    } catch (e) {
      debugPrint('[ChatPage] Realtime subscribe failed: $e');
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final departments = await DepartmentService.getDepartments(limit: 100);
      if (!mounted) return;
      setState(() => _departments = departments);
    } catch (_) {
      // Department list is optional for channel grouping.
    }
  }

  /// Détermine si l'utilisateur peut publier une annonce.
  ///
  /// L'implémentation précédente terminait sa condition par `|| true`, ce qui
  /// accordait le droit à tout le monde — le commentaire annonçait d'ailleurs
  /// « restrict in production ». La permission est désormais réellement
  /// vérifiée.
  ///
  /// Ce contrôle ne sert qu'à masquer le bouton : le serveur refuse de toute
  /// façon une publication sans le droit `chat:create`.
  Future<void> _checkPermissions() async {
    try {
      final canCreate = await PermissionHelper.canCreate('chat');

      if (!mounted) return;
      setState(() => _canCreateAnnouncement = canCreate);
    } catch (e) {
      // En cas d'échec, on refuse : masquer un bouton légitime est une gêne,
      // en afficher un qui mènera à une erreur est pire.
      if (mounted) setState(() => _canCreateAnnouncement = false);
    }
  }

  Future<void> _loadAnnouncements({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final announcements = await ChatService.getAnnouncements(limit: 200);
      if (!mounted) return;
      setState(() {
        _announcements = announcements;
        _isLoading = false;
        if (_isWideLayout && _selectedChannelId == null) {
          _selectedChannelId = _kEveryoneId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Error loading announcements: $e'))),
      );
    }
  }

  String _channelIdFor(Map<String, dynamic> announcement) {
    if (announcement['is_global'] == true) return _kEveryoneId;
    final departmentId = announcement['department_id']?.toString();
    if (departmentId != null && departmentId.isNotEmpty) {
      return 'dept:$departmentId';
    }
    return _kDirectId;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _previewText(Map<String, dynamic> announcement) {
    final message = (announcement['message'] ?? '').toString().trim();
    if (message.isNotEmpty) {
      return message.replaceAll(RegExp(r'\s+'), ' ');
    }
    return (announcement['title'] ?? '').toString().trim();
  }

  List<_ChatChannel> get _channels {
    final latestByChannel = <String, Map<String, dynamic>>{};
    final counts = <String, int>{};
    for (final announcement in _announcements) {
      final id = _channelIdFor(announcement);
      counts[id] = (counts[id] ?? 0) + 1;
      final existing = latestByChannel[id];
      final existingDate = _parseDate(existing?['created_at']);
      final nextDate = _parseDate(announcement['created_at']);
      if (existing == null ||
          (nextDate != null &&
              (existingDate == null || nextDate.isAfter(existingDate)))) {
        latestByChannel[id] = announcement;
      }
    }

    _ChatChannel buildChannel({
      required String id,
      required String name,
      required IconData icon,
      String? departmentId,
      bool isDirect = false,
      bool isEveryone = false,
    }) {
      final latest = latestByChannel[id];
      return _ChatChannel(
        id: id,
        name: name,
        icon: icon,
        departmentId: departmentId,
        isDirect: isDirect,
        isEveryone: isEveryone,
        lastPreview: latest == null ? null : _previewText(latest),
        lastAt: _parseDate(latest?['created_at']),
        count: counts[id] ?? 0,
      );
    }

    final channels = <_ChatChannel>[
      buildChannel(
        id: _kEveryoneId,
        name: context.tr('Everyone'),
        icon: Icons.public,
        isEveryone: true,
      ),
    ];

    final departmentChannels = _departments.map((dept) {
      final id = dept['id']?.toString() ?? '';
      return buildChannel(
        id: 'dept:$id',
        name: dept['name']?.toString() ?? context.tr('Department'),
        icon: Icons.group_work_outlined,
        departmentId: id,
      );
    }).toList();

    departmentChannels.sort((a, b) {
      final aTime = a.lastAt;
      final bTime = b.lastAt;
      if (aTime != null && bTime != null) return bTime.compareTo(aTime);
      if (aTime != null) return -1;
      if (bTime != null) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    channels.addAll(departmentChannels);

    final hasDirect = (counts[_kDirectId] ?? 0) > 0;
    if (hasDirect || _canCreateAnnouncement) {
      channels.insert(
        1,
        buildChannel(
          id: _kDirectId,
          name: context.tr('Direct messages'),
          icon: Icons.person_outline,
          isDirect: true,
        ),
      );
    }

    return channels;
  }

  List<_ChatChannel> get _visibleChannels {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _channels;
    return _channels.where((channel) {
      return channel.name.toLowerCase().contains(query) ||
          (channel.lastPreview?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  _ChatChannel? get _selectedChannel {
    final id = _selectedChannelId;
    if (id == null) return null;
    for (final channel in _channels) {
      if (channel.id == id) return channel;
    }
    return null;
  }

  List<Map<String, dynamic>> get _threadMessages {
    final channel = _selectedChannel;
    if (channel == null) return const [];
    final messages = _announcements
        .where((item) => _channelIdFor(item) == channel.id)
        .toList();
    messages.sort((a, b) {
      final aDate = _parseDate(a['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _parseDate(b['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return messages;
  }

  Map<String, dynamic>? get _liveVideoCall {
    for (final message in _threadMessages) {
      if (ChatVideoService.isLiveVideoCall(message)) return message;
    }
    return null;
  }

  Future<void> _startOrJoinVideoCall() async {
    final channel = _selectedChannel;
    if (channel == null) return;

    final alreadyLive = _liveVideoCall != null;
    try {
      if (channel.isDirect &&
          _directRecipientIds.isEmpty &&
          _allMembers.isEmpty) {
        try {
          _allMembers = await MemberService.getMembers(limit: 1000);
        } catch (_) {}
      }

      try {
        await ChatVideoService.announceCallIfNeeded(
          channelName: channel.name,
          isEveryone: channel.isEveryone,
          departmentId: channel.departmentId,
          targetMemberIds: channel.isDirect ? _directRecipientIds : null,
          alreadyLive: alreadyLive,
        );
        if (!alreadyLive) {
          await _loadAnnouncements(silent: true);
        }
      } catch (e) {
        debugPrint('[ChatPage] Video call notify failed: $e');
      }

      if (!mounted) return;
      final displayName = await ChatVideoService.currentDisplayName();
      if (!mounted) return;
      await _openVideoCall(
        roomName: ChatVideoService.roomNameForChannel(channel.id),
        roomTitle: channel.name,
        displayName: displayName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Could not start video call')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _senderName(Map<String, dynamic> announcement) {
    if (_isMine(announcement)) return context.tr('You');
    final user = announcement['users'];
    if (user is Map) {
      final members = user['members'];
      Map<String, dynamic>? member;
      if (members is Map<String, dynamic>) {
        member = members;
      } else if (members is List && members.isNotEmpty && members.first is Map) {
        member = Map<String, dynamic>.from(members.first as Map);
      }
      final first = member?['first_name']?.toString() ?? '';
      final last = member?['last_name']?.toString() ?? '';
      final name = '$first $last'.trim();
      if (name.isNotEmpty) return name;
      final email = user['email']?.toString() ?? '';
      if (email.isNotEmpty) return email.split('@').first;
    }
    return context.tr('Member');
  }

  bool _isMine(Map<String, dynamic> announcement) {
    final createdBy = announcement['created_by']?.toString();
    return createdBy != null &&
        createdBy.isNotEmpty &&
        createdBy == _currentUserId;
  }

  bool _shouldShowTitle(Map<String, dynamic> announcement) {
    final title = (announcement['title'] ?? '').toString().trim();
    final message = (announcement['message'] ?? '').toString().trim();
    if (title.isEmpty) return false;
    if (title == message) return false;
    if (message.startsWith(title)) return false;
    final stripped = title.replaceAll(RegExp(r'…$'), '');
    return stripped.isNotEmpty && !message.startsWith(stripped);
  }

  String _formatClock(DateTime date) {
    return DateFormat.jm(context.appLocale.toString()).format(date);
  }

  String _formatListTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return _formatClock(date);
    if (day == today.subtract(const Duration(days: 1))) {
      return context.tr('Yesterday');
    }
    if (now.difference(date).inDays < 7) {
      return DateFormat.E(context.appLocale.toString()).format(date);
    }
    return DateFormat.MMMd(context.appLocale.toString()).format(date);
  }

  String _formatDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return context.tr('Today');
    if (day == today.subtract(const Duration(days: 1))) {
      return context.tr('Yesterday');
    }
    return DateFormat('EEEE, MMM d, yyyy', context.appLocale.toString())
        .format(date);
  }

  String _channelSubtitle(_ChatChannel channel) {
    if (channel.isEveryone) return context.tr('Church-wide messages');
    if (channel.isDirect) return context.tr('Messages sent to specific members');
    return context.tr('Department chat');
  }

  Future<void> _selectChannel(_ChatChannel channel) async {
    setState(() => _selectedChannelId = channel.id);
    if (channel.isDirect && _allMembers.isEmpty) {
      try {
        final members = await MemberService.getMembers(limit: 1000);
        if (mounted) setState(() => _allMembers = members);
      } catch (_) {}
    }
  }

  Future<void> _sendMessage() async {
    final channel = _selectedChannel;
    final text = _composerController.text.trim();
    if (channel == null || text.isEmpty || _isSending) return;

    if (channel.isDirect && _directRecipientIds.isEmpty) {
      final picked = await _pickDirectRecipients();
      if (picked == null || picked.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Select recipients'))),
          );
        }
        return;
      }
      setState(() => _directRecipientIds = picked);
    }

    setState(() => _isSending = true);
    _composerController.clear();

    try {
      await ChatService.createAnnouncement(
        title: ChatService.titleFromMessage(text),
        message: text,
        isGlobal: channel.isEveryone,
        departmentId: channel.departmentId,
        targetMemberIds: channel.isDirect ? _directRecipientIds : null,
      );
      await _loadAnnouncements(silent: true);
    } catch (e) {
      if (!mounted) return;
      _composerController.text = text;
      _composerController.selection = TextSelection.collapsed(offset: text.length);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error creating announcement: $e')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openVideoCall({
    required String roomName,
    required String roomTitle,
    required String displayName,
  }) async {
    if (widget.hideAppBarAndBottomNav) {
      setState(() {
        _embeddedVideoCall = _EmbeddedVideoCall(
          roomName: roomName,
          roomTitle: roomTitle,
          displayName: displayName,
        );
      });
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChatVideoCallPage(
          roomName: roomName,
          roomTitle: roomTitle,
          displayName: displayName,
        ),
      ),
    );
  }

  Future<void> _openAdvancedCompose() async {
    if (widget.hideAppBarAndBottomNav) {
      setState(() => _showAddAnnouncement = true);
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddAnnouncementPage()),
    );
    if (result == true) _loadAnnouncements(silent: true);
  }

  Future<void> _editMessage(Map<String, dynamic> announcement) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditAnnouncementPage(
          announcementId: announcement['id'].toString(),
        ),
      ),
    );
    if (result == true) _loadAnnouncements(silent: true);
  }

  Future<void> _deleteMessage(Map<String, dynamic> announcement) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete')),
        content: Text(
          context.tr('Are you sure you want to delete this announcement?'),
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
    if (confirm != true) return;

    try {
      await ChatService.deleteAnnouncement(announcement['id'].toString());
      await _loadAnnouncements(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error deleting announcement: $e')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showMessageActions(Map<String, dynamic> announcement) async {
    if (!_isMine(announcement) || !_canCreateAnnouncement) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.tr('Edit')),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(announcement);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(context.tr('Delete')),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(announcement);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<String>?> _pickDirectRecipients() async {
    if (_allMembers.isEmpty) {
      try {
        _allMembers = await MemberService.getMembers(limit: 1000);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Error loading data: $e'))),
          );
        }
        return null;
      }
    }

    if (!mounted) return null;
    return showDialog<List<String>>(
      context: context,
      builder: (context) => _MemberPickerDialog(
        allMembers: _allMembers,
        selectedMemberIds: _directRecipientIds.toSet(),
      ),
    );
  }

  String _memberName(String memberId) {
    final member = _allMembers.firstWhere(
      (item) => item['id'].toString() == memberId,
      orElse: () => <String, dynamic>{},
    );
    if (member.isEmpty) return context.tr('Member');
    return '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final wide = _isWideLayout;
    final showingThread = _selectedChannelId != null;
    final showList = wide || !showingThread;
    final showingOverlay =
        widget.hideAppBarAndBottomNav &&
        (_showAddAnnouncement || _embeddedVideoCall != null);

    return PopScope(
      canPop: (wide || !showingThread) && !showingOverlay,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_showAddAnnouncement) {
          setState(() => _showAddAnnouncement = false);
          return;
        }
        if (_embeddedVideoCall != null) {
          setState(() => _embeddedVideoCall = null);
          return;
        }
        if (!wide && showingThread) {
          setState(() => _selectedChannelId = null);
        }
      },
      child: Scaffold(
        backgroundColor: context.mic.background,
        appBar: widget.hideAppBarAndBottomNav
            ? null
            : AppBar(
                leading: !wide && showingThread
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () =>
                            setState(() => _selectedChannelId = null),
                      )
                    : null,
                title: Text(
                  !wide && showingThread
                      ? (_selectedChannel?.name ?? context.tr('Chat'))
                      : context.tr('Chat'),
                ),
                actions: [
                  if (showingThread)
                    IconButton(
                      icon: Icon(
                        _liveVideoCall != null
                            ? Icons.videocam
                            : Icons.videocam_outlined,
                      ),
                      onPressed: _startOrJoinVideoCall,
                      tooltip: _liveVideoCall != null
                          ? context.tr('Join video call')
                          : context.tr('Start video call'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadAnnouncements,
                    tooltip: context.tr('Refresh'),
                  ),
                  if (_canCreateAnnouncement)
                    IconButton(
                      icon: const Icon(Icons.campaign_outlined),
                      onPressed: _openAdvancedCompose,
                      tooltip: context.tr('Create Announcement'),
                    ),
                ],
              ),
        body: Stack(
          children: [
            Positioned.fill(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : wide
                      ? Padding(
                          padding: EdgeInsets.all(AppDimensions.paddingMD),
                          child: Material(
                            color: context.mic.surface,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDimensions.radiusXL),
                              side: BorderSide(
                                color: context.mic.border.withValues(alpha: 0.8),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 320,
                                  child: _buildConversationPane(),
                                ),
                                VerticalDivider(
                                  width: 1,
                                  color: context.mic.border,
                                ),
                                Expanded(
                                  child: _buildThreadPane(showBack: false),
                                ),
                              ],
                            ),
                          ),
                        )
                      : showList
                          ? _buildConversationPane()
                          : _buildThreadPane(
                              showBack: widget.hideAppBarAndBottomNav,
                            ),
            ),
            if (widget.hideAppBarAndBottomNav && _showAddAnnouncement)
              Positioned.fill(
                child: Material(
                  elevation: 8,
                  child: AddAnnouncementPage(
                    onClose: (result) {
                      setState(() => _showAddAnnouncement = false);
                      if (result == true) {
                        _loadAnnouncements(silent: true);
                      }
                    },
                  ),
                ),
              ),
            if (widget.hideAppBarAndBottomNav && _embeddedVideoCall != null)
              Positioned.fill(
                child: Material(
                  elevation: 8,
                  child: ChatVideoCallPage(
                    roomName: _embeddedVideoCall!.roomName,
                    roomTitle: _embeddedVideoCall!.roomTitle,
                    displayName: _embeddedVideoCall!.displayName,
                    onClose: () => setState(() => _embeddedVideoCall = null),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationPane() {
    final channels = _visibleChannels;
    final searching = _searchController.text.trim().isNotEmpty;

    return ColoredBox(
      color: context.mic.surface,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.paddingMD,
              AppDimensions.paddingMD,
              AppDimensions.paddingMD,
              AppDimensions.spacingSM,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.tr('Search conversations...'),
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: context.mic.background,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(_searchController.clear);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  borderSide: BorderSide(color: context.mic.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  borderSide: BorderSide(color: context.mic.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: channels.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppDimensions.paddingLG),
                      child: Text(
                        searching
                            ? context.tr('No conversations found')
                            : context.tr('No messages yet'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: context.mic.textSecondary,
                            ),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAnnouncements,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: channels.length,
                      itemBuilder: (context, index) {
                        final channel = channels[index];
                        final selected =
                            _isWideLayout && channel.id == _selectedChannelId;
                        return _ConversationTile(
                          channel: channel,
                          selected: selected,
                          timeLabel: channel.lastAt == null
                              ? null
                              : _formatListTime(channel.lastAt!),
                          preview: channel.lastPreview ??
                              context.tr('No messages yet'),
                          onTap: () => _selectChannel(channel),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadPane({required bool showBack}) {
    final channel = _selectedChannel;
    if (channel == null) {
      return _buildEmptyThreadPlaceholder();
    }

    final messages = _threadMessages;

    return ColoredBox(
      color: context.mic.background,
      child: Column(
        children: [
          if (showBack || _isWideLayout)
            _ThreadHeader(
              channel: channel,
              subtitle: _channelSubtitle(channel),
              showBack: showBack,
              onBack: () => setState(() => _selectedChannelId = null),
              onRefresh: _loadAnnouncements,
              onCompose: _canCreateAnnouncement ? _openAdvancedCompose : null,
              onVideoCall: _startOrJoinVideoCall,
              videoLive: _liveVideoCall != null,
            ),
            if (_liveVideoCall != null)
              _VideoCallBanner(onJoin: _startOrJoinVideoCall),
          Expanded(
            child: messages.isEmpty
                ? _EmptyThread(
                    channelName: channel.name,
                    canCompose: _canCreateAnnouncement,
                  )
                : ListView.builder(
                    reverse: true,
                    padding: EdgeInsets.fromLTRB(
                      AppDimensions.paddingMD,
                      AppDimensions.spacingSM,
                      AppDimensions.paddingMD,
                      AppDimensions.spacingSM,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final announcement = messages[index];
                      final date = _parseDate(announcement['created_at']);
                      final next = index + 1 < messages.length
                          ? messages[index + 1]
                          : null;
                      final nextDate = next == null
                          ? null
                          : _parseDate(next['created_at']);
                      final showDayChip = date != null &&
                          (nextDate == null ||
                              date.year != nextDate.year ||
                              date.month != nextDate.month ||
                              date.day != nextDate.day);
                      final groupedWithOlder = next != null &&
                          next['created_by']?.toString() ==
                              announcement['created_by']?.toString() &&
                          date != null &&
                          nextDate != null &&
                          date.difference(nextDate).inMinutes.abs() < 8;

                      return Column(
                        children: [
                          if (showDayChip)
                            _DayChip(label: _formatDayLabel(date)),
                          _MessageBubble(
                            announcement: announcement,
                            mine: _isMine(announcement),
                            senderName: _senderName(announcement),
                            showTitle: _shouldShowTitle(announcement),
                            timeLabel:
                                date == null ? '' : _formatClock(date),
                            showSender: !groupedWithOlder,
                            onLongPress: () =>
                                _showMessageActions(announcement),
                            onJoinVideo: ChatVideoService.isVideoCall(
                              announcement,
                            )
                                ? _startOrJoinVideoCall
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (_canCreateAnnouncement) _buildComposer(channel),
        ],
      ),
    );
  }

  Widget _buildEmptyThreadPlaceholder() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: context.mic.textSecondary,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              context.tr('Select a conversation'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: AppDimensions.spacingSM),
            Text(
              context.tr('Choose a conversation to start messaging'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.mic.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(_ChatChannel channel) {
    return Material(
      color: context.mic.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: context.mic.border),
            if (channel.isDirect)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.paddingMD,
                  AppDimensions.spacingSM,
                  AppDimensions.paddingMD,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: AppDimensions.spacingXS,
                    runSpacing: AppDimensions.spacingXS,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.people_outline, size: 16),
                        label: Text(
                          _directRecipientIds.isEmpty
                              ? context.tr('Select recipients')
                              : context.tr(
                                  '${_directRecipientIds.length} selected',
                                ),
                        ),
                        onPressed: () async {
                          final picked = await _pickDirectRecipients();
                          if (picked != null) {
                            setState(() => _directRecipientIds = picked);
                          }
                        },
                      ),
                      ..._directRecipientIds.take(4).map((id) {
                        return Chip(
                          label: Text(_memberName(id)),
                          visualDensity: VisualDensity.compact,
                          onDeleted: () {
                            setState(() => _directRecipientIds.remove(id));
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.paddingSM,
                AppDimensions.spacingSM,
                AppDimensions.paddingSM,
                AppDimensions.spacingSM,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composerController,
                      focusNode: _composerFocus,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: context.tr('Type a message...'),
                        filled: true,
                        fillColor: context.mic.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.mic.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                          borderSide: BorderSide(color: context.mic.border),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingSM),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: IconButton.filled(
                      onPressed: _composerController.text.trim().isEmpty ||
                              _isSending
                          ? null
                          : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      tooltip: context.tr('Send'),
                    ),
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.channel,
    required this.selected,
    required this.preview,
    required this.onTap,
    this.timeLabel,
  });

  final _ChatChannel channel;
  final bool selected;
  final String preview;
  final String? timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMD,
            vertical: 10,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                child: Icon(channel.icon, color: AppColors.primary, size: 22),
              ),
              SizedBox(width: AppDimensions.spacingSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            channel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (timeLabel != null)
                          Text(
                            timeLabel!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: context.mic.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.channel,
    required this.subtitle,
    required this.showBack,
    required this.onBack,
    required this.onRefresh,
    this.onCompose,
    this.onVideoCall,
    this.videoLive = false,
  });

  final _ChatChannel channel;
  final String subtitle;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback? onCompose;
  final VoidCallback? onVideoCall;
  final bool videoLive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.mic.surface,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingSM,
          vertical: AppDimensions.spacingSM,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.mic.border)),
        ),
        child: Row(
          children: [
            if (showBack)
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
                tooltip: context.tr('Back'),
              ),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.14),
              child: Icon(channel.icon, color: AppColors.primary, size: 18),
            ),
            SizedBox(width: AppDimensions.spacingSM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
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
            if (onVideoCall != null)
              IconButton(
                icon: Icon(
                  videoLive ? Icons.videocam : Icons.videocam_outlined,
                  color: videoLive ? AppColors.primary : null,
                ),
                onPressed: onVideoCall,
                tooltip: videoLive
                    ? context.tr('Join video call')
                    : context.tr('Start video call'),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
              tooltip: context.tr('Refresh'),
            ),
            if (onCompose != null)
              IconButton(
                icon: const Icon(Icons.campaign_outlined),
                onPressed: onCompose,
                tooltip: context.tr('Create Announcement'),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoCallBanner extends StatelessWidget {
  const _VideoCallBanner({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onJoin,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMD,
            vertical: AppDimensions.spacingSM,
          ),
          child: Row(
            children: [
              Icon(Icons.videocam, color: AppColors.primary),
              SizedBox(width: AppDimensions.spacingSM),
              Expanded(
                child: Text(
                  context.tr('Video call in progress'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              FilledButton(
                onPressed: onJoin,
                child: Text(context.tr('Join video call')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread({
    required this.channelName,
    required this.canCompose,
  });

  final String channelName;
  final bool canCompose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 56,
              color: context.mic.textSecondary,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              context.tr('No messages yet'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            SizedBox(height: AppDimensions.spacingXS),
            Text(
              canCompose
                  ? context.tr('Send the first message')
                  : channelName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.mic.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingSM),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.mic.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
            border: Border.all(color: context.mic.border),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.mic.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.announcement,
    required this.mine,
    required this.senderName,
    required this.showTitle,
    required this.timeLabel,
    required this.showSender,
    required this.onLongPress,
    this.onJoinVideo,
  });

  final Map<String, dynamic> announcement;
  final bool mine;
  final String senderName;
  final bool showTitle;
  final String timeLabel;
  final bool showSender;
  final VoidCallback onLongPress;
  final VoidCallback? onJoinVideo;

  String get _initials {
    final parts = senderName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = mine
        ? (isDark ? AppColors.primaryDarkMode : AppColors.primary)
        : context.mic.surface;
    final textColor = mine ? Colors.white : context.mic.textPrimary;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: showSender ? AppDimensions.spacingSM : 2,
        bottom: 2,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bubbleMax = math.min(540.0, constraints.maxWidth * 0.84);
          return Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bubbleMax),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!mine) ...[
                    if (showSender)
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.sage.withValues(alpha: 0.25),
                        child: Text(
                          _initials,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 28),
                    SizedBox(width: AppDimensions.spacingSM),
                  ],
                  Flexible(
                    child: GestureDetector(
                      onLongPress: onLongPress,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: radius,
                          border: mine
                              ? null
                              : Border.all(
                                  color:
                                      context.mic.border.withValues(alpha: 0.8),
                                ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!mine && showSender)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  senderName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                ),
                              ),
                            if (showTitle)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  announcement['title']?.toString() ?? '',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            Text(
                              announcement['message']?.toString() ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: textColor,
                                    height: 1.35,
                                  ),
                            ),
                            if (onJoinVideo != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: FilledButton.tonalIcon(
                                  onPressed: onJoinVideo,
                                  icon: const Icon(Icons.videocam, size: 18),
                                  label: Text(context.tr('Join video call')),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: mine
                                        ? Colors.white
                                        : AppColors.primary,
                                    backgroundColor: mine
                                        ? Colors.white.withValues(alpha: 0.18)
                                        : AppColors.primary.withValues(
                                            alpha: 0.12,
                                          ),
                                  ),
                                ),
                              ),
                            if (timeLabel.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    timeLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: mine
                                              ? Colors.white
                                                  .withValues(alpha: 0.8)
                                              : context.mic.textSecondary,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MemberPickerDialog extends StatefulWidget {
  const _MemberPickerDialog({
    required this.allMembers,
    required this.selectedMemberIds,
  });

  final List<Map<String, dynamic>> allMembers;
  final Set<String> selectedMemberIds;

  @override
  State<_MemberPickerDialog> createState() => _MemberPickerDialogState();
}

class _MemberPickerDialogState extends State<_MemberPickerDialog> {
  final _searchController = TextEditingController();
  late Set<String> _selectedMemberIds;

  @override
  void initState() {
    super.initState();
    _selectedMemberIds = Set.from(widget.selectedMemberIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredMembers {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return widget.allMembers;
    return widget.allMembers.where((member) {
      return (member['first_name']?.toString().toLowerCase().contains(query) ??
              false) ||
          (member['last_name']?.toString().toLowerCase().contains(query) ??
              false) ||
          (member['email']?.toString().toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.tr('Search members...'),
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredMembers.length,
                itemBuilder: (context, index) {
                  final member = _filteredMembers[index];
                  final memberId = member['id'].toString();
                  final selected = _selectedMemberIds.contains(memberId);
                  return CheckboxListTile(
                    title: Text(
                      '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'
                          .trim(),
                    ),
                    subtitle: Text(member['email']?.toString() ?? ''),
                    value: selected,
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
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                children: [
                  Text(context.tr('${_selectedMemberIds.length} selected')),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('Cancel')),
                  ),
                  SizedBox(width: AppDimensions.spacingSM),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, _selectedMemberIds.toList()),
                    child: Text(context.tr('Select')),
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