import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'member_service.dart';
import 'report_service.dart';

/// Rapport sur les membres.
///
/// Signatures et **forme de sortie identiques** à l'implémentation Supabase :
/// les services PDF qui consomment ce rapport n'ont rien à changer.
///
/// L'agrégation de présence migre côté serveur. L'ancienne version chargeait
/// toutes les lignes de `church_attendance` de la période — plusieurs milliers
/// sur une année — pour les compter en mémoire. La route `/reports/attendance`
/// fait ce calcul en SQL et ne renvoie que le résultat.
///
/// Les décomptes par statut et par rôle restent calculés localement : ils
/// portent sur la liste des membres, déjà chargée pour le rapport, et ne
/// justifient pas un appel supplémentaire.
class MembersReportService {
  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// La semaine commence le lundi — convention locale.
  static Future<Map<String, dynamic>> getWeeklyReport({
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final start = ref.subtract(Duration(days: ref.weekday - 1));

    return getReport(
      startDate: start,
      endDate: start.add(const Duration(days: 6)),
    );
  }

  static Future<Map<String, dynamic>> getMonthlyReport({
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();

    return getReport(
      startDate: DateTime(ref.year, ref.month, 1),
      // Le jour 0 du mois suivant est le dernier du mois courant.
      endDate: DateTime(ref.year, ref.month + 1, 0),
    );
  }

  static Future<Map<String, dynamic>> getYearlyReport({int? year}) {
    final y = year ?? DateTime.now().year;
    return getReport(
      startDate: DateTime(y, 1, 1),
      endDate: DateTime(y, 12, 31),
    );
  }

  static Future<Map<String, dynamic>> getReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final members = await _fetchMembers();

    return {
      'period': {
        'start': startDate != null ? _day(startDate) : null,
        'end': endDate != null ? _day(endDate) : null,
      },
      'total': members.length,
      'status_summary': _buildStatusSummary(members),
      'role_summary': _buildRoleSummary(members),
      'attendance_report': await _buildAttendanceReport(
        members,
        startDate: startDate,
        endDate: endDate,
      ),
      'records': members,
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // Collecte
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> _fetchMembers() async {
    try {
      // Toutes les pages sont parcourues : le serveur plafonne chaque requête
      // à deux cents lignes, et se contenter de ce plafond tronquerait le
      // rapport dès que l'assemblée dépasse cette taille — sans le signaler.
      return await AuthService.client.getAll('/members', query: {
        'orderBy': 'lastName',
        'order': 'asc',
      });
    } catch (e) {
      debugPrint('[MembersReport] Lecture des membres échouée : $e');
      return MemberService.getMembers();
    }
  }

  static Map<String, int> _buildStatusSummary(
    List<Map<String, dynamic>> members,
  ) {
    var active = 0;
    var inactive = 0;
    var newcomers = 0;

    for (final member in members) {
      if (member['is_active'] == true) {
        active++;
      } else {
        inactive++;
      }
      if (member['is_new_comer'] == true) {
        newcomers++;
      }
    }

    return {'active': active, 'inactive': inactive, 'new_comer': newcomers};
  }

  static Map<String, int> _buildRoleSummary(
    List<Map<String, dynamic>> members,
  ) {
    final summary = <String, int>{
      'member': 0,
      'leader': 0,
      'worker': 0,
      'admin': 0,
      'sympathiser': 0,
    };

    for (final member in members) {
      final role = member['role']?.toString() ?? 'member';
      summary[role] = (summary[role] ?? 0) + 1;
    }

    return summary;
  }

  // ---------------------------------------------------------------------------
  // Présence
  // ---------------------------------------------------------------------------

  /// Construit le bloc de présence à partir du rapport serveur.
  ///
  /// La forme de sortie est conservée à l'identique — `member_rows`, `onsite`,
  /// `online`, `absent`, `unique_services` — pour que les services PDF
  /// continuent de fonctionner sans modification.
  ///
  /// Une différence : `records` est désormais vide. L'ancienne version
  /// renvoyait toutes les lignes de présence brutes, ce qui pouvait
  /// représenter plusieurs milliers d'entrées pour un rapport annuel. Le
  /// serveur ne les transmet plus, et aucun consommateur ne les utilisait —
  /// seuls les décomptes agrégés servaient.
  static Future<Map<String, dynamic>> _buildAttendanceReport(
    List<Map<String, dynamic>> members, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (members.isEmpty) {
      return _emptyAttendanceReport();
    }

    try {
      final report = await ReportService.getAttendanceReport(
        fromDate: startDate,
        toDate: endDate,
      );

      final rows = ((report['members'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      var onsite = 0;
      var online = 0;
      var absent = 0;

      final memberRows = rows.map((row) {
        final rowOnsite = row['onsite'] as int? ?? 0;
        final rowOnline = row['online'] as int? ?? 0;
        final rowAbsent = row['absent'] as int? ?? 0;

        onsite += rowOnsite;
        online += rowOnline;
        absent += rowAbsent;

        return <String, dynamic>{
          'member_id': row['id'],
          'name': '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim(),
          'role': row['role'] ?? 'member',
          'is_active': true,
          'onsite': rowOnsite,
          'online': rowOnline,
          'absent': rowAbsent,
          'attended': row['present'] as int? ?? 0,
          'total': rowOnsite + rowOnline + rowAbsent,
          'attendance_rate': row['attendance_rate'] as int? ?? 0,
          'diligence': row['diligence'],
          'last_attended': null,
        };
      }).toList()
        // Les plus assidus d'abord, puis par ordre alphabétique — même tri que
        // l'implémentation précédente.
        ..sort((a, b) {
          final byAttendance =
              (b['attended'] as int).compareTo(a['attended'] as int);
          if (byAttendance != 0) return byAttendance;
          return (a['name']?.toString() ?? '')
              .compareTo(b['name']?.toString() ?? '');
        });

      return {
        'total_records': onsite + online + absent,
        'onsite': onsite,
        'online': online,
        'absent': absent,
        'attended': onsite + online,
        'unique_services': report['total_services'] as int? ?? 0,
        'member_rows': memberRows,
        'records': const <Map<String, dynamic>>[],
        // Ces trois valeurs n'existaient pas dans l'ancienne version : le
        // serveur qualifie l'assiduité de chaque membre selon des seuils.
        'summary': report['summary'],
        'thresholds': report['thresholds'],
        'services': report['services'],
      };
    } catch (e) {
      debugPrint('[MembersReport] Rapport de présence échoué : $e');
      return {..._emptyAttendanceReport(), 'error': e.toString()};
    }
  }

  static Map<String, dynamic> _emptyAttendanceReport() => {
        'total_records': 0,
        'onsite': 0,
        'online': 0,
        'absent': 0,
        'attended': 0,
        'unique_services': 0,
        'member_rows': <Map<String, dynamic>>[],
        'records': <Map<String, dynamic>>[],
      };
}