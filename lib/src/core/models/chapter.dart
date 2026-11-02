import '_helpers.dart';

class Chapter {
  const Chapter({
    required this.id,
    required this.bookId,
    required this.title,
    required this.path,
    required this.chapterIndex,
    this.duration = 0,
    this.isExtra = false,
    this.startTime,
    this.endTime,
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

  /// Milliseconds into [path] where this chapter starts. Set for chapters read
  /// from an embedded M4B chapter table; null when the chapter is the file.
  final int? startTime;

  /// Milliseconds into [path] where this chapter ends.
  final int? endTime;
  final double? progressPosition;
  final String? progressUpdatedAt;

  bool get isSegmented => startTime != null && endTime != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'book_id': bookId,
        'title': title,
        'path': path,
        'chapter_index': chapterIndex,
        'duration': duration,
        'is_extra': isExtra,
        'start_time': startTime,
        'end_time': endTime,
        'progress_position': progressPosition,
        'progress_updated_at': progressUpdatedAt,
      };

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: readString(json, 'id') ?? '',
      bookId: readString(json, 'book_id') ?? '',
      title: readString(json, 'title') ?? '',
      path: readString(json, 'path') ?? '',
      duration: readInt(json, 'duration') ?? 0,
      chapterIndex: readInt(json, 'chapter_index') ?? 0,
      isExtra: (readInt(json, 'is_extra') ?? 0) != 0 ||
          (readBool(json, 'is_extra') ?? false),
      startTime: readInt(json, 'start_time'),
      endTime: readInt(json, 'end_time'),
      progressPosition: readDouble(json, 'progress_position'),
      progressUpdatedAt: readString(json, 'progress_updated_at'),
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
      startTime: startTime,
      endTime: endTime,
      progressPosition: progressPosition ?? this.progressPosition,
      progressUpdatedAt: progressUpdatedAt ?? this.progressUpdatedAt,
    );
  }

  /// Start of this chapter inside the shared audio file, in seconds.
  double get startSeconds => (startTime ?? 0) / 1000;

  /// End of this chapter inside the shared audio file, in seconds.
  double get endSeconds => (endTime ?? 0) / 1000;
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
      total: readInt(json, 'total') ?? 0,
      mainTotal: readInt(json, 'main_total') ?? 0,
      extraTotal: readInt(json, 'extra_total') ?? 0,
      offset: readInt(json, 'offset') ?? 0,
      limit: readInt(json, 'limit') ?? 100,
      chapterType: readString(json, 'chapter_type') ?? 'main',
      order: readString(json, 'order') ?? 'asc',
    );
  }
}
