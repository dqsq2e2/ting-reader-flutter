import 'dart:convert';

String? _string(Map<String, dynamic> json, String snake, [String? camel]) {
  final value = json[snake] ?? (camel == null ? null : json[camel]);
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _int(Map<String, dynamic> json, String snake, [String? camel]) {
  final value = json[snake] ?? (camel == null ? null : json[camel]);
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _double(Map<String, dynamic> json, String snake, [String? camel]) {
  final value = json[snake] ?? (camel == null ? null : json[camel]);
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool? _bool(Map<String, dynamic> json, String snake, [String? camel]) {
  final value = json[snake] ?? (camel == null ? null : json[camel]);
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value.toString() == 'true';
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }
  return const [];
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) return const [];
  return value.map(asMap).toList();
}

class User {
  const User({
    required this.id,
    required this.username,
    required this.role,
    this.createdAt,
    this.librariesAccessible = const [],
    this.booksAccessible = const [],
  });

  final String id;
  final String username;
  final String role;
  final String? createdAt;
  final List<String> librariesAccessible;
  final List<String> booksAccessible;

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _string(json, 'id') ?? '',
      username: _string(json, 'username') ?? '',
      role: _string(json, 'role') ?? 'user',
      createdAt: _string(json, 'created_at', 'createdAt'),
      librariesAccessible: _stringList(
          json['libraries_accessible'] ?? json['librariesAccessible']),
      booksAccessible:
          _stringList(json['books_accessible'] ?? json['booksAccessible']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'role': role,
        if (createdAt != null) 'created_at': createdAt,
        'libraries_accessible': librariesAccessible,
        'books_accessible': booksAccessible,
      };

  String encode() => jsonEncode(toJson());
}

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
    final rawScraper = json['scraper_config'] ?? json['scraperConfig'];
    return Library(
      id: _string(json, 'id') ?? '',
      name: _string(json, 'name') ?? '未命名媒体库',
      libraryType: _string(json, 'library_type', 'libraryType') ?? 'local',
      rootPath: _string(json, 'root_path', 'rootPath') ?? '',
      url: _string(json, 'url'),
      username: _string(json, 'username'),
      lastScannedAt: _string(json, 'last_scanned_at', 'lastScannedAt'),
      createdAt: _string(json, 'created_at', 'createdAt'),
      scraperConfig: rawScraper is Map
          ? rawScraper.map((key, value) => MapEntry(key.toString(), value))
          : null,
    );
  }
}

class Book {
  const Book({
    required this.id,
    required this.libraryId,
    required this.title,
    this.author,
    this.narrator,
    this.description,
    this.coverUrl,
    this.themeColor,
    this.duration,
    this.size,
    this.path,
    this.hash,
    this.createdAt,
    this.updatedAt,
    this.isFavorite = false,
    this.libraryType,
    this.skipIntro = 0,
    this.skipOutro = 0,
    this.tags,
    this.genre,
    this.year,
    this.chapterRegex,
  });

  final String id;
  final String libraryId;
  final String title;
  final String? author;
  final String? narrator;
  final String? description;
  final String? coverUrl;
  final String? themeColor;
  final int? duration;
  final int? size;
  final String? path;
  final String? hash;
  final String? createdAt;
  final String? updatedAt;
  final bool isFavorite;
  final String? libraryType;
  final int skipIntro;
  final int skipOutro;
  final String? tags;
  final String? genre;
  final int? year;
  final String? chapterRegex;

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: _string(json, 'id') ?? '',
      libraryId: _string(json, 'library_id', 'libraryId') ?? '',
      title: (_string(json, 'title')?.trim().isNotEmpty ?? false)
          ? _string(json, 'title')!
          : '未命名书籍',
      author: _string(json, 'author'),
      narrator: _string(json, 'narrator'),
      description: _string(json, 'description'),
      coverUrl: _string(json, 'cover_url', 'coverUrl'),
      themeColor: _string(json, 'theme_color', 'themeColor'),
      duration: _int(json, 'duration'),
      size: _int(json, 'size'),
      path: _string(json, 'path'),
      hash: _string(json, 'hash'),
      createdAt: _string(json, 'created_at', 'createdAt'),
      updatedAt: _string(json, 'updated_at', 'updatedAt'),
      isFavorite: _bool(json, 'is_favorite', 'isFavorite') ?? false,
      libraryType: _string(json, 'library_type', 'libraryType'),
      skipIntro: _int(json, 'skip_intro', 'skipIntro') ?? 0,
      skipOutro: _int(json, 'skip_outro', 'skipOutro') ?? 0,
      tags: _string(json, 'tags'),
      genre: _string(json, 'genre'),
      year: _int(json, 'year'),
      chapterRegex: _string(json, 'chapter_regex', 'chapterRegex'),
    );
  }

  Book copyWith({
    String? title,
    String? author,
    String? narrator,
    String? description,
    String? coverUrl,
    String? themeColor,
    bool? isFavorite,
    int? skipIntro,
    int? skipOutro,
    String? tags,
    String? genre,
    int? year,
    String? chapterRegex,
  }) {
    return Book(
      id: id,
      libraryId: libraryId,
      title: title ?? this.title,
      author: author ?? this.author,
      narrator: narrator ?? this.narrator,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      themeColor: themeColor ?? this.themeColor,
      duration: duration,
      size: size,
      path: path,
      hash: hash,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      libraryType: libraryType,
      skipIntro: skipIntro ?? this.skipIntro,
      skipOutro: skipOutro ?? this.skipOutro,
      tags: tags ?? this.tags,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      chapterRegex: chapterRegex ?? this.chapterRegex,
    );
  }
}

