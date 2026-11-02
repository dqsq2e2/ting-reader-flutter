import 'dart:async';

class SocketHeartbeat {
  SocketHeartbeat(
      {required this.sendPing,
      required this.onTimeout,
      this.interval = const Duration(seconds: 25),
      this.timeout = const Duration(seconds: 10)});
  final void Function() sendPing;
  final void Function() onTimeout;
  final Duration interval;
  final Duration timeout;
  Timer? _timer;
  Timer? _deadline;

  void start() {
    stop();
    _timer = Timer.periodic(interval, (_) {
      if (_deadline != null) return;
      _deadline = Timer(timeout, _failed);
      try {
        sendPing();
      } catch (_) {
        _failed();
      }
    });
  }

  void pong() {
    _deadline?.cancel();
    _deadline = null;
  }

  void _failed() {
    stop();
    onTimeout();
  }

  void stop() {
    _timer?.cancel();
    _deadline?.cancel();
    _timer = null;
    _deadline = null;
  }
}
