import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/api_error.dart';
import '../models/models.dart';
import '../utils/chapter_sort.dart';
import '../utils/formatters.dart';

/// Pending chapter edits, shared filtering and the exact batch write payload.
/// UI controllers and confirmation dialogs stay with the page.
class ChapterEditDraft {
  ChapterEditDraft(Iterable<Chapter> source)
      : _chapters = source.toList()
          ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));

  List<Chapter> _chapters;
  final Set<String> changedIds = {};
  List<Chapter> get chapters => List.unmodifiable(_chapters);

  List<Chapter> forTab(String tab) => _chapters
      .where((chapter) => chapter.isExtra == (tab == 'extra'))
      .toList();

  int count(String tab) =>
      _chapters.where((chapter) => chapter.isExtra == (tab == 'extra')).length;

  List<Chapter> filter(
      String tab, String query, String Function(String) displayPath) {
    final needle = query.trim().toLowerCase();
    return forTab(tab)
        .where((chapter) =>
            needle.isEmpty ||
            chapter.title.toLowerCase().contains(needle) ||
            chapter.chapterIndex.toString().contains(needle) ||
            displayPath(chapter.path).toLowerCase().contains(needle))
        .toList();
  }

  void update(String id, Chapter Function(Chapter) change) {
    if (!_chapters.any((chapter) => chapter.id == id)) {
      throw StateError('Cannot edit a chapter outside the current draft');
    }
    _chapters = [
      for (final chapter in _chapters)
        if (chapter.id == id) change(chapter) else chapter,
    ];
    changedIds.add(id);
  }

  void renumber() {
    _chapters = [
      for (var i = 0; i < _chapters.length; i++)
        _chapters[i].copyWith(chapterIndex: i + 1),
    ];
    changedIds.addAll(_chapters.map((chapter) => chapter.id));
  }

  List<Map<String, Object>> get updates => [
        for (final chapter in _chapters)
          if (changedIds.contains(chapter.id))
            {
              'id': chapter.id,
              'title': chapter.title,
              'chapter_index': chapter.chapterIndex,
              'is_extra': chapter.isExtra ? 1 : 0,
            },
      ];
}

/// Shared book mutations for shelf, series, detail and player settings.
/// The owner scopes cancellation; callers keep confirmation dialogs.
class BookOperations {
  BookOperations(this.api);
  final ApiClient api;
  final Set<CancelToken> _requests = {};
  bool _disposed = false;

  Future<T> run<T>(Future<T> Function(CancelToken token) operation) async {
    if (_disposed) throw StateError('Book operation owner disposed');
    final token = CancelToken();
    _requests.add(token);
    try {
      final result = await operation(token);
      if (_disposed || token.isCancelled) {
        throw StateError('Book operation cancelled');
      }
      return result;
    } finally {
      _requests.remove(token);
    }
  }

  Future<void> markRead(Iterable<String> bookIds, bool read) =>
      run((token) async {
        final ids = bookIds.toSet().toList();
        for (var offset = 0; offset < ids.length; offset += 200) {
          if (token.isCancelled) throw StateError('Book operation cancelled');
          await api.post('/api/books/read-status', cancelToken: token, data: {
            'book_ids': ids.skip(offset).take(200).toList(),
            'read': read
          });
        }
      });

  Future<void> deleteBooks(Iterable<String> ids, {bool deleteFiles = false}) =>
      run((token) async {
        // Bound concurrency instead of creating a request for every selected book.
        final pending = ids.toSet().toList();
        for (var offset = 0; offset < pending.length; offset += 4) {
          if (token.isCancelled) throw StateError('Book operation cancelled');
          await Future.wait(pending.skip(offset).take(4).map((id) => api.delete(
              '/api/books/${Uri.encodeComponent(id)}',
              params: {'delete_files': deleteFiles},
              cancelToken: token)));
        }
      });

  Future<void> deleteSeries(Iterable<String> ids) => run((token) async {
        for (final id in ids.toSet()) {
          if (token.isCancelled) throw StateError('Book operation cancelled');
          await api.delete('/api/v1/series/${Uri.encodeComponent(id)}',
              cancelToken: token);
        }
      });

  Future<void> createSeries(Map<String, dynamic> values) => run((token) async {
        await api.post('/api/v1/series', data: values, cancelToken: token);
      });

  Future<void> favorite(String id, bool value) => run((token) async {
        final path = '/api/favorites/${Uri.encodeComponent(id)}';
        if (value) {
          await api.post(path, cancelToken: token);
        } else {
          await api.delete(path, cancelToken: token);
        }
      });