class Chapter {
  const Chapter({
    required this.id,
    required this.bookId,
    required this.title,
    required this.path,
    required this.chapterIndex,
    this.duration = 0,
    this.isExtra = false,
    this.progressPosition,
    this.progressUpdatedAt,
  });

  final String id;
  final String bookId;
  final String title;
  final String path;
  final int chapterIndex;
  final int duration;
  final bool isExtra;
  final double? progressPosition;
  final String? progressUpdatedAt;

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: _string(json, 'id') ?? '',
      bookId: _string(json, 'book_id', 'bookId') ?? '',
      title: _string(json, 'title') ?? '未命名章节',
      path: _string(json, 'path') ?? '',
      duration: _int(json, 'duration') ?? 0,
      chapterIndex: _int(json, 'chapter_index', 'chapterIndex') ?? 0,
      isExtra: (_int(json, 'is_extra', 'isExtra') ?? 0) != 0 ||
          (_bool(json, 'is_extra', 'isExtra') ?? false),
      progressPosition: _double(json, 'progress_position', 'progressPosition'),
      progressUpdatedAt:
          _string(json, 'progress_updated_at', 'progressUpdatedAt'),
    );
  }

  Chapter copyWith({
    String? title,
    int? chapterIndex,
    int? duration,
    bool? isExtra,
    double? progressPosition,
    String? progressUpdatedAt,
  }) {
    return Chapter(
      id: id,
      bookId: bookId,
      title: title ?? this.title,
      path: path,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      duration: duration ?? this.duration,
      isExtra: isExtra ?? this.isExtra,
      progressPosition: progressPosition ?? this.progressPosition,
      progressUpdatedAt: progressUpdatedAt ?? this.progressUpdatedAt,
    );
  }
}

class ChaptersPage {
  const ChaptersPage({
    required this.chapters,
    required this.total,
    required this.mainTotal,
    required this.extraTotal,
    required this.offset,
    required this.limit,
    required this.chapterType,
    required this.order,
  });

  final List<Chapter> chapters;
  final int total;
  final int mainTotal;
  final int extraTotal;
  final int offset;
  final int limit;
  final String chapterType;
  final String order;

  factory ChaptersPage.fromJson(Map<String, dynamic> json) {
    return ChaptersPage(
      chapters: asMapList(json['chapters']).map(Chapter.fromJson).toList(),
      total: _int(json, 'total') ?? 0,
      mainTotal: _int(json, 'main_total', 'mainTotal') ?? 0,
      extraTotal: _int(json, 'extra_total', 'extraTotal') ?? 0,
      offset: _int(json, 'offset') ?? 0,
      limit: _int(json, 'limit') ?? 100,
      chapterType: _string(json, 'chapter_type', 'chapterType') ?? 'main',
      order: _string(json, 'order') ?? 'asc',
    );
  }
}

class ProgressItem {
  const ProgressItem({
    required this.bookId,
    this.chapterId,
    this.position = 0,
    this.duration = 0,
    this.updatedAt,
    this.bookTitle,
    this.chapterTitle,
    this.coverUrl,
    this.libraryId,
    this.chapterDuration,
  });

