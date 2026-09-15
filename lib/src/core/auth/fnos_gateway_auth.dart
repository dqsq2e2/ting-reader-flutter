/// Utilities for the fnOS/FN Connect gateway address used by a server profile.
class FnosGateway {
  const FnosGateway._();

  static const _gatewaySuffixes = <String>[
    '.fnos.net',
    '.5ddd.com',
    '.trzznas.com',
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

  static Uri originUriForHost(String host) {
    return Uri.https(_normalizeGatewayHost(host), '/');
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
}
