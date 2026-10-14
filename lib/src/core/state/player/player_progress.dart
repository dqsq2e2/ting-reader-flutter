part of '../player_state.dart';

typedef _ProgressSnapshot = ({
  Book book,
  Chapter chapter,
  double position,
  double duration,
});

/// Owns progress transport, timers and sockets; receives playback snapshots
/// without changing the audio source or chapter-selection state.
class _PlayerProgress {
  _PlayerProgress({
    required this.appState,
    required this.snapshot,
    required this.suspended,
    required this.needsHttpFallback,
    required this.onRemotePosition,
  });

  final AppState appState;
  final _ProgressSnapshot? Function() snapshot;
  final bool Function() suspended;
  final bool Function() needsHttpFallback;
  final void Function(String? bookId, String? chapterId, double position)
      onRemotePosition;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _webSocketTimer;
  Timer? _httpTimer;
  bool _connecting = false;
  bool _disposed = false;
  int _generation = 0;

  bool get _blocked => _disposed || appState.offlineMode || suspended();

  Future<void> send({double? playbackStart}) async {
    if (_blocked) return;
    final value = snapshot();
    if (value == null) return;
    if (await _sendWebSocket(value, playbackStart: playbackStart)) return;
    if (!_blocked) await _sendHttp(value, playbackStart: playbackStart);
  }

  Future<void> _sendCurrentWebSocket() async {
    if (_blocked) return;
    final value = snapshot();
    if (value != null) await _sendWebSocket(value);
  }

  Future<void> _sendCurrentHttp() async {
    if (_blocked || (!kIsWeb && _socket != null && !needsHttpFallback())) {
      return;
    }
    final value = snapshot();
    if (value != null) await _sendHttp(value);
  }

  Future<void> _sendHttp(_ProgressSnapshot value,
      {double? playbackStart}) async {
    if (_blocked) return;
    try {
      await appState.api.post('/api/progress', data: {
        'book_id': value.book.id,
        'chapter_id': value.chapter.id,
        'position': value.position,
        'duration':
            value.duration > 0 ? value.duration : value.chapter.duration,
        if (playbackStart != null) 'playback_start': playbackStart,
      });
    } catch (_) {
      // Background progress synchronization must not interrupt listening.
    }
  }

  Future<bool> _sendWebSocket(_ProgressSnapshot value,
      {double? playbackStart}) async {
    if (kIsWeb || _blocked || (appState.token?.isEmpty ?? true)) return false;
    try {
      final socket = await _ensureSocket();
      if (socket == null || _blocked) return false;
      socket.add(jsonEncode({
        'type': 'progress_update',
        'book_id': value.book.id,
        'chapter_id': value.chapter.id,
        'position': value.position.floor(),
        if (playbackStart != null) 'playback_start': playbackStart.floor(),
      }));
      return true;
    } catch (error) {
      if (_invalidGatewayToken(error)) _reauthenticate();
      closeSocket();
      return false;
    }
  }

  Future<WebSocket?> _ensureSocket() async {
    if (_blocked) return null;
    if (_socket != null) return _socket;
    if (_connecting) return null;
    _connecting = true;
    final generation = _generation;
    final authRevision = appState.api.authRevision;
    var acceptConnection = true;
    try {
      final uri = _socketUri();
      if (uri == null) return null;
      final headers = appState.api.authHeaders;
      // A timed-out connect can still finish later. Close that late socket
      // instead of losing ownership of an open connection.
      final connection = WebSocket.connect(
        uri.toString(),
        headers: headers.isEmpty ? null : headers,
      ).then((socket) async {
        if (!acceptConnection ||
            _blocked ||
            generation != _generation ||
            authRevision != appState.api.authRevision) {
          await socket.close();
          return null;
        }
        return socket;
      });
      final socket = await connection.timeout(const Duration(seconds: 5));
      if (socket == null) return null;
      _socket = socket;
      _subscription = socket.listen(
        _handleMessage,
        onDone: () {
          if (!identical(_socket, socket)) return;
          if (_invalidGatewayToken(socket.closeReason)) _reauthenticate();
          closeSocket();
        },
        onError: (Object error) {
          if (!identical(_socket, socket)) return;
          if (_invalidGatewayToken(error)) _reauthenticate();
          closeSocket();
        },
        cancelOnError: true,
      );
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _socket?.add(jsonEncode({'type': 'ping'}));
        } catch (_) {
          closeSocket();
        }
      });
      return socket;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        if (_invalidGatewayToken(error)) _reauthenticate();
        closeSocket();
      }
      return null;
    } finally {
      acceptConnection = false;
      _connecting = false;
    }
  }

  Uri? _socketUri() {
    final token = appState.token;
    if (token == null || token.isEmpty) return null;
    final base = Uri.tryParse(appState.activeUrl);
    if (base == null || base.host.isEmpty) return null;
    final path = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '$path/api/ws',
      queryParameters: {'token': token},
    );
  }

  void _handleMessage(dynamic message) {
    if (_disposed || message == null) return;
    try {
      final raw = message is List<int>
          ? utf8.decode(message, allowMalformed: true)
          : message.toString();
      if (_invalidGatewayToken(raw)) {
        _reauthenticate();
        return;
      }
      final data = jsonDecode(raw);
      if (_invalidGatewayToken(data)) {
        _reauthenticate();
        return;
      }
      if (data is! Map || data['type'] != 'progress_updated') return;
      final position = _doubleValue(data['position']);
      if (position == null || !position.isFinite) return;
      onRemotePosition(data['book_id']?.toString(),
          data['chapter_id']?.toString(), position);
    } catch (_) {
      // Malformed realtime packets must not affect playback.
    }
  }

  bool _invalidGatewayToken(Object? value) =>
      (appState.api.isGatewaySession?.call() ?? false) &&
      ApiClient.isInvalidGatewayTokenPayload(value);

  void _reauthenticate() {
    closeSocket();
    if (!_disposed) unawaited(appState.handleGatewaySessionExpired());
  }

  void start(double position) {
    if (_blocked) return;
    stop();
    unawaited(send(playbackStart: position));
    _webSocketTimer = Timer.periodic(
        const Duration(seconds: 2), (_) => unawaited(_sendCurrentWebSocket()));
    _httpTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => unawaited(_sendCurrentHttp()));
  }

  void stop() {
    _webSocketTimer?.cancel();
    _webSocketTimer = null;
    _httpTimer?.cancel();
    _httpTimer = null;
  }

  void closeSocket() {
    _generation++;
    _pingTimer?.cancel();
    _pingTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) unawaited(socket.close());
  }

  void dispose() {
    _disposed = true;
    stop();
    closeSocket();
  }
}
