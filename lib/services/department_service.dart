import '../core/api/api_client.dart';
import '../core/utils/permission_helper.dart';
import 'auth_service.dart';

/// Départements et appartenances.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// Les quatre méthodes de vérification — `isDepartmentLeader`,
/// `isDepartmentSubleader`, `canEditDepartment`, `canDeleteDepartment` — ne
/// déclenchent plus de requête : les appartenances sont chargées une fois avec
/// le profil, et lues en mémoire. L'ancienne version interrogeait la base à
/// chaque appel, plusieurs fois par écran.
class DepartmentService {
  static ApiClient get _client => AuthService.client;

  // ---------------------------------------------------------------------------
  // Vérifications
  // ---------------------------------------------------------------------------

  static Future<bool> isDepartmentLeader(String departmentId) async {
    if (PermissionHelper.role == 'admin' || PermissionHelper.role == 'pastor') {
      return true;
    }
    return PermissionHelper.departmentRoles.any(
      (d) => d['department_id'] == departmentId && d['role'] == 'leader',
    );
  }

  static Future<bool> isDepartmentSubleader(String departmentId) async {
    return PermissionHelper.departmentRoles.any(
      (d) => d['department_id'] == departmentId && d['role'] == 'subleader',
    );
  }

  /// Un responsable ou un adjoint peut modifier son département.
  static Future<bool> canEditDepartment(String departmentId) async {
    return await isDepartmentLeader(departmentId) ||
        await isDepartmentSubleader(departmentId);
  }

  /// La suppression reste réservée aux responsables et administrateurs.
  ///
  /// Un adjoint peut modifier, pas supprimer : la nuance existait déjà dans
  /// l'implémentation d'origine et méritait d'être conservée.
  static Future<bool> canDeleteDepartment(String departmentId) =>
      isDepartmentLeader(departmentId);

  // ---------------------------------------------------------------------------
  // Départements
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> createDepartment({
    required Map<String, dynamic> departmentData,
  }) async {
    final data = await _client.post('/departments', body: departmentData);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getDepartments({
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
  }) {
    final effectiveLimit = limit ?? 100;
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList('/departments', query: {
      'page': page,
      'limit': effectiveLimit,
      'with_counts': true,
      ...?filters,
    });
  }

  static Future<Map<String, dynamic>> getDepartmentById(String departmentId) =>
      _client.getOne('/departments/$departmentId');

  /// Modifie un département.
  ///
  /// Renommer « Finance » est refusé avec le code
  /// `FINANCE_DEPARTMENT_PROTECTED` : l'accès au module financier dépend de ce
  /// nom exact, et le changer couperait silencieusement l'accès aux trésoriers.
  static Future<Map<String, dynamic>> updateDepartment({
    required String departmentId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client.patch('/departments/$departmentId', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteDepartment(String departmentId) async {
    await _client.delete('/departments/$departmentId');
  }

  // ---------------------------------------------------------------------------
  // Membres
  // ---------------------------------------------------------------------------

  /// Membres d'un département, avec leur rôle interne.
  ///
  /// Extrait la liste du détail du département : une seule requête suffit là
  /// où l'ancienne version en faisait deux.
  static Future<List<Map<String, dynamic>>> getDepartmentMembers(
    String departmentId,
  ) async {
    final department = await getDepartmentById(departmentId);
    final members = (department['department_members'] as List?) ?? const [];

    return members
        .map((entry) => (entry as Map).cast<String, dynamic>())
        .toList();
  }

  /// Tous les ouvriers, avec leurs départements.
  static Future<List<Map<String, dynamic>>> getAllWorkersWithDepartments() {
    return _client.getList('/members', query: {
      'role': 'worker',
      'is_active': true,
      'limit': 200,
    });
  }

  /// Définit le département principal d'un membre.
  ///
  /// L'ancien est automatiquement dégradé, dans une transaction côté serveur :
  /// un membre ne peut jamais se retrouver avec deux départements principaux,
  /// ni aucun, même en cas de coupure réseau.
  static Future<void> setMainDepartment({
    required String memberId,
    required String departmentId,
  }) async {
    await _client.patch(
      '/departments/$departmentId/members/$memberId',
      body: {'is_main': true},
    );
  }

  /// Ajoute un membre au département.
  ///
  /// [defaultPassword] est ignoré : la création de compte relève désormais de
  /// `UserService.createAccount`, qui attribue lui-même le mot de passe par
  /// défaut avec changement obligatoire. Le paramètre est conservé pour ne pas
  /// casser les appels existants.
  static Future<Map<String, dynamic>> addMemberToDepartment({
    required String departmentId,
    required String memberId,
    required String role,
    String? defaultPassword,
  }) async {
    final data = await _client.post(
      '/departments/$departmentId/members',
      body: {'member_id': memberId, 'role': role},
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> removeMemberFromDepartment({
    required String departmentId,
    required String memberId,
  }) async {
    await _client.delete('/departments/$departmentId/members/$memberId');
  }

  // ---------------------------------------------------------------------------
  // Rapports d'activité
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getReports(
    String departmentId, {
    int page = 1,
    int limit = 20,
  }) =>
      _client.getList(
        '/departments/$departmentId/reports',
        query: {'page': page, 'limit': limit},
      );

  static Future<Map<String, dynamic>> createReport({
    required String departmentId,
    required Map<String, dynamic> reportData,
  }) async {
    final data = await _client.post(
      '/departments/$departmentId/reports',
      body: reportData,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateReport({
    required String reportId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client.patch(
      '/departments/reports/$reportId',
      body: updates,
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteReport(String reportId) async {
    await _client.delete('/departments/reports/$reportId');
  }
}