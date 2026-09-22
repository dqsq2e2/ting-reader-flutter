import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' show ValueChanged, visibleForTesting;
import 'package:pointycastle/export.dart' show RSAPublicKey;

import 'fn_access_code.dart';
import 'fn_connect_http_adapter.dart';
import 'fnos_gateway_auth.dart';
import 'fnos_ws_transport.dart';

enum FnConnectStage { resolving, signingIn, probing, tingReaderLogin }

enum FnConnectCandidateGroup { lan, publicIpv6, publicIpv4, relay }

const defaultFnConnectOrder = <FnConnectCandidateGroup>[
  FnConnectCandidateGroup.lan,
  FnConnectCandidateGroup.publicIpv6,
  FnConnectCandidateGroup.publicIpv4,
  FnConnectCandidateGroup.relay,
];

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

/// 飞牛账号已开启访问码保护，但调用方未提供访问码。
class FnConnectAccessCodeRequiredException extends FnConnectException {
  const FnConnectAccessCodeRequiredException()
      : super('服务器已开启访问码，请输入访问码');
}

/// 访问码校验失败（访问码错误）。
class FnConnectAccessCodeException extends FnConnectAuthenticationException {
  const FnConnectAccessCodeException() : super('访问码错误，请检查后重试');
}

/// 飞牛账号已开启二步验证，需要输入动态验证码（OTP）才能继续登录。
///
/// 仅在未提供 [FnConnectClient.login] 的 `onTwofaRequired` 回调时抛出；
/// 提供回调后 SDK 会自动完成 `user.2fa.loginVerify` 流程。
class FnConnectTwofaRequiredException extends FnConnectException {
  const FnConnectTwofaRequiredException()
      : super('飞牛账号已开启二步验证，请输入动态验证码');
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
    final port = _stringMap(json['port']);
    return FnConnectDiscovery(
      fnId: fnId,
      lanIpv4: _stringList(json['ipv4']),
      publicIpv4: _stringList(json['publicIpv4']),
      publicIpv6: _stringList(json['publicIpv6']),
      httpPort: _intValue(port['httpPort'], 5666),
      httpsPort: _intValue(port['httpsPort'], 5667),
      relayHosts: _stringList(json['fn'])
          .map(FnConnectClient.normalizeRelayHost)
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
  });

  final String rootUrl;
  final String description;
  final FnConnectCandidateGroup group;
  final bool isRelay;
  final String? ipLabel;

  String get appBaseUrl => '$rootUrl/app/ting-reader';
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
  String get cookie => FnConnectClient.cookieHeader(
        session.token,
        relay: selected.isRelay,
      );
}

class FnConnectClient {
  FnConnectClient({Dio? discoveryDio}) : _discoveryDio = discoveryDio ?? Dio();

  static const _discoveryPath = '/api/v1/fn/con';
  static const _authxPrefix = 'NDzZTVxnRKP8Z0jXg1VAMonaG8akvh';
  static const _authxSuffix = 'zIGtkc3dqZnJpd29qZXJqa2w7c';

  final Dio _discoveryDio;
  final Random _random = Random.secure();

