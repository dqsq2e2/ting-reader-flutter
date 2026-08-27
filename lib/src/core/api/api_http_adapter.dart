import 'package:dio/dio.dart';

import 'api_http_adapter_stub.dart'
    if (dart.library.io) 'api_http_adapter_io.dart' as platform;

void configureApiHttpAdapter(
  Dio dio, {
  required bool Function() allowBadCertificate,
}) {
  platform.configureApiHttpAdapter(
    dio,
    allowBadCertificate: allowBadCertificate,
  );
}
