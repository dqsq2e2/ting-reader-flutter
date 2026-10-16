import 'package:dio/dio.dart';

class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    required this.details,
    required this.status,
    required this.requestId,
  });

  final String? code;
  final String? message;
  final Map<String, dynamic>? details;
  final int? status;
  final String? requestId;

  bool get retryable => details?['retryable'] == true;
  String? get reason => _text(details?['reason']);
  String? get operation => _text(details?['operation']);
  Map<String, dynamic>? get resource => _map(details?['resource']);

  factory ApiError.local({
    required String code,
    required String message,
    required String reason,
    required String operation,
    int? status,
    bool retryable = false,
  }) =>
      ApiError(
        code: code,
        message: message,
        details: {
          'reason': reason,
          'operation': operation,
          'retryable': retryable,
        },
        status: status,
        requestId: null,
      );

  Map<String, dynamic> toJson() => {
        'error': code ?? 'InternalError',
        'message': message ?? 'Request failed',
        'details': details ?? {'retryable': false},
        if (requestId != null) 'trace_id': requestId,
        if (status != null) 'status': status,
      };

  static ApiError capture(Object error, {String fallback = 'Request failed'}) =>
      from(error) ??
      ApiError(
        code: 'InternalError',
        message: messageFor(error, fallback: fallback),
        details: const {'retryable': false},
        status: null,
        requestId: null,
      );

  @override
  String toString() => message ?? code ?? 'Request failed';

  static ApiError? from(Object error) {
    if (error is ApiError) return error;
    final response = error is DioException ? error.response : null;
    final map = _map(response?.data ?? error);
    if (map == null) return null;
    final code = _text(map['error']);
    final message = _text(map['message']);
    if (code == null && message == null) return null;
    return ApiError(
      code: code,
      message: message,
      details: _map(map['details']),
      status: response?.statusCode ??
          (map['status'] is int ? map['status'] as int : null),
      requestId: _text(map['trace_id']),
    );
  }

  static String messageFor(Object error, {String fallback = '请求失败'}) {
    final apiError = from(error);
    final message = apiError?.message?.trim();
    if (message != null && message.isNotEmpty) return message;
    final code = apiError?.code?.trim();
    if (code != null && code.isNotEmpty) return code;
    if (error is DioException) {
      final transportMessage = error.message?.trim();
      if (transportMessage != null && transportMessage.isNotEmpty) {
        return transportMessage;
      }
      return fallback;
    }
    final text = error.toString().replaceFirst('Bad state: ', '').trim();
    if (text.isNotEmpty && !text.startsWith('Instance of \'')) return text;
    return fallback;
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is! Map || value.keys.any((key) => key is! String)) return null;
    return Map<String, dynamic>.from(value);
  }
}