  final String bookId;
  final String? chapterId;
  final double position;
  final double duration;
  final String? updatedAt;
  final String? bookTitle;
  final String? chapterTitle;
  final String? coverUrl;
  final String? libraryId;
  final int? chapterDuration;

  factory ProgressItem.fromJson(Map<String, dynamic> json) {
    return ProgressItem(
      bookId: _string(json, 'book_id', 'bookId') ?? '',
      chapterId: _string(json, 'chapter_id', 'chapterId'),
      position: _double(json, 'position') ?? 0,
      duration: _double(json, 'duration') ?? 0,
      updatedAt: _string(json, 'updated_at', 'updatedAt'),
      bookTitle: _string(json, 'book_title', 'bookTitle'),
      chapterTitle: _string(json, 'chapter_title', 'chapterTitle'),
      coverUrl: _string(json, 'cover_url', 'coverUrl'),
      libraryId: _string(json, 'library_id', 'libraryId'),
      chapterDuration: _int(json, 'chapter_duration', 'chapterDuration'),
    );
  }
}

class Stats {
  const Stats({
    this.totalBooks = 0,
    this.totalChapters = 0,
    this.totalDuration = 0,
    this.lastScanTime,
  });

  final int totalBooks;
  final int totalChapters;
  final int totalDuration;
  final String? lastScanTime;

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      totalBooks: _int(json, 'total_books', 'totalBooks') ?? 0,
      totalChapters: _int(json, 'total_chapters', 'totalChapters') ?? 0,
      totalDuration: _int(json, 'total_duration', 'totalDuration') ?? 0,
      lastScanTime: _string(json, 'last_scan_time', 'lastScanTime'),
    );
  }
}

class Series {
  const Series({
    required this.id,
    required this.libraryId,
    required this.title,
    this.author,
    this.narrator,
    this.description,
    this.coverUrl,
    this.createdAt,
    this.updatedAt,
    this.books = const [],
  });

  final String id;
  final String libraryId;
  final String title;
  final String? author;
  final String? narrator;
  final String? description;
  final String? coverUrl;
  final String? createdAt;
  final String? updatedAt;
  final List<Book> books;

  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: _string(json, 'id') ?? '',
      libraryId: _string(json, 'library_id', 'libraryId') ?? '',
      title: _string(json, 'title') ?? '未命名系列',
      author: _string(json, 'author'),
      narrator: _string(json, 'narrator'),
      description: _string(json, 'description'),
      coverUrl: _string(json, 'cover_url', 'coverUrl'),
      createdAt: _string(json, 'created_at', 'createdAt'),
      updatedAt: _string(json, 'updated_at', 'updatedAt'),
      books: asMapList(json['books']).map(Book.fromJson).toList(),
    );
  }
}

class CacheItem {
  const CacheItem({
    required this.chapterId,
    this.bookId,
    this.bookTitle,
    this.chapterTitle,
    this.fileSize = 0,
    this.createdAt,
    this.coverUrl,
  });

  final String chapterId;
  final String? bookId;
  final String? bookTitle;
  final String? chapterTitle;
  final int fileSize;
  final String? createdAt;
  final String? coverUrl;

  factory CacheItem.fromJson(Map<String, dynamic> json) {
    return CacheItem(
      chapterId: _string(json, 'chapter_id', 'chapterId') ?? '',
      bookId: _string(json, 'book_id', 'bookId'),
      bookTitle: _string(json, 'book_title', 'bookTitle'),
      chapterTitle: _string(json, 'chapter_title', 'chapterTitle'),
      fileSize: _int(json, 'file_size', 'fileSize') ?? 0,
      createdAt: _string(json, 'created_at', 'createdAt'),
      coverUrl: _string(json, 'cover_url', 'coverUrl'),
    );
  }
}

class Playlist {
  const Playlist({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.bookIds = const [],
    this.books = const [],
    this.items = const [],
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? createdAt;
  final String? updatedAt;
  final List<String> bookIds;
  final List<Book> books;
  final List<PlaylistItem> items;

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final rawItems =
        asMapList(json['items']).map(PlaylistItem.fromJson).toList();
    return Playlist(
      id: _string(json, 'id') ?? '',
      userId: _string(json, 'user_id', 'userId') ?? '',
      title: _string(json, 'title') ?? '未命名书单',
      description: _string(json, 'description'),
      createdAt: _string(json, 'created_at', 'createdAt'),
      updatedAt: _string(json, 'updated_at', 'updatedAt'),
      bookIds: _stringList(json['book_ids'] ?? json['bookIds']),
      books: asMapList(json['books']).map(Book.fromJson).toList(),
      items: rawItems,
    );
  }

  List<PlaylistItem> get effectiveItems {
    if (items.isNotEmpty) return items;
    return [
      for (var i = 0; i < books.length; i++)
        PlaylistItem(
          itemType: 'book',
          itemId: books[i].id,
          order: i + 1,
          book: books[i],
        ),
    ];
  }
}

class PlaylistItem {
  const PlaylistItem({
    required this.itemType,
    required this.itemId,
    required this.order,
    this.book,
    this.series,
  });

