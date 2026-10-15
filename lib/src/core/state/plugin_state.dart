import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/models.dart';

/// Owns plugin catalogue loading and package confirmation retries.
/// Dialogs are supplied by the page; neither contexts nor widgets are retained.
class PluginState extends ChangeNotifier {
  PluginState(this.api);
  final ApiClient api;
  final Set<CancelToken> _requests = {};
  CancelToken? _installedRequest;
  CancelToken? _storeRequest;
  bool _disposed = false;
  int _installedRevision = 0;
  int _storeRevision = 0;
  List<PluginItem> installed = [];
  List<PluginItem> store = [];
  bool installedLoading = true;
  bool storeLoading = false;
  String? error;

  bool get hasStore => installed.any((plugin) => plugin.capabilities
      .any((capability) => capability.kind == 'plugin_store'));

  String? installedVersion(String id) {
    final exact = installed.where((plugin) => plugin.id == id).firstOrNull;
    return exact?.version ??
        installed
            .where((plugin) => basePluginId(plugin.id) == basePluginId(id))
            .firstOrNull
            ?.version;
  }

  PluginItem? storePlugin(String id) =>
      store.where((plugin) => plugin.id == id).firstOrNull ??
      store
          .where((plugin) => basePluginId(plugin.id) == basePluginId(id))
          .firstOrNull;

  bool hasUpdate(PluginItem plugin) {
    final version = installedVersion(plugin.id);
    return version != null &&
        comparePluginVersions(plugin.version, version) > 0;
  }

  /// Resolve transitive dependencies once, in installation order.
  /// Already installed plugins do not require another installation.
  List<PluginItem> installationPlan(PluginItem target) {
    final result = <PluginItem>[];
    final visiting = <String>{};
    final visited = <String>{};
    void visit(PluginItem item) {
      final key = basePluginId(item.id);
      if (visited.contains(key)) return;
      if (!visiting.add(key)) {
        throw StateError('Cyclic plugin dependency: ${item.id}');
      }
      for (final id in item.dependencies) {
        if (installedVersion(id) != null) continue;
        final dependency = storePlugin(id);
        if (dependency == null) {
          throw StateError('Plugin dependency unavailable: $id');
        }
        visit(dependency);
      }
      visiting.remove(key);
      visited.add(key);
      result.add(item);
    }

    visit(target);
    return result;
  }

  Future<bool> install(
    PluginItem target, {
    required Future<bool> Function(PluginItem) checkClientVersion,
    required Future<bool> Function(List<PluginItem>) confirmDependencies,
    required Future<bool> Function(UnverifiedPluginConfirmation) confirmPackage,
    required void Function(String?) onInstalling,
  }) async {
    if (_disposed) return false;
    final plan = installationPlan(target);
    for (final item in plan) {
      if (_disposed || !await checkClientVersion(item) || _disposed) {
        return false;
      }
    }
    final dependencies = plan.take(plan.length - 1).toList();
    if (dependencies.isNotEmpty &&
        (!await confirmDependencies(dependencies) || _disposed)) {
      return false;
    }
    try {
      for (final item in plan) {
        if (_disposed) return false;
        onInstalling(item.id);
        if (!await installStore(item.id, item.name, confirmPackage)) {
          return false;
        }
      }
      return true;
    } finally {
      if (!_disposed) {
        onInstalling(null);
        await refresh();
      }
    }
  }

