import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Nouveaux venus.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// L'agrégation des rapports migre côté serveur : `/reports/newcomers` croise
/// les arrivées avec la présence effective et signale ceux qui décrochent.
/// L'ancienne version chargeait l'historique complet pour le recouper en
/// mémoire — praticable sur cent membres, plus au-delà.
class NewComerService {
  static ApiClient get _client => AuthService.client;

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// La semaine commence le lundi — convention locale.
  static ({DateTime start, DateTime end}) _weekBounds(DateTime reference) {
    final start = reference.subtract(Duration(days: reference.weekday - 1));
    return (start: start, end: start.add(const Duration(days: 6)));
  }

  static ({DateTime start, DateTime end}) _monthBounds(DateTime reference) {
    return (
      start: DateTime(reference.year, reference.month, 1),
      // Le jour 0 du mois suivant est le dernier du mois courant.
      end: DateTime(reference.year, reference.month + 1, 0),
    );
  }

  // ---------------------------------------------------------------------------
  // Enregistrements
  // ---------------------------------------------------------------------------

  /// Crée une fiche de nouveau venu.
  ///
  /// Une intention `just_passing` est refusée côté membre : ces personnes
  /// relèvent des visiteurs, et les compter comme membres fausserait les
  /// effectifs.
  static Future<Map<String, dynamic>> createNewComerRecord({
    String? memberId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    required DateTime newcomerJoinDate,
    String? newcomerIntention,
  }) async {
    final data = await _client.post('/members', body: {
      'first_name': firstName,
      'last_name': lastName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'is_new_comer': true,
      'newcomer_join_date': _day(newcomerJoinDate),
      if (newcomerIntention != null) 'newcomer_intention': newcomerIntention,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Liste des nouveaux venus.
  ///
  /// [currentStatus] filtre sur l'état actuel : `new_comer` pour ceux qui le
  /// sont encore, `member` pour ceux qui ont gradué.
  static Future<List<Map<String, dynamic>>> getNewComerRecords({
    DateTime? startDate,
    DateTime? endDate,
    String? currentStatus,
    int? limit,
    int? offset,
  }) {
    final effectiveLimit = limit ?? 200;
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList('/members', query: {
      'page': page,
      'limit': effectiveLimit,
      // `member` signifie « a gradué » : la personne n'est plus nouvelle venue.
      'is_new_comer': currentStatus != 'member',
      if (startDate != null) 'from': _day(startDate),
      if (endDate != null) 'to': _day(endDate),
    });
  }

  /// Crée la fiche si le membre n'en a pas déjà une.
  ///
  /// Le serveur crée automatiquement l'enregistrement à la création d'un
  /// membre marqué nouveau venu. Cette méthode reste pour les cas où le
  /// drapeau serait activé après coup.
  static Future<Map<String, dynamic>?> ensureRecordExistsForMember({
    required Map<String, dynamic> member,
  }) async {
    final memberId = member['id'] as String?;
    if (memberId == null) return null;

    if (member['is_new_comer'] == true) return member;

    final data = await _client.patch('/members/$memberId', body: {
      'is_new_comer': true,
      'newcomer_join_date': _day(DateTime.now()),
    });
    return (data as Map).cast<String, dynamic>();
  }

  // ---------------------------------------------------------------------------
  // Rapports
  // ---------------------------------------------------------------------------

  /// Rapport sur une période libre.
  ///
  /// Le drapeau `at_risk` de chaque ligne signale ceux qui décrochent : aucune
  /// présence, ou dernière présence remontant à plus de trente jours. C'est
  /// l'information utile — compter les arrivées n'apprend rien qu'on ne sache
  /// déjà.
  static Future<Map<String, dynamic>> getReport({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) =>
      _client.getOne('/reports/newcomers', query: {
        if (startDate != null) 'from': _day(startDate),
        if (endDate != null) 'to': _day(endDate),
      });

  static Future<Map<String, dynamic>> getWeeklyReport({
    DateTime? referenceDate,
  }) {
    final bounds = _weekBounds(referenceDate ?? DateTime.now());
    return getReport(startDate: bounds.start, endDate: bounds.end);
  }

  static Future<Map<String, dynamic>> getMonthlyReport({
    DateTime? referenceDate,
  }) {
    final bounds = _monthBounds(referenceDate ?? DateTime.now());
    return getReport(startDate: bounds.start, endDate: bounds.end);
  }

  static Future<Map<String, dynamic>> getYearlyReport({int? year}) {
    final y = year ?? DateTime.now().year;
    return getReport(
      startDate: DateTime(y, 1, 1),
      endDate: DateTime(y, 12, 31),
    );
  }
}