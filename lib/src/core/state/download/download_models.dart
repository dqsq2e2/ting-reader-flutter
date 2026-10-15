import '../../models/_helpers.dart' show readInt, readDouble, readString;
import '../../models/models.dart';

const legacyDownloadServerKey = 'legacy';

String downloadRecordKey(String serverKey, String itemId) {
  final server = serverKey.trim().isEmpty ? legacyDownloadServerKey : serverKey;
  return '$server::$itemId';
}

enum DownloadStatus { queued, downloading, paused, completed, failed }

extension DownloadStatusText on DownloadStatus {
  String get label {
    return switch (this) {
      DownloadStatus.queued => '排队中',
      DownloadStatus.downloading => '下载中',
      DownloadStatus.paused => '已暂停',
      DownloadStatus.completed => '已下载',
      DownloadStatus.failed => '失败',
    };
  }

  String get key {
    return switch (this) {
      DownloadStatus.queued => 'queued',
      DownloadStatus.downloading => 'downloading',
      DownloadStatus.paused => 'paused',
      DownloadStatus.completed => 'completed',
      DownloadStatus.failed => 'failed',
    };
  }

  String labelForLocale(bool english) {
    if (english) {
      return switch (this) {
        DownloadStatus.queued => 'Queued',
        DownloadStatus.downloading => 'Downloading',
        DownloadStatus.paused => 'Paused',
        DownloadStatus.completed => 'Downloaded',
        DownloadStatus.failed => 'Failed',
      };
    }
    return label;
  }

  static DownloadStatus fromKey(String? value) {
    return switch (value) {
      'downloading' => DownloadStatus.downloading,
      'paused' => DownloadStatus.paused,
      'completed' => DownloadStatus.completed,
      'failed' => DownloadStatus.failed,
      _ => DownloadStatus.queued,
    };
  }
}

/// A download that has already been written to disk.
class LocalDownload {
  const LocalDownload({
    required this.chapterId,
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.filePath,
    required this.fileSize,
    required this.createdAt,
    this.coverUrl,
    this.localCoverPath,
    this.libraryId,
    this.duration,
    this.isExtra = false,
    this.bookMetadata = const {},
    this.serverKey = legacyDownloadServerKey,
    this.serverName,
  });

  final String chapterId;
  final String bookId;
  final String bookTitle;
  final String chapterTitle;
  final int chapterIndex;
  final String filePath;
  final int fileSize;
  final DateTime createdAt;
  final String? coverUrl;
  final String? localCoverPath;
  final String? libraryId;
  final int? duration;
  final bool isExtra;
  final Map<String, dynamic> bookMetadata;
  final String serverKey;
  final String? serverName;

  String get storageKey => downloadRecordKey(serverKey, chapterId);
  String get bookGroupKey => downloadRecordKey(serverKey, bookId);

  Book toBook({Map<String, dynamic> fallbackMetadata = const {}}) {
    final localCover = localCoverPath;
    return Book.fromJson({
      ...(bookMetadata.isEmpty ? fallbackMetadata : bookMetadata),
      'id': bookId,
      'library_id': libraryId ?? '',
      'title': bookTitle,
      'can_write_metadata_files': false,
      'cover_url':
          localCover == null ? coverUrl : Uri.file(localCover).toString(),
    });
  }

  Chapter get chapter => Chapter(
        id: chapterId,
        bookId: bookId,
        title: chapterTitle,
        path: Uri.file(filePath).toString(),
        chapterIndex: chapterIndex,
        duration: duration ?? 0,
        isExtra: isExtra,
      );

