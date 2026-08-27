import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

void configureApiHttpAdapter(
  Dio dio, {
  required bool Function() allowBadCertificate,
}) {
  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) return;
  adapter.createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => allowBadCertificate();
    return client;
  };
}
