import 'device_token_service.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';
import 'task_penalty_service.dart';

/// Task service for task and notification management
class TaskService {
  static final _client = SupabaseService.client;

  /// Task select with project, tags and assignments (for getTaskById, getAllTasks, getDepartmentTasks)
  static const String _taskSelectWithProjectAndTags =
      '*, departments(id, name), members!tasks_member_id_fkey(id, first_name, last_name, email), projects(id, title), task_tags(tag_id, tags(id, name)), task_assignments(member_id, members(id, first_name, last_name, email))';

  /// Create task for a department or individual
  /// taskData may include project_id (optional) and other fields.
  static Future<Map<String, dynamic>> createTask({
    String? departmentId,
    String? memberId,
    required Map<String, dynamic> taskData,
  }) async {
    try {
      final response = await _client
          .from('tasks')
          .insert({
            if (departmentId != null) 'department_id': departmentId,
            if (departmentId == null && memberId != null) 'member_id': memberId,
            ...taskData,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  /// Get tags for a task (from task_tags + tags)
  static Future<List<Map<String, dynamic>>> getTaskTags(String taskId) async {
    try {
      final response = await _client
          .from('task_tags')
          .select('tag_id, tags(id, name)')
          .eq('task_id', taskId);
      final list = List<Map<String, dynamic>>.from(response);
      return list
          .map((e) => e['tags'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      throw Exception('Failed to get task tags: $e');
    }
  }

  /// Replace all tags for a task (removes existing, inserts new)
  static Future<void> setTaskTags({
    required String taskId,
    required List<String> tagIds,
  }) async {
    try {
      await _client.from('task_tags').delete().eq('task_id', taskId);
      if (tagIds.isEmpty) return;
      await _client
          .from('task_tags')
          .insert(
            tagIds
                .map(
                  (tagId) => {
                    'task_id': taskId,
                    'tag_id': tagId,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                )
                .toList(),
          );
    } catch (e) {
      throw Exception('Failed to set task tags: $e');
    }
  }

  /// Assign task to member (insert into task_assignments and send notification)
  /// POST /tasks/:id/assign/:memberId
  static Future<void> assignTask({
    required String taskId,
    required String memberId,
  }) async {
    try {
      final canAssign = await TaskPenaltyService.canAssignMember(memberId);
      if (!canAssign) {
        final balance = await TaskPenaltyService.getMemberPenaltyBalance(
          memberId,
        );
        final threshold = await TaskPenaltyService.getBlockingThreshold();
        throw Exception(
          'This member has ${balance}frs unpaid penalties and cannot be assigned until below ${threshold}frs.',
        );
      }

      // Insert into task_assignments
      await _client.from('task_assignments').insert({
        'task_id': taskId,
        'member_id': memberId,
        'assigned_at': DateTime.now().toIso8601String(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      final task = await _getTaskPushDetails(taskId);
      final taskTitle = _taskTitle(task);
      final message = _buildTaskNotificationMessage(
        task,
        fallbackPrefix: 'You have been assigned this task.',
      );

      // Create notification for the assignee
      await _client.from('notifications').insert({
        'member_id': memberId,
        'type': 'task_assigned',
        'title': taskTitle,
        'message': message,
        'related_id': taskId,
        'related_type': 'task',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _sendTaskPushNotification(
        taskId: taskId,
        memberIds: [memberId],
        type: 'task_assigned',
        task: task,
        fallbackPrefix: 'You have been assigned this task.',
      );
    } catch (e) {
      throw Exception('Failed to assign task: $e');
    }
  }

  static Future<Map<String, dynamic>?> _getTaskPushDetails(
    String taskId,
  ) async {
    try {
      final task = await _client
          .from('tasks')
          .select(
            'id, title, description, due_date, priority, status, departments(name), projects(title)',
          )
          .eq('id', taskId)
          .maybeSingle();
      if (task == null) return null;
      return Map<String, dynamic>.from(task);
    } catch (_) {
      return null;
    }
  }

  static String _taskTitle(Map<String, dynamic>? task) {
    final title = task?['title']?.toString().trim();
    return title == null || title.isEmpty ? 'Task' : title;
  }

  static String _buildTaskNotificationMessage(
    Map<String, dynamic>? task, {
    required String fallbackPrefix,
    String? customMessage,
  }) {
    final details = <String>[];
    final dueDate = task?['due_date']?.toString();
    final priority = task?['priority']?.toString();
    final department = task?['departments'] is Map
        ? (task?['departments'] as Map)['name']?.toString()
        : null;
    final project = task?['projects'] is Map
        ? (task?['projects'] as Map)['title']?.toString()
        : null;
    final description = task?['description']?.toString().trim();

    if (dueDate != null && dueDate.isNotEmpty) {
      details.add('Due: $dueDate');
    }
    if (priority != null && priority.isNotEmpty) {
      details.add('Priority: $priority');
    }
    if (project != null && project.isNotEmpty) {
      details.add('Project: $project');
    }
    if (department != null && department.isNotEmpty) {
      details.add('Department: $department');
    }
    if (description != null && description.isNotEmpty) {
      details.add(description);
    }

    final intro = customMessage?.trim().isNotEmpty == true
        ? customMessage!.trim()
        : fallbackPrefix;
    if (details.isEmpty) return intro;
    return '$intro\n${details.join(' • ')}';
  }

  static Future<void> _sendTaskPushNotification({
    required String taskId,
    required List<String> memberIds,
    required String type,
    Map<String, dynamic>? task,
    required String fallbackPrefix,
    String? customMessage,
  }) async {
    try {
      final uniqueMemberIds = memberIds.toSet().toList();
      if (uniqueMemberIds.isEmpty) return;

      final users = await _client
          .from('users')
          .select('id')
          .inFilter('member_id', uniqueMemberIds)
          .eq('is_active', true)
          .limit(1000);

      final userIds = List<Map<String, dynamic>>.from(
        users,
      ).map((user) => user['id']?.toString()).whereType<String>().toList();
      if (userIds.isEmpty) return;

      final tokensMap = await DeviceTokenService.getDeviceTokensForUsers(
        userIds,
      );
      final tokens = <String>{};
      for (final entry in tokensMap.entries) {
        tokens.addAll(entry.value);
      }
      if (tokens.isEmpty) return;

      final taskDetails = task ?? await _getTaskPushDetails(taskId);
      final title = _taskTitle(taskDetails);
      final body = _buildTaskNotificationMessage(
        taskDetails,
        fallbackPrefix: fallbackPrefix,
        customMessage: customMessage,
      );

      await PushNotificationService.sendPushNotification(
        deviceTokens: tokens.toList(),
        title: title,
        body: body,
        data: {
          'type': type,
          'taskId': taskId,
          'related_id': taskId,
          'related_type': 'task',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );
    } catch (_) {
      // Push is best-effort; in-app notification above is the source of truth.
    }
  }

  /// Send reminder for task (create notification)
  /// POST /tasks/:id/remind
  static Future<void> remindTask({
    required String taskId,
    String? customMessage,
  }) async {
    try {
      // Get task assignments
      final assignments = await _client
          .from('task_assignments')
          .select('member_id')
          .eq('task_id', taskId);

      final task = await _getTaskPushDetails(taskId);
      final taskTitle = _taskTitle(task);
      final message = _buildTaskNotificationMessage(
        task,
        fallbackPrefix: 'Reminder: you have a pending task.',
        customMessage: customMessage,
      );

      // Create notifications for all assignees
      final notifications = (assignments as List)
          .map(
            (assignment) => {
              'member_id': assignment['member_id'],
              'type': 'task_reminder',
              'title': taskTitle,
              'message': message,
              'related_id': taskId,
              'related_type': 'task',
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      if (notifications.isNotEmpty) {
        await _client.from('notifications').insert(notifications);
        await _sendTaskPushNotification(
          taskId: taskId,
          memberIds: (assignments as List)
              .map((assignment) => assignment['member_id']?.toString())
              .whereType<String>()
              .toList(),
          type: 'task_reminder',
          task: task,
          fallbackPrefix: 'Reminder: you have a pending task.',
          customMessage: customMessage,
        );
      }
    } catch (e) {
      throw Exception('Failed to send task reminder: $e');
    }
  }

  static Future<int> remindAllPendingTasks({String? customMessage}) async {
    try {
      final assignments = await _client.from('task_assignments').select('''
            member_id,
            status,
            tasks(id, title, description, due_date, priority, status, archived_at, departments(name), projects(title))
          ''');

      final notifications = <Map<String, dynamic>>[];
      final pushTargets =
          <({String taskId, String memberId, Map<String, dynamic> task})>[];

      for (final row in List<Map<String, dynamic>>.from(assignments)) {
        final assignmentStatus = row['status']?.toString().toLowerCase();
        if (assignmentStatus == 'completed' ||
            assignmentStatus == 'cancelled') {
          continue;
        }
        final task = row['tasks'];
        if (task is! Map) continue;
        if (task['archived_at'] != null) continue;
        final taskStatus = task['status']?.toString().toLowerCase();
        if (taskStatus == 'completed' || taskStatus == 'cancelled') continue;

        final memberId = row['member_id']?.toString();
        final taskId = task['id']?.toString();
        if (memberId == null || taskId == null) continue;
        final taskMap = Map<String, dynamic>.from(task);
        final message = _buildTaskNotificationMessage(
          taskMap,
          fallbackPrefix: 'Reminder: you have a pending task.',
          customMessage: customMessage,
        );
        notifications.add({
          'member_id': memberId,
          'type': 'task_reminder',
          'title': _taskTitle(taskMap),
          'message': message,
          'related_id': taskId,
          'related_type': 'task',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
        pushTargets.add((taskId: taskId, memberId: memberId, task: taskMap));
      }

      if (notifications.isEmpty) return 0;

      await _client.from('notifications').insert(notifications);
      for (final target in pushTargets) {
        await _sendTaskPushNotification(
          taskId: target.taskId,
          memberIds: [target.memberId],
          type: 'task_reminder',
          task: target.task,
          fallbackPrefix: 'Reminder: you have a pending task.',
          customMessage: customMessage,
        );
      }

      return notifications.length;
    } catch (e) {
      throw Exception('Failed to send general task reminder: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> createTeachingTasks({
    required Map<String, dynamic> teaching,
  }) async {
    final mediaTeam = await TaskPenaltyService.getMediaTeamDepartment();
    if (mediaTeam == null) {
      throw Exception('Department "Media Team" was not found');
    }

    final departmentId = mediaTeam['id'].toString();
    final title = teaching['title']?.toString() ?? 'Teaching';
    final teachingId = teaching['id'].toString();
    final teachingDate = DateTime.parse(teaching['teaching_date'].toString());
    final dueOffset = await TaskPenaltyService.getTeachingTaskDueOffsetDays();
    final dueDate = teachingDate.add(Duration(days: dueOffset));
    final dueDateString = dueDate.toIso8601String().split('T')[0];

    final specs = [
      {
        'type': 'mid',
        'index': 1,
        'title': 'Mid 1 - $title',
        'description':
            'Prepare the first mid teaching deliverable for "$title".',
      },
      {
        'type': 'mid',
        'index': 2,
        'title': 'Mid 2 - $title',
        'description':
            'Prepare the second mid teaching deliverable for "$title".',
      },
      {
        'type': 'short',
        'index': 1,
        'title': 'Short 1 - $title',
        'description':
            'Prepare the first short teaching deliverable for "$title".',
      },
      {
        'type': 'short',
        'index': 2,
        'title': 'Short 2 - $title',
        'description':
            'Prepare the second short teaching deliverable for "$title".',
      },
      {
        'type': 'short',
        'index': 3,
        'title': 'Short 3 - $title',
        'description':
            'Prepare the third short teaching deliverable for "$title".',
      },
      {
        'type': 'full',
        'index': 1,
        'title': 'Full - $title',
        'description': 'Prepare the full teaching deliverable for "$title".',
      },
    ];

    final created = <Map<String, dynamic>>[];
    for (final spec in specs) {
      created.add(
        await createTask(
          departmentId: departmentId,
          taskData: {
            'title': spec['title'],
            'description': spec['description'],
            'due_date': dueDateString,
            'priority': 'medium',
            'status': 'pending',
            'teaching_id': teachingId,
            'teaching_task_type': spec['type'],
            'teaching_task_index': spec['index'],
          },
        ),
      );
    }

    return created;
  }

  /// Get user's notifications
  /// GET /notifications
  static Future<List<Map<String, dynamic>>> getNotifications({
    required String memberId,
    bool? isRead,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _client
          .from('notifications')
          .select()
          .eq('member_id', memberId);

      // Filter by read status
      if (isRead != null) {
        query = query.eq('is_read', isRead);
      }

      // Order by created date (newest first) - returns PostgrestTransformBuilder
      dynamic transformQuery = query.order('created_at', ascending: false);

      // Apply pagination (on PostgrestTransformBuilder)
      if (limit != null) {
        transformQuery = transformQuery.limit(limit);
      }
      if (offset != null) {
        transformQuery = transformQuery.range(
          offset,
          offset + (limit ?? 10) - 1,
        );
      }

      final response = await transformQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get notifications: $e');
    }
  }

  /// Get tasks for a department
  /// GET /departments/:deptId/tasks
  static Future<List<Map<String, dynamic>>> getDepartmentTasks({
    required String departmentId,
    int? limit,
    int? offset,
  }) async {
    try {
      var filterQuery = _client
          .from('tasks')
          .select(_taskSelectWithProjectAndTags)
          .eq('department_id', departmentId);

      // Order by created date (returns PostgrestTransformBuilder)
      dynamic transformQuery = filterQuery.order(
        'created_at',
        ascending: false,
      );

      // Apply pagination (on PostgrestTransformBuilder)
      if (limit != null) {
        transformQuery = transformQuery.limit(limit);
      }
      if (offset != null) {
        transformQuery = transformQuery.range(
          offset,
          offset + (limit ?? 10) - 1,
        );
      }

      final response = await transformQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get department tasks: $e');
    }
  }

  /// Get task by ID
  /// GET /tasks/:id
  static Future<Map<String, dynamic>> getTaskById(String taskId) async {
    try {
      final response = await _client
          .from('tasks')
          .select(_taskSelectWithProjectAndTags)
          .eq('id', taskId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get task: $e');
    }
  }

  /// Get task assignments
  static Future<List<Map<String, dynamic>>> getTaskAssignments(
    String taskId,
  ) async {
    try {
      final response = await _client
          .from('task_assignments')
          .select('*, members(id, first_name, last_name, email)')
          .eq('task_id', taskId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get task assignments: $e');
    }
  }

  /// Update task
  /// PATCH /tasks/:id
  static Future<Map<String, dynamic>> updateTask({
    required String taskId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _client
          .from('tasks')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', taskId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to update task: $e');
    }
  }

  /// Delete task
  /// DELETE /tasks/:id
  static Future<void> deleteTask(String taskId) async {
    try {
      await _client.from('tasks').delete().eq('id', taskId);
    } catch (e) {
      throw Exception('Failed to delete task: $e');
    }
  }

  static Future<void> archiveTask(String taskId) async {
    try {
      await _client
          .from('tasks')
          .update({
            'archived_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);
    } catch (e) {
      throw Exception('Failed to archive task: $e');
    }
  }

  /// Get all tasks (with optional filters)
  static Future<List<Map<String, dynamic>>> getAllTasks({
    String? departmentId,
    String? status,
    String? priority,
    int? limit,
    int? offset,
  }) async {
    try {
      var filterQuery = _client
          .from('tasks')
          .select(_taskSelectWithProjectAndTags);

      // Apply filters
      if (departmentId != null) {
        filterQuery = filterQuery.eq('department_id', departmentId);
      }
      if (status != null) {
        filterQuery = filterQuery.eq('status', status);
      }
      if (priority != null) {
        filterQuery = filterQuery.eq('priority', priority);
      }

      // Order by created date (returns PostgrestTransformBuilder)
      dynamic transformQuery = filterQuery.order(
        'created_at',
        ascending: false,
      );

      // Apply pagination
      if (limit != null) {
        transformQuery = transformQuery.limit(limit);
      }
      if (offset != null) {
        transformQuery = transformQuery.range(
          offset,
          offset + (limit ?? 10) - 1,
        );
      }

      final response = await transformQuery;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get tasks: $e');
    }
  }

  /// Update assignment status
  static Future<void> updateAssignmentStatus({
    required String taskId,
    required String memberId,
    required String status,
  }) async {
    try {
      // Update the assignment status
      await _client
          .from('task_assignments')
          .update({'status': status})
          .eq('task_id', taskId)
          .eq('member_id', memberId);

      // If the assignment is marked as completed, check if all assignments are completed
      if (status.toLowerCase() == 'completed' ||
          status.toLowerCase() == 'done' ||
          status.toLowerCase() == 'finished') {
        // Get all assignments for this task
        final assignments = await _client
            .from('task_assignments')
            .select('status')
            .eq('task_id', taskId);

        final assignmentsList = List<Map<String, dynamic>>.from(assignments);

        // Check if all assignments are completed
        if (assignmentsList.isNotEmpty) {
          final allCompleted = assignmentsList.every((assignment) {
            final assignmentStatus = (assignment['status'] as String? ?? '')
                .toLowerCase();
            return assignmentStatus == 'completed' ||
                assignmentStatus == 'done' ||
                assignmentStatus == 'finished';
          });

          // If all assignments are completed, update the task status
          if (allCompleted) {
            await _client
                .from('tasks')
                .update({
                  'status': 'completed',
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', taskId);
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to update assignment status: $e');
    }
  }

  /// Remove assignment
  static Future<void> removeAssignment({
    required String taskId,
    required String memberId,
  }) async {
    try {
      await _client
          .from('task_assignments')
          .delete()
          .eq('task_id', taskId)
          .eq('member_id', memberId);
    } catch (e) {
      throw Exception('Failed to remove assignment: $e');
    }
  }

  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }
}
