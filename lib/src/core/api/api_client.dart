import 'dart:convert';

import 'package:dio/dio.dart';

class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  late final Dio _dio;
  String _baseUrl = 'http://localhost:3000';
  String? _token;
  Map<String, String> _clientHeaders = const {};
  String _languageCode = 'zh';
  final Map<String, Future<Response<dynamic>>> _inFlightMutations = {};
  int _mutationSequence = 0;
  Future<String?> Function(String failedBaseUrl)? recoverBaseUrl;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  Map<String, String> get clientHeaders => _clientHeaders;

  void configure({required String baseUrl, String? token}) {
    _baseUrl = normalizeServerUrl(baseUrl);
    _token = token;
    _dio.options.baseUrl = _baseUrl;
  }

  void setClientHeaders(Map<String, String> headers) {
    _clientHeaders = Map.unmodifiable(headers);
  }

  void setLanguage(String languageCode) {
    _languageCode = languageCode.toLowerCase().startsWith('en') ? 'en' : 'zh';
  }

  static String normalizeServerUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) return 'http://localhost:3000';
    if (!value.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      value = 'http://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) {
    return _send(
      () => _dio.get<dynamic>(
        path,
        queryParameters: params,
        options: _authOptions(),
      ),
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? params,
  }) {
    final idempotencyKey = _idempotencyKey();
    return _sendMutation(
      'POST',
      path,
      data: data,
      params: params,
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: params,
        options: _authOptions(idempotencyKey: idempotencyKey),
      ),
    );
  }

  Future<Response<dynamic>> put(String path, {Object? data}) {
    final idempotencyKey = _idempotencyKey();
    return _sendMutation(
      'PUT',
      path,
      data: data,
      () => _dio.put<dynamic>(
        path,
        data: data,
        options: _authOptions(idempotencyKey: idempotencyKey),
      ),
    );
  }

  Future<Response<dynamic>> patch(String path, {Object? data}) {
    final idempotencyKey = _idempotencyKey();
    return _sendMutation(
      'PATCH',
      path,
      data: data,
      () => _dio.patch<dynamic>(
        path,
        data: data,
        options: _authOptions(idempotencyKey: idempotencyKey),
      ),
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? params,
  }) {
    final idempotencyKey = _idempotencyKey();
    return _sendMutation(
      'DELETE',
      path,
      data: data,
      params: params,
      () => _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: params,
        options: _authOptions(idempotencyKey: idempotencyKey),
      ),
    );
  }

  Future<Response<dynamic>> _sendMutation(
    String method,
    String path,
    Future<Response<dynamic>> Function() request, {
    Object? data,
    Map<String, dynamic>? params,
  }) {
    final fingerprint = _mutationFingerprint(method, path, data, params);
    final existing = _inFlightMutations[fingerprint];
    if (existing != null) return existing;

    final future = _send(request).whenComplete(() {
      _inFlightMutations.remove(fingerprint);
    });
    _inFlightMutations[fingerprint] = future;
    return future;
  }

  String _mutationFingerprint(
    String method,
    String path,
    Object? data,
    Map<String, dynamic>? params,
  ) {
    return '$method|$_baseUrl|$path|${_stableEncode(params)}|${_stableEncode(data)}';
  }

  String _idempotencyKey() {
    final now = DateTime.now();
    return '${now.microsecondsSinceEpoch}-${_mutationSequence++}';
  }

  String _stableEncode(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return '{${keys.map((key) => '$key:${_stableEncode(value[key])}').join(',')}}';
    }
    if (value is Iterable) {
      return '[${value.map(_stableEncode).join(',')}]';
    }
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() request, {
    bool retrying = false,
  }) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (retrying || !_shouldTryRecover(error) || recoverBaseUrl == null) {
        rethrow;
      }

      final recovered = await recoverBaseUrl!(_baseUrl);
      if (recovered == null || recovered.isEmpty) rethrow;
      configure(baseUrl: recovered, token: _token);
      return _send(request, retrying: true);
    }
  }

  bool _shouldTryRecover(DioException error) {
    final status = error.response?.statusCode;
    if (status == null) return true;
    return status == 502 || status == 503 || status == 504;
  }

  Options _authOptions({String? idempotencyKey}) {
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
      'Accept-Language': _languageCode,
      ..._clientHeaders,
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return Options(headers: headers);
  }
}
