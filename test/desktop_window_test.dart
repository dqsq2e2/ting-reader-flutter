import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/l10n/app_localizations.dart';
import 'package:ting_reader_flutter/src/core/services/desktop_window.dart';
import 'package:ting_reader_flutter/src/core/models/models.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';
import 'package:ting_reader_flutter/src/features/player/desktop_window_host.dart';
import 'package:ting_reader_flutter/src/features/player/small_player_window.dart';
import 'package:ting_reader_flutter/src/shared/app_scope.dart';

class _Player extends ChangeNotifier implements PlayerState {
  @override
  Book? get currentBook =>
      const Book(id: 'b', libraryId: 'l', title: 'A long book title');
  @override
  Chapter? get currentChapter => const Chapter(
      id: 'c',
      bookId: 'b',
      title: 'A long chapter title',
      path: '/test.mp3',
      chapterIndex: 1,
      duration: 600);
  @override
  bool get hasChapter => true;
  @override
  double get duration => 600;
  @override
  double get currentTime => 20;
  @override
  bool get isPlaying => false;
  @override
  bool get isLoading => false;
  int toggles = 0;
  int seeks = 0;
  @override
  Future<void> togglePlay() async {
    toggles++;
  }

  @override
  Future<void> seek(double seconds) async {
    seeks++;
  }

  @override
  Future<void> nextChapter({bool fromOutro = false}) async {}
  @override
  Future<void> previousChapter() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RetainedPage extends StatefulWidget {
  const _RetainedPage({required this.created, required this.destroyed});
  final VoidCallback created;
  final VoidCallback destroyed;
  @override
  State<_RetainedPage> createState() => _RetainedPageState();
}

class _RetainedPageState extends State<_RetainedPage> {
  @override
  void initState() {
    super.initState();
    widget.created();
  }

  @override
  void dispose() {
    widget.destroyed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Center(child: Text('Main page'));
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ting_reader/window');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  });

  test('mini mode toggles the existing native window', () async {
    final window = DesktopWindow();
    addTearDown(window.dispose);
    await window.setMini(true);
    expect(window.isMini, isTrue);
    await window.setMini(false);
    expect(window.isMini, isFalse);
    expect(calls.map((call) => call.method), ['setMiniMode', 'setMiniMode']);
    expect(calls.map((call) => call.arguments), [true, false]);
  });

  for (final platform in TargetPlatform.values) {
    test('desktop window capability is scoped correctly on $platform',
        () async {
      debugDefaultTargetPlatformOverride = platform;
      final window = DesktopWindow();
      addTearDown(window.dispose);
      final desktop = [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux
      ].contains(platform);
      expect(window.supported, desktop);
      expect(window.usesCustomTitleBar, platform == TargetPlatform.windows);
      await window.setMini(true);
      expect(window.isMini, desktop);
      expect(calls.length, desktop ? 1 : 0);
    });
  }

  test('failed native resize restores the previous mini state', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel, (_) async => throw PlatformException(code: 'resize_failed'));
    final window = DesktopWindow();
    addTearDown(window.dispose);
    await expectLater(window.setMini(true), throwsA(isA<PlatformException>()));
    expect(window.isMini, isFalse);
  });

