import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  promptWorkflowTests();
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
    test(
        'startup finishes FNID login before returning (cached token: $hasToken)',
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
      expect(prefs.getString('auth_token'), isNull);
      final scope = prefs.getString('active_session_scope')!;
      final session = jsonDecode(
        (await const FlutterSecureStorage().read(key: scope))!,
      ) as Map<String, dynamic>;
      expect(session['token'], 'new-token');
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

  test('direct discovery follows redirects and reuses its own cache', () async {
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => target.close(force: true));
    addTearDown(() => redirect.close(force: true));
    var probes = 0;
    target.listen((request) async {
      probes++;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'healthy'}));
      await request.response.close();
    });
    redirect.listen((request) async {
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader,
            'http://127.0.0.1:${target.port}${request.uri.path}');
      await request.response.close();
    });
    final state = AppState();
    addTearDown(state.dispose);
    final source = 'http://127.0.0.1:${redirect.port}';
    final resolved = await state.resolveServerUrl(source);
    expect(resolved.resolvedUrl, 'http://127.0.0.1:${target.port}');
    expect(resolved.fromCache, isFalse);
    final cached = await state.resolveServerUrl(source);
    expect(cached.fromCache, isTrue);
    expect(probes, 1);
    expect(state.resolvingRedirect, isFalse);
    // A second application state has its own discovery cache.
    final other = AppState();
    addTearDown(other.dispose);
    await other.resolveServerUrl(source);
    expect(probes, 2);
  });

  test('cancelled discovery releases its client and allows a fresh probe',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final started = Completer<void>();
    var requests = 0;
    server.listen((request) async {
      requests++;
      if (requests == 1) {
        started.complete();
        return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'healthy'}));
      await request.response.close();
    });
    final state = AppState();
    addTearDown(state.dispose);
    final source = 'http://127.0.0.1:${server.port}';
    final cancellation = CancelToken();
    final pending = state.resolveBestServerUrl(
      server: source,
      localServer: '',
      cancelToken: cancellation,
    );
    final rejected = expectLater(pending, throwsA(anything));
    await started.future.timeout(const Duration(seconds: 5));
    cancellation.cancel('User cancelled discovery');
    await rejected.timeout(const Duration(seconds: 5));
    expect(state.resolvingRedirect, isFalse);
    final retry = await state.resolveBestServerUrl(
      server: source,
      localServer: '',
    );
    expect(retry.resolvedUrl, source);
    expect(requests, 2);
  });

  test('disposing application state cancels discovery and detaches callbacks',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final started = Completer<void>();
    server.listen((_) => started.complete());
    final state = AppState();
    final pending = state.resolveServerUrl('http://127.0.0.1:${server.port}');
    final rejected = expectLater(pending, throwsA(anything));
    await started.future.timeout(const Duration(seconds: 5));
    state.dispose();
    await rejected.timeout(const Duration(seconds: 5));
    expect(state.api.onGatewaySessionExpired, isNull);
    expect(state.api.recoverBaseUrl, isNull);
    expect(state.resolvingRedirect, isFalse);
  });

  test('disposing application state prevents late gateway renewal', () async {
    final client = _FnConnectClient('http://127.0.0.1')
      ..loginStarted = Completer<void>()
      ..allowLogin = Completer<void>();
    final state = _authenticatedState(client);
    final pending = state.handleGatewaySessionExpired();
    await client.loginStarted!.future.timeout(const Duration(seconds: 5));
    state.dispose();
    expect(client.loginCancelToken!.isCancelled, isTrue);
    client.allowLogin!.complete();
    await pending;
    expect(state.token, 'old-token');
    expect(state.gatewaySessionRecoveryInFlight, isNull);
  });
}

class _PromptApp extends AppState {
  final codes = <String?>[];
  final modes = <ServerProfileMode>[];
  Future<void>? recoveryGate;
  String recovered = 'https://next.test/app/ting-reader-docker';
  @override
  Future<void> login(
      {required String server,
      String localServer = '',
      required String username,
      required String password,
      ServerProfileMode mode = ServerProfileMode.direct,
      String fnId = '',
      String fnosUsername = '',
      String fnosPassword = '',
      String? gatewayCookie,
      String? fnAccessCode,
      Future<FnTwofaAnswer?> Function()? onTwofaRequired,
      ValueChanged<FnConnectStage>? onFnConnectStage,
      SavedServerProfile? replaceProfile,
      Map<String, dynamic> loginSettingsPatch = const {},
      CancelToken? cancelToken}) async {
    codes.add(fnAccessCode);
    modes.add(mode);
    if (fnAccessCode == null) {
      throw const FnConnectAccessCodeRequiredException();
    }
    if (fnAccessCode == 'bad') throw const FnConnectAccessCodeException();
  }

  @override
  Future<String?> recoverActiveUrl({CancelToken? cancelToken}) async {
    await recoveryGate;
    return recovered;
  }
}

void promptWorkflowTests() {
  const profile = SavedServerProfile(
      serverUrl: 'https://example.fnos.net',
      activeUrl: '',
      username: 'reader',
      password: 'secret',
      label: 'Test',
      mode: ServerProfileMode.fnosGateway,
      fnId: 'example.fnos.net');
  test(
      'one login loop handles missing and incorrect access codes without recursive attempts',
      () async {
    final app = _PromptApp();
    addTearDown(app.dispose);
    final hints = <bool>[];
    await app.loginWithPrompts(profile, requestAccessCode: (incorrect) async {
      hints.add(incorrect);
      return incorrect ? 'correct' : 'bad';
    });
    expect(app.codes, [null, 'bad', 'correct']);
    expect(hints, [false, true]);
    expect(app.modes, everyElement(ServerProfileMode.fnosGateway));
  });
  test('cancelled access-code prompt never retries a disposed login attempt',
      () async {
    final app = _PromptApp();
    addTearDown(app.dispose);
    final token = CancelToken();
    await expectLater(
        app.loginWithPrompts(profile, cancelToken: token,
            requestAccessCode: (_) async {
          token.cancel('Closed');
          return 'correct';
        }),
        throwsA(isA<DioException>()));
    expect(app.codes, [null]);
  });
  test(
      'resource recovery preserves gateway-relative paths and ignores another server session',
      () async {
    final app = _PromptApp()
      ..serverUrl = 'https://before.test'
      ..activeUrl = 'https://before.test/app/ting-reader';
    addTearDown(app.dispose);
    expect(
        await app.recoverResourceUrl(
            'https://before.test/app/ting-reader/api/proxy/cover?id=one'),
        'https://next.test/app/ting-reader-docker/api/proxy/cover?id=one');
    expect(
        await app.recoverResourceUrl('https://outside.test/cover.jpg'), isNull);
    final gate = Completer<void>();
    app.recoveryGate = gate.future;
    final recovering =
        app.recoverResourceUrl('https://before.test/app/ting-reader/api/cover');
    app.serverUrl = 'https://another.test';
    gate.complete();
    expect(await recovering, isNull);
  });
}
