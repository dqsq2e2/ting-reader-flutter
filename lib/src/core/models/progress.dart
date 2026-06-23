import '_helpers.dart';

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
      bookId: readString(json, 'book_id', 'bookId') ?? '',
      chapterId: readString(json, 'chapter_id', 'chapterId'),
      position: readDouble(json, 'position') ?? 0,
      duration: readDouble(json, 'duration') ?? 0,
      updatedAt: readString(json, 'updated_at', 'updatedAt'),
      bookTitle: readString(json, 'book_title', 'bookTitle'),
      chapterTitle: readString(json, 'chapter_title', 'chapterTitle'),
      coverUrl: readString(json, 'cover_url', 'coverUrl'),
      libraryId: readString(json, 'library_id', 'libraryId'),
      chapterDuration: readInt(json, 'chapter_duration', 'chapterDuration'),
    );
  }
}
