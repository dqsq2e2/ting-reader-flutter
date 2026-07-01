import '../models/_helpers.dart' show asMap, asMapList, readInt, readString;
import '../models/plugin.dart'
    show PluginCapabilityRegistration, ToolProviderRegistration;
import 'api_client.dart';

class PluginCapabilitiesApi {
  const PluginCapabilitiesApi(this._api);

  final ApiClient _api;

  Future<List<PluginCapabilityRegistration>> listPluginCapabilities({
    String? kind,
  }) async {
    final res = await _api.get(
      '/api/v1/plugin-capabilities',
      params: _compactParams({'kind': kind}),
    );
    return asMapList(res.data)
        .map(PluginCapabilityRegistration.fromJson)
        .toList();
  }

  Future<List<PluginCapabilityRegistration>> findContentProcessors({
    required String extension,
    String? operation,
  }) async {
    final res = await _api.get(
      '/api/v1/plugin-capabilities/content-processors',
      params: _compactParams({
        'extension': extension,
        'operation': operation,
      }),
    );
    return asMapList(res.data)
        .map(PluginCapabilityRegistration.fromJson)
        .toList();
  }

  Future<List<ToolProviderRegistration>> findToolProviders({
    String? name,
  }) async {
    final res = await _api.get(
      '/api/v1/plugin-capabilities/tools',
      params: _compactParams({'name': name}),
    );
    return asMapList(res.data).map(ToolProviderRegistration.fromJson).toList();
  }

  Future<List<PluginCapabilityRegistration>> findTaskHandlers({
    String? taskType,
  }) async {
    final res = await _api.get(
      '/api/v1/plugin-capabilities/task-handlers',
      params: _compactParams({'task_type': taskType}),
    );
    return asMapList(res.data)
        .map(PluginCapabilityRegistration.fromJson)
        .toList();
  }

  Future<List<PluginCapabilityRegistration>> findEventHandlers({
    String? event,
  }) async {
    final res = await _api.get(
      '/api/v1/plugin-capabilities/event-handlers',
      params: _compactParams({'event': event}),
    );
    return asMapList(res.data)
        .map(PluginCapabilityRegistration.fromJson)
        .toList();
  }

  Future<T> invokePluginCapability<T>({
    required String pluginId,
    required String capabilityId,
    Object? params = const {},
  }) async {
    final res = await _api.post(
      '/api/v1/plugins/${Uri.encodeComponent(pluginId)}/capabilities/'
      '${Uri.encodeComponent(capabilityId)}/invoke',
      data: {'params': params ?? const {}},
    );
    return asMap(res.data)['result'] as T;
  }

  Future<SignedPluginRoute> signPluginRoute({
    required String method,
    required String path,
    int? expiresInSeconds,
    bool? bindCurrentUser,
  }) async {
    final res = await _api.post(
      '/api/v1/plugin-route-signatures',
      data: _compactParams({
        'method': method,
        'path': path,
        'expires_in_seconds': expiresInSeconds,
        'bind_current_user': bindCurrentUser,
      }),
    );
    return SignedPluginRoute.fromJson(asMap(res.data));
  }

  Future<T> invokePluginHost<T>({
    required String pluginId,
    required String method,
    Object? params,
  }) async {
    final res = await _api.post(
      '/api/v1/plugin-host/invoke',
      data: _compactParams({
        'plugin_id': pluginId,
        'method': method,
        'params': params,
      }),
    );
    return asMap(res.data)['result'] as T;
  }

  String pluginAssetUrl({
    required String pluginId,
    required String entry,
  }) {
    final encodedEntry = entry
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return '${_api.baseUrl}/api/v1/plugin-assets/'
        '${Uri.encodeComponent(pluginId)}/$encodedEntry';
  }
}

class SignedPluginRoute {
  const SignedPluginRoute({
    required this.path,
    required this.expires,
    required this.signature,
    this.userId,
    required this.signedUrl,
  });

  final String path;
  final int expires;
  final String signature;
  final String? userId;
  final String signedUrl;

  factory SignedPluginRoute.fromJson(Map<String, dynamic> json) {
    return SignedPluginRoute(
      path: readString(json, 'path') ?? '',
      expires: readInt(json, 'expires') ?? 0,
      signature: readString(json, 'signature') ?? '',
      userId: readString(json, 'user_id'),
      signedUrl: readString(json, 'signed_url') ?? '',
    );
  }
}

Map<String, dynamic> _compactParams(Map<String, Object?> source) {
  return Map<String, dynamic>.from(source)
    ..removeWhere((_, value) => value == null);
}
