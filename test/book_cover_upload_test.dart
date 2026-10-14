import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/l10n/app_localizations.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';
import 'package:ting_reader_flutter/src/core/models/models.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/core/state/books_state.dart';
import 'package:ting_reader_flutter/src/core/state/scrape_state.dart';
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';
import 'package:ting_reader_flutter/src/core/utils/urls.dart';
import 'package:ting_reader_flutter/src/features/bookshelf/book_detail/book_detail_page.dart';
import 'package:ting_reader_flutter/src/shared/app_scope.dart';

class _CoverApi extends ApiClient {
  final uploads = <FormData>[];
  final updates = <Map<String, dynamic>>[];
  final scrapeApplications = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> scrapeItems = [];
  bool failUpload = false;
  bool failMetadataWrite = false;
  int metadataWrites = 0;
  Map<String, dynamic> book = {
    'id': 'cover-book',
    'library_id': 'lib',
    'library_type': 'rss',
    'title': 'Cover fixture',
    'path': 'https://example.test/feed',
  };

  Response<dynamic> _response(String path, Object? data) =>
      Response(requestOptions: RequestOptions(path: path), data: data);

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) async {
    if (path == '/api/books/cover-book') return _response(path, book);
    if (path == '/api/scraper/sources') {
      return _response(path, {
        'sources': [
          {
            'id': 'fixture-scraper',
            'name': 'Fixture scraper',
            'enabled': true,
            'auto_scrape': true,
            'result_fields': ['title', 'author'],
          }
        ]
      });
    }
    if (path == '/api/libraries') {
      return _response(path, [
        {
          'id': 'lib',
          'name': 'Library',
          'type': 'local',
          'scraper_config': {
            'default_sources': ['fixture-scraper']
          },
        }
      ]);
    }
    if (path == '/api/books/cover-book/chapters') {
      return _response(path, {
        'chapters': [],
        'total': 0,
        'main_total': 0,
        'extra_total': 0,
        'offset': 0,
        'chapter_type': 'main',
      });
    }
    if (path == '/api/settings') {
      return _response(path, {
        'settings_json': {
          'chapter_group_orders': [
            {'book_id': 'cover-book', 'order': 'desc'},
          ],
        },
      });
    }
    if (path == '/api/progress/cover-book') throw StateError('No progress');
    return _response(path, []);
  }

  @override
  Future<Response<dynamic>> post(String path,
      {Object? data,
      Map<String, dynamic>? params,
      CancelToken? cancelToken,
      Duration? receiveTimeout}) async {
    if (path == '/api/scraper/search') {
      return _response(path, {'items': scrapeItems});
    }
    if (path == '/api/books/cover-book/scrape-apply') {
      final payload = Map<String, dynamic>.from(data as Map);
      scrapeApplications.add(payload);
      final fields = payload['fields'] as Map;
      book = {
        ...book,
        for (final entry in fields.entries)
          entry.key as String: (entry.value as Map)['value']
      };
      return _response(path, book);
    }
    if (path == '/api/books/cover-book/write-metadata') {
      metadataWrites++;
      if (failMetadataWrite) throw StateError('Metadata writing disabled');
      return _response(path, {'task_id': 'metadata-write-fixture'});
    }
    if (path != '/api/books/cover-book/cover') {
      throw StateError('Unexpected POST: $path');
    }
    final form = data as FormData;
    uploads.add(form);
    if (failUpload) throw StateError('Upload rejected');
    book = {
      ...book,
      ...jsonDecode(
              form.fields.singleWhere((field) => field.key == 'metadata').value)
          as Map,
      'cover_url': 'D:/server/temp/hash/cover.jpg',
      'theme_color': 'rgba(30, 60, 120, 0.1)',
      'manual_corrected': true,
    };
    return _response(path, book);
  }

  @override
  Future<Response<dynamic>> patch(String path,
      {Object? data, CancelToken? cancelToken}) async {
    updates.add(Map<String, dynamic>.from(data as Map));
    book = {...book, ...updates.last};
    return _response(path, book);
  }
}

