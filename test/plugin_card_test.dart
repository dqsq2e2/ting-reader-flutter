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