  test('maximize exits mini mode before maximizing the main window', () async {
    final window = DesktopWindow();
    addTearDown(window.dispose);
    await window.setMini(true);
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      return call.method == 'toggleMaximize' ? true : null;
    });
    await window.toggleMaximize();
    expect(window.isMini, isFalse);
    expect(window.isMaximized, isTrue);
    expect(calls.map((call) => call.method), ['setMiniMode', 'toggleMaximize']);
    expect(calls.map((call) => call.arguments), [false, true]);
  });

  test('native maximize and mini events keep the rendered mode synchronized',
      () async {
    final app = AppState();
    final window = DesktopWindow();
    addTearDown(app.dispose);
    addTearDown(window.dispose);
    await window.initialize(app);
    Future<void> native(String method, bool value) async {
      final complete = Completer<void>();
      binding.channelBuffers.push(
          channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(MethodCall(method, value)),
          (_) => complete.complete());
      await complete.future;
    }

    await native('miniModeChanged', true);
    expect(window.isMini, isTrue);
    await native('maximizedChanged', true);
    expect(window.isMini, isFalse);
    expect(window.isMaximized, isTrue);
    expect(calls.last.method, 'setMiniMode');
    await native('miniModeChanged', false);
    expect(window.isMini, isFalse);
  });

  test('caption controls and explicit exit remain available in minimize mode',
      () async {
    final window = DesktopWindow()..closeBehavior = 'minimize';
    addTearDown(window.dispose);
    await window.close();
    await window.startDragging();
    await window.toggleMaximize();
    await window.requestExit();
    expect(calls.map((call) => call.method),
        ['close', 'startDragging', 'toggleMaximize', 'exit']);
    expect(window.closeBehavior, 'minimize');
  });

  test('saved close preference reaches the native window', () async {
    final app = AppState()..settings = {'desktop_close_behavior': 'minimize'};
    final window = DesktopWindow();
    addTearDown(app.dispose);
    addTearDown(window.dispose);
    await window.initialize(app);
    expect(calls.single.method, 'setCloseBehavior');
    expect(calls.single.arguments, 'minimize');
    app.settings = {'desktop_close_behavior': 'exit'};
    app.notifyListeners();
    expect(calls.last.arguments, 'exit');
    await window.minimize();
    await window.exit();
    expect(calls.map((call) => call.method),
        ['setCloseBehavior', 'setCloseBehavior', 'minimize', 'exit']);
  });

  testWidgets(
      'mini window keeps the main page and restores it without remounting',
      (tester) async {
    final window = DesktopWindow.instance;
    window.isMini = false;
    var created = 0;
    var destroyed = 0;
    final app = AppState();
    final player = _Player();
    final downloads = DownloadState(app);
    addTearDown(app.dispose);
    addTearDown(player.dispose);
    addTearDown(downloads.dispose);
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(AppScope(
        appState: app,
        downloadState: downloads,
        playerState: player,
        child: MaterialApp(
            home: DesktopWindowHost(
                openChapters: () async {},
                child: _RetainedPage(
                    created: () => created++, destroyed: () => destroyed++)))));
    await tester.pumpAndSettle();
    expect(created, 1);
    expect(find.byType(MenuAnchor), findsNothing);
    expect(find.byIcon(Icons.headphones_rounded), findsNothing);
    expect(find.text('Ting Reader'), findsNothing);
    expect(find.text('听悦'), findsNothing);
    for (final button in find.byType(IconButton).evaluate()) {
      expect(tester.getRect(find.byWidget(button.widget)).left,
          greaterThanOrEqualTo(1000 - 44 * 4));
    }
    await window.setMini(true);
    await tester.binding.setSurfaceSize(const Size(560, 150));
    await tester.pumpAndSettle();
    expect(find.byType(SmallPlayerWindow), findsOneWidget);
    expect(find.byType(MenuAnchor), findsNothing);
    expect(find.byIcon(Icons.headphones_rounded), findsNothing);
    expect(find.text('Ting Reader · Mini'), findsNothing);
    expect(find.text('听悦 · 小窗'), findsNothing);
    expect(created, 1);
    expect(destroyed, 0);
    expect(tester.takeException(), isNull);
    await window.toggleMaximize();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpAndSettle();
    expect(window.isMini, isFalse);
    expect(find.byType(SmallPlayerWindow), findsNothing);
    expect(find.text('Main page'), findsOneWidget);
    expect(created, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(destroyed, 1);
    await tester.binding.setSurfaceSize(null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final width in [420.0, 560.0]) {
    testWidgets('mini player has usable controls at width $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 140));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final app = AppState();
      final player = _Player();
      final downloads = DownloadState(app);
      addTearDown(app.dispose);
      addTearDown(player.dispose);
      addTearDown(downloads.dispose);
      var chapters = 0;
      await tester.pumpWidget(AppScope(
          appState: app,
          downloadState: downloads,
          playerState: player,
          child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SmallPlayerWindow(openChapters: () async {
                chapters++;
              }))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Chapters').last);
      await tester.tap(find.byTooltip('Play or pause'));
      expect(chapters, 1);
      expect(player.toggles, 1);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(40);
      slider.onChanged!(50);
      expect(player.seeks, 0);
      slider.onChangeEnd!(50);
      expect(player.seeks, 1);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  for (final brightness in Brightness.values) {
    for (final action in WindowCaptionAction.values) {
      testWidgets('caption $action paints visible lines in $brightness',
          (tester) async {
        final key = GlobalKey();
        final background =
            brightness == Brightness.dark ? Colors.black : Colors.white;
        final foreground =
            brightness == Brightness.dark ? Colors.white : Colors.black;
        await tester.pumpWidget(MaterialApp(
            home: Center(
                child: RepaintBoundary(
                    key: key,
                    child: ColoredBox(
                        color: background,
                        child: SizedBox(
                            width: 44,
                            height: 34,
                            child: Center(
                                child: IconTheme(
                                    data: IconThemeData(color: foreground),
                                    child: WindowCaptionIcon(action)))))))));
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final pixels = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          } finally {
            image.dispose();
          }
        });
        var visible = 0;
        for (var offset = 0; offset < pixels!.lengthInBytes; offset += 4) {
          final red = pixels.getUint8(offset);
          if (brightness == Brightness.dark ? red > 128 : red < 128) visible++;
        }
        expect(visible, greaterThan(12));
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
