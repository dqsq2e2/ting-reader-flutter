import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/l10n/app_localizations.dart';
import 'package:ting_reader_flutter/src/core/api/api_client.dart';
import 'package:ting_reader_flutter/src/core/models/models.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/core/state/download_state.dart';
import 'package:ting_reader_flutter/src/core/state/player_state.dart';
import 'package:ting_reader_flutter/src/features/app_shell.dart';
import 'package:ting_reader_flutter/src/features/mine/mine_page.dart';
import 'package:ting_reader_flutter/src/shared/app_scope.dart';

class _ReminderApi extends ApiClient {
  Map<String, dynamic>? accountUpdate;

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? params, CancelToken? cancelToken}) async {
    return Response(
      requestOptions: RequestOptions(path: path),
      data: path == '/api/history/summary' || path == '/api/health'
          ? <String, dynamic>{}
          : [],
    );
  }

  @override
  Future<Response<dynamic>> patch(String path, {Object? data}) async {
    accountUpdate = Map<String, dynamic>.from(data as Map);
    return Response(
      requestOptions: RequestOptions(path: path),
      data: {
        'id': 'admin-id',
        'username': accountUpdate?['username'] ?? 'admin',
        'role': 'admin',
        'uses_default_admin_credentials': false,
      },
    );
  }
}

class _ReminderApp extends AppState {
  final _ReminderApi reminderApi = _ReminderApi();

  @override
  _ReminderApi get api => reminderApi;
}

class _ReminderPlayer extends ChangeNotifier implements PlayerState {
  @override
  bool get isMiniCollapsed => false;
  @override
  bool get hasChapter => false;
  @override
  bool get isExpanded => false;
  @override
  void setExpanded(bool value) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_ReminderApp> _pumpShell(WidgetTester tester,
    {bool usesDefaultCredentials = true, bool offline = false}) async {
  final app = _ReminderApp()
    ..token = 'authenticated-token'
    ..user = User(
      id: 'admin-id',
      username: 'admin',
      role: 'admin',
      usesDefaultAdminCredentials: usesDefaultCredentials,
    )
    ..offlineMode = offline;
  final downloads = DownloadState(app);
  final player = _ReminderPlayer();
  addTearDown(app.dispose);
  addTearDown(downloads.dispose);
  addTearDown(player.dispose);
  await tester.pumpWidget(AppScope(
    appState: app,
    downloadState: downloads,
    playerState: player,
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppShell(),
    ),
  ));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  test('credential status survives cached session encoding', () {
    final user = User.fromJson({
      'id': 'admin-id',
      'username': 'admin',
      'role': 'admin',
      'uses_default_admin_credentials': true,
    });
    expect(user.usesDefaultAdminCredentials, isTrue);
    expect(User.fromJson(jsonDecode(user.encode())).usesDefaultAdminCredentials,
        isTrue);
    expect(
        User.fromJson({'id': 'reader', 'username': 'reader', 'role': 'user'})
            .usesDefaultAdminCredentials,
        isFalse);
  });

  testWidgets(
      'default administrator reminder opens Mine and refreshes account status',
      (tester) async {
    final app = await _pumpShell(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Change credentials'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(MyPage), findsOneWidget);
    expect(find.widgetWithText(TextField, 'admin'), findsOneWidget);
    await tester.enterText(
        find.byWidgetPredicate(
            (widget) => widget is TextField && widget.obscureText),
        'new-password');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(app.api.accountUpdate, {'password': 'new-password'});
    expect(app.user?.usesDefaultAdminCredentials, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissal does not repeat on settings or playback updates',
      (tester) async {
    final app = await _pumpShell(tester);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    app.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changed credentials do not trigger the reminder',
      (tester) async {
    await _pumpShell(tester, usesDefaultCredentials: false);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
