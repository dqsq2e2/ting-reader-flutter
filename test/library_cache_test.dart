import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';
import 'package:ting_reader_flutter/src/core/services/library_cache.dart';
import 'package:ting_reader_flutter/src/core/state/books_state.dart';

class _LibraryApi extends ApiClient {
  bool fail = false;
  Future<void>? gate;
  String identity = 'server|user';
  _LibraryApi() {
    sessionIdentity = () => identity;
  }

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) async {
    await gate;
    if (fail) throw StateError('Unavailable');
    final Object data;
    if (path == '/api/books') {
      data = [
        {'id': 'book', 'library_id': 'lib', 'title': 'Cached book'}
      ];
    } else if (path == '/api/books/book') {
      data = {'id': 'book', 'library_id': 'lib', 'title': 'Cached book'};
    } else if (path.endsWith('/chapters')) {
      data = {
        'chapters': [
          {
            'id': 'chapter',
            'book_id': 'book',
            'title': 'Chapter',
            'path': 'book.m4b',
            'start_time': 30000,
            'end_time': 90000
          }
        ],
        'total': 1,
        'main_total': 1,
        'extra_total': 0,
        'offset': 0
      };
    } else if (path == '/api/libraries') {
      data = [
        {'id': 'lib', 'name': 'Library', 'password': 'not-a-display-setting'}
      ];
    } else if (path == '/api/settings') {
      data = {
        'settings_json': {'bookshelf_view_mode': 'list', 'password': 'secret'}
      };
    } else {
      data = <String, dynamic>{};
    }
    return Response(requestOptions: RequestOptions(path: path), data: data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LibraryCache cache;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ting-library-cache-test-');
    cache = LibraryCache(directory: root);
  });
  tearDown(() async {
    cache.dispose();
    await cache.flush();
    await root.delete(recursive: true);
  });

  test('snapshots persist and remain isolated by server and account', () async {
    await cache.write('server|alice', 'shelf', {'title': 'Alice'});
    expect(cache.peek('server|bob', 'shelf'), isNull);
    final reopened = LibraryCache(directory: root);
    addTearDown(reopened.dispose);
    expect((await reopened.read('server|alice', 'shelf'))?['title'], 'Alice');
    expect(await reopened.read('other-server|alice', 'shelf'), isNull);
    final file = root.listSync().whereType<File>().single;
    await file.writeAsString('invalid json');
    final corrupt = LibraryCache(directory: root);
    addTearDown(corrupt.dispose);
    expect(await corrupt.read('server|alice', 'shelf'), isNull);
  });

  test('coalesced writes and disk pruning keep the latest bounded snapshots',
      () async {
    final bounded = LibraryCache(directory: root, maxEntries: 2, maxBytes: 500);
    addTearDown(bounded.dispose);
    final writes = <Future<void>>[];
    for (var i = 0; i < 50; i++) {
      writes.add(bounded.write('user', 'shelf', {'revision': i}));
    }
    await Future.wait(writes);
    await bounded.write('user', 'second', {'title': 'Second'});
    await bounded.write('user', 'third', {'title': 'Third'});
    expect(root.listSync().whereType<File>().length, lessThanOrEqualTo(2));
    final reader = LibraryCache(directory: root);
    addTearDown(reader.dispose);
    expect((await reader.read('user', 'third'))?['title'], 'Third');
    await bounded.write('user', 'oversize', {'title': 'x' * 1000});
    expect(bounded.peek('user', 'oversize'), isNull);
  });

  test('cover requests deduplicate and disposal cancels active requests',
      () async {
    final bytes = Completer<List<int>>();
    var calls = 0;
    CancelToken? active;
    Future<List<int>> fetch(CancelToken token) {
      calls++;
      active = token;
      return bytes.future;
    }

    final first = cache.cover('alice', 'cover', fetch);
    final second = cache.cover('alice', 'cover', fetch);
    while (active == null) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(calls, 1);
    cache.dispose();
    expect(active!.isCancelled, isTrue);
    bytes.complete([1, 2, 3]);
    expect(await first, isNull);
    expect(await second, isNull);
    expect(root.listSync(), isEmpty);
  });

  test('a first cover download completes and later reads reuse its file',
      () async {
    var calls = 0;
    Future<List<int>> fetch(CancelToken _) async {
      calls++;
      return [1, 2, 3];
    }

    final file = await cache
        .cover('alice', 'cover', fetch)
        .timeout(const Duration(seconds: 2));
    expect(await file!.readAsBytes(), [1, 2, 3]);
    final reused = await cache.cover('alice', 'cover', fetch);
    expect(reused!.path, file.path);
    expect(calls, 1);
  });

  test('server artwork keys survive token rotation but retain cover revisions',
      () {
    final first = cache.coverResource(
        'https://server/app/api/proxy/cover?book_id=b&token=old&v=1',
        serverResource: true);
    expect(
        first,
        cache.coverResource(
            'https://new-route/api/proxy/cover?book_id=b&token=new&v=1',
            serverResource: true));
    expect(first, isNot(contains('token')));
    expect(
        first,
        isNot(cache.coverResource(
            'https://server/api/proxy/cover?book_id=b&token=new&v=2',
            serverResource: true)));
  });

  test('cover recovery notifies only active listeners for the same account',
      () async {
    final updated = <File>[];
    var unrelated = 0;
    final stop = cache.watchCover('alice', 'cover', updated.add);
    final stopOther = cache.watchCover('bob', 'cover', (_) => unrelated++);
    addTearDown(stopOther);
    expect(
        await cache.cover(
            'alice', 'cover', (_) async => throw StateError('offline')),
        isNull);
    expect(updated, isEmpty);
    final file = await cache.cover('alice', 'cover', (_) async => [1, 2, 3]);
    expect(updated.single.path, file!.path);
    expect(unrelated, 0);
    stop();
    await file.delete();
    await cache.cover('alice', 'cover', (_) async => [4, 5, 6]);
    expect(updated, hasLength(1));
  });

  test('shelf and detail keep cached content during refresh and on failure',
      () async {
    final api = _LibraryApi();
    addTearDown(api.close);
    final shelf = BookshelfState(api, cache: cache);
    final details = BookDetailState(api, 'book', cache: cache);
    addTearDown(shelf.dispose);
    addTearDown(details.dispose);
    await shelf.load();
    await details.load();
    await cache.flush();
    final gate = Completer<void>();
    api
      ..fail = true
      ..gate = gate.future;
    final restored = BookshelfState(api, cache: cache);
    final restoredDetails = BookDetailState(api, 'book', cache: cache);
    addTearDown(restored.dispose);
    addTearDown(restoredDetails.dispose);
    final refresh = restored.load();
    final detailRefresh = restoredDetails.load();
    expect(restored.loading, isFalse);
    expect(restored.books.single.title, 'Cached book');
    expect(restoredDetails.book?.title, 'Cached book');
    expect(restoredDetails.chapters.single.startTime, 30000);
    gate.complete();
    await Future.wait([refresh, detailRefresh]);
    expect(restored.books, hasLength(1));
    expect(restoredDetails.chapters, hasLength(1));
    expect(cache.peek(api.identity, 'shelf')!['settings'].toString(),
        isNot(contains('secret')));
    expect(cache.peek(api.identity, 'shelf')!['libraries'].toString(),
        isNot(contains('password')));
  });

  test('late detail responses cannot populate a different account cache',
      () async {
    final api = _LibraryApi();
    addTearDown(api.close);
    final gate = Completer<void>();
    api.gate = gate.future;
    final detail = BookDetailState(api, 'book', cache: cache);
    addTearDown(detail.dispose);
    final pending = detail.load();
    api.identity = 'server|other';
    gate.complete();
    await pending;
    expect(detail.book, isNull);
    expect(cache.peek('server|user', 'book:book'), isNull);
    expect(cache.peek('server|other', 'book:book'), isNull);
  });

  test('cached server artwork requests include gateway cookies and headers',
      () async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previous);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final headers = Completer<HttpHeaders>();
    server.listen((request) async {
      headers.complete(request.headers);
      request.response.add([1, 2, 3]);
      await request.response.close();
    });
    final api = ApiClient();
    addTearDown(api.close);
    final url = 'http://127.0.0.1:${server.port}';
    api.configure(baseUrl: url, token: 'fixture', cookie: 'session=fixture');
    api.setGatewayExtraHeaders({'x-access-code': 'fixture-code'});
    final response = await api.getBytes('$url/cover');
    expect(response.data, [1, 2, 3]);
    final received = await headers.future;
    expect(received.value('Authorization'), 'Bearer fixture');
    expect(received.value('Cookie'), 'session=fixture');
    expect(received.value('x-access-code'), 'fixture-code');
  });
}