  Future<FnConnectLoginResult> loginAndConnect({
    required String fnId,
    required String username,
    required String password,
    List<FnConnectCandidateGroup> order = defaultFnConnectOrder,
    Set<FnConnectCandidateGroup> disabledGroups = const {},
    bool ignoreSsl = true,
    String? accessCode,
    String? deviceId,
    Future<FnTwofaAnswer?> Function()? onTwofaRequired,
    ValueChanged<FnConnectStage>? onStage,
    CancelToken? cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    onStage?.call(FnConnectStage.resolving);
    final fallback = FnConnectDiscovery.fallback(fnId);
    FnConnectDiscovery discovery;
    try {
      discovery = await discover(fnId, cancelToken: cancelToken);
      if (discovery.relayHosts.isEmpty) {
        discovery = FnConnectDiscovery(
          fnId: discovery.fnId,
          lanIpv4: discovery.lanIpv4,
          publicIpv4: discovery.publicIpv4,
          publicIpv6: discovery.publicIpv6,
          httpPort: discovery.httpPort,
          httpsPort: discovery.httpsPort,
          relayHosts: fallback.relayHosts,
        );
      }
    } catch (_) {
      _throwIfCancelled(cancelToken);
      discovery = fallback;
    }

    onStage?.call(FnConnectStage.signingIn);
    final session = await login(
      relayHost: discovery.relayHosts.first,
      username: username,
      password: password,
      accessCode: accessCode,
      deviceId: deviceId,
      onTwofaRequired: onTwofaRequired,
      ignoreSsl: ignoreSsl,
      cancelToken: cancelToken,
    );

    onStage?.call(FnConnectStage.probing);
    final candidates = buildCandidates(
      discovery: discovery,
      order: order,
      disabledGroups: disabledGroups,
    );
    var results = <FnConnectCandidateResult>[];
    FnConnectCandidateResult? selectedResult;
    // A freshly issued session may not be accepted by the HTTP gateway yet.
    // Retry readiness, not credentials, and never use an unverified route.
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await _awaitCancellable(
          Future<void>.delayed(Duration(milliseconds: 500 * attempt)),
          cancelToken,
        );
      }
      results = await probeCandidates(
        candidates: candidates,
        token: session.token,
        ignoreSsl: ignoreSsl,
        accessCode: accessCode,
        cancelToken: cancelToken,
      );
      _throwIfCancelled(cancelToken);
      selectedResult = results.where((item) => item.reachable).firstOrNull;
      if (selectedResult != null) break;
    }
    if (selectedResult == null) {
      throw const FnConnectProtocolException(
        '飞牛会话已建立，但没有可用的应用链路。请检查远程访问、访问码和听书服务后重试',
      );
    }
    return FnConnectLoginResult(
      discovery: discovery,
      session: session,
      selected: selectedResult.candidate,
      candidates: results,
    );
  }

  Future<FnConnectDiscovery> discover(
    String rawFnId, {
    CancelToken? cancelToken,
  }) async {
    final fnId = FnosGateway.fnIdLabel(rawFnId);
    final body = jsonEncode({'fnId': fnId});
    final response = await _discoveryDio.post<dynamic>(
      'https://5ddd.com$_discoveryPath',
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'authx': buildAuthx(body),
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
      cancelToken: cancelToken,
    );
    final root = _stringMap(response.data);
    if (_intValue(root['code'], -1) != 0) {
      throw FnConnectException(
        root['msg']?.toString().trim().isNotEmpty == true
            ? root['msg'].toString()
            : 'Unable to resolve FNID',
      );
    }
    final data = _stringMap(root['data']);
    if (data.isEmpty) {
      throw const FnConnectException('Empty FNID response');
    }
    return FnConnectDiscovery.fromJson(fnId, data);
  }

  @visibleForTesting
  String buildAuthx(
    String body, {
    String? nonce,
    String? timestamp,
  }) {
    final effectiveNonce =
        nonce ?? (_random.nextInt(900000) + 100000).toString().padLeft(6, '0');
    final effectiveTimestamp =
        timestamp ?? DateTime.now().millisecondsSinceEpoch.toString();
    final raw = [
      _authxPrefix,
      _discoveryPath,
      effectiveNonce,
      effectiveTimestamp,
      crypto.md5.convert(utf8.encode(body)).toString(),
      _authxSuffix,
    ].join('_');
    final sign = crypto.md5.convert(utf8.encode(raw)).toString();
    return 'nonce=$effectiveNonce&timestamp=$effectiveTimestamp&sign=$sign';
  }

  Future<FnConnectSession> login({
    required String relayHost,
    required String username,
    required String password,
    String? accessCode,
    String? deviceId,
    Future<FnTwofaAnswer?> Function()? onTwofaRequired,
    bool ignoreSsl = true,
    CancelToken? cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    final host = normalizeRelayHost(relayHost);
    if (host.isEmpty) {
      throw const FnConnectProtocolException('Invalid fnOS relay host');
    }

    // 访问码预检（飞牛「访问码」是 FN Connect 远程入口的中间件统一校验）。
    // 未开启时直接放行；开启但未提供/提供错误访问码时给出明确错误，
    // 而不是让 WebSocket 握手被网关拦下后报一个看不懂的连接错误。
    final trimmedAccessCode = accessCode?.trim() ?? '';
    final accessCodeStatus = await FnAccessCode.probe(
      'https://$host',
      accessCode: trimmedAccessCode.isEmpty ? null : trimmedAccessCode,
      ignoreSsl: ignoreSsl,
      cancelToken: cancelToken,
    );
    _throwIfCancelled(cancelToken);
    final accessCodeHeaders = switch (accessCodeStatus) {
      FnAccessCodeStatus.required =>
        throw const FnConnectAccessCodeRequiredException(),
      FnAccessCodeStatus.rejected =>
        throw const FnConnectAccessCodeException(),
      FnAccessCodeStatus.accepted => FnAccessCode.headers(trimmedAccessCode),
      _ => const <String, String>{},
    };

    FnosWebSocketSession? socket;
    try {
      final socketFuture = connectFnosWebSocket(
        Uri.parse('wss://$host/websocket?type=main'),
        headers: {
          'Cookie': 'mode=relay',
          'Origin': 'https://$host',
          ...accessCodeHeaders,
        },
      );
      if (cancelToken != null) {
        unawaited(
          socketFuture.then<void>(
            (session) {
              if (cancelToken.isCancelled) unawaited(session.close());
            },
            onError: (Object _) {},
          ),
        );
      }
      final connectedSocket =
          await _awaitCancellable(socketFuture, cancelToken);
      socket = connectedSocket;
      final reqId = DateTime.now().microsecondsSinceEpoch.toString();
      final cryptoResponse = await _awaitCancellable(
        connectedSocket.request(
          {'reqid': reqId, 'req': 'util.crypto.getRSAPub'},
          matches: (response) => response['reqid']?.toString() == reqId,
        ),
        cancelToken,
        onCancel: connectedSocket.close,
      );
      final publicKeyPem = cryptoResponse['pub']?.toString() ?? '';
      final serverSalt = cryptoResponse['si']?.toString() ?? '';
      if (cryptoResponse['result']?.toString() != 'succ' ||
          publicKeyPem.isEmpty ||
          serverSalt.isEmpty) {
        throw const FnConnectProtocolException(
          'fnOS did not return its encryption key',
        );
      }

      final did = (deviceId != null && deviceId.trim().isNotEmpty)
          ? deviceId.trim()
          : generateDeviceId();
      final envelope = buildLoginEnvelope(
        publicKeyPem: publicKeyPem,
        serverSalt: serverSalt,
        reqId: reqId,
        username: username,
        password: password,
        deviceId: did,
      );
      final loginResponse = await _awaitCancellable(
        connectedSocket.request(
          envelope,
          matches: (response) => response['reqid']?.toString() == reqId,
        ),
        cancelToken,
        onCancel: connectedSocket.close,
      );
      if (loginResponse['result']?.toString() != 'succ') {
        throw const FnConnectAuthenticationException(
          '飞牛账号或密码错误',
        );
      }
      final token = loginResponse['token']?.toString().trim() ?? '';
      if (token.isNotEmpty) {
        return FnConnectSession(
          token: token,
          relayHost: host,
          secret: loginResponse['secret']?.toString() ?? '',
          longToken: loginResponse['longToken']?.toString() ?? '',
        );
      }

      // 账号密码正确但未直接下发会话：二步验证分支。
      // - isTwofaEnforced && !isBindTwofaSecret → 被强制要求 2FA 但未绑定，
      //   只能先去飞牛网页端完成绑定（无法通过 API 完成绑定流程）。
      // - isBindTwofaSecret && !isTrustedDevice && accessToken → OTP 挑战，
      //   通过 user.2fa.loginVerify 提交动态验证码完成登录。
      if (_isTwofaSetupChallenge(loginResponse)) {
        throw const FnConnectTwofaSetupRequiredException();
      }
      if (_isTwofaChallenge(loginResponse)) {
        return await _completeTwofaLogin(
          connectedSocket,
          relayHost: host,
          publicKeyPem: publicKeyPem,
          serverSalt: serverSalt,
          challenge: loginResponse,
          deviceId: did,
          onTwofaRequired: onTwofaRequired,
          cancelToken: cancelToken,
        );
      }
      throw const FnConnectProtocolException(
        'fnOS login response did not include a session token',
      );
    } on FnConnectException {
      rethrow;
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      throw FnConnectProtocolException('fnOS account login failed: $error');
    } finally {
      await socket?.close();
    }
  }

  /// 响应是否为「已绑定二步验证、当前设备未信任」的 OTP 挑战。
  static bool _isTwofaChallenge(Map<String, dynamic> response) {
    final token = response['token']?.toString().trim() ?? '';
    final secret = response['secret']?.toString().trim() ?? '';
    return response['result']?.toString() == 'succ' &&
        response['isBindTwofaSecret'] == true &&
        response['isTrustedDevice'] == false &&
        (response['accessToken']?.toString().isNotEmpty ?? false) &&
        token.isEmpty &&
        secret.isEmpty;
  }

  /// 响应是否为「被强制要求二步验证但尚未绑定 TOTP」。
  static bool _isTwofaSetupChallenge(Map<String, dynamic> response) {
    final token = response['token']?.toString().trim() ?? '';
    final secret = response['secret']?.toString().trim() ?? '';
    return response['result']?.toString() == 'succ' &&
        response['isTwofaEnforced'] == true &&
        response['isBindTwofaSecret'] == false &&
        (response['accessToken']?.toString().isNotEmpty ?? false) &&
        token.isEmpty &&
        secret.isEmpty;
  }

  /// 完成二步验证：向用户索取 OTP 后发送 `user.2fa.loginVerify`。
  Future<FnConnectSession> _completeTwofaLogin(
    FnosWebSocketSession socket, {
    required String relayHost,
    required String publicKeyPem,
    required String serverSalt,
    required Map<String, dynamic> challenge,
    required String deviceId,
    Future<FnTwofaAnswer?> Function()? onTwofaRequired,
    CancelToken? cancelToken,
  }) async {
    final provider = onTwofaRequired;
    if (provider == null) {
      throw const FnConnectTwofaRequiredException();
    }
    final answer = await provider();
    _throwIfCancelled(cancelToken);
    final code = answer?.code.trim() ?? '';
    if (answer == null || code.isEmpty) {
      throw const FnConnectTwofaCancelledException();
    }

    final reqId = DateTime.now().microsecondsSinceEpoch.toString();
    final envelope = buildTwofaLoginEnvelope(
      publicKeyPem: publicKeyPem,
      serverSalt: serverSalt,
      reqId: reqId,
      accessToken: challenge['accessToken']?.toString() ?? '',
      code: code,
      trustDevice: answer.trustDevice,
      deviceId: deviceId,
    );
    // 服务器对 loginVerify 的应答可能是两条消息，且顺序不定：
    // 1. reqid 匹配的直接响应（首次勾选「信任本设备」注册新设备时，
    //    这条可能是不带凭据的确认）；
    // 2. 「最终登录成功」推送（result=succ 且携带 token/secret，
    //    reqid 不一定匹配本请求）。
    // 只认 reqid 会把携带凭据的推送丢弃，拿到无效/缺失的 token，
    // 之后经统一网关的请求会被 302 打回——这正是首次勾选信任设备
    // 登录失败、不勾选或第二次勾选却正常的原因（pyfnos 同样按
    // 「任何带 token+secret 的 succ 消息」判定最终成功）。
    final response = await _awaitCancellable(
      socket.request(
        envelope,
        matches: (item) => isTwofaLoginOutcome(item, reqId),
      ),
      cancelToken,
      onCancel: socket.close,
    );
    if (response['result']?.toString() != 'succ') {
      throw const FnConnectTwofaInvalidException();
    }
    final token = response['token']?.toString().trim() ?? '';
    if (token.isEmpty) {
      throw const FnConnectProtocolException(
        'fnOS two-step verification did not return a session token',
      );
    }
    return FnConnectSession(
      token: token,
      relayHost: relayHost,
      secret: response['secret']?.toString() ?? '',
      longToken: response['longToken']?.toString() ?? '',
    );
  }

  /// `user.2fa.loginVerify` 的终局消息判定：失败以 reqid 匹配为准，
  /// 成功以「任何携带 token 的 succ 消息」为准（最终凭据可能是独立推送，
  /// reqid 与本请求不同，见 [_completeTwofaLogin] 注释）。
  @visibleForTesting
  static bool isTwofaLoginOutcome(Map<String, dynamic> item, String reqId) {
    final result = item['result']?.toString();
    if (item['reqid']?.toString() == reqId && result == 'fail') {
      return true;
    }
    final token = item['token']?.toString().trim() ?? '';
    return result == 'succ' && token.isNotEmpty;
  }

  @visibleForTesting
  Map<String, dynamic> buildLoginEnvelope({
    required String publicKeyPem,
    required String serverSalt,
    required String reqId,
    required String username,
    required String password,
    String deviceId = '',
    Uint8List? keySeed,
    Uint8List? ivBytes,
  }) {
    final seed = keySeed ?? _randomBytes(16);
    final keyHex =
        seed.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final keyBytes = Uint8List.fromList(utf8.encode(keyHex));
    final iv = ivBytes ?? _randomBytes(16);
    final payload = jsonEncode({
      'reqid': reqId,
      'user': username,
      'password': password,
      'deviceType': 'Browser',
      'deviceName': 'Ting Reader Flutter',
      if (deviceId.isNotEmpty) 'did': deviceId,
      'stay': true,
      'req': 'user.login',
      'si': serverSalt,
    });

    final aes = Encrypter(AES(Key(keyBytes), mode: AESMode.cbc));
    final encryptedPayload = aes.encryptBytes(
      utf8.encode(payload),
      iv: IV(iv),
    );
    final parsedKey = RSAKeyParser().parse(publicKeyPem);
    if (parsedKey is! RSAPublicKey) {
      throw const FormatException('fnOS returned a non-public RSA key');
    }
    final rsa = Encrypter(
      RSA(publicKey: parsedKey, encoding: RSAEncoding.PKCS1),
    );
    final encryptedKey = rsa.encryptBytes(keyBytes);
    return {
      'req': 'encrypted',
      'iv': base64Encode(iv),
      'rsa': encryptedKey.base64,
      'aes': encryptedPayload.base64,
    };
  }

  /// 构造 `user.2fa.loginVerify` 加密信封（字段与飞牛网页版一致）。
  ///
  /// 与 [buildLoginEnvelope] 一样使用全新 AES 密钥/IV 的信封加密；
  /// `stay` 在该请求中为 int（0/1），[accessToken] 来自 `user.login`
  /// 返回的二步验证挑战。
  @visibleForTesting
  Map<String, dynamic> buildTwofaLoginEnvelope({
    required String publicKeyPem,
    required String serverSalt,
    required String reqId,
    required String accessToken,
    required String code,
    bool trustDevice = false,
    String deviceId = '',
    Uint8List? keySeed,
    Uint8List? ivBytes,
  }) {
    final seed = keySeed ?? _randomBytes(16);
    final keyHex =
        seed.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final keyBytes = Uint8List.fromList(utf8.encode(keyHex));
    final iv = ivBytes ?? _randomBytes(16);
    final payload = jsonEncode({
      'reqid': reqId,
      'code': code,
      'isTrustedDevice': trustDevice,
      'accessToken': accessToken,
      'stay': 1,
      'deviceType': 'Browser',
      'deviceName': 'Ting Reader Flutter',
      if (deviceId.isNotEmpty) 'did': deviceId,
      'req': 'user.2fa.loginVerify',
      'si': serverSalt,
    });

    final aes = Encrypter(AES(Key(keyBytes), mode: AESMode.cbc));
    final encryptedPayload = aes.encryptBytes(
      utf8.encode(payload),
      iv: IV(iv),
    );
    final parsedKey = RSAKeyParser().parse(publicKeyPem);
    if (parsedKey is! RSAPublicKey) {
      throw const FormatException('fnOS returned a non-public RSA key');
    }
    final rsa = Encrypter(
      RSA(publicKey: parsedKey, encoding: RSAEncoding.PKCS1),
    );
    final encryptedKey = rsa.encryptBytes(keyBytes);
    return {
      'req': 'encrypted',
      'iv': base64Encode(iv),
      'rsa': encryptedKey.base64,
      'aes': encryptedPayload.base64,
    };
  }

  /// 生成飞牛设备 ID（`did`），格式与官方前端一致：
  /// `base32(毫秒时间戳)-base32(随机)[:15]-base32(随机)[:15]`，小写且无填充。
  ///
  /// 二步验证勾选「信任本设备」后，服务器按 did 记住受信设备，
  /// 因此客户端应持久化该值并在后续登录复用（见 AppState 的安全存储）。
  String generateDeviceId() {
    String encodePart(String value, [int? maxLength]) {
      final encoded = _base32Encode(utf8.encode(value))
          .toLowerCase()
          .replaceAll('=', '');
      if (maxLength != null && encoded.length > maxLength) {
        return encoded.substring(0, maxLength);
      }
      return encoded;
    }

    final time = encodePart('${DateTime.now().millisecondsSinceEpoch}');
    final randA = encodePart('${_random.nextDouble()}', 15);
    final randB = encodePart('${_random.nextDouble()}', 15);
    return '$time-$randA-$randB';
  }

  /// RFC 4648 base32（无填充），仅用于 [generateDeviceId]。
  static String _base32Encode(List<int> bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final buffer = StringBuffer();
    var bitBuffer = 0;
    var bitCount = 0;
    for (final byte in bytes) {
      bitBuffer = (bitBuffer << 8) | byte;
      bitCount += 8;
      while (bitCount >= 5) {
        final index = (bitBuffer >> (bitCount - 5)) & 0x1f;
        buffer.write(alphabet[index]);
        bitCount -= 5;
      }
    }
    if (bitCount > 0) {
      final index = (bitBuffer << (5 - bitCount)) & 0x1f;
      buffer.write(alphabet[index]);
    }
    return buffer.toString();
  }

  List<FnConnectCandidate> buildCandidates({
    required FnConnectDiscovery discovery,
    List<FnConnectCandidateGroup> order = defaultFnConnectOrder,
    Set<FnConnectCandidateGroup> disabledGroups = const {},
  }) {
    final candidates = <FnConnectCandidate>[];
    for (final group in order) {
      if (disabledGroups.contains(group)) continue;
      switch (group) {
        case FnConnectCandidateGroup.lan:
          for (final ip in discovery.lanIpv4) {
            _addIpCandidates(candidates, ip, group, discovery);
          }
        case FnConnectCandidateGroup.publicIpv6:
          for (final ip in discovery.publicIpv6) {
            _addIpCandidates(candidates, ip, group, discovery, ipv6: true);
          }
        case FnConnectCandidateGroup.publicIpv4:
          for (final ip in discovery.publicIpv4) {
            _addIpCandidates(candidates, ip, group, discovery);
          }
        case FnConnectCandidateGroup.relay:
          for (final host in discovery.relayHosts) {
            candidates.add(
              FnConnectCandidate(
                rootUrl: 'https://$host',
                description: 'HTTPS ($host)',
                group: group,
                isRelay: true,
              ),
            );
          }
      }
    }
    return candidates;
  }

  Future<List<FnConnectCandidateResult>> probeCandidates({
    required List<FnConnectCandidate> candidates,
    required String token,
    bool ignoreSsl = true,
    String? accessCode,
    CancelToken? cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    final dio = Dio(
      BaseOptions(
        followRedirects: false,
        validateStatus: (_) => true,
      ),
    );
    configureFnConnectHttpAdapter(dio, ignoreSsl: ignoreSsl);
    final accessCodeHeaders = FnAccessCode.headers(accessCode);
    final results = await Future.wait(
      candidates.map((candidate) async {
        final started = DateTime.now();
        final timeout = candidate.isRelay
            ? const Duration(seconds: 10)
            : const Duration(seconds: 3);
        try {
          final response = await dio.get<dynamic>(
            '${candidate.appBaseUrl}/api/health',
            cancelToken: cancelToken,
            options: Options(
              connectTimeout: timeout,
              receiveTimeout: timeout,
              sendTimeout: timeout,
              headers: {
                'Cookie': cookieHeader(token, relay: candidate.isRelay),
                ...accessCodeHeaders,
              },
            ),
          );
          final status = response.statusCode ?? 0;
          final invalidToken = _isInvalidToken(response.data);
          final reachable = status >= 200 &&
              status < 300 &&
              !invalidToken &&
              response.data is Map &&
              response.data['status'] == 'ok';
          return FnConnectCandidateResult(
            candidate: candidate,
            reachable: reachable,
            latency: DateTime.now().difference(started),
            error: reachable
                ? null
                : invalidToken
                    ? 'invalid token'
                    : 'HTTP $status',
            errorKind: reachable
                ? null
                : invalidToken
                    ? FnConnectProbeErrorKind.invalidToken
                    : FnConnectProbeErrorKind.httpStatus,
          );
        } catch (error) {
          if (error is DioException &&
              CancelToken.isCancel(error) &&
              (cancelToken?.isCancelled ?? false)) {
            rethrow;
          }
          return FnConnectCandidateResult(
            candidate: candidate,
            reachable: false,
            latency: DateTime.now().difference(started),
            error: error is DioException
                ? (error.message ?? error.type.name)
                : error.toString(),
            errorKind: _classifyProbeError(error),
          );
        }
      }),
    );
    _throwIfCancelled(cancelToken);
    return results;
  }

  static String cookieHeader(String token, {required bool relay}) {
    return relay ? 'fnos-token=$token; mode=relay' : 'fnos-token=$token';
  }

  static String? tokenFromCookie(String? cookie) {
    for (final part in (cookie ?? '').split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      if (part.substring(0, separator).trim().toLowerCase() == 'fnos-token') {
        final value = part.substring(separator + 1).trim();
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  static String normalizeRelayHost(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
    return uri?.host.toLowerCase() ?? '';
  }

  void _addIpCandidates(
    List<FnConnectCandidate> target,
    String rawIp,
    FnConnectCandidateGroup group,
    FnConnectDiscovery discovery, {
    bool ipv6 = false,
  }) {
    final ip = rawIp.trim();
    if (ip.isEmpty) return;
    final host = ipv6 ? '[$ip]' : ip;
    target
      ..add(
        FnConnectCandidate(
          rootUrl: 'http://$host:${discovery.httpPort}',
          description: 'HTTP ($ip:${discovery.httpPort})',
          group: group,
          isRelay: false,
          ipLabel: ip,
        ),
      )
      ..add(
        FnConnectCandidate(
          rootUrl: 'https://$host:${discovery.httpsPort}',
          description: 'HTTPS ($ip:${discovery.httpsPort})',
          group: group,
          isRelay: false,
          ipLabel: ip,
        ),
      );
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }

  static bool _isInvalidToken(Object? data) {
    final text = switch (data) {
      List<int> value => utf8.decode(value, allowMalformed: true),
      _ => data?.toString() ?? '',
    };
    return text.trim().toLowerCase() == 'invalid token';
  }

  Future<T> _awaitCancellable<T>(
    Future<T> future,
    CancelToken? cancelToken, {
    Future<void> Function()? onCancel,
  }) async {
    if (cancelToken == null) return future;
    if (cancelToken.isCancelled) {
      try {
        await onCancel?.call();
      } catch (_) {}
      throw cancelToken.cancelError ??
          DioException.requestCancelled(
            requestOptions: RequestOptions(),
            reason: 'Login cancelled',
          );
    }

    final cancellation = cancelToken.whenCancel.then<T>((error) async {
      try {
        await onCancel?.call();
      } catch (_) {}
      throw error;
    });
    return Future.any<T>([future, cancellation]);
  }

  void _throwIfCancelled(CancelToken? cancelToken) {
    if (cancelToken?.isCancelled ?? false) {
      throw cancelToken!.cancelError ??
          DioException.requestCancelled(
            requestOptions: RequestOptions(),
            reason: 'Login cancelled',
          );
    }
  }
}

/// 将探测抛出的底层异常归类为 [FnConnectProbeErrorKind]。
/// 关键词匹配参考 FeiNiuMusic 的错误识别（SocketException 文本含
/// "Connection refused" / errno 等），超时类先用 DioException.type 判定。
FnConnectProbeErrorKind _classifyProbeError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return FnConnectProbeErrorKind.timeout;
      case DioExceptionType.badCertificate:
        return FnConnectProbeErrorKind.tls;
      default:
        break;
    }
  }
  final lower = error.toString().toLowerCase();
  if (lower.contains('connection refused') ||
      lower.contains('econnrefused') ||
      lower.contains('10061')) {
    return FnConnectProbeErrorKind.refused;
  }
  if (lower.contains('timed out') || lower.contains('timeout')) {
    return FnConnectProbeErrorKind.timeout;
  }
  if (lower.contains('network is unreachable') ||
      lower.contains('network unreachable') ||
      lower.contains('ehostunreach') ||
      lower.contains('enetunreach')) {
    return FnConnectProbeErrorKind.unreachable;
  }
  if (lower.contains('host not found') ||
      lower.contains('cannot resolve') ||
      lower.contains('failed to resolve') ||
      lower.contains('name or service not known')) {
    return FnConnectProbeErrorKind.dns;
  }
  if (lower.contains('handshake') || lower.contains('certificate')) {
    return FnConnectProbeErrorKind.tls;
  }
  return FnConnectProbeErrorKind.connectionFailed;
}

Map<String, dynamic> _stringMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

int _intValue(Object? value, int fallback) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
