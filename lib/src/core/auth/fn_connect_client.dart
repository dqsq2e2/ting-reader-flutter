import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' show ValueChanged, visibleForTesting;
import 'package:pointycastle/export.dart' show RSAPublicKey;

import 'fn_connect_http_adapter.dart';
import 'fnos_gateway_auth.dart';
import 'fnos_ws_transport.dart';

enum FnConnectStage {
  resolving,
  signingIn,
  probing,
  tingReaderLogin,
  webFallback
}

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

class FnConnectCandidateResult {
  const FnConnectCandidateResult({
    required this.candidate,
    required this.reachable,
    required this.latency,
    this.error,
  });

  final FnConnectCandidate candidate;
  final bool reachable;
  final Duration latency;
  final String? error;
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
    ValueChanged<FnConnectStage>? onStage,
  }) async {
    onStage?.call(FnConnectStage.resolving);
    final fallback = FnConnectDiscovery.fallback(fnId);
    FnConnectDiscovery discovery;
    try {
      discovery = await discover(fnId);
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
      discovery = fallback;
    }

    onStage?.call(FnConnectStage.signingIn);
    final session = await login(
      relayHost: discovery.relayHosts.first,
      username: username,
      password: password,
    );

    onStage?.call(FnConnectStage.probing);
    final candidates = buildCandidates(
      discovery: discovery,
      order: order,
      disabledGroups: disabledGroups,
    );
    final results = await probeCandidates(
      candidates: candidates,
      token: session.token,
      ignoreSsl: ignoreSsl,
    );
    final selectedResult = results.where((item) => item.reachable).firstOrNull;
    final relayFallback = candidates.where((item) => item.isRelay).firstOrNull;
    final selected = selectedResult?.candidate ??
        relayFallback ??
        FnConnectCandidate(
          rootUrl: 'https://${session.relayHost}',
          description: 'HTTPS (${session.relayHost})',
          group: FnConnectCandidateGroup.relay,
          isRelay: true,
        );
    return FnConnectLoginResult(
      discovery: discovery,
      session: session,
      selected: selected,
      candidates: results,
    );
  }

  Future<FnConnectDiscovery> discover(String rawFnId) async {
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
  }) async {
    final host = normalizeRelayHost(relayHost);
    if (host.isEmpty) {
      throw const FnConnectProtocolException('Invalid fnOS relay host');
    }

    FnosWebSocketSession? socket;
    try {
      socket = await connectFnosWebSocket(
        Uri.parse('wss://$host/websocket?type=main'),
        headers: {
          'Cookie': 'mode=relay',
          'Origin': 'https://$host',
        },
      );
      final reqId = DateTime.now().microsecondsSinceEpoch.toString();
      final cryptoResponse = await socket.request(
        {'reqid': reqId, 'req': 'util.crypto.getRSAPub'},
        matches: (response) => response['reqid']?.toString() == reqId,
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

      final envelope = buildLoginEnvelope(
        publicKeyPem: publicKeyPem,
        serverSalt: serverSalt,
        reqId: reqId,
        username: username,
        password: password,
      );
      final loginResponse = await socket.request(
        envelope,
        matches: (response) => response['reqid']?.toString() == reqId,
      );
      if (loginResponse['result']?.toString() != 'succ') {
        throw const FnConnectAuthenticationException(
          '飞牛账号或密码错误',
        );
      }
      final token = loginResponse['token']?.toString().trim() ?? '';
      if (token.isEmpty) {
        throw const FnConnectProtocolException(
          'fnOS login response did not include a session token',
        );
      }
      return FnConnectSession(
        token: token,
        relayHost: host,
        secret: loginResponse['secret']?.toString() ?? '',
        longToken: loginResponse['longToken']?.toString() ?? '',
      );
    } on FnConnectException {
      rethrow;
    } catch (error) {
      throw FnConnectProtocolException('fnOS account login failed: $error');
    } finally {
      await socket?.close();
    }
  }

  @visibleForTesting
  Map<String, dynamic> buildLoginEnvelope({
    required String publicKeyPem,
    required String serverSalt,
    required String reqId,
    required String username,
    required String password,
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
  }) async {
    final dio = Dio(
      BaseOptions(
        followRedirects: false,
        validateStatus: (_) => true,
      ),
    );
    configureFnConnectHttpAdapter(dio, ignoreSsl: ignoreSsl);
    return Future.wait(
      candidates.map((candidate) async {
        final started = DateTime.now();
        final timeout = candidate.isRelay
            ? const Duration(seconds: 10)
            : const Duration(seconds: 3);
        try {
          final response = await dio.get<dynamic>(
            '${candidate.appBaseUrl}/api/health',
            options: Options(
              connectTimeout: timeout,
              receiveTimeout: timeout,
              sendTimeout: timeout,
              headers: {
                'Cookie': cookieHeader(token, relay: candidate.isRelay)
              },
            ),
          );
          final status = response.statusCode ?? 0;
          final invalidToken = _isInvalidToken(response.data);
          final reachable = status >= 200 && status < 300 && !invalidToken;
          return FnConnectCandidateResult(
            candidate: candidate,
            reachable: reachable,
            latency: DateTime.now().difference(started),
            error: reachable
                ? null
                : invalidToken
                    ? 'invalid token'
                    : 'HTTP $status',
          );
        } catch (error) {
          return FnConnectCandidateResult(
            candidate: candidate,
            reachable: false,
            latency: DateTime.now().difference(started),
            error: error is DioException
                ? (error.message ?? error.type.name)
                : error.toString(),
          );
        }
      }),
    );
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
