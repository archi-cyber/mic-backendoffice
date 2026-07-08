import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class TaskMemberMetric {
  const TaskMemberMetric({
    required this.memberId,
    required this.name,
    required this.value,
    required this.color,
    this.taskCount = 0,
  });

  final String memberId;
  final String name;
  final double value;
  final Color color;
  final int taskCount;
}

class TaskMemberAnalytics {
  TaskMemberAnalytics._();

  static const List<Color> chartPalette = [
    AppColors.primary,
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFFFA726),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF29B6F6),
    Color(0xFF8D6E63),
    Color(0xFF66BB6A),
    Color(0xFFEC407A),
    Color(0xFF7E57C2),
    Color(0xFF26C6DA),
  ];

  static DateTime? _dueDate(Map<String, dynamic> task) {
    final value = task['due_date']?.toString();
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String _memberName(Map<String, dynamic> member) {
    final name = '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'
        .trim();
    return name.isEmpty ? 'Unnamed member' : name;
  }

  static Iterable<({Map<String, dynamic> assignment, Map<String, dynamic> member})>
  _assignments(Map<String, dynamic> task) sync* {
    final rows = task['task_assignments'];
    if (rows is! List) return;
    for (final row in rows) {
      if (row is! Map) continue;
      final member = row['members'];
      if (member is Map) {
        yield (
          assignment: Map<String, dynamic>.from(row),
          member: Map<String, dynamic>.from(member),
        );
      }
    }
  }

  static int? _daysLate(
    Map<String, dynamic> task,
    Map<String, dynamic> assignment,
  ) {
    final dueDate = _dueDate(task);
    if (dueDate == null) return null;

    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final taskStatus = task['status']?.toString();
    final assignmentStatus = assignment['status']?.toString();
    if (taskStatus == 'cancelled' || assignmentStatus == 'cancelled') {
      return null;
    }

    final isDone =
        taskStatus == 'completed' || assignmentStatus == 'completed';
    if (isDone) {
      final doneAt = DateTime.tryParse(task['updated_at']?.toString() ?? '');
      if (doneAt == null) return null;
      final doneDay = DateTime(doneAt.year, doneAt.month, doneAt.day);
      final lateDays = doneDay.difference(dueDay).inDays;
      return lateDays > 0 ? lateDays : 0;
    }

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    if (todayDay.isAfter(dueDay)) {
      return todayDay.difference(dueDay).inDays;
    }
    return 0;
  }

  static bool _isActiveAssignment(
    Map<String, dynamic> task,
    Map<String, dynamic> assignment,
  ) {
    final taskStatus = task['status']?.toString();
    final assignmentStatus = assignment['status']?.toString();
    if (taskStatus == 'completed' || taskStatus == 'cancelled') return false;
    if (assignmentStatus == 'completed' || assignmentStatus == 'cancelled') {
      return false;
    }
    return true;
  }

  static int _priorityWeight(Map<String, dynamic> task) {
    switch (task['priority']?.toString()) {
      case 'urgent':
        return 4;
      case 'high':
        return 3;
      case 'low':
        return 1;
      default:
        return 2;
    }
  }

  static List<TaskMemberMetric> averageLatenessPerMember(
    List<Map<String, dynamic>> tasks,
  ) {
    final totals = <String, double>{};
    final counts = <String, int>{};
    final names = <String, String>{};

    for (final task in tasks) {
      for (final row in _assignments(task)) {
        final memberId = row.member['id']?.toString();
        if (memberId == null) continue;
        final lateDays = _daysLate(task, row.assignment);
        if (lateDays == null) continue;

        names[memberId] = _memberName(row.member);
        totals[memberId] = (totals[memberId] ?? 0) + lateDays;
        counts[memberId] = (counts[memberId] ?? 0) + 1;
      }
    }

    final metrics = <TaskMemberMetric>[];
    var colorIndex = 0;
    for (final entry in totals.entries) {
      final count = counts[entry.key] ?? 0;
      if (count == 0) continue;
      metrics.add(
        TaskMemberMetric(
          memberId: entry.key,
          name: names[entry.key] ?? '—',
          value: entry.value / count,
          color: chartPalette[colorIndex % chartPalette.length],
          taskCount: count,
        ),
      );
      colorIndex++;
    }

    metrics.sort((a, b) => b.value.compareTo(a.value));
    return metrics;
  }

  static List<TaskMemberMetric> workloadPerMember(
    List<Map<String, dynamic>> tasks,
  ) {
    final counts = <String, double>{};
    final taskCounts = <String, int>{};
    final names = <String, String>{};

    for (final task in tasks) {
      for (final row in _assignments(task)) {
        if (!_isActiveAssignment(task, row.assignment)) continue;
        final memberId = row.member['id']?.toString();
        if (memberId == null) continue;

        names[memberId] = _memberName(row.member);
        final weight = _priorityWeight(task).toDouble();
        counts[memberId] = (counts[memberId] ?? 0) + weight;
        taskCounts[memberId] = (taskCounts[memberId] ?? 0) + 1;
      }
    }

    final metrics = <TaskMemberMetric>[];
    var colorIndex = 0;
    for (final entry in counts.entries) {
      metrics.add(
        TaskMemberMetric(
          memberId: entry.key,
          name: names[entry.key] ?? '—',
          value: entry.value,
          color: chartPalette[colorIndex % chartPalette.length],
          taskCount: taskCounts[entry.key] ?? 0,
        ),
      );
      colorIndex++;
    }

    metrics.sort((a, b) => b.value.compareTo(a.value));
    return metrics;
  }

  static String? departmentLabel(List<Map<String, dynamic>> tasks) {
    for (final task in tasks) {
      final dept = task['departments'];
      if (dept is Map) {
        final name = dept['name']?.toString();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return null;
  }
}
