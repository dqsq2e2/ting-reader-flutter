part of '../app_state.dart';

enum ServerProfileMode {
  direct,
  fnosGateway,
}

/// A previously-used server + credential bundle saved to local storage so the
/// user can quickly switch back without re-typing.
class SavedServerProfile {
  const SavedServerProfile({
    required this.serverUrl,
    this.localServerUrl = '',
    required this.activeUrl,
    required this.username,
    required this.password,
    required this.label,
    this.mode = ServerProfileMode.direct,
    this.fnId = '',
    this.fnosUsername = '',
    this.fnosPassword = '',
    this.gatewayCookie = '',
    this.gatewayCookieAt,
    this.lastLoginAt,
  });

  final String serverUrl;
  final String localServerUrl;
  final String activeUrl;
  final String username;
  final String password;
  final String label;
  final ServerProfileMode mode;
  final String fnId;
  final String fnosUsername;
  final String fnosPassword;
  final String gatewayCookie;
  final DateTime? gatewayCookieAt;
  final DateTime? lastLoginAt;

  bool get isFnosGateway =>
      mode == ServerProfileMode.fnosGateway || fnId.trim().isNotEmpty;

  factory SavedServerProfile.fromJson(Map<String, dynamic> json) {
    final rawFnId = json['fn_id']?.toString().trim() ?? '';
    final modeValue = json['mode']?.toString();
    return SavedServerProfile(
      serverUrl: json['server_url']?.toString() ?? '',
      localServerUrl: json['local_server_url']?.toString() ?? '',
      activeUrl: json['active_url']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      mode: _isFnosGatewayModeValue(modeValue) ||
              (modeValue == null && rawFnId.isNotEmpty)
          ? ServerProfileMode.fnosGateway
          : ServerProfileMode.direct,
      fnId: rawFnId,
      fnosUsername: json['fnos_username']?.toString() ?? '',
      fnosPassword: json['fnos_password']?.toString() ?? '',
      gatewayCookie: json['gateway_cookie']?.toString() ?? '',
      gatewayCookieAt:
          DateTime.tryParse(json['gateway_cookie_at']?.toString() ?? ''),
      lastLoginAt: DateTime.tryParse(json['last_login_at']?.toString() ?? ''),
    );
  }

  SavedServerProfile copyWith({
    String? serverUrl,
    String? localServerUrl,
    String? activeUrl,
    String? username,
    String? password,
    String? label,
    ServerProfileMode? mode,
    String? fnId,
    String? fnosUsername,
    String? fnosPassword,
    String? gatewayCookie,
    DateTime? gatewayCookieAt,
    DateTime? lastLoginAt,
  }) {
    return SavedServerProfile(
      serverUrl: serverUrl ?? this.serverUrl,
      localServerUrl: localServerUrl ?? this.localServerUrl,
      activeUrl: activeUrl ?? this.activeUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      label: label ?? this.label,
      mode: mode ?? this.mode,
      fnId: fnId ?? this.fnId,
      fnosUsername: fnosUsername ?? this.fnosUsername,
      fnosPassword: fnosPassword ?? this.fnosPassword,
      gatewayCookie: gatewayCookie ?? this.gatewayCookie,
      gatewayCookieAt: gatewayCookieAt ?? this.gatewayCookieAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toJson({bool includeSecrets = false}) => {
        'server_url': serverUrl,
        'local_server_url': localServerUrl,
        'active_url': activeUrl,
        'username': username,
        if (includeSecrets) 'password': password,
        'label': label,
        'mode': mode.name,
        if (fnId.isNotEmpty) 'fn_id': fnId,
        if (fnosUsername.isNotEmpty) 'fnos_username': fnosUsername,
        if (includeSecrets && fnosPassword.isNotEmpty)
          'fnos_password': fnosPassword,
        if (gatewayCookie.isNotEmpty) 'gateway_cookie': gatewayCookie,
        if (gatewayCookieAt != null)
          'gateway_cookie_at': gatewayCookieAt!.toIso8601String(),
        if (lastLoginAt != null)
          'last_login_at': lastLoginAt!.toIso8601String(),
      };
}

/// Result of resolving a redirect chain on the server URL.
class RedirectResolution {
  const RedirectResolution({
    required this.sourceUrl,
    required this.resolvedUrl,
    required this.fromCache,
  });

  final String sourceUrl;
  final String resolvedUrl;
  final bool fromCache;

  bool get redirected => sourceUrl != resolvedUrl;
}

/// Thrown internally by [AppState.initialize] to short-circuit startup when the
/// user cancels.
class _StartupCancelled implements Exception {
  const _StartupCancelled();
}

class _GatewaySessionExpired implements Exception {
  const _GatewaySessionExpired();
}
