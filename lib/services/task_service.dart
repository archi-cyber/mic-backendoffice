import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Tâches, projets, étiquettes et notifications associées.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// Deux traitements disparaissent du client, désormais assurés par le serveur :
/// l'envoi des notifications push lors d'une assignation ou d'un rappel, et la
/// génération des tâches de montage à la création d'un enseignement. Les
/// méthodes correspondantes restent exposées, mais se contentent d'appeler
/// l'API.
class TaskService {
  static ApiClient get _client => AuthService.client;

  // ---------------------------------------------------------------------------
  // Tâches
  // ---------------------------------------------------------------------------

  /// Crée une tâche.
  ///
  /// Une tâche relève **soit** d'un département, **soit** d'un membre. Fournir
  /// les deux renvoie `TASK_OWNER_CONFLICT`, aucun des deux
  /// `TASK_OWNER_REQUIRED`.
  ///
  /// Si un assigné a dépassé le seuil de pénalités, le serveur refuse avec
  /// `PENALTY_THRESHOLD_EXCEEDED` et nomme les personnes concernées.
  static Future<Map<String, dynamic>> createTask({
    String? departmentId,
    String? memberId,
    required Map<String, dynamic> taskData,
  }) async {
    final data = await _client.post('/tasks', body: {
      ...taskData,
      if (departmentId != null) 'department_id': departmentId,
      if (memberId != null) 'member_id': memberId,
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getTaskById(String taskId) =>
      _client.getOne('/tasks/$taskId');

  /// Toutes les tâches, filtrables.
  ///
  /// Les tâches archivées sont exclues : l'archivage est le geste par lequel
  /// un responsable acte qu'une tâche n'a plus à être suivie.
  static Future<List<Map<String, dynamic>>> getAllTasks({
    String? departmentId,
    String? status,
    String? priority,
    int? limit,
    int? offset,
  }) {
    final effectiveLimit = (limit ?? 200).clamp(1, 200);
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList('/tasks', query: {
      'page': page,
      'limit': effectiveLimit,
      if (departmentId != null) 'department_id': departmentId,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
    });
  }

  static Future<List<Map<String, dynamic>>> getDepartmentTasks({
    required String departmentId,
    int? limit,
    int? offset,
  }) =>
      getAllTasks(departmentId: departmentId, limit: limit, offset: offset);

  static Future<Map<String, dynamic>> updateTask({
    required String taskId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client.patch('/tasks/$taskId', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteTask(String taskId) async {
    await _client.delete('/tasks/$taskId');
  }

  /// Archive une tâche.
  ///
  /// Arrête l'accumulation des pénalités sans effacer celles déjà dues.
  static Future<Map<String, dynamic>> archiveTask(String taskId) async {
    final data = await _client.post('/tasks/$taskId/archive');
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> unarchiveTask(String taskId) async {
    final data = await _client.post('/tasks/$taskId/unarchive');
    return (data as Map).cast<String, dynamic>();
  }

  // ---------------------------------------------------------------------------
  // Assignations
  // ---------------------------------------------------------------------------

  /// Assignations d'une tâche.
  ///
  /// Extraites du détail : une seule requête suffit là où l'ancienne version
  /// en faisait deux.
  static Future<List<Map<String, dynamic>>> getTaskAssignments(
    String taskId,
  ) async {
    final task = await _client.getOne('/tasks/$taskId');
    final assignments = (task['assignments'] as List?) ?? const [];
    return assignments.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Assigne la tâche à un membre.
  ///
  /// Le membre est notifié côté serveur, en temps réel et par push : le client
  /// n'a plus à s'en charger.
  static Future<Map<String, dynamic>> assignTask({
    required String taskId,
    required String memberId,
  }) async {
    final data = await _client.post(
      '/tasks/$taskId/assign',
      body: {'member_ids': [memberId]},
    );
    return (data as Map).cast<String, dynamic>();
  }

  /// Retire une assignation.
  ///
  /// Les pénalités déjà constatées sont conservées : elles sanctionnent un
  /// retard qui a réellement eu lieu. Les effacer ouvrirait une échappatoire —
  /// il suffirait de se désassigner pour effacer son ardoise.
  static Future<void> removeAssignment({
    required String taskId,
    required String memberId,
  }) async {
    await _client.delete('/tasks/$taskId/assign/$memberId');
  }

  /// Change le statut d'une tâche.
  ///
  /// L'API porte le statut sur la tâche elle-même, non sur chaque assignation :
  /// une tâche est terminée ou non, indépendamment de qui l'a menée.
  static Future<Map<String, dynamic>> updateAssignmentStatus({
    required String taskId,
    required String memberId,
    required String status,
  }) async {
    final data = await _client.patch('/tasks/$taskId', body: {'status': status});
    return (data as Map).cast<String, dynamic>();
  }

  /// Remplace les étiquettes de la tâche.
  ///
  /// Elles doivent appartenir au département de la tâche ; le serveur refuse
  /// sinon avec `TAG_DEPARTMENT_MISMATCH`.
  static Future<Map<String, dynamic>> setTaskTags({
    required String taskId,
    required List<String> tagIds,
  }) async {
    final data = await _client.post(
      '/tasks/$taskId/tags',
      body: {'tag_ids': tagIds},
    );
    return (data as Map).cast<String, dynamic>();
  }

  // ---------------------------------------------------------------------------
  // Rappels
  // ---------------------------------------------------------------------------

  /// Envoie un rappel aux assignés d'une tâche.
  ///
  /// Le serveur refuse les tâches terminées, annulées ou archivées : insister
  /// sur un travail déjà fait décrédibilise les notifications, et les gens
  /// finissent par ne plus les lire.
  ///
  /// [customMessage] n'est pas transmis : le message est composé côté serveur
  /// à partir de l'échéance, ce qui garantit un texte cohérent et à jour.
  static Future<Map<String, dynamic>> remindTask({
    required String taskId,
    String? customMessage,
  }) async {
    final data = await _client.post('/tasks/$taskId/remind');
    return (data as Map).cast<String, dynamic>();
  }

  /// Rappelle toutes les tâches en attente.
  ///
  /// Une notification **par membre**, pas par tâche : quelqu'un ayant cinq
  /// tâches en retard reçoit un récapitulatif. L'inverse noierait sa liste et
  /// le pousserait à tout ignorer.
  static Future<Map<String, dynamic>> remindAllPendingTasks({
    String? customMessage,
    String? departmentId,
  }) async {
    final data = await _client.post('/tasks/remind-pending', body: {
      if (departmentId != null) 'department_id': departmentId,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Crée les tâches de montage d'un enseignement.
  ///
  /// Conservée pour compatibilité. Le serveur les génère automatiquement à la
  /// création de l'enseignement — trois formats, échéance à dix jours — ce qui
  /// garantit qu'elles ne peuvent être oubliées.
  static Future<List<Map<String, dynamic>>> createTeachingTasks({
    required Map<String, dynamic> teaching,
  }) async {
    final teachingId = teaching['id'] as String?;
    if (teachingId == null) return const [];

    final detail = await _client.getOne('/teachings/$teachingId');
    final tasks = (detail['tasks'] as List?) ?? const [];

    return tasks.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// Notifications de l'utilisateur connecté.
  ///
  /// [memberId] est ignoré : le serveur déduit le destinataire du jeton.
  /// Accepter un identifiant fourni par le client permettrait de lire les
  /// notifications d'autrui en changeant une valeur.
  static Future<List<Map<String, dynamic>>> getNotifications({
    required String memberId,
    bool? isRead,
    int? limit,
    int? offset,
  }) {
    final effectiveLimit = limit ?? 50;
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList('/notifications', query: {
      'page': page,
      'limit': effectiveLimit,
      if (isRead != null) 'is_read': isRead,
    });
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    await _client.post('/notifications/read', body: {
      'notification_ids': [notificationId],
    });
  }
}