import '_helpers.dart';

class PluginItem {
  const PluginItem({
    required this.id,
    required this.name,
    required this.version,
    required this.pluginType,
    required this.state,
    this.author,
    this.description,
    this.descriptionI18n = const {},
    this.longDescription,
    this.runtime,
    this.license,
    this.repo,
    this.minCoreVersion,
    this.minFlutterVersion,
    this.adminOnly = false,
    this.dependencies = const [],
    this.permissions = const [],
    this.capabilities = const [],
    this.supportedExtensions = const [],
    this.configSchema,
  });

  final String id;
  final String name;
  final String version;
  final String pluginType;
  final String state;
  final String? author;
  final String? description;
  final Map<String, String> descriptionI18n;
  final String? longDescription;
  final String? runtime;
  final String? license;
  final String? repo;
  final String? minCoreVersion;
  final String? minFlutterVersion;
  final bool adminOnly;
  final List<String> dependencies;
  final List<String> permissions;
  final List<PluginCapability> capabilities;
  final List<String> supportedExtensions;
  final Map<String, dynamic>? configSchema;

  factory PluginItem.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['config_schema'];
    final capabilities = _capabilityList(json['capabilities']);
    return PluginItem(
      id: readString(json, 'id') ?? '',
      name: readString(json, 'name') ?? 'Plugin',
      version: readString(json, 'version') ?? '',
      pluginType: _pluginCategory(capabilities),
      state: readString(json, 'state') ??
          (readBool(json, 'is_enabled') == false ? 'inactive' : 'active'),
      author: readString(json, 'author'),
      description: readString(json, 'description'),
      descriptionI18n: _localizedTextMap(json['description_i18n']),
      longDescription: readString(json, 'long_description'),
      runtime: readString(json, 'runtime'),
      license: readString(json, 'license'),
      repo: readString(json, 'repo'),
      minCoreVersion: readString(json, 'min_core_version'),
      minFlutterVersion: readString(json, 'min_flutter_version'),
      adminOnly: readBool(json, 'admin_only') ?? false,
      dependencies: _pluginStringList(json['dependencies']),
      permissions: readStringList(json['permissions']),
      capabilities: capabilities,
      supportedExtensions: _capabilitySupportedExtensions(capabilities),
      configSchema: rawConfig is Map
          ? rawConfig.map((key, value) => MapEntry(key.toString(), value))
          : null,
    );
  }
}

class PluginCapability {
  const PluginCapability({
    required this.id,
    required this.kind,
    this.invoke,
    this.extra = const {},
  });

  final String id;
  final String kind;
  final String? invoke;
  final Map<String, dynamic> extra;

  Object? operator [](String key) => extra[key];

  factory PluginCapability.fromJson(Map<String, dynamic> json) {
    final extra = Map<String, dynamic>.from(json)
      ..remove('id')
      ..remove('kind')
      ..remove('invoke');
    return PluginCapability(
      id: readString(json, 'id') ?? '',
      kind: readString(json, 'kind') ?? '',
      invoke: readString(json, 'invoke'),
      extra: Map.unmodifiable(extra),
    );
  }
}

class PluginCapabilityRegistration {
  const PluginCapabilityRegistration({
    required this.pluginId,
    required this.pluginName,
    this.adminOnly = false,
    required this.capability,
  });

  final String pluginId;
  final String pluginName;
  final bool adminOnly;
  final PluginCapability capability;

  factory PluginCapabilityRegistration.fromJson(Map<String, dynamic> json) {
    return PluginCapabilityRegistration(
      pluginId: readString(json, 'plugin_id') ?? '',
      pluginName: readString(json, 'plugin_name') ?? '',
      adminOnly: readBool(json, 'admin_only') ?? false,
      capability: PluginCapability.fromJson(asMap(json['capability'])),
    );
  }
}

class ToolProviderRegistration extends PluginCapabilityRegistration {
  const ToolProviderRegistration({
    required super.pluginId,
    required super.pluginName,
    super.adminOnly = false,
    required super.capability,
    this.tool,
  });

  final Object? tool;

  factory ToolProviderRegistration.fromJson(Map<String, dynamic> json) {
    return ToolProviderRegistration(
      pluginId: readString(json, 'plugin_id') ?? '',
      pluginName: readString(json, 'plugin_name') ?? '',
      adminOnly: readBool(json, 'admin_only') ?? false,
      capability: PluginCapability.fromJson(asMap(json['capability'])),
      tool: json['tool'],
    );
  }
}

Map<String, String> _localizedTextMap(dynamic value) {
  if (value is! Map) return const {};
  return value.map(
    (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
  )..removeWhere((_, value) => value.trim().isEmpty);
}

List<String> _pluginStringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) {
        if (item is Map) {
          return (item['plugin_name'] ?? item['id'] ?? item).toString().trim();
        }
        return item.toString().trim();
      })
      .where((text) => text.isNotEmpty)
      .toList();
}

List<PluginCapability> _capabilityList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map(asMap)
      .where((item) => item.isNotEmpty)
      .map(PluginCapability.fromJson)
      .where((item) => item.id.isNotEmpty && item.kind.isNotEmpty)
      .toList();
}

String _pluginCategory(List<PluginCapability> capabilities) {
  final kinds = capabilities.map((capability) => capability.kind).toSet();
  if (kinds.contains('metadata_provider')) return 'scraper';
  if (kinds.contains('format_handler') || kinds.contains('content_processor')) {
    return 'format';
  }
  return 'utility';
}

List<String> _capabilitySupportedExtensions(
    List<PluginCapability> capabilities) {
  final extensions = <String>[];
  void add(String value) {
    final extension =
        value.trim().replaceFirst(RegExp(r'^\.'), '').toLowerCase();
    if (extension.isNotEmpty && !extensions.contains(extension)) {
      extensions.add(extension);
    }
  }

  for (final capability in capabilities) {
    if (capability.kind == 'format_handler' ||
        capability.kind == 'content_processor') {
      for (final extension in _capabilityExtensions(capability)) {
        add(extension);
      }
    }
  }
  return extensions;
}

List<String> _capabilityExtensions(PluginCapability capability) {
  final matches = capability.extra['matches'];
  final nested = matches is Map ? matches['extensions'] : null;
  final value = capability.extra['extensions'] ?? nested;
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}
