import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/src/core/auth/fn_connect_client.dart';

class _Client extends FnConnectClient {
  int loginCount = 0;
  int probeCount = 0;
  int readyOnAttempt = 2;
  void Function()? afterProbe;

  @override
  Future<FnConnectDiscovery> discover(String rawFnId,
          {CancelToken? cancelToken}) async =>
      FnConnectDiscovery.fallback(rawFnId);

  @override
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
    loginCount++;
    return FnConnectSession(token: 'fresh', relayHost: relayHost);
  }

  @override
  Future<List<FnConnectCandidateResult>> probeCandidates({
    required List<FnConnectCandidate> candidates,
    required String token,
    bool ignoreSsl = true,
    String? accessCode,
    CancelToken? cancelToken,
  }) async {
    probeCount++;
    afterProbe?.call();
    return candidates.map((candidate) => FnConnectCandidateResult(
      candidate: candidate,
      reachable: probeCount >= readyOnAttempt,
      latency: Duration.zero,
      error: probeCount >= readyOnAttempt ? null : 'HTTP 302',
    )).toList();
  }
}

void main() {
  test('retries readiness with the same session after an initial 302', () async {
    final client = _Client();
    final result = await client.loginAndConnect(
      fnId: 'example', username: 'user', password: 'password',
    );
    expect(result.session.token, 'fresh');
    expect(client.loginCount, 1);
    expect(client.probeCount, 2);
    expect(result.candidates.any((item) =>
        item.reachable && item.candidate == result.selected), isTrue);
  });

  test('never selects an unreachable fallback when every probe fails', () async {
    final client = _Client()..readyOnAttempt = 10;
    await expectLater(client.loginAndConnect(
      fnId: 'example', username: 'user', password: 'password',
    ), throwsA(isA<FnConnectProtocolException>()));
    expect(client.loginCount, 1);
    expect(client.probeCount, 3);
  });

  test('cancellation prevents further readiness attempts', () async {
    final token = CancelToken();
    final client = _Client()..afterProbe = () => token.cancel();
    await expectLater(client.loginAndConnect(
      fnId: 'example', username: 'user', password: 'password',
      cancelToken: token,
    ), throwsA(isA<DioException>()));
    expect(client.probeCount, 1);
  });

  test('HTTP 200 gateway HTML is not a healthy application route', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var healthy = false;
    server.listen((request) async {
      request.response.headers.contentType =
          healthy ? ContentType.json : ContentType.html;
      request.response.write(
          healthy ? jsonEncode({'status': 'healthy'}) : '<html>Login</html>');
      await request.response.close();
    });
    final client = FnConnectClient();
    final candidates = [FnConnectCandidate(
      rootUrl: 'http://127.0.0.1:${server.port}',
      description: 'test',
      group: FnConnectCandidateGroup.lan,
      isRelay: false,
    )];
    expect((await client.probeCandidates(
      candidates: candidates, token: 'fresh',
    )).single.reachable, isFalse);
    healthy = true;
    expect((await client.probeCandidates(
      candidates: candidates, token: 'fresh',
    )).single.reachable, isTrue);
  });

  test('does not accept a 200 response from a different service', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'ok'}));
      await request.response.close();
    });
    final result = await FnConnectClient().probeCandidates(
      candidates: [
        FnConnectCandidate(
          rootUrl: 'http://127.0.0.1:${server.port}',
          description: 'test',
          group: FnConnectCandidateGroup.lan,
          isRelay: false,
        ),
      ],
      token: 'fresh',
    );
    expect(result.single.reachable, isFalse);
  });

  test('a degraded backend is still a reachable application route', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'unhealthy'}));
      await request.response.close();
    });
    final result = await FnConnectClient().probeCandidates(
      candidates: [
        FnConnectCandidate(
          rootUrl: 'http://127.0.0.1:${server.port}',
          description: 'test',
          group: FnConnectCandidateGroup.lan,
          isRelay: false,
        ),
      ],
      token: 'fresh',
    );
    expect(result.single.reachable, isTrue);
  });

  test('waits for complete credentials when trusting a new device', () {
    const reqId = '42';
    const messages = [
      {'result': 'succ', 'reqid': reqId, 'token': 'pending'},
      {'result': 'succ', 'reqid': reqId},
      {'result': 'succ', 'reqid': 'other', 'token': 'final', 'secret': 'key'},
    ];
    expect(
      messages.where(
        (message) => FnConnectClient.isTwofaLoginOutcome(message, reqId),
      ),
      [messages.last],
    );
    expect(
      FnConnectClient.isTwofaLoginOutcome(
        {'result': 'fail', 'reqid': reqId},
        reqId,
      ),
      isTrue,
    );
  });
}
