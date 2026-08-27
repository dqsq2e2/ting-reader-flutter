import 'fnos_ws_transport_base.dart';
import 'fnos_ws_transport_stub.dart'
    if (dart.library.io) 'fnos_ws_transport_io.dart' as platform;

export 'fnos_ws_transport_base.dart';

Future<FnosWebSocketSession> connectFnosWebSocket(
  Uri uri, {
  required Map<String, String> headers,
}) {
  return platform.connectFnosWebSocket(uri, headers: headers);
}
