import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

void configureFnConnectHttpAdapter(Dio dio, {required bool ignoreSsl}) {
  if (!ignoreSsl) return;
  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) return;
  adapter.createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => true;
    return client;
  };
}
