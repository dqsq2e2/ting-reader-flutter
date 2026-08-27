import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'fnos_ws_transport_base.dart';

Future<FnosWebSocketSession> connectFnosWebSocket(
  Uri uri, {
  required Map<String, String> headers,
}) async {
  final socket = await WebSocket.connect(uri.toString(), headers: headers)
      .timeout(const Duration(seconds: 12));
  return _IoFnosWebSocketSession(socket);
}

class _IoFnosWebSocketSession implements FnosWebSocketSession {
  _IoFnosWebSocketSession(this._socket)
      : _messages = StreamIterator<dynamic>(_socket);

  final WebSocket _socket;
  final StreamIterator<dynamic> _messages;
  bool _closed = false;

  @override
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> payload, {
    required bool Function(Map<String, dynamic> response) matches,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_closed) throw StateError('fnOS WebSocket is already closed');
    _socket.add(jsonEncode(payload));

    while (await _messages.moveNext().timeout(timeout)) {
      final current = _messages.current;
      final text = switch (current) {
        String value => value,
        List<int> value => utf8.decode(value, allowMalformed: true),
        _ => current.toString(),
      };
      final decoded = jsonDecode(text);
      if (decoded is! Map) continue;
      final response = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (matches(response)) return response;
    }
    throw StateError('fnOS WebSocket closed before a response arrived');
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _messages.cancel();
    await _socket.close();
  }
}
