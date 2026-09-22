import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ting_reader_flutter/src/core/auth/fn_connect_client.dart';
import 'package:ting_reader_flutter/src/core/models/models.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';

class _FnConnectClient extends FnConnectClient {
  _FnConnectClient(this.rootUrl);

  final String rootUrl;
  int attempts = 0;
  Object? failure;
  Completer<void>? loginStarted;
  Completer<void>? allowLogin;
  CancelToken? loginCancelToken;
  VoidCallback? beforeLogin;

  @override
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
    attempts++;
    beforeLogin?.call();
    loginCancelToken = cancelToken;
    loginStarted?.complete();
    await allowLogin?.future;
    if (cancelToken?.isCancelled ?? false) throw cancelToken!.cancelError!;
    if (failure != null) throw failure!;
    return FnConnectLoginResult(
      discovery: FnConnectDiscovery.fallback(fnId),
      session: const FnConnectSession(
        token: 'fresh-cookie',
        relayHost: 'example.fnos.net',
      ),
      selected: FnConnectCandidate(
        rootUrl: rootUrl,
        description: 'test',
        group: FnConnectCandidateGroup.lan,
        isRelay: false,
      ),
      candidates: const [],
    );
  }
}

class _StartupAppState extends AppState {
  _StartupAppState(_FnConnectClient client) : super(fnConnect: client) {
    // Keep platform-specific device header encoding out of startup tests.
    client.beforeLogin = () => api.setClientHeaders(const {});
  }

  @override
  Future<bool> reprobeFnConnect() async {
    api.setClientHeaders(const {});
    return true;
  }

  @override
  Future<String?> recoverActiveUrl({CancelToken? cancelToken}) async => null;
}

void _seedStartup(
  _FnConnectClient client, {
  bool hasToken = true,
  bool hasSession = true,
}) {
  final existing = _authenticatedState(client);
  final profile = existing.savedServers.single;
  SharedPreferences.setMockInitialValues({
    'server_url': profile.serverUrl,
    'active_url': '${client.rootUrl}/app/ting-reader',
    'server_mode': 'fnosGateway',
    'fn_id': profile.fnId,
    if (hasSession) 'gateway_cookie': 'fnos-token=stale; mode=relay',
    if (hasSession && !hasToken) 'gateway_relogin_required': true,
    if (hasSession && hasToken) 'auth_token': existing.token!,
    if (hasSession && hasToken) 'user': existing.user!.encode(),
    'saved_servers': jsonEncode([profile.toJson(includeSecrets: true)]),
  });
  existing.dispose();
}

