import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/l10n/app_localizations.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';
import 'package:ting_reader_flutter/src/core/models/plugin.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';
import 'package:ting_reader_flutter/src/core/state/plugin_state.dart';
import 'package:ting_reader_flutter/src/core/state/log_state.dart';
import 'package:ting_reader_flutter/src/core/state/notification_state.dart';
import 'package:ting_reader_flutter/src/core/models/notification.dart';
import 'package:ting_reader_flutter/src/features/admin/admin_pages.dart';
import 'package:ting_reader_flutter/src/shared/app_scope.dart';

final _plugin = <String, dynamic>{
  'id': 'reading-tools',
  'name': 'Reading Tools',
  'version': '1.0.0',
  'state': 'active',
  'runtime': 'javascript',
  'description': 'Tools for managing books.',
  'admin_only': true,
  'license': 'MIT',
  'config_schema': {
    'type': 'object',
    'properties': <String, dynamic>{},
  },
  'dependencies': ['reading-base'],
  'permissions': [
    {'type': 'books_read'},
    {'type': 'chapters_read'},
    {'type': 'progress_read'},
    {'type': 'cache_read'},
    {'type': 'cache_write'},
    {'type': 'playlists_read'},
    {'type': 'playlists_write'},
    {'type': 'favorites_read'},
    {'type': 'favorites_write'},
    {'type': 'user_settings_read'},
    {'type': 'user_settings_write'},
    {'type': 'network_access', 'domain': 'example.com'},
  ],
  'capabilities': [
    {'id': 'events', 'kind': 'event_handler'},
    {'id': 'tasks', 'kind': 'task_handler'},
    {'id': 'store', 'kind': 'plugin_store'},
    {'id': 'ui', 'kind': 'ui_extension'},
    {'id': 'http', 'kind': 'http_route'},
    {'id': 'tools', 'kind': 'tool_provider'},
    {'id': 'more-tools', 'kind': 'tool_provider'},
    {
      'id': 'format',
      'kind': 'format_handler',
      'extensions': ['.wma', 'WMA', 'flac', 'ogg', 'opus', 'aac'],
    },
    {
      'id': 'content',
      'kind': 'content_processor',
      'extensions': ['.epub'],
    },
    {
      'id': 'metadata',
      'kind': 'metadata_provider',
      'search_fields': [
        {'key': 'title'}
      ],
      'result_fields': [
        {'key': 'title'},
        {'key': 'author'}
      ],
    },
  ],
};

class _PluginApi extends ApiClient {
  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) async {
    final data = switch (path) {
      '/api/v1/plugins' => [
          _plugin,
          {
            'id': 'simple-tool',
            'name': 'Simple Tool',
            'version': '1.0.0',
            'state': 'inactive',
            'capabilities': [
              {'id': 'tool', 'kind': 'tool_provider'},
            ],
          },
        ],
      '/api/v1/store/plugins' => [
          {..._plugin, 'id': 'store-tools', 'name': 'Store Tools'},
        ],
      _ => throw StateError('Unexpected request: $path'),
    };
    return Response(requestOptions: RequestOptions(path: path), data: data);
  }
}

class _PluginApp extends AppState {
  final _pluginApi = _PluginApi();

  @override
  _PluginApi get api => _pluginApi;
}

class _PluginPlayer extends ChangeNotifier implements PlayerState {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  adminStateTests();
  test('permissions decode their declared type and formats are deduplicated',
      () {
    final plugin = PluginItem.fromJson(_plugin);
    expect(plugin.permissions.length, 12);
    expect(plugin.permissions.first.type, 'books_read');
    expect(plugin.permissions.last.type, 'network_access');
    expect(plugin.permissions.last.scope, 'example.com');
    expect(plugin.supportedExtensions,
        ['wma', 'flac', 'ogg', 'opus', 'aac', 'epub']);
  });

