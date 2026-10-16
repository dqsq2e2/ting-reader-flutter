import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/api_error.dart';
import '../models/models.dart';

class NotificationState extends ChangeNotifier {
  NotificationState(this.api);
  final ApiClient api;
  final Set<CancelToken> _requests = {};
  CancelToken? _loadToken;
  bool _disposed = false;
  bool loading = true;
  String? error;
  List<NotificationWebhook> webhooks = [];
  List<NotificationEventOption> events = [];

  Future<T> _run<T>(Future<T> Function(CancelToken) operation) async {
    if (_disposed) throw StateError('Notification owner closed');
    final token = CancelToken();
    _requests.add(token);
    try {
      return await operation(token);
    } finally {
      _requests.remove(token);
    }
  }

  Future<void> load() async {
    if (_disposed) return;
    _loadToken?.cancel('Notifications query replaced');
    await _run((token) async {
      _loadToken = token;
      loading = true;
      error = null;
      notifyListeners();
      try {
        final response = await Future.wait([
          api.get('/api/system/notifications', cancelToken: token),
          api.get('/api/system/notifications/events', cancelToken: token),
        ]);
        if (_disposed || token.isCancelled) return;
        webhooks = asMapList(response[0].data)
            .map(NotificationWebhook.fromJson)
            .toList();
        events = asMapList(response[1].data)
            .map(NotificationEventOption.fromJson)
            .toList();
      } catch (failure) {
        if (!_disposed && !token.isCancelled) {
          error = ApiError.messageFor(failure);
        }
      } finally {
        if (!_disposed && identical(_loadToken, token)) {
          loading = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> save(Map<String, dynamic> values, {String? id}) =>
      _run((token) async {
        if (id == null) {
          await api.post('/api/system/notifications',
              data: values, cancelToken: token);
        } else {
          await api.put('/api/system/notifications/${Uri.encodeComponent(id)}',
              data: values, cancelToken: token);
        }
      });

  Future<void> delete(String id) => _run((token) async {
        await api.delete('/api/system/notifications/${Uri.encodeComponent(id)}',
            cancelToken: token);
      });

  Future<WebhookTestResult?> test(Map<String, dynamic> values) =>
      _run((token) async {
        try {
          final response = await api.post('/api/system/notifications/test',
              data: values, cancelToken: token);
          return _disposed
              ? null
              : WebhookTestResult.fromJson(asMap(response.data));
        } catch (failure) {
          return _disposed
              ? null
              : WebhookTestResult(
                  success: false, status: 0, error: ApiError.capture(failure));
        }
      });

  @override
  void dispose() {
    _disposed = true;
    for (final token in _requests) {
      token.cancel('Notification owner closed');
    }
    _requests.clear();
    super.dispose();
  }
}
