import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/models.dart';

/// Owns filtered system/plugin log requests and their refresh timer.
/// A new query cancels the previous one; periodic refresh never overlaps it.
class LogState extends ChangeNotifier {
  LogState(this.api, {this.pluginId});

  final ApiClient api;
  final String? pluginId;
  Timer? _timer;
  CancelToken? _request;
  final Set<CancelToken> _actions = {};
  bool _disposed = false;
  int _revision = 0;
  bool loading = true;
  bool autoRefresh = true;
  String module = 'audit';
  String level = '';
  String plugin = '';
  String source = '';
  String search = '';
  int page = 1;
  int total = 0;
  String? error;
  List<LogEntry> logs = [];
  List<PluginItem> plugins = [];

  static const pageSize = 100;
  int get pageCount => (total / pageSize).ceil().clamp(1, 1 << 20);
  bool get _pluginLogs => pluginId != null || module == 'plugins';
  String get _endpoint {
    final id = pluginId;
    if (id != null) return '/api/v1/plugins/${Uri.encodeComponent(id)}/logs';
    return _pluginLogs ? '/api/v1/plugin-logs' : '/api/system/logs';
  }

  Map<String, dynamic> _query({bool paging = true, String? exportLevel}) => {
        if (paging) 'page': page,
        if (paging) 'page_size': pageSize,
        if ((exportLevel ?? level).isNotEmpty) 'level': exportLevel ?? level,
        if (!_pluginLogs && module.isNotEmpty) 'module': module,
        if (_pluginLogs && pluginId == null && plugin.isNotEmpty)
          'plugin_id': plugin,
        if (_pluginLogs && source.isNotEmpty) 'source': source,
        if (_pluginLogs && search.trim().isNotEmpty) 'q': search.trim(),
      };

  void start() {
    if (_disposed) return;
    _syncTimer();
    unawaited(load());
  }

  void setAutoRefresh(bool value) {
    if (_disposed) return;
    autoRefresh = value;
    _syncTimer();
    notifyListeners();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = autoRefresh
        ? Timer.periodic(const Duration(seconds: 3), (_) {
            if (_request == null) unawaited(load(silent: true));
          })
        : null;
  }

  Future<void> load({bool silent = false}) async {
    if (_disposed) return;
    _request?.cancel('Log query changed');
    final token = CancelToken();
    _request = token;
    final revision = ++_revision;
    final endpoint = _endpoint;
    final query = _query();
    if (!silent) loading = true;
    notifyListeners();
    try {
      if (_pluginLogs && pluginId == null && plugins.isEmpty) {
        try {
          final response = await api.get('/api/v1/plugins', cancelToken: token);
          if (!_disposed && revision == _revision) {
            plugins = asMapList(response.data)
                .map(PluginItem.fromJson)
                .where((item) => item.id.isNotEmpty)
                .toList();
          }
        } catch (_) {
          if (token.isCancelled) return;
          // Logs are still useful when the catalogue is temporarily unavailable.
        }
      }
      final response =
          await api.get(endpoint, params: query, cancelToken: token);
      if (_disposed || revision != _revision) return;
      final data = asMap(response.data);
      logs = asMapList(data['logs']).map(LogEntry.fromJson).toList();
      total = (data['total'] as num?)?.toInt() ?? logs.length;
      error = null;
    } catch (failure) {
      if (!_disposed && revision == _revision && !token.isCancelled) {
        error = failure.toString();
      }
    } finally {
      if (!_disposed && revision == _revision) {
        _request = null;
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<T> _action<T>(Future<T> Function(CancelToken) run) async {
    if (_disposed) throw StateError('Log state disposed');
    final token = CancelToken();
    _actions.add(token);
    try {
      return await run(token);
    } finally {
      _actions.remove(token);
    }
  }

  Future<String> export({String? level}) => _action((token) async {
        final response = await api.get('$_endpoint/export',
            params: _query(paging: false, exportLevel: level),
            cancelToken: token);
        return response.data?.toString() ?? '';
      });

  Future<void> clear() async {
    await _action((token) => Future.wait([
          api.delete('/api/tasks', cancelToken: token),
          api.delete('/api/system/logs', cancelToken: token),
        ]));
    await load();
  }

  Future<void> cancelTask(String id) async {
    await _action((token) => api.post(
        '/api/tasks/${Uri.encodeComponent(id)}/cancel',
        cancelToken: token));
    await load();
  }

  Future<void> deleteTask(String id) async {
    await _action((token) => api.delete('/api/tasks/${Uri.encodeComponent(id)}',
        cancelToken: token));
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    _request?.cancel('Log page disposed');
    for (final token in _actions) {
      token.cancel('Log page disposed');
    }
    _actions.clear();
    super.dispose();
  }
}
