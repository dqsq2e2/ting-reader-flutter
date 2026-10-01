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
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';
import 'package:ting_reader_flutter/src/core/utils/urls.dart';
import 'package:ting_reader_flutter/src/features/bookshelf/book_detail/book_detail_page.dart';
import 'package:ting_reader_flutter/src/shared/app_scope.dart';

class _CoverApi extends ApiClient {
  final uploads = <FormData>[];
  final updates = <Map<String, dynamic>>[];
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
  Future<Response<dynamic>> patch(String path, {Object? data}) async {
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
    WidgetTester tester, _CoverApp app, _CoverPlayer player) async {
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
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
}

void main() {
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
