part of 'plugin_extension_host.dart';

class _PluginBridgeRequest {
  const _PluginBridgeRequest({
    required this.id,
    required this.method,
    required this.bridgeToken,
    this.params,
  });

  final String id;
  final String method;
  final String bridgeToken;
  final Object? params;
}

String _newPluginBridgeNonce() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64UrlEncode(bytes);
}

_PluginBridgeRequest? _decodeBridgeRequest(
  String raw, {
  required String expectedNonce,
  required String expectedBridgeToken,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  if (decoded['type'] != 'ting-plugin:request') return null;
  if (decoded['bridge_nonce'] != expectedNonce) return null;
  if (decoded['bridge_token'] != expectedBridgeToken) return null;
  final id = decoded['id']?.toString();
  final method = decoded['method']?.toString();
  if (id == null ||
      id.isEmpty ||
      id.length > 128 ||
      method == null ||
      method.isEmpty ||
      method.length > 64) {
    return null;
  }
  return _PluginBridgeRequest(
    id: id,
    method: method,
    bridgeToken: expectedBridgeToken,
    params: decoded['params'],
  );
}

String? _decodeExternalUrlRequest(
  String raw, {
  required String expectedNonce,
  required String expectedBridgeToken,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  if (decoded['type'] != 'ting-plugin:external-url') return null;
  if (decoded['bridge_nonce'] != expectedNonce) return null;
  if (decoded['bridge_token'] != expectedBridgeToken) return null;
  final url = decoded['url']?.toString().trim();
  return url == null || url.isEmpty ? null : url;
}

Future<void> _installTopLevelPluginBridge(
  WebViewController controller, {
  required String initPayload,
  required Map<String, Object?> theme,
  required String assetUrl,
  required String bridgeNonce,
  required String bridgeToken,
}) async {
  final themeScript = _pluginThemeApplicationScript(theme);
  final assetUrlPayload = jsonEncode(assetUrl);
  final noncePayload = jsonEncode(bridgeNonce);
  final tokenPayload = jsonEncode(bridgeToken);
  final secureBridgeScript = buildPluginTopLevelSecureBridgeScript(
    noncePayload: noncePayload,
    tokenPayload: tokenPayload,
  );
  final safeInitPayload = initPayload.replaceAll('<', r'\u003C');
  await controller.runJavaScript('''
(function() {
  $themeScript
  if (window.__tingPluginBridgeInstalled) {
    window.postMessage($safeInitPayload, "*");
    return;
  }
  window.__tingPluginBridgeInstalled = true;
  $secureBridgeScript
  window.__tingPluginRespond = function(response) {
    if (!response || response.bridge_token !== bridgeToken) return;
    window.postMessage(response, "*");
  };
  const pluginAssetUrl = $assetUrlPayload;
  function absolutePluginUrl(url) {
    try {
      return new URL(url, document.baseURI || window.location.href).href;
    } catch (_) {
      return "";
    }
  }
  function shouldOpenExternally(url) {
    const absoluteUrl = absolutePluginUrl(url);
    if (!absoluteUrl) return false;
    try {
      const parsed = new URL(absoluteUrl);
      if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return false;
      return absoluteUrl !== pluginAssetUrl &&
        !absoluteUrl.startsWith(pluginAssetUrl + "#") &&
        !absoluteUrl.startsWith(pluginAssetUrl + "?");
    } catch (_) {
      return false;
    }
  }
  function openExternal(url) {
    const absoluteUrl = absolutePluginUrl(url);
    if (!absoluteUrl) return false;
    TingPluginBridge.postMessage(JSON.stringify({
      type: "ting-plugin:external-url",
      url: absoluteUrl,
      bridge_nonce: bridgeNonce,
      bridge_token: bridgeToken
    }));
    return true;
  }
  const originalWindowOpen = window.open;
  window.open = function(url, target, features) {
    if (url && shouldOpenExternally(url)) {
      const activation = navigator.userActivation;
      if (!activation || activation.isActive) openExternal(url);
      return null;
    }
    return originalWindowOpen
      ? originalWindowOpen.call(window, url, target, features)
      : null;
  };
  document.addEventListener("click", function(event) {
    if (!event.isTrusted) return;
    const target = event.target;
    const anchor = target && target.closest ? target.closest("a[href]") : null;
    if (!anchor || !shouldOpenExternally(anchor.href)) return;
    event.preventDefault();
    event.stopPropagation();
    openExternal(anchor.href);
  }, true);
  window.addEventListener("message", function(event) {
    if (event.source !== window) return;
    const data = event.data;
    if (!data || data.type !== "ting-plugin:request" || !data.id) return;
    postBridgeMessage(data);
  });
  window.postMessage($safeInitPayload, "*");
})();
''');
}

@visibleForTesting
String buildPluginTopLevelSecureBridgeScript({
  required String noncePayload,
  required String tokenPayload,
}) {
  return '''
  const bridgeToken = $tokenPayload;
  const bridgeNonce = $noncePayload;
  function postBridgeMessage(message) {
    TingPluginBridge.postMessage(JSON.stringify(Object.assign({}, message, {
      bridge_nonce: bridgeNonce,
      bridge_token: bridgeToken
    })));
  }
  const secureBridge = Object.freeze({
    postMessage: function(message) {
      if (!message || typeof message !== "object" ||
          message.type !== "ting-plugin:request") return;
      postBridgeMessage(message);
    }
  });
  Object.defineProperty(window, "__TING_PLUGIN_BRIDGE__", {
    value: secureBridge,
    configurable: false,
    enumerable: false,
    writable: false
  });
''';
}

bool _isPluginAssetUrl(
  String url, {
  required String assetUrl,
  required String pluginId,
  required String clientGrant,
}) {
  final uri = Uri.tryParse(url);
  final assetUri = Uri.tryParse(assetUrl);
  if (uri == null || assetUri == null) return false;
  if (uri.scheme != assetUri.scheme ||
      uri.host != assetUri.host ||
      uri.port != assetUri.port) {
    return false;
  }

  // The gateway adds a path prefix such as /app/ting-reader before the API
  // path. Anchor the check to the actual asset URL instead of assuming that
  // /api/v1 is at the origin root.
  final assetSegments = assetUri.pathSegments;
  final requestSegments = uri.pathSegments;
  final pluginAssetsIndex = assetSegments.indexOf('plugin-assets');
  if (pluginAssetsIndex < 0 ||
      pluginAssetsIndex + 2 >= assetSegments.length ||
      requestSegments.length <= pluginAssetsIndex + 2) {
    return false;
  }
  for (var index = 0; index <= pluginAssetsIndex; index++) {
    if (requestSegments[index] != assetSegments[index]) return false;
  }

  final grantSegment = requestSegments[pluginAssetsIndex + 1];
  final pluginSegment = requestSegments[pluginAssetsIndex + 2];
  return grantSegment == clientGrant &&
      (pluginSegment == pluginId ||
          pluginSegment == Uri.encodeComponent(pluginId));
}

@visibleForTesting
bool isPluginAssetUrlForTesting(
  String url, {
  required String assetUrl,
  required String pluginId,
  required String clientGrant,
}) {
  return _isPluginAssetUrl(
    url,
    assetUrl: assetUrl,
    pluginId: pluginId,
    clientGrant: clientGrant,
  );
}

int _parsePluginCssColor(Object? value) {
  final raw = value?.toString().trim() ?? '';
  final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(raw);
  if (match == null) return 0xfff8fafc;
  return 0xff000000 | int.parse(match.group(1)!, radix: 16);
}

String _pluginInitPayloadJson({
  required ClientExtensionDescriptor extension,
  required Map<String, Object?> extensionContext,
  required Map<String, Object?> theme,
  required String bridgeToken,
}) {
  return jsonEncode({
    'type': 'ting-plugin:init',
    'pluginId': extension.pluginId,
    'pluginName': extension.pluginName,
    'capabilityId': extension.capability.id,
    'slot': extension.slot.value,
    'contexts': extension.contexts,
    'context': extensionContext,
    'theme': theme,
    'bridgeToken': bridgeToken,
  });
}

Map<String, Object?> _pluginThemePayload(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.brightness == Brightness.dark ? 'dark' : 'light';
  final cssVariables = colorScheme == 'dark'
      ? const {
          '--bg': '#020617',
          '--panel': '#0f172a',
          '--text': '#f8fafc',
          '--muted': '#cbd5e1',
          '--line': '#1e293b',
          '--accent': '#7dd3fc',
          '--soft': '#082f49',
          '--danger': '#fca5a5',
        }
      : const {
          '--bg': '#f8fafc',
          '--panel': '#ffffff',
          '--text': '#0f172a',
          '--muted': '#475569',
          '--line': '#e2e8f0',
          '--accent': '#0284c7',
          '--soft': '#f0f9ff',
          '--danger': '#dc2626',
        };
  return {
    'colorScheme': colorScheme,
    'brightness': colorScheme,
    'cssVariables': cssVariables,
  };
}

String _pluginThemeSignature(Map<String, Object?> theme) => jsonEncode(theme);

enum _PluginTextAssetKind { document, stylesheet, script }

extension on _PluginTextAssetKind {
  String get label => switch (this) {
        _PluginTextAssetKind.document => 'document',
        _PluginTextAssetKind.stylesheet => 'stylesheet',
        _PluginTextAssetKind.script => 'script',
      };

  String get accept => switch (this) {
        _PluginTextAssetKind.document => 'text/html,application/xhtml+xml',
        _PluginTextAssetKind.stylesheet => 'text/css',
        _PluginTextAssetKind.script =>
          'text/javascript,application/javascript,application/ecmascript',
      };

  bool acceptsContentType(String contentType) => switch (this) {
        _PluginTextAssetKind.document => contentType.contains('text/html') ||
            contentType.contains('application/xhtml+xml'),
        _PluginTextAssetKind.stylesheet => contentType.contains('text/css'),
        _PluginTextAssetKind.script => contentType.contains('javascript') ||
            contentType.contains('ecmascript'),
      };
}

Future<String> _fetchPluginTextAsset({
  required AppState app,
  required Uri uri,
  required _PluginTextAssetKind kind,
}) async {
  final response = await app.api.getTextUri(uri, accept: kind.accept);
  final contentType =
      response.headers.value('content-type')?.toLowerCase() ?? '';
  if (!kind.acceptsContentType(contentType)) {
    throw StateError(
      'Plugin ${kind.label} returned an invalid content type '
      '(${contentType.isEmpty ? 'missing' : contentType})',
    );
  }

  final responseData = response.data;
  final bytes = responseData is List<int>
      ? responseData
      : utf8.encode(responseData?.toString() ?? '');
  final limit = kind == _PluginTextAssetKind.document
      ? _maxPluginDocumentBytes
      : _maxPluginTextAssetBytes;
  if (bytes.length > limit) {
    throw StateError('Plugin ${kind.label} exceeds the size limit');
  }
  return utf8.decode(bytes, allowMalformed: false);
}

typedef _PluginTextAssetLoader = Future<String> Function(
  Uri uri,
  _PluginTextAssetKind kind,
);

Future<String> _bundlePluginTextAssets({
  required String html,
  required Uri assetUri,
  required _PluginTextAssetLoader loadAsset,
}) async {
  final document = html_parser.parse(html);
  var bundledBytes = utf8.encode(html).length;

  void reserveBytes(String source) {
    bundledBytes += utf8.encode(source).length;
    if (bundledBytes > _maxBundledPluginBytes) {
      throw StateError('Plugin UI exceeds the bundled asset size limit');
    }
  }

  final stylesheets = document.querySelectorAll('link[href]').where((link) {
    final rel = link.attributes['rel']?.toLowerCase().split(RegExp(r'\s+')) ??
        const <String>[];
    return rel.contains('stylesheet');
  }).toList(growable: false);
  for (final stylesheet in stylesheets) {
    final href = stylesheet.attributes['href']?.trim() ?? '';
    final uri = _resolvePluginTextAssetUri(assetUri, href);
    final source = await loadAsset(uri, _PluginTextAssetKind.stylesheet);
    if (RegExp(r'@import\b|url\s*\(', caseSensitive: false).hasMatch(source)) {
      throw StateError(
        'Plugin stylesheet contains a resource that cannot be bundled',
      );
    }
    reserveBytes(source);
    final replacement = html_dom.Element.tag('style')
      ..attributes['data-ting-bundled-asset'] = uri.toString()
      ..text = source;
    stylesheet.replaceWith(replacement);
  }

  final scripts =
      document.querySelectorAll('script[src]').toList(growable: false);
  for (final script in scripts) {
    if ((script.attributes['type'] ?? '').trim().toLowerCase() == 'module') {
      throw StateError('Plugin module scripts are not supported');
    }
    final src = script.attributes['src']?.trim() ?? '';
    final uri = _resolvePluginTextAssetUri(assetUri, src);
    final source = await loadAsset(uri, _PluginTextAssetKind.script);
    reserveBytes(source);
    final replacement = html_dom.Element.tag('script');
    for (final attribute in script.attributes.entries) {
      final attributeName = attribute.key.toString();
      if (const {'src', 'crossorigin', 'integrity', 'nonce'}
          .contains(attributeName.toLowerCase())) {
        continue;
      }
      replacement.attributes[attributeName] = attribute.value;
    }
    replacement.attributes['data-ting-bundled-asset'] = uri.toString();
    replacement.nodes.add(
      html_dom.Text(
        source.replaceAll(
          RegExp(r'</script', caseSensitive: false),
          r'<\/script',
        ),
      ),
    );
    script.replaceWith(replacement);
  }

  return document.outerHtml;
}

Uri _resolvePluginTextAssetUri(Uri documentUri, String reference) {
  if (reference.isEmpty) {
    throw StateError('Plugin asset reference is empty');
  }
  final resolved = documentUri.resolve(reference);
  final identity = _pluginAssetIdentity(documentUri);
  if (!_isPluginAssetUrl(
    resolved.toString(),
    assetUrl: documentUri.toString(),
    pluginId: identity.pluginId,
    clientGrant: identity.clientGrant,
  )) {
    throw StateError('Plugin asset is outside the authorized package');
  }
  return resolved;
}

({String clientGrant, String pluginId}) _pluginAssetIdentity(Uri uri) {
  final segments = uri.pathSegments;
  final index = segments.indexOf('plugin-assets');
  if (index < 0 || index + 2 >= segments.length) {
    throw StateError('Plugin asset URL is invalid');
  }
  return (
    clientGrant: segments[index + 1],
    pluginId: segments[index + 2],
  );
}

@visibleForTesting
Future<String> bundlePluginTextAssetsForTesting({
  required String html,
  required String assetUrl,
  required Future<String> Function(Uri uri, String kind) loadAsset,
}) {
  return _bundlePluginTextAssets(
    html: html,
    assetUri: Uri.parse(assetUrl),
    loadAsset: (uri, kind) => loadAsset(uri, kind.label),
  );
}

String _pluginHtmlForSandbox({
  required String html,
  required String assetUrl,
  required String initPayload,
  required Map<String, Object?> theme,
  required String bridgeNonce,
  required String bridgeToken,
}) {
  final origin = Uri.parse(assetUrl).origin;
  final policy = [
    "default-src 'none'",
    "script-src 'unsafe-inline' $origin",
    "style-src 'unsafe-inline' $origin",
    "font-src data: $origin",
    'img-src data: blob: $origin',
    'media-src data: blob: $origin',
    "connect-src 'none'",
    "object-src 'none'",
    "frame-src 'none'",
    "worker-src 'none'",
    "form-action 'none'",
    'base-uri $origin',
  ].join('; ');
  final bootstrap = _pluginTopLevelBootstrapScript(
    initPayload: initPayload,
    theme: theme,
    assetUrl: assetUrl,
    bridgeNonce: bridgeNonce,
    bridgeToken: bridgeToken,
  );
  const attributeEscape = HtmlEscape(HtmlEscapeMode.attribute);
  final injectedHead = '''
<meta http-equiv="Content-Security-Policy" content="${attributeEscape.convert(policy)}">
<base href="${attributeEscape.convert(Uri.parse(assetUrl).resolve('.').toString())}">
<script>$bootstrap</script>
''';
  final document = html
      .replaceAll(RegExp(r'<base\b[^>]*>', caseSensitive: false), '')
      .replaceAll(
        RegExp(
          r'''<meta\b(?=[^>]*\bhttp-equiv\s*=\s*["']?\s*content-security-policy\b)[^>]*>''',
          caseSensitive: false,
        ),
        '',
      );
  final head =
      RegExp(r'<head\b[^>]*>', caseSensitive: false).firstMatch(document);
  if (head != null) {
    return document.replaceRange(head.end, head.end, injectedHead);
  }
  final htmlTag =
      RegExp(r'<html\b[^>]*>', caseSensitive: false).firstMatch(document);
  if (htmlTag != null) {
    return document.replaceRange(
      htmlTag.end,
      htmlTag.end,
      '<head>$injectedHead</head>',
    );
  }
  return '<!doctype html><html><head>$injectedHead</head><body>'
      '$document</body></html>';
}

String _pluginTopLevelBootstrapScript({
  required String initPayload,
  required Map<String, Object?> theme,
  required String assetUrl,
  required String bridgeNonce,
  required String bridgeToken,
}) {
  final assetPayload = jsonEncode(assetUrl).replaceAll('<', r'\u003C');
  final themePayload = jsonEncode(theme).replaceAll('<', r'\u003C');
  final noncePayload = jsonEncode(bridgeNonce);
  final tokenPayload = jsonEncode(bridgeToken);
  final safeInitPayload = initPayload.replaceAll('<', r'\u003C');
  final secureBridgeScript = buildPluginTopLevelSecureBridgeScript(
    noncePayload: noncePayload,
    tokenPayload: tokenPayload,
  );
  return '''
(function() {
  if (window.__tingPluginBridgeInstalled) return;
  Object.defineProperty(window, "__tingPluginBridgeInstalled", {
    value: true, configurable: false, enumerable: false, writable: false
  });
  const assetUrl = $assetPayload;
  const initialTheme = $themePayload;
  $secureBridgeScript
  const scheduleTask = window.setTimeout.bind(window);
  const bootstrapScript = document.currentScript;
  if (bootstrapScript) bootstrapScript.remove();
  let externalNavigationPermit = false;
  let permitGeneration = 0;

  function applyTheme(theme) {
    const rawScheme = String(theme && (theme.colorScheme || theme.brightness) || "light").toLowerCase();
    const colorScheme = rawScheme.indexOf("dark") >= 0 ? "dark" : "light";
    const root = document.documentElement;
    const vars = theme && theme.cssVariables || {};
    root.style.setProperty("color-scheme", colorScheme, "important");
    root.dataset.tingTheme = colorScheme;
    root.dataset.theme = colorScheme;
    root.classList.toggle("dark", colorScheme === "dark");
    root.classList.toggle("light", colorScheme === "light");
    Object.keys(vars).forEach(function(key) {
      root.style.setProperty(key, String(vars[key]), "important");
    });
    if (document.body) {
      if (vars["--bg"]) document.body.style.setProperty("background-color", String(vars["--bg"]), "important");
      if (vars["--text"]) document.body.style.setProperty("color", String(vars["--text"]), "important");
    }
    let style = document.getElementById("ting-plugin-host-style");
    if (!style) {
      style = document.createElement("style");
      style.id = "ting-plugin-host-style";
      (document.head || root).appendChild(style);
    }
    const thumb = colorScheme === "dark"
      ? "rgba(148, 163, 184, 0.48)"
      : "rgba(100, 116, 139, 0.34)";
    style.textContent =
      "html, body, .generate-panel, .saved-panel { scrollbar-width: thin; scrollbar-color: " + thumb + " transparent; }" +
      "html::-webkit-scrollbar, body::-webkit-scrollbar, .generate-panel::-webkit-scrollbar, .saved-panel::-webkit-scrollbar { width: 8px; height: 8px; }" +
      "html::-webkit-scrollbar-track, body::-webkit-scrollbar-track, .generate-panel::-webkit-scrollbar-track, .saved-panel::-webkit-scrollbar-track { background: transparent; }" +
      "html::-webkit-scrollbar-thumb, body::-webkit-scrollbar-thumb, .generate-panel::-webkit-scrollbar-thumb, .saved-panel::-webkit-scrollbar-thumb { background: " + thumb + "; border: 2px solid transparent; border-radius: 999px; background-clip: padding-box; }";
    window.__tingPluginTheme = theme;
  }
  Object.defineProperty(window, "__tingPluginApplyTheme", {
    value: applyTheme, configurable: false, enumerable: false, writable: false
  });
  Object.defineProperty(window, "__tingPluginRespond", {
    value: function(response) {
      if (!response || response.bridge_token !== bridgeToken) return;
      window.postMessage(response, "*");
    },
    configurable: false, enumerable: false, writable: false
  });

  function absolutePluginUrl(url) {
    try { return new URL(url, assetUrl).href; } catch (_) { return ""; }
  }

  function shouldOpenExternally(url) {
    const absoluteUrl = absolutePluginUrl(url);
    if (!absoluteUrl) return false;
    try {
      const parsed = new URL(absoluteUrl);
      if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return false;
      return absoluteUrl !== assetUrl &&
        !absoluteUrl.startsWith(assetUrl + "#") &&
        !absoluteUrl.startsWith(assetUrl + "?");
    } catch (_) {
      return false;
    }
  }

  function openExternal(url) {
    if (!externalNavigationPermit) return;
    externalNavigationPermit = false;
    const absoluteUrl = absolutePluginUrl(url);
    if (!absoluteUrl || !shouldOpenExternally(absoluteUrl)) return;
    postBridgeMessage({
      type: "ting-plugin:external-url",
      url: absoluteUrl
    });
  }

  const originalWindowOpen = window.open;
  window.open = function(url, target, features) {
    if (url && shouldOpenExternally(url)) {
      openExternal(url);
      return null;
    }
    return originalWindowOpen
      ? originalWindowOpen.call(window, url, target, features)
      : null;
  };
  window.addEventListener("click", function(event) {
    if (event.isTrusted) {
      const generation = ++permitGeneration;
      externalNavigationPermit = true;
      queueMicrotask(function() {
        if (permitGeneration === generation) externalNavigationPermit = false;
      });
    }
    const target = event.target;
    const anchor = target && target.closest ? target.closest("a[href]") : null;
    if (!anchor || !shouldOpenExternally(anchor.href)) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    openExternal(anchor.href);
  }, { capture: true });
  window.addEventListener("message", function(event) {
    if (event.source !== window) return;
    const data = event.data;
    if (!data || data.type !== "ting-plugin:request" || !data.id) return;
    postBridgeMessage(data);
  });
  function finishBootstrap() {
    applyTheme(initialTheme);
    window.postMessage($safeInitPayload, "*");
    TingPluginLifecycle.postMessage(bridgeToken);
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function() {
      scheduleTask(finishBootstrap, 0);
    }, { capture: true, once: true });
  } else {
    scheduleTask(finishBootstrap, 0);
  }
})();
''';
}

bool _looksLikeTingReaderShell(String html) {
  final hasAppTitle = RegExp(
    r'<title[^>]*>\s*Ting Reader\b',
    caseSensitive: false,
  ).hasMatch(html);
  final normalized = html.toLowerCase();
  final hasRoot =
      normalized.contains('id="root"') || normalized.contains("id='root'");
  return hasAppTitle && hasRoot;
}

String _pluginThemeApplicationScript(Map<String, Object?> theme) {
  final themePayload = jsonEncode(theme);
  return '''
(function() {
  const theme = $themePayload;
  const rawScheme = String(theme.colorScheme || theme.brightness || "light").toLowerCase();
  const colorScheme = rawScheme.indexOf("dark") >= 0 ? "dark" : "light";
  const root = document.documentElement;
  const vars = theme.cssVariables || {};
  root.style.setProperty("color-scheme", colorScheme, "important");
  root.dataset.tingTheme = colorScheme;
  root.dataset.theme = colorScheme;
  root.classList.toggle("dark", colorScheme === "dark");
  root.classList.toggle("light", colorScheme === "light");
  Object.keys(vars).forEach(function(key) {
    root.style.setProperty(key, String(vars[key]), "important");
  });
  let meta = document.querySelector('meta[name="color-scheme"]');
  if (!meta) {
    meta = document.createElement("meta");
    meta.setAttribute("name", "color-scheme");
    document.head && document.head.appendChild(meta);
  }
  meta.setAttribute("content", colorScheme);
  if (document.body) {
    if (vars["--bg"]) document.body.style.setProperty("background-color", String(vars["--bg"]), "important");
    if (vars["--text"]) document.body.style.setProperty("color", String(vars["--text"]), "important");
  }
  if (typeof window.__tingPluginApplyTheme === "function") {
    window.__tingPluginApplyTheme(theme);
  }
  window.__tingPluginTheme = theme;
  window.postMessage({ type: "ting-plugin:theme", theme: theme }, "*");
})();
''';
}

@visibleForTesting
String buildPluginTopLevelDocumentForTesting({
  required String html,
  required String assetUrl,
  required String initPayload,
  required Map<String, Object?> theme,
  required String bridgeNonce,
  required String bridgeToken,
}) {
  return _pluginHtmlForSandbox(
    html: html,
    assetUrl: assetUrl,
    initPayload: initPayload,
    theme: theme,
    bridgeNonce: bridgeNonce,
    bridgeToken: bridgeToken,
  );
}
