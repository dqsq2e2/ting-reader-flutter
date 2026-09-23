import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/src/core/auth/fn_connect_client.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';

void main() {
  test('switching a candidate verifies the Ting Reader health endpoint',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      requests++;
      expect(request.uri.path, '/app/ting-reader/api/health');
      expect(
        request.headers.value(HttpHeaders.cookieHeader),
        'fnos-token=session-token',
      );
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'status': 'healthy'}));
      await request.response.close();
    });

    final state = AppState()
      ..fnId = 'test-fnid'
      ..gatewayCookie = 'fnos-token=session-token'
      ..savedServers = const [
        SavedServerProfile(
          serverUrl: 'https://test-fnid.fnos.net',
          activeUrl: 'https://test-fnid.fnos.net/app/ting-reader',
          username: 'reader',
          password: '',
          label: 'reader',
          mode: ServerProfileMode.fnosGateway,
          fnId: 'test-fnid',
          gatewayCookie: 'fnos-token=session-token',
        ),
      ];
    final candidate = FnConnectCandidate(
      rootUrl: 'http://${server.address.address}:${server.port}',
      description: 'HTTP (${server.address.address}:${server.port})',
      group: FnConnectCandidateGroup.lan,
      isRelay: false,
    );

    try {
      await state.switchFnConnectCandidate(candidate);

      expect(requests, 1);
      expect(state.activeUrl, candidate.appBaseUrl);
      expect(state.api.baseUrl, candidate.appBaseUrl);
    } finally {
      await server.close(force: true);
    }
  });
}