class _CoverApp extends AppState {
  final _coverApi = _CoverApi();
  @override
  _CoverApi get api => _coverApi;
}

class _CoverPlayer extends ChangeNotifier implements PlayerState {
  @override
  Book? currentBook;
  @override
  Chapter? currentChapter;
  @override
  bool isPlaying = false;
  @override
  void updateBookMetadata(Book book) {
    currentBook = book;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CoverPicker extends FilePicker {
  PlatformFile? next;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      next == null ? null : FilePickerResult([next!]);
}

Future<void> _showEditor(
    WidgetTester tester, _CoverApp app, _CoverPlayer player,
    {String action = 'Edit'}) async {
  tester.view.physicalSize = const Size(1200, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  app.user = const User(id: 'admin', username: 'admin', role: 'admin');
  final downloads = DownloadState(app);
  addTearDown(downloads.dispose);
  await tester.pumpWidget(AppScope(
    appState: app,
    downloadState: downloads,
    playerState: player,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: BookDetailPage(bookId: 'cover-book', onBack: () {})),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  bookWorkflowTests();
  late _CoverPicker picker;
  setUp(() {
    picker = _CoverPicker()
      ..next = PlatformFile(
        name: 'selected.png',
        size: 68,
        bytes: Uint8List.fromList(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aNfoAAAAASUVORK5CYII=',
        )),
      );
    FilePicker.platform = picker;
  });

  testWidgets(
      'empty scrape results allow filling missing fields while preserving untouched values',
      (tester) async {
    final app = _CoverApp();
    final player = _CoverPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    app.api.book = {
      ...app.api.book,
      'author': 'Existing author',
      'tags': 'keep, tags'
    };
    await _showEditor(tester, app, player, action: 'Scrape');
    await tester.tap(find.text('Search 1 plugin'));
    await tester.pumpAndSettle();
    expect(find.text('No Results'), findsOneWidget);
    await tester.tap(find.text('Review & Apply').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scrape-review-title')), findsOneWidget);
    for (final key in [
      'subtitle',
      'published_date',
      'publisher',
      'isbn',
      'asin',
      'language',
      'explicit',
      'abridged',
      'duration'
    ]) {
      expect(find.byKey(ValueKey('scrape-review-$key')), findsNothing);
    }
    for (final key in scrapeFieldOrder) {
      expect(find.byKey(ValueKey('scrape-review-$key')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('scrape-review-description')),
        findsOneWidget);
    final author = find.descendant(
      of: find.byKey(const ValueKey('scrape-review-author')),
      matching: find.byType(TextField),
    );
    expect(
        tester.widget<TextField>(author).controller?.text, 'Existing author');
    final narrator = find.descendant(
      of: find.byKey(const ValueKey('scrape-review-narrator')),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(narrator);
    await tester.enterText(narrator, 'Known narrator');
    await tester.pump();
    await tester.tap(find.text('Apply').last);
    await tester.pumpAndSettle();
    final fields = app.api.scrapeApplications.single['fields'] as Map;
    expect(fields.keys, ['narrator']);
    expect(fields['narrator'], {'value': 'Known narrator'});
    expect(app.api.book['author'], 'Existing author');
    expect(app.api.book['tags'], 'keep, tags');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'manual review edits can be reverted and clear restores current values',
      (tester) async {
    final app = _CoverApp();
    final player = _CoverPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    app.api.book = {...app.api.book, 'author': 'Existing author'};
    await _showEditor(tester, app, player, action: 'Scrape');
    await tester.tap(find.text('Review & Apply'));
    await tester.pumpAndSettle();
    final author = find.descendant(
      of: find.byKey(const ValueKey('scrape-review-author')),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(author);
    await tester.enterText(author, 'New author');
    await tester.pump();
    expect(find.text('Manual edit'), findsOneWidget);
    await tester.enterText(author, 'Existing author');
    await tester.pump();
    expect(find.text('Manual edit'), findsNothing);
    await tester.enterText(author, 'New author');
    await tester.pump();
    await tester.ensureVisible(find.text('Clear'));
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(
        tester.widget<TextField>(author).controller?.text, 'Existing author');
    expect(app.api.scrapeApplications, isEmpty);
    expect(find.byKey(const ValueKey('scrape-review-author')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'review saves scraper selections together with manually filled fields',
      (tester) async {
    final app = _CoverApp();
    final player = _CoverPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    app.api.scrapeItems = [
      {'id': 'result-1', 'title': 'Scraped title', 'author': 'Scraped author'}
    ];
    await _showEditor(tester, app, player, action: 'Scrape');
    await tester.tap(find.text('Search 1 plugin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scraped title'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use All'));
    await tester.pump();
    await tester.tap(find.text('Review & Apply').last);
    await tester.pumpAndSettle();
    final narrator = find.descendant(
      of: find.byKey(const ValueKey('scrape-review-narrator')),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(narrator);
    await tester.enterText(narrator, 'Known narrator');
    await tester.pump();
    await tester.tap(find.text('Apply').last);
    await tester.pumpAndSettle();
    final fields = app.api.scrapeApplications.single['fields'] as Map;
    expect(fields.keys.toSet(), {'title', 'author', 'narrator'});
    expect(fields['title'], {
      'value': 'Scraped title',
      'source': 'fixture-scraper',
      'external_id': 'result-1',
    });
    expect(fields['author']['value'], 'Scraped author');
    expect(fields['narrator'], {'value': 'Known narrator'});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'review omits plugin-only flags and preserves a manually filled database year',
      (tester) async {
    final app = _CoverApp();
    final player = _CoverPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _showEditor(tester, app, player, action: 'Scrape');
    await tester.tap(find.text('Review & Apply'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scrape-review-explicit')), findsNothing);
    expect(find.byKey(const ValueKey('scrape-review-abridged')), findsNothing);
    final year = find.descendant(
      of: find.byKey(const ValueKey('scrape-review-year')),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(year);
    await tester.enterText(year, '2026');
    await tester.pump();
    await tester.tap(find.text('Apply').last);
    await tester.pumpAndSettle();
    final fields = app.api.scrapeApplications.single['fields'] as Map;
    expect(fields, {
      'year': {'value': '2026'}
    });
    expect(tester.takeException(), isNull);
  });

  for (final libraryType in ['local', 'webdav', 'rss']) {
    for (final enabled in [false, true]) {
      testWidgets(
          'metadata file writing follows $libraryType setting ($enabled)',
          (tester) async {
        final app = _CoverApp();
        final player = _CoverPlayer();
        addTearDown(app.dispose);
        addTearDown(player.dispose);
        app.api.book = {
          ...app.api.book,
          'library_type': libraryType,
          'can_write_metadata_files':
              libraryType == 'local' || libraryType == 'webdav' && enabled,
        };
        await _showEditor(tester, app, player);
        final allowed =
            libraryType == 'local' || libraryType == 'webdav' && enabled;
        expect(find.text('Write'), allowed ? findsOneWidget : findsNothing);
        if (allowed) {
          await tester.tap(find.text('Write'));
          await tester.pumpAndSettle();
          expect(app.api.metadataWrites, 1);
          expect(
              find.text('Metadata write started. Check task progress later.'),
              findsOneWidget);
        }
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('rejected metadata writing shows an error without crashing',
      (tester) async {
    final app = _CoverApp()..api.failMetadataWrite = true;
    final player = _CoverPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    app.api.book = {
      ...app.api.book,
      'library_type': 'webdav',
      'can_write_metadata_files': true,
    };
    await _showEditor(tester, app, player);
    await tester.tap(find.text('Write'));
    await tester.pumpAndSettle();
    expect(app.api.metadataWrites, 1);
    expect(find.textContaining('Failed to start metadata writing:'),
        findsOneWidget);
    expect(find.text('Metadata write started. Check task progress later.'),
        findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting and cancelling a cover never uploads', (tester) async {
    final app = _CoverApp();
    final player = _CoverPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _showEditor(tester, app, player);
    expect(find.text('Cover'), findsOneWidget);
    expect(find.text('Cover URL'), findsNothing);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('selected.png'), findsOneWidget);
    expect(app.api.uploads, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(app.api.uploads, isEmpty);
    expect(app.api.updates, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a cover sends image and metadata together',
      (tester) async {
    final app = _CoverApp();
    final player = _CoverPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _showEditor(tester, app, player);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(app.api.uploads, hasLength(1));
    final upload = app.api.uploads.single;
    expect(upload.files.single.key, 'file');
    expect(upload.files.single.value.filename, 'selected.png');
    final metadata = jsonDecode(upload.fields.single.value) as Map;
    expect(metadata['title'], 'Cover fixture');
    expect(metadata['manual_corrected'], isTrue);
    expect(app.api.updates, isEmpty);
    expect(player.currentBook?.coverUrl, endsWith('cover.jpg'));
    final url = bookCoverUrl(app, Book.fromJson(app.api.book));
    expect(Uri.parse(url).path, '/api/proxy/cover');
    expect(Uri.parse(url).queryParameters['book_id'], 'cover-book');
    expect(Uri.parse(url).queryParameters['v'], isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed cover upload retains the selection for retry',
      (tester) async {
    final app = _CoverApp()..api.failUpload = true;
    final player = _CoverPlayer();
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    await _showEditor(tester, app, player);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('selected.png'), findsOneWidget);
    expect(find.textContaining('Upload rejected'), findsOneWidget);
    app.api.failUpload = false;
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(app.api.uploads, hasLength(2));
    expect(find.text('Edit book metadata'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('server paths use proxy while explicit offline files stay local', () {
    final app = _CoverApp();
    addTearDown(app.dispose);
    for (final path in [
      'D:/server/cover.jpg',
      '/data/books/cover.jpg',
      'cover.jpg'
    ]) {
      final result =
          Uri.parse(coverUrl(app, url: path, libraryId: 'lib', bookId: 'book'));
      expect(result.path, '/api/proxy/cover');
      expect(result.queryParameters['path'], path);
      expect(result.queryParameters['book_id'], 'book');
    }
    expect(
      coverUrl(app,
          url: 'file:///D:/downloads/cover.jpg',
          libraryId: 'lib',
          bookId: 'book'),
      'file:///D:/downloads/cover.jpg',
    );
  });
}

class _BookWorkflowApi extends ApiClient {
  final calls = <({
    String path,
    Map<String, dynamic>? params,
    Object? data,
    CancelToken? token
  })>[];
  Future<Object?> Function(String, Map<String, dynamic>?, CancelToken?)? onGet;
  Future<Object?> Function(String, Object?, CancelToken?)? onPost;
  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) async {
    calls.add((path: path, params: params, data: null, token: cancelToken));
    final result = await onGet?.call(path, params, cancelToken);
    return Response(requestOptions: RequestOptions(path: path), data: result);
  }

  @override
  Future<Response<dynamic>> post(String path,
      {Object? data,
      Map<String, dynamic>? params,
      CancelToken? cancelToken,
      Duration? receiveTimeout}) async {
    calls.add((path: path, params: params, data: data, token: cancelToken));
    final result = await onPost?.call(path, data, cancelToken);
    return Response(
        requestOptions: RequestOptions(path: path), data: result ?? {});
  }
}

void bookWorkflowTests() {
  test(
      'chapter catalogue shares full loads and rejects late invalidated results',
      () async {
    final pending = <Completer<Object?>>[];
    final api = _BookWorkflowApi()
      ..onGet = (_, __, ___) {
        final response = Completer<Object?>();
        pending.add(response);
        return response.future;
      };
    final catalogue = ChapterCatalogue(api, 'book');
    addTearDown(catalogue.dispose);
    final first = catalogue.all();
    expect(identical(first, catalogue.all()), isTrue);
    catalogue.invalidate();
    expect(api.calls.first.token!.isCancelled, isTrue);
    final next = catalogue.all();
    pending.first.complete([
      {'id': 'stale', 'book_id': 'book'}
    ]);
    expect(await first, isNull);
    pending.last.complete([
      {'id': 'current', 'book_id': 'book'}
    ]);
    expect((await next)!.single.id, 'current');
    expect((await catalogue.all())!.single.id, 'current');
    expect(api.calls, hasLength(2));
  });

  test(
      'chapter page replacement cancels the previous query and disposal settles late reads',
      () async {
    final pending = <Completer<Object?>>[];
    final api = _BookWorkflowApi()
      ..onGet = (_, __, ___) {
        final response = Completer<Object?>();
        pending.add(response);
        return response.future;
      };
    final catalogue = ChapterCatalogue(api, 'book');
    final first = catalogue.page({'offset': 0});
    final second = catalogue.page({'offset': 100});
    expect(api.calls.first.token!.isCancelled, isTrue);
    pending.last.complete({
      'chapters': [
        {'id': 'current'}
      ],
      'offset': 100
    });
    expect((await second)!.chapters.single.id, 'current');
    catalogue.dispose();
    pending.first.complete({
      'chapters': [
        {'id': 'stale'}
      ]
    });
    expect(await first, isNull);
    expect(await catalogue.all(), isNull);
  });

  test('book reload ignores an old response and uses one chapter catalogue',
      () async {
    final old = Completer<Object?>();
    var reads = 0;
    final api = _BookWorkflowApi()
      ..onGet = (path, params, token) async {
        if (path == '/api/books/book') {
          if (++reads == 1) return old.future;
          return {'id': 'book', 'library_id': 'lib', 'title': 'Current'};
        }
        if (path == '/api/settings') {
          return {
            'settings_json': {
              'chapter_group_orders': {'book': 'desc'}
            }
          };
        }
        if (path == '/api/progress/book') return null;
        return {
          'chapters': [
            {'id': 'chapter', 'book_id': 'book'}
          ],
          'main_total': 1,
          'total': 1,
          'offset': 0
        };
      };
    final detail = BookDetailState(api, 'book');
    addTearDown(detail.dispose);
    final first = detail.load();
    await detail.load();
    expect(detail.book!.title, 'Current');
    expect(detail.groupsDescending, isTrue);
    expect(detail.chapters.single.id, 'chapter');
    old.complete({'id': 'book', 'title': 'Stale'});
    await first;
    expect(detail.book!.title, 'Current');
    expect(api.calls.where((call) => call.path.endsWith('/chapters')),
        hasLength(1));
  });

  test(
      'batch read rules deduplicate ids and stop before another batch after owner disposal',
      () async {
    final api = _BookWorkflowApi();
    final operations = BookOperations(api);
    final ids = List.generate(401, (index) => '$index');
    await operations.markRead([...ids, '0'], true);
    expect(
        api.calls
            .map((call) => ((call.data as Map)['book_ids'] as List).length),
        [200, 200, 1]);
    api.calls.clear();
    final gate = Completer<Object?>();
    api.onPost = (_, __, ___) => gate.future;
    final stopped = operations.markRead(ids, false);
    final assertion = expectLater(stopped, throwsStateError);
    operations.dispose();
    gate.complete({});
    await assertion;
    expect(api.calls, hasLength(1));
    expect(api.calls.single.token!.isCancelled, isTrue);
  });

  test('shelf rules hide series members and group books consistently', () {
    final shelf = BookshelfState(_BookWorkflowApi());
    addTearDown(shelf.dispose);
    shelf.sortBy = 'title';
    shelf.books = [
      const Book(id: 'b', libraryId: 'l', title: 'Bravo'),
      const Book(id: 'a', libraryId: 'l', title: 'Alpha')
    ];
    shelf.series = [
      Series.fromJson({
        'id': 's',
        'title': 'Collection',
        'books': [
          {'id': 'a', 'library_id': 'l', 'title': 'Alpha'}
        ]
      })
    ];
    expect(shelf.filteredBooks.map((book) => book.id), ['b']);
    expect(shelf.groupedContent!.keys, ['B', 'C']);
  });

  test('scrape search ranks results and only accepts database-backed fields',
      () async {
    final api = _BookWorkflowApi()
      ..onPost = (_, data, __) async {
        if ((data as Map).containsKey('search_params')) {
          return {
            'items': [
              {'id': 'wrong', 'title': 'Different'},
              {'id': 'match', 'title': 'Exact', 'explicit': false},
            ]
          };
        }
        return {};
      };
    final scrape = ScrapeState(api, 'book');
    addTearDown(scrape.dispose);
    scrape.book = const Book(id: 'book', libraryId: 'lib', title: 'Exact');
    final source = ScrapeSource.fromJson({
      'id': 'source',
      'name': 'Source',
      'enabled': true,
      'result_fields': ['title', 'explicit']
    });
    scrape.sources = [source];
    scrape.enabledSources.add('source');
    await scrape.search({
      'source': {'title': 'Exact'}
    });
    expect(scrape.results.first.externalId, 'match');
    scrape.select(scrape.results.first, 'explicit', 'Explicit', 'Exact');
    scrape.edit('author', 'Known author', 'Author', 'Manual');
    expect(await scrape.apply(), isTrue);
    final fields = (api.calls.last.data as Map)['fields'] as Map;
    expect(fields.containsKey('explicit'), isFalse);
    expect((fields['author'] as Map)['value'], 'Known author');
    expect(fields.containsKey('title'), isFalse);
  });

  test(
      'scrape sources filter extended fields and retain database field aliases',
      () {
    final source = ScrapeSource.fromJson({
      'id': 'extended',
      'name': 'Extended',
      'result_fields': [
        'title',
        'intro',
        'published_year',
        'isbn',
        'duration',
        'subtitle'
      ],
    });
    expect(source.resultFields, ['title', 'description', 'year']);
    expect(
        ScrapeSource.fromJson({
          'id': 'unsupported',
          'result_fields': ['isbn', 'language']
        }).resultFields,
        isEmpty);
    expect(
        ScrapeSource.fromJson({'id': 'legacy'}).resultFields, scrapeFieldOrder);
    expect(scrapeFieldOrder, [
      'title',
      'author',
      'narrator',
      'cover_url',
      'description',
      'tags',
      'genre',
      'year'
    ]);
  });

  test(
      'closing a scrape search cancels the request and skips remaining sources',
      () async {
    final gate = Completer<Object?>();
    final api = _BookWorkflowApi()..onPost = (_, __, ___) => gate.future;
    final scrape = ScrapeState(api, 'book');
    scrape.sources = ['a', 'b']
        .map((id) =>
            ScrapeSource.fromJson({'id': id, 'name': id, 'enabled': true}))
        .toList();
    scrape.enabledSources.addAll(['a', 'b']);
    final searching = scrape.search({
      'a': {'title': 'Book'},
      'b': {'title': 'Book'}
    });
    scrape.dispose();
    gate.complete({
      'items': [
        {'id': 'late'}
      ]
    });
    await searching;
    expect(api.calls, hasLength(1));
    expect(api.calls.single.token!.isCancelled, isTrue);
    expect(scrape.results, isEmpty);
  });
}
