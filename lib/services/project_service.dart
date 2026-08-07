import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Projets.
///
/// Regroupement de tâches au sein d'un département. Conservé comme classe
/// distincte : les écrans l'importent sous ce nom, et le fusionner ailleurs
/// aurait imposé de tous les modifier sans bénéfice.
class ProjectService {
  static ApiClient get _client => AuthService.client;

  /// Projets, filtrables par département.
  static Future<List<Map<String, dynamic>>> getProjects({
    String? departmentId,
    int? limit,
    int? offset,
  }) {
    return _client.getList('/projects', query: {
      if (departmentId != null) 'department_id': departmentId,
      'limit': limit ?? 200,
    });
  }

  /// Détail d'un projet.
  ///
  /// Inclut ses tâches et un taux d'avancement calculé à la lecture. Le
  /// stocker en base imposerait de le recalculer à chaque changement de
  /// statut, avec le risque de le laisser dériver.
  static Future<Map<String, dynamic>> getProjectById(String projectId) =>
      _client.getOne('/projects/$projectId');

  static Future<Map<String, dynamic>> createProject({
    required Map<String, dynamic> projectData,
  }) async {
    final data = await _client.post('/projects', body: projectData);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateProject({
    required String projectId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client.patch('/projects/$projectId', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  /// Supprime un projet.
  ///
  /// Ses tâches sont **conservées** : elles perdent leur regroupement mais
  /// restent à faire. Un projet n'est qu'une vue d'organisation ; le supprimer
  /// ne signifie pas que le travail disparaît.
  static Future<void> deleteProject(String projectId) async {
    await _client.delete('/projects/$projectId');
  }
}