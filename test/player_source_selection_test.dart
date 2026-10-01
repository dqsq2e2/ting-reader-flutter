import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';
import 'package:ting_reader_flutter/src/core/models/models.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';

class _PlaybackApi extends ApiClient {
  @override
  Future<Response<dynamic>> post(String path,
          {Object? data,
          Map<String, dynamic>? params,
          CancelToken? cancelToken,
          Duration? receiveTimeout}) async =>
      Response(requestOptions: RequestOptions(path: path), data: {});
}

class _PlaybackApp extends AppState {
  final _playbackApi = _PlaybackApi();
  @override
  _PlaybackApi get api => _playbackApi;
}

class _Downloads extends DownloadState {
  _Downloads(super.appState);
  final paths = <String, String>{};
  @override
  Future<String?> localPathForChapter(String chapterId) async =>
      paths[chapterId];
}

/// Records the actual source sent to the native player without decoding audio.
class _NativeAudio {
  _NativeAudio(this.binding);
  final TestWidgetsFlutterBinding binding;
  final sources = <Map<dynamic, dynamic>>[];
  final initialPositions = <int?>[];
  final _channels = <MethodChannel>[];
  static const _main = MethodChannel('com.ryanheise.just_audio.methods');
  static const _codec = StandardMethodCodec();

