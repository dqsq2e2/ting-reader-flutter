import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/l10n/app_localizations.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';
import 'package:ting_reader_flutter/src/core/models/models.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';
import 'package:ting_reader_flutter/src/features/admin/admin_pages.dart';
import 'package:ting_reader_flutter/src/shared/app_scope.dart';

class _LibraryApi extends ApiClient {
  _LibraryApi(bool enabled, {String libraryType = 'webdav', bool? autoSeries})
      : library = {
          'id': 'dav-library',
          'name': 'WebDAV fixture',
          'library_type': libraryType,
          'url': 'https://example.test/dav',
          'root_path': '/books',
          'scraper_config': {
            'webdav_metadata_writing_enabled': enabled,
            'scheduled_sync_interval': 'weekly',
            if (autoSeries != null) 'auto_generate_series': autoSeries,
          },
        };

  Map<String, dynamic> library;
  final updates = <Map<String, dynamic>>[];

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: path == '/api/libraries' ? [library] : {'sources': []},
    );
  }

  @override
  Future<Response<dynamic>> patch(String path,
      {Object? data, CancelToken? cancelToken}) async {
    expect(path, '/api/libraries/dav-library');
    updates.add(Map<String, dynamic>.from(data as Map));
    library = {...library, ...updates.last};
    return Response(requestOptions: RequestOptions(path: path), data: library);
  }
}

class _LibraryApp extends AppState {
  _LibraryApp(bool enabled, {String libraryType = 'webdav', bool? autoSeries})
      : _libraryApi = _LibraryApi(enabled,
            libraryType: libraryType, autoSeries: autoSeries);
  final _LibraryApi _libraryApi;
  @override
  _LibraryApi get api => _libraryApi;
}

class _LibraryPlayer extends ChangeNotifier implements PlayerState {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final locale in ['zh', 'en']) {
    for (final initiallyEnabled in [false, true]) {
      testWidgets('WebDAV setting persists in $locale ($initiallyEnabled)',
          (tester) async {
        tester.view.physicalSize = const Size(1200, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = _LibraryApp(initiallyEnabled)
          ..user = const User(id: 'admin', username: 'admin', role: 'admin');
        final player = _LibraryPlayer();
        final downloads = DownloadState(app);
        addTearDown(app.dispose);
        addTearDown(player.dispose);
        addTearDown(downloads.dispose);
        await tester.pumpWidget(AppScope(
          appState: app,
          downloadState: downloads,
          playerState: player,
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: AdminLibrariesPage()),
          ),
        ));
        await tester.pumpAndSettle();
        final editTooltip = locale == 'zh' ? '编辑存储库' : 'Edit library';
        await tester.tap(find.byTooltip(editTooltip));
        await tester.pumpAndSettle();
        final title = locale == 'zh' ? '元数据写入网盘' : 'Write metadata to WebDAV';
        final label = find.text(title);
        await tester.ensureVisible(label);
        expect(label, findsOneWidget);
        final row =
            find.ancestor(of: label, matching: find.byType(Container)).first;
        final toggle =
            find.descendant(of: row, matching: find.byType(Checkbox));
        expect(tester.widget<Checkbox>(toggle).value, initiallyEnabled);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await tester.tap(find.text(locale == 'zh' ? '保存配置' : 'Save'));
        await tester.pumpAndSettle();
        expect(app.api.updates, hasLength(1));
        final config = app.api.updates.single['scraper_config'] as Map;
        expect(config['webdav_metadata_writing_enabled'], !initiallyEnabled);
        expect(config['scheduled_sync_interval'], 'weekly');
        await tester.tap(find.byTooltip(editTooltip));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(title));
        final reopenedRow = find
            .ancestor(of: find.text(title), matching: find.byType(Container))
            .first;
        final reopenedToggle =
            find.descendant(of: reopenedRow, matching: find.byType(Checkbox));
        expect(
            tester.widget<Checkbox>(reopenedToggle).value, !initiallyEnabled);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final libraryType in ['local', 'webdav']) {
    for (final initiallyEnabled in <bool?>[null, false, true]) {
      testWidgets('$libraryType series generation persists ($initiallyEnabled)',
          (tester) async {
        tester.view.physicalSize = const Size(1200, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = _LibraryApp(false,
            libraryType: libraryType, autoSeries: initiallyEnabled)
          ..user = const User(id: 'admin', username: 'admin', role: 'admin');
        final player = _LibraryPlayer();
        final downloads = DownloadState(app);
        addTearDown(app.dispose);
        addTearDown(player.dispose);
        addTearDown(downloads.dispose);
        await tester.pumpWidget(AppScope(
          appState: app,
          downloadState: downloads,
          playerState: player,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AdminLibrariesPage()),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('编辑存储库'));
        await tester.pumpAndSettle();
        final label = find.text('自动生成系列');
        await tester.ensureVisible(label);
        final row =
            find.ancestor(of: label, matching: find.byType(Container)).first;
        final toggle =
            find.descendant(of: row, matching: find.byType(Checkbox));
        final expectedInitialValue = initiallyEnabled ?? true;
        expect(tester.widget<Checkbox>(toggle).value, expectedInitialValue);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('优先使用文件/文件夹名作为标题'), findsNothing);
        await tester.ensureVisible(find.text('优先级'));
        await tester.tap(find.text('优先级'));
        await tester.pumpAndSettle();
        final filename = find.text('文件/文件夹名');
        await tester.ensureVisible(filename);
        expect(tester.getTopLeft(filename).dy,
            lessThan(tester.getTopLeft(find.text('本地元数据 (JSON/NFO)')).dy));
        final filenameRow =
            find.ancestor(of: filename, matching: find.byType(Container)).first;
        await tester.tap(find.descendant(
            of: filenameRow,
            matching: find.byIcon(Icons.arrow_downward_rounded)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存配置'));
        await tester.pumpAndSettle();
        expect(app.api.updates, hasLength(1));
        final config = app.api.updates.single['scraper_config'] as Map;
        expect(config['auto_generate_series'], !expectedInitialValue);
        expect(config['scheduled_sync_interval'], 'weekly');
        expect(config.containsKey('use_filename_as_title'), isFalse);
        expect(config['metadata_priority'],
            ['local_metadata', 'filename', 'audio_metadata', 'scraper']);
        await tester.tap(find.byTooltip('编辑存储库'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(label);
        final reopenedRow =
            find.ancestor(of: label, matching: find.byType(Container)).first;
        final reopenedToggle =
            find.descendant(of: reopenedRow, matching: find.byType(Checkbox));
        expect(tester.widget<Checkbox>(reopenedToggle).value,
            !expectedInitialValue);
        await tester.ensureVisible(find.text('优先级'));
        await tester.tap(find.text('优先级'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(filename);
        expect(tester.getTopLeft(find.text('本地元数据 (JSON/NFO)')).dy,
            lessThan(tester.getTopLeft(filename).dy));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
