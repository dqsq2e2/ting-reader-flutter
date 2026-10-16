part of '../app_state.dart';

/// Startup restoration and cancellation checkpoints.
extension _AppStartup on AppState {
  Future<void> _initializeSession({bool Function()? isCancelled}) async {
    if (_disposed) throw const _StartupCancelled();
    gatewayStartupLoginAttempted = false;
    final startupGeneration = ++_startupGeneration;
    final cancelToken = CancelToken();
    _startupCancelToken = cancelToken;

    bool isStartupCancelled() {
      return (isCancelled?.call() ?? false) ||
          cancelToken.isCancelled ||
          startupGeneration != _startupGeneration;
    }

    void checkCancelled() {
      if (isStartupCancelled()) throw const _StartupCancelled();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      checkCancelled();
      _connections._loadRedirectCache();
      api.recoverBaseUrl = (_, requestCancelToken) =>
          recoverActiveUrl(cancelToken: requestCancelToken);
      final storedServerUrl = prefs.getString('server_url');
      final storedLocalServerUrl = prefs.getString('local_server_url');
      final storedActiveUrl = prefs.getString('active_url');
      serverUrl = storedServerUrl ?? serverUrl;
      localServerUrl = storedLocalServerUrl ?? localServerUrl;
      activeUrl = storedActiveUrl ??
          (localServerUrl.isNotEmpty ? localServerUrl : serverUrl);
      serverMode = _serverProfileModeFromPrefs();
      fnId = prefs.getString(AppState._fnIdPrefsKey) ?? fnId;
      final persistedGatewayHost = _gatewayHostForProfile(
        server: serverUrl,
        fnId: fnId,
        mode: serverMode,
      );
      // For an FNID profile, activeUrl is only the last known route. Do not
      // expose it on the startup page until the current network probe has
      // selected a reachable route.
      _startupConnectionTarget = persistedGatewayHost == null
          ? _firstNonEmptyUrl([
              storedActiveUrl,
              storedLocalServerUrl,
              storedServerUrl,
            ])
          : null;
      await _restoreSessionCredentials();
      needsGatewayLogin =
          prefs.getBool(AppState._gatewayReloginRequiredPrefsKey) ?? false;
      final shouldRestoreGatewaySession = persistedGatewayHost != null &&
          (needsGatewayLogin ||
              (token?.trim().isNotEmpty ?? false) ||
              (gatewayCookie?.trim().isNotEmpty ?? false));
      savedServers = await _loadSavedServers();
      _loadFnConnectSettings();
      _preferences._loadLocalLanguage();
      _preferences._loadCachedSettings();
      _preferences._loadLocalApplicationTimeZone();
      _notifyIfActive();
      api.setClientHeaders(await buildClientDeviceHeaders());
      checkCancelled();
      final hasPersistedServerConfig = prefs.containsKey('server_url') ||
          prefs.containsKey('local_server_url');

      final rawUser = prefs.getString('user');
      if (rawUser != null) {
        try {
          user = _requireAuthenticatedUser(jsonDecode(rawUser));
        } catch (_) {
          user = null;
        }
      }

      if (persistedGatewayHost != null) {
        fnId = persistedGatewayHost;
      }

      if (persistedGatewayHost != null &&
          fnId.trim().isNotEmpty &&
          (token == null || user == null) &&
          (gatewayCookie?.trim().isNotEmpty ?? false)) {
        // Migrate installations that lost the login marker before automatic
        // gateway re-authentication was persisted.
        needsGatewayLogin = true;
        await prefs.setBool(AppState._gatewayReloginRequiredPrefsKey, true);
      }

      if (persistedGatewayHost != null) {
        await _selectGatewayProfileRoute(
          gatewayHost: persistedGatewayHost,
          quick: true,
          isCancelled: isStartupCancelled,
          cancelToken: cancelToken,
        );
        // The persisted active URL is only the last successful route. It may
        // be unreachable after the app restarts (for example, when the LAN
        // address or NAT mapping changed), so always refresh FN Connect
        // candidates before restoring the authenticated session.
        var routeDetected = serverMode != ServerProfileMode.fnosGateway;
        if (serverMode == ServerProfileMode.fnosGateway &&
            savedGatewayProfile != null &&
            FnConnectClient.tokenFromCookie(gatewayCookie) != null) {
          try {
            routeDetected = await reprobeFnConnect();
          } catch (_) {
            // Keep the persisted route as a fallback. The normal connection
            // validation below will still handle an expired gateway session.
          }
        }
        if (routeDetected) {
          _startupConnectionTarget = _firstNonEmptyUrl([activeUrl]);
        }
        _notifyIfActive();
        checkCancelled();
      } else if (token != null && user != null && hasPersistedServerConfig) {
        await _selectActiveUrlForCurrentNetwork(
          isCancelled: isStartupCancelled,
          cancelToken: cancelToken,
        );
        _startupConnectionTarget = _firstNonEmptyUrl([activeUrl]);
        _notifyIfActive();
        checkCancelled();
      }
      api.configure(
        baseUrl: activeUrl,
        token: token,
        cookie:
            serverMode == ServerProfileMode.fnosGateway ? gatewayCookie : null,
      );
      // 恢复上次的访问码头（若有）：路由切换与静默重登都不会重置它。
      api.setGatewayExtraHeaders(
        serverMode == ServerProfileMode.fnosGateway
            ? FnAccessCode.headers(savedGatewayProfile?.fnAccessCode)
            : const {},
      );

      if (token != null && user != null) {
        await validateConnection(
          recordLogin: true,
          isCancelled: isStartupCancelled,
          cancelToken: cancelToken,
        );
        checkCancelled();
      }

      // Token-login cannot renew an expired fnOS cookie. Finish credential
      // recovery inside the startup gate instead of handing it to LoginPage.
      if (shouldRestoreGatewaySession && !isAuthenticated) {
        final profile = savedGatewayProfile;
        if (profile != null &&
            profile.username.trim().isNotEmpty &&
            profile.password.isNotEmpty &&
            profile.fnosUsername.trim().isNotEmpty &&
            profile.fnosPassword.isNotEmpty) {
          gatewayStartupLoginAttempted = true;
          try {
            await login(
              server: profile.serverUrl,
              localServer: profile.localServerUrl,
              username: profile.username,
              password: profile.password,
              mode: profile.mode,
              fnId: profile.fnId,
              fnosUsername: profile.fnosUsername,
              fnosPassword: profile.fnosPassword,
              fnAccessCode: profile.fnAccessCode,
              replaceProfile: profile,
              cancelToken: cancelToken,
            );
            checkCancelled();
            _startupConnectionTarget = _firstNonEmptyUrl([activeUrl]);
          } catch (error) {
            checkCancelled();
            await _markGatewayLoginRequired();
            connectionError = ApiError.messageFor(
              error,
              fallback: textForLocale(
                '登录失败，请检查服务器地址和账号信息',
                'Login failed. Check the server address and credentials.',
              ),
            );
            _notifyIfActive();
          }
          return;
        }
      }

      if (token != null && connectionError == null && user != null) {
        await loadSettings(
          silent: true,
          isCancelled: isStartupCancelled,
          cancelToken: cancelToken,
        );
        checkCancelled();
        await loadApplicationTimeZone(
          silent: true,
          cancelToken: cancelToken,
        );
        checkCancelled();
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) && isStartupCancelled()) {
        throw const _StartupCancelled();
      }
      rethrow;
    } finally {
      if (identical(_startupCancelToken, cancelToken)) {
        _startupCancelToken = null;
      }
    }
  }

  Future<void> _resetAfterStartupFailure({
    bool requireGatewayLogin = true,
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      _connections._loadRedirectCache();
      final storedServerUrl = prefs.getString('server_url');
      final storedLocalServerUrl = prefs.getString('local_server_url');
      final storedActiveUrl = prefs.getString('active_url');
      _startupConnectionTarget = _firstNonEmptyUrl([
        storedActiveUrl,
        storedLocalServerUrl,
        storedServerUrl,
      ]);
      serverUrl = storedServerUrl ?? serverUrl;
      localServerUrl = storedLocalServerUrl ?? localServerUrl;
      activeUrl = storedActiveUrl ??
          (localServerUrl.isNotEmpty ? localServerUrl : serverUrl);
      serverMode = _serverProfileModeFromPrefs();
      fnId = prefs.getString(AppState._fnIdPrefsKey) ?? fnId;
      await _restoreSessionCredentials();
      final persistedGatewayHost = _gatewayHostForProfile(
        server: serverUrl,
        fnId: fnId,
        mode: serverMode,
      );
      if (persistedGatewayHost != null) fnId = persistedGatewayHost;
      needsGatewayLogin = requireGatewayLogin && persistedGatewayHost != null;
      savedServers = await _loadSavedServers();
      _loadFnConnectSettings();
      await _clearPersistedToken();
      await _prefs?.remove('user');
    } catch (_) {
      // Keep a clean login screen even when persisted startup state is broken.
    }
    api.recoverBaseUrl = (_, requestCancelToken) =>
        recoverActiveUrl(cancelToken: requestCancelToken);
    try {
      api.setClientHeaders(await buildClientDeviceHeaders());
    } catch (_) {
      api.setClientHeaders(const {});
    }
    token = null;
    user = null;
    offlineMode = false;
    connectionError = null;
    if (needsGatewayLogin) {
      await _prefs?.setBool(AppState._gatewayReloginRequiredPrefsKey, true);
    } else {
      await _prefs?.remove(AppState._gatewayReloginRequiredPrefsKey);
    }
    _preferences._loadCachedSettings();
    api.configure(
      baseUrl: activeUrl,
      token: null,
      cookie:
          serverMode == ServerProfileMode.fnosGateway ? gatewayCookie : null,
    );
    _notifyIfActive();
  }
}
