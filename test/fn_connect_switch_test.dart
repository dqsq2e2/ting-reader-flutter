import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/src/core/auth/fn_connect_client.dart';
import 'package:ting_reader_flutter/src/core/auth/fnos_gateway_auth.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';

void main() {
  for (final appPath in FnosGateway.appPaths) {
    test('switching a candidate keeps the verified application route: $appPath',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      server.listen((request) async {
        requests++;
        if (request.uri.path != '$appPath/api/health') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
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

        expect(requests, FnosGateway.appPaths.indexOf(appPath) + 1);
        final expectedUrl = '${candidate.rootUrl}$appPath';
        expect(state.activeUrl, expectedUrl);
        expect(state.api.baseUrl, expectedUrl);
        expect(state.savedGatewayProfile?.activeUrl, expectedUrl);
      } finally {
        state.dispose();
        await server.close(force: true);
      }
    });
  }
}