  void install() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_main,
        (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map)['id'] as String;
        final methods = MethodChannel('com.ryanheise.just_audio.methods.$id');
        final events = MethodChannel('com.ryanheise.just_audio.events.$id');
        final data = MethodChannel('com.ryanheise.just_audio.data.$id');
        _channels.addAll([methods, events, data]);
        binding.defaultBinaryMessenger
            .setMockMethodCallHandler(events, (_) async => null);
        binding.defaultBinaryMessenger
            .setMockMethodCallHandler(data, (_) async => null);
        binding.defaultBinaryMessenger.setMockMethodCallHandler(methods,
            (request) async {
          if (request.method == 'load') {
            final args = request.arguments as Map;
            sources.add(args['audioSource'] as Map);
              initialPositions.add(args['initialPosition'] as int?);
            binding.channelBuffers.push(
                events.name,
                _codec.encodeSuccessEnvelope({
                  'processingState': 3,
                  'updateTime': DateTime.now().millisecondsSinceEpoch,
                  'updatePosition': args['initialPosition'] ?? 0,
                  'bufferedPosition': 636000000,
                  'duration': 636000000,
                  'currentIndex': args['initialIndex'] ?? 0,
                }),
                (_) {});
            return {'duration': 636000000};
          }
          return <String, dynamic>{};
        });
      }
      return <String, dynamic>{};
    });
  }

  void uninstall() {
    for (final channel in [_main, ..._channels]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  }

  List<Uri> get loadedUris {
    final uris = <Uri>[];
    void visit(Map<dynamic, dynamic> source) {
      if (source['uri'] != null) uris.add(Uri.parse(source['uri'] as String));
      for (final child in source['children'] as List? ?? []) {
        visit(child as Map);
      }
    }

    for (final source in sources) {
      visit(source);
    }
    return uris;
  }

  List<Map<dynamic, dynamic>> get loadedHeaders {
    final headers = <Map<dynamic, dynamic>>[];
    void visit(Map<dynamic, dynamic> source) {
      if (source['uri'] != null) {
        headers.add(source['headers'] as Map? ?? {});
      }
      for (final child in source['children'] as List? ?? []) {
        visit(child as Map);
      }
    }

    for (final source in sources) {
      visit(source);
    }
    return headers;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const book = Book(id: 'book', libraryId: 'library', title: 'Book');
  late _NativeAudio native;
  late _PlaybackApp app;
  late _Downloads downloads;
  late PlayerState player;

  setUp(() {
    native = _NativeAudio(binding)..install();
    app = _PlaybackApp()
      ..activeUrl = 'http://127.0.0.1:9'
      ..token = 'fixture'
      ..offlineMode = true;
    app.api.configure(baseUrl: app.activeUrl, token: app.token);
    downloads = _Downloads(app);
    player = PlayerState(app, downloads);
  });

  tearDown(() async {
    player.dispose();
    await Future<void>.delayed(Duration.zero);
    native.uninstall();
    downloads.dispose();
    app.dispose();
  });

  Chapter chapter(String path) => Chapter(
      id: 'chapter',
      bookId: book.id,
      title: 'Chapter',
      path: path,
      chapterIndex: 0,
      duration: 636);

  for (final path in [
    'D:/ting-reader/ting-reader/backend/storage/乱世书/极品家丁-第0001章-公子，公子.(m4a).strm',
    r'D:\Audiobooks\Book\chapter.m4a',
    '/data/audiobooks/chapter.strm',
    '/storage/audiobooks/chapter.m4a',
    '/var/audiobooks/chapter.strm',
    '/Users/server/Audiobooks/chapter.m4a',
  ]) {
    test('server path uses HTTP streaming: $path', () async {
      final item = chapter(path);
      await player.playChapter(book, [item], item);
      expect(native.loadedUris, hasLength(1));
      expect(native.loadedUris.single.scheme, 'http');
      expect(native.loadedUris.single.path, '/api/stream/chapter');
      expect(native.loadedUris.single.queryParameters['transcode'], isNull);
      expect(player.usingLocalFile, isFalse);
      expect(player.error, isNull);
    });
  }

  test('gateway single-chapter source also streams server STRM paths',
      () async {
    app.offlineMode = false;
    app.api.isGatewaySession = () => true;
    final item = chapter('D:/server/book/chapter.strm');
    await player.playChapter(book, [item], item);
    expect(native.loadedUris.single.scheme, 'http');
    expect(native.loadedUris.single.path, '/api/stream/chapter');
    expect(native.loadedUris.single.queryParameters['transcode'], isNull);
    expect(player.usingLocalFile, isFalse);
  });

  test(
      'media authenticates through query without leaking Bearer to STRM origin',
      () async {
    final item = chapter('D:/server/book/chapter.strm');
    await player.playChapter(book, [item], item, startAt: 502.317);
    expect(native.loadedUris.single.queryParameters['token'], 'fixture');
    expect(app.api.authHeaders['Authorization'], 'Bearer fixture');
    expect(
        native.loadedHeaders.single.keys
            .where((name) => name.toString().toLowerCase() == 'authorization'),
        isEmpty);
    // Playback time advances after load; verify the exact seek sent to native.
    expect(native.initialPositions.single, 502317000);
  });

  test('gateway media keeps required cookies and gateway headers', () async {
    app.offlineMode = false;
    app.api.isGatewaySession = () => true;
    app.api.configure(
        baseUrl: app.activeUrl, token: app.token, cookie: 'session=fixture');
    app.api.setGatewayExtraHeaders({'x-access-code': 'gateway-fixture'});
    final item = chapter('D:/server/book/chapter.strm');
    await player.playChapter(book, [item], item, startAt: 502.317);
    expect(native.loadedHeaders.single['Cookie'], 'session=fixture');
    expect(native.loadedHeaders.single['x-access-code'], 'gateway-fixture');
    expect(native.loadedHeaders.single['Authorization'], isNull);
    expect(native.loadedUris.single.queryParameters['token'], 'fixture');
  });

  test('explicit file URI still plays offline audio', () async {
    final item = chapter('file:///C:/client/downloads/chapter.mp3');
    await player.playChapter(book, [item], item);
    expect(native.loadedUris.single.scheme, 'file');
    expect(native.loadedUris.single.path, endsWith('/chapter.mp3'));
    expect(player.usingLocalFile, isTrue);
  });

  test('indexed client download takes priority over server path', () async {
    downloads.paths['chapter'] = 'C:/client/downloads/chapter.mp3';
    final item = chapter('D:/server/book/chapter.strm');
    await player.playChapter(book, [item], item);
    expect(native.loadedUris.single.scheme, 'file');
    expect(native.loadedUris.single.path, contains('/client/downloads/'));
    expect(player.usingLocalFile, isTrue);
  });
}
