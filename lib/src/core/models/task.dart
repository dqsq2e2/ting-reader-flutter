import '_helpers.dart';

class TaskItem {
  const TaskItem({
    required this.id,
    required this.taskType,
    required this.status,
    this.progress,
    this.message,
    this.createdAt,
  });

  final String id;
  final String taskType;
  final String status;
  final double? progress;
  final String? message;
  final String? createdAt;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: readString(json, 'id') ?? '',
      taskType: readString(json, 'task_type') ?? 'task',
      status: readString(json, 'status') ?? '',
      progress: readDouble(json, 'progress'),
      message: readString(json, 'message'),
      createdAt: readString(json, 'created_at'),
    );
  }
}