  Future<void> loadInstalled() async {
    if (_disposed) return;
    _installedRequest?.cancel('Plugin catalogue replaced');
    final revision = ++_installedRevision;
    final token = CancelToken();
    _installedRequest = token;
    _requests.add(token);
    installedLoading = true;
    error = null;
    notifyListeners();
    try {
      final response = await api.get('/api/v1/plugins', cancelToken: token);
      if (_disposed || revision != _installedRevision) return;
      installed = asMapList(response.data).map(PluginItem.fromJson).toList();
      if (!hasStore) {
        _storeRevision++;
        _storeRequest?.cancel('Plugin store unavailable');
        store = [];
        storeLoading = false;
      }
    } catch (failure) {
      if (!_disposed && revision == _installedRevision && !token.isCancelled) {
        error = failure.toString();
      }
    } finally {
      _requests.remove(token);
      if (!_disposed && revision == _installedRevision) {
        _installedRequest = null;
        installedLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadStore({bool refresh = false}) async {
    if (_disposed || !hasStore) return;
    _storeRequest?.cancel('Plugin store query replaced');
    final revision = ++_storeRevision;
    final token = CancelToken();
    _storeRequest = token;
    _requests.add(token);
    storeLoading = true;
    error = null;
    notifyListeners();
    try {
      if (refresh) {
        await api.post('/api/v1/store/cache/clear', cancelToken: token);
      }
      final response = await api.get('/api/v1/store/plugins',
          params: refresh ? {'refresh': 'true'} : null, cancelToken: token);
      if (!_disposed && revision == _storeRevision && hasStore) {
        store = asMapList(response.data).map(PluginItem.fromJson).toList();
      }
    } catch (failure) {
      if (!_disposed && revision == _storeRevision && !token.isCancelled) {
        error = failure.toString();
      }
    } finally {
      _requests.remove(token);
      if (!_disposed && revision == _storeRevision) {
        _storeRequest = null;
        storeLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> installStore(String id, String name,
          Future<bool> Function(UnverifiedPluginConfirmation) confirm) =>
      installWithConfirmation((digest, token) async {
        await api.post('/api/v1/store/install', cancelToken: token, data: {
          'plugin_id': id,
          if (digest != null) 'accept_unverified': true,
          if (digest != null) 'confirmed_package_sha256': digest,
        });
      }, name, confirm);

  Future<void> refresh({bool refreshStore = false}) async {
    if (_disposed) return;
    await loadInstalled();
    if (!_disposed && hasStore) await loadStore(refresh: refreshStore);
  }

  Future<bool> _mutate(
      Future<void> Function(CancelToken token) operation) async {
    if (_disposed) return false;
    final token = CancelToken();
    _requests.add(token);
    try {
      await operation(token);
      if (_disposed || token.isCancelled) return false;
      await refresh();
      return !_disposed && !token.isCancelled;
    } finally {
      _requests.remove(token);
    }
  }

  Future<bool> reload(String id) => _mutate((token) async {
        await api.post('/api/v1/plugins/${Uri.encodeComponent(id)}/reload',
            cancelToken: token);
      });

  Future<bool> uninstall(String id) => _mutate((token) async {
        await api.delete('/api/v1/plugins/${Uri.encodeComponent(id)}',
            cancelToken: token);
      });

  Future<bool> installPackage({
    required String name,
    String? path,
    Uint8List? bytes,
    required Future<bool> Function(UnverifiedPluginConfirmation) confirm,
  }) async {
    if (_disposed) return false;
    if (path == null && bytes == null) {
      throw StateError('Missing plugin package');
    }
    final installed = await installWithConfirmation((digest, token) async {
      final MultipartFile file;
      if (path != null) {
        file = await MultipartFile.fromFile(path, filename: name);
      } else if (bytes != null) {
        file = MultipartFile.fromBytes(bytes, filename: name);
      } else {
        throw StateError('Missing plugin package');
      }
      if (_disposed || token.isCancelled) {
        throw StateError('Plugin install cancelled');
      }
      await api.post('/api/v1/plugins/install',
          cancelToken: token,
          data: FormData.fromMap({
            'file': file,
            if (digest != null) 'accept_unverified': 'true',
            if (digest != null) 'confirmed_package_sha256': digest,
          }));
    }, name, confirm);
    if (installed) await refresh();
    return installed && !_disposed;
  }

  Future<bool> installWithConfirmation(
    Future<void> Function(String? digest, CancelToken token) install,
    String name,
    Future<bool> Function(UnverifiedPluginConfirmation) confirm,
  ) async {
    String? digest;
    final token = CancelToken();
    _requests.add(token);
    try {
      while (!_disposed) {
        try {
          await install(digest, token);
          return !_disposed;
        } on DioException catch (failure) {
          final data = failure.response?.data;
          if (failure.response?.statusCode != 428 ||
              data is! Map ||
              data['requires_confirmation'] != true) {
            rethrow;
          }
          final confirmation = UnverifiedPluginConfirmation.fromJson(
            Map<String, dynamic>.from(data),
            fallbackName: name,
          );
          if (_disposed || !await confirm(confirmation) || _disposed) {
            return false;
          }
          if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(confirmation.digest)) {
            throw StateError('Server did not provide a package digest');
          }
          if (digest == confirmation.digest) {
            throw StateError('Server rejected the confirmed plugin package');
          }
          digest = confirmation.digest;
        }
      }
      return false;
    } finally {
      _requests.remove(token);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _installedRevision++;
    _storeRevision++;
    for (final token in _requests) {
      if (!token.isCancelled) token.cancel('Plugin page disposed');
    }
    _requests.clear();
    super.dispose();
  }
}

String basePluginId(String id) => id.split('@').first;

/// Plugin configuration owns requests and schema coercion. Text controllers
/// remain in the form because their focus and selection are presentation state.
class PluginConfigurationState extends ChangeNotifier {
  PluginConfigurationState(this.api, this.plugin);
  final ApiClient api;
  final PluginItem plugin;
  final Set<CancelToken> _requests = {};
  bool _disposed = false;
  bool loading = true;
  bool saving = false;
  String? error;
  Map<String, dynamic> config = {};
  static const secretPlaceholder = '__TING_READER_SECRET_UNCHANGED__';

  Map<String, Map<String, dynamic>> get properties {
    final raw = plugin.configSchema?['properties'];
    if (raw is! Map) return const {};
    return raw.map((key, value) => MapEntry(key.toString(), asMap(value)));
  }

  String get _endpoint =>
      '/api/v1/plugins/${Uri.encodeComponent(plugin.id)}/config';

  Future<void> load() async {
    if (_disposed) return;
    final token = CancelToken();
    _requests.add(token);
    try {
      final response = await api.get(_endpoint, cancelToken: token);
      if (!_disposed) {
        config = asMap(asMap(response.data)['config']);
        error = null;
      }
    } catch (failure) {
      if (!_disposed && !token.isCancelled) error = failure.toString();
    } finally {
      _requests.remove(token);
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(Map<String, dynamic> values) async {
    if (_disposed || saving) return false;
    final token = CancelToken();
    _requests.add(token);
    saving = true;
    error = null;
    notifyListeners();
    try {
      await api.put(_endpoint, data: {'config': values}, cancelToken: token);
      return !_disposed;
    } catch (failure) {
      if (!_disposed && !token.isCancelled) error = failure.toString();
      return false;
    } finally {
      _requests.remove(token);
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  void setValue(String key, Object? value) {
    if (_disposed) return;
    config = {...config, key: value};
    notifyListeners();
  }

  Object? valueFor(String key, Map<String, dynamic> property) =>
      config.containsKey(key) ? config[key] : property['default'];

  Map<String, dynamic> readForm(Map<String, String> texts) {
    final result = Map<String, dynamic>.from(config);
    for (final entry in properties.entries) {
      final property = entry.value;
      final type = pluginSchemaType(property);
      if (pluginSchemaEnum(property).isNotEmpty || type == 'boolean') {
        final value = valueFor(entry.key, property);
        final choices = property['enum'];
        result[entry.key] = choices is List
            ? choices
                    .where((choice) => choice.toString() == value?.toString())
                    .firstOrNull ??
                value
            : value;
        continue;
      }
      final text = (texts[entry.key] ?? '').trim();
      Object? value;
      if (isEncryptedPluginField(property) && text.isEmpty) {
        value = secretPlaceholder;
      } else if (type == 'integer') {
        value = text.isEmpty ? null : int.parse(text);
      } else if (type == 'number') {
        value = text.isEmpty ? null : num.parse(text);
        if (value is num && !value.isFinite) {
          throw FormatException('Invalid number: ${entry.key}');
        }
      } else if (type == 'array' || type == 'object') {
        value = text.isEmpty
            ? (type == 'array' ? <dynamic>[] : <String, dynamic>{})
            : jsonDecode(text);
        if (type == 'array' ? value is! List : value is! Map) {
          throw FormatException('${entry.key} must contain a JSON $type');
        }
      } else {
        value = text;
      }
      result[entry.key] = value;
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final token in _requests) {
      token.cancel('Plugin configuration closed');
    }
    _requests.clear();
    super.dispose();
  }
}

String pluginSchemaType(Map<String, dynamic> property) {
  final type = property['type'];
  return type is String && type.trim().isNotEmpty ? type.trim() : 'string';
}

List<String> pluginSchemaEnum(Map<String, dynamic> property) {
  final values = property['enum'];
  return values is List
      ? values.map((value) => value.toString()).toList()
      : const [];
}

bool isEncryptedPluginField(Map<String, dynamic> property) =>
    property['x-encrypted'] == true ||
    property['encrypted'] == true ||
    property['format'] == 'password' ||
    property['format'] == 'secret';

String pluginEditorText(Object? value, Map<String, dynamic> property) {
  if (value == null ||
      isEncryptedPluginField(property) &&
          value == PluginConfigurationState.secretPlaceholder) {
    return '';
  }
  final type = pluginSchemaType(property);
  return type == 'array' || type == 'object'
      ? const JsonEncoder.withIndent('  ').convert(value)
      : value.toString();
}

int comparePluginVersions(String left, String right) {
  List<int> parts(String version) => version
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final a = parts(left);
  final b = parts(right);
  for (var index = 0;
      index < (a.length > b.length ? a.length : b.length);
      index++) {
    final difference =
        (index < a.length ? a[index] : 0) - (index < b.length ? b[index] : 0);
    if (difference != 0) return difference;
  }
  return 0;
}
