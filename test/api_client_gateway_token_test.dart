import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';

void main() {
  for (final useCancelToken in [false, true]) {
    test('replays multipart uploads after gateway renewal ($useCancelToken)',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bodies = <String>[];
      final contentTypes = <String?>[];
      final cookies = <String?>[];
      server.listen((request) async {
        contentTypes.add(request.headers.value(HttpHeaders.contentTypeHeader));
        cookies.add(request.headers.value(HttpHeaders.cookieHeader));
        bodies.add(latin1.decode(await request.fold<List<int>>(
          [],
          (buffer, bytes) => buffer..addAll(bytes),
        )));
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType =
              bodies.length == 1 ? ContentType.text : ContentType.json
          ..write(bodies.length == 1
              ? 'invalid token'
              : jsonEncode({'saved': true}));
        await request.response.close();
      });
      final client = ApiClient()
        ..configure(
          baseUrl: 'http://${server.address.address}:${server.port}',
          token: 'fixture-token',
          cookie: 'fnos-token=stale',
        );
      client.isGatewaySession = () => true;
      client.onGatewaySessionExpired = () async {
        client.configure(
            baseUrl: client.baseUrl,
            token: 'fixture-token',
            cookie: 'fnos-token=fresh');
        return true;
      };
      try {
        final response = await client.post(
          '/api/books/book/cover',
          data: FormData.fromMap({
            'file':
                MultipartFile.fromBytes([0, 1, 2, 3], filename: 'cover.png'),
            'metadata': jsonEncode({'title': 'Cover fixture'}),
          }),
          cancelToken: useCancelToken ? CancelToken() : null,
        );
        expect(response.data, {'saved': true});
        expect(bodies, hasLength(2));
        expect(cookies, ['fnos-token=stale', 'fnos-token=fresh']);
        for (var index = 0; index < bodies.length; index++) {
          expect(contentTypes[index],
              startsWith('multipart/form-data; boundary='));
          expect(bodies[index], contains('filename="cover.png"'));
          expect(bodies[index], contains('\x00\x01\x02\x03'));
          expect(bodies[index], contains('"title":"Cover fixture"'));
        }
      } finally {
        await server.close(force: true);
      }
    });
  }

  group('ApiClient server URL handling', () {
    test('normalizes bracketed IPv6 servers without losing the port', () {
      expect(
        ApiClient.normalizeServerUrl(' http://[2001:db8::216]:3000/ '),
        'http://[2001:db8::216]:3000',
      );
      expect(
        ApiClient.normalizeServerUrl('[2001:db8::216]:3000'),
        'http://[2001:db8::216]:3000',
      );
    });

    test('keeps IPv6 brackets when extracting a redirected origin', () {
      final redirected = Uri.parse(
        'http://[2001:db8::216]:3000/api/health?probe=true',
      );

      expect(
        ApiClient.originFromUri(redirected),
        'http://[2001:db8::216]:3000',
      );
    });
  });

  group('ApiClient.isInvalidGatewayTokenPayload', () {
    test('recognizes explicit fnOS token failures', () {
      expect(ApiClient.isInvalidGatewayTokenPayload('invalid token'), isTrue);
      expect(
        ApiClient.isInvalidGatewayTokenPayload(utf8.encode('token is invalid')),
        isTrue,
      );
      expect(
        ApiClient.isInvalidGatewayTokenPayload({
          'type': 'error',
          'message': 'invalid token',
        }),
        isTrue,
      );
    });

    test('does not confuse normal progress sync failures with token expiry',
        () {
      expect(
        ApiClient.isInvalidGatewayTokenPayload('connection timed out'),
        isFalse,
      );
      expect(
        ApiClient.isInvalidGatewayTokenPayload({
          'type': 'error',
          'message': 'progress save failed',
        }),
        isFalse,
      );
      expect(
        ApiClient.isInvalidGatewayTokenPayload('invalid token format'),
        isFalse,
      );
    });
  });

  test('silently renews a gateway session and replays the request once',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final cookies = <String?>[];
    var requests = 0;
    server.listen((request) async {
      requests++;
      cookies.add(request.headers.value(HttpHeaders.cookieHeader));
      if (requests == 1) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..write('invalid token');
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'healthy'}));
      }
      await request.response.close();
    });

    final client = ApiClient();
    client.configure(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'tr-token',
      cookie: 'fnos-token=stale; mode=relay',
    );
    client.isGatewaySession = () => true;
    client.onGatewaySessionExpired = () async {
      client.configure(
        baseUrl: client.baseUrl,
        token: 'new-tr-token',
        cookie: 'fnos-token=fresh; mode=relay',
      );
      return true;
    };

    try {
      final response = await client.get('/api/health');
      expect(response.data, {'status': 'healthy'});
      expect(requests, 2);
      expect(cookies, [
        'fnos-token=stale; mode=relay',
        'fnos-token=fresh; mode=relay',
      ]);
    } finally {
      await server.close(force: true);
    }
  });

  test('treats a gateway login redirect as an expired session', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      requests++;
      if (requests == 1) {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, '/login');
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'id': 'user'}));
      }
      await request.response.close();
    });

    final client = ApiClient();
    client.configure(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'tr-token',
      cookie: 'fnos-token=stale; mode=relay',
    );
    client.isGatewaySession = () => true;
    var renewals = 0;
    client.onGatewaySessionExpired = () async {
      renewals++;
      client.configure(
        baseUrl: client.baseUrl,
        token: 'new-tr-token',
        cookie: 'fnos-token=fresh; mode=relay',
      );
      return true;
    };

    try {
      final response = await client.get('/api/me');
      expect(response.data, {'id': 'user'});
      expect(requests, 2);
      expect(renewals, 1);
    } finally {
      await server.close(force: true);
    }
  });

  test('treats a gateway HTML login page as an expired session', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      requests++;
      if (requests == 1) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('<!doctype html><title>fnOS login</title>');
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'id': 'user'}));
      }
      await request.response.close();
    });

    final client = ApiClient();
    client.configure(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'tr-token',
      cookie: 'fnos-token=stale; mode=relay',
    );
    client.isGatewaySession = () => true;
    var renewals = 0;
    client.onGatewaySessionExpired = () async {
      renewals++;
      client.configure(
        baseUrl: client.baseUrl,
        token: 'new-tr-token',
        cookie: 'fnos-token=fresh; mode=relay',
      );
      return true;
    };

    try {
      final response = await client.get('/api/me');
      expect(response.data, {'id': 'user'});
      expect(requests, 2);
      expect(renewals, 1);
    } finally {
      await server.close(force: true);
    }
  });

  test('auth revision changes only when media credentials change', () {
    final client = ApiClient();
    final initialRevision = client.authRevision;

    client.configure(
      baseUrl: 'https://example.com',
      token: 'token',
      cookie: 'fnos-token=one',
    );
    final configuredRevision = client.authRevision;
    expect(configuredRevision, greaterThan(initialRevision));

    client.configure(
      baseUrl: 'https://example.com',
      token: 'token',
      cookie: 'fnos-token=one',
    );
    expect(client.authRevision, configuredRevision);

    client.configure(
      baseUrl: 'https://example.com',
      token: 'token',
      cookie: 'fnos-token=two',
    );
    expect(client.authRevision, greaterThan(configuredRevision));
  });

  test('replays a stale in-flight request without renewing twice', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final firstRequestReceived = Completer<void>();
    final releaseFirstResponse = Completer<void>();
    var requests = 0;
    server.listen((request) async {
      requests++;
      if (requests == 1) {
        firstRequestReceived.complete();
        await releaseFirstResponse.future;
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, '/login');
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'id': 'user'}));
      }
      await request.response.close();
    });

    final client = ApiClient();
    client.configure(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'old-token',
      cookie: 'fnos-token=old',
    );
    client.isGatewaySession = () => true;
    var renewals = 0;
    client.onGatewaySessionExpired = () async {
      renewals++;
      return true;
    };

    try {
      final responseFuture = client.get('/api/me');
      await firstRequestReceived.future;
      client.configure(
        baseUrl: client.baseUrl,
        token: 'new-token',
        cookie: 'fnos-token=new',
      );
      releaseFirstResponse.complete();

      final response = await responseFuture;
      expect(response.data, {'id': 'user'});
      expect(requests, 2);
      expect(renewals, 0);
    } finally {
      await server.close(force: true);
    }
  });

  test('does not renew a normal forbidden API response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'detail': 'Admin access required'}));
      await request.response.close();
    });

    final client = ApiClient();
    client.configure(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 'token',
      cookie: 'fnos-token=valid',
    );
    client.isGatewaySession = () => true;
    var renewals = 0;
    client.onGatewaySessionExpired = () async {
      renewals++;
      return true;
    };

    try {
      await expectLater(
        client.get('/api/admin'),
        throwsA(isA<DioException>()),
      );
      expect(renewals, 0);
    } finally {
      await server.close(force: true);
    }
  });
}
