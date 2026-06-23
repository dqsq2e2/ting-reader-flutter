part of '../app_state.dart';

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
    this.lastLoginAt,
  });

  final String serverUrl;
  final String localServerUrl;
  final String activeUrl;
  final String username;
  final String password;
  final String label;
  final DateTime? lastLoginAt;

  factory SavedServerProfile.fromJson(Map<String, dynamic> json) {
    return SavedServerProfile(
      serverUrl: json['server_url']?.toString() ?? '',
      localServerUrl: json['local_server_url']?.toString() ?? '',
      activeUrl: json['active_url']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
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
    DateTime? lastLoginAt,
  }) {
    return SavedServerProfile(
      serverUrl: serverUrl ?? this.serverUrl,
      localServerUrl: localServerUrl ?? this.localServerUrl,
      activeUrl: activeUrl ?? this.activeUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      label: label ?? this.label,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'server_url': serverUrl,
        'local_server_url': localServerUrl,
        'active_url': activeUrl,
        'username': username,
        'password': password,
        'label': label,
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
