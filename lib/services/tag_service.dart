import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Étiquettes de tâches.
///
/// Les étiquettes appartiennent à un **département** : deux départements
/// peuvent avoir chacun une étiquette « Urgent » sans interférence. Le nom
/// doit être unique au sein de son département — le serveur renvoie
/// `TAG_NAME_TAKEN` sinon.
class TagService {
  static ApiClient get _client => AuthService.client;

  static Future<List<Map<String, dynamic>>> getTags({
    String? departmentId,
    int? limit,
    int? offset,
  }) {
    return _client.getList('/tags', query: {
      if (departmentId != null) 'department_id': departmentId,
      'limit': limit ?? 200,
    });
  }

  static Future<Map<String, dynamic>> createTag({
    required String name,
    required String departmentId,
    String? color,
  }) async {
    final data = await _client.post('/tags', body: {
      'name': name,
      'department_id': departmentId,
      if (color != null) 'color': color,
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateTag({
    required String tagId,
    String? name,
    String? color,
    String? departmentId,
  }) async {
    final data = await _client.patch('/tags/$tagId', body: {
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (departmentId != null) 'department_id': departmentId,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Supprime une étiquette.
  ///
  /// Suppression définitive, sans corbeille : une étiquette est un simple
  /// libellé, sans valeur historique. Les tâches concernées la perdent, rien
  /// de plus.
  static Future<void> deleteTag(String tagId) async {
    await _client.delete('/tags/$tagId');
  }
}