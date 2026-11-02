import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/l10n/app_localizations.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';
import 'package:ting_reader_flutter/src/core/models/models.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/core/state/books_state.dart';
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';
import 'package:ting_reader_flutter/src/core/state/search_state.dart';
import 'package:ting_reader_flutter/src/features/admin/admin_pages.dart';
import 'package:ting_reader_flutter/src/features/bookshelf/bookshelf_page.dart';
import 'package:ting_reader_flutter/src/features/bookshelf/search_page.dart';
import 'package:ting_reader_flutter/src/features/bookshelf/book_detail/book_detail_page.dart';
import 'package:ting_reader_flutter/src/features/player/mini_player.dart';
import 'package:ting_reader_flutter/src/shared/app_scope.dart';
import 'package:ting_reader_flutter/src/shared/cards/book_card.dart';

const _sourceLibrary = {
  'id': 'source-library',
  'name': 'Source Library',
  'library_type': 'source',
};
const _shelfBook = {
  'id': 'shelf-book',
  'library_id': 'source-library',
  'title': 'Shelf Book',
  'author': 'Shelf Author',
};
const _onlineBook = {
  'id': 'book',
  'library_id': 'source-library',
  'library_type': 'source',
  'title': 'Online Book',
  'author': 'An Author With An Extremely Long Display Name',
  'narrator': 'A Narrator With An Extremely Long Display Name',
};

class _SourceApi extends ApiClient {
  final bookMetadata = <String, dynamic>{};
  int chapterTotal = 205;
  final searches = <Map<String, dynamic>>[];
  final queries = <Map<String, dynamic>>[];
  final adds = <Object?>[];
  final scans = <Object?>[];
  final deletes = <Map<String, dynamic>>[];
  final tokens = <CancelToken>[];
  final chapterQueries = <Map<String, dynamic>>[];
  final pendingSearches = <String, Completer<Response<dynamic>>>{};
  final failSources = <String>{};
  Completer<Response<dynamic>>? pendingAdd;
  bool shelfDeleted = false;
  bool failBookshelf = false;
  bool failSourceLoad = false;

  Response<dynamic> response(String path, Object? data) =>
      Response(requestOptions: RequestOptions(path: path), data: data);

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) async {
    if (cancelToken != null) tokens.add(cancelToken);
    if (path == '/api/v1/scraper/sources') {
      if (failSourceLoad) throw StateError('Source registry unavailable');
      return response(path, {
        'sources': [
          for (final id in ['alpha', 'beta', 'scraper', 'disabled'])
            {
              'id': id,
              'name': id,
              'enabled': id != 'disabled',
              'book_source': id != 'scraper',
            },
        ],
      });
    }
    if (path == '/api/books') {
      queries.add({...?params});
      if (failBookshelf && params?['search'] != null) {
        throw StateError('Bookshelf unavailable');
      }
      return response(path, shelfDeleted ? [] : [_shelfBook]);
    }
    if (path == '/api/libraries') return response(path, [_sourceLibrary]);
    if (path == '/api/settings') return response(path, {'settings_json': {}});
    if (path == '/api/books/book') {
      return response(path, {..._onlineBook, ...bookMetadata});
    }
    if (path.endsWith('/chapters')) {
      chapterQueries.add({...?params});
      final target = params?['target_chapter_id']?.toString();
      final offset = target != null
          ? ((int.parse(target.substring(1)) - 1) ~/ 100) * 100
          : (params?['offset'] as int? ?? 0);
      final count = (205 - offset).clamp(0, 100);
      return response(path, {
        'chapters': [
          for (var i = 1; i <= count; i++)
            {
              'id': 'c${offset + i}',
              'book_id': 'book',
              'title': 'Chapter ${offset + i}',
              'chapter_index': offset + i
            },
        ],
        'total': chapterTotal,
        'main_total': chapterTotal,
        'extra_total': 0,
        'offset': offset,
        'limit': 100,
        'chapter_type': 'main',
      });
    }
    return response(path, []);
  }

  @override
  Future<Response<dynamic>> post(String path,
      {Object? data,
      Map<String, dynamic>? params,
      CancelToken? cancelToken,
      Duration? receiveTimeout}) async {
    if (cancelToken != null) tokens.add(cancelToken);
    if (path == '/api/v1/scraper/search') {
      final body = asMap(data);
      searches.add(body);
      final source = body['source'].toString();
      if (failSources.contains(source)) throw StateError('$source unavailable');
      final pending = pendingSearches[body['query']];
      if (pending != null) return pending.future;
      return response(path, {
        'items': [
          {
            'id': '$source-book',
            'title': '$source Book',
            'author': 'Author $source',
            'narrator': 'Narrator $source',
            'source_url': 'https://example.test/$source'
          },
        ],
        'has_more': body['page'] == 1,
        'page_size': 20,
      });
    }
    if (path == '/api/v1/scraper/books') {
      adds.add(data);
      final pending = pendingAdd;
      return pending == null
          ? response(path, {'book_id': 'added-book'})
          : pending.future;
    }
    if (path.endsWith('/scan')) {
      scans.add(data);
      return response(path, {});
    }
    return response(path, {});
  }

  @override
  Future<Response<dynamic>> delete(String path,
      {Object? data,
      Map<String, dynamic>? params,
      CancelToken? cancelToken}) async {
    deletes.add({'path': path, ...?params});
    shelfDeleted = true;
    return response(path, {});
  }
}

