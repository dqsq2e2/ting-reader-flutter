part of '../download_state.dart';

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

  factory LocalDownload.fromJson(Map<String, dynamic> json) {
    return LocalDownload(
      chapterId: json['chapter_id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      bookTitle: json['book_title']?.toString() ?? '',
      chapterTitle: json['chapter_title']?.toString() ?? '',
      chapterIndex: _int(json['chapter_index']) ?? 0,
      filePath: json['file_path']?.toString() ?? '',
      fileSize: _int(json['file_size']) ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      coverUrl: _string(json['cover_url']),
      localCoverPath: _string(json['local_cover_path']),
      libraryId: _string(json['library_id']),
      duration: _int(json['duration']),
      isExtra: _boolLike(json['is_extra']),
      bookMetadata: asMap(json['book_metadata']),
      serverKey: _string(json['server_key']) ?? legacyDownloadServerKey,
      serverName: _string(json['server_name']),
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

  Book get book => Book(
        id: bookId,
        libraryId: libraryId ?? '',
        title: bookTitle,
        author: _string(bookMetadata['author']),
        narrator: _string(bookMetadata['narrator']),
        description: _string(bookMetadata['description']),
        coverUrl: coverUrl,
        themeColor: _string(bookMetadata['theme_color']),
        duration: _int(bookMetadata['duration']),
        size: _int(bookMetadata['size']),
        path: _string(bookMetadata['path']),
        hash: _string(bookMetadata['hash']),
        createdAt: _string(bookMetadata['created_at']),
        updatedAt: _string(bookMetadata['updated_at']),
        libraryType: _string(bookMetadata['library_type']),
        skipIntro: _int(bookMetadata['skip_intro']) ?? 0,
        skipOutro: _int(bookMetadata['skip_outro']) ?? 0,
        tags: _string(bookMetadata['tags']),
        genre: _string(bookMetadata['genre']),
        year: _int(bookMetadata['year']),
        chapterRegex: _string(bookMetadata['chapter_regex']),
      );

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
      chapterIndex: _int(json['chapter_index']) ?? 0,
      chapterPath: json['chapter_path']?.toString() ?? '',
      coverUrl: _string(json['cover_url']),
      libraryId: _string(json['library_id']),
      duration: _int(json['duration']),
      isExtra: _boolLike(json['is_extra']),
      bookMetadata: asMap(json['book_metadata']),
      serverKey: _string(json['server_key']) ?? legacyDownloadServerKey,
      serverName: _string(json['server_name']),
      transcode: json['transcode'] == true,
      progress: _double(json['progress']) ?? 0,
      status:
          status == DownloadStatus.downloading ? DownloadStatus.queued : status,
      receivedBytes: _int(json['received_bytes']) ?? 0,
      totalBytes: _int(json['total_bytes']) ?? 0,
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
