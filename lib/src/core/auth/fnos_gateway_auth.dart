import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

const _webViewCookieChannel = MethodChannel('ting_reader/webview_cookies');

/// Utilities for the fnOS/FN Connect gateway address used by a server profile.
class FnosGateway {
  const FnosGateway._();

  static const _gatewaySuffixes = <String>[
    '.fnos.net',
    '.5ddd.com',
  ];

  static String _normalizedHostOrLabel(String rawFnId) {
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

    return value.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  }

  static String fnIdLabel(String rawFnId) {
    final value = _normalizedHostOrLabel(rawFnId);
    for (final suffix in _gatewaySuffixes) {
      if (value.endsWith(suffix)) {
        return value.substring(0, value.length - suffix.length);
      }
    }
    return value.split('.').first;
  }

  static String hostForFnId(String rawFnId) {
    final value = _normalizedHostOrLabel(rawFnId);
    if (_gatewaySuffixes.any(value.endsWith)) return value;
    return '${fnIdLabel(value)}.fnos.net';
  }

  /// Detects an FNID entered in a WAN address field and returns its canonical
  /// gateway host. Ordinary HTTP(S) server URLs are intentionally ignored.
  ///
  /// Supported inputs include `fnid`, `fnid.fnos.net`,
  /// `fnid.5ddd.com`, and their HTTP(S) URL forms.
  static String? tryGatewayHostFromInput(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return null;

    final hasScheme = value.contains('://');
    final parsed = Uri.tryParse(hasScheme ? value : 'https://$value');
    final host = parsed?.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (host == null || host.isEmpty) return null;

    for (final suffix in _gatewaySuffixes) {
      if (!host.endsWith(suffix)) continue;
      final label = host.substring(0, host.length - suffix.length);
      if (_isValidFnIdLabel(label)) return host;
      return null;
    }

    if (hasScheme ||
        value.contains('/') ||
        value.contains('.') ||
        value.contains(':') ||
        host == 'localhost') {
      return null;
    }
    return _isValidFnIdLabel(host) ? '$host.fnos.net' : null;
  }

  static bool _isValidFnIdLabel(String value) {
    return RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(value);
  }

  static Uri originUri(String fnId) {
    return Uri.https(hostForFnId(fnId), '/');
  }

  static Uri originUriForHost(String host) {
    return Uri.https(_normalizeGatewayHost(host), '/');
  }

  static Uri fnidLoginUri(String fnId) {
    return Uri.https('fnos.net', '/${fnIdLabel(fnId)}');
  }

  static Uri fnosValidationUri() {
    return Uri.https('fnos.net', '/');
  }

  static Uri appUri(String fnId) {
    return Uri.https(hostForFnId(fnId), '/app/ting-reader');
  }

  static Uri appUriForHost(String host) {
    return Uri.https(_normalizeGatewayHost(host), '/app/ting-reader');
  }

  static bool isGatewayHostForFnId(String rawFnId, String rawHost) {
    final host = rawHost.trim().toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (host.isEmpty || host == 'fnos.net') return false;
    final label = fnIdLabel(rawFnId);
    return _gatewaySuffixes.any((suffix) => host == '$label$suffix');
  }

