import '_helpers.dart';

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
      chapterId: readString(json, 'chapter_id', 'chapterId') ?? '',
      bookId: readString(json, 'book_id', 'bookId'),
      bookTitle: readString(json, 'book_title', 'bookTitle'),
      chapterTitle: readString(json, 'chapter_title', 'chapterTitle'),
      fileSize: readInt(json, 'file_size', 'fileSize') ?? 0,
      createdAt: readString(json, 'created_at', 'createdAt'),
      coverUrl: readString(json, 'cover_url', 'coverUrl'),
    );
  }
}
