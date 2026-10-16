import '_helpers.dart';
import '../api/api_error.dart';

class TaskItem {
  const TaskItem({
    required this.id,
    required this.taskType,
    required this.status,
    this.progress,
    this.message,
    this.createdAt,
    this.error,
  });

  final String id;
  final String taskType;
  final String status;
  final double? progress;
  final String? message;
  final String? createdAt;
  final ApiError? error;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: readString(json, 'id') ?? '',
      taskType: readString(json, 'task_type') ?? 'task',
      status: readString(json, 'status') ?? '',
      progress: readDouble(json, 'progress'),
      message: readString(json, 'message'),
      createdAt: readString(json, 'created_at'),
      error: json['error'] == null ? null : ApiError.from(json['error']),
    );
  }
}
