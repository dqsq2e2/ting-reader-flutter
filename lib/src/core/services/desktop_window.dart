import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';

class DesktopWindow extends ChangeNotifier {
  static final instance = DesktopWindow();
  static const _channel = MethodChannel('ting_reader/window');
  bool get supported =>
      !kIsWeb &&
      [TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux]
          .contains(defaultTargetPlatform);
  bool get usesCustomTitleBar =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  bool isMini = false;
  Size normalSize = const Size(1280, 720);
  String closeBehavior = 'exit';
  bool isMaximized = false;
  Future<void> Function()? onCloseRequested;
  Future<void> Function()? onExitRequested;
  AppState? _app;
  VoidCallback? _syncPreferences;
  bool _disposed = false;
  bool _initialized = false;
  int _miniGeneration = 0;

  Future<void> initialize(AppState app) async {
    if (!supported || _disposed) return;
    final previousSync = _syncPreferences;
    if (previousSync != null) _app?.removeListener(previousSync);
    _app = app;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'closeRequested') await onCloseRequested?.call();
      if (call.method == 'maximizedChanged') {
        if (call.arguments == true && isMini) await setMini(false);
        final value = call.arguments == true;
        if (isMaximized != value) {
          isMaximized = value;
          notifyListeners();
        }
      }
      if (call.method == 'miniModeChanged' &&
          call.arguments is bool &&
          isMini != call.arguments) {
        _miniGeneration++;
        isMini = call.arguments as bool;
        notifyListeners();
      }
    });
    void sync() {
      final value = app.settings['desktop_close_behavior']?.toString();
      final next = ['exit', 'minimize'].contains(value) ? value! : 'exit';
      if (_initialized && next == closeBehavior) return;
      _initialized = true;
      closeBehavior = next;
      _channel.invokeMethod<void>('setCloseBehavior', next);
      notifyListeners();
    }

    _syncPreferences = sync;
    app.addListener(sync);
    sync();
  }

  Future<void> setMini(bool value) async {
    if (_disposed || !supported || value == isMini) return;
    final generation = ++_miniGeneration;
    isMini = value;
    notifyListeners();
    try {
      await _channel.invokeMethod<void>('setMiniMode', value);
    } catch (_) {
      if (!_disposed && generation == _miniGeneration) {
        isMini = !value;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> minimize() => _channel.invokeMethod<void>('minimize');
  Future<void> exit() => _channel.invokeMethod<void>('exit');
  Future<void> close() => _channel.invokeMethod<void>('close');
  Future<void> startDragging() => _channel.invokeMethod<void>('startDragging');

  Future<void> toggleMaximize() async {
    final wasMini = isMini;
    if (wasMini) await setMini(false);
    isMaximized = await _channel.invokeMethod<bool>(
            'toggleMaximize', wasMini ? true : null) ??
        false;
    notifyListeners();
  }

  Future<void> requestExit() async {
    final handler = onExitRequested;
    if (handler != null) {
      await handler();
    } else {
      await exit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_initialized) _channel.setMethodCallHandler(null);
    final sync = _syncPreferences;
    if (sync != null) _app?.removeListener(sync);
    super.dispose();
  }
}
