import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

const _tingReaderPath = '/app/ting-reader';

/// Utilities for the fnOS/FN Connect gateway address used by a server profile.
class FnosGateway {
  const FnosGateway._();

  static String hostForFnId(String rawFnId) {
    var value = rawFnId.trim();
    if (value.isEmpty) {
      throw const FormatException('Missing fnOS ID');
    }

    final parsed = Uri.tryParse(
      value.contains('://') ? value : 'https://$value',
    );
    if (parsed != null && parsed.host.isNotEmpty) {
      value = parsed.host;
    } else {
      value = value.split('/').first;
    }

    value = value.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (!value.endsWith('.fnos.net')) {
      value = '$value.fnos.net';
    }
    return value;
  }

  static Uri originUri(String fnId) {
    return Uri.https(hostForFnId(fnId), '/');
  }

  static Uri fnidLoginUri(String fnId) {
    final host = hostForFnId(fnId);
    final id = host.substring(0, host.length - '.fnos.net'.length);
    return Uri.https('fnos.net', '/$id');
  }

  static Uri fnosValidationUri() {
    return Uri.https('fnos.net', '/');
  }

  static Uri appUri(String fnId) {
    return Uri.https(hostForFnId(fnId), '/app/ting-reader');
  }

  static String cookieHeader(Iterable<WebViewCookie> cookies) {
    return _filterCookiePairs(
      cookies.map((cookie) => '${cookie.name}=${cookie.value}'),
    );
  }

  static String cookieHeaderFromDocumentCookie(String rawCookie) {
    var value = rawCookie.trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is String) value = decoded;
      } catch (_) {
        value = value.substring(1, value.length - 1);
      }
    }
    return _filterCookiePairs(value.split(';'));
  }

  static String mergeCookieHeaders(String primary, String secondary) {
    return _filterCookiePairs([
      ...primary.split(';'),
      ...secondary.split(';'),
    ]);
  }

  static bool hasGatewaySession(String cookieHeader) {
    final names = cookieHeader
        .split(';')
        .map((part) => part.trim().split('=').first.toLowerCase())
        .toSet();
    return names.contains('fnos-token') && names.contains('entry-token');
  }

  static String _filterCookiePairs(Iterable<String> pairs) {
    const acceptedNames = {
      'mode',
      'language',
      'fnos-token',
      'entry-token',
    };
    final values = <String, String>{};
    for (final pair in pairs) {
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator).trim();
      final value = pair.substring(separator + 1).trim();
      if (acceptedNames.contains(name.toLowerCase()) && value.isNotEmpty) {
        values[name.toLowerCase()] = '$name=$value';
      }
    }
    return values.values.join('; ');
  }
}

/// A short-lived handoff result from the interactive fnOS login page.
class FnidLoginPage extends StatefulWidget {
  const FnidLoginPage({required this.fnId, super.key});

  final String fnId;

  @override
  State<FnidLoginPage> createState() => _FnidLoginPageState();
}

