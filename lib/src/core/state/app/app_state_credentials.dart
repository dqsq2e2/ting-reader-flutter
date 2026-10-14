part of '../app_state.dart';

/// Credential persistence belongs here; routing and playback keep using the
/// in-memory session owned by AppState.
extension _AppStateCredentials on AppState {
  static const _sessionScopePrefsKey = 'active_session_scope';
  static const _sessionRestoreDisabledPrefsKey = 'session_restore_disabled';

  String _sessionSecretKey() {
    var username = user?.username ?? '';
    if (username.isEmpty) {
      try {
        final stored = jsonDecode(_prefs?.getString('user') ?? '{}');
        username = asMap(stored)['username']?.toString() ?? '';
      } catch (_) {
        // A corrupt cached user is validated separately during startup.
      }
    }
    return '${_serverProfileSecretKey(SavedServerProfile(
      serverUrl: serverUrl,
      localServerUrl: localServerUrl,
      activeUrl: activeUrl,
      username: username,
      password: '',
      label: '',
      fnId: fnId,
      mode: serverMode,
    ))}.session';
  }

  Future<void> _restoreSessionCredentials() async {
    if (_prefs?.getBool(_sessionRestoreDisabledPrefsKey) == true) {
      token = null;
      gatewayCookie = null;
      return;
    }
    final key = _prefs?.getString(_sessionScopePrefsKey) ?? _sessionSecretKey();
    var record = await _credentials.read(key);
    if (record == null) {
      final legacyToken = _prefs?.getString('auth_token');
      final legacyCookie = _prefs?.getString(AppState._gatewayCookiePrefsKey);
      if (legacyToken != null || legacyCookie != null) {
        record = {
          'token': legacyToken ?? '',
          'cookie': legacyCookie ?? '',
        };
        await _credentials.write(key, record);
        await _prefs?.setString(_sessionScopePrefsKey, key);
      }
    }
    // Leave old values untouched if writing/verification throws.
    await _prefs?.remove('auth_token');
    await _prefs?.remove(AppState._gatewayCookiePrefsKey);
    token = _nonEmptyCredential(record?['token']);
    gatewayCookie = _nonEmptyCredential(record?['cookie']);
  }

  Future<void> _persistSessionCredentials() async {
    final key = user == null
        ? (_prefs?.getString(_sessionScopePrefsKey) ?? _sessionSecretKey())
        : _sessionSecretKey();
    await _credentials.write(key, {
      'token': token ?? '',
      'cookie': gatewayCookie ?? '',
    });
    await _prefs?.setString(_sessionScopePrefsKey, key);
    await _prefs?.remove(_sessionRestoreDisabledPrefsKey);
    await _prefs?.remove('auth_token');
    await _prefs?.remove(AppState._gatewayCookiePrefsKey);
  }

  Future<void> _clearPersistedToken() async {
    final key = _prefs?.getString(_sessionScopePrefsKey) ?? _sessionSecretKey();
    final record = await _credentials.read(key);
    if (record != null) {
      await _credentials.write(key, {...record, 'token': ''});
    }
    await _prefs?.remove('auth_token');
  }

  Future<void> _clearPersistedSession() async {
    final key = _prefs?.getString(_sessionScopePrefsKey) ?? _sessionSecretKey();
    // Record logout before touching the keychain: a storage failure must not
    // restore the old session when the platform keychain becomes available.
    await _prefs?.setBool(_sessionRestoreDisabledPrefsKey, true);
    await _prefs?.remove('auth_token');
    await _prefs?.remove(AppState._gatewayCookiePrefsKey);
    await _prefs?.remove(AppState._gatewayReloginRequiredPrefsKey);
    await _prefs?.remove('user');
    await _credentials.delete(key);
    final profiles = <SavedServerProfile>[];
    for (final profile in savedServers) {
      if ('${_serverProfileSecretKey(profile)}.session' == key) {
        final cleared = profile.copyWith(gatewayCookie: '');
        await _storeServerProfileSecrets(cleared);
        profiles.add(cleared);
      } else {
        profiles.add(profile);
      }
    }
    savedServers = profiles;
    await _persistSavedServers(profiles);
    await _prefs?.remove(_sessionScopePrefsKey);
    await _prefs?.remove('auth_token');
    await _prefs?.remove(AppState._gatewayCookiePrefsKey);
  }

  String? _nonEmptyCredential(String? value) =>
      value == null || value.isEmpty ? null : value;

  Future<List<SavedServerProfile>> _loadSavedServers() async {
    final raw = _prefs?.getString('saved_servers');
    if (raw == null || raw.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    final profiles = decoded
        .map((item) => SavedServerProfile.fromJson(asMap(item)))
        .where((item) =>
            item.serverUrl.isNotEmpty || item.localServerUrl.isNotEmpty)
        .toList();
    final hydrated = <SavedServerProfile>[];
    for (final profile in profiles) {
      hydrated.add(await _hydrateServerProfileSecrets(profile));
    }
    // Only remove inline secrets after every profile has been migrated.
    await _persistSavedServers(hydrated);
    return hydrated;
  }

  Future<SavedServerProfile> _hydrateServerProfileSecrets(
    SavedServerProfile profile,
  ) async {
    final key = _serverProfileSecretKey(profile);
    var record = await _credentials.read('$key.credentials');
    if (record == null) {
      record = {
        'password':
            await _secureStorage.read(key: '$key.tr') ?? profile.password,
        'fnos_password':
            await _secureStorage.read(key: '$key.fnos') ?? profile.fnosPassword,
        'cookie': profile.gatewayCookie,
        'access_code': profile.fnAccessCode,
      };
      await _credentials.write('$key.credentials', record);
    }
    await _secureStorage.delete(key: '$key.tr');
    await _secureStorage.delete(key: '$key.fnos');
    return profile.copyWith(
      password: record['password'] ?? '',
      fnosPassword: record['fnos_password'] ?? '',
      gatewayCookie: record['cookie'] ?? '',
      fnAccessCode: record['access_code'] ?? '',
    );
  }

  Future<void> _storeServerProfileSecrets(
    SavedServerProfile profile, {
    SavedServerProfile? replaceProfile,
  }) async {
    final key = _serverProfileSecretKey(profile);
    await _credentials.write('$key.credentials', {
      'password': profile.password,
      'fnos_password': profile.fnosPassword,
      'cookie': profile.gatewayCookie,
      'access_code': profile.fnAccessCode,
    });
    if (replaceProfile != null &&
        _serverProfileSecretKey(replaceProfile) != key) {
      await _deleteServerProfileSecrets(replaceProfile);
    }
  }

  Future<void> _deleteServerProfileSecrets(SavedServerProfile profile) async {
    final key = _serverProfileSecretKey(profile);
    await _credentials.delete('$key.credentials');
    await _credentials.delete('$key.session');
    await _secureStorage.delete(key: '$key.tr');
    await _secureStorage.delete(key: '$key.fnos');
  }

  String _serverProfileSecretKey(SavedServerProfile profile) {
    final gatewayIdentity = _normalizedGatewayIdentity(profile.fnId);
    final identity = gatewayIdentity.isNotEmpty
        ? 'gateway|$gatewayIdentity|${profile.username}'
        : 'direct|${_normalizeOptionalServerUrl(profile.serverUrl)}|${_normalizeOptionalServerUrl(profile.localServerUrl)}|${profile.username}';
    final encoded = base64UrlEncode(utf8.encode(identity)).replaceAll('=', '');
    return 'server_profile.$encoded';
  }

  Future<void> _persistSavedServers(List<SavedServerProfile> profiles) async {
    await _prefs?.setString(
      'saved_servers',
      jsonEncode(profiles.map((item) => item.toJson()).toList()),
    );
  }

  Future<SavedServerProfile> _rememberProfile({
    required String server,
    String localServer = '',
    required String username,
    required String password,
    ServerProfileMode mode = ServerProfileMode.direct,
    String fnId = '',
    String fnosUsername = '',
    String fnosPassword = '',
    String gatewayCookie = '',
    String fnAccessCode = '',
    SavedServerProfile? replaceProfile,
  }) async {
    final gatewayHost = _gatewayHostForProfile(
      server: server,
      fnId: fnId,
      mode: mode,
    );
    final normalizedLocal = _normalizeOptionalServerUrl(localServer);
    final normalizedServer = gatewayHost == null
        ? _normalizeOptionalServerUrl(server)
        : FnosGateway.originUriForHost(gatewayHost).toString();
    final resolvedMode = gatewayHost == null
        ? ServerProfileMode.direct
        : ServerProfileMode.fnosGateway;
    final profile = SavedServerProfile(
      serverUrl: normalizedServer,
      localServerUrl: normalizedLocal,
      activeUrl: gatewayHost == null
          ? (normalizedLocal.isNotEmpty ? normalizedLocal : normalizedServer)
          : FnosGateway.appUriForHost(gatewayHost).toString(),
      username: username,
      password: password,
      label: username,
      mode: resolvedMode,
      fnId: gatewayHost ?? '',
      fnosUsername: resolvedMode == ServerProfileMode.fnosGateway
          ? fnosUsername.trim()
          : '',
      fnosPassword:
          resolvedMode == ServerProfileMode.fnosGateway ? fnosPassword : '',
      gatewayCookie: gatewayCookie,
      fnAccessCode:
          resolvedMode == ServerProfileMode.fnosGateway ? fnAccessCode : '',
    );
    await _saveServerProfile(profile, replaceProfile: replaceProfile);
    _notifyIfActive();
    return profile;
  }

  Future<void> _saveServerProfile(
    SavedServerProfile profile, {
    SavedServerProfile? replaceProfile,
  }) async {
    final normalizedServer = _normalizeOptionalServerUrl(profile.serverUrl);
    final normalizedLocal = _normalizeOptionalServerUrl(profile.localServerUrl);
    final normalizedReplaceServer = replaceProfile == null
        ? null
        : _normalizeOptionalServerUrl(replaceProfile.serverUrl);
    final normalizedReplaceLocal = replaceProfile == null
        ? null
        : _normalizeOptionalServerUrl(replaceProfile.localServerUrl);

    bool sameProfile(
      SavedServerProfile item,
      String? server,
      String? local,
      String username,
      ServerProfileMode mode,
      String fnId,
    ) {
      if (server == null || local == null) return false;
      final gatewayIdentity = _normalizedGatewayIdentity(fnId);
      final itemGatewayIdentity = _normalizedGatewayIdentity(item.fnId);
      if (_normalizeOptionalServerUrl(item.localServerUrl) != local ||
          item.username != username) {
        return false;
      }
      if (gatewayIdentity.isNotEmpty) {
        // Gateway profiles are one logical server; fnos.net and 5ddd.com
        // are only relay hosts chosen by fnOS, not different profiles.
        return itemGatewayIdentity == gatewayIdentity;
      }
      return itemGatewayIdentity.isEmpty &&
          item.mode == mode &&
          _normalizeOptionalServerUrl(item.serverUrl) == server;
    }

    final next = [
      profile.copyWith(
        serverUrl: normalizedServer,
        localServerUrl: normalizedLocal,
      ),
      ...savedServers.where(
        (item) {
          if (sameProfile(
            item,
            normalizedServer,
            normalizedLocal,
            profile.username,
            profile.mode,
            profile.fnId,
          )) {
            return false;
          }
          if (replaceProfile != null &&
              sameProfile(
                item,
                normalizedReplaceServer,
                normalizedReplaceLocal,
                replaceProfile.username,
                replaceProfile.mode,
                replaceProfile.fnId,
              )) {
            return false;
          }
          return true;
        },
      ),
    ];
    await _storeServerProfileSecrets(
      profile,
      replaceProfile: replaceProfile,
    );
    savedServers = next.take(8).toList();
    await _persistSavedServers(savedServers);
  }

  Future<void> _deleteProfile(SavedServerProfile profile) async {
    await _deleteServerProfileSecrets(profile);
    final normalizedServer = _normalizeOptionalServerUrl(profile.serverUrl);
    final normalizedLocal = _normalizeOptionalServerUrl(profile.localServerUrl);
    final gatewayIdentity = _normalizedGatewayIdentity(profile.fnId);
    savedServers = savedServers.where(
      (item) {
        final itemGatewayIdentity = _normalizedGatewayIdentity(item.fnId);
        if (_normalizeOptionalServerUrl(item.localServerUrl) !=
                normalizedLocal ||
            item.username != profile.username) {
          return true;
        }
        if (gatewayIdentity.isNotEmpty) {
          return itemGatewayIdentity != gatewayIdentity;
        }
        return itemGatewayIdentity.isNotEmpty ||
            item.mode != profile.mode ||
            _normalizeOptionalServerUrl(item.serverUrl) != normalizedServer;
      },
    ).toList();
    await _persistSavedServers(savedServers);
    _notifyIfActive();
  }
}
