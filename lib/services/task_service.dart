import 'supabase_service.dart';

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
      await _client.from('task_tags').insert(
            tagIds
                .map((tagId) => {
                      'task_id': taskId,
                      'tag_id': tagId,
                      'created_at': DateTime.now().toIso8601String(),
                    })
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
      // Insert into task_assignments
      await _client.from('task_assignments').insert({
        'task_id': taskId,
        'member_id': memberId,
        'assigned_at': DateTime.now().toIso8601String(),
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create notification for the assignee
      await _client.from('notifications').insert({
        'member_id': memberId,
        'type': 'task_assigned',
        'title': 'New Task Assigned',
        'message': 'You have been assigned a new task',
        'related_id': taskId,
        'related_type': 'task',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to assign task: $e');
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

      // Create notifications for all assignees
      final notifications = (assignments as List)
          .map(
            (assignment) => {
              'member_id': assignment['member_id'],
              'type': 'task_reminder',
              'title': 'Task Reminder',
              'message': customMessage ?? 'You have a pending task',
              'related_id': taskId,
              'related_type': 'task',
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      if (notifications.isNotEmpty) {
        await _client.from('notifications').insert(notifications);
      }
    } catch (e) {
      throw Exception('Failed to send task reminder: $e');
    }
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

  /// Get all tasks (with optional filters)
  static Future<List<Map<String, dynamic>>> getAllTasks({
    String? departmentId,
    String? status,
    String? priority,
    int? limit,
    int? offset,
  }) async {
    try {
      var filterQuery = _client.from('tasks').select(_taskSelectWithProjectAndTags);

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
