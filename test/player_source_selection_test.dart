import 'dart:async';
import 'dart:io';

import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:audio_service_platform_interface/method_channel_audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';
import 'package:ting_reader_flutter/src/core/models/models.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';

class _PlaybackApi extends ApiClient {
  final durationUpdates = <Object?>[];
  final progressUpdates = <Object?>[];
  final sessionProbes = <String>[];
  Future<void>? progressGate;

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) async {
    sessionProbes.add(path);
    return Response(
        requestOptions: RequestOptions(path: path), data: {}, statusCode: 200);
  }

  @override
  Future<Response<dynamic>> patch(String path, {Object? data}) async {
    durationUpdates.add(data);
    return Response(requestOptions: RequestOptions(path: path), data: {});
  }

  @override
  Future<Response<dynamic>> post(String path,
      {Object? data,
      Map<String, dynamic>? params,
      CancelToken? cancelToken,
      Duration? receiveTimeout}) async {
    if (path == '/api/progress') {
      progressUpdates.add(data);
      await progressGate;
    }
    return Response(requestOptions: RequestOptions(path: path), data: {});
  }
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

class _NativeNotifications {
  _NativeNotifications(this.binding);
  final TestWidgetsFlutterBinding binding;
  static const _client =
      MethodChannel('com.ryanheise.audio_service.client.methods');
  static const _handler =
      MethodChannel('com.ryanheise.audio_service.handler.methods');
  final mediaItems = <Map<dynamic, dynamic>>[];
  final states = <Map<dynamic, dynamic>>[];

  void install() {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_client, (_) async => null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_handler,
        (call) async {
      final args = call.arguments as Map;
      if (call.method == 'setMediaItem') {
        mediaItems.add(args['mediaItem'] as Map);
      } else if (call.method == 'setState') {
        states.add(args['state'] as Map);
      }
      return null;
    });
  }

  void clear() {
    mediaItems.clear();
    states.clear();
  }

  void uninstall() {
    for (final channel in [_client, _handler]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  }
}

/// Records the actual source sent to the native player without decoding audio.
class _NativeAudio {
  _NativeAudio(this.binding);
  final TestWidgetsFlutterBinding binding;
  final sources = <Map<dynamic, dynamic>>[];
  final initialPositions = <int?>[];
  final initialIndices = <int>[];
  final unsupportedChapterIds = <String>{};
  final _channels = <MethodChannel>[];
  MethodChannel? _events;
  bool failFirstLoad = false;
  Duration reportedDuration = const Duration(seconds: 636);
  static const _main = MethodChannel('com.ryanheise.just_audio.methods');
  static const _codec = StandardMethodCodec();

