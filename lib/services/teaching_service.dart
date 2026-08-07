import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Enseignements et auditeurs.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// Créer un enseignement déclenche deux automatismes côté serveur : trois
/// tâches de montage pour le département Média, avec une échéance à dix jours,
/// et la synchronisation des auditeurs depuis la présence au culte de la même
/// date. Le client n'a plus à les orchestrer.
class TeachingService {
  static ApiClient get _client => AuthService.client;

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Enseignements
  // ---------------------------------------------------------------------------

  /// Crée un enseignement.
  ///
  /// La réponse contient `tasks_created` et `listeners_added`. Si le
  /// département « Média » n'existe pas, aucune tâche n'est générée et
  /// l'enseignement est enregistré quand même : mieux vaut un enseignement
  /// sans tâches qu'un échec d'enregistrement.
  static Future<Map<String, dynamic>> createTeaching({
    required Map<String, dynamic> teachingData,
  }) async {
    final data = await _client.post('/teachings', body: teachingData);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getTeachings({
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = false,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final effectiveLimit = (limit ?? 200).clamp(1, 200);
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList('/teachings', query: {
      'page': page,
      'limit': effectiveLimit,
      'order': ascending ? 'asc' : 'desc',
      if (orderBy != null) 'orderBy': orderBy,
      if (fromDate != null) 'from': _day(fromDate),
      if (toDate != null) 'to': _day(toDate),
      ...?filters,
    });
  }

  /// Détail d'un enseignement, avec ses auditeurs et ses tâches de montage.
  static Future<Map<String, dynamic>> getTeachingById(String teachingId) =>
      _client.getOne('/teachings/$teachingId');

  /// Modifie un enseignement.
  ///
  /// Changer la date décale l'échéance des tâches de montage associées : les
  /// laisser en arrière ferait courir des pénalités pour un retard inexistant.
  static Future<Map<String, dynamic>> updateTeaching({
    required String teachingId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client.patch('/teachings/$teachingId', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  /// Supprime un enseignement.
  ///
  /// Ses tâches de montage suivent : elles n'ont plus d'objet, et les laisser
  /// vivantes ferait courir des pénalités pour un travail devenu sans raison
  /// d'être.
  static Future<void> deleteTeaching(String teachingId) async {
    await _client.delete('/teachings/$teachingId');
  }

  // ---------------------------------------------------------------------------
  // Auditeurs
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getTeachingListeners(
    String teachingId,
  ) async {
    final teaching = await _client.getOne('/teachings/$teachingId');
    final listeners = (teaching['listeners'] as List?) ?? const [];
    return listeners.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Membres pouvant être ajoutés comme auditeurs.
  ///
  /// La notion d'auditeur sert au suivi de formation interne : le serveur ne
  /// retient que les ouvriers, responsables et administrateurs lors de la
  /// synchronisation automatique. L'ajout manuel reste libre.
  static Future<List<Map<String, dynamic>>> getPotentialListeners() =>
      _client.getList('/members', query: {
        'is_active': true,
        'limit': 200,
        'orderBy': 'lastName',
        'order': 'asc',
      });

  static Future<Map<String, dynamic>> addListener({
    required String teachingId,
    required String memberId,
  }) async {
    final data = await _client.post(
      '/teachings/$teachingId/listeners',
      body: {'member_ids': [memberId]},
    );
    return (data as Map).cast<String, dynamic>();
  }

  /// Retire un auditeur.
  ///
  /// L'API identifie l'auditeur par le couple enseignement + membre, non par
  /// un identifiant de ligne. Le [teachingId] est donc nécessaire, et
  /// [listenerId] doit être l'identifiant du **membre**.
  static Future<void> removeListener(
    String listenerId, {
    String? teachingId,
  }) async {
    if (teachingId == null) {
      throw ArgumentError(
        'teachingId est requis : l\'API identifie un auditeur par le couple '
        'enseignement + membre, non par un identifiant de ligne.',
      );
    }

    await _client.delete('/teachings/$teachingId/listeners/$listenerId');
  }

  /// Alimente les auditeurs depuis la présence au culte de la même date.
  ///
  /// Utile si la feuille de présence a été complétée après la création de
  /// l'enseignement.
  static Future<Map<String, dynamic>> syncListenersFromAttendance(
    String teachingId,
  ) async {
    final data = await _client.post('/teachings/$teachingId/listeners/sync');
    return (data as Map).cast<String, dynamic>();
  }
}