AppState _authenticatedState(_FnConnectClient client) {
  return AppState(fnConnect: client)
    ..serverMode = ServerProfileMode.fnosGateway
    ..fnId = 'example.fnos.net'
    ..token = 'old-token'
    ..user = const User(id: '1', username: 'reader', role: 'user')
    ..savedServers = const [
      SavedServerProfile(
        serverUrl: 'https://example.fnos.net',
        activeUrl: 'https://example.fnos.net/app/ting-reader',
        username: 'reader',
        password: 'password',
        label: 'reader',
        mode: ServerProfileMode.fnosGateway,
        fnId: 'example.fnos.net',
        fnosUsername: 'fn-user',
        fnosPassword: 'fn-password',
      ),
    ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);
  });

  test('renewal preserves UI authentication during login and shares recovery',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = Completer<HttpRequest>();
    server.listen(received.complete);
    final client = _FnConnectClient('http://127.0.0.1:${server.port}');
    final state = _authenticatedState(client);
    addTearDown(state.dispose);
    final observed = <bool>[];
    state.addListener(() => observed.add(state.isAuthenticated));
    var restored = 0;
    state.onGatewayLoginRestored = () async {
      restored++;
    };

    final first = state.handleGatewaySessionExpired();
    final request = await received.future.timeout(const Duration(seconds: 5));
    final second = state.handleGatewaySessionExpired();
    expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
    expect(state.gatewaySessionRecoveryInFlight, isNotNull);
    expect(state.isAuthenticated, isTrue);
    // Other state changes can rebuild StartupGate while login is pending.
    state.notifyPluginExtensionsChanged();
    expect(observed, everyElement(isTrue));
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'token': 'new-token',
      'user': {'id': '1', 'username': 'reader', 'role': 'user'},
    }));
    await request.response.close();
    await Future.wait([first, second]);

    expect(client.attempts, 1);
    expect(restored, 1);
    expect(state.token, 'new-token');
    expect(state.api.token, 'new-token');
    expect(state.needsGatewayLogin, isFalse);
    expect(state.gatewaySessionRecoveryInFlight, isNull);
    expect(observed, everyElement(isTrue));
  });

  test('transport failure keeps session and allows a later recovery', () async {
    final client = _FnConnectClient('http://127.0.0.1')
      ..failure = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionTimeout,
      );
    final state = _authenticatedState(client);
    addTearDown(state.dispose);
    await state.handleGatewaySessionExpired();
    expect(state.isAuthenticated, isTrue);
    expect(state.token, 'old-token');
    expect(state.api.token, 'old-token');
    expect(state.needsGatewayLogin, isFalse);
    expect(state.gatewaySessionRecoveryInFlight, isNull);
    await state.handleGatewaySessionExpired();
    expect(client.attempts, 2);
  });

  test('rejected credentials still require interactive login', () async {
    final client = _FnConnectClient('http://127.0.0.1')
      ..failure = const FnConnectAuthenticationException('Invalid credentials');
    final state = _authenticatedState(client);
    addTearDown(state.dispose);
    await state.handleGatewaySessionExpired();
    expect(state.isAuthenticated, isFalse);
    expect(state.needsGatewayLogin, isTrue);
    expect(state.token, isNull);
    expect(state.user, isNull);
  });

  test('wrapped WebSocket failure does not log out the user', () async {
    final client = _FnConnectClient('http://127.0.0.1')
      ..failure = const FnConnectProtocolException(
        'fnOS account login failed: connection closed',
      );
    final state = _authenticatedState(client);
    addTearDown(state.dispose);
    await state.handleGatewaySessionExpired();
    expect(state.isAuthenticated, isTrue);
    expect(state.needsGatewayLogin, isFalse);
    expect(state.connectionError, isNotNull);
  });

  for (final hasToken in [true, false]) {
    test('startup finishes FNID login before returning (cached token: $hasToken)',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final paths = <String>[];
      server.listen((request) async {
        paths.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/api/auth/token-login')) {
          request.response.statusCode = 401;
          request.response.write(jsonEncode({'message': 'invalid token'}));
        } else if (request.uri.path.endsWith('/api/auth/login')) {
          request.response.write(jsonEncode({
            'token': 'new-token',
            'user': {'id': '1', 'username': 'reader', 'role': 'user'},
          }));
        } else {
          request.response.write('{}');
        }
        await request.response.close();
      });
      final client = _FnConnectClient('http://127.0.0.1:${server.port}')
        ..loginStarted = Completer<void>()
        ..allowLogin = Completer<void>();
      _seedStartup(client, hasToken: hasToken);
      final state = _StartupAppState(client);
      addTearDown(state.dispose);
      var startupFinished = false;
      final startup = state.initialize().then((_) => startupFinished = true);
      await client.loginStarted!.future.timeout(const Duration(seconds: 5));
      expect(startupFinished, isFalse);
      expect(state.gatewayStartupLoginAttempted, isTrue);
      client.allowLogin!.complete();
      await startup;

      expect(state.isAuthenticated, isTrue, reason: state.connectionError);
      expect(state.needsGatewayLogin, isFalse);
      expect(state.connectionError, isNull);
      expect(client.attempts, 1);
      expect(paths.where((p) => p.endsWith('/api/auth/login')), hasLength(1));
      expect(paths.contains('/app/ting-reader/api/auth/token-login'), hasToken);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), 'new-token');
      expect(prefs.getBool('gateway_relogin_required'), isNull);
    });
  }

  test('startup preserves a valid FNID session without credential login',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(
        request.uri.path.endsWith('/api/auth/token-login')
            ? {
                'token': 'renewed-token',
                'user': {'id': '1', 'username': 'reader', 'role': 'user'},
              }
            : {},
      ));
      await request.response.close();
    });
    final client = _FnConnectClient('http://127.0.0.1:${server.port}');
    _seedStartup(client);
    final state = _StartupAppState(client);
    addTearDown(state.dispose);
    await state.initialize();
    expect(state.isAuthenticated, isTrue, reason: state.connectionError);
    expect(state.token, 'renewed-token');
    expect(client.attempts, 0);
    expect(state.gatewayStartupLoginAttempted, isFalse);
  });

  test('startup authentication failure is attempted once and exposes login',
      () async {
    final client = _FnConnectClient('http://127.0.0.1')
      ..failure = const FnConnectTwofaRequiredException();
    _seedStartup(client, hasToken: false);
    final state = _StartupAppState(client);
    addTearDown(state.dispose);
    await state.initialize();
    expect(client.attempts, 1);
    expect(state.isAuthenticated, isFalse);
    expect(state.needsGatewayLogin, isTrue);
    expect(state.gatewayStartupLoginAttempted, isTrue);
  });

  test('cancelled startup cannot complete FNID login later', () async {
    final client = _FnConnectClient('http://127.0.0.1')
      ..loginStarted = Completer<void>()
      ..allowLogin = Completer<void>();
    _seedStartup(client, hasToken: false);
    final state = _StartupAppState(client);
    addTearDown(state.dispose);
    final startup = state.initialize();
    final cancelled = expectLater(startup, throwsA(anything));
    await client.loginStarted!.future.timeout(const Duration(seconds: 5));
    state.cancelStartup();
    expect(client.loginCancelToken!.isCancelled, isTrue);
    client.allowLogin!.complete();
    await cancelled;
    expect(state.isAuthenticated, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
  });

  test('saved FNID credentials alone do not undo an explicit logout', () async {
    final client = _FnConnectClient('http://127.0.0.1');
    _seedStartup(client, hasSession: false);
    final state = _StartupAppState(client);
    addTearDown(state.dispose);
    await state.initialize();
    expect(client.attempts, 0);
    expect(state.isAuthenticated, isFalse);
  });

  test('fnOS protocol failure is not replaced by an unauthenticated fallback',
      () async {
    const failure = FnConnectProtocolException('WebSocket handshake failed');
    final client = _FnConnectClient('http://127.0.0.1')..failure = failure;
    final state = _StartupAppState(client);
    addTearDown(state.dispose);
    await expectLater(
      state.login(
        server: 'https://example.fnos.net',
        username: 'reader',
        password: 'password',
        mode: ServerProfileMode.fnosGateway,
        fnId: 'example',
        fnosUsername: 'fn-user',
        fnosPassword: 'fn-password',
      ),
      throwsA(same(failure)),
    );
    expect(client.attempts, 1);
  });
}
