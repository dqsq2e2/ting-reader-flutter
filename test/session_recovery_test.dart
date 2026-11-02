import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ting_reader_flutter/src/core/models/models.dart';
import 'package:ting_reader_flutter/src/core/services/session_monitor.dart';
import 'package:ting_reader_flutter/src/core/services/socket_heartbeat.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';

const _user = {'id': 'reader', 'username': 'reader', 'role': 'user'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previous);
  });

  Future<HttpServer> serve(Future<void> Function(HttpRequest) handler) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        await handler(request);
      } on SocketException {/* 取消请求会关闭测试连接。 */}
    });
    addTearDown(() => server.close(force: true));
    return server;
  }

  AppState authenticated(HttpServer server, {bool password = true}) {
    final base = 'http://127.0.0.1:${server.port}';
    final state = AppState()
      ..serverUrl = base
      ..activeUrl = base
      ..token = 'expired'
      ..user = User.fromJson(_user)
      ..savedServers = [
        SavedServerProfile(
            serverUrl: base,
            activeUrl: base,
            username: 'reader',
            password: password ? 'fixture-password' : '',
            label: 'reader')
      ];
    state.api.configure(baseUrl: base, token: state.token);
    addTearDown(state.dispose);
    return state;
  }

  Future<void> respond(HttpRequest request, int status, Object data) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  }

  test('直连并发过期只登录一次，界面保持登录且请求重试成功', () async {
    var logins = 0;
    final started = Completer<void>();
    final release = Completer<void>();
    final server = await serve((request) async {
      await request.drain<void>();
      if (request.uri.path == '/api/auth/login') {
        logins++;
        if (!started.isCompleted) started.complete();
        await release.future;
        await respond(request, 200, {'token': 'renewed', 'user': _user});
      } else {
        final valid =
            request.headers.value('authorization') == 'Bearer renewed';
        await respond(request, valid ? 200 : 401, {'ok': valid});
      }
    });
    final state = authenticated(server);
    final observed = <bool>[];
    state.addListener(() => observed.add(state.isAuthenticated));
    var restored = 0;
    state.onGatewayLoginRestored = () async {
      restored++;
    };
    final pending =
        Future.wait(List.generate(6, (i) => state.api.get('/api/items/$i')));
    await started.future;
    expect(state.isAuthenticated, isTrue);
    expect(state.api.token, 'expired');
    release.complete();
    expect((await pending).every((item) => item.statusCode == 200), isTrue);
    expect(logins, 1);
    expect(restored, 1);
    expect(observed, everyElement(isTrue));
    expect(state.token, 'renewed');
  });

  test('直连写入重试保留幂等标识和请求内容', () async {
    var logins = 0;
    final keys = <String?>[];
    final bodies = <dynamic>[];
    final server = await serve((request) async {
      final body = await utf8.decoder.bind(request).join();
      if (request.uri.path == '/api/auth/login') {
        logins++;
        expect(request.headers.value('authorization'), isNull);
        await respond(request, 200, {'token': 'renewed', 'user': _user});
      } else {
        keys.add(request.headers.value('idempotency-key'));
        bodies.add(jsonDecode(body));
        await respond(
            request,
            request.headers.value('authorization') == 'Bearer renewed'
                ? 200
                : 401,
            {});
      }
    });
    final state = authenticated(server);
    await state.api.post('/api/progress', data: {'position': 123});
    expect(logins, 1);
    expect(keys, hasLength(2));
    expect(keys.first, isNotEmpty);
    expect(keys.first, keys.last);
    expect(bodies, [
      {'position': 123},
      {'position': 123}
    ]);
  });

  test('权限不足不触发重登或清除账号', () async {
    var logins = 0;
    final server = await serve((request) async {
      await request.drain<void>();
      if (request.uri.path == '/api/auth/login') logins++;
      await respond(request, 403, {});
    });
    final state = authenticated(server);
    await expectLater(
        state.api.get('/api/admin'), throwsA(isA<DioException>()));
    expect(logins, 0);
    expect(state.isAuthenticated, isTrue);
  });

  test('密码失效提示应用内重登，不循环登录且保留服务器配置', () async {
    var logins = 0;
    final server = await serve((request) async {
      await request.drain<void>();
      if (request.uri.path == '/api/auth/login') logins++;
      await respond(request, 401, {});
    });
    final state = authenticated(server);
    await expectLater(state.api.get('/api/me'), throwsA(isA<DioException>()));
    expect(logins, 1);
    expect(state.token, isNull);
    expect(state.needsDirectLogin, isTrue);
    expect(state.savedServers, hasLength(1));
    expect(state.connectionError, contains('无需退出'));
  });

  test('重登网络失败保留会话并限速重试', () async {
    var logins = 0;
    final server = await serve((request) async {
      await request.drain<void>();
      if (request.uri.path == '/api/auth/login') logins++;
      await respond(
          request, request.uri.path == '/api/auth/login' ? 503 : 401, {});
    });
    final state = authenticated(server);
    await expectLater(state.api.get('/api/me'), throwsA(isA<DioException>()));
    await expectLater(
        state.api.get('/api/another'), throwsA(isA<DioException>()));
    expect(logins, 1);
    expect(state.token, 'expired');
    expect(state.isAuthenticated, isTrue);
    expect(state.needsDirectLogin, isFalse);
    expect(state.connectionError, isNull);
  });

  test('没有保存密码时直接显示登录入口', () async {
    var logins = 0;
    final server = await serve((request) async {
      await request.drain<void>();
      if (request.uri.path == '/api/auth/login') logins++;
      await respond(request, 401, {});
    });
    final state = authenticated(server, password: false);
    await expectLater(state.api.get('/api/me'), throwsA(isA<DioException>()));
    expect(logins, 0);
    expect(state.needsDirectLogin, isTrue);
  });

  for (final logout in [true, false]) {
    test('重登期间${logout ? '退出' : '切换账号'}，迟到结果不能恢复旧身份', () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var protected = 0;
      final server = await serve((request) async {
        await request.drain<void>();
        if (request.uri.path == '/api/auth/login') {
          started.complete();
          await release.future;
          await respond(request, 200, {'token': 'renewed', 'user': _user});
        } else {
          protected++;
          await respond(request, 401, {});
        }
      });
      final state = authenticated(server);
      final pending =
          expectLater(state.api.get('/api/me'), throwsA(isA<DioException>()));
      await started.future;
      if (logout) {
        await state.logout();
      } else {
        state.user = const User(id: 'other', username: 'other', role: 'user');
        state.token = 'other-token';
        state.api.configure(baseUrl: state.activeUrl, token: state.token);
      }
      release.complete();
      await pending;
      expect(state.token, logout ? isNull : 'other-token');
      expect(state.user?.id, logout ? isNull : 'other');
      expect(protected, 1);
    });
  }

  testWidgets('未收到 pong 十秒后断线处理，旧心跳计时器停止', (tester) async {
    var pings = 0;
    var timeouts = 0;
    final heartbeat = SocketHeartbeat(sendPing: () {
      pings++;
    }, onTimeout: () {
      timeouts++;
    })
      ..start();
    await tester.pump(const Duration(seconds: 25));
    expect(pings, 1);
    await tester.pump(const Duration(seconds: 9));
    expect(timeouts, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(timeouts, 1);
    await tester.pump(const Duration(minutes: 2));
    expect(pings, 1);
    heartbeat.stop();
  });

  testWidgets('pong 取消超时，停止后不再发送心跳', (tester) async {
    var pings = 0;
    var timeouts = 0;
    final heartbeat = SocketHeartbeat(sendPing: () {
      pings++;
    }, onTimeout: () {
      timeouts++;
    })
      ..start();
    await tester.pump(const Duration(seconds: 25));
    heartbeat.pong();
    await tester.pump(const Duration(seconds: 15));
    expect(timeouts, 0);
    await tester.pump(const Duration(seconds: 10));
    expect(pings, 2);
    heartbeat.pong();
    heartbeat.stop();
    await tester.pump(const Duration(minutes: 1));
    expect(timeouts, 0);
    expect(pings, 2);
  });

  testWidgets('未播放时定期检查会话，恢复前台重试，禁用后停止请求', (tester) async {
    var enabled = true;
    var checks = 0;
    final monitor = SessionMonitor(
        enabled: () => enabled,
        check: (_) async {
          checks++;
          throw StateError('测试网络中断');
        })
      ..start();
    await tester.pump(const Duration(minutes: 1));
    expect(checks, 1);
    monitor.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(checks, 2);
    enabled = false;
    await tester.pump(const Duration(minutes: 1));
    expect(checks, 2);
    monitor.dispose();
    await tester.pump(const Duration(minutes: 1));
    expect(checks, 2);
  });

  testWidgets('会话检查合并并发，超时后取消旧请求', (tester) async {
    var checks = 0;
    CancelToken? cancellation;
    final monitor = SessionMonitor(
        enabled: () => true,
        check: (token) async {
          checks++;
          cancellation = token;
          await token.whenCancel;
        });
    final first = monitor.checkNow();
    final second = monitor.checkNow();
    expect(identical(first, second), isTrue);
    await tester.pump(const Duration(seconds: 10));
    expect(await first, isFalse);
    expect(cancellation!.isCancelled, isTrue);
    expect(checks, 1);
    monitor.dispose();
  });
}