  Future<void> writeMetadata(String id) => run((token) async {
        await api.post('/api/books/${Uri.encodeComponent(id)}/write-metadata',
            cancelToken: token);
      });

  Future<Book> save(String id, Map<String, dynamic> metadata,
          {List<int>? coverBytes, String? coverName, Book? original}) =>
      run((token) async {
        final path = '/api/books/${Uri.encodeComponent(id)}';
        final response = coverBytes == null
            ? await api.patch(path, data: metadata, cancelToken: token)
            : await api.post('$path/cover',
                cancelToken: token,
                data: FormData.fromMap({
                  'file': MultipartFile.fromBytes(coverBytes,
                      filename: coverName ?? 'cover.jpg'),
                  'metadata': jsonEncode(metadata),
                }));
        return Book.fromJson({
          ...asMap(response.data),
          if (original != null) ...{
            'library_type': original.libraryType,
            'can_write_metadata_files': original.canWriteMetadataFiles,
            'is_favorite': original.isFavorite,
          },
        });
      });

  Future<Map<String, dynamic>> generateRegex(
          String filename, String number, String title) =>
      run((token) async {
        final response = await api.post('/api/tools/regex/generate',
            cancelToken: token,
            data: {
              'filename': filename,
              'chapter_number': number,
              'chapter_title': title
            });
        return asMap(response.data);
      });

  void dispose() {
    _disposed = true;
    for (final token in _requests) {
      token.cancel('Book operation owner disposed');
    }
    _requests.clear();
  }
}

/// Requests and cache for one book. Paging cancels its predecessor and full
/// catalogue consumers share one request until an edit invalidates the cache.
class ChapterCatalogue {
  ChapterCatalogue(this.api, this.bookId);
  final ApiClient api;
  final String bookId;
  CancelToken? _pageToken;
  CancelToken? _allToken;
  Future<List<Chapter>?>? _pending;
  List<Chapter>? _cached;
  bool _disposed = false;

  Future<ChaptersPage?> page(Map<String, dynamic> params) async {
    if (_disposed) return null;
    _pageToken?.cancel('Chapter page replaced');
    final token = CancelToken();
    _pageToken = token;
    try {
      final response = await api.get(
          '/api/books/${Uri.encodeComponent(bookId)}/chapters',
          params: params,
          cancelToken: token);
      if (_disposed || token.isCancelled) return null;
      return ChaptersPage.fromJson(asMap(response.data));
    } on DioException {
      if (_disposed || token.isCancelled) return null;
      rethrow;
    } finally {
      if (identical(_pageToken, token)) _pageToken = null;
    }
  }

  Future<List<Chapter>?> all() {
    if (_disposed) return Future.value(null);
    if (_cached != null) return Future.value(_cached);
    return _pending ??= _loadAll();
  }

  Future<List<Chapter>?> _loadAll() async {
    final token = CancelToken();
    _allToken = token;
    try {
      final response = await api.get(
          '/api/books/${Uri.encodeComponent(bookId)}/chapters',
          cancelToken: token);
      if (_disposed || token.isCancelled) return null;
      _cached = sortChaptersForPlayback(
          asMapList(response.data).map(Chapter.fromJson));
      return _cached;
    } on DioException {
      if (_disposed || token.isCancelled) return null;
      rethrow;
    } finally {
      if (identical(_allToken, token)) {
        _allToken = null;
        _pending = null;
      }
    }
  }

  void invalidate() {
    _pageToken?.cancel('Chapter catalogue invalidated');
    _allToken?.cancel('Chapter catalogue invalidated');
    _allToken = null;
    _pending = null;
    _cached = null;
  }

  void dispose() {
    _disposed = true;
    invalidate();
  }
}

