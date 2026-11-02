import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

class SessionMonitor with WidgetsBindingObserver {
  SessionMonitor(
      {required this.enabled,
      required this.check,
      this.interval = const Duration(minutes: 1),
      this.timeout = const Duration(seconds: 10)});
  final bool Function() enabled;
  final Future<void> Function(CancelToken token) check;
  final Duration interval;
  final Duration timeout;
  Timer? _timer;
  CancelToken? _cancel;
  Future<bool>? _checking;
  bool _disposed = false;

  void start() {
    if (_disposed || _timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(interval, (_) => unawaited(checkNow()));
  }

  Future<bool> checkNow() {
    if (_disposed || !enabled()) return Future.value(false);
    return _checking ??= _check().whenComplete(() {
      _checking = null;
    });
  }

  Future<bool> _check() async {
    final cancellation = CancelToken();
    _cancel = cancellation;
    try {
      await check(cancellation).timeout(timeout, onTimeout: () {
        cancellation.cancel('会话检查超时');
        throw TimeoutException('会话检查超时');
      });
      return !_disposed && !cancellation.isCancelled;
    } catch (_) {
      // 网络故障保留本地登录状态，下一轮或恢复前台时再次检查。
      return false;
    } finally {
      if (identical(_cancel, cancellation)) _cancel = null;
    }
  }

  void cancel() => _cancel?.cancel('会话已切换');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(checkNow());
  }

  void dispose() {
    _disposed = true;
    if (_timer != null) WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    cancel();
  }
}
