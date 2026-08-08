import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

const _tingReaderPath = '/app/ting-reader';
const _webViewCookieChannel = MethodChannel('ting_reader/webview_cookies');

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
    final selected = <String, WebViewCookie>{};
    for (final cookie in cookies) {
      if (!_isAcceptedCookieName(cookie.name) || cookie.value.isEmpty) {
        continue;
      }
      final key = cookie.name.toLowerCase();
      final current = selected[key];
      if (current == null ||
          _cookieSpecificity(cookie) > _cookieSpecificity(current)) {
        selected[key] = cookie;
      }
    }
    return _filterCookiePairs(
      selected.values.map((cookie) => '${cookie.name}=${cookie.value}'),
    );
  }

  static int _cookieSpecificity(WebViewCookie cookie) {
    final domain = cookie.domain.startsWith('.')
        ? cookie.domain.substring(1)
        : cookie.domain;
    return domain.length * 1000 + cookie.path.length;
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

  static String mergeMissingCookieHeaders(String primary, String secondary) {
    final existingNames = primary
        .split(';')
        .map((part) => part.trim().split('=').first.toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    final missing = secondary.split(';').where((part) {
      final separator = part.indexOf('=');
      if (separator <= 0) return false;
      return !existingNames.contains(
        part.substring(0, separator).trim().toLowerCase(),
      );
    });
    return mergeCookieHeaders(primary, missing.join(';'));
  }

  static bool hasGatewaySession(String cookieHeader) {
    final names = cookieHeader
        .split(';')
        .map((part) => part.trim().split('=').first.toLowerCase())
        .toSet();
    return names.contains('fnos-token') && names.contains('entry-token');
  }

  static String _filterCookiePairs(Iterable<String> pairs) {
    final values = <String, String>{};
    for (final pair in pairs) {
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator).trim();
      final value = pair.substring(separator + 1).trim();
      if (_isAcceptedCookieName(name) && value.isNotEmpty) {
        values[name.toLowerCase()] = '$name=$value';
      }
    }
    return values.values.join('; ');
  }

  static bool _isAcceptedCookieName(String name) {
    const acceptedNames = {
      'mode',
      'language',
      'fnos-token',
      'entry-token',
    };
    return acceptedNames.contains(name.toLowerCase());
  }
}

/// Authentication data returned after both fnOS and TingReader login succeed.
class FnosGatewayLoginResult {
  const FnosGatewayLoginResult({
    required this.cookie,
    required this.response,
  });

  final String cookie;
  final Map<String, dynamic> response;
}

/// A short-lived handoff result from the interactive fnOS login page.
class FnidLoginPage extends StatefulWidget {
  const FnidLoginPage({
    required this.fnId,
    required this.username,
    required this.password,
    super.key,
  });

  final String fnId;
  final String username;
  final String password;

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
  bool _webLoginAttempted = false;
  String? _gatewayCookie;
  Completer<String>? _webLoginCompleter;
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
        ..addJavaScriptChannel(
          'TingReaderLogin',
          onMessageReceived: _handleWebLoginMessage,
        )
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
    var targetCookieHeader = '';
    var validationCookieHeader = '';
    final targetHost = FnosGateway.hostForFnId(widget.fnId);
    final targetDomains = <Uri>[FnosGateway.originUri(widget.fnId)];
    final currentUri = Uri.tryParse(_currentUrl);
    if (currentUri != null &&
        (currentUri.scheme.toLowerCase() == 'http' ||
            currentUri.scheme.toLowerCase() == 'https') &&
        currentUri.host.toLowerCase() == targetHost) {
      targetDomains.insert(0, currentUri);
    }
    for (final domain in targetDomains) {
      try {
        final cookies = await _cookieManager.getCookies(domain: domain);
        targetCookieHeader = FnosGateway.mergeCookieHeaders(
          targetCookieHeader,
          FnosGateway.cookieHeader(cookies),
        );
      } catch (_) {
        // Desktop WebView adapters may not implement CookieManager.getCookies.
      }
      // Android's adapter splits cookie values on every '=', which truncates
      // padded Base64 session tokens. Merge the platform's raw header last.
      targetCookieHeader = FnosGateway.mergeCookieHeaders(
        targetCookieHeader,
        await _readNativeCookie(domain),
      );
    }

    try {
      final rawDocumentCookie =
          await _controller.runJavaScriptReturningResult('document.cookie');
      targetCookieHeader = FnosGateway.mergeMissingCookieHeaders(
        targetCookieHeader,
        FnosGateway.cookieHeaderFromDocumentCookie(
          rawDocumentCookie.toString(),
        ),
      );
    } catch (_) {
      // Keep the platform cookie result when JavaScript cookie access fails.
    }

