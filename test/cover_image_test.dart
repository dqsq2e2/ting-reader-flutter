import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';
import 'package:ting_reader_flutter/src/core/services/library_cache.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';
import 'package:ting_reader_flutter/src/shared/app_scope.dart';
import 'package:ting_reader_flutter/src/shared/common/media_widgets.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');

class _CoverApi extends ApiClient {
  bool fail = true;
  int calls = 0;

  @override
  Future<Response<dynamic>> getBytes(String url,
      {CancelToken? cancelToken}) async {
    calls++;
    if (fail) throw StateError('Temporary cover failure');
    return Response(requestOptions: RequestOptions(path: url), data: _png);
  }
}

class _CoverApp extends AppState {
  _CoverApp(this._cache) {
    activeUrl = 'https://cover.test';
  }

  final LibraryCache _cache;
  final _coverApi = _CoverApi();
  @override
  LibraryCache get libraryCache => _cache;
  @override
  _CoverApi get api => _coverApi;

  @override
  Future<String?> recoverResourceUrl(String failedUrl,
          {CancelToken? cancelToken}) async =>
      null;
}

class _UnusedPlayer extends ChangeNotifier implements PlayerState {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _finishIo(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
    if (done()) return;
  }
  fail('Cover did not settle');
}

void main() {
  late Directory root;
  late _CoverApp app;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ting-cover-widget-test-');
    app = _CoverApp(LibraryCache(directory: root));
  });

  tearDown(() {
    app.dispose();
    app.api.close();
    root.deleteSync(recursive: true);
  });

  Future<void> mount(WidgetTester tester) async {
    final downloads = DownloadState(app);
    final player = _UnusedPlayer();
    addTearDown(downloads.dispose);
    addTearDown(player.dispose);
    await tester.pumpWidget(MaterialApp(
      home: AppScope(
        appState: app,
        downloadState: downloads,
        playerState: player,
        child: const SizedBox(
            width: 100,
            height: 100,
            child: CoverImage(url: 'https://cover.test/api/cover')),
      ),
    ));
    await _finishIo(tester, () => find.byType(Image).evaluate().isNotEmpty);
    await tester.pumpAndSettle();
  }

  bool hasFileImage(WidgetTester tester) =>
      find.byType(Image).evaluate().isNotEmpty &&
      tester.widget<Image>(find.byType(Image)).image is ResizeImage &&
      find.byType(RawImage).evaluate().isNotEmpty &&
      tester.widget<RawImage>(find.byType(RawImage)).image != null;

  testWidgets('the first uncached shelf cover displays without reopening',
      (tester) async {
    app.api.fail = false;
    await mount(tester);
    await _finishIo(tester, () => hasFileImage(tester));
    expect(app.api.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failed shelf cover retries without recreating the page',
      (tester) async {
    await mount(tester);
    expect(app.api.calls, 1);
    app.api.fail = false;
    await tester.pump(const Duration(seconds: 1));
    await _finishIo(tester, () => hasFileImage(tester));
    expect(app.api.calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('detail cache success updates the existing failed shelf cover',
      (tester) async {
    await mount(tester);
    final resource = app.libraryCache
        .coverResource('https://cover.test/api/cover', serverResource: true);
    final loaded = app.libraryCache
        .cover(app.libraryCacheIdentity, resource, (_) async => _png);
    await _finishIo(tester, () => hasFileImage(tester));
    expect(await loaded, isNotNull);
    expect(app.api.calls, 1);
    await tester.pump(const Duration(seconds: 20));
    expect(app.api.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('credential rotation retries without changing the disk cache key',
      (tester) async {
    await mount(tester);
    app.api.fail = false;
    app.api.configure(baseUrl: app.activeUrl, token: 'renewed');
    app.notifyListeners();
    await tester.pump();
    await _finishIo(tester, () => hasFileImage(tester));
    expect(app.api.calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'persistent failures have bounded retries and disposal stops them',
      (tester) async {
    await mount(tester);
    for (final seconds in [1, 3, 8]) {
      final before = app.api.calls;
      await tester.pump(Duration(seconds: seconds));
      await _finishIo(tester, () => app.api.calls > before);
      await tester.pumpAndSettle();
    }
    expect(app.api.calls, 4);
    await tester.pump(const Duration(minutes: 1));
    expect(app.api.calls, 4);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
    expect(app.api.calls, 4);
  });

  testWidgets('disposal cancels a pending retry and cache notifications',
      (tester) async {
    await mount(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    final resource = app.libraryCache
        .coverResource('https://cover.test/api/cover', serverResource: true);
    var completed = false;
    app.libraryCache
        .cover(app.libraryCacheIdentity, resource, (_) async => _png)
        .then((_) => completed = true);
    await _finishIo(tester, () => completed);
    await tester.pump(const Duration(seconds: 20));
    expect(app.api.calls, 1);
    expect(tester.takeException(), isNull);
  });
}