  void install() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_main,
        (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map)['id'] as String;
        final methods = MethodChannel('com.ryanheise.just_audio.methods.$id');
        final events = MethodChannel('com.ryanheise.just_audio.events.$id');
        _events = events;
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
            initialIndices.add(args['initialIndex'] as int? ?? 0);
            emit(
              position:
                  Duration(microseconds: args['initialPosition'] as int? ?? 0),
              index: args['initialIndex'] as int? ?? 0,
            );
            if ((failFirstLoad && sources.length == 1) ||
                (unsupportedChapterIds.contains(activeUri.pathSegments.last) &&
                    activeUri.queryParameters['transcode'] != 'mp3')) {
              throw PlatformException(code: '4', message: 'Unsupported WMA');
            }
            return {'duration': reportedDuration.inMicroseconds};
          }
          return <String, dynamic>{};
        });
      }
      return <String, dynamic>{};
    });
  }

  Uri get activeUri {
    Map<dynamic, dynamic> source = sources.last;
    final children = source['children'] as List?;
    if (children != null) {
      source = children[initialIndices.last] as Map;
    }
    return Uri.parse(source['uri'] as String);
  }

  void emit({
    Duration position = Duration.zero,
    int processingState = 3,
    int index = 0,
  }) {
    binding.channelBuffers.push(
        _events!.name,
        _codec.encodeSuccessEnvelope({
          'processingState': processingState,
          'updateTime': DateTime.now().millisecondsSinceEpoch,
          'updatePosition': position.inMicroseconds,
          'bufferedPosition': reportedDuration.inMicroseconds,
          'duration': reportedDuration.inMicroseconds,
          'currentIndex': index,
        }),
        (_) {});
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
  final notifications = _NativeNotifications(binding);
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  late Directory cacheDirectory;

  Chapter chapter(String path, {String id = 'chapter', int index = 0}) =>
      Chapter(
          id: id,
          bookId: book.id,
          title: 'Chapter',
          path: path,
          chapterIndex: index,
          duration: 636);

  Future<void> waitForPlayback(bool Function() settled) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (!settled()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Playback did not reach the expected state');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(Duration.zero);
  }

  setUpAll(() async {
    AudioServicePlatform.instance = MethodChannelAudioService();
    cacheDirectory =
        await Directory.systemTemp.createTemp('ting-player-notification-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathProvider, (_) async => cacheDirectory.path);
    notifications.install();
    await JustAudioBackground.init();
  });

  tearDownAll(() async {
    notifications.uninstall();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProvider, null);
    await cacheDirectory.delete(recursive: true);
  });

  setUp(() {
    native = _NativeAudio(binding)..install();
    app = _PlaybackApp()
      ..activeUrl = 'http://127.0.0.1:9'
      ..token = 'fixture'
      ..offlineMode = true;
    app.api.configure(baseUrl: app.activeUrl, token: app.token);
    downloads = _Downloads(app);
    player = PlayerState(app, downloads);
    JustAudioBackground.setAudioFocusEnabled(false);
    notifications.clear();
  });

  test('WMA transcode keeps chapter duration in player and notification',
      () async {
    native
      ..failFirstLoad = true
      ..reportedDuration = const Duration(seconds: 120);
    final item = chapter('/data/audiobooks/chapter.wma');
    await player.playChapter(book, [item], item);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(native.loadedUris.last.queryParameters['transcode'], 'mp3');
    expect(player.error, isNull);
    expect(player.duration, 636);
    expect(notifications.mediaItems.last['duration'], 636000);
    expect(notifications.mediaItems.last['extras']['isTranscodedStream'], true);
  });

  test('transcode seek beyond native estimate keeps advancing', () async {
    native
      ..failFirstLoad = true
      ..reportedDuration = const Duration(seconds: 120);
    final item = chapter('/data/audiobooks/chapter.wma');
    await player.playChapter(book, [item], item, startAt: 130);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(player.currentTime, greaterThan(130));
    expect(player.duration, 636);
    expect(notifications.mediaItems.last['duration'], 636000);
    await player.seek(300);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    native.emit();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(native.loadedUris.last.queryParameters['seek'], '300');
    expect(player.currentTime, greaterThan(300));
    expect(notifications.states.last['updatePosition'],
        greaterThanOrEqualTo(300000));
    expect(notifications.mediaItems.last['duration'], 636000);
  });

  test('unknown transcode duration is not saved as a short chapter', () async {
    native
      ..failFirstLoad = true
      ..reportedDuration = const Duration(seconds: 120);
    final item = chapter('/data/audiobooks/chapter.wma').copyWith(duration: 0);
    await player.playChapter(book, [item], item);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(player.duration, 0);
    expect(player.currentChapter!.duration, 0);
    expect(app.api.durationUpdates, isEmpty);
    expect(notifications.mediaItems.last['duration'], isNull);
  });

  test('zero-offset transcode progresses past changing native estimates',
      () async {
    native
      ..failFirstLoad = true
      ..reportedDuration = const Duration(milliseconds: 120);
    final item = chapter('/data/audiobooks/chapter.wma');
    await player.playChapter(book, [item], item);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    native
      ..reportedDuration = const Duration(milliseconds: 200)
      ..emit(position: const Duration(milliseconds: 120));
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(player.currentTime, greaterThan(0.4));
    expect(player.duration, 636);
    expect(notifications.states.last['updatePosition'], greaterThan(400));
    expect(notifications.mediaItems.last['duration'], 636000);
  });

  test('transcode clock pauses during buffering and does not jump on speed',
      () async {
    native
      ..failFirstLoad = true
      ..reportedDuration = const Duration(seconds: 120);
    final item = chapter('/data/audiobooks/chapter.wma');
    await player.playChapter(book, [item], item, startAt: 130);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    native.emit(processingState: 2);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final bufferedPosition = player.currentTime;
    final bufferedNotification = notifications.states.last['updatePosition'];
    await Future<void>.delayed(const Duration(milliseconds: 300));
    native.emit(processingState: 2);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(player.currentTime, closeTo(bufferedPosition, 0.05));
    expect(notifications.states.last['updatePosition'], bufferedNotification);

    native.emit();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await player.togglePlay();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final pausedPosition = player.currentTime;
    final pausedNotification = notifications.states.last['updatePosition'];
    await player.setSpeed(2);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(player.currentTime, closeTo(pausedPosition, 0.05));
    expect(notifications.states.last['updatePosition'],
        closeTo(pausedNotification, 50));
    expect(notifications.states.last['speed'], 2);

    await player.togglePlay();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    native.emit();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(player.currentTime - pausedPosition, greaterThan(0.7));
    expect(notifications.states.last['updatePosition'] - pausedNotification,
        greaterThan(700));
    expect(player.duration, 636);
  });

  test('reloading a transcode at zero resets its notification clock', () async {
    native
      ..failFirstLoad = true
      ..reportedDuration = const Duration(seconds: 120);
    final item = chapter('/data/audiobooks/chapter.wma');
    await player.playChapter(book, [item], item);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await player.seek(0);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    native.emit();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(player.currentTime, lessThan(0.4));
    expect(notifications.states.last['updatePosition'], lessThan(400));
    expect(notifications.mediaItems.last['duration'], 636000);
  });

  test('ordinary playback still discovers and saves an unknown duration',
      () async {
    final item = chapter('/data/audiobooks/chapter.mp3').copyWith(duration: 0);
    await player.playChapter(book, [item], item);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(player.duration, 636);
    expect(player.currentChapter!.duration, 636);
    expect(app.api.durationUpdates, [
      {'duration': 636}
    ]);
    expect(notifications.mediaItems.last['duration'], 636000);
  });

  test('notification artwork authentication survives metadata copies', () {
    final headers = {
      'Cookie': 'fnos-token=fixture',
      'x-access-code': 'gateway-fixture',
      'Authorization': 'Bearer fixture',
    };
    final item = MediaItem(
      id: 'chapter',
      title: 'Chapter',
      artUri:
          Uri.parse('https://gateway.example/api/proxy/cover?path=cover.jpg'),
      artHeaders: headers,
    );

    final transcode = item.copyWith(
      duration: const Duration(seconds: 636),
      extras: {'isTranscodedStream': true},
    );
    final durationUpdate =
        item.copyWith(duration: const Duration(seconds: 120));
    final cachedArtwork =
        item.copyWith(extras: {'artCacheFile': '/client/cache/cover.jpg'});

    expect(transcode.artHeaders, headers);
    expect(durationUpdate.artHeaders, headers);
    expect(cachedArtwork.artHeaders, headers);
  });

  test('notification artwork headers can be replaced or explicitly cleared',
      () {
    final item = MediaItem(
      id: 'chapter',
      title: 'Chapter',
      artUri: Uri.parse('https://gateway.example/api/proxy/cover'),
      artHeaders: const {'Cookie': 'old-session'},
    );
    expect(
      item.copyWith(artHeaders: const {'Cookie': 'new-session'}).artHeaders,
      {'Cookie': 'new-session'},
    );
    expect(
      item
          .copyWith(
            artUri: Uri.parse('https://images.example/cover.jpg'),
            artHeaders: null,
          )
          .artHeaders,
      isNull,
    );
  });

  for (final nextFormat in ['wma', 'mp3']) {
    test('WMA completion automatically plays the next $nextFormat chapter',
        () async {
      final first = chapter('/data/first.wma', id: 'first');
      final second =
          chapter('/data/second.$nextFormat', id: 'second', index: 1);
      native.unsupportedChapterIds.add('first');
      if (nextFormat == 'wma') {
        native.unsupportedChapterIds.add('second');
      }
      await player.playChapter(book, [second, first], first, startAt: 630);
      expect(native.activeUri.queryParameters['transcode'], 'mp3');

      native.emit(processingState: 4, position: const Duration(seconds: 636));
      await waitForPlayback(() =>
          player.currentChapter?.id == second.id &&
          native.activeUri.path == '/api/stream/second' &&
          (nextFormat != 'wma' ||
              native.activeUri.queryParameters['transcode'] == 'mp3'));

      expect(player.isPlaying, isTrue);
      expect(player.error, isNull);
      expect(player.duration, 636);
      expect(notifications.mediaItems.last['id'], second.id);
    });
  }

  test('WMA completion at the end of a book stops without reloading', () async {
    final item = chapter('/data/chapter.wma');
    native.unsupportedChapterIds.add(item.id);
    await player.playChapter(book, [item], item, startAt: 630);
    final loadCount = native.sources.length;

    native.emit(processingState: 4, position: const Duration(seconds: 636));
    await waitForPlayback(() => !player.isPlaying);

    expect(player.currentChapter?.id, item.id);
    expect(native.sources, hasLength(loadCount));
    expect(player.error, isNull);
  });

  test('paused WMA completion does not start another chapter', () async {
    final first = chapter('/data/first.wma', id: 'first');
    final second = chapter('/data/second.wma', id: 'second', index: 1);
    native.unsupportedChapterIds.addAll([first.id, second.id]);
    await player.playChapter(book, [first, second], first);
    await player.togglePlay();
    native.emit(processingState: 4, position: const Duration(seconds: 636));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(player.currentChapter?.id, first.id);
    expect(player.isPlaying, isFalse);
    expect(native.sources, hasLength(2));
  });

  test('episode sleep still stops WMA continuation', () async {
    final first = chapter('/data/first.wma', id: 'first');
    final second = chapter('/data/second.wma', id: 'second', index: 1);
    native.unsupportedChapterIds.addAll([first.id, second.id]);
    await player.playChapter(book, [first, second], first, startAt: 630);
    player.startEpisodeSleepTimer(1);
    native.emit(processingState: 4, position: const Duration(seconds: 636));
    await waitForPlayback(
        () => player.currentChapter?.id == second.id && !player.isPlaying);

    expect(player.sleepEpisodesRemaining, isNull);
    expect(player.error, isNull);
  });

  test('gateway WMA completion still verifies the session and advances',
      () async {
    app.offlineMode = false;
    app.api.isGatewaySession = () => true;
    final first = chapter('/data/first.wma', id: 'first');
    final second = chapter('/data/second.wma', id: 'second', index: 1);
    native.unsupportedChapterIds.addAll([first.id, second.id]);
    await player.playChapter(book, [first, second], first, startAt: 630);
    app.api.sessionProbes.clear();

    native.emit(processingState: 4, position: const Duration(seconds: 636));
    await waitForPlayback(() =>
        player.currentChapter?.id == second.id &&
        native.activeUri.path == '/api/stream/second' &&
        native.activeUri.queryParameters['transcode'] == 'mp3');

    expect(app.api.sessionProbes, contains('/api/me'));
    expect(player.isPlaying, isTrue);
    expect(player.error, isNull);
  });

  test('premature gateway WMA completion does not skip a chapter', () async {
    app.offlineMode = false;
    app.api.isGatewaySession = () => true;
    final first = chapter('/data/first.wma', id: 'first');
    final second = chapter('/data/second.wma', id: 'second', index: 1);
    native.unsupportedChapterIds.addAll([first.id, second.id]);
    await player.playChapter(book, [first, second], first);
    native.emit(processingState: 4);
    await waitForPlayback(() => player.error != null);

    expect(player.currentChapter?.id, first.id);
    expect(player.isPlaying, isFalse);
    expect(native.sources, hasLength(2));
  });

  test('unknown WMA duration still advances on actual completion', () async {
    final first = chapter('/data/first.wma', id: 'first').copyWith(duration: 0);
    final second = chapter('/data/second.wma', id: 'second', index: 1);
    native.unsupportedChapterIds.addAll([first.id, second.id]);
    await player.playChapter(book, [first, second], first);
    native.emit(processingState: 4);
    await waitForPlayback(() =>
        player.currentChapter?.id == second.id &&
        native.activeUri.queryParameters['transcode'] == 'mp3');

    expect(player.isPlaying, isTrue);
    expect(app.api.durationUpdates, isEmpty);
  });

  test('ordinary native queues still advance without reloading', () async {
    final first = chapter('/data/first.mp3', id: 'first');
    final second = chapter('/data/second.mp3', id: 'second', index: 1);
    await player.playChapter(book, [first, second], first);
    native.emit(index: 1);
    await waitForPlayback(() => player.currentChapter?.id == second.id);
    native.emit(processingState: 4, index: 1);
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(native.sources, hasLength(1));
    expect(player.currentChapter?.id, second.id);
  });

  test('a stale WMA completion cannot advance a manually selected chapter',
      () async {
    app.offlineMode = false;
    final first = chapter('/data/first.wma', id: 'first');
    final second = chapter('/data/second.wma', id: 'second', index: 1);
    final third = chapter('/data/third.wma', id: 'third', index: 2);
    final items = [first, second, third];
    native.unsupportedChapterIds.addAll(items.map((item) => item.id));
    await player.playChapter(book, items, first, startAt: 630);
    final gate = Completer<void>();
    app.api.progressGate = gate.future;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final progressCount = app.api.progressUpdates.length;
    native.emit(processingState: 4, position: const Duration(seconds: 636));
    await waitForPlayback(() => app.api.progressUpdates.length > progressCount);
    await player.playChapter(book, items, second);
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(player.currentChapter?.id, second.id);
    expect(native.activeUri.path, '/api/stream/second');
  });

  test('repeated WMA completion events advance only one chapter', () async {
    app.offlineMode = false;
    final first = chapter('/data/first.wma', id: 'first');
    final second = chapter('/data/second.wma', id: 'second', index: 1);
    final third = chapter('/data/third.wma', id: 'third', index: 2);
    final items = [first, second, third];
    native.unsupportedChapterIds.addAll(items.map((item) => item.id));
    await player.playChapter(book, items, first, startAt: 630);
    final gate = Completer<void>();
    app.api.progressGate = gate.future;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final progressCount = app.api.progressUpdates.length;
    native.emit(processingState: 4, position: const Duration(seconds: 636));
    await waitForPlayback(() => app.api.progressUpdates.length > progressCount);
    native.emit(processingState: 2);
    await Future<void>.delayed(Duration.zero);
    native.emit(processingState: 4, position: const Duration(seconds: 636));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    gate.complete();
    await waitForPlayback(() =>
        player.currentChapter?.id == second.id &&
        native.activeUri.path == '/api/stream/second' &&
        native.activeUri.queryParameters['transcode'] == 'mp3');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(player.currentChapter?.id, second.id);
    expect(native.sources, hasLength(4));
  });

  test('pausing cancels an in-flight WMA chapter advance', () async {
    app.offlineMode = false;
    final first = chapter('/data/first.wma', id: 'first');
    final second = chapter('/data/second.wma', id: 'second', index: 1);
    native.unsupportedChapterIds.addAll([first.id, second.id]);
    await player.playChapter(book, [first, second], first, startAt: 630);
    final gate = Completer<void>();
    app.api.progressGate = gate.future;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final progressCount = app.api.progressUpdates.length;
    native.emit(processingState: 4, position: const Duration(seconds: 636));
    await waitForPlayback(() => app.api.progressUpdates.length > progressCount);
    final pause = player.togglePlay();
    await waitForPlayback(() => !player.isPlaying);
    gate.complete();
    await pause;
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(player.currentChapter?.id, first.id);
    expect(player.isPlaying, isFalse);
    expect(native.sources, hasLength(2));
  });

  test('seeking cancels an in-flight WMA chapter advance', () async {
    app.offlineMode = false;
    final first = chapter('/data/first.wma', id: 'first');
    final second = chapter('/data/second.wma', id: 'second', index: 1);
    native.unsupportedChapterIds.addAll([first.id, second.id]);
    await player.playChapter(book, [first, second], first, startAt: 630);
    final gate = Completer<void>();
    app.api.progressGate = gate.future;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final progressCount = app.api.progressUpdates.length;
    native.emit(processingState: 4, position: const Duration(seconds: 636));
    await waitForPlayback(() => app.api.progressUpdates.length > progressCount);
    final seek = player.seek(20);
    await waitForPlayback(
        () => native.activeUri.queryParameters['seek'] == '20');
    gate.complete();
    await seek;
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(player.currentChapter?.id, first.id);
    expect(player.isPlaying, isTrue);
    expect(native.activeUri.queryParameters['seek'], '20');
  });

  tearDown(() async {
    player.dispose();
    await Future<void>.delayed(Duration.zero);
    native.uninstall();
    downloads.dispose();
    app.dispose();
  });

  Future<File> localAudioFile() async {
    final directory =
        await Directory.systemTemp.createTemp('ting-player-source-');
    addTearDown(() => directory.delete(recursive: true));
    return File('${directory.path}${Platform.pathSeparator}chapter.mp3')
        .writeAsBytes([]);
  }

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
    final localFile = await localAudioFile();
    final item = chapter(localFile.uri.toString());
    await player.playChapter(book, [item], item);
    expect(native.loadedUris.single, localFile.uri);
    expect(native.loadedUris.single.scheme, 'file');
    expect(player.usingLocalFile, isTrue);
  });

  for (final gateway in [false, true]) {
    test(
        'indexed client download takes priority over server path (gateway: $gateway)',
        () async {
      final localFile = await localAudioFile();
      downloads.paths['chapter'] = localFile.path;
      if (gateway) {
        app.offlineMode = false;
        app.api.isGatewaySession = () => true;
      }
      final item = chapter('D:/server/book/chapter.strm');
      await player.playChapter(book, [item], item);
      expect(native.loadedUris.single, localFile.uri);
      expect(native.loadedUris.single.scheme, 'file');
      expect(native.loadedHeaders.single, isEmpty);
      expect(player.usingLocalFile, isTrue);
      expect(player.error, isNull);
    });
  }
}
