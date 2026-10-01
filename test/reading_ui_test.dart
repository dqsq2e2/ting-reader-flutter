import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/l10n/app_localizations.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';
import 'package:ting_reader_flutter/src/core/models/models.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';
import 'package:ting_reader_flutter/src/features/bookshelf/bookshelf_page.dart';
import 'package:ting_reader_flutter/src/features/bookshelf/series_detail/series_detail_page.dart';
import 'package:ting_reader_flutter/src/features/mine/bookmarks_page.dart';
import 'package:ting_reader_flutter/src/features/mine/history_page.dart';
import 'package:ting_reader_flutter/src/features/mine/mine_page.dart';
import 'package:ting_reader_flutter/src/shared/app_scope.dart';
import 'package:ting_reader_flutter/src/shared/cards/book_card.dart';

class _ReadingApi extends ApiClient {
  final gets = <String>[];
  final deletes = <Map<String, dynamic>>[];
  final readStatuses = <Map<String, dynamic>>[];
  bool cleared = false;
  final pendingBookmarks = <String, Completer<Response<dynamic>>>{};
  bool includeOtherBook = false;
  int bookmarkCount = 1;
  final seriesUpdates = <Map<String, dynamic>>[];
  final bookDeletes = <Map<String, dynamic>>[];
  String seriesLibraryType = 'local';
  List<String> seriesBookIds = ['other-book', 'book', 'alpha-book'];
  final pendingSeries = <String, Completer<Response<dynamic>>>{};
  final settingsPayload = <String, dynamic>{};
  final statisticsPayload = <String, dynamic>{};

