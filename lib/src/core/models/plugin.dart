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
    this.longDescription,
    this.runtime,
    this.license,
    this.repo,
    this.dependencies = const [],
    this.permissions = const [],
    this.supportedExtensions = const [],
    this.configSchema,
    this.scraper,
  });

  final String id;
  final String name;
  final String version;
  final String pluginType;
  final String state;
  final String? author;
  final String? description;
  final String? longDescription;
  final String? runtime;
  final String? license;
  final String? repo;
  final List<String> dependencies;
  final List<String> permissions;
  final List<String> supportedExtensions;
  final Map<String, dynamic>? configSchema;
  final PluginScraperInfo? scraper;

  factory PluginItem.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['config_schema'] ?? json['configSchema'];
    final rawScraper = json['scraper'];
    return PluginItem(
      id: readString(json, 'id') ?? '',
      name: readString(json, 'name') ?? 'Plugin',
      version: readString(json, 'version') ?? '',
      pluginType: readString(json, 'plugin_type', 'pluginType') ?? '',
      state: readString(json, 'state') ??
          (readBool(json, 'is_enabled', 'isEnabled') == false
              ? 'inactive'
              : 'active'),
      author: readString(json, 'author'),
      description: readString(json, 'description'),
      longDescription: readString(json, 'long_description', 'longDescription'),
      runtime: readString(json, 'runtime'),
      license: readString(json, 'license'),
      repo: readString(json, 'repo'),
      dependencies: _pluginStringList(json['dependencies']),
      permissions: readStringList(json['permissions']),
      supportedExtensions: readStringList(
          json['supported_extensions'] ?? json['supportedExtensions']),
      configSchema: rawConfig is Map
          ? rawConfig.map((key, value) => MapEntry(key.toString(), value))
          : null,
      scraper: rawScraper is Map
          ? PluginScraperInfo.fromJson(
              rawScraper.map((key, value) => MapEntry(key.toString(), value)),
            )
          : null,
    );
  }
}

class PluginScraperInfo {
  const PluginScraperInfo({
    this.autoScrape = false,
    this.searchFields = const [],
    this.resultFields = const [],
  });

  final bool autoScrape;
  final List<String> searchFields;
  final List<String> resultFields;

  factory PluginScraperInfo.fromJson(Map<String, dynamic> json) {
    return PluginScraperInfo(
      autoScrape: readBool(json, 'autoScrape', 'auto_scrape') ?? false,
      searchFields:
          _scraperFieldNames(json['searchFields'] ?? json['search_fields']),
      resultFields:
          readStringList(json['resultFields'] ?? json['result_fields']),
    );
  }
}

List<String> _scraperFieldNames(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) {
        if (item is Map) {
          return (item['label'] ?? item['key'] ?? item['name'] ?? item)
              .toString()
              .trim();
        }
        return item.toString().trim();
      })
      .where((text) => text.isNotEmpty)
      .toList();
}

List<String> _pluginStringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) {
        if (item is Map) {
          return (item['plugin_name'] ??
                  item['pluginName'] ??
                  item['id'] ??
                  item)
              .toString()
              .trim();
        }
        return item.toString().trim();
      })
      .where((text) => text.isNotEmpty)
      .toList();
}