class _FnidLoginPageState extends State<FnidLoginPage> {
  late final WebViewController _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  String? _error;
  String _currentUrl = '';
  bool _loading = true;
  bool _finishing = false;
  bool _appRequestStarted = false;
  String? _gatewayCookie;
  Timer? _sessionPollTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    if (kIsWeb) {
      _error = '当前平台不支持内嵌飞牛登录';
      return;
    }

    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (!mounted) return;
              setState(() {
                _loading = true;
                _currentUrl = url;
              });
            },
            onPageFinished: (url) {
              if (!mounted) return;
              setState(() {
                _loading = false;
                _currentUrl = url;
              });
              _startSessionPolling();
            },
            onUrlChange: (change) {
              final url = change.url;
              if (!mounted || url == null || url.isEmpty) return;
              setState(() => _currentUrl = url);
            },
            onWebResourceError: (error) {
              if (!mounted || error.isForMainFrame != true) return;
              setState(() {
                _loading = false;
                _error = error.description;
              });
            },
          ),
        )
        // Let the native WebView follow fnOS's JavaScript redirect chain.
        ..loadRequest(FnosGateway.fnidLoginUri(widget.fnId));
    } catch (error) {
      _error = error.toString();
    }
  }

  void _startSessionPolling() {
    if (_sessionPollTimer != null) return;
    _sessionPollTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) {
        if (!mounted || _finishing || _loading) return;
        unawaited(_continueLogin(automatic: true));
      },
    );
  }

  bool get _isGatewayHost {
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null) return false;
    return (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https') &&
        uri.host.toLowerCase() == FnosGateway.hostForFnId(widget.fnId);
  }

  bool get _isTingReaderPage {
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null || !_isGatewayHost) return false;
    return uri.path == _tingReaderPath ||
        uri.path.startsWith('$_tingReaderPath/');
  }

  Future<String> _readGatewayCookie() async {
    var cookieHeader = '';
    final domains = <Uri>[
      FnosGateway.originUri(widget.fnId),
      FnosGateway.fnosValidationUri(),
    ];
    final currentUri = Uri.tryParse(_currentUrl);
    if (currentUri != null &&
        (currentUri.scheme.toLowerCase() == 'http' ||
            currentUri.scheme.toLowerCase() == 'https')) {
      domains.insert(0, currentUri);
    }
    for (final domain in domains) {
      try {
        final cookies = await _cookieManager.getCookies(domain: domain);
        cookieHeader = FnosGateway.mergeCookieHeaders(
          cookieHeader,
          FnosGateway.cookieHeader(cookies),
        );
      } catch (_) {
        // Desktop WebView adapters may not implement CookieManager.getCookies.
      }
    }

    try {
      final rawDocumentCookie =
          await _controller.runJavaScriptReturningResult('document.cookie');
      cookieHeader = FnosGateway.mergeCookieHeaders(
        cookieHeader,
        FnosGateway.cookieHeaderFromDocumentCookie(
          rawDocumentCookie.toString(),
        ),
      );
    } catch (_) {
      // Keep the platform cookie result when JavaScript cookie access fails.
    }
    return cookieHeader;
  }

  Future<void> _continueLogin({bool automatic = false}) async {
    if (_isTingReaderPage) {
      await _finishLogin(automatic: automatic);
      return;
    }
    if (_isGatewayHost) {
      await _openTingReaderWithCookie(automatic: automatic);
      return;
    }
    if (!automatic && mounted) {
      setState(() {
        _error = context.localeText(
          '正在等待飞牛完成 FNID 校验，请稍候。',
          'Waiting for fnOS to finish FNID validation.',
        );
      });
    }
  }

  Future<void> _openTingReaderWithCookie({bool automatic = false}) async {
    if (_finishing || _appRequestStarted || !_isGatewayHost) return;
    final noSessionMessage = context.localeText(
      '没有检测到飞牛登录会话，请先在页面中完成登录。',
      'No fnOS login session was found. Complete fnOS login first.',
    );
    setState(() {
      _finishing = true;
      if (!automatic) _error = null;
    });

    try {
      final cookieHeader = await _readGatewayCookie();
      if (!FnosGateway.hasGatewaySession(cookieHeader)) {
        if (!automatic) throw StateError(noSessionMessage);
        return;
      }
      _gatewayCookie = cookieHeader;
      _appRequestStarted = true;
      await _controller.loadRequest(
        FnosGateway.appUri(widget.fnId),
        headers: {'Cookie': cookieHeader},
      );
    } catch (error) {
      _appRequestStarted = false;
      if (!mounted || automatic) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _finishLogin({bool automatic = false}) async {
    if (_finishing) return;
    if (!_isTingReaderPage || _loading) {
      if (!automatic && mounted) {
        setState(() {
          _error = context.localeText(
            '正在等待飞牛登录完成，请稍候。',
            'Waiting for fnOS login to finish.',
          );
        });
      }
      return;
    }
    final noSessionMessage = context.localeText(
      '没有检测到飞牛登录会话，请先在页面中完成登录。',
      'No fnOS login session was found. Complete login first.',
    );
    setState(() {
      _finishing = true;
      if (!automatic) _error = null;
    });

    try {
      final cookieHeader = FnosGateway.mergeCookieHeaders(
        _gatewayCookie ?? '',
        await _readGatewayCookie(),
      );
      if (!FnosGateway.hasGatewaySession(cookieHeader)) {
        if (!automatic) throw StateError(noSessionMessage);
        return;
      }
      if (!mounted) return;
      _sessionPollTimer?.cancel();
      _sessionPollTimer = null;
      Navigator.of(context).pop(cookieHeader);
    } catch (error) {
      if (!mounted || automatic) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  void dispose() {
    _sessionPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _error != null && !(_controllerReady())
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ),
          )
        : Stack(
            children: [
              if (_controllerReady()) WebViewWidget(controller: _controller),
              if (_loading)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.localeText('飞牛登录', 'fnOS login')),
      ),
      body: body,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.localeText(
                '完成飞牛登录后会自动继续；若未自动继续，可点下方按钮。应用只会接收当前站点的登录会话。',
                'After fnOS login, the app continues automatically. Use the button below if needed. Only this site session is used.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _controllerReady() && !_finishing ? _continueLogin : null,
                icon: _finishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  context.localeText('完成飞牛登录并继续', 'Continue'),
                ),
              ),
            ),
            if (_currentUrl.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _currentUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.mutedText, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _controllerReady() {
    return !_errorIsUnsupported && _hasController;
  }

  bool get _hasController {
    try {
      // Reading the late field is intentional: this keeps the page usable on
      // platforms where WebView construction fails during initialization.
      _controller;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get _errorIsUnsupported => kIsWeb;
}

extension on BuildContext {
  String localeText(String zh, String en) {
    final locale = Localizations.localeOf(this);
    return locale.languageCode.toLowerCase().startsWith('en') ? en : zh;
  }
}