class _SourceApp extends AppState {
  final sourceApi = _SourceApi();
  @override
  _SourceApi get api => sourceApi;
}

class _SourcePlayer extends ChangeNotifier implements PlayerState {
  @override
  Book? currentBook;
  @override
  Chapter? currentChapter;
  @override
  List<Chapter> chapters = [];
  @override
  bool get hasChapter => currentChapter != null;
  @override
  bool isExpanded = true;
  @override
  bool isPlaying = false;
  @override
  double currentTime = 0;
  @override
  double duration = 120;
  @override
  double volume = 1;
  @override
  double playbackSpeed = 1;
  @override
  String? error;
  @override
  int? get sleepRemainingSeconds => null;
  @override
  int? get sleepEpisodesRemaining => null;
  @override
  Future<void> playChapter(Book book, List<Chapter> items, Chapter chapter,
      {double? startAt}) async {
    currentBook = book;
    currentChapter = chapter;
    chapters = items;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, Widget page,
    {double width = 390,
    bool english = false,
    _SourceApp? app,
    _SourcePlayer? playerState}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final state = app ?? _SourceApp();
  final downloads = DownloadState(state);
  final player = playerState ?? _SourcePlayer();
  addTearDown(state.dispose);
  addTearDown(downloads.dispose);
  addTearDown(player.dispose);
  await tester.pumpWidget(AppScope(
    appState: state,
    downloadState: downloads,
    playerState: player,
    child: MaterialApp(
      locale: Locale(english ? 'en' : 'zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: page),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('only enabled book sources are selected; bookshelf is the default',
      () async {
    final api = _SourceApi();
    final state = SearchState(api);
    addTearDown(state.dispose);
    await state.load();
    expect(state.scope, SearchScope.bookshelf);
    expect(state.sources.map((source) => source.id), ['alpha', 'beta']);
    expect(state.selectedSourceIds, {'alpha', 'beta'});
    expect(state.libraries.single.isSource, isTrue);
    state.query = 'Book';
    await state.search();
    expect(state.books.single.id, 'shelf-book');
    expect(api.searches, isEmpty);
  });

  test(
      'all scope ignores bookshelf filters; online supports multiple sources and paging',
      () async {
    final api = _SourceApi();
    final state = SearchState(api);
    addTearDown(state.dispose);
    await state.load();
    state.query = 'Book';
    state.author = 'Other Author';
    state.libraryId = 'other-library';
    state.tag = 'other-tag';
    await state.setScope(SearchScope.all);
    expect(state.showFilters, isFalse);
    expect(state.books, hasLength(1));
    expect(api.queries.last, {'search': 'Book'});
    expect(state.sourceBooks.map((book) => book.sourceId), ['alpha', 'beta']);
    expect(state.hasMore, isTrue);
    await state.search(requestedPage: 2);
    expect(api.searches.last['page'], 2);
    expect(state.hasMore, isFalse);
    await state.setScope(SearchScope.online);
    await state.selectSources(['beta']);
    expect(state.sourceBooks.single.sourceId, 'beta');
    expect(state.books, isEmpty);
    expect(state.page, 1);
    await state.selectSources([]);
    expect(state.sourceBooks, isEmpty);
    await state.setScope(SearchScope.bookshelf);
    expect(state.books, isEmpty);
    expect(api.queries.last['library_id'], 'other-library');
    expect(api.queries.last['tag'], 'other-tag');
  });

  test(
      'one failed source does not discard successful source or bookshelf results',
      () async {
    final api = _SourceApi()..failSources.add('alpha');
    final state = SearchState(api);
    addTearDown(state.dispose);
    await state.load();
    state.query = 'Book';
    await state.setScope(SearchScope.all);
    expect(state.sourceErrors.single, contains('alpha'));
    expect(state.sourceBooks.single.sourceId, 'beta');
    expect(state.books, hasLength(1));
    api.failBookshelf = true;
    await state.search();
    expect(state.bookshelfError, isNotNull);
    expect(state.sourceBooks.single.sourceId, 'beta');
  });

  test('source registry failure leaves bookshelf search available', () async {
    final api = _SourceApi()..failSourceLoad = true;
    final state = SearchState(api);
    addTearDown(state.dispose);
    await state.load();
    expect(state.loading, isFalse);
    expect(state.sourceLoadError, isNotNull);
    state.query = 'Book';
    await state.search();
    expect(state.books, hasLength(1));
  });

  test(
      'superseded requests cannot replace new results; dispose cancels requests',
      () async {
    final api = _SourceApi();
    final state = SearchState(api);
    await state.load();
    state.scope = SearchScope.online;
    state.query = 'old';
    final pending = Completer<Response<dynamic>>();
    api.pendingSearches['old'] = pending;
    final old = state.search();
    state.query = 'new';
    await state.search();
    pending.complete(api.response('/api/v1/scraper/search', {
      'items': [
        {'id': 'old-book', 'title': 'Old Book'}
      ],
    }));
    await old;
    expect(
        state.sourceBooks.every((book) => book.book.id != 'old-book'), isTrue);
    state.query = 'pending';
    final later = Completer<Response<dynamic>>();
    api.pendingSearches['pending'] = later;
    final loading = state.search();
    final token = api.tokens.last;
    state.dispose();
    expect(token.isCancelled, isTrue);
    later.complete(api.response('/api/v1/scraper/search', {'items': []}));
    await loading;
  });

  test(
      'adding is deduplicated and updates matching results after another search',
      () async {
    final api = _SourceApi();
    final state = SearchState(api);
    addTearDown(state.dispose);
    await state.load();
    state.query = 'Book';
    await state.setScope(SearchScope.online);
    final item = state.sourceBooks.first;
    final pending = Completer<Response<dynamic>>();
    api.pendingAdd = pending;
    final add = state.addBook(item);
    await state.addBook(item);
    expect(api.adds, hasLength(1));
    expect(api.adds.single, {
      'source': 'alpha',
      'book': {'id': 'alpha-book', 'url': 'https://example.test/alpha'},
    });
    await state.search();
    pending.complete(
        api.response('/api/v1/scraper/books', {'book_id': 'added-book'}));
    await add;
    expect(state.adding, isEmpty);
    expect(state.sourceBooks.first.addedBookId, 'added-book');
    await state.search();
    expect(state.sourceBooks.first.added, isTrue);
    expect(api.queries.every((query) => !query.containsKey('limit')), isTrue);
  });

  test('online chapter window loads only adjacent pages, forward and backward',
      () async {
    final api = _SourceApi();
    final catalogue = ChapterCatalogue(api, 'book');
    addTearDown(catalogue.dispose);
    Chapter chapter(int index) => Chapter(
        id: 'c$index',
        bookId: 'book',
        title: 'Chapter $index',
        path: '',
        chapterIndex: index);
    final next = await catalogue.adjacentPage(chapter(100), 1);
    expect(next?.offset, 100);
    expect(next?.chapters.first.id, 'c101');
    final previous = await catalogue.adjacentPage(chapter(101), -1);
    expect(previous?.chapters.last.id, 'c100');
    final last = await catalogue.adjacentPage(chapter(205), 1);
    expect(last, isNull);
    expect(await catalogue.adjacentPage(chapter(1), -1), isNull);
  });

  for (final width in [320.0, 768.0, 1280.0]) {
    for (final english in [false, true]) {
      testWidgets(
          'search tabs, multi-source menu and split results fit $width / $english',
          (tester) async {
        final app = _SourceApp();
        await _pump(tester, SearchPage(openBook: (_) {}, onBack: () {}),
            width: width, english: english, app: app);
        expect(find.text(english ? 'Bookshelf' : '书架'), findsOneWidget);
        expect(find.text('本地'), findsNothing);
        expect(find.text('本地书架'), findsNothing);
        await tester.enterText(find.byType(TextField), 'Book');
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        await tester.tap(find.text(english ? 'All' : '全部'));
        await tester.pumpAndSettle();
        expect(find.text(english ? 'Bookshelf' : '书架'), findsNWidgets(2));
        expect(find.text(english ? 'Online' : '在线'), findsNWidgets(2));
        expect(find.text(english ? 'Show Filters' : '展开筛选'), findsNothing);
        expect(find.byType(BookCard), findsNWidgets(3));
        expect(find.text('Narrator alpha'), findsNothing);
        final onlineTab = find.ancestor(
            of: find.text(english ? 'Online' : '在线').first,
            matching: find.byType(TextButton));
        await tester.tap(onlineTab);
        await tester.pumpAndSettle();
        expect(find.byType(CheckboxMenuButton), findsNWidgets(3));
        await tester.tap(find.text('alpha'));
        await tester.pumpAndSettle();
        expect(find.byType(CheckboxMenuButton), findsNWidgets(3));
        expect(app.api.searches.last['source'], 'beta');
        await tester.tap(find.text('beta'));
        await tester.pumpAndSettle();
        expect(find.text(english ? 'Select online sources' : '请选择在线书源'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    for (final english in [false, true]) {
      testWidgets(
          'metadata uses available space before ellipsis at $width / $english',
          (tester) async {
        final app = _SourceApp();
        app.api.bookMetadata.addAll({'author': 'A', 'narrator': 'Narrator'});
        app.api.chapterTotal = 1332;
        await _pump(tester, BookDetailPage(bookId: 'book', onBack: () {}),
            width: width, english: english, app: app);
        final chapterLabel = find.text(english ? '1332 chapters' : '1332 章节');
        expect(chapterLabel, findsOneWidget);
        for (final finder in [
          find.text('A'),
          find.text('Narrator'),
          chapterLabel
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          if (finder == chapterLabel ||
              width >= 768 ||
              (width >= 390 && !english)) {
            expect(paragraph.didExceedMaxLines, isFalse);
          }
          expect(tester.getCenter(finder).dy,
              closeTo(tester.getCenter(chapterLabel).dy, 1));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [320.0, 1280.0]) {
    testWidgets('online book metadata stays on one line at $width',
        (tester) async {
      final app = _SourceApp();
      await _pump(tester, BookDetailPage(bookId: 'book', onBack: () {}),
          width: width, app: app);
      final author = find.text(_onlineBook['author'] as String);
      final narrator = find.text(_onlineBook['narrator'] as String);
      expect(author, findsOneWidget);
      expect(narrator, findsOneWidget);
      expect(tester.getCenter(author).dy,
          closeTo(tester.getCenter(narrator).dy, 1));
      expect(tester.widget<Text>(author).maxLines, 1);
      expect(tester.widget<Text>(narrator).overflow, TextOverflow.ellipsis);
      final count = find.textContaining('205');
      expect(
          tester.renderObject<RenderParagraph>(count.first).didExceedMaxLines,
          isFalse);
      expect(app.api.chapterQueries, hasLength(1));
      expect(app.api.chapterQueries.single['limit'], 100);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'online player chapter selector shows unloaded groups at $width',
        (tester) async {
      final app = _SourceApp();
      final player = _SourcePlayer()
        ..currentBook = Book.fromJson(_onlineBook)
        ..currentChapter = const Chapter(
            id: 'c100',
            bookId: 'book',
            title: 'Chapter 100',
            path: 'source:100',
            chapterIndex: 100)
        ..chapters = [
          for (var i = 1; i <= 100; i++)
            Chapter(
                id: 'c$i',
                bookId: 'book',
                title: 'Chapter $i',
                path: 'source:$i',
                chapterIndex: i)
        ];
      await _pump(tester, const ExpandedPlayerOverlay(),
          width: width, app: app, playerState: player);
      await tester.tap(find.text('选集'));
      await tester.pumpAndSettle();
      expect(find.text('第 201-205 章'), findsOneWidget);
      final lastGroup = find.text('第 201-205 章');
      await tester.ensureVisible(lastGroup);
      await tester.tap(lastGroup);
      await tester.pumpAndSettle();
      expect(app.api.chapterQueries.last['offset'], 200);
      expect(find.text('Chapter 201'), findsOneWidget);
      await tester.tap(find.text('Chapter 201'));
      await tester.pumpAndSettle();
      expect(player.currentChapter?.id, 'c201');
      expect(player.chapters, hasLength(5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('bookshelf selection count lives in actions at $width',
        (tester) async {
      await _pump(
          tester,
          BookshelfPage(
              openBook: (_) {},
              openSeries: (_) {},
              openLibraries: () {},
              openSearch: () {}),
          width: width);
      await tester.tap(find.text(width < 560 ? '选择' : '选择模式'));
      await tester.pumpAndSettle();
      expect(find.text('操作（0）'), findsOneWidget);
      await tester.tap(find.text('全选'));
      await tester.pumpAndSettle();
      expect(find.text('操作（1）'), findsOneWidget);
      expect(find.textContaining('已选'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'source library sync and editor manage books without WebDAV fields at $width',
        (tester) async {
      final app = _SourceApp();
      await _pump(tester, const AdminLibrariesPage(), width: width, app: app);
      expect(find.text('在线书源'), findsOneWidget);
      expect(find.text('WebDAV'), findsNothing);
      await tester.tap(find.text('同步'));
      await tester.pumpAndSettle();
      expect(app.api.scans.single, {'mode': 'incremental'});
      expect(find.text('增量同步'), findsNothing);
      await tester.tap(find.byTooltip('编辑存储库'));
      await tester.pumpAndSettle();
      expect(find.text('Shelf Book'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byTooltip('删除书籍'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('删除')));
      await tester.pumpAndSettle();
      expect(app.api.deletes.single, {
        'path': '/api/books/shelf-book',
        'delete_files': false,
      });
      expect(find.text('此书源尚未加入书籍'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