  Response<dynamic> _response(String path, dynamic value) =>
      Response(requestOptions: RequestOptions(path: path), data: value);

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) async {
    gets.add(path);
    if (pendingBookmarks.containsKey(path)) {
      return pendingBookmarks[path]!.future;
    }
    if (path == '/api/settings') return _response(path, settingsPayload);
    if (path == '/api/system/statistics') {
      return _response(path, statisticsPayload);
    }
    if (pendingSeries.containsKey(path)) return pendingSeries[path]!.future;
    if (path.startsWith('/api/v1/series/')) {
      return _response(path, {
        'id': path.split('/').last,
        'library_id': 'lib',
        'title': path.endsWith('/series') ? 'Test Series' : 'Other Series',
        'books': [
          for (final id in seriesBookIds)
            {
              'id': id,
              'library_id': 'lib',
              'library_type': seriesLibraryType,
              'title': switch (id) {
                'book' => 'Selected Book',
                'other-book' => 'Other Book',
                'alpha-book' => 'Alpha Book',
                _ => 'Book $id',
              },
              'progress_percent': readStatuses
                          .where((status) =>
                              (status['book_ids'] as List).contains(id))
                          .lastOrNull?['read'] ==
                      true
                  ? 100
                  : 0,
            },
        ],
      });
    }
    if (path == '/api/libraries') {
      return _response(path, [
        {'id': 'lib', 'name': 'Library', 'type': 'local'},
      ]);
    }
    if (path == '/api/v1/series') return _response(path, []);
    if (path == '/api/books') {
      return _response(path, [
        {
          'id': 'book',
          'library_id': 'lib',
          'title': 'Selected Book',
          'progress_percent': readStatuses.isEmpty ? 100 : 0,
        },
      ]);
    }
    if (path == '/api/history/books') {
      return _response(path, {
        'total': cleared ? 0 : 1,
        'items': cleared
            ? []
            : [
                {
                  'book_id': 'book',
                  'book_title': 'Large Book',
                  'chapter_count': 1500,
                  'latest_chapter_id': 'chapter-0',
                  'latest_chapter_title': 'Latest Chapter',
                  'latest_position': 90.0,
                  'latest_duration': 120.0,
                  'updated_at': '2026-09-30T00:00:00Z',
                }
              ],
      });
    }
    if (path == '/api/history/books/book/chapters') {
      final page = params?['page'] as int? ?? 1;
      return _response(path, {
        'total': 1500,
        'items': List.generate(50, (offset) {
          final index = (page - 1) * 50 + offset;
          return {
            'id': 'progress-$index',
            'book_id': 'book',
            'chapter_id': 'chapter-$index',
            'chapter_title': 'Chapter $index',
            'position': 30,
            'duration': 120,
            'updated_at': '2026-09-30T00:00:00Z',
          };
        }),
      });
    }
    if (path == '/api/bookmarks/books') {
      return _response(path, {
        'total': 1,
        'items': [
          {
            'book_id': 'book',
            'book_title': 'Book with bookmarks',
            'chapter_count': 1,
            'latest_chapter_title': 'Saved Chapter',
            'latest_position': 0,
            'latest_duration': 100,
          },
        ],
      });
    }
    if (path == '/api/bookmarks/books/book' ||
        path == '/api/bookmarks/books/other-book') {
      final bookId = path.split('/').last;
      return _response(path, {
        'total': bookmarkCount,
        'items': [
          for (var index = 0; index < bookmarkCount; index++)
            {
              'id': 'bookmark-$index',
              'book_id': bookId,
              'chapter_id': bookId == 'book' ? 'chapter' : 'other-chapter',
              'chapter_title':
                  bookId == 'book' ? 'Saved Chapter' : 'Other Chapter',
              'chapter_duration': 100,
              'position': 12.5,
              'note': 'Remember this',
            },
          if (includeOtherBook)
            {
              'id': 'incorrect-book',
              'book_id': bookId == 'book' ? 'other-book' : 'book',
              'chapter_id': 'incorrect-chapter',
              'chapter_title': 'Incorrect book entry',
              'position': 30,
            },
        ],
      });
    }
    if (path == '/api/books/book') {
      return _response(
          path, {'id': 'book', 'title': 'Book', 'library_id': 'lib'});
    }
    if (path == '/api/books/book/chapters') {
      return _response(path, [
        {
          'id': 'chapter',
          'book_id': 'book',
          'title': 'Saved Chapter',
          'duration': 120,
        }
      ]);
    }
    throw StateError('Unexpected API request: $path');
  }

  @override
  Future<Response<dynamic>> post(String path,
      {Object? data,
      Map<String, dynamic>? params,
      CancelToken? cancelToken,
      Duration? receiveTimeout}) async {
    if (path == '/api/books/read-status') {
      readStatuses.add(Map<String, dynamic>.from(data as Map));
      return _response(path, null);
    }
    if (path != '/api/progress/recent/delete') {
      throw StateError('Unexpected mutation: $path');
    }
    deletes.add(Map<String, dynamic>.from(data as Map));
    cleared = true;
    return _response(path, {'deleted': 1500});
  }

  @override
  Future<Response<dynamic>> put(String path, {Object? data}) async {
    if (!path.startsWith('/api/v1/series/')) {
      throw StateError('Unexpected mutation: $path');
    }
    final body = Map<String, dynamic>.from(data as Map);
    seriesUpdates.add(body);
    seriesBookIds = List<String>.from(body['book_ids'] as List);
    return _response(path, null);
  }

  @override
  Future<Response<dynamic>> delete(String path,
      {Object? data, Map<String, dynamic>? params}) async {
    if (!path.startsWith('/api/books/')) {
      throw StateError('Unexpected mutation: $path');
    }
    bookDeletes.add({'path': path, ...?params});
    seriesBookIds.remove(path.split('/').last);
    return _response(path, null);
  }
}

class _ReadingApp extends AppState {
  final _readingApi = _ReadingApi();

  @override
  _ReadingApi get api => _readingApi;
}

class _ReadingPlayer extends ChangeNotifier implements PlayerState {
  double? bookmarkPosition;
  int playCalls = 0;
  int seekCalls = 0;
  int resumeCalls = 0;
  @override
  Book? currentBook;
  @override
  Chapter? currentChapter;
  @override
  double currentTime = 6;
  @override
  bool isPlaying = true;
  @override
  String? error;

  @override
  Future<void> playChapter(Book book, List<Chapter> chapters, Chapter chapter,
      {double? startAt}) async {
    bookmarkPosition = startAt;
    playCalls++;
  }

  @override
  Future<void> seek(double position) async {
    seekCalls++;
    bookmarkPosition = position;
    currentTime = position;
  }

