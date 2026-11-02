import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../models/models.dart';
import 'scrape_state.dart';

enum SearchScope { all, bookshelf, online }

class SourceSearchBook {
  SourceSearchBook.fromJson(this.sourceId, Map<String, dynamic> json)
      : book = Book.fromJson(json),
        sourceUrl = json['source_url']?.toString(),
        addedBookId = json['added_book_id']?.toString();

  final String sourceId;
  final Book book;
  final String? sourceUrl;
  String? addedBookId;

  (String, String) get key => (sourceId, book.id);
  bool get added => addedBookId?.isNotEmpty == true;
}

/// One search session owns scope, filters, source selection and request lifetime.
class SearchState extends ChangeNotifier {
  SearchState(this.api);

  final ApiClient api;
  final Set<CancelToken> _requests = {};
  final Set<(String, String)> adding = {};
  final Map<(String, String), String> _addedBooks = {};
  CancelToken? _searchToken;
  bool _disposed = false;
  bool loading = true;
  bool searching = false;
  Object? metadataError;
  Object? sourceLoadError;
  Object? bookshelfError;
  List<String> sourceErrors = [];
  SearchScope scope = SearchScope.bookshelf;
  String query = '';
  String libraryId = '';
  String seriesId = '';
  String tag = '';
  String genre = '';
  String year = '';
  String author = '';
  String narrator = '';
  List<Library> libraries = [];
  List<Series> series = [];
  List<String> tags = [];
  List<String> genres = [];
  List<String> years = [];
  List<String> authors = [];
  List<String> narrators = [];
  Map<String, dynamic> settings = {};
  List<ScrapeSource> sources = [];
  final Set<String> selectedSourceIds = {};
  List<Book> books = [];
  List<SourceSearchBook> sourceBooks = [];
  int page = 1;
  bool hasMore = false;

