import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Rapports d'activité des départements.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// Les cinq champs du canevas — objectifs, points positifs, difficultés,
/// suggestions — restent obligatoires côté serveur. C'est la structure retenue
/// par l'église, et la rendre facultative produirait des rapports
/// inexploitables.
class DepartmentReportService {
  static ApiClient get _client => AuthService.client;

  static Future<Map<String, dynamic>> createReport({
    required String departmentId,
    required String title,
    required String definedObjectives,
    required String positivePoints,
    required String difficultiesEncountered,
    required String suggestions,
    String? comments,
  }) async {
    final data = await _client.post(
      '/departments/$departmentId/reports',
      body: {
        'title': title,
        'defined_objectives': definedObjectives,
        'positive_points': positivePoints,
        'difficulties_encountered': difficultiesEncountered,
        'suggestions': suggestions,
        if (comments != null) 'comments': comments,
      },
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> getDepartmentReports({
    required String departmentId,
    int? limit,
    int? offset,
  }) {
    final effectiveLimit = limit ?? 50;
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList(
      '/departments/$departmentId/reports',
      query: {'page': page, 'limit': effectiveLimit},
    );
  }

  /// Détail d'un rapport.
  ///
  /// L'API n'expose pas de route unitaire : le rapport est retrouvé dans la
  /// liste de son département. Une recherche transversale est donc nécessaire
  /// quand le département n'est pas connu de l'appelant.
  static Future<Map<String, dynamic>> getReportById(String reportId) async {
    final departments = await _client.getList('/departments', query: {
      'limit': 100,
    });

    for (final department in departments) {
      final reports = await getDepartmentReports(
        departmentId: department['id'] as String,
        limit: 200,
      );

      for (final report in reports) {
        if (report['id'] == reportId) return report;
      }
    }

    throw Exception('Rapport introuvable.');
  }

  /// Modifie un rapport.
  ///
  /// Réservé à son auteur ou à un administrateur : un rapport d'activité
  /// engage celui qui le signe, et permettre à un tiers de le réécrire lui
  /// ferait endosser des propos qui ne sont pas les siens.
  static Future<Map<String, dynamic>> updateReport({
    required String reportId,
    required String title,
    required String definedObjectives,
    required String positivePoints,
    required String difficultiesEncountered,
    required String suggestions,
    String? comments,
  }) async {
    final data = await _client.patch(
      '/departments/reports/$reportId',
      body: {
        'title': title,
        'defined_objectives': definedObjectives,
        'positive_points': positivePoints,
        'difficulties_encountered': difficultiesEncountered,
        'suggestions': suggestions,
        if (comments != null) 'comments': comments,
      },
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteReport(String reportId) async {
    await _client.delete('/departments/reports/$reportId');
  }

  /// Tous les rapports d'un département, pour une synthèse.
  static Future<List<Map<String, dynamic>>> getAllDepartmentReportsForSummary(
    String departmentId,
  ) =>
      getDepartmentReports(departmentId: departmentId, limit: 200);
}