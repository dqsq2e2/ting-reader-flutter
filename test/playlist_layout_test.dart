import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/l10n/app_localizations.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';
import 'package:ting_reader_flutter/src/features/playlists/playlists_page.dart';
import 'package:ting_reader_flutter/src/shared/app_scope.dart';
import 'package:ting_reader_flutter/src/shared/common/media_widgets.dart';

final _books = List.generate(
    3,
    (index) => {
          'id': 'book-$index',
          'library_id': 'library',
          'title': '书籍 $index',
        });
final _playlist = {
  'id': 'playlist',
  'title': '给每一个平凡日子的一份很长很长的听书清单',
  'description': '在路上，在睡前，留一点时间给自己。',
  'books': _books,
  'book_ids': _books.map((book) => book['id']).toList(),
};

class _PlaylistApi extends ApiClient {
  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: switch (path) {
        '/api/playlists' => [_playlist],
        '/api/playlists/playlist' => _playlist,
        '/api/books' => _books,
        _ => [],
      },
    );
  }
}

class _PlaylistApp extends AppState {
  final _playlistApi = _PlaylistApi();

  @override
  _PlaylistApi get api => _playlistApi;
}

class _PlaylistPlayer extends ChangeNotifier implements PlayerState {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [320.0, 390.0, 768.0, 1280.0, 1920.0]) {
    for (final shape in ['square', 'rect']) {
      for (final size in ['small', 'medium', 'large']) {
        testWidgets('playlist stack fits $width / $shape / $size',
            (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final app = _PlaylistApp()
            ..settings = {
              'settings_json': {
                'playlist_icon_size': size,
                'bookshelf_cover_shape': shape,
              },
            };
          final downloads = DownloadState(app);
          final player = _PlaylistPlayer();
          addTearDown(app.dispose);
          addTearDown(downloads.dispose);
          addTearDown(player.dispose);
          String? opened;
          await tester.pumpWidget(AppScope(
            appState: app,
            downloadState: downloads,
            playerState: player,
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: PlaylistsPage(
                  openPlaylist: (id) => opened = id,
                  onBack: () {},
                ),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Even a single playlist keeps its bookshelf cell width.
          final cover = find.byType(CoverImage).first;
          expect(tester.getSize(cover).width, lessThan(width / 2));
          expect(find.byType(CoverImage), findsNWidgets(3));
          final label = find.text(_playlist['title'] as String);
          expect(tester.widget<Text>(label).maxLines, 1);
          expect(tester.widget<Text>(label).overflow, TextOverflow.ellipsis);
          final description = find.text(_playlist['description'] as String);
          expect(tester.widget<Text>(description).maxLines, 1);
          expect(
              tester.widget<Text>(description).overflow, TextOverflow.ellipsis);
          await tester.ensureVisible(label);
          await tester.tap(label);
          expect(opened, 'playlist');
        });
      }
    }
  }
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets('playlist detail and content management fit $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = _PlaylistApp();
      final downloads = DownloadState(app);
      final player = _PlaylistPlayer();
      addTearDown(app.dispose);
      addTearDown(downloads.dispose);
      addTearDown(player.dispose);
      await tester.pumpWidget(AppScope(
        appState: app,
        downloadState: downloads,
        playerState: player,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlaylistDetailPage(
              playlistId: 'playlist',
              onBack: () {},
              openBook: (_) {},
              openSeries: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final value in [_playlist['title'], _playlist['description']]) {
        final text = tester.widget<Text>(find.text(value as String));
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
      }
      await tester.ensureVisible(find.text('管理内容'));
      await tester.tap(find.text('管理内容'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('保存书单'), findsOneWidget);
    });
  }
}