  for (final width in [390.0, 1280.0]) {
    for (final language in ['zh', 'en']) {
      testWidgets(
          'plugin tags stay visible and permissions use a tooltip at $width pixels in $language',
          (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = _PluginApp();
        final downloads = DownloadState(app);
        final player = _PluginPlayer();
        addTearDown(app.dispose);
        addTearDown(downloads.dispose);
        addTearDown(player.dispose);
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          themeMode: width == 1280 ? ThemeMode.dark : ThemeMode.light,
          darkTheme: ThemeData.dark(),
          home: AppScope(
            appState: app,
            downloadState: downloads,
            playerState: player,
            child: const Scaffold(body: PluginsPage()),
          ),
        ));
        await tester.pumpAndSettle();
        final english = language == 'en';
        final metadata = english ? 'Metadata scraping' : '元数据刮削';
        final event = english ? 'Event handling' : '事件响应';
        final permissionCount = english ? '12 permissions' : '12 个权限';
        expect(find.text(metadata), findsOneWidget);
        expect(find.text(event), findsOneWidget);
        expect(find.text('JavaScript'), findsOneWidget);
        expect(find.text('WMA, FLAC, OGG, OPUS +2'), findsOneWidget);
        expect(find.text(english ? 'Admin only' : '仅管理员'), findsOneWidget);
        expect(find.text('unknown'), findsNothing);
        expect(find.text(permissionCount), findsOneWidget);
        expect(find.text('MIT'), findsOneWidget);
        expect(find.text(english ? 'Read books' : '读取书籍'), findsNothing);
        expect(find.text(english ? 'More information' : '更多信息'), findsNothing);
        final tooltipFinder = find.ancestor(
            of: find.text(permissionCount), matching: find.byType(Tooltip));
        final permissionMessage =
            tester.widget<Tooltip>(tooltipFinder).message!;
        expect(permissionMessage.split('\n'), hasLength(12));
        expect(permissionMessage, contains(english ? 'Read books' : '读取书籍'));
        expect(permissionMessage, contains(english ? 'Read chapters' : '读取章节'));
        expect(permissionMessage,
            contains(english ? 'Read playback progress' : '读取播放进度'));
        expect(permissionMessage,
            contains(english ? 'Modify preferences' : '修改个人设置'));
        expect(
            permissionMessage,
            contains(english
                ? 'Network access (example.com)'
                : '网络访问 (example.com)'));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(permissionCount));
        if (width == 1280) {
          final mouse =
              await tester.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.addPointer();
          await mouse.moveTo(tester.getCenter(find.text(permissionCount)));
          await tester.pump(const Duration(milliseconds: 600));
          expect(find.text(permissionMessage), findsOneWidget);
          await mouse.removePointer();
        } else {
          await tester.longPress(find.text(permissionCount));
          await tester.pump(const Duration(milliseconds: 600));
          expect(find.text(permissionMessage), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        Tooltip.dismissAllToolTips();
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        final storeTab = find.text('Plugin Store').first;
        // The store tab has its own label; the capability tag uses "Plugin store".
        final store = english ? storeTab : find.text('插件商店').first;
        await tester.ensureVisible(store);
        await tester.tap(store);
        await tester.pumpAndSettle();
        expect(find.text('Store Tools'), findsOneWidget);
        expect(find.text(metadata), findsOneWidget);
        expect(find.text(permissionCount), findsOneWidget);
        final storeTooltip = find.ancestor(
            of: find.text(permissionCount), matching: find.byType(Tooltip));
        expect(tester.widget<Tooltip>(storeTooltip).message, permissionMessage);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _ControlledAdminApi extends ApiClient {
  final requests = <({
    String path,
    Map<String, dynamic>? query,
    CancelToken? token,
    Completer<Response<dynamic>> response
  })>[];
  final digests = <String?>[];
  final mutations = <({String path, CancelToken? token, Object? data})>[];
  Completer<Response<dynamic>>? mutationGate;
  bool requireConfirmation = false;
  static final digest = 'a' * 64;

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) {
    final response = Completer<Response<dynamic>>();
    requests.add(
        (path: path, query: params, token: cancelToken, response: response));
    return response.future;
  }

  @override
  Future<Response<dynamic>> post(String path,
      {Object? data,
      Map<String, dynamic>? params,
      CancelToken? cancelToken,
      Duration? receiveTimeout}) async {
    mutations.add((path: path, token: cancelToken, data: data));
    if (!path.endsWith('/install')) {
      return mutationGate?.future ?? _adminResponse({});
    }
    final digest = data is FormData
        ? data.fields
            .where((field) => field.key == 'confirmed_package_sha256')
            .firstOrNull
            ?.value
        : (data as Map)['confirmed_package_sha256'] as String?;
    digests.add(digest);
    if (requireConfirmation && digest == null) {
      final options = RequestOptions(path: path);
      throw DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 428,
            data: {
              'requires_confirmation': true,
              'package_sha256': _ControlledAdminApi.digest,
              'name': 'Unknown developer package',
            },
          ));
    }
    return Response(requestOptions: RequestOptions(path: path), data: {});
  }

  @override
  Future<Response<dynamic>> delete(String path,
      {Object? data, Map<String, dynamic>? params, CancelToken? cancelToken}) {
    mutations.add((path: path, token: cancelToken, data: data));
    return mutationGate?.future ?? Future.value(_adminResponse({}));
  }
}

Response<dynamic> _adminResponse(Object? data) =>
    Response(requestOptions: RequestOptions(path: '/test'), data: data);

void adminStateTests() {
  test(
      'plugin mutation owns refresh and cancels a late uninstall without reloading',
      () async {
    final api = _ControlledAdminApi();
    final state = PluginState(api);
    final reloaded = state.reload('plugin@2.0.5');
    await Future<void>.delayed(Duration.zero);
    expect(api.mutations.single.path, '/api/v1/plugins/plugin%402.0.5/reload');
    expect(api.requests.single.path, '/api/v1/plugins');
    api.requests.single.response.complete(_adminResponse([
      {'id': 'current'}
    ]));
    expect(await reloaded, isTrue);
    expect(state.installed.single.id, 'current');
    api.mutationGate = Completer<Response<dynamic>>();
    final uninstall = state.uninstall('plugin@2.0.5');
    state.dispose();
    expect(api.mutations.last.token!.isCancelled, isTrue);
    api.mutationGate!.complete(_adminResponse({}));
    expect(await uninstall, isFalse);
    expect(api.requests, hasLength(1));
  });

  test('local plugin packages rebuild each confirmed upload and refresh once',
      () async {
    final api = _ControlledAdminApi()..requireConfirmation = true;
    final state = PluginState(api);
    addTearDown(state.dispose);
    final installing = state.installPackage(
      name: 'unknown.tr',
      bytes: Uint8List.fromList([1, 2, 3]),
      confirm: (confirmation) async {
        expect(confirmation.digest, _ControlledAdminApi.digest);
        return true;
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(api.digests, [null, _ControlledAdminApi.digest]);
    final bodies =
        api.mutations.map((request) => request.data as FormData).toList();
    expect(identical(bodies[0], bodies[1]), isFalse);
    expect(bodies.every((body) => body.files.single.value.length == 3), isTrue);
    expect(api.requests, hasLength(1));
    api.requests.single.response.complete(_adminResponse([]));
    expect(await installing, isTrue);
  });
  test(
      'notification reload ignores an old response and dispose cancels pending reads',
      () async {
    final api = _ControlledAdminApi();
    final state = NotificationState(api);
    final old = state.load();
    final current = state.load();
    expect(api.requests.take(2).every((request) => request.token!.isCancelled),
        isTrue);
    api.requests[2].response.complete(_adminResponse([
      {'id': 'active', 'name': 'Current', 'url': 'https://example.com'}
    ]));
    api.requests[3].response.complete(_adminResponse([]));
    await current;
    expect(state.webhooks.single.id, 'active');
    api.requests[0].response.complete(_adminResponse([
      {'id': 'stale'}
    ]));
    api.requests[1].response.complete(_adminResponse([]));
    await old;
    expect(state.webhooks.single.id, 'active');
    final closing = state.load();
    state.dispose();
    for (final request in api.requests.skip(4)) {
      expect(request.token!.isCancelled, isTrue);
      request.response.complete(_adminResponse([]));
    }
    await closing;
  });

  test('notification toggle preserves the same request template and secret',
      () {
    final webhook = NotificationWebhook.fromJson({
      'id': 'hook',
      'name': 'Webhook',
      'url': 'https://example.com',
      'secret': 'kept',
      'headers': {'Authorization': 'Bearer value'},
      'events': ['book.added']
    });
    final payload = webhook.toRequestJson(enabledOverride: false);
    expect(payload['enabled'], isFalse);
    expect(payload['secret'], 'kept');
    expect(payload['body_template'], defaultWebhookBodyTemplate);
    expect(payload['headers'], {'Authorization': 'Bearer value'});
    expect(payload['events'], ['book.added']);
  });
  test(
      'plugin configuration keeps secrets and coerces schema values outside the form',
      () {
    final state = PluginConfigurationState(
        _ControlledAdminApi(),
        PluginItem.fromJson({
          'id': 'configured@2.0.5',
          'name': 'Configured',
          'config_schema': {
            'properties': {
              'secret': {'type': 'string', 'x-encrypted': true},
              'count': {'type': 'integer', 'default': 9},
              'enabled': {'type': 'boolean', 'default': true},
              'choice': {
                'type': 'integer',
                'enum': [1, 2]
              },
              'list': {'type': 'array'},
              'options': {'type': 'object'},
            }
          },
        }));
    addTearDown(state.dispose);
    state.config = {
      'secret': PluginConfigurationState.secretPlaceholder,
      'choice': '2',
      'count': null,
      'kept': 'original'
    };
    expect(state.valueFor('count', state.properties['count']!), isNull);
    final values = state.readForm({
      'secret': '',
      'count': '12',
      'list': '["one"]',
      'options': '{"key":true}'
    });
    expect(values, {
      'secret': PluginConfigurationState.secretPlaceholder,
      'count': 12,
      'enabled': true,
      'choice': 2,
      'list': ['one'],
      'options': {'key': true},
      'kept': 'original'
    });
    expect(pluginEditorText(values['secret'], state.properties['secret']!), '');
    expect(() => state.readForm({'count': 'bad'}), throwsFormatException);
    expect(() => state.readForm({'count': '12', 'list': '{}'}),
        throwsFormatException);
  });

  test(
      'closing plugin configuration cancels loading and ignores a late response',
      () async {
    final api = _ControlledAdminApi();
    final state = PluginConfigurationState(
        api, PluginItem.fromJson({'id': 'config@2', 'name': 'Config'}));
    final loading = state.load();
    expect(api.requests.single.path, '/api/v1/plugins/config%402/config');
    state.dispose();
    expect(api.requests.single.token!.isCancelled, isTrue);
    api.requests.single.response.complete(_adminResponse({
      'config': {'late': 'value'}
    }));
    await loading;
    expect(state.config, isEmpty);
  });
  test(
      'plugin installation resolves shared transitive dependencies and rejects cycles',
      () {
    final state = PluginState(_ControlledAdminApi());
    addTearDown(state.dispose);
    PluginItem item(String id, List<String> dependencies) =>
        PluginItem.fromJson({
          'id': id,
          'name': id,
          'version': '1.0.0',
          'dependencies': dependencies,
        });
    final shared = item('shared', []);
    final a = item('a', ['shared']);
    final b = item('b', ['shared']);
    final target = item('target', ['a', 'b']);
    state.store = [shared, a, b, target];
    expect(state.installationPlan(target).map((item) => item.id),
        ['shared', 'a', 'b', 'target']);
    state.installed = [shared];
    expect(state.installationPlan(target).map((item) => item.id),
        ['a', 'b', 'target']);
    state.store = [
      item('a', ['b']),
      item('b', ['a'])
    ];
    expect(() => state.installationPlan(target), throwsStateError);
    state.store = [];
    expect(() => state.installationPlan(target), throwsStateError);
  });

  test('plugin requests cancel replacement and ignore late catalogue responses',
      () async {
    final api = _ControlledAdminApi();
    final state = PluginState(api);
    addTearDown(state.dispose);
    final first = state.loadInstalled();
    final second = state.loadInstalled();
    expect(api.requests.first.token!.isCancelled, isTrue);
    api.requests.last.response.complete(_adminResponse([
      {'id': 'current', 'name': 'Current'}
    ]));
    await second;
    api.requests.first.response.complete(_adminResponse([
      {'id': 'stale', 'name': 'Stale'}
    ]));
    await first;
    expect(state.installed.single.id, 'current');
  });

  test(
      'unknown plugin confirmation retries with digest and stops on page disposal',
      () async {
    final api = _ControlledAdminApi()..requireConfirmation = true;
    final state = PluginState(api);
    final result =
        await state.installStore('unknown', 'Unknown', (confirmation) async {
      expect(confirmation.digest, _ControlledAdminApi.digest);
      return true;
    });
    expect(result, isTrue);
    expect(api.digests, [null, _ControlledAdminApi.digest]);
    api.digests.clear();
    final decision = Completer<bool>();
    final waiting =
        state.installStore('unknown', 'Unknown', (_) => decision.future);
    await Future<void>.delayed(Duration.zero);
    state.dispose();
    decision.complete(true);
    expect(await waiting, isFalse);
    expect(api.digests, [null]);
  });

  test(
      'log filters cancel previous requests, keep current results and export the same query',
      () async {
    final api = _ControlledAdminApi();
    final state = LogState(api, pluginId: 'plugin@2.0.5');
    addTearDown(state.dispose);
    state.level = 'INFO';
    final first = state.load();
    state.level = 'ERROR';
    state.source = 'runtime';
    state.page = 2;
    final second = state.load();
    expect(api.requests.first.token!.isCancelled, isTrue);
    expect(api.requests.last.path, '/api/v1/plugins/plugin%402.0.5/logs');
    expect(api.requests.last.query,
        {'level': 'ERROR', 'source': 'runtime', 'page': 2, 'page_size': 100});
    api.requests.last.response.complete(_adminResponse({
      'logs': [
        {'message': 'current'}
      ],
      'total': 250
    }));
    await second;
    api.requests.first.response.complete(_adminResponse({
      'logs': [
        {'message': 'stale'}
      ]
    }));
    await first;
    expect(state.logs.single.message, 'current');
    expect(state.pageCount, 3);
    final exported = state.export();
    expect(api.requests.last.query, {'level': 'ERROR', 'source': 'runtime'});
    api.requests.last.response.complete(_adminResponse('exported'));
    expect(await exported, 'exported');
  });

  testWidgets(
      'log refresh skips active requests and disposal cancels timers and late updates',
      (tester) async {
    final api = _ControlledAdminApi();
    final state = LogState(api);
    var notifications = 0;
    state.addListener(() => notifications++);
    state.start();
    await tester.pump(const Duration(seconds: 9));
    expect(api.requests, hasLength(1));
    final beforeDispose = notifications;
    state.dispose();
    expect(api.requests.single.token!.isCancelled, isTrue);
    api.requests.single.response.complete(_adminResponse({
      'logs': [
        {'message': 'late'}
      ]
    }));
    await tester.pump(const Duration(seconds: 9));
    expect(api.requests, hasLength(1));
    expect(state.logs, isEmpty);
    expect(notifications, beforeDispose);
  });
}
