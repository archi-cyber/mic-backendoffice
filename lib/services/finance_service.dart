import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Finances.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// Accès réservé aux administrateurs et aux responsables du département
/// « Finance ». Toute autre tentative reçoit `FINANCE_ACCESS_DENIED`, y
/// compris avec le droit `giving` accordé dans la grille des permissions : la
/// garde financière s'y superpose au lieu de s'y substituer.
class FinanceService {
  static ApiClient get _client => AuthService.client;

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Accès
  // ---------------------------------------------------------------------------

  /// Indique si l'utilisateur peut accéder aux données financières.
  ///
  /// Vérifié en interrogeant l'API : une seule requête légère tranche, là où
  /// l'ancienne version croisait trois tables côté client.
  ///
  /// Sert à décider d'afficher l'onglet. Le serveur reste seul juge de l'accès
  /// réel — masquer un bouton évite une tentative vouée à l'échec, mais ne
  /// protège rien.
  static Future<bool> isFinanceLeader() async {
    try {
      await _client.get('/giving', query: {'limit': 1});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Identifiant du département Finance.
  ///
  /// Ce département ne peut être ni renommé ni supprimé côté serveur :
  /// l'accès au module financier dépend de son nom exact.
  static Future<String?> getFinanceDepartmentId() async {
    try {
      final departments = await _client.getList('/departments', query: {
        'search': 'Finance',
        'limit': 20,
      });

      for (final department in departments) {
        final name = (department['name'] as String? ?? '').trim().toLowerCase();
        if (name == 'finance') return department['id'] as String?;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Membres actifs, pour le sélecteur de donateur.
  static Future<List<Map<String, dynamic>>> getActiveMembers() =>
      _client.getList('/members', query: {
        'is_active': true,
        'limit': 200,
        'orderBy': 'firstName',
        'order': 'asc',
      });

  // ---------------------------------------------------------------------------
  // Mouvements
  // ---------------------------------------------------------------------------

  /// Liste des mouvements financiers.
  static Future<List<Map<String, dynamic>>> getAllGivingRecords({
    DateTime? fromDate,
    DateTime? toDate,
    String? type,
    String? tag,
    String? memberId,
    int? limit,
  }) =>
      _client.getList('/giving', query: {
        if (fromDate != null) 'from': _day(fromDate),
        if (toDate != null) 'to': _day(toDate),
        if (type != null) 'type': type,
        if (tag != null) 'tag': tag,
        if (memberId != null) 'member_id': memberId,
        'limit': limit ?? 500,
      });

  /// Détail d'un mouvement.
  ///
  /// Le champ `is_editable` indique si la fenêtre de modification de deux
  /// jours est encore ouverte — de quoi griser le bouton plutôt que de laisser
  /// tenter une action vouée à échouer.
  static Future<Map<String, dynamic>> getGivingRecordById(String givingId) =>
      _client.getOne('/giving/$givingId');

  /// Enregistre un mouvement.
  ///
  /// [isExpense] est traduit en `type` pour l'API : `expense` pour une sortie,
  /// `receiving` pour une entrée.
  ///
  /// [giverName] reste obligatoire même pour un membre : il figure tel quel
  /// sur les reçus, et un membre supprimé ne doit pas rendre le mouvement
  /// anonyme.
  static Future<Map<String, dynamic>> createGivingRecord({
    required String giverName,
    required double amount,
    required String tag,
    required bool isExpense,
    String? notes,
    String? memberId,
    DateTime? date,
  }) async {
    final data = await _client.post('/giving', body: {
      'giver_name': giverName,
      'amount': amount,
      'tag': tag,
      'type': isExpense ? 'expense' : 'receiving',
      if (notes != null) 'notes': notes,
      if (memberId != null) 'member_id': memberId,
      if (date != null) 'date': _day(date),
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Modifie un mouvement.
  ///
  /// Possible pendant deux jours ; au-delà, réservé aux administrateurs avec
  /// le code `GIVING_EDIT_WINDOW_CLOSED`. Une écriture ancienne a
  /// probablement été reportée dans un rapport ou un rapprochement, et la
  /// modifier sans trace romprait la piste d'audit.
  static Future<Map<String, dynamic>> updateGivingRecord({
    required String givingId,
    required String giverName,
    required double amount,
    required String tag,
    required bool isExpense,
    String? notes,
    String? memberId,
    DateTime? date,
  }) async {
    final data = await _client.patch('/giving/$givingId', body: {
      'giver_name': giverName,
      'amount': amount,
      'tag': tag,
      'type': isExpense ? 'expense' : 'receiving',
      'notes': notes,
      'member_id': memberId,
      if (date != null) 'date': _day(date),
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteGivingRecord(String givingId) async {
    await _client.delete('/giving/$givingId');
  }

  // ---------------------------------------------------------------------------
  // Synthèses
  // ---------------------------------------------------------------------------

  /// Totaux et ventilation par catégorie sur une période.
  static Future<Map<String, dynamic>> getSummary({
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _client.getOne('/giving/summary', query: {
        if (fromDate != null) 'from': _day(fromDate),
        if (toDate != null) 'to': _day(toDate),
      });

  /// Ventilation mensuelle d'une année.
  ///
  /// Les douze mois sont toujours présents, même vides : un graphique avec des
  /// mois manquants serait trompeur à la lecture.
  static Future<Map<String, dynamic>> getMonthlyBreakdown(int year) =>
      _client.getOne('/giving/monthly/$year');

  /// Historique des dons d'un membre.
  static Future<Map<String, dynamic>> getMemberGiving(
    String memberId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      _client.getOne('/giving/member/$memberId', query: {
        if (fromDate != null) 'from': _day(fromDate),
        if (toDate != null) 'to': _day(toDate),
      });
}