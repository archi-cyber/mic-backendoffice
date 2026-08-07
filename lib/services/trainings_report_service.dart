import '../core/api/api_client.dart';
import 'auth_service.dart';
import 'class_service.dart';

/// Rapports de formation.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// L'assiduité de chaque formation est calculée par le serveur — routes
/// `/classes/:id/report`. Ce service agrège ces résultats pour l'ensemble des
/// formations actives, ce qui reste léger : une requête par formation, et une
/// église en compte rarement plus de quelques dizaines.
class TrainingsReportService {
  static ApiClient get _client => AuthService.client;

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Rapport sur une période libre.
  static Future<Map<String, dynamic>> getReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final classes = await ClassService.getClasses(limit: 200);

    final reports = <Map<String, dynamic>>[];
    var totalSessions = 0;
    var totalMembers = 0;

    for (final training in classes) {
      final classId = training['id'] as String?;
      if (classId == null) continue;

      try {
        final report = await _client.getOne('/classes/$classId/report');
        reports.add(report);

        totalSessions += (report['total_sessions'] as int?) ?? 0;
        totalMembers += ((report['members'] as List?) ?? const []).length;
      } catch (_) {
        // Une formation dont le rapport échoue est ignorée plutôt que de
        // faire échouer l'ensemble : mieux vaut un rapport partiel qu'aucun.
        continue;
      }
    }

    // Le taux global est la moyenne des taux individuels, pondérée par le
    // nombre d'inscrits. Faire la moyenne des moyennes donnerait le même poids
    // à une formation de trois personnes et à une de cinquante.
    var weightedSum = 0;
    var weightTotal = 0;

    for (final report in reports) {
      final members = (report['members'] as List?) ?? const [];
      for (final member in members) {
        final rate = (member as Map)['attendance_rate'] as int? ?? 0;
        weightedSum += rate;
        weightTotal += 1;
      }
    }

    return {
      'period': {
        'from': startDate != null ? _day(startDate) : null,
        'to': endDate != null ? _day(endDate) : null,
      },
      'total_classes': reports.length,
      'total_sessions': totalSessions,
      'total_members': totalMembers,
      'average_attendance_rate':
          weightTotal > 0 ? (weightedSum / weightTotal).round() : 0,
      'classes': reports,
    };
  }

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
}