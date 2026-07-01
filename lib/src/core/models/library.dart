import '_helpers.dart';

class Library {
  const Library({
    required this.id,
    required this.name,
    required this.libraryType,
    required this.rootPath,
    this.url,
    this.username,
    this.lastScannedAt,
    this.createdAt,
    this.scraperConfig,
  });

  final String id;
  final String name;
  final String libraryType;
  final String rootPath;
  final String? url;
  final String? username;
  final String? lastScannedAt;
  final String? createdAt;
  final Map<String, dynamic>? scraperConfig;

  factory Library.fromJson(Map<String, dynamic> json) {
    final rawScraper = json['scraper_config'];
    return Library(
      id: readString(json, 'id') ?? '',
      name: readString(json, 'name') ?? '',
      libraryType: readString(json, 'library_type') ?? 'local',
      rootPath: readString(json, 'root_path') ?? '',
      url: readString(json, 'url'),
      username: readString(json, 'username'),
      lastScannedAt: readString(json, 'last_scanned_at'),
      createdAt: readString(json, 'created_at'),
      scraperConfig: rawScraper is Map
          ? rawScraper.map((key, value) => MapEntry(key.toString(), value))
          : null,
    );
  }
}
