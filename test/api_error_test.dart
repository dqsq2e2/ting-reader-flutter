import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/src/core/api/api_error.dart';
import 'package:ting_reader_flutter/src/core/models/plugin.dart';
import 'package:ting_reader_flutter/src/core/models/task.dart';
import 'package:ting_reader_flutter/src/core/models/notification.dart';

void main() {
  DioException responseError(Object data, {int status = 400}) {
    return DioException(
      requestOptions: RequestOptions(path: '/api/test'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/test'),
        statusCode: status,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );
  }

  test('reads the compatible REST error envelope', () {
    final error = ApiError.from(responseError({
      'error': 'permission_denied',
      'message': '没有权限',
      'details': {
        'reason': 'missing_capability',
        'retryable': false,
      },
      'trace_id': 'trace-1',
    }));

    expect(error?.code, 'permission_denied');
    expect(error?.message, '没有权限');
    expect(error?.reason, 'missing_capability');
    expect(error?.retryable, isFalse);
    expect(error?.requestId, 'trace-1');
  });

  test('falls back from message to error code', () {
    expect(
      ApiError.messageFor(
        responseError({'error': 'request_failed'}),
      ),
      'request_failed',
    );
  });

  test('uses the transport error when the response has no message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/test'),
      type: DioExceptionType.connectionError,
      message: '连接服务器失败',
    );
    expect(ApiError.messageFor(error), '连接服务器失败');
  });

  test('uses a readable fallback for non REST errors', () {
    expect(ApiError.messageFor(StateError('本地状态错误')), '本地状态错误');
    expect(ApiError.messageFor(Object(), fallback: '未知错误'), '未知错误');
  });

  test('preserves operation resource retryability and trace information', () {
    final error = ApiError.from(responseError({
      'error': 'PluginExecutionError',
      'message': ' 插件暂时不可用 ',
      'details': {
        'reason': 'plugin_unavailable',
        'operation': 'search',
        'resource': {'kind': 'plugin', 'id': 'example@1.0.0'},
        'retryable': true,
      },
      'trace_id': 'trace-2',
    }, status: 503));
    expect(error?.operation, 'search');
    expect(error?.resource?['id'], 'example@1.0.0');
    expect(error?.retryable, isTrue);
    expect(error?.requestId, 'trace-2');
    expect(error?.status, 503);
    expect(ApiError.messageFor(error!), '插件暂时不可用');
  });

  test('malformed bodies never cause a second error during error handling', () {
    for (final data in [
      'gateway login page',
      <Object?>[],
      {1: 'not a string key'},
      {'error': <String, Object?>{}, 'message': 123},
    ]) {
      final error = responseError(data);
      expect(ApiError.from(error), isNull);
      expect(ApiError.messageFor(error, fallback: '请求失败'), '请求失败');
    }
    final error = ApiError.from(responseError({
      'message': '有效错误信息',
      'details': {
        'reason': [],
        'operation': false,
        'resource': {1: 'invalid key'},
        'retryable': 'false',
      },
    }));
    expect(error?.reason, isNull);
    expect(error?.operation, isNull);
    expect(error?.resource, isNull);
    expect(error?.retryable, isFalse);
  });

  test('bridge failures preserve metadata and local policy errors are typed',
      () {
    final failure = ApiError.capture(responseError({
      'error': 'PluginExecutionError',
      'message': 'Provider unavailable',
      'details': {
        'reason': 'plugin_unavailable',
        'operation': 'search',
        'retryable': true,
      },
      'trace_id': 'trace-bridge',
    }, status: 503));
    final payload = failure.toJson();
    expect(payload['error'], 'PluginExecutionError');
    expect(payload['status'], 503);
    expect(payload['trace_id'], 'trace-bridge');
    expect(payload['details']['retryable'], isTrue);
    final restored = ApiError.from(payload);
    expect(restored?.code, failure.code);
    expect(restored?.status, failure.status);
    expect(restored?.requestId, failure.requestId);
    expect(restored?.retryable, isTrue);
    final denied = ApiError.local(
      code: 'PermissionDenied',
      message: 'Host method is not allowed for this view',
      reason: 'capability_denied',
      operation: 'host.invoke',
      status: 403,
    );
    expect(ApiError.from(denied), same(denied));
    expect(denied.toString(), denied.message);
    expect(denied.reason, 'capability_denied');
    expect(denied.retryable, isFalse);
  });

  test('plugin task and webhook results retain the same structured failure',
      () {
    final failure = {
      'error': 'Timeout',
      'message': 'Provider timed out',
      'details': {
        'reason': 'elapsed',
        'operation': 'task.execute',
        'retryable': true
      },
      'trace_id': 'stored-trace',
    };
    final plugin = PluginItem.fromJson(
        {'id': 'plugin', 'state': 'failed', 'error': failure});
    final task =
        TaskItem.fromJson({'id': 'task', 'status': 'failed', 'error': failure});
    final webhook = WebhookTestResult.fromJson(
        {'success': false, 'status': 0, 'error': failure});
    for (final error in [plugin.error, task.error, webhook.error]) {
      expect(error?.message, 'Provider timed out');
      expect(error?.code, 'Timeout');
      expect(error?.retryable, isTrue);
      expect(error?.requestId, 'stored-trace');
    }
  });
}
