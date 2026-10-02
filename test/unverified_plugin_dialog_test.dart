import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/l10n/app_localizations.dart';
import 'package:ting_reader_flutter/src/core/models/plugin.dart';
import 'package:ting_reader_flutter/src/shared/dialogs/unverified_plugin_dialog.dart';

void main() {
  for (final language in ['zh', 'en']) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
          'permission review scrolls and cancels at $width in $language',
          (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final confirmation = UnverifiedPluginConfirmation.fromJson({
          'plugin_name': 'Unknown Plugin',
          'plugin_version': '2.0.0',
          'runtime': 'native',
          'package_sha256': 'a' * 64,
          'package_changed': true,
          'permissions': [
            {'type': 'network_access', 'domain': '*'},
            {'type': 'file_write', 'path': 'data/${'long-path/' * 30}'},
            for (var index = 0; index < 30; index++)
              {
                'type': 'capability_invoke',
                'plugin_id': 'other-$index',
                'capability_id': 'tools'
              },
          ],
          'capabilities': [
            {'id': 'tools', 'kind': 'tool_provider'},
          ],
        }, fallbackName: 'Fallback');
        bool? accepted;
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        accepted = await showDialog<bool>(
                          context: context,
                          builder: (_) => UnverifiedPluginDialog(
                              confirmation: confirmation),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  )),
        ));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final english = language == 'en';
        expect(find.text('Unknown Plugin · 2.0.0'), findsOneWidget);
        expect(find.text(english ? 'Requested access permissions' : '请求的访问权限'),
            findsOneWidget);
        expect(find.text('*'), findsOneWidget);
        expect(find.text(english ? 'Sensitive permission' : '高风险权限'),
            findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(english ? 'Cancel' : '取消'));
        await tester.pumpAndSettle();
        expect(accepted, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('zero requested permissions are explicit and can be accepted',
      (tester) async {
    final confirmation = UnverifiedPluginConfirmation.fromJson({
      'permissions': [],
      'capabilities': [],
      'runtime': 'javascript',
    }, fallbackName: 'Zero Permissions');
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: UnverifiedPluginDialog(confirmation: confirmation)),
    ));
    expect(find.text('No host access permissions requested'), findsOneWidget);
    expect(find.text('Agree and install'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
