import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'class_service.dart';
import 'task_service.dart';

/// Service for offline queueing of operations
class OfflineQueueService {
  static const String _queueKey = 'offline_queue';

  /// Check if device is online
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Add operation to queue
  static Future<void> queueOperation({
    required String type, // 'attendance', 'task', etc.
    required Map<String, dynamic> data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(
      jsonDecode(queueJson) as List,
    );

    queue.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'data': data,
      'created_at': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  /// Get all queued operations
  static Future<List<Map<String, dynamic>>> getQueuedOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey) ?? '[]';
    return List<Map<String, dynamic>>.from(jsonDecode(queueJson) as List);
  }

  /// Remove operation from queue
  static Future<void> removeOperation(String operationId) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey) ?? '[]';
    final queue = List<Map<String, dynamic>>.from(
      jsonDecode(queueJson) as List,
    );

    queue.removeWhere((op) => op['id'] == operationId);
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  /// Clear all queued operations
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  /// Process queued operations when online
  static Future<void> processQueue() async {
    final isOnline = await OfflineQueueService.isOnline();
    if (!isOnline) return;

    final queue = await getQueuedOperations();
    if (queue.isEmpty) return;

    // Process each operation
    for (final operation in queue) {
      try {
        await _processOperation(operation);
        await removeOperation(operation['id']);
      } catch (e) {
        // Log error but continue processing other operations
        debugPrint('Error processing operation ${operation['id']}: $e');
      }
    }
  }

  /// Process a single operation
  static Future<void> _processOperation(Map<String, dynamic> operation) async {
    final type = operation['type'] as String;
    final data = operation['data'] as Map<String, dynamic>;

    switch (type) {
      case 'attendance':
        // Call attendance service
        await ClassService.recordAttendance(
          sessionId: data['session_id'],
          attendanceRecords: data['records'],
        );
        break;
      case 'task':
        // Call task service
        await TaskService.assignTask(
          taskId: data['task_id'],
          memberId: data['member_id'],
        );
        break;
      // Add more operation types as needed
    }
  }

  /// Listen to connectivity changes and process queue
  static Stream<ConnectivityResult> connectivityStream() {
    return Connectivity().onConnectivityChanged;
  }
}
