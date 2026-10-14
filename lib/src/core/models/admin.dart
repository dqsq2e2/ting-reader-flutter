import '_helpers.dart';

class AdminStatistics {
  const AdminStatistics({
    required this.overview,
    this.libraryBreakdown = const [],
    this.userActivity = const [],
    this.recentActivity = const [],
    this.topBooks = const [],
    this.generatedAt,
  });

  final Map<String, dynamic> overview;
  final List<Map<String, dynamic>> libraryBreakdown;
  final List<Map<String, dynamic>> userActivity;
  final List<Map<String, dynamic>> recentActivity;
  final List<Map<String, dynamic>> topBooks;
  final String? generatedAt;

  factory AdminStatistics.fromJson(Map<String, dynamic> json) {
    return AdminStatistics(
      overview: asMap(json['overview']),
      libraryBreakdown: asMapList(json['library_breakdown']),
      userActivity: asMapList(json['user_activity']),
      recentActivity: asMapList(json['recent_activity']),
      topBooks: asMapList(json['top_books']),
      generatedAt: readString(json, 'generated_at'),
    );
  }
}

class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.module,
    required this.message,
    this.rawMessage,
    this.messageKey,
    this.messageParams = const {},
    this.fields = const {},
    this.taskId,
    this.taskStatus,
    this.taskType,
  });

  final String timestamp;
  final String level;
  final String module;
  final String message;
  final String? rawMessage;
  final String? messageKey;
  final Map<String, dynamic> messageParams;
  final Map<String, dynamic> fields;
  final String? taskId;
  final String? taskStatus;
  final String? taskType;

  bool get isTask => taskId?.isNotEmpty == true;

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: (json['timestamp'] ?? json['created_at'] ?? '').toString(),
      level: (json['level'] ?? 'INFO').toString(),
      module: (json['module'] ?? 'audit').toString(),
      message: (json['message'] ?? '').toString(),
      rawMessage: json['raw_message']?.toString(),
      messageKey: json['message_key']?.toString(),
      messageParams: asMap(json['message_params']),
      fields: asMap(json['fields']),
      taskId: json['task_id']?.toString(),
      taskStatus: json['task_status']?.toString(),
      taskType: json['task_type']?.toString(),
    );
  }
}
