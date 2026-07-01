import '_helpers.dart';
import 'book.dart';

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
      id: readString(json, 'id') ?? '',
      libraryId: readString(json, 'library_id') ?? '',
      title: readString(json, 'title') ?? '',
      author: readString(json, 'author'),
      narrator: readString(json, 'narrator'),
      description: readString(json, 'description'),
      coverUrl: readString(json, 'cover_url'),
      createdAt: readString(json, 'created_at'),
      updatedAt: readString(json, 'updated_at'),
      books: asMapList(json['books']).map(Book.fromJson).toList(),
    );
  }
}
