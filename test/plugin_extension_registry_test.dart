import 'package:flutter_test/flutter_test.dart';
import 'package:ting_reader_flutter/src/core/models/plugin.dart';
import 'package:ting_reader_flutter/src/core/plugin_extensions/registry.dart';
import 'package:ting_reader_flutter/src/core/plugin_extensions/types.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';
import 'package:ting_reader_flutter/src/shared/plugin_extensions/plugin_extension_host.dart';

void main() {
  test('registers sidebar pages with their declared icon and render metadata',
      () {
    const registration = PluginCapabilityRegistration(
      pluginId: 'reading-tools',
      pluginName: 'Reading Tools',
      capability: PluginCapability(
        id: 'rules',
        kind: 'ui_extension',
        extra: {
          'slot': 'app.sidebar_page',
          'title': {'zh': '响应规则', 'en': 'Response Rules'},
          'icon': {'type': 'lucide', 'value': 'workflow'},
          'priority': 12,
          'render_mode': 'web_container',
          'render': {
            'entry': '/plugins/reading-tools/rules',
            'bridge': {
              'capabilities': ['rules.tools'],
              'host_methods': ['user_settings.get'],
            },
          },
        },
      ),
    );

    final registry = buildClientExtensionRegistry([registration]);
    final extension =
        registry.bySlot[ClientExtensionSlot.appSidebarPage]!.single;

    expect(extension.label, '响应规则');
    expect(extension.icon, {'type': 'lucide', 'value': 'workflow'});
    expect(extension.entry, '/plugins/reading-tools/rules');
    expect(extension.allowsCapabilityInvoke, isTrue);
    expect(extension.allowedCapabilityIds, {'rules', 'rules.tools'});
    expect(extension.allowedHostMethods, {'user_settings.get'});
    expect(extension.priority, 12);
  });

  test('retired reader slots remain parseable but are never registered', () {
    const retiredSlots = [
      'reader.toolbar_action',
      'reader.side_panel',
      'reader.document_viewer',
    ];
    for (final value in retiredSlots) {
      final slot = ClientExtensionSlot.fromValue(value);
      expect(slot, isNotNull);
      expect(slot!.rendersInClient, isFalse);
    }

    const registration = PluginCapabilityRegistration(
      pluginId: 'legacy-reader-ui',
      pluginName: 'Legacy Reader UI',
      capability: PluginCapability(
        id: 'legacy-page',
        kind: 'client_extension',
        extra: {'slots': retiredSlots},
      ),
    );

    final registry = buildClientExtensionRegistry([registration]);
    expect(registry.extensions, isEmpty);
    expect(registry.bySlot, isEmpty);
  });

  test('unknown explicit slots do not fall back to a global panel', () {
    const registration = PluginCapabilityRegistration(
      pluginId: 'unknown-slot',
      pluginName: 'Unknown Slot',
      capability: PluginCapability(
        id: 'unknown-page',
        kind: 'ui_extension',
        extra: {'slot': 'future.unknown_slot'},
      ),
    );

    final registry = buildClientExtensionRegistry([registration]);
    expect(registry.extensions, isEmpty);
  });

  test('plugin tool menu is enabled by default and honors saved values', () {
    final appState = AppState();
    addTearDown(appState.dispose);

    expect(appState.pluginToolMenuEnabled, isTrue);
    appState.settings = {
      'settings_json': {'plugin_tool_menu_enabled': '0'},
    };
    expect(appState.pluginToolMenuEnabled, isFalse);
  });

  test('Windows top-level plugin bridge exposes the tokenized facade', () {
    final script = buildPluginTopLevelSecureBridgeScript(
      noncePayload: '"test-nonce"',
      tokenPayload: '"test-token"',
    );

    expect(
      script,
      contains('Object.defineProperty(window, "__TING_PLUGIN_BRIDGE__"'),
    );
    expect(script, contains('value: secureBridge'));
    expect(script, contains('configurable: false'));
    expect(script, contains('writable: false'));
    expect(script, contains('bridge_nonce: bridgeNonce'));
    expect(script, contains('bridge_token: bridgeToken'));
    expect(script, contains('const bridgeNonce = "test-nonce"'));
    expect(script, contains('const bridgeToken = "test-token"'));
  });

  test('plugin asset URL validation includes the client grant segment', () {
    const assetUrl =
        'https://example.test/app/ting-reader/api/v1/plugin-assets/'
        'grant-123/ai-booklist-assistant/ui/assistant.html';

    expect(
      isPluginAssetUrlForTesting(
        'https://example.test/app/ting-reader/api/v1/plugin-assets/'
        'grant-123/ai-booklist-assistant/ui/assistant.js',
        assetUrl: assetUrl,
        pluginId: 'ai-booklist-assistant',
        clientGrant: 'grant-123',
      ),
      isTrue,
    );
    expect(
      isPluginAssetUrlForTesting(
        'https://example.test/app/ting-reader/api/v1/plugin-assets/'
        'other-grant/ai-booklist-assistant/ui/assistant.js',
        assetUrl: assetUrl,
        pluginId: 'ai-booklist-assistant',
        clientGrant: 'grant-123',
      ),
      isFalse,
    );
    expect(
      isPluginAssetUrlForTesting(
        'https://example.test/app/ting-reader/api/v1/plugin-assets/'
        'grant-123/other-plugin/ui/assistant.js',
        assetUrl: assetUrl,
        pluginId: 'ai-booklist-assistant',
        clientGrant: 'grant-123',
      ),
      isFalse,
    );
  });

  test('plugin top-level document installs bridge before plugin scripts', () {
    const assetUrl = 'https://example.test/api/v1/plugin-assets/grant-123/'
        'ai-booklist-assistant/ui/assistant.html';
    final html = buildPluginTopLevelDocumentForTesting(
      html: '<!doctype html><html><head><title>Assistant</title>'
          '<script src="./assistant.js"></script></head>'
          '<body>Ready</body></html>',
      assetUrl: assetUrl,
      initPayload: '{"type":"ting-plugin:init"}',
      theme: const {
        'colorScheme': 'light',
        'cssVariables': {'--bg': '#f8fafc'},
      },
      bridgeNonce: 'nonce-123',
      bridgeToken: 'token-123',
    );

    expect(html, contains('TingPluginLifecycle.postMessage(bridgeToken)'));
    expect(
      html,
      contains(
        '<base href="https://example.test/api/v1/plugin-assets/grant-123/'
        'ai-booklist-assistant/ui/">',
      ),
    );
    expect(html, contains('const bridgeToken = "token-123"'));
    expect(html, contains('<body>Ready</body>'));
    expect(html, isNot(contains('<iframe')));
    expect(
      html.indexOf('Object.defineProperty(window, "__TING_PLUGIN_BRIDGE__"'),
      lessThan(html.indexOf('./assistant.js')),
    );
  });

  test('bundles plugin stylesheets and scripts before loading the WebView',
      () async {
    const assetUrl = 'https://example.test/api/v1/plugin-assets/grant-123/'
        'ai-cover-generator/ui/cover.html';
    final requested = <String>[];
    final html = await bundlePluginTextAssetsForTesting(
      html: '<!doctype html><html><head>'
          '<link rel="stylesheet" href="./cover.css">'
          '</head><body><script src="./cover.js"></script></body></html>',
      assetUrl: assetUrl,
      loadAsset: (uri, kind) async {
        requested.add('$kind:$uri');
        return kind == 'stylesheet'
            ? 'body { color: rgb(1, 2, 3); }'
            : 'window.coverLoaded = 1 < 2; // </script>';
      },
    );

    expect(
      requested,
      [
        'stylesheet:https://example.test/api/v1/plugin-assets/grant-123/'
            'ai-cover-generator/ui/cover.css',
        'script:https://example.test/api/v1/plugin-assets/grant-123/'
            'ai-cover-generator/ui/cover.js',
      ],
    );
    expect(html, contains('body { color: rgb(1, 2, 3); }'));
    expect(html, contains('window.coverLoaded = 1 < 2;'));
    expect(html, contains(r'<\/script>'));
    expect(html, isNot(contains('href="./cover.css"')));
    expect(html, isNot(contains('src="./cover.js"')));
  });

  test('rejects plugin text assets outside the authorized package', () async {
    await expectLater(
      bundlePluginTextAssetsForTesting(
        html: '<html><head><script src="../../other/ui/pwn.js"></script>'
            '</head></html>',
        assetUrl: 'https://example.test/api/v1/plugin-assets/grant-123/'
            'demo/ui/index.html',
        loadAsset: (_, __) async => 'throw new Error("no");',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
