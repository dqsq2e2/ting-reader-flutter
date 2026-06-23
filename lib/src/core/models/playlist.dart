import '_helpers.dart';
import 'book.dart';
import 'series.dart';

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
      id: readString(json, 'id') ?? '',
      userId: readString(json, 'user_id', 'userId') ?? '',
      title: readString(json, 'title') ?? '未命名书单',
      description: readString(json, 'description'),
      createdAt: readString(json, 'created_at', 'createdAt'),
      updatedAt: readString(json, 'updated_at', 'updatedAt'),
      bookIds: readStringList(json['book_ids'] ?? json['bookIds']),
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
      itemType: readString(json, 'item_type', 'itemType') ?? 'book',
      itemId: readString(json, 'item_id', 'itemId') ?? '',
      order: readInt(json, 'order') ?? 0,
      book: bookMap.isEmpty ? null : Book.fromJson(bookMap),
      series: seriesMap.isEmpty ? null : Series.fromJson(seriesMap),
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'item_type': itemType,
        'item_id': itemId,
      };
}
