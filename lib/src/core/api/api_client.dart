import 'dart:convert';

import 'package:dio/dio.dart';

class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: false,
        maxRedirects: 0,
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  late final Dio _dio;
  String _baseUrl = 'http://localhost:3000';
  String? _token;
  String? _cookie;
  Map<String, String> _clientHeaders = const {};
  String _languageCode = 'zh';
  final Map<String, Future<Response<dynamic>>> _inFlightMutations = {};
  int _mutationSequence = 0;
  Future<String?> Function(String failedBaseUrl, CancelToken? cancelToken)?
      recoverBaseUrl;
  bool Function()? isGatewaySession;
  Future<void> Function()? onGatewaySessionExpired;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  String? get cookie => _cookie;
  Map<String, String> get clientHeaders => _clientHeaders;

  /// Headers required by native media clients as well as ordinary API calls.
  ///
  /// Unlike Dio, native audio backends do not share its default headers or
  /// cookie jar, so expose the complete authenticated set explicitly.
  Map<String, String> get authHeaders {
    final headers = <String, String>{
      'Accept-Language': _languageCode,
      ..._clientHeaders,
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (_cookie != null && _cookie!.isNotEmpty) {
      headers['Cookie'] = _cookie!;
    }
    return Map.unmodifiable(headers);
  }

  void configure({required String baseUrl, String? token, String? cookie}) {
    _baseUrl = normalizeServerUrl(baseUrl);
    _token = token;
    _cookie = cookie;
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

  /// Returns an HTTP(S) origin while preserving IPv6 address brackets.
  static String originFromUri(Uri uri) {
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw FormatException('Invalid HTTP server URI: $uri');
    }
    return uri.origin;
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
  }) {
    return _send(
      () => _dio.get<dynamic>(
        path,
        queryParameters: params,
        options: _authOptions(),
        cancelToken: cancelToken,
      ),
      cancelToken: cancelToken,
    );
  }

  /// Fetch a text asset from an absolute URL with the same credentials as API
  /// requests. Plugin UI HTML is an API asset, not an SPA fallback, so callers
  /// need a plain-text response and must not rely on the WebView's document
  /// navigation semantics.
  Future<Response<dynamic>> getTextUri(Uri uri) {
    return _send(
      () => _dio.getUri<dynamic>(
        uri,
        options: Options(
          // Decode plugin documents explicitly in the caller. Some plugin
          // responses omit charset even though their files are UTF-8.
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'text/html,application/xhtml+xml',
            ...authHeaders,
          },
        ),
      ),
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
    Duration? receiveTimeout,
  }) {
    final idempotencyKey = _idempotencyKey();
    if (cancelToken != null) {
      return _send(
        () => _dio.post<dynamic>(
          path,
          data: data,
          queryParameters: params,
          options: _authOptions(
            idempotencyKey: idempotencyKey,
            receiveTimeout: receiveTimeout,
          ),
          cancelToken: cancelToken,
        ),
        cancelToken: cancelToken,
      );
    }
    return _sendMutation(
      'POST',
      path,
      data: data,
      params: params,
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: params,
        options: _authOptions(
          idempotencyKey: idempotencyKey,
          receiveTimeout: receiveTimeout,
        ),
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
    CancelToken? cancelToken,
  }) async {
    var gatewaySessionExpiredNotified = false;
    try {
      final response = await request();
      if (_isGatewaySessionInvalidResponse(response)) {
        gatewaySessionExpiredNotified = true;
        await _notifyGatewaySessionExpired();
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Gateway session returned invalid token',
        );
      }
      if (_isHtmlFallbackForApi(response)) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'API endpoint returned an HTML page',
        );
      }
      return response;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      if (!gatewaySessionExpiredNotified &&
          _isGatewaySessionInvalidResponse(error.response)) {
        gatewaySessionExpiredNotified = true;
        await _notifyGatewaySessionExpired();
      }
      if (retrying || !_shouldTryRecover(error) || recoverBaseUrl == null) {
        rethrow;
      }

      final recovered = await recoverBaseUrl!(_baseUrl, cancelToken);
      if (cancelToken?.isCancelled ?? false) {
        throw DioException(
          requestOptions: error.requestOptions,
          type: DioExceptionType.cancel,
          message: 'Request cancelled',
        );
      }
      if (recovered == null || recovered.isEmpty) rethrow;
      configure(baseUrl: recovered, token: _token, cookie: _cookie);
      return _send(request, retrying: true, cancelToken: cancelToken);
    }
  }

  Future<void> _notifyGatewaySessionExpired() async {
    final handler = onGatewaySessionExpired;
    if (handler == null) return;
    try {
      await handler();
    } catch (_) {
      // Session detection must not hide the original API response.
    }
  }

  bool _isGatewaySessionInvalidResponse(Response<dynamic>? response) {
    if (response == null) return false;
    if (!(isGatewaySession?.call() ?? false)) return false;
    final status = response.statusCode;
    // fnOS Connect can return a plain "invalid token" body with HTTP 200.
    // Only an explicit token marker in a successful response is handled here;
    // ordinary HTTP failures remain ordinary API failures.
    if (status == null || status < 200 || status >= 300) return false;

    return isInvalidGatewayTokenPayload(response.data);
  }

  /// Whether a gateway response explicitly reports an expired fnOS session.
  ///
  /// fnOS Connect can report this condition with HTTP 200, so callers must not
  /// treat generic transport or progress-sync errors as a reason to re-login.
  static bool isInvalidGatewayTokenPayload(Object? payload) {
    if (payload is Map) {
      for (final key in const ['error', 'message', 'detail', 'code', 'type']) {
        if (_isInvalidTokenText(payload[key]?.toString())) return true;
      }
      return false;
    }
    if (payload is List<int>) {
      return _isInvalidTokenText(utf8.decode(payload, allowMalformed: true));
    }
    return _isInvalidTokenText(payload?.toString());
  }

  static bool _isInvalidTokenText(String? value) {
    var normalized =
        value?.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ' ') ?? '';
    if (normalized.length >= 2 &&
        normalized.startsWith('"') &&
        normalized.endsWith('"')) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
    return normalized == 'invalid token' ||
        normalized == 'token is invalid' ||
        normalized == 'invalid fnos token';
  }

  bool _isHtmlFallbackForApi(Response<dynamic> response) {
    final path = response.requestOptions.uri.path;
    if (!path.contains('/api/')) return false;

    // Plugin UI documents are intentionally served as text/html from an API
    // asset route. They must not be mistaken for the application's SPA shell.
    if (path.contains('/api/v1/plugin-assets/') ||
        path.contains('/api/plugin-assets/')) {
      return false;
    }

    final contentType =
        response.headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';
    if (contentType.contains('text/html')) return true;

    final body = response.data;
    if (body is! String) return false;
    final trimmed = body.trimLeft().toLowerCase();
    return trimmed.startsWith('<!doctype html') ||
        trimmed.startsWith('<html') ||
        trimmed.startsWith('<head');
  }

  bool _shouldTryRecover(DioException error) {
    final status = error.response?.statusCode;
    if (status == null) return true;
    return status == 502 || status == 503 || status == 504;
  }

  Options _authOptions({
    String? idempotencyKey,
    Duration? receiveTimeout,
  }) {
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
      'Accept-Language': _languageCode,
      ..._clientHeaders,
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (_cookie != null && _cookie!.isNotEmpty) {
      headers['Cookie'] = _cookie;
    }
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return Options(headers: headers, receiveTimeout: receiveTimeout);
  }
}
