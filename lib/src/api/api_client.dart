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
    return _send(
      () => _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: params,
        options: _authOptions(),
      ),
    );
  }

  Future<Response<dynamic>> put(String path, {Object? data}) {
    return _send(
      () => _dio.put<dynamic>(path, data: data, options: _authOptions()),
    );
  }

  Future<Response<dynamic>> patch(String path, {Object? data}) {
    return _send(
      () => _dio.patch<dynamic>(path, data: data, options: _authOptions()),
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? params,
  }) {
    return _send(
      () => _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: params,
        options: _authOptions(),
      ),
    );
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

  Options _authOptions() {
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
      ..._clientHeaders,
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return Options(headers: headers);
  }
}