  @override
  Future<void> togglePlay() async {
    resumeCalls++;
    isPlaying = !isPlaying;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
    WidgetTester tester, _ReadingApp app, _ReadingPlayer player, Widget child,
    {bool settle = true}) async {
  final downloads = DownloadState(app);
  addTearDown(downloads.dispose);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AppScope(
      appState: app,
      downloadState: downloads,
      playerState: player,
      child: Scaffold(body: child),
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  const book = Book(id: 'book', libraryId: 'lib', title: 'Book');
  const chapter = Chapter(
      id: 'chapter',
      bookId: 'book',
      title: 'Chapter',
      path: '/server/chapter.strm',
      chapterIndex: 0);
  const otherBook =
      Book(id: 'other-book', libraryId: 'lib', title: 'Other Book');

  testWidgets('same STRM chapter bookmark seeks without reloading the source',
      (tester) async {
    final app = _ReadingApp();
    final player = _ReadingPlayer()
      ..currentBook = book
      ..currentChapter = chapter
      ..isPlaying = false;
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _pump(tester, app, player, const BookBookmarkPanel(book: book));
    await tester.tap(find.text('Remember this'));
    await tester.pumpAndSettle();
    expect(player.bookmarkPosition, 12.5);
    expect(player.seekCalls, 1);
    expect(player.playCalls, 0);
    expect(player.resumeCalls, 1);
    expect(app.api.gets, isNot(contains('/api/books/book/chapters')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('immersive bookmarks are compact and follow the playing book',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _ReadingApp();
    app.api.includeOtherBook = true;
    final player = _ReadingPlayer()
      ..currentBook = book
      ..currentChapter = chapter;
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _pump(tester, app, player, const BookBookmarkDialog());
    expect(find.text('Book'), findsOneWidget);
    expect(find.text('Saved Chapter'), findsOneWidget);
    expect(find.text('Incorrect book entry'), findsNothing);
    expect(find.text('0/2000'), findsNothing);
    expect(
        tester.getSize(find.byType(BookBookmarkPanel)).height, lessThan(400));

    player.currentBook = otherBook;
    player.currentChapter = const Chapter(
        id: 'other-chapter',
        bookId: 'other-book',
        title: 'Other Chapter',
        path: '/server/other.strm',
        chapterIndex: 0);
    player.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Saved Chapter'), findsNothing);
    expect(find.text('Other Book'), findsOneWidget);
    expect(find.text('Other Chapter'), findsOneWidget);
    expect(find.text('Incorrect book entry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old bookmark response cannot replace the new book list',
      (tester) async {
    final app = _ReadingApp();
    final oldResponse = Completer<Response<dynamic>>();
    app.api.pendingBookmarks['/api/bookmarks/books/book'] = oldResponse;
    final player = _ReadingPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    // Keep the same widget state to exercise didUpdateWidget, not just keys.
    final selected = ValueNotifier<Book>(book);
    addTearDown(selected.dispose);
    final panel = ValueListenableBuilder<Book>(
        valueListenable: selected,
        builder: (context, value, child) => BookBookmarkPanel(book: value));
    await _pump(tester, app, player, panel, settle: false);
    selected.value = otherBook;
    await tester.pumpAndSettle();
    expect(find.text('Other Chapter'), findsOneWidget);
    oldResponse.complete(Response(
        requestOptions: RequestOptions(path: '/api/bookmarks/books/book'),
        data: {
          'total': 1,
          'items': [
            {
              'book_id': 'book',
              'chapter_title': 'Late old bookmark',
              'position': 30,
            }
          ]
        }));
    await tester.pumpAndSettle();
    expect(find.text('Other Chapter'), findsOneWidget);
    expect(find.text('Late old bookmark'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('many immersive bookmarks scroll within mobile dialog bounds',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _ReadingApp();
    app.api.bookmarkCount = 40;
    final player = _ReadingPlayer()
      ..currentBook = book
      ..currentChapter = chapter;
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _pump(tester, app, player, const BookBookmarkDialog());
    expect(tester.getSize(find.byType(BookBookmarkPanel)).height,
        lessThanOrEqualTo(844 * 0.8));
    expect(find.byType(ListView), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cover progress only marks true zero and hundred as unread/read',
      (tester) async {
    final app = _ReadingApp();
    final player = _ReadingPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    for (final (percentage, label) in [
      (0.0, 'Unread'),
      (100.0, 'Read'),
      (99.9, '99%'),
      (0.1, '1%'),
    ]) {
      await _pump(
          tester,
          app,
          player,
          SizedBox(
            width: 180,
            child: BookCard(
              book: Book(
                  id: 'book',
                  libraryId: 'lib',
                  title: 'Book',
                  progressPercent: percentage),
              onTap: () {},
            ),
          ));
      expect(find.text(label), findsOneWidget);
    }
    app.settings = {
      'settings_json': {'bookshelf_progress_enabled': false}
    };
    await _pump(
        tester,
        app,
        player,
        SizedBox(
            width: 180,
            child: BookCard(
                book: const Book(
                    id: 'book',
                    libraryId: 'lib',
                    title: 'Book',
                    progressPercent: 100),
                onTap: () {})));
    expect(find.text('Read'), findsNothing);
  });

  testWidgets(
      '1500 chapter history is lazy, bounded and confirmed before clear',
      (tester) async {
    final app = _ReadingApp();
    final player = _ReadingPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _pump(
        tester,
        app,
        player,
        HistoryPage(
            openBook: (bookId, chapterId) {},
            onBack: () {},
            openBookshelf: () {}));
    expect(app.api.gets, isNot(contains('/api/history/books/book/chapters')));
    expect(find.text('Latest Chapter'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    await tester.tap(find.text('Large Book'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 0'), findsOneWidget);
    expect(find.text('Chapter 50'), findsNothing);
    final next = find.byTooltip('Next chapters');
    await tester.scrollUntilVisible(next, 400);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Chapter 0'), findsNothing);
    expect(find.text('Chapter 50'), findsOneWidget);
    final select = find.text('Select');
    await tester.scrollUntilVisible(select, -500);
    await tester.pumpAndSettle();
    await tester.tap(select);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(app.api.deletes, isEmpty);
    expect(find.text('Also clear playback progress'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(app.api.deletes.single['all'], isTrue);
    expect(app.api.deletes.single['clear_progress'], isTrue);
    expect(find.text('Large Book'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('book bookmark jumps to its exact fractional saved position',
      (tester) async {
    final app = _ReadingApp();
    final player = _ReadingPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _pump(
        tester,
        app,
        player,
        const BookBookmarkPanel(
            book: Book(id: 'book', libraryId: 'lib', title: 'Book')));
    await tester.tap(find.text('Remember this'));
    await tester.pumpAndSettle();
    expect(player.bookmarkPosition, 12.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookmark header hides position and expanded rows show progress',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _ReadingApp();
    final player = _ReadingPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _pump(tester, app, player, BookmarksPage(onBack: () {}));
    expect(find.text('Book with bookmarks'), findsOneWidget);
    expect(find.text('00:00:00'), findsNothing);
    expect(find.text('Saved Chapter'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(app.api.gets, isNot(contains('/api/bookmarks/books/book')));
    await tester.tap(find.text('Book with bookmarks'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Chapter'), findsOneWidget);
    expect(find.text('00:00:12'), findsOneWidget);
    expect(find.text('13%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unread menu requires confirmation and cancel preserves progress',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _ReadingApp();
    final player = _ReadingPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _pump(
        tester,
        app,
        player,
        BookshelfPage(
            openBook: (_) {},
            openSeries: (_) {},
            openLibraries: () {},
            openSearch: () {}));
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected Book'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as unread'), findsNothing);
    await tester.tap(find.byTooltip('Batch Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as unread'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('all their playback progress'), findsOneWidget);
    expect(app.api.readStatuses, isEmpty);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(app.api.readStatuses, isEmpty);
    await tester.tap(find.byTooltip('Batch Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as unread'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Mark as unread')));
    await tester.pumpAndSettle();
    expect(app.api.readStatuses.single['read'], isFalse);
    expect(app.api.readStatuses.single['book_ids'], ['book']);
    expect(find.text('Unread'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('series selection marks books through the operations menu',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final app = _ReadingApp();
    final player = _ReadingPlayer();
    final openedBooks = <String>[];
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _pump(
        tester,
        app,
        player,
        SeriesDetailPage(
            seriesId: 'series', onBack: () {}, openBook: openedBooks.add));
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as read'), findsNothing);
    await tester.tap(find.text('Selected Book'));
    await tester.pumpAndSettle();
    expect(openedBooks, isEmpty);
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Batch Actions'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from series'), findsNothing);
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(app.api.readStatuses.single, {
      'book_ids': ['book'],
      'read': true
    });
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('0 selected'), findsOneWidget);

    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected Book'));
    await tester.pumpAndSettle();
    expect(openedBooks, ['book']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('series unread confirmation cancels safely and clears on confirm',
      (tester) async {
    final app = _ReadingApp();
    final player = _ReadingPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _pump(tester, app, player,
        SeriesDetailPage(seriesId: 'series', onBack: () {}, openBook: (_) {}));
    await tester.tap(find.text('Select Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected Book'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Batch Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as unread'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('all their playback progress'), findsOneWidget);
    expect(app.api.readStatuses, isEmpty);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(app.api.readStatuses, isEmpty);
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Batch Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as unread'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Mark as unread')));
    await tester.pumpAndSettle();
    expect(app.api.readStatuses.single, {
      'book_ids': ['book'],
      'read': false
    });
    expect(tester.takeException(), isNull);
  });

  for (final deleteSourceFiles in [false, true]) {
    testWidgets(
        'series deletion uses bookshelf confirmation (source files: $deleteSourceFiles)',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = _ReadingApp()
        ..user = const User(id: 'admin', username: 'Admin', role: 'admin');
      app.api.settingsPayload['series_sort_by'] = 'title';
      final player = _ReadingPlayer();
      addTearDown(app.dispose);
      addTearDown(player.dispose);
      await _pump(
          tester,
          app,
          player,
          SeriesDetailPage(
              seriesId: 'series', onBack: () {}, openBook: (_) {}));
      expect(find.byTooltip('Manage Series'), findsOneWidget);
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selected Book'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha Book'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Batch Actions'));
      await tester.pumpAndSettle();
      expect(find.text('Remove from series'), findsNothing);
      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Remove 2 selected books'), findsOneWidget);
      expect(find.text('Delete local source files too'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(app.api.bookDeletes, isEmpty);
      expect(app.api.seriesUpdates, isEmpty);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      expect(app.api.bookDeletes, isEmpty);
      expect(find.text('2 selected'), findsOneWidget);
      expect(app.api.seriesUpdates, isEmpty);
      await tester.tap(find.byTooltip('Batch Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 300));
      if (deleteSourceFiles) {
        await tester.tap(find.byType(Checkbox));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Delete')));
      await tester.pumpAndSettle();
      expect(app.api.seriesUpdates, isEmpty);
      expect(app.api.bookDeletes, [
        {'path': '/api/books/book', 'delete_files': deleteSourceFiles},
        {'path': '/api/books/alpha-book', 'delete_files': deleteSourceFiles},
      ]);
      expect(app.api.deletes, isEmpty);
      expect(find.text('Selected Book'), findsNothing);
      expect(find.text('Other Book'), findsOneWidget);
      expect(find.text('Alpha Book'), findsNothing);
      expect(find.text('Select'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('remote series deletion keeps source file option hidden',
      (tester) async {
    final app = _ReadingApp()
      ..user = const User(id: 'admin', username: 'Admin', role: 'admin');
    app.api.seriesLibraryType = 'webdav';
    final player = _ReadingPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _pump(tester, app, player,
        SeriesDetailPage(seriesId: 'series', onBack: () {}, openBook: (_) {}));
    await tester.tap(find.text('Select Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected Book'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Batch Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Delete local source files too'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Delete')));
    await tester.pumpAndSettle();
    expect(app.api.bookDeletes.single,
        {'path': '/api/books/book', 'delete_files': false});
    expect(app.api.seriesUpdates, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('series marks more than 200 books in bounded batches',
      (tester) async {
    final app = _ReadingApp();
    app.api.seriesBookIds = List.generate(201, (index) => 'batch-$index');
    final player = _ReadingPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _pump(tester, app, player,
        SeriesDetailPage(seriesId: 'series', onBack: () {}, openBook: (_) {}));
    await tester.tap(find.text('Select Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Batch Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(app.api.readStatuses, hasLength(2));
    expect(app.api.readStatuses[0]['book_ids'], hasLength(200));
    expect(app.api.readStatuses[1]['book_ids'], ['batch-200']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late series response cannot replace a newly opened series',
      (tester) async {
    final app = _ReadingApp();
    final response = Completer<Response<dynamic>>();
    app.api.pendingSeries['/api/v1/series/series'] = response;
    final player = _ReadingPlayer();
    final selected = ValueNotifier<String>('series');
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    addTearDown(selected.dispose);
    await _pump(
        tester,
        app,
        player,
        ValueListenableBuilder<String>(
          valueListenable: selected,
          builder: (context, id, child) =>
              SeriesDetailPage(seriesId: id, onBack: () {}, openBook: (_) {}),
        ),
        settle: false);
    selected.value = 'other-series';
    await tester.pumpAndSettle();
    expect(find.text('Other Series'), findsOneWidget);
    response.complete(Response(
      requestOptions: RequestOptions(path: '/api/v1/series/series'),
      data: {'id': 'series', 'title': 'Old Series', 'books': []},
    ));
    await tester.pumpAndSettle();
    expect(find.text('Old Series'), findsNothing);
    expect(find.text('Other Series'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (local, webdav, rss, percentage) in [
    (1, 1, 2, '50%'),
    (0, 0, 2, '100%'),
    (0, 0, 0, '0%'),
  ]) {
    testWidgets('statistics counts RSS libraries ($local/$webdav/$rss)',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = _ReadingApp();
      app.api.statisticsPayload.addAll({
        'overview': {
          'total_libraries': local + webdav + rss,
          'local_libraries': local,
          'webdav_libraries': webdav,
          'rss_libraries': rss,
        },
        'library_breakdown': rss == 0
            ? []
            : [
                {
                  'id': 'rss-library',
                  'name': 'RSS Fixture',
                  'library_type': 'rss',
                  'total_books': 1,
                  'total_chapters': 3,
                  'total_duration': 1800,
                }
              ],
      });
      final player = _ReadingPlayer();
      addTearDown(app.dispose);
      addTearDown(player.dispose);
      await _pump(tester, app, player, const AdminStatisticsPage());
      expect(find.text('Local $local · WebDAV $webdav · RSS $rss'),
          findsOneWidget);
      await tester.scrollUntilVisible(find.text('Library Mix'), 350);
      await tester.pumpAndSettle();
      final mix = find
          .ancestor(of: find.text('Library Mix'), matching: find.byType(Column))
          .first;
      expect(find.descendant(of: mix, matching: find.text('RSS')),
          findsNWidgets(2));
      final rssCount = find
          .ancestor(
              of: find.descendant(of: mix, matching: find.text('RSS')).first,
              matching: find.byType(Column))
          .first;
      expect(find.descendant(of: rssCount, matching: find.text('$rss')),
          findsOneWidget);
      final rssRow = find
          .ancestor(
              of: find.descendant(of: mix, matching: find.text('RSS')).last,
              matching: find.byType(Row))
          .first;
      expect(find.descendant(of: rssRow, matching: find.text(percentage)),
          findsOneWidget);
      final segments = find.descendant(
          of: mix,
          matching: find.byWidgetPredicate((widget) =>
              widget is Container &&
              widget.constraints?.maxWidth != null &&
              widget.constraints!.maxWidth.isFinite &&
              [Colors.orange, Colors.purple, const Color(0xff0ea5e9)]
                  .contains(widget.color)));
      expect(
          segments,
          findsNWidgets(
              [local, webdav, rss].where((count) => count > 0).length));
      if (rss > 0) {
        await tester.scrollUntilVisible(find.text('RSS Fixture'), 350);
        await tester.pumpAndSettle();
        expect(find.text('RSS Fixture'), findsOneWidget);
        expect(find.text('RSS'), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
