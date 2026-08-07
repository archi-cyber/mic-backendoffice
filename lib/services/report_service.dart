import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Rapports et agrégations.
///
/// Signatures identiques à l'implémentation Supabase : paramètres nommés,
/// dates en `DateTime`.
///
/// Le calcul migre entièrement côté serveur. L'ancienne version chargeait
/// l'historique complet pour l'agréger en mémoire ; les agrégations sont
/// désormais faites en SQL, ce qui change l'échelle du praticable — un rapport
/// annuel sur trois cents membres ne tenait plus dans la mémoire d'un
/// téléphone.
class ReportService {
  static ApiClient get _client => AuthService.client;

  // ---------------------------------------------------------------------------
  // Bornes de période
  // ---------------------------------------------------------------------------

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// La semaine commence le lundi — convention locale.
  static ({String from, String to}) _weekBounds(DateTime reference) {
    final start = reference.subtract(Duration(days: reference.weekday - 1));
    return (from: _day(start), to: _day(start.add(const Duration(days: 6))));
  }

  static ({String from, String to}) _monthBounds(DateTime reference) {
    final start = DateTime(reference.year, reference.month, 1);
    // Le jour 0 du mois suivant est le dernier du mois courant : évite de
    // gérer 28, 29, 30 et 31 à la main.
    final end = DateTime(reference.year, reference.month + 1, 0);
    return (from: _day(start), to: _day(end));
  }

  static ({String from, String to}) _yearBounds(int year) =>
      (from: '$year-01-01', to: '$year-12-31');

  // ---------------------------------------------------------------------------
  // Tableau de bord
  // ---------------------------------------------------------------------------

  /// Vue d'ensemble de l'écran d'accueil.
  ///
  /// Effectifs, tâches ouvertes, prochains événements et séances,
  /// anniversaires du mois. Accessible sans permission particulière.
  static Future<Map<String, dynamic>> getDashboard() =>
      _client.getOne('/reports/dashboard');

  // ---------------------------------------------------------------------------
  // Présence
  // ---------------------------------------------------------------------------

  /// Rapport de présence par membre.
  ///
  /// Le taux rapporte les présences au nombre de cultes **tenus** sur la
  /// période, non au nombre de fois où la personne a été pointée. Un membre
  /// jamais pointé apparaît donc à 0 % : pour le suivi pastoral, l'oubli de
  /// pointage et l'absence appellent le même geste.
  ///
  /// Chaque membre reçoit une qualification `diligence` : `diligent`,
  /// `moderate` ou `low`.
  static Future<Map<String, dynamic>> getAttendanceReport({
    DateTime? fromDate,
    DateTime? toDate,
    int diligentThreshold = 75,
    int moderateThreshold = 50,
    String? departmentId,
  }) =>
      _client.getOne('/reports/attendance', query: {
        if (fromDate != null) 'from': _day(fromDate),
        if (toDate != null) 'to': _day(toDate),
        'diligentThreshold': diligentThreshold,
        'moderateThreshold': moderateThreshold,
        if (departmentId != null) 'departmentId': departmentId,
      });

