import 'package:flutter/foundation.dart' show debugPrint;

import 'supabase_service.dart';

/// Service for tracking newcomer history and generating newcomer reports.
class NewComerService {
  static final _client = SupabaseService.client;

  /// Creates a newcomer history row from explicit data.
  static Future<Map<String, dynamic>> createNewComerRecord({
    String? memberId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required DateTime newcomerJoinDate,
    required String newcomerIntention,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) {
        throw Exception('User must be authenticated to create newcomer record');
      }

      final response = await _client
          .from('new_comers')
          .insert({
            'member_id': memberId,
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'phone': phone,
            'newcomer_join_date':
                newcomerJoinDate.toIso8601String().split('T')[0],
            'newcomer_intention': newcomerIntention,
            'created_by': currentUser.id,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      throw Exception('Failed to create newcomer record: $e');
    }
  }

  /// Creates a newcomer history row when a member is marked as newcomer.
  static Future<Map<String, dynamic>> createNewComerRecordFromMember({
    required Map<String, dynamic> member,
  }) async {
    try {
      final memberId = member['id']?.toString();
      if (memberId == null || memberId.isEmpty) {
        throw Exception('Member id is required to create newcomer record');
      }

      return createNewComerRecord(
        memberId: memberId,
        firstName: member['first_name']?.toString() ?? '',
        lastName: member['last_name']?.toString() ?? '',
        email: member['email']?.toString(),
        phone: member['phone']?.toString(),
        newcomerJoinDate:
            member['newcomer_join_date'] != null
            ? DateTime.parse(member['newcomer_join_date'].toString())
            : DateTime.now(),
        newcomerIntention:
            member['newcomer_intention']?.toString() ?? 'does_not_know_yet',
      );
    } catch (e) {
      throw Exception('Failed to create newcomer record: $e');
    }
  }

  /// Returns newcomer records for any period, with current status resolved.
  static Future<List<Map<String, dynamic>>> getNewComerRecords({
    DateTime? startDate,
    DateTime? endDate,
    String? currentStatus, // new_comer | member | visitor
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic query = _client
          .from('new_comers')
          .select('*')
          .isFilter('deleted_at', null);

      if (startDate != null) {
        query = query.gte(
          'newcomer_join_date',
          startDate.toIso8601String().split('T')[0],
        );
      }
      if (endDate != null) {
        query = query.lte(
          'newcomer_join_date',
          endDate.toIso8601String().split('T')[0],
        );
      }

      query = query.order('newcomer_join_date', ascending: false).order(
        'created_at',
        ascending: false,
      );

      if (limit != null) {
        query = query.limit(limit);
      }
      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 50) - 1);
      }

      final response = await query;
      final records = List<Map<String, dynamic>>.from(response);
      final withStatus = await _attachCurrentStatus(records);

      if (currentStatus == null) {
        return withStatus;
      }
      return withStatus
          .where((r) => r['current_status']?.toString() == currentStatus)
          .toList();
    } catch (e) {
      throw Exception('Failed to get newcomer records: $e');
    }
  }

  static Future<Map<String, dynamic>> getWeeklyReport({DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final start = DateTime(ref.year, ref.month, ref.day).subtract(
      Duration(days: ref.weekday - DateTime.monday),
    );
    final end = start.add(const Duration(days: 6));
    return getReport(startDate: start, endDate: end);
  }

  static Future<Map<String, dynamic>> getMonthlyReport({
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final start = DateTime(ref.year, ref.month, 1);
    final end = DateTime(ref.year, ref.month + 1, 0);
    return getReport(startDate: start, endDate: end);
  }

  static Future<Map<String, dynamic>> getYearlyReport({int? year}) {
    final y = year ?? DateTime.now().year;
    final start = DateTime(y, 1, 1);
    final end = DateTime(y, 12, 31);
    return getReport(startDate: start, endDate: end);
  }

  /// Custom range newcomer report with current status distribution.
  static Future<Map<String, dynamic>> getReport({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    final records = await getNewComerRecords(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      offset: offset,
    );

    final newComers = records
        .where((r) => r['current_status'] == 'new_comer')
        .length;
    final members =
        records.where((r) => r['current_status'] == 'member').length;
    final visitors =
        records.where((r) => r['current_status'] == 'visitor').length;
    final intentionOutcomeSummary = _buildIntentionOutcomeSummary(records);

    return {
      'period': {
        'start': startDate?.toIso8601String().split('T')[0],
        'end': endDate?.toIso8601String().split('T')[0],
      },
      'total': records.length,
      'status_summary': {
        'new_comer': newComers,
        'member': members,
        'visitor': visitors,
      },
      'intention_outcome_summary': intentionOutcomeSummary,
      'records': records,
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, Map<String, int>> _buildIntentionOutcomeSummary(
    List<Map<String, dynamic>> records,
  ) {
    final summary = <String, Map<String, int>>{
      'wants_to_stay': {'member': 0, 'new_comer': 0, 'visitor': 0},
      'does_not_know_yet': {'member': 0, 'new_comer': 0, 'visitor': 0},
      'just_passing': {'member': 0, 'new_comer': 0, 'visitor': 0},
    };

    for (final record in records) {
      final intention = record['newcomer_intention']?.toString();
      final status = record['current_status']?.toString();
      if (intention == null || status == null) continue;
      final intentionMap = summary[intention];
      if (intentionMap == null) continue;
      if (!intentionMap.containsKey(status)) continue;
      intentionMap[status] = (intentionMap[status] ?? 0) + 1;
    }

    return summary;
  }

  static Future<List<Map<String, dynamic>>> _attachCurrentStatus(
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) return records;

    final memberIds = records
        .map((r) => r['member_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final memberStatusById = <String, String>{};
    if (memberIds.isNotEmpty) {
      final memberRows = await _client
          .from('members')
          .select('id, is_new_comer, deleted_at')
          .inFilter('id', memberIds);
      for (final row in List<Map<String, dynamic>>.from(memberRows)) {
        final id = row['id']?.toString();
        if (id == null) continue;
        if (row['deleted_at'] != null) {
          memberStatusById[id] = 'visitor';
        } else if (row['is_new_comer'] == true) {
          memberStatusById[id] = 'new_comer';
        } else {
          memberStatusById[id] = 'member';
        }
      }
    }

    return records.map((record) {
      final memberId = record['member_id']?.toString();
      final status = memberId != null && memberStatusById.containsKey(memberId)
          ? memberStatusById[memberId]!
          : 'visitor';

      return {
        ...record,
        'current_status': status,
      };
    }).toList();
  }

  /// Writes newcomer history when newcomer is enabled on update/create.
  static Future<void> ensureRecordExistsForMember({
    required Map<String, dynamic> member,
  }) async {
    try {
      final memberId = member['id']?.toString();
      final isNewComer = member['is_new_comer'] == true;
      if (memberId == null || memberId.isEmpty || !isNewComer) return;

      final existing = await _client
          .from('new_comers')
          .select('id')
          .eq('member_id', memberId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(1);

      if ((existing as List).isNotEmpty) {
        return;
      }

      await createNewComerRecordFromMember(member: member);
    } catch (e) {
      debugPrint('[NewComerService] ensureRecordExistsForMember failed: $e');
    }
  }
}