    try {
      final validationUri = FnosGateway.fnosValidationUri();
      final cookies = await _cookieManager.getCookies(domain: validationUri);
      validationCookieHeader = FnosGateway.mergeCookieHeaders(
        validationCookieHeader,
        FnosGateway.cookieHeader(cookies),
      );
      validationCookieHeader = FnosGateway.mergeCookieHeaders(
        validationCookieHeader,
        await _readNativeCookie(validationUri),
      );
    } catch (_) {
      // The target FNID host is the authoritative cookie source.
    }

    // fnos.net may carry only relay metadata. It must never overwrite a
    // token already issued for the concrete FNID host.
    return FnosGateway.mergeMissingCookieHeaders(
      targetCookieHeader,
      validationCookieHeader,
    );
  }

  Future<String> _readNativeCookie(Uri domain) async {
    if (defaultTargetPlatform != TargetPlatform.android) return '';
    try {
      final rawCookie = await _webViewCookieChannel.invokeMethod<String>(
        'getCookie',
        {'url': domain.toString()},
      );
      return FnosGateway.cookieHeaderFromDocumentCookie(rawCookie ?? '');
    } on MissingPluginException {
      return '';
    } catch (_) {
      return '';
    }
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
      await _writeGatewayCookiesToWebView(cookieHeader);
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
    if (_finishing || _webLoginAttempted) return;
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
      _webLoginAttempted = true;
      _sessionPollTimer?.cancel();
      _sessionPollTimer = null;
      final response = await _loginToTingReaderInWebView();
      if (!mounted) return;
      Navigator.of(context).pop(
        FnosGatewayLoginResult(cookie: cookieHeader, response: response),
      );
    } catch (error) {
      _webLoginAttempted = false;
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _writeGatewayCookiesToWebView(String cookieHeader) async {
    final domain = FnosGateway.hostForFnId(widget.fnId);
    for (final pair in cookieHeader.split(';')) {
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final name = pair.substring(0, separator).trim();
      final value = pair.substring(separator + 1).trim();
      if (name.isEmpty || value.isEmpty) continue;
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final written = await _webViewCookieChannel.invokeMethod<bool>(
            'setCookie',
            {
              'url': 'https://$domain/',
              'cookie': '$name=$value; Path=/',
            },
          );
          if (written == true) continue;
        } on MissingPluginException {
          // Fall back to the platform cookie manager below.
        } catch (_) {
          // Fall back to the platform cookie manager below.
        }
      }
      try {
        await _cookieManager.setCookie(
          WebViewCookie(
            name: name,
            value: value,
            domain: domain,
            path: '/',
          ),
        );
      } catch (_) {
        // The initial request still carries the raw Cookie header below.
      }
    }
  }

  void _handleWebLoginMessage(JavaScriptMessage message) {
    final completer = _webLoginCompleter;
    if (completer == null || completer.isCompleted) return;
    completer.complete(message.message);
  }

  Future<Map<String, dynamic>> _loginToTingReaderInWebView() async {
    final completer = Completer<String>();
    _webLoginCompleter = completer;
    final username = jsonEncode(widget.username);
    final password = jsonEncode(widget.password);
    final endpoint = jsonEncode('$_tingReaderPath/api/auth/login');

    try {
      await _controller.runJavaScript('''
(async () => {
  try {
    const response = await fetch($endpoint, {
      method: 'POST',
      credentials: 'include',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({username: $username, password: $password}),
    });
    const body = await response.text();
    TingReaderLogin.postMessage(JSON.stringify({status: response.status, body}));
  } catch (error) {
    TingReaderLogin.postMessage(JSON.stringify({error: String(error)}));
  }
})();
''');

      final rawMessage = await completer.future.timeout(
        const Duration(seconds: 20),
      );
      final envelope = jsonDecode(rawMessage);
      if (envelope is! Map) {
        throw StateError('TingReader 登录返回了无效响应');
      }
      final error = envelope['error']?.toString();
      if (error != null && error.isNotEmpty) {
        throw StateError('TingReader 登录请求失败：$error');
      }

      final status = int.tryParse(envelope['status']?.toString() ?? '');
      final rawBody = envelope['body']?.toString() ?? '';
      if (status == null || status < 200 || status >= 300) {
        throw StateError(
          'TingReader 登录失败（HTTP ${status ?? 'unknown'}）',
        );
      }

      final decodedBody = jsonDecode(rawBody);
      if (decodedBody is! Map) {
        throw StateError(
          'WebView 中的飞牛会话未被 TingReader API 接受，请重新登录飞牛。',
        );
      }
      final response = Map<String, dynamic>.from(decodedBody);
      if (response['token']?.toString().isEmpty ?? true) {
        throw StateError('TingReader 登录响应缺少 token');
      }
      if (response['user'] is! Map) {
        throw StateError('TingReader 登录响应缺少 user');
      }
      return response;
    } finally {
      _webLoginCompleter = null;
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
