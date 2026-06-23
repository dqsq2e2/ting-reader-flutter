import '_helpers.dart';

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
      id: readString(json, 'id') ?? '',
      libraryId: readString(json, 'library_id', 'libraryId') ?? '',
      title: (readString(json, 'title')?.trim().isNotEmpty ?? false)
          ? readString(json, 'title')!
          : '未命名书籍',
      author: readString(json, 'author'),
      narrator: readString(json, 'narrator'),
      description: readString(json, 'description'),
      coverUrl: readString(json, 'cover_url', 'coverUrl'),
      themeColor: readString(json, 'theme_color', 'themeColor'),
      duration: readInt(json, 'duration'),
      size: readInt(json, 'size'),
      path: readString(json, 'path'),
      hash: readString(json, 'hash'),
      createdAt: readString(json, 'created_at', 'createdAt'),
      updatedAt: readString(json, 'updated_at', 'updatedAt'),
      isFavorite: readBool(json, 'is_favorite', 'isFavorite') ?? false,
      libraryType: readString(json, 'library_type', 'libraryType'),
      skipIntro: readInt(json, 'skip_intro', 'skipIntro') ?? 0,
      skipOutro: readInt(json, 'skip_outro', 'skipOutro') ?? 0,
      tags: readString(json, 'tags'),
      genre: readString(json, 'genre'),
      year: readInt(json, 'year'),
      chapterRegex: readString(json, 'chapter_regex', 'chapterRegex'),
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