class BookDetailState extends ChangeNotifier {
  BookDetailState(this.api, this.bookId)
      : catalogue = ChapterCatalogue(api, bookId),
        operations = BookOperations(api);
  final ApiClient api;
  final String bookId;
  final ChapterCatalogue catalogue;
  final BookOperations operations;
  CancelToken? _loadToken;
  bool _disposed = false;
  bool loading = true;
  bool pageLoading = false;
  String? error;
  Book? book;
  ProgressItem? progress;
  Map<String, dynamic> settings = {};
  List<Chapter> chapters = [];
  int total = 0;
  int mainTotal = 0;
  int extraTotal = 0;
  String tab = 'main';
  int group = 0;
  bool ascending = true;
  bool groupsDescending = false;
  List<ChapterGroupOrderEntry> groupOrders = [];
  static const pageSize = 100;
  int _pageRevision = 0;
  bool _favoritePending = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({String? initialChapter}) async {
    if (_disposed) return;
    _loadToken?.cancel('Book details reloaded');
    _pageRevision++;
    pageLoading = false;
    catalogue.invalidate();
    final token = CancelToken();
    _loadToken = token;
    loading = true;
    error = null;
    _notify();
    try {
      final results = await Future.wait<dynamic>([
        api.get('/api/books/${Uri.encodeComponent(bookId)}',
            cancelToken: token),
        api
            .get('/api/progress/${Uri.encodeComponent(bookId)}',
                cancelToken: token)
            .then<ProgressItem?>(
                (response) => ProgressItem.fromJson(asMap(response.data)))
            .catchError((_) => null),
        api.get('/api/settings', cancelToken: token),
      ]);
      if (_disposed || token.isCancelled) return;
      book = Book.fromJson(asMap((results[0] as Response).data));
      progress = results[1] as ProgressItem?;
      settings = asMap(asMap((results[2] as Response).data)['settings_json']);
      groupOrders = readChapterGroupOrders(settings);
      final order = findChapterGroupOrder(groupOrders, bookId) ??
          (book?.libraryType == 'rss' ? 'desc' : 'asc');
      ascending = order == 'asc';
      groupsDescending = !ascending;
      tab = 'main';
      group = 0;
      chapters = [];
      total = mainTotal = extraTotal = 0;
      await loadPage(
          target: initialChapter,
          preferLast: groupsDescending && initialChapter == null);
    } catch (failure) {
      if (!_disposed && !token.isCancelled) {
        error = ApiError.messageFor(failure);
      }
    } finally {
      if (identical(_loadToken, token) && !_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<ChaptersPage?> loadPage(
      {String? requestedTab,
      int? requestedGroup,
      String? target,
      bool preferLast = false}) async {
    if (_disposed || book == null) return null;
    final revision = ++_pageRevision;
    pageLoading = true;
    _notify();
    try {
      final page = await catalogue.page({
        'limit': pageSize,
        'offset': (requestedGroup ?? group) * pageSize,
        'order': 'asc',
        if (target == null || requestedTab != null)
          'chapter_type': requestedTab ?? tab,
        if (target != null) 'target_chapter_id': target,
      });
      if (page == null || _disposed || revision != _pageRevision) return null;
      total = page.total;
      mainTotal = page.mainTotal;
      extraTotal = page.extraTotal;
      tab = page.chapterType == 'extra' ? 'extra' : 'main';
      group = page.offset ~/ pageSize;
      final last = lastGroup(tab);
      if (preferLast && target == null && group != last) {
        return await loadPage(requestedTab: tab, requestedGroup: last);
      }
      chapters = page.chapters;
      return page;
    } catch (failure) {
      if (!_disposed && revision == _pageRevision) {
        error = ApiError.messageFor(failure);
      }
      return null;
    } finally {
      if (!_disposed && revision == _pageRevision) {
        pageLoading = false;
        _notify();
      }
    }
  }

  int lastGroup(String tab) {
    final count = tab == 'extra' ? extraTotal : mainTotal;
    return count <= 0 ? 0 : (count - 1) ~/ pageSize;
  }

  Future<Chapter?> resolveResume(String? initial, Chapter? current) async {
    if (current?.bookId == bookId) return current;
    for (final id in [initial, progress?.chapterId].whereType<String>()) {
      final local = chapters.where((chapter) => chapter.id == id).firstOrNull;
      if (local != null) return local;
      final page = await loadPage(target: id);
      if (_disposed) return null;
      final found =
          page?.chapters.where((chapter) => chapter.id == id).firstOrNull;
      if (found != null) return found;
    }
    return null;
  }

  Future<void> toggleFavorite() async {
    final current = book;
    if (_disposed || current == null || _favoritePending) return;
    _favoritePending = true;
    try {
      await operations.favorite(bookId, !current.isFavorite);
      if (_disposed) return;
      book = book?.copyWith(isFavorite: !current.isFavorite);
      _notify();
    } finally {
      _favoritePending = false;
    }
  }

  Future<Book> save(Map<String, dynamic> values,
      {List<int>? coverBytes,
      String? coverName,
      required String groupOrder,
      required Future<void> Function(Map<String, dynamic>)
          saveSettings}) async {
    final current = book;
    final response = await operations.save(bookId, values,
        coverBytes: coverBytes, coverName: coverName, original: current);
    final saved = response.copyWith(isFavorite: book?.isFavorite);
    if (_disposed) return saved;
    book = saved;
    if (findChapterGroupOrder(groupOrders, bookId) != groupOrder) {
      final next = upsertChapterGroupOrder(groupOrders, bookId, groupOrder);
      await saveSettings(
          {'chapter_group_orders': serializeChapterGroupOrders(next)});
      if (_disposed) return saved;
      groupOrders = next;
    }
    if ((groupsDescending ? 'desc' : 'asc') != groupOrder) {
      groupsDescending = groupOrder == 'desc';
      ascending = !groupsDescending;
      group = groupsDescending ? lastGroup(tab) : 0;
    }
    catalogue.invalidate();
    _notify();
    return saved;
  }

  @override
  void dispose() {
    _disposed = true;
    _pageRevision++;
    _loadToken?.cancel('Book details closed');
    catalogue.dispose();
    operations.dispose();
    super.dispose();
  }
}

typedef ChapterGroupOrderEntry = Map<String, String>;

String? normalizeChapterGroupOrder(dynamic value) {
  final text = value?.toString();
  return text == 'asc' || text == 'desc' ? text : null;
}

List<ChapterGroupOrderEntry> readChapterGroupOrders(
  Map<String, dynamic> settings,
) {
  final raw = settings['chapter_group_orders'];
  if (raw is Iterable) {
    return raw.expand<ChapterGroupOrderEntry>((entry) {
      final item = asMap(entry);
      final bookId = item['book_id']?.toString() ?? '';
      final order = normalizeChapterGroupOrder(item['order']);
      return bookId.isNotEmpty && order != null
          ? [
              {'book_id': bookId, 'order': order},
            ]
          : const [];
    }).toList(growable: false);
  }
  final rawMap = asMap(raw);
  if (rawMap.isNotEmpty) {
    return rawMap.entries.expand<ChapterGroupOrderEntry>((entry) {
      final order = normalizeChapterGroupOrder(entry.value);
      return order != null
          ? [
              {'book_id': entry.key, 'order': order},
            ]
          : const [];
    }).toList(growable: false);
  }
  return const [];
}

String? findChapterGroupOrder(
  List<ChapterGroupOrderEntry> orders,
  String bookId,
) {
  for (final entry in orders) {
    if (entry['book_id'] == bookId) return entry['order'];
  }
  return null;
}

List<ChapterGroupOrderEntry> upsertChapterGroupOrder(
  List<ChapterGroupOrderEntry> orders,
  String bookId,
  String order,
) {
  var found = false;
  final next = orders.map<ChapterGroupOrderEntry>((entry) {
    if (entry['book_id'] != bookId) return {...entry};
    found = true;
    return {'book_id': bookId, 'order': order};
  }).toList();
  if (!found) next.add({'book_id': bookId, 'order': order});
  return next;
}

List<Map<String, String>> serializeChapterGroupOrders(
  List<ChapterGroupOrderEntry> orders,
) {
  return orders
      .map((entry) => {
            'book_id': entry['book_id'] ?? '',
            'order': entry['order'] ?? 'asc',
          })
      .where((entry) => entry['book_id']?.isNotEmpty == true)
      .toList(growable: false);
}

/// Shelf data and ordering rules. Selection, scrolling and overlays are UI state.
class BookshelfState extends ChangeNotifier {
  BookshelfState(this.api) : operations = BookOperations(api);
  final ApiClient api;
  final BookOperations operations;
  CancelToken? _loadToken;
  bool _disposed = false;
  bool loading = true;
  String? error;
  List<Book> books = [];
  List<Series> series = [];
  List<Library> libraries = [];
  Map<String, dynamic> settings = {};
  String selectedLibrary = '';
  String sortBy = 'created_at';
  String searchQuery = '';

  Future<void> load() async {
    if (_disposed) return;
    _loadToken?.cancel('Shelf query replaced');
    final token = CancelToken();
    _loadToken = token;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final initial = await Future.wait([
        api.get('/api/settings', cancelToken: token),
        api.get('/api/libraries', cancelToken: token),
      ]);
      if (_disposed || token.isCancelled) return;
      final payload = asMap(initial[0].data);
      final nextSettings = {...asMap(payload['settings_json']), ...payload}
        ..remove('settings_json');
      final nextLibraries =
          asMapList(initial[1].data).map(Library.fromJson).toList();
      var library = (nextSettings['bookshelf_library_id'] ?? '').toString();
      if (!nextLibraries.any((item) => item.id == library)) library = '';
      final params = {if (library.isNotEmpty) 'library_id': library};
      final results = await Future.wait([
        api.get('/api/books', params: params, cancelToken: token),
        api.get('/api/v1/series', params: params, cancelToken: token),
      ]);
      if (_disposed || token.isCancelled) return;
      settings = nextSettings;
      libraries = nextLibraries;
      selectedLibrary = library;
      sortBy = (settings['bookshelf_sort_by'] ?? 'created_at').toString();
      books = asMapList(results[0].data).map(Book.fromJson).toList();
      series = asMapList(results[1].data).map(Series.fromJson).toList();
    } catch (failure) {
      if (!_disposed && !token.isCancelled) {
        error = ApiError.messageFor(failure);
      }
    } finally {
      if (!_disposed && identical(_loadToken, token)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  List<Book> get sortedBooks {
    final result = [...books];
    result.sort((a, b) {
      if (sortBy == 'title') return compareChineseText(a.title, b.title);
      if (sortBy == 'author') {
        return compareChineseText(a.author ?? '', b.author ?? '');
      }
      if (sortBy == 'year') return (b.year ?? 0).compareTo(a.year ?? 0);
      final ad = DateTime.tryParse(a.createdAt ?? '') ?? DateTime(1970);
      final bd = DateTime.tryParse(b.createdAt ?? '') ?? DateTime(1970);
      return bd.compareTo(ad);
    });
    return result;
  }

  List<Book> get filteredBooks {
    final booksInSeries =
        series.expand((item) => item.books.map((book) => book.id)).toSet();
    final query = searchQuery.trim().toLowerCase();
    return sortedBooks.where((book) {
      if (booksInSeries.contains(book.id)) return false;
      if (query.isEmpty) return true;
      return book.title.toLowerCase().contains(query) ||
          (book.author ?? '').toLowerCase().contains(query) ||
          (book.narrator ?? '').toLowerCase().contains(query);
    }).toList();
  }

  List<Series> get filteredSeries {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return series;
    return series.where((series) {
      return series.title.toLowerCase().contains(query) ||
          (series.author ?? '').toLowerCase().contains(query);
    }).toList();
  }

  /// Groups the filtered books and series by pinyin initial (or year) for the
  /// active sort mode, mirroring the web client's bookshelf grouping.
  ({List<String> keys, Map<String, List<Object>> groups})? get groupedContent {
    if (sortBy == 'created_at') return null;

    final groups = <String, List<Object>>{};
    for (final book in filteredBooks) {
      final String key;
      if (sortBy == 'author') {
        key = pinyinInitial(book.author ?? '');
      } else if (sortBy == 'year') {
        key = _yearGroupKey(book.year);
      } else {
        key = pinyinInitial(book.title);
      }
      groups.putIfAbsent(key, () => []).add(book);
    }
    for (final item in filteredSeries) {
      final String key;
      if (sortBy == 'author') {
        key = pinyinInitial(item.author ?? '');
      } else if (sortBy == 'year') {
        key = '#';
      } else {
        key = pinyinInitial(item.title);
      }
      groups.putIfAbsent(key, () => []).add(item);
    }

    for (final items in groups.values) {
      items.sort((a, b) {
        if (sortBy == 'author') {
          return compareChineseText(_itemAuthor(a), _itemAuthor(b));
        }
        if (sortBy == 'year') return _itemYear(b).compareTo(_itemYear(a));
        return compareChineseText(_itemTitle(a), _itemTitle(b));
      });
    }

    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        if (sortBy == 'year') return b.compareTo(a);
        return a.compareTo(b);
      });
    return (keys: keys, groups: groups);
  }

  static String _yearGroupKey(int? year) {
    if (year == null) return '#';
    final text = year.toString();
    return text.length > 2 ? text.substring(text.length - 2) : text;
  }

  static String _itemTitle(Object item) =>
      item is Book ? item.title : (item as Series).title;

  static String _itemAuthor(Object item) =>
      item is Book ? (item.author ?? '') : ((item as Series).author ?? '');

  static int _itemYear(Object item) => item is Book ? (item.year ?? 0) : 0;

  @override
  void dispose() {
    _disposed = true;
    _loadToken?.cancel('Shelf closed');
    operations.dispose();
    super.dispose();
  }
}