  final String itemType;
  final String itemId;
  final int order;
  final Book? book;
  final Series? series;

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    final bookMap = asMap(json['book']);
    final seriesMap = asMap(json['series']);
    return PlaylistItem(
      itemType: _string(json, 'item_type', 'itemType') ?? 'book',
      itemId: _string(json, 'item_id', 'itemId') ?? '',
      order: _int(json, 'order') ?? 0,
      book: bookMap.isEmpty ? null : Book.fromJson(bookMap),
      series: seriesMap.isEmpty ? null : Series.fromJson(seriesMap),
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'item_type': itemType,
        'item_id': itemId,
      };
}

class NotificationEventOption {
  const NotificationEventOption({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  factory NotificationEventOption.fromJson(Map<String, dynamic> json) {
    return NotificationEventOption(
      id: _string(json, 'id') ?? '',
      label: _string(json, 'label') ?? '',
      description: _string(json, 'description') ?? '',
    );
  }
}

class NotificationWebhook {
  const NotificationWebhook({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
    this.events = const [],
    this.secret,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String url;
  final bool enabled;
  final List<String> events;
  final String? secret;
  final String? createdAt;
  final String? updatedAt;

  factory NotificationWebhook.fromJson(Map<String, dynamic> json) {
    return NotificationWebhook(
      id: _string(json, 'id') ?? '',
      name: _string(json, 'name') ?? 'Webhook',
      url: _string(json, 'url') ?? '',
      enabled: _bool(json, 'enabled') ?? true,
      events: _stringList(json['events']),
      secret: _string(json, 'secret'),
      createdAt: _string(json, 'created_at', 'createdAt'),
      updatedAt: _string(json, 'updated_at', 'updatedAt'),
    );
  }
}

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
      libraryBreakdown:
          asMapList(json['library_breakdown'] ?? json['libraryBreakdown']),
      userActivity: asMapList(json['user_activity'] ?? json['userActivity']),
      recentActivity:
          asMapList(json['recent_activity'] ?? json['recentActivity']),
      topBooks: asMapList(json['top_books'] ?? json['topBooks']),
      generatedAt: _string(json, 'generated_at', 'generatedAt'),
    );
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.taskType,
    required this.status,
    this.progress,
    this.message,
    this.createdAt,
  });

  final String id;
  final String taskType;
  final String status;
  final double? progress;
  final String? message;
  final String? createdAt;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: _string(json, 'id') ?? '',
      taskType: _string(json, 'task_type', 'taskType') ?? 'task',
      status: _string(json, 'status') ?? '',
      progress: _double(json, 'progress'),
      message: _string(json, 'message'),
      createdAt: _string(json, 'created_at', 'createdAt'),
    );
  }
}

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
      id: _string(json, 'id') ?? '',
      name: _string(json, 'name') ?? 'Plugin',
      version: _string(json, 'version') ?? '',
      pluginType: _string(json, 'plugin_type', 'pluginType') ?? '',
      state: _string(json, 'state') ??
          (_bool(json, 'is_enabled', 'isEnabled') == false
              ? 'inactive'
              : 'active'),
      author: _string(json, 'author'),
      description: _string(json, 'description'),
      longDescription: _string(json, 'long_description', 'longDescription'),
      runtime: _string(json, 'runtime'),
      license: _string(json, 'license'),
      repo: _string(json, 'repo'),
      dependencies: _pluginStringList(json['dependencies']),
      permissions: _stringList(json['permissions']),
      supportedExtensions: _stringList(
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
      autoScrape: _bool(json, 'autoScrape', 'auto_scrape') ?? false,
      searchFields:
          _scraperFieldNames(json['searchFields'] ?? json['search_fields']),
      resultFields: _stringList(json['resultFields'] ?? json['result_fields']),
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
