part of 'plugin_extension_host.dart';

class _PluginWebContainer extends StatefulWidget {
  const _PluginWebContainer({
    required this.extension,
    required this.extensionContext,
  });

  final ClientExtensionDescriptor extension;
  final Map<String, Object?> extensionContext;

  @override
  State<_PluginWebContainer> createState() => _PluginWebContainerState();
}

class _PluginWebContainerState extends State<_PluginWebContainer> {
  WebViewController? _controller;
  String? _error;
  bool _unsupported = false;
  bool _pageLoaded = false;
  bool _pluginDocumentReady = false;
  String? _appliedThemeSignature;
  int _loadGeneration = 0;
  Timer? _documentReadyTimer;
  bool _initialized = false;
  String _bridgeNonce = _newPluginBridgeNonce();
  String _bridgeToken = _newPluginBridgeNonce();
  final List<DateTime> _bridgeRequestTimes = [];

  @override
  void didUpdateWidget(covariant _PluginWebContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extension.id != widget.extension.id ||
        oldWidget.extension.clientGrant != widget.extension.clientGrant ||
        jsonEncode(oldWidget.extension.render) !=
            jsonEncode(widget.extension.render) ||
        jsonEncode(oldWidget.extensionContext) !=
            jsonEncode(widget.extensionContext)) {
      _initialize();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initialize();
      return;
    }
    _syncPluginTheme();
  }

  @override
  void dispose() {
    _documentReadyTimer?.cancel();
    super.dispose();
  }

  void _initialize() {
    final generation = ++_loadGeneration;
    _documentReadyTimer?.cancel();
    final bridgeNonce = _newPluginBridgeNonce();
    final bridgeToken = _newPluginBridgeNonce();
    _bridgeNonce = bridgeNonce;
    _bridgeToken = bridgeToken;
    _bridgeRequestTimes.clear();
    final entry = widget.extension.entry;
    if (entry == null) {
      setState(() {
        _controller = null;
        _error = _missingPluginUiEntryError;
        _unsupported = false;
      });
      return;
    }

    if (!_pluginWebViewSupported()) {
      setState(() {
        _controller = null;
        _error = null;
        _unsupported = true;
      });
      return;
    }

    final app = AppScope.appOf(context);
    final clientGrant = widget.extension.clientGrant;
    if (clientGrant == null || clientGrant.isEmpty) {
      setState(() {
        _controller = null;
        _error = 'Plugin UI authorization is unavailable.';
        _unsupported = false;
      });
      return;
    }
    final assetUrl = app.pluginCapabilities.pluginAssetUrl(
      pluginId: widget.extension.pluginId,
      clientGrant: clientGrant,
      entry: entry,
    );
    final loadAssetAsTopLevel = _pluginWebViewLoadsAssetAsTopLevel();
    final pluginTheme = _pluginThemePayload(context);
    final themeVariables = pluginTheme['cssVariables'];
    debugPrint(
      '[plugin-webview] theme scheme=${pluginTheme['colorScheme']} '
      'bg=${themeVariables is Map ? themeVariables['--bg'] : ''}',
    );
    final initPayload = _pluginInitPayloadJson(
      extension: widget.extension,
      extensionContext: widget.extensionContext,
      theme: pluginTheme,
      bridgeToken: bridgeToken,
    );
    _appliedThemeSignature = null;
    _pageLoaded = false;
    _pluginDocumentReady = false;

    final WebViewController controller;
    late final Future<void> controllerSetup;
    try {
      late final WebViewController nextController;
      nextController = defaultTargetPlatform == TargetPlatform.windows
          ? WebViewController.fromPlatformCreationParams(
              const WindowsWebViewControllerCreationParams(
                // The native WebView is an HWND overlay. A dialog rebuild can
                // temporarily deactivate its Flutter subtree; suspending the
                // browser in that interval leaves a blank native surface.
                suspendDuringDeactive: false,
              ),
            )
          : WebViewController();
      controllerSetup = nextController
          .setJavaScriptMode(JavaScriptMode.unrestricted)
          .then<void>((_) => nextController.setBackgroundColor(
                Color(themeVariables is Map
                    ? _parsePluginCssColor(themeVariables['--bg'])
                    : 0xfff8fafc),
              ))
          .then<void>(
            (_) => nextController.setNavigationDelegate(
              NavigationDelegate(
                onNavigationRequest: (request) {
                  // Allow the plugin document and its authenticated assets,
                  // including css/js, before applying the external-navigation
                  // policy.
                  if (_isPluginAssetUrl(
                    request.url,
                    assetUrl: assetUrl,
                    pluginId: widget.extension.pluginId,
                    clientGrant: clientGrant,
                  )) {
                    return NavigationDecision.navigate;
                  }
                  if (loadAssetAsTopLevel) {
                    // Subresources such as the plugin CSS/JS are not top-level
                    // navigations. Let the WebView fetch them under the same
                    // authenticated origin instead of applying the main-frame
                    // external-link policy to every request.
                    if (!request.isMainFrame) {
                      return NavigationDecision.navigate;
                    }
                    if (_isPluginAssetUrl(
                      request.url,
                      assetUrl: assetUrl,
                      pluginId: widget.extension.pluginId,
                      clientGrant: clientGrant,
                    )) {
                      return NavigationDecision.navigate;
                    }
                    _openPluginExternalUrl(request.url);
                    return NavigationDecision.prevent;
                  }
                  if (request.isMainFrame) {
                    if (_openPluginExternalUrl(request.url)) {
                      return NavigationDecision.prevent;
                    }
                    return NavigationDecision.navigate;
                  }
                  if (request.url == assetUrl ||
                      request.url.startsWith('$assetUrl#') ||
                      request.url.startsWith('$assetUrl?')) {
                    return NavigationDecision.navigate;
                  }
                  debugPrint(
                    '[plugin-webview] blocked untrusted subframe navigation',
                  );
                  return NavigationDecision.prevent;
                },
                onPageFinished: (url) {
                  if (loadAssetAsTopLevel &&
                      url.isNotEmpty &&
                      !_isPluginAssetUrl(
                        url,
                        assetUrl: assetUrl,
                        pluginId: widget.extension.pluginId,
                        clientGrant: clientGrant,
                      )) {
                    final parsedUrl = Uri.tryParse(url);
                    final safeUrl = parsedUrl == null
                        ? url
                        : parsedUrl.replace(query: '', fragment: '').toString();
                    debugPrint(
                      '[plugin-webview] rejected final document outside plugin asset: $safeUrl',
                    );
                    if (mounted) {
                      setState(() {
                        _error =
                            'Plugin UI redirected outside the authenticated asset';
                      });
                    }
                    return;
                  }
                  if (loadAssetAsTopLevel) {
                    unawaited(() async {
                      await _installTopLevelPluginBridge(
                        nextController,
                        initPayload: initPayload,
                        theme: pluginTheme,
                        assetUrl: assetUrl,
                        bridgeNonce: bridgeNonce,
                        bridgeToken: bridgeToken,
                      );
                      _appliedThemeSignature =
                          _pluginThemeSignature(pluginTheme);
                      await _probePluginDocument(
                        nextController,
                        url,
                      );
                    }());
                  } else {
                    unawaited(_probePluginDocument(nextController, url));
                  }
                  if (mounted && generation == _loadGeneration) {
                    setState(() => _pageLoaded = true);
                  }
                },
                onHttpError: (error) {
                  if (!mounted) return;
                  final statusCode = error.response?.statusCode;
                  setState(() {
                    _error = statusCode == null
                        ? 'Plugin UI request failed'
                        : 'Plugin UI request failed: HTTP $statusCode';
                  });
                },
                onWebResourceError: (error) {
                  if (!mounted || error.isForMainFrame != true) return;
                  setState(() => _error = error.description);
                },
              ),
            ),
          )
          .then<void>(
            (_) => nextController.addJavaScriptChannel(
              'TingPluginBridge',
              onMessageReceived: _handleBridgeMessage,
            ),
          )
          .then<void>(
            (_) => nextController.addJavaScriptChannel(
              'TingPluginLifecycle',
              onMessageReceived: (message) {
                if (message.message != bridgeToken ||
                    generation != _loadGeneration ||
                    !mounted) {
                  return;
                }
                _documentReadyTimer?.cancel();
                setState(() {
                  _pageLoaded = true;
                  _pluginDocumentReady = true;
                  _error = null;
                });
              },
            ),
          );
      controller = nextController;
    } catch (error) {
      setState(() {
        _controller = null;
        _error = ApiError.messageFor(error);
        _unsupported = false;
      });
      return;
    }

    setState(() {
      _controller = controller;
      _error = null;
      _unsupported = false;
      _pageLoaded = false;
      _pluginDocumentReady = false;
    });

    unawaited(
      _loadPluginWebView(
        controller: controller,
        assetUrl: assetUrl,
        app: app,
        loadAssetAsTopLevel: loadAssetAsTopLevel,
        initPayload: initPayload,
        theme: pluginTheme,
        bridgeNonce: bridgeNonce,
        bridgeToken: bridgeToken,
        generation: generation,
        setupFuture: controllerSetup,
      ),
    );
  }

  Future<void> _loadPluginWebView({
    required WebViewController controller,
    required String assetUrl,
    required AppState app,
    required bool loadAssetAsTopLevel,
    required String initPayload,
    required Map<String, Object?> theme,
    required String bridgeNonce,
    required String bridgeToken,
    required int generation,
    required Future<void> setupFuture,
  }) async {
    try {
      // WebView2 registers navigation callbacks and document-created scripts
      // asynchronously. Do not navigate until all three setup operations have
      // completed, otherwise the plugin can run before TingPluginBridge exists.
      await setupFuture;

      final assetUri = Uri.parse(assetUrl);
      await _writePluginCookiesToWebView(
        controller: controller,
        assetUri: assetUri,
        cookieHeader: app.api.cookie,
      );
      await _configurePluginSubresourceHeaders(
        controller: controller,
        assetUri: assetUri,
        headers: app.api.authHeaders,
      );

      if (loadAssetAsTopLevel) {
        await controller.loadRequest(
          assetUri,
          headers: app.api.authHeaders,
        );
      } else {
        final html = await _fetchPluginTextAsset(
          app: app,
          uri: assetUri,
          kind: _PluginTextAssetKind.document,
        );
        final safeUrl = assetUri.replace(query: '', fragment: '').toString();
        debugPrint(
          '[plugin-webview] fetched plugin html url=$safeUrl '
          'length=${html.length}',
        );
        if (_looksLikeTingReaderShell(html)) {
          throw StateError(
            'Plugin asset request returned the Ting Reader app shell',
          );
        }
        final bundledHtml = await _bundlePluginTextAssets(
          html: html,
          assetUri: assetUri,
          loadAsset: (uri, kind) => _fetchPluginTextAsset(
            app: app,
            uri: uri,
            kind: kind,
          ),
        );
        await controller.loadHtmlString(
          _pluginHtmlForSandbox(
            html: bundledHtml,
            assetUrl: assetUrl,
            initPayload: initPayload,
            theme: theme,
            bridgeNonce: bridgeNonce,
            bridgeToken: bridgeToken,
          ),
          baseUrl: app.api.baseUrl,
        );
        _documentReadyTimer = Timer(const Duration(seconds: 8), () {
          if (!mounted ||
              generation != _loadGeneration ||
              _pluginDocumentReady) {
            return;
          }
          setState(() {
            _error = context.localeText(
              '插件页面未能完成渲染，请重试。',
              'The plugin page did not finish rendering. Please try again.',
            );
          });
        });
      }
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = ApiError.messageFor(error));
    }
  }

  Future<void> _configurePluginSubresourceHeaders({
    required WebViewController controller,
    required Uri assetUri,
    required Map<String, String> headers,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    final platform = controller.platform;
    if (platform is! WindowsPlatformWebViewController) return;
    final configured = await platform.setRequestHeaders(
      assetUri,
      headers: headers,
    );
    if (!configured) {
      throw StateError(
        'Windows WebView2 failed to configure plugin resource headers',
      );
    }
  }

  Future<void> _writePluginCookiesToWebView({
    required WebViewController controller,
    required Uri assetUri,
    required String? cookieHeader,
  }) async {
    final rawCookie = cookieHeader?.trim() ?? '';
    if (rawCookie.isEmpty || assetUri.host.isEmpty) return;

    final windowsController = defaultTargetPlatform == TargetPlatform.windows &&
            controller.platform is WindowsPlatformWebViewController
        ? controller.platform as WindowsPlatformWebViewController
        : null;
    final cookieManager =
        windowsController == null ? WebViewCookieManager() : null;
    for (final pair in rawCookie.split(';')) {
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;

      final name = pair.substring(0, separator).trim();
      final value = pair.substring(separator + 1).trim();
      if (name.isEmpty) continue;

      final cookie = WebViewCookie(
        name: name,
        value: value,
        // fnOS may redirect through fnos.net while validating the relay
        // session. Use the parent domain so both the FNID host and fnos.net
        // receive the same gateway cookies, as they do in a browser.
        domain: FnosGateway.cookieDomainForHost(assetUri.host),
        path: '/',
      );
      if (windowsController != null) {
        final written = await windowsController.setCookie(cookie);
        if (!written) {
          throw StateError('Windows WebView2 failed to write plugin cookie');
        }
      } else {
        if (cookieManager == null) {
          throw StateError('WebView cookie manager is missing');
        }
        await cookieManager.setCookie(cookie);
      }
    }
  }

  void _syncPluginTheme() {
    final controller = _controller;
    if (controller == null || !_pageLoaded || _unsupported || _error != null) {
      return;
    }
    final pluginTheme = _pluginThemePayload(context);
    final signature = _pluginThemeSignature(pluginTheme);
    if (signature == _appliedThemeSignature) return;
    _appliedThemeSignature = signature;
    controller.runJavaScript(_pluginThemeApplicationScript(pluginTheme));
  }

  bool _acceptBridgeMessage(String raw) {
    if (raw.length > 256 * 1024) return false;
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 10));
    _bridgeRequestTimes.removeWhere((timestamp) => timestamp.isBefore(cutoff));
    if (_bridgeRequestTimes.length >= 100) return false;
    _bridgeRequestTimes.add(now);
    return true;
  }

  Future<void> _handleBridgeMessage(JavaScriptMessage message) async {
    if (!_acceptBridgeMessage(message.message)) {
      debugPrint(
          '[plugin-webview] rejected oversized or rate-limited bridge message');
      return;
    }

    final externalUrl = _decodeExternalUrlRequest(
      message.message,
      expectedNonce: _bridgeNonce,
      expectedBridgeToken: _bridgeToken,
    );
    if (externalUrl != null) {
      _openPluginExternalUrl(externalUrl);
      return;
    }

    final request = _decodeBridgeRequest(
      message.message,
      expectedNonce: _bridgeNonce,
      expectedBridgeToken: _bridgeToken,
    );
    if (request == null) return;

    debugPrint(
      '[plugin-webview] bridge request method=${request.method}',
    );

    try {
      final result = await _invokeBridgeRequest(request);
      await _postBridgeResponse(request, ok: true, result: result);
      debugPrint(
        '[plugin-webview] bridge response method=${request.method} ok=1',
      );
    } catch (error) {
      await _postBridgeResponse(
        request,
        ok: false,
        error: ApiError.capture(error),
      );
      debugPrint(
        '[plugin-webview] bridge response method=${request.method} ok=0',
      );
    }
  }

  Future<void> _probePluginDocument(
    WebViewController controller,
    String url,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    final parsed = Uri.tryParse(url);
    final safeUrl = parsed == null
        ? url
        : parsed.replace(query: '', fragment: '').toString();
    try {
      final result = await controller.runJavaScriptReturningResult('''
JSON.stringify({
  readyState: document.readyState,
  title: document.title,
  href: location.href,
  bodyLength: document.body ? document.body.innerHTML.length : -1,
  scriptCount: document.scripts.length,
  styleCount: document.styleSheets.length,
  appText: document.body ? document.body.innerText.slice(0, 80) : ""
})
''');
      debugPrint('[plugin-webview] DOM probe url=$safeUrl result=$result');
    } catch (error) {
      debugPrint('[plugin-webview] DOM probe failed url=$safeUrl');
    }
  }

  Future<Object?> _invokeBridgeRequest(_PluginBridgeRequest request) {
    final pluginCapabilities = AppScope.appOf(context).pluginCapabilities;
    switch (request.method) {
      case 'capability.invoke':
        if (!widget.extension.allowsCapabilityInvoke) {
          throw ApiError.local(
            code: 'PermissionDenied',
            message: 'Capability invocation is disabled for this view',
            reason: 'capability_denied',
            operation: request.method,
            status: 403,
          );
        }
        final params = request.params is Map
            ? Map<String, dynamic>.from(request.params as Map)
            : const <String, dynamic>{};
        final declaredCapabilityId = params['capabilityId']?.toString().trim();
        final capabilityId =
            declaredCapabilityId == null || declaredCapabilityId.isEmpty
                ? widget.extension.capability.id
                : declaredCapabilityId;
        if (!widget.extension.allowedCapabilityIds.contains(capabilityId)) {
          throw ApiError.local(
            code: 'PermissionDenied',
            message: 'Capability is not allowed for this view',
            reason: 'capability_denied',
            operation: request.method,
            status: 403,
          );
        }
        return pluginCapabilities.invokePluginCapability<Object?>(
          pluginId: widget.extension.pluginId,
          capabilityId: capabilityId,
          uiCapabilityId: widget.extension.capability.id,
          uiGrant: widget.extension.clientGrant,
          params: params['params'] ?? const {},
        );
      case 'host.invoke':
        final params = request.params is Map
            ? Map<String, dynamic>.from(request.params as Map)
            : const <String, dynamic>{};
        final method = params['method']?.toString();
        if (method == null || method.trim().isEmpty) {
          throw ApiError.local(
            code: 'InvalidRequest',
            message: 'Missing host method',
            reason: 'missing_field',
            operation: request.method,
            status: 400,
          );
        }
        if (!widget.extension.allowedHostMethods.contains(method)) {
          throw ApiError.local(
            code: 'PermissionDenied',
            message: 'Host method is not allowed for this view',
            reason: 'capability_denied',
            operation: request.method,
            status: 403,
          );
        }
        return pluginCapabilities.invokePluginHost<Object?>(
          pluginId: widget.extension.pluginId,
          uiCapabilityId: widget.extension.capability.id,
          uiGrant: widget.extension.clientGrant ?? '',
          method: method,
          params: params['params'] ?? const {},
        );
      default:
        throw ApiError.local(
          code: 'InvalidRequest',
          message: 'Unknown bridge method: ${request.method}',
          reason: 'unsupported_value',
          operation: request.method,
          status: 400,
        );
    }
  }

  Future<void> _postBridgeResponse(
    _PluginBridgeRequest request, {
    required bool ok,
    Object? result,
    ApiError? error,
  }) async {
    final controller = _controller;
    if (controller == null) return;

    final payload = jsonEncode({
      'type': 'ting-plugin:response',
      'id': request.id,
      'bridge_token': request.bridgeToken,
      'ok': ok,
      if (ok) 'result': result,
      if (!ok) 'error': error?.toJson(),
    });
    await controller.runJavaScript('window.__tingPluginRespond($payload);');
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_unsupported) {
      return _PluginUnsupportedBody(
        title: context.localeText('WebView 不可用', 'WebView unavailable'),
        message: context.localeText(
          '当前平台暂不支持插件 Web UI。',
          'Plugin Web UI is not supported on this platform yet.',
        ),
      );
    }
    if (_error case final errorText?) {
      return _PluginUnsupportedBody(
        title: context.localeText('Web UI 加载失败', 'Web UI failed'),
        message: errorText == _missingPluginUiEntryError
            ? context.localeText('缺少插件 UI 入口。', 'Missing plugin UI entry.')
            : errorText,
      );
    }
    if (controller == null) {
      return _PluginUnsupportedBody(
        title: context.localeText('Web UI 待接入', 'Web UI pending'),
        message: widget.extension.capability.id,
      );
    }

    if (!_pageLoaded || !_pluginDocumentReady) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: WebViewWidget(controller: controller),
    );
  }
}

bool _pluginWebViewLoadsAssetAsTopLevel() {
  // Fetch through the authenticated API, then load the hardened HTML string as
  // the WebView document. Navigating to the asset URL can return the fnOS SPA
  // shell instead of the plugin asset.
  return false;
}

bool _pluginWebViewSupported() {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
}

bool _openPluginExternalUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  final scheme = uri?.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  openExternalUrl(rawUrl);
  return true;
}
