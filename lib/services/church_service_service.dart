import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Cultes.
///
/// Signatures identiques à l'implémentation Supabase. Les dates restent des
/// `DateTime` : la conversion vers le format `AAAA-MM-JJ` attendu par l'API se
/// fait ici, pas dans les écrans.
class ChurchServiceService {
  static ApiClient get _client => AuthService.client;

  /// Formate une date pour l'API — jour seul, sans heure ni fuseau.
  ///
  /// Envoyer un `DateTime` complet ferait dériver la date d'un jour selon le
  /// fuseau du serveur : un culte du dimanche saisi à 23 h basculerait au lundi.
  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Crée un culte.
  ///
  /// Le couple date + nom doit être unique ; le serveur renvoie
  /// `SERVICE_NAME_DUPLICATE` sinon.
  static Future<Map<String, dynamic>> createService({
    required DateTime serviceDate,
    required String name,
  }) async {
    final data = await _client.post('/church-services', body: {
      'service_date': _day(serviceDate),
      'name': name.trim(),
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Retrouve un culte existant, ou le crée.
  ///
  /// Évite un doublon quand deux responsables ouvrent l'écran de pointage en
  /// même temps. La recherche précède la création ; en cas de collision malgré
  /// tout, l'erreur d'unicité est rattrapée et le culte existant renvoyé.
  static Future<Map<String, dynamic>> findOrCreate({
    required DateTime serviceDate,
    required String name,
  }) async {
    final trimmed = name.trim();
    final existing = await getServicesForDate(serviceDate);

    for (final service in existing) {
      if ((service['name'] as String?)?.trim().toLowerCase() ==
          trimmed.toLowerCase()) {
        return service;
      }
    }

    try {
      return await createService(serviceDate: serviceDate, name: trimmed);
    } catch (_) {
      // Course entre deux clients : le culte vient d'être créé par l'autre.
      final retry = await getServicesForDate(serviceDate);
      return retry.firstWhere(
        (s) => (s['name'] as String?)?.trim().toLowerCase() ==
            trimmed.toLowerCase(),
        orElse: () => throw StateError('Culte introuvable après conflit.'),
      );
    }
  }

  /// Détail d'un culte, avec sa feuille de présence.
  ///
  /// Renvoie `null` si le culte n'existe pas, comme l'ancienne implémentation.
  static Future<Map<String, dynamic>?> getById(String serviceId) async {
    try {
      return await _client.getOne('/church-services/$serviceId');
    } catch (_) {
      return null;
    }
  }

  /// Cultes d'une date donnée.
  static Future<List<Map<String, dynamic>>> getServicesForDate(
    DateTime serviceDate,
  ) {
    final day = _day(serviceDate);
    return _client.getList(
      '/church-services',
      query: {'from': day, 'to': day, 'limit': 50},
    );
  }

  /// Tous les cultes, du plus récent au plus ancien.
  static Future<List<Map<String, dynamic>>> getAllServices({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    return _client.getList('/church-services', query: {
      if (startDate != null) 'from': _day(startDate),
      if (endDate != null) 'to': _day(endDate),
      'limit': limit ?? 200,
    });
  }

  /// Modifie un culte.
  ///
  /// Changer la date propage la mise à jour sur toutes les présences liées.
  static Future<Map<String, dynamic>> updateService({
    required String serviceId,
    String? name,
    DateTime? serviceDate,
  }) async {
    final data = await _client.patch('/church-services/$serviceId', body: {
      if (name != null) 'name': name.trim(),
      if (serviceDate != null) 'service_date': _day(serviceDate),
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Suppression logique.
  ///
  /// Les présences et les visiteurs rattachés sont retirés en cascade :
  /// conserver une présence pointant vers un culte invisible fausserait tous
  /// les décomptes.
  static Future<void> softDelete(String serviceId) async {
    await _client.delete('/church-services/$serviceId');
  }

  /// Membres absents d'un culte.
  ///
  /// Réunit les absents déclarés et ceux jamais pointés.
  static Future<Map<String, dynamic>> getAbsentees(String serviceId) =>
      _client.getOne('/church-services/$serviceId/absentees');
}