  bool get showFilters => scope == SearchScope.bookshelf;
  bool get showBookshelf => scope != SearchScope.online;
  bool get showOnline => scope != SearchScope.bookshelf;
  bool get hasFilters => [
        libraryId,
        seriesId,
        tag,
        genre,
        year,
        author,
        narrator
      ].any((value) => value.isNotEmpty);
  bool get hasSearch => query.trim().isNotEmpty || (showFilters && hasFilters);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed) return;
    final token = CancelToken();
    _requests.add(token);
    loading = true;
    metadataError = sourceLoadError = null;
    _notify();
    try {
      await Future.wait([_loadMetadata(token), _loadSources(token)]);
    } finally {
      _requests.remove(token);
      if (!_disposed && !token.isCancelled) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> _loadMetadata(CancelToken token) async {
    try {
      final responses = await Future.wait([
        api.get('/api/tags', cancelToken: token),
        api.get('/api/books', cancelToken: token),
        api.get('/api/libraries', cancelToken: token),
        api.get('/api/v1/series', cancelToken: token),
        api.get('/api/settings', cancelToken: token),
      ]);
      if (_disposed || token.isCancelled) return;
      final allBooks = asMapList(responses[1].data).map(Book.fromJson).toList();
      List<String> values(String? Function(Book) value) => allBooks
          .map(value)
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      authors = values((book) => book.author);
      narrators = values((book) => book.narrator);
      genres = allBooks
          .expand((book) => (book.genre ?? '').split(','))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      years = values((book) => book.year?.toString())
        ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));
      tags = (responses[0].data as List? ?? []).map((e) => '$e').toList();
      libraries = asMapList(responses[2].data).map(Library.fromJson).toList();
      series = asMapList(responses[3].data).map(Series.fromJson).toList();
      settings = asMap(responses[4].data);
    } catch (error) {
      if (!_disposed && !token.isCancelled) metadataError = error;
    }
  }

  Future<void> _loadSources(CancelToken token) async {
    try {
      final response =
          await api.get('/api/v1/scraper/sources', cancelToken: token);
      if (_disposed || token.isCancelled) return;
      sources = asMapList(asMap(response.data)['sources'])
          .map(ScrapeSource.fromJson)
          .where((source) => source.enabled && source.bookSource)
          .toList();
      selectedSourceIds
        ..clear()
        ..addAll(sources.map((source) => source.id));
    } catch (error) {
      if (!_disposed && !token.isCancelled) sourceLoadError = error;
    }
  }

  void invalidateSearch() {
    _searchToken?.cancel('Search inputs changed');
    searching = false;
  }

  Future<void> setScope(SearchScope value) async {
    scope = value;
    await search();
  }

  Future<void> selectSources(Iterable<String> ids) async {
    selectedSourceIds
      ..clear()
      ..addAll(ids.where((id) => sources.any((source) => source.id == id)));
    await search();
  }

  Future<void> search({int requestedPage = 1}) async {
    if (_disposed) return;
    invalidateSearch();
    final token = CancelToken();
    _searchToken = token;
    _requests.add(token);
    page = requestedPage;
    bookshelfError = null;
    sourceErrors = [];
    books = [];
    sourceBooks = [];
    hasMore = false;
    if (!hasSearch) {
      _requests.remove(token);
      _notify();
      return;
    }
    searching = true;
    _notify();
    try {
      await Future.wait([
        if (showBookshelf) _searchBookshelf(token),
        if (showOnline && query.trim().isNotEmpty)
          for (final source in sources)
            if (selectedSourceIds.contains(source.id))
              _searchSource(source, token, requestedPage),
      ]);
    } finally {
      _requests.remove(token);
      if (!_disposed && identical(_searchToken, token) && !token.isCancelled) {
        searching = false;
        _notify();
      }
    }
  }

  Future<void> _searchBookshelf(CancelToken token) async {
    try {
      final response = await api.get('/api/books', cancelToken: token, params: {
        if (query.trim().isNotEmpty) 'search': query.trim(),
        if (showFilters && tag.isNotEmpty) 'tag': tag,
        if (showFilters && libraryId.isNotEmpty) 'library_id': libraryId,
      });
      if (_disposed || token.isCancelled) return;
      var found = asMapList(response.data).map(Book.fromJson);
      if (showFilters) {
        final seriesBooks = series
                .where((item) => item.id == seriesId)
                .firstOrNull
                ?.books
                .map((book) => book.id)
                .toSet() ??
            <String>{};
        found = found.where((book) =>
            (author.isEmpty || book.author == author) &&
            (narrator.isEmpty || book.narrator == narrator) &&
            (year.isEmpty || book.year?.toString() == year) &&
            (genre.isEmpty ||
                (book.genre ?? '')
                    .split(',')
                    .map((s) => s.trim())
                    .contains(genre)) &&
            (seriesId.isEmpty || seriesBooks.contains(book.id)));
      }
      books = found.toList();
      _notify();
    } catch (error) {
      if (!_disposed && !token.isCancelled) {
        bookshelfError = error;
        _notify();
      }
    }
  }

  Future<void> _searchSource(
      ScrapeSource source, CancelToken token, int requestedPage) async {
    try {
      final response = await api.post('/api/v1/scraper/search',
          cancelToken: token,
          receiveTimeout: const Duration(minutes: 2),
          data: {
            'source': source.id,
            'query': query.trim(),
            'page': requestedPage,
            'page_size': 20,
          });
      if (_disposed || token.isCancelled) return;
      final data = asMap(response.data);
      sourceBooks.addAll(asMapList(data['items']).map((json) {
        final item = SourceSearchBook.fromJson(source.id, json);
        item.addedBookId = _addedBooks[item.key] ?? item.addedBookId;
        return item;
      }));
      sourceBooks = [
        for (final source in sources)
          ...sourceBooks.where((item) => item.sourceId == source.id),
      ];
      final total = (data['total'] as num?)?.toInt();
      final pageSize = (data['page_size'] as num?)?.toInt() ?? 20;
      hasMore |= data['has_more'] as bool? ??
          (total != null && requestedPage * pageSize < total);
      _notify();
    } catch (error) {
      if (!_disposed && !token.isCancelled) {
        sourceErrors.add('${source.name}: ${ApiError.messageFor(error)}');
        _notify();
      }
    }
  }

  Future<void> addBook(SourceSearchBook item) async {
    if (_disposed ||
        item.added ||
        item.book.id.isEmpty ||
        !adding.add(item.key)) {
      return;
    }
    final token = CancelToken();
    _requests.add(token);
    _notify();
    try {
      final response = await api.post('/api/v1/scraper/books',
          cancelToken: token,
          receiveTimeout: const Duration(minutes: 2),
          data: {
            'source': item.sourceId,
            'book': {'id': item.book.id, 'url': item.sourceUrl},
          });
      if (_disposed || token.isCancelled) return;
      final id = asMap(response.data)['book_id']?.toString();
      if (id == null || id.isEmpty) {
        throw const FormatException('Missing book_id in source book response');
      }
      _addedBooks[item.key] = id;
      item.addedBookId = id;
      for (final current in sourceBooks) {
        if (current.key == item.key) current.addedBookId = id;
      }
    } finally {
      _requests.remove(token);
      adding.remove(item.key);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final token in _requests) {
      token.cancel('Search closed');
    }
    super.dispose();
  }
}
