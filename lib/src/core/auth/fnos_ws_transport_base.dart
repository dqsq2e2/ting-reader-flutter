class FnosWebSocketClosedException implements Exception {
  const FnosWebSocketClosedException();

  @override
  String toString() => 'fnOS WebSocket closed before a response arrived';
}

abstract interface class FnosWebSocketSession {
  Future<Map<String, dynamic>> request(
    Map<String, dynamic> payload, {
    required bool Function(Map<String, dynamic> response) matches,
    Duration timeout = const Duration(seconds: 12),
  });

  Future<void> close();
}