  factory LocalDownload.fromJson(Map<String, dynamic> json) {
    return LocalDownload(
      chapterId: json['chapter_id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      bookTitle: json['book_title']?.toString() ?? '',
      chapterTitle: json['chapter_title']?.toString() ?? '',
      chapterIndex: readInt(json, 'chapter_index') ?? 0,
      filePath: json['file_path']?.toString() ?? '',
      fileSize: readInt(json, 'file_size') ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      coverUrl: readString(json, 'cover_url'),
      localCoverPath: readString(json, 'local_cover_path'),
      libraryId: readString(json, 'library_id'),
      duration: readInt(json, 'duration'),
      isExtra: _boolLike(json['is_extra']),
      bookMetadata: asMap(json['book_metadata']),
      serverKey: readString(json, 'server_key') ?? legacyDownloadServerKey,
      serverName: readString(json, 'server_name'),
    );
  }

  Map<String, dynamic> toJson() => {
        'chapter_id': chapterId,
        'book_id': bookId,
        'book_title': bookTitle,
        'chapter_title': chapterTitle,
        'chapter_index': chapterIndex,
        'file_path': filePath,
        'file_size': fileSize,
        'created_at': createdAt.toIso8601String(),
        if (coverUrl != null) 'cover_url': coverUrl,
        if (localCoverPath != null) 'local_cover_path': localCoverPath,
        if (libraryId != null) 'library_id': libraryId,
        if (duration != null) 'duration': duration,
        if (isExtra) 'is_extra': true,
        if (bookMetadata.isNotEmpty) 'book_metadata': bookMetadata,
        'server_key': serverKey,
        if (serverName != null) 'server_name': serverName,
      };
}

/// An in-flight or queued download task.
class DownloadTask {
  DownloadTask({
    required this.chapterId,
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.chapterPath,
    this.coverUrl,
    this.libraryId,
    this.duration,
    this.isExtra = false,
    this.bookMetadata = const {},
    this.serverKey = legacyDownloadServerKey,
    this.serverName,
    this.transcode = false,
    this.progress = 0,
    this.status = DownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.filePath,
    this.tempPath,
    this.error,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String chapterId;
  final String bookId;
  final String bookTitle;
  final String chapterTitle;
  final int chapterIndex;
  final String chapterPath;
  final String? coverUrl;
  final String? libraryId;
  final int? duration;
  final bool isExtra;
  final Map<String, dynamic> bookMetadata;
  final String serverKey;
  final String? serverName;
  final bool transcode;
  final DateTime createdAt;

  double progress;
  DownloadStatus status;
  int receivedBytes;
  int totalBytes;
  String? filePath;
  String? tempPath;
  String? error;
  DateTime updatedAt;

  String get storageKey => downloadRecordKey(serverKey, chapterId);
  String get bookGroupKey => downloadRecordKey(serverKey, bookId);

  Book get book => Book.fromJson({
        ...bookMetadata,
        'id': bookId,
        'library_id': libraryId ?? '',
        'title': bookTitle,
        'can_write_metadata_files': false,
        'cover_url': coverUrl,
      });

  Chapter get chapter => Chapter(
        id: chapterId,
        bookId: bookId,
        title: chapterTitle,
        path: chapterPath,
        chapterIndex: chapterIndex,
        duration: duration ?? 0,
        isExtra: isExtra,
      );

  factory DownloadTask.fromBookChapter(
    Book book,
    Chapter chapter, {
    required String serverKey,
    String? serverName,
    bool transcode = false,
  }) {
    return DownloadTask(
      chapterId: chapter.id,
      bookId: book.id,
      bookTitle: book.title,
      chapterTitle: chapter.title,
      chapterIndex: chapter.chapterIndex,
      chapterPath: chapter.path,
      coverUrl: book.coverUrl,
      libraryId: book.libraryId,
      duration: chapter.duration,
      isExtra: chapter.isExtra,
      bookMetadata: _bookMetadataFromBook(book),
      serverKey: serverKey,
      serverName: serverName,
      transcode: transcode,
    );
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final status = DownloadStatusText.fromKey(json['status']?.toString());
    return DownloadTask(
      chapterId: json['chapter_id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      bookTitle: json['book_title']?.toString() ?? '',
      chapterTitle: json['chapter_title']?.toString() ?? '',
      chapterIndex: readInt(json, 'chapter_index') ?? 0,
      chapterPath: json['chapter_path']?.toString() ?? '',
      coverUrl: readString(json, 'cover_url'),
      libraryId: readString(json, 'library_id'),
      duration: readInt(json, 'duration'),
      isExtra: _boolLike(json['is_extra']),
      bookMetadata: asMap(json['book_metadata']),
      serverKey: readString(json, 'server_key') ?? legacyDownloadServerKey,
      serverName: readString(json, 'server_name'),
      transcode: json['transcode'] == true,
      progress: readDouble(json, 'progress') ?? 0,
      status:
          status == DownloadStatus.downloading ? DownloadStatus.queued : status,
      receivedBytes: readInt(json, 'received_bytes') ?? 0,
      totalBytes: readInt(json, 'total_bytes') ?? 0,
      filePath: json['file_path']?.toString(),
      tempPath: json['temp_path']?.toString(),
      error: json['error']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'chapter_id': chapterId,
        'book_id': bookId,
        'book_title': bookTitle,
        'chapter_title': chapterTitle,
        'chapter_index': chapterIndex,
        'chapter_path': chapterPath,
        if (coverUrl != null) 'cover_url': coverUrl,
        if (libraryId != null) 'library_id': libraryId,
        if (duration != null) 'duration': duration,
        if (isExtra) 'is_extra': true,
        if (bookMetadata.isNotEmpty) 'book_metadata': bookMetadata,
        'server_key': serverKey,
        if (serverName != null) 'server_name': serverName,
        'transcode': transcode,
        'progress': progress,
        'status': status.key,
        'received_bytes': receivedBytes,
        'total_bytes': totalBytes,
        if (filePath != null) 'file_path': filePath,
        if (tempPath != null) 'temp_path': tempPath,
        if (error != null) 'error': error,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  void touch() {
    updatedAt = DateTime.now();
  }
}

bool _boolLike(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

Map<String, dynamic> _bookMetadataFromBook(Book book) {
  return {
    'id': book.id,
    'library_id': book.libraryId,
    'title': book.title,
    'author': book.author,
    'narrator': book.narrator,
    'description': book.description,
    'cover_url': book.coverUrl,
    'theme_color': book.themeColor,
    'duration': book.duration,
    'size': book.size,
    'path': book.path,
    'hash': book.hash,
    'created_at': book.createdAt,
    'updated_at': book.updatedAt,
    'library_type': book.libraryType,
    'skip_intro': book.skipIntro,
    'skip_outro': book.skipOutro,
    'tags': book.tags,
    'genre': book.genre,
    'year': book.year,
    'chapter_regex': book.chapterRegex,
  }..removeWhere((_, value) => value == null || value == '');
}

/// Result of asking the queue to start or resume one chapter.
enum DownloadRequestOutcome { downloaded, resumed, existing, queued }

class DownloadRequestResult {
  const DownloadRequestResult(this.outcome, {this.status});
  final DownloadRequestOutcome outcome;
  final DownloadStatus? status;

  String messageForLocale(bool english, String title) => switch (outcome) {
        DownloadRequestOutcome.downloaded =>
          english ? 'Chapter already downloaded' : '章节已下载',
        DownloadRequestOutcome.resumed =>
          english ? 'Resumed download: $title' : '已恢复下载：$title',
        DownloadRequestOutcome.existing => english
            ? 'Download task already exists: ${status?.labelForLocale(true) ?? "Queued"}'
            : '下载任务已存在：${status?.labelForLocale(false) ?? "排队中"}',
        DownloadRequestOutcome.queued =>
          english ? 'Added to download queue: $title' : '已加入下载队列：$title',
      };
}

/// Versioned disk snapshot; legacy lists and interrupted transfers share one parser.
class DownloadIndex {
  const DownloadIndex(
      {this.downloads = const [],
      this.tasks = const [],
      this.maxConcurrent = 2});
  final List<LocalDownload> downloads;
  final List<DownloadTask> tasks;
  final int maxConcurrent;

  factory DownloadIndex.fromJson(Object? decoded) {
    final payload = asMap(decoded);
    final downloads = asMapList(
            decoded is List ? decoded : payload['downloads'])
        .map(LocalDownload.fromJson)
        .where((item) => item.chapterId.isNotEmpty && item.filePath.isNotEmpty)
        .toList();
    final completed = downloads.map((item) => item.storageKey).toSet();
    final tasks = asMapList(payload['tasks'])
        .map(DownloadTask.fromJson)
        .where((task) =>
            task.chapterId.isNotEmpty &&
            task.bookId.isNotEmpty &&
            task.chapterPath.isNotEmpty &&
            !completed.contains(task.storageKey))
        .toList();
    return DownloadIndex(
        downloads: downloads,
        tasks: tasks,
        maxConcurrent:
            (readInt(asMap(payload['settings']), 'max_concurrent_downloads') ??
                    2)
                .clamp(1, 6));
  }

  Map<String, dynamic> toJson({String? directory}) => {
        'version': 2,
        'settings': {
          'max_concurrent_downloads': maxConcurrent,
          if (directory != null) 'cache_directory': directory
        },
        'downloads': downloads.map((item) => item.toJson()).toList(),
        'tasks': tasks
            .where((task) => task.status != DownloadStatus.completed)
            .map((task) => task.toJson())
            .toList(),
      };
}
