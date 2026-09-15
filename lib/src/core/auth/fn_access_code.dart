import 'dart:convert';

import 'package:dio/dio.dart';

import 'fn_connect_http_adapter.dart';

/// fnOS「访问码」检查结果。
///
/// 对应网关 `/access_code_verify` 端点（参考 FeiNiuMusic 的
/// access_code_service.dart，与飞牛网页版行为一致）：
/// - GET 返回 2xx 且未携带访问码 → 服务器未开启访问码防护（[notRequired]）；
/// - GET 携带正确访问码返回 2xx → 访问码有效（[accepted]）；
/// - GET 返回 401 / 403 / 429 → 需要访问码或访问码错误
///   （未携带时为 [required]，携带后为 [rejected]）；
/// - 其余情况（网络异常 / 端点不存在）→ [unknown]，调用方按「暂不要求」处理，
///   避免把没开访问码的服务器挡在门外。
enum FnAccessCodeStatus { notRequired, required, accepted, rejected, unknown }

/// fnOS 统一网关「访问码」辅助。
///
/// 访问码是飞牛在 FN Connect 远程入口加的统一中间件校验（内网直连不受限）。
/// 开启后，所有经过网关的请求（含 WebSocket 握手、音频流）都必须携带：
/// `x-access-code: base64(访问码)` 与 `x-access-source: app`。
class FnAccessCode {
  const FnAccessCode._();

  static const String _verifyPath = '/access_code_verify';

  /// 访问码请求头（[code] 为空时返回空 Map）。
  static Map<String, String> headers(String? code) {
    final value = code?.trim() ?? '';
    if (value.isEmpty) return const {};
    return {
      'x-access-code': base64.encode(utf8.encode(value)),
      'x-access-source': 'app',
    };
  }

  /// 探测 [rootUrl]（如 `https://fnid.fnos.net`）的访问码要求。
  ///
  /// [accessCode] 非空时同时校验访问码是否有效；[relay] 为 true 时携带
  /// `Cookie: mode=relay`（中继链路下网关才识别该请求，否则会被 302 跳走）。
  static Future<FnAccessCodeStatus> probe(
    String rootUrl, {
    String? accessCode,
    bool relay = true,
    bool ignoreSsl = true,
    CancelToken? cancelToken,
  }) async {
    final trimmed = rootUrl.trim();
    if (trimmed.isEmpty) return FnAccessCodeStatus.unknown;
    final base = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        followRedirects: false,
        validateStatus: (_) => true,
      ),
    );
    configureFnConnectHttpAdapter(dio, ignoreSsl: ignoreSsl);
    try {
      final code = accessCode?.trim() ?? '';
      final response = await dio.get<dynamic>(
        '$base$_verifyPath',
        cancelToken: cancelToken,
        options: Options(
          headers: {
            if (relay) 'Cookie': 'mode=relay',
            ...headers(code),
          },
        ),
      );
      final status = response.statusCode ?? 0;
      if (status == 401 || status == 403 || status == 429) {
        return code.isEmpty
            ? FnAccessCodeStatus.required
            : FnAccessCodeStatus.rejected;
      }
      if (status >= 200 && status < 300) {
        return code.isEmpty
            ? FnAccessCodeStatus.notRequired
            : FnAccessCodeStatus.accepted;
      }
      return FnAccessCodeStatus.unknown;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      return FnAccessCodeStatus.unknown;
    } finally {
      dio.close();
    }
  }
}