  /// Fréquentation culte par culte, en ordre chronologique.
  ///
  /// Format directement exploitable pour un graphique d'évolution. Inclut le
  /// décompte des visiteurs.
  static Future<List<Map<String, dynamic>>> getAttendanceTrend({
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _client.getList('/reports/attendance/trend', query: {
        if (fromDate != null) 'from': _day(fromDate),
        if (toDate != null) 'to': _day(toDate),
      });

  // ---------------------------------------------------------------------------
  // Membres
  // ---------------------------------------------------------------------------

  /// Bilan complet d'un membre : présence, dons, tâches, pénalités, formations.
  ///
  /// Les dons sont réduits à un total, sans détail par mouvement : ce rapport
  /// est consulté par des responsables de département, qui n'ont pas à
  /// connaître le détail des offrandes.
  static Future<Map<String, dynamic>> getMemberReport({
    required String memberId,
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _client.getOne('/reports/member/$memberId', query: {
        if (fromDate != null) 'from': _day(fromDate),
        if (toDate != null) 'to': _day(toDate),
      });

  /// Présence d'un membre aux cultes.
  static Future<Map<String, dynamic>> getMemberChurchAttendanceReport({
    required String memberId,
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      getMemberReport(memberId: memberId, fromDate: fromDate, toDate: toDate);

  /// Mon propre bilan — accessible sans permission.
  static Future<Map<String, dynamic>> getMyReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _client.getOne('/reports/me', query: {
        if (fromDate != null) 'from': _day(fromDate),
        if (toDate != null) 'to': _day(toDate),
      });

  /// Rapport de présence des membres — période libre.
  static Future<Map<String, dynamic>> getMembersReport({
    DateTime? fromDate,
    DateTime? toDate,
    String? departmentId,
  }) =>
      getAttendanceReport(
        fromDate: fromDate,
        toDate: toDate,
        departmentId: departmentId,
      );

  static Future<Map<String, dynamic>> getWeeklyMembersReport({
    DateTime? referenceDate,
  }) {
    final bounds = _weekBounds(referenceDate ?? DateTime.now());
    return _client.getOne('/reports/attendance', query: {
      'from': bounds.from,
      'to': bounds.to,
    });
  }

  static Future<Map<String, dynamic>> getMonthlyMembersReport({
    DateTime? referenceDate,
  }) {
    final bounds = _monthBounds(referenceDate ?? DateTime.now());
    return _client.getOne('/reports/attendance', query: {
      'from': bounds.from,
      'to': bounds.to,
    });
  }

  static Future<Map<String, dynamic>> getYearlyMembersReport({int? year}) {
    final bounds = _yearBounds(year ?? DateTime.now().year);
    return _client.getOne('/reports/attendance', query: {
      'from': bounds.from,
      'to': bounds.to,
    });
  }

  // ---------------------------------------------------------------------------
  // Nouveaux venus
  // ---------------------------------------------------------------------------

  /// Suivi des nouveaux venus.
  ///
  /// Le drapeau `at_risk` signale ceux qui décrochent : aucune présence, ou
  /// dernière présence remontant à plus de trente jours. C'est l'information
  /// utile — compter les arrivées n'apprend rien qu'on ne sache déjà.
  static Future<Map<String, dynamic>> getNewComerReport({
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int? offset,
    int windowDays = 90,
  }) =>
      _client.getOne('/reports/newcomers', query: {
        if (fromDate != null) 'from': _day(fromDate),
        if (toDate != null) 'to': _day(toDate),
        'windowDays': windowDays,
      });

  static Future<Map<String, dynamic>> getWeeklyNewComerReport({
    DateTime? referenceDate,
  }) {
    final bounds = _weekBounds(referenceDate ?? DateTime.now());
    return _client.getOne('/reports/newcomers', query: {
      'from': bounds.from,
      'to': bounds.to,
    });
  }

  static Future<Map<String, dynamic>> getMonthlyNewComerReport({
    DateTime? referenceDate,
  }) {
    final bounds = _monthBounds(referenceDate ?? DateTime.now());
    return _client.getOne('/reports/newcomers', query: {
      'from': bounds.from,
      'to': bounds.to,
    });
  }

  static Future<Map<String, dynamic>> getYearlyNewComerReport({int? year}) {
    final bounds = _yearBounds(year ?? DateTime.now().year);
    return _client.getOne('/reports/newcomers', query: {
      'from': bounds.from,
      'to': bounds.to,
    });
  }

  // ---------------------------------------------------------------------------
  // Départements et formations
  // ---------------------------------------------------------------------------

  /// Bilan d'activité d'un département.
  static Future<Map<String, dynamic>> getDepartmentReport({
    required String departmentId,
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _client.getOne('/reports/department/$departmentId', query: {
        if (fromDate != null) 'from': _day(fromDate),
        if (toDate != null) 'to': _day(toDate),
      });

  /// Assiduité d'une formation, par inscrit.
  static Future<Map<String, dynamic>> getClassReport({
    required String classId,
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _client.getOne('/classes/$classId/report');
}