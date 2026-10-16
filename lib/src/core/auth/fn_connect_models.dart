import '../models/_helpers.dart' show asMap, readInt, readStringList;
import 'fnos_gateway_auth.dart';

enum FnConnectStage { resolving, signingIn, probing, tingReaderLogin }

enum FnConnectCandidateGroup { lan, publicIpv6, publicIpv4, relay }

class FnConnectException implements Exception {
  const FnConnectException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FnConnectAuthenticationException extends FnConnectException {
  const FnConnectAuthenticationException(super.message);
}

class FnConnectProtocolException extends FnConnectException {
  const FnConnectProtocolException(super.message);
}

class FnConnectTwofaTrustPendingException extends FnConnectProtocolException {
  const FnConnectTwofaTrustPendingException()
      : super('飞牛正在登记受信设备，登录连接已关闭；请稍后重试');
}

/// 飞牛账号已开启访问码保护，但调用方未提供访问码。
class FnConnectAccessCodeRequiredException extends FnConnectException {
  const FnConnectAccessCodeRequiredException() : super('服务器已开启访问码，请输入访问码');
}

/// 访问码校验失败（访问码错误）。
class FnConnectAccessCodeException extends FnConnectAuthenticationException {
  const FnConnectAccessCodeException() : super('访问码错误，请检查后重试');
}

/// 飞牛账号已开启二步验证，需要输入动态验证码（OTP）才能继续登录。
///
/// 仅在未提供登录的 `onTwofaRequired` 回调时抛出；
/// 提供回调后 SDK 会自动完成 `user.2fa.loginVerify` 流程。
class FnConnectTwofaRequiredException extends FnConnectException {
  const FnConnectTwofaRequiredException() : super('飞牛账号已开启二步验证，请输入动态验证码');
}

/// 飞牛账号被管理员强制要求二步验证，但尚未绑定 TOTP 密钥，
/// 必须先在飞牛网页端「个人设置 → 双重验证」完成绑定后才能登录。
class FnConnectTwofaSetupRequiredException extends FnConnectException {
  const FnConnectTwofaSetupRequiredException()
      : super('飞牛账号被要求启用二步验证，请先在飞牛网页端完成双重验证绑定');
}

/// 二步验证码（OTP）校验失败。
class FnConnectTwofaInvalidException extends FnConnectAuthenticationException {
  const FnConnectTwofaInvalidException() : super('二步验证码错误或已过期');
}

/// 用户在二步验证输入环节取消。
class FnConnectTwofaCancelledException extends FnConnectException {
  const FnConnectTwofaCancelledException() : super('已取消二步验证');
}

/// 二步验证（OTP）应答：6 位动态验证码 + 是否信任本设备。
class FnTwofaAnswer {
  const FnTwofaAnswer({required this.code, this.trustDevice = false});

  final String code;
  final bool trustDevice;
}

class FnConnectDiscovery {
  const FnConnectDiscovery({
    required this.fnId,
    required this.lanIpv4,
    required this.publicIpv4,
    required this.publicIpv6,
    required this.httpPort,
    required this.httpsPort,
    required this.relayHosts,
  });

  final String fnId;
  final List<String> lanIpv4;
  final List<String> publicIpv4;
  final List<String> publicIpv6;
  final int httpPort;
  final int httpsPort;
  final List<String> relayHosts;

  factory FnConnectDiscovery.fallback(String rawFnId) {
    final host = FnosGateway.hostForFnId(rawFnId);
    return FnConnectDiscovery(
      fnId: FnosGateway.fnIdLabel(rawFnId),
      lanIpv4: const [],
      publicIpv4: const [],
      publicIpv6: const [],
      httpPort: 5666,
      httpsPort: 5667,
      relayHosts: [host],
    );
  }

  factory FnConnectDiscovery.fromJson(
    String fnId,
    Map<String, dynamic> json,
  ) {
    final port = asMap(json['port']);
    return FnConnectDiscovery(
      fnId: fnId,
      lanIpv4: readStringList(json['ipv4']),
      publicIpv4: readStringList(json['publicIpv4']),
      publicIpv6: readStringList(json['publicIpv6']),
      httpPort: readInt(port, 'httpPort') ?? 5666,
      httpsPort: readInt(port, 'httpsPort') ?? 5667,
      relayHosts: readStringList(json['fn'])
          .map(normalizeFnRelayHost)
          .where((host) => host.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class FnConnectSession {
  const FnConnectSession({
    required this.token,
    required this.relayHost,
    this.secret = '',
    this.longToken = '',
  });

  final String token;
  final String relayHost;
  final String secret;
  final String longToken;
}

class FnConnectCandidate {
  const FnConnectCandidate({
    required this.rootUrl,
    required this.description,
    required this.group,
    required this.isRelay,
    this.ipLabel,
    this.appPath = FnosGateway.defaultAppPath,
  });

  final String rootUrl;
  final String description;
  final FnConnectCandidateGroup group;
  final bool isRelay;
  final String? ipLabel;

  final String appPath;

  String get appBaseUrl => '$rootUrl$appPath';

  FnConnectCandidate withAppPath(String path) => FnConnectCandidate(
        rootUrl: rootUrl,
        description: description,
        group: group,
        isRelay: isRelay,
        ipLabel: ipLabel,
        appPath: path,
      );
}

/// 候选链路探测失败的归类，用于 UI 展示简短的中英文原因文案，
/// 不再透出底层异常（如 DioException）的长串英文报错。
enum FnConnectProbeErrorKind {
  /// 连接被拒绝（端口不通或服务未启动）
  refused,

  /// 连接超时（端口无响应）
  timeout,

  /// 网络不可达（目标主机不在当前网络）
  unreachable,

  /// 无法解析主机（DNS）
  dns,

  /// TLS 握手失败（证书或 HTTPS 端口异常）
  tls,

  /// 网关返回 invalid token（飞牛登录会话失效）
  invalidToken,

  /// 服务返回异常 HTTP 状态码
  httpStatus,

  /// 其他连接失败
  connectionFailed,
}

class FnConnectCandidateResult {
  const FnConnectCandidateResult({
    required this.candidate,
    required this.reachable,
    required this.latency,
    this.error,
    this.errorKind,
  });

  final FnConnectCandidate candidate;
  final bool reachable;
  final Duration latency;

  /// 原始错误描述（调试用；UI 展示请用 [localizedErrorText]）。
  final String? error;

  /// 失败原因归类；可达时为 null。
  final FnConnectProbeErrorKind? errorKind;
}

extension FnConnectCandidateResultErrorText on FnConnectCandidateResult {
  /// 探测失败原因的简短文案；[chinese] 为 true 返回中文，否则英文。
  String localizedErrorText({required bool chinese}) {
    String pick(String zh, String en) => chinese ? zh : en;
    return switch (errorKind) {
      null => pick('不可用', 'Unavailable'),
      FnConnectProbeErrorKind.refused => pick(
          '连接被拒绝（端口不通或服务未启动）',
          'Connection refused (port closed or service down)',
        ),
      FnConnectProbeErrorKind.timeout => pick(
          '连接超时（端口无响应）',
          'Timed out (no response from port)',
        ),
      FnConnectProbeErrorKind.unreachable => pick(
          '网络不可达（目标主机不在当前网络）',
          'Network unreachable',
        ),
      FnConnectProbeErrorKind.dns => pick(
          '无法解析主机（DNS）',
          'Host resolution failed (DNS)',
        ),
      FnConnectProbeErrorKind.tls => pick(
          'TLS 握手失败（证书或 HTTPS 端口异常）',
          'TLS handshake failed',
        ),
      FnConnectProbeErrorKind.invalidToken => pick(
          '飞牛登录已失效，请重新登录',
          'fnOS session expired, sign in again',
        ),
      FnConnectProbeErrorKind.httpStatus => pick(
          '服务返回错误（$error）',
          'Server error ($error)',
        ),
      FnConnectProbeErrorKind.connectionFailed =>
        pick('连接失败', 'Connection failed'),
    };
  }
}

class FnConnectLoginResult {
  const FnConnectLoginResult({
    required this.discovery,
    required this.session,
    required this.selected,
    required this.candidates,
  });

  final FnConnectDiscovery discovery;
  final FnConnectSession session;
  final FnConnectCandidate selected;
  final List<FnConnectCandidateResult> candidates;

  String get appBaseUrl => selected.appBaseUrl;
  String get cookie => fnCookieHeader(
        session.token,
        relay: selected.isRelay,
      );
}

String normalizeFnRelayHost(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
  return uri?.host.toLowerCase() ?? '';
}

String fnCookieHeader(String token, {required bool relay}) =>
    relay ? 'fnos-token=$token; mode=relay' : 'fnos-token=$token';
