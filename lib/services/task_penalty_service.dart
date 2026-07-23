import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class TaskPenaltyService {
  static final _client = SupabaseService.client;

  static const int fallbackDailyPenaltyAmount = 100;
  static const int fallbackBlockingThreshold = 3500;
  static const int fallbackTeachingTaskDueOffsetDays = 10;
  static const String mediaTeamDepartmentName = 'Media Team';

  static String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parseDateOnly(String value) {
    final parts = value.split('T').first.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await _client
          .from('task_penalty_settings')
          .select()
          .eq('id', 'global')
          .maybeSingle();

      return {
        'default_daily_penalty_amount': fallbackDailyPenaltyAmount,
        'blocking_threshold_amount': fallbackBlockingThreshold,
        'teaching_task_due_offset_days': fallbackTeachingTaskDueOffsetDays,
        if (response != null) ...response,
      };
    } catch (e) {
      debugPrint('[TaskPenaltyService] Could not load settings: $e');
      return {
        'default_daily_penalty_amount': fallbackDailyPenaltyAmount,
        'blocking_threshold_amount': fallbackBlockingThreshold,
        'teaching_task_due_offset_days': fallbackTeachingTaskDueOffsetDays,
      };
    }
  }

  static Future<int> getBlockingThreshold() async {
    final settings = await getSettings();
    return _asInt(
      settings['blocking_threshold_amount'],
      fallbackBlockingThreshold,
    );
  }

  static Future<int> getTeachingTaskDueOffsetDays() async {
    final settings = await getSettings();
    return _asInt(
      settings['teaching_task_due_offset_days'],
      fallbackTeachingTaskDueOffsetDays,
    );
  }

  static Future<Map<String, dynamic>?> getMediaTeamDepartment() async {
    try {
      return await _client
          .from('departments')
          .select('id, name, task_penalty_amount')
          .ilike('name', mediaTeamDepartmentName)
          .limit(1)
          .maybeSingle();
    } catch (e) {
      debugPrint('[TaskPenaltyService] Could not load Media Team: $e');
      return null;
    }
  }

  static int taskPenaltyAmountFromSettings(
    Map<String, dynamic> task,
    Map<String, dynamic> settings,
  ) {
    final fallback = _asInt(
      settings['default_daily_penalty_amount'],
      fallbackDailyPenaltyAmount,
    );

    final taskAmount = task['penalty_amount_per_day'];
    if (taskAmount != null) return _asInt(taskAmount, fallback);

    final department = task['departments'];
    if (department is Map && department['task_penalty_amount'] != null) {
      return _asInt(department['task_penalty_amount'], fallback);
    }

    return fallback;
  }

  static Future<int> getTaskPenaltyAmount(Map<String, dynamic> task) async {
    final settings = await getSettings();
    return taskPenaltyAmountFromSettings(task, settings);
  }

  static Future<void> calculatePenaltiesOnStartup() async {
    try {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final settings = await getSettings();
      final defaultAmount = _asInt(
        settings['default_daily_penalty_amount'],
        fallbackDailyPenaltyAmount,
      );

      final response = await _client.from('tasks').select('''
            id,
            title,
            due_date,
            status,
            archived_at,
            penalty_amount_per_day,
            departments(task_penalty_amount),
            task_assignments(member_id, status)
          ''');

      final rowsToInsert = <Map<String, dynamic>>[];

      for (final rawTask in List<Map<String, dynamic>>.from(response)) {
        final dueDateRaw = rawTask['due_date']?.toString();
        if (dueDateRaw == null || dueDateRaw.isEmpty) continue;
        if (rawTask['archived_at'] != null) continue;

        final taskStatus = rawTask['status']?.toString().toLowerCase();
        if (taskStatus == 'completed' || taskStatus == 'cancelled') continue;

        final dueDate = _parseDateOnly(dueDateRaw);
        final firstPenaltyDate = dueDate.add(const Duration(days: 1));
        if (firstPenaltyDate.isAfter(todayDate)) continue;

        final amount = taskPenaltyAmountFromSettings({
          ...rawTask,
          if (rawTask['penalty_amount_per_day'] == null)
            'penalty_amount_per_day': defaultAmount,
        }, settings);
        if (amount <= 0) continue;

        final assignments =
            rawTask['task_assignments'] as List<dynamic>? ?? const [];
        for (final assignmentRaw in assignments) {
          if (assignmentRaw is! Map) continue;
          final memberId = assignmentRaw['member_id']?.toString();
          if (memberId == null || memberId.isEmpty) continue;
          final assignmentStatus = assignmentRaw['status']
              ?.toString()
              .toLowerCase();
          if (assignmentStatus == 'completed' ||
              assignmentStatus == 'cancelled') {
            continue;
          }

          var penaltyDate = firstPenaltyDate;
          while (!penaltyDate.isAfter(todayDate)) {
            rowsToInsert.add({
              'task_id': rawTask['id'].toString(),
              'member_id': memberId,
              'penalty_date': _dateOnly(penaltyDate),
              'amount': amount,
              'created_at': DateTime.now().toIso8601String(),
            });
            penaltyDate = penaltyDate.add(const Duration(days: 1));
          }
        }
      }

      if (rowsToInsert.isEmpty) return;

      await _client
          .from('task_penalties')
          .upsert(rowsToInsert, onConflict: 'task_id,member_id,penalty_date');
      debugPrint(
        '[TaskPenaltyService] Calculated ${rowsToInsert.length} penalty rows',
      );
    } catch (e) {
      debugPrint(
        '[TaskPenaltyService] Penalty calculation skipped: ${_sanitizeLogError(e)}',
      );
    }
  }

  static Future<Map<String, int>> getMemberPenaltyBalances(
    List<String> memberIds,
  ) async {
    if (memberIds.isEmpty) return {};

    try {
      final penalties = await _client
          .from('task_penalties')
          .select('member_id, amount')
          .inFilter('member_id', memberIds);
      final payments = await _client
          .from('task_penalty_payments')
          .select('member_id, amount')
          .inFilter('member_id', memberIds);

      final balances = <String, int>{for (final id in memberIds) id: 0};

      for (final row in List<Map<String, dynamic>>.from(penalties)) {
        final memberId = row['member_id']?.toString();
        if (memberId == null) continue;
        balances[memberId] =
            (balances[memberId] ?? 0) + _asInt(row['amount'], 0);
      }

      for (final row in List<Map<String, dynamic>>.from(payments)) {
        final memberId = row['member_id']?.toString();
        if (memberId == null) continue;
        balances[memberId] =
            (balances[memberId] ?? 0) - _asInt(row['amount'], 0);
      }

      balances.updateAll((_, balance) => balance < 0 ? 0 : balance);
      return balances;
    } catch (e) {
      debugPrint(
        '[TaskPenaltyService] Could not load balances: ${_sanitizeLogError(e)}',
      );
      return {for (final id in memberIds) id: 0};
    }
  }

  static String _sanitizeLogError(Object e) {
    var text = e.toString();
    text = text.replaceAll(RegExp(r'https?://[^\s,)]+'), '[url]');
    text = text.replaceAll(RegExp(r'uri=[^\s,)]+'), 'uri=[url]');
    if (text.length > 160) text = '${text.substring(0, 157)}...';
    return text;
  }

  static Future<int> getMemberPenaltyBalance(String memberId) async {
    final balances = await getMemberPenaltyBalances([memberId]);
    return balances[memberId] ?? 0;
  }

  static Future<bool> canAssignMember(String memberId) async {
    final balance = await getMemberPenaltyBalance(memberId);
    final threshold = await getBlockingThreshold();
    return balance < threshold;
  }

  static Future<List<Map<String, dynamic>>> annotateMembersWithPenalties(
    List<Map<String, dynamic>> members,
  ) async {
    final ids = members
        .map((member) => member['id']?.toString())
        .whereType<String>()
        .toList();
    final balances = await getMemberPenaltyBalances(ids);
    final threshold = await getBlockingThreshold();

    return members.map((member) {
      final memberId = member['id']?.toString();
      final balance = memberId == null ? 0 : (balances[memberId] ?? 0);
      return {
        ...member,
        'penalty_balance': balance,
        'is_assignment_blocked': balance >= threshold,
      };
    }).toList();
  }

  static Future<void> recordPayment({
    required String memberId,
    required int amount,
    String? note,
  }) async {
    if (amount <= 0) {
      throw Exception('Payment amount must be greater than zero');
    }

    await _client.from('task_penalty_payments').insert({
      'member_id': memberId,
      'amount': amount,
      'note': note,
      'recorded_by': SupabaseService.currentUser?.id,
      'paid_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