  static String? gatewayHostFromAppUrl(String rawUrl, String rawFnId) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.host.isEmpty) return null;
    final path = uri.path;
    if (path != '/app/ting-reader' && !path.startsWith('/app/ting-reader/')) {
      return null;
    }
    return isGatewayHostForFnId(rawFnId, uri.host) ? uri.host : null;
  }

  static String _normalizeGatewayHost(String rawHost) {
    return rawHost.trim().toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  }

  /// Returns the cookie domain that survives the fnOS relay redirect chain.
  ///
  /// Cookies collected from an FNID host are later used on both
  /// `<fnid>.fnos.net`, `<fnid>.5ddd.com`, and their relay parent domains. A
  /// host-only cookie works for the first request but disappears when fnOS
  /// performs its validation redirect.
  static String cookieDomainForHost(String rawHost) {
    final host = _normalizeGatewayHost(rawHost);
    if (host == 'fnos.net') return 'fnos.net';
    for (final suffix in _gatewaySuffixes) {
      if (host.endsWith(suffix)) return suffix.substring(1);
    }
    return host;
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
    final values = _cookieValues(cookieHeader);
    return values.containsKey('fnos-token') &&
        values.containsKey('entry-token');
  }

  static bool sameGatewaySession(String first, String second) {
    final firstValues = _cookieValues(first);
    final secondValues = _cookieValues(second);
    final firstFnosToken = firstValues['fnos-token'];
    final firstEntryToken = firstValues['entry-token'];
    if (firstFnosToken == null || firstEntryToken == null) return false;
    return firstFnosToken == secondValues['fnos-token'] &&
        firstEntryToken == secondValues['entry-token'];
  }

  static Map<String, String> _cookieValues(String cookieHeader) {
    final values = <String, String>{};
    for (final part in cookieHeader.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      final name = part.substring(0, separator).trim().toLowerCase();
      final value = part.substring(separator + 1).trim();
      if (_isAcceptedCookieName(name) && value.isNotEmpty) {
        values[name] = value;
      }
    }
    return values;
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

/// Authentication data returned after the fnOS WebView session is acquired.
/// Ting Reader login is completed by [AppState] through its authenticated API
/// client after this page closes.
class FnosGatewayLoginResult {
  const FnosGatewayLoginResult({
    required this.cookie,
    required this.gatewayHost,
  });

  final String cookie;
  final String gatewayHost;
}

/// A short-lived handoff result from the interactive fnOS login page.
class FnidLoginPage extends StatefulWidget {
  const FnidLoginPage({
    required this.fnId,
    this.rejectedCookie = '',
    super.key,
  });

  final String fnId;
  final String rejectedCookie;

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
  String? _gatewayHost;
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
              _recordGatewayHost(url);
              setState(() {
                _loading = true;
                _currentUrl = url;
              });
            },
            onPageFinished: (url) {
              if (!mounted) return;
              _recordGatewayHost(url);
              setState(() {
                _loading = false;
                _currentUrl = url;
              });
              _startSessionPolling();
            },
            onUrlChange: (change) {
              final url = change.url;
              if (!mounted || url == null || url.isEmpty) return;
              _recordGatewayHost(url);
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
        FnosGateway.isGatewayHostForFnId(widget.fnId, uri.host);
  }

  String get _resolvedGatewayHost {
    final currentUri = Uri.tryParse(_currentUrl);
    if (currentUri != null &&
        FnosGateway.isGatewayHostForFnId(widget.fnId, currentUri.host)) {
      return currentUri.host.toLowerCase();
    }
    return _gatewayHost ?? FnosGateway.hostForFnId(widget.fnId);
  }

  void _recordGatewayHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !FnosGateway.isGatewayHostForFnId(widget.fnId, uri.host)) {
      return;
    }
    _gatewayHost = uri.host.toLowerCase();
  }

  Future<String> _readGatewayCookie() async {
    var targetCookieHeader = '';
    var validationCookieHeader = '';
    final targetHost = _resolvedGatewayHost;
    final targetDomains = <Uri>[FnosGateway.originUriForHost(targetHost)];
    final currentUri = Uri.tryParse(_currentUrl);
    if (currentUri != null &&
        (currentUri.scheme.toLowerCase() == 'http' ||
            currentUri.scheme.toLowerCase() == 'https') &&
        FnosGateway.isGatewayHostForFnId(widget.fnId, currentUri.host)) {
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
    if (_isGatewayHost) {
      await _finishGatewayLogin(automatic: automatic);
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

  Future<void> _finishGatewayLogin({bool automatic = false}) async {
    if (_finishing || !_isGatewayHost || _loading) return;
    final noSessionMessage = context.localeText(
      '没有检测到飞牛登录会话，请先在页面中完成登录。',
      'No fnOS login session was found. Complete fnOS login first.',
    );
    final staleSessionMessage = context.localeText(
      '仍检测到已失效的飞牛会话，请完成重新登录。',
      'The rejected fnOS session is still active. Complete sign-in again.',
    );
    setState(() {
      _finishing = true;
      if (!automatic) _error = null;
    });

    try {
      final firstCookieHeader = await _readGatewayCookie();
      if (!FnosGateway.hasGatewaySession(firstCookieHeader)) {
        if (!automatic) throw StateError(noSessionMessage);
        return;
      }
      if (widget.rejectedCookie.isNotEmpty &&
          FnosGateway.sameGatewaySession(
            firstCookieHeader,
            widget.rejectedCookie,
          )) {
        if (!automatic) throw StateError(staleSessionMessage);
        return;
      }

      // Android may expose the new FNOS cookies before both values have been
      // committed. Confirm the same complete session twice before handing it
      // to the background API client.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted || !_isGatewayHost) return;
      final confirmedCookieHeader = await _readGatewayCookie();
      if (!FnosGateway.hasGatewaySession(confirmedCookieHeader) ||
          !FnosGateway.sameGatewaySession(
            firstCookieHeader,
            confirmedCookieHeader,
          )) {
        return;
      }
      if (widget.rejectedCookie.isNotEmpty &&
          FnosGateway.sameGatewaySession(
            confirmedCookieHeader,
            widget.rejectedCookie,
          )) {
        if (!automatic) throw StateError(staleSessionMessage);
        return;
      }

      _sessionPollTimer?.cancel();
      _sessionPollTimer = null;
      if (!mounted) return;
      Navigator.of(context).pop(
        FnosGatewayLoginResult(
          cookie: confirmedCookieHeader,
          gatewayHost: _resolvedGatewayHost,
        ),
      );
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
