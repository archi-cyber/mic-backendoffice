import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Visiteurs.
///
/// Signatures identiques à l'implémentation Supabase : paramètres nommés,
/// dates en `DateTime`. Les écrans n'ont rien à changer.
class VisitorService {
  static ApiClient get _client => AuthService.client;

  /// Formate une date pour l'API — jour seul, sans heure ni fuseau.
  ///
  /// Envoyer un `DateTime` complet ferait dériver la date d'un jour selon le
  /// fuseau du serveur : une visite saisie à 23 h basculerait au lendemain.
  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Enregistre un visiteur.
  ///
  /// Le rattachement à un culte est facultatif : une visite peut avoir lieu en
  /// dehors d'un service.
  static Future<Map<String, dynamic>> createVisitor({
    required Map<String, dynamic> visitorData,
  }) async {
    final data = await _client.post('/visitors', body: visitorData);
    return (data as Map).cast<String, dynamic>();
  }

  /// Liste des visiteurs.
  ///
  /// [filters] accepte les mêmes clés qu'auparavant : `church_service_id`,
  /// `search`.
  static Future<List<Map<String, dynamic>>> getVisitors({
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

    return _client.getList('/visitors', query: {
      'page': page,
      'limit': effectiveLimit,
      'order': ascending ? 'asc' : 'desc',
      if (orderBy != null) 'orderBy': orderBy,
      if (fromDate != null) 'from': _day(fromDate),
      if (toDate != null) 'to': _day(toDate),
      ...?filters,
    });
  }

  static Future<Map<String, dynamic>> getVisitorById(String visitorId) =>
      _client.getOne('/visitors/$visitorId');

  static Future<Map<String, dynamic>> updateVisitor({
    required String visitorId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client.patch('/visitors/$visitorId', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteVisitor(String visitorId) async {
    await _client.delete('/visitors/$visitorId');
  }

  /// Convertit le visiteur en membre.
  ///
  /// Le visiteur est supprimé au profit de la fiche membre : le conserver
  /// produirait un doublon dans les statistiques de fréquentation.
  ///
  /// Requiert le droit de **créer des membres**, et non celui de gérer les
  /// visiteurs — c'est bien un membre qui est créé.
  static Future<Map<String, dynamic>> convertToMember({
    required String visitorId,
    required DateTime birthday,
    required String role,
    bool isNewComer = true,
    String? newcomerIntention,
    String? departmentId,
  }) async {
    final data = await _client.post('/visitors/$visitorId/convert', body: {
      'birthday': _day(birthday),
      'is_new_comer': isNewComer,
      if (departmentId != null) 'department_id': departmentId,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Supprime les visiteurs rattachés à un culte.
  ///
  /// Côté serveur, supprimer un culte retire déjà ses visiteurs en cascade.
  /// Cette méthode couvre le cas où l'on souhaite les retirer sans toucher au
  /// culte lui-même.
  static Future<void> deleteVisitorsForService({
    required String churchServiceId,
  }) async {
    final visitors = await _client.getList('/visitors', query: {
      'church_service_id': churchServiceId,
      'limit': 200,
    });

    for (final visitor in visitors) {
      await _client.delete('/visitors/${visitor['id']}');
    }
  }

  /// Visiteurs d'un culte donné.
  static Future<List<Map<String, dynamic>>> getVisitorsForService(
    String churchServiceId,
  ) =>
      _client.getList('/visitors', query: {
        'church_service_id': churchServiceId,
        'limit': 200,
      });
}