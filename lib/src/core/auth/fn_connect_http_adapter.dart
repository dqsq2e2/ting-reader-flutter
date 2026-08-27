import 'package:dio/dio.dart';

import 'fn_connect_http_adapter_stub.dart'
    if (dart.library.io) 'fn_connect_http_adapter_io.dart' as platform;

void configureFnConnectHttpAdapter(Dio dio, {required bool ignoreSsl}) {
  platform.configureFnConnectHttpAdapter(dio, ignoreSsl: ignoreSsl);
}
