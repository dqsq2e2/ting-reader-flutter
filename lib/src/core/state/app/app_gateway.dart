part of '../app_state.dart';

/// fnOS session renewal and transport selection for the active account.
extension _AppGateway on AppState {
  Future<bool> _handleGatewaySessionExpired() async {
    if (_disposed) return false;
    final activeRecovery = _gatewaySessionRecovery;
    if (activeRecovery != null) {
      return activeRecovery;
    }

    if (serverMode != ServerProfileMode.fnosGateway ||
        fnId.trim().isEmpty ||
        (token?.trim().isEmpty ?? true) ||
        offlineMode) {
      return false;
    }

    final cancelToken = CancelToken();
    _gatewayRecoveryCancelToken = cancelToken;
    final recovery = _recoverGatewaySessionSilently(cancelToken);
    _gatewaySessionRecovery = recovery;
    try {
      return await recovery;
    } finally {
      if (identical(_gatewaySessionRecovery, recovery)) {
        _gatewaySessionRecovery = null;
        _gatewayRecoveryCancelToken = null;
      }
    }
  }

  Future<bool> _recoverGatewaySessionSilently(CancelToken cancelToken) async {
    final profile = savedGatewayProfile;
    if (profile == null ||
        profile.fnosUsername.trim().isEmpty ||
        profile.fnosPassword.isEmpty ||
        profile.username.trim().isEmpty ||
        profile.password.isEmpty) {
      await _markGatewayLoginRequired();
      return false;
    }

    try {
      final result = await fnConnect.loginAndConnect(
        fnId: profile.fnId,
        username: profile.fnosUsername,
        password: profile.fnosPassword,
        order: fnConnectOrder,
        disabledGroups: fnConnectDisabledGroups,
        ignoreSsl: fnConnectIgnoreSsl,
        accessCode: profile.fnAccessCode,
        deviceId: await _fnDeviceDid(),
        cancelToken: cancelToken,
      );
      _throwIfLoginCancelled(cancelToken);
      fnConnectCandidates = result.candidates;
      serverMode = ServerProfileMode.fnosGateway;
      fnId = result.session.relayHost;
      serverUrl = 'https://${result.session.relayHost}';
      activeUrl = result.appBaseUrl;
      gatewayCookie = result.cookie;
      // Keep the UI session alive until renewal succeeds or requires login.
      // The login request itself must not carry the previous API token.
      api.configure(baseUrl: activeUrl, token: null, cookie: gatewayCookie);
      // 访问码头先于 TR 登录请求生效（穿过网关的 /api/auth/login 同样需要）。
      api.setGatewayExtraHeaders(FnAccessCode.headers(profile.fnAccessCode));

      final map = await _loginToTingReader(
        profile.username,
        profile.password,
        cancelToken: cancelToken,
      );
      _throwIfLoginCancelled(cancelToken);
      final renewedUser = _requireAuthenticatedUser(map['user']);
      token = map['token']?.toString();
      user = renewedUser;
      api.configure(baseUrl: activeUrl, token: token, cookie: gatewayCookie);
      needsGatewayLogin = false;
      connectionError = null;

      await _persistAuthenticatedGatewayState(renewedUser, cancelToken);
      _throwIfLoginCancelled(cancelToken);
      await _saveServerProfile(
        profile.copyWith(
          serverUrl: serverUrl,
          activeUrl: activeUrl,
          mode: ServerProfileMode.fnosGateway,
          fnId: fnId,
          gatewayCookie: gatewayCookie,
          gatewayCookieAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        ),
        replaceProfile: profile,
      );
      _throwIfLoginCancelled(cancelToken);
      _notifyIfActive();
      await _notifyGatewayLoginRestored();
      return true;
    } on FnConnectProtocolException {
      if (_disposed) return false;
      // fnOS also wraps WebSocket connection failures as protocol errors.
      _keepGatewaySessionAfterConnectionFailure();
      return false;
    } on DioException catch (error) {
      if (_disposed || CancelToken.isCancel(error)) return false;
      final status = error.response?.statusCode;
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError ||
          status == 502 ||
          status == 503 ||
          status == 504) {
        // Transport failure does not invalidate the user's application session.
        _keepGatewaySessionAfterConnectionFailure();
        return false;
      }
      await _markGatewayLoginRequired();
      return false;
    } catch (_) {
      if (_disposed) return false;
      await _markGatewayLoginRequired();
      return false;
    }
  }

  void _keepGatewaySessionAfterConnectionFailure() {
    api.configure(baseUrl: activeUrl, token: token, cookie: gatewayCookie);
    connectionError = textForLocale(
      '无法连接服务器',
      'Unable to connect to server',
    );
    _notifyIfActive();
  }

  Future<void> _persistAuthenticatedGatewayState(
      User authenticatedUser, CancelToken cancelToken) async {
    _throwIfLoginCancelled(cancelToken);
    await _persistSessionCredentials();
    _throwIfLoginCancelled(cancelToken);
    await _prefs?.setString('server_url', serverUrl);
    _throwIfLoginCancelled(cancelToken);
    await _prefs?.setString('local_server_url', localServerUrl);
    _throwIfLoginCancelled(cancelToken);
    await _prefs?.setString('active_url', activeUrl);
    _throwIfLoginCancelled(cancelToken);
    await _prefs?.setString(AppState._serverModePrefsKey, serverMode.name);
    _throwIfLoginCancelled(cancelToken);
    await _prefs?.setString(AppState._fnIdPrefsKey, fnId);
    _throwIfLoginCancelled(cancelToken);
    await _prefs?.setString('user', authenticatedUser.encode());
    _throwIfLoginCancelled(cancelToken);
    await _prefs?.remove(AppState._gatewayReloginRequiredPrefsKey);
  }

  Future<void> _markGatewayLoginRequired() async {
    await _notifyGatewayLoginRequired();
    needsGatewayLogin = true;
    token = null;
    user = null;
    connectionError = textForLocale(
      '飞牛登录会话已失效，正在重新登录',
      'The fnOS login session expired. Signing in again',
    );
    api.configure(
      baseUrl: activeUrl,
      token: null,
      cookie: gatewayCookie,
    );
    await _clearPersistedToken();
    await _prefs?.remove('user');
    await _prefs?.setBool(AppState._gatewayReloginRequiredPrefsKey, true);
    _notifyIfActive();
  }

  Future<void> _notifyGatewayLoginRequired() async {
    final callback = onGatewayLoginRequired;
    if (callback == null) return;
    try {
      await callback();
    } catch (_) {
      // A playback pause must not prevent the user from recovering fnOS auth.
    }
  }

  Future<void> _notifyGatewayLoginRestored() async {
    final callback = onGatewayLoginRestored;
    if (callback == null) return;
    try {
      await callback();
    } catch (_) {
      // Authentication has already succeeded; playback can remain paused.
    }
  }

  String? _gatewayHostForProfile({
    required String server,
    required String fnId,
    required ServerProfileMode mode,
  }) {
    final detected = FnosGateway.tryGatewayHostFromInput(server);
    if (detected != null) return detected;

    final stored = FnosGateway.tryGatewayHostFromInput(fnId);
    if (stored != null) return stored;

    if (mode == ServerProfileMode.fnosGateway && fnId.trim().isNotEmpty) {
      return FnosGateway.hostForFnId(fnId);
    }
    return null;
  }

  String _normalizedGatewayIdentity(String rawFnId) {
    final value = rawFnId.trim();
    if (value.isEmpty) return '';
    final gatewayHost = FnosGateway.tryGatewayHostFromInput(value);
    if (gatewayHost != null) return FnosGateway.fnIdLabel(gatewayHost);
    return value.toLowerCase();
  }

  Future<RedirectResolution?> _tryResolveLocalServer(
    String localServer, {
    bool quick = true,
    bool Function()? isCancelled,
    CancelToken? cancelToken,
  }) async {
    if ((isCancelled?.call() ?? false) || (cancelToken?.isCancelled ?? false)) {
      throw const _StartupCancelled();
    }
    bool? sameSubnet;
    try {
      sameSubnet = await isServerOnCurrentIpv4Subnet(localServer);
    } catch (_) {
      sameSubnet = null;
    }
    if ((isCancelled?.call() ?? false) || (cancelToken?.isCancelled ?? false)) {
      throw const _StartupCancelled();
    }
    if (sameSubnet == false) return null;

    try {
      return await resolveBestServerUrl(
        server: '',
        localServer: localServer,
        force: true,
        quick: quick,
        cancelToken: cancelToken,
      );
    } on _StartupCancelled {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) && (cancelToken?.isCancelled ?? false)) {
        throw const _StartupCancelled();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectGatewayProfileRoute({
    required String gatewayHost,
    bool quick = false,
    bool Function()? isCancelled,
    CancelToken? cancelToken,
  }) async {
    fnId = gatewayHost;
    localServerUrl = _normalizeOptionalServerUrl(localServerUrl);

    final persistedActiveUri = Uri.tryParse(activeUrl);
    final persistedDirectFnConnectRoute = quick &&
        persistedActiveUri != null &&
        (persistedActiveUri.scheme == 'http' ||
            persistedActiveUri.scheme == 'https') &&
        (persistedActiveUri.path == '/app/ting-reader' ||
            persistedActiveUri.path.startsWith('/app/ting-reader/')) &&
        !FnosGateway.isGatewayHostForFnId(
          gatewayHost,
          persistedActiveUri.host,
        ) &&
        FnConnectClient.tokenFromCookie(gatewayCookie) != null;
    if (persistedDirectFnConnectRoute) {
      serverMode = ServerProfileMode.fnosGateway;
      needsGatewayLogin = false;
      api.configure(baseUrl: activeUrl, token: token, cookie: gatewayCookie);
      return;
    }

    if (localServerUrl.isNotEmpty) {
      final localResolution = await _tryResolveLocalServer(
        localServerUrl,
        quick: quick,
        isCancelled: isCancelled,
        cancelToken: cancelToken,
      );
      if (localResolution != null) {
        if ((isCancelled?.call() ?? false) ||
            (cancelToken?.isCancelled ?? false)) {
          throw const _StartupCancelled();
        }
        activeUrl = localResolution.resolvedUrl;
        serverMode = ServerProfileMode.direct;
        needsGatewayLogin = false;
        await _prefs?.remove(AppState._gatewayReloginRequiredPrefsKey);
        api.configure(baseUrl: activeUrl, token: token, cookie: null);
        return;
      }
    }

    if ((isCancelled?.call() ?? false) || (cancelToken?.isCancelled ?? false)) {
      throw const _StartupCancelled();
    }

    serverMode = ServerProfileMode.fnosGateway;
    final activeGatewayHost =
        FnosGateway.gatewayHostFromAppUrl(activeUrl, gatewayHost) ??
            FnosGateway.gatewayHostFromAppUrl(serverUrl, gatewayHost) ??
            gatewayHost;
    activeUrl = FnosGateway.appUriForHost(activeGatewayHost).toString();
    serverUrl = FnosGateway.originUriForHost(activeGatewayHost).toString();
    api.configure(baseUrl: activeUrl, token: token, cookie: gatewayCookie);
  }

  Future<void> _setGatewayOrder(List<FnConnectCandidateGroup> order) async {
    final normalized = <FnConnectCandidateGroup>[];
    for (final group in [...order, ...defaultFnConnectOrder]) {
      if (!normalized.contains(group)) normalized.add(group);
    }
    fnConnectOrder = normalized;
    await _prefs?.setStringList(
      AppState._fnConnectOrderPrefsKey,
      normalized.map((group) => group.name).toList(growable: false),
    );
    _notifyIfActive();
  }

  Future<void> _setGatewayGroupEnabled(
    FnConnectCandidateGroup group,
    bool enabled,
  ) async {
    final next = Set<FnConnectCandidateGroup>.from(fnConnectDisabledGroups);
    if (enabled) {
      next.remove(group);
    } else {
      final enabledCount = FnConnectCandidateGroup.values
          .where((item) => !next.contains(item))
          .length;
      if (enabledCount <= 1) return;
      next.add(group);
    }
    fnConnectDisabledGroups = next;
    await _prefs?.setStringList(
      AppState._fnConnectDisabledPrefsKey,
      next.map((item) => item.name).toList(growable: false),
    );
    _notifyIfActive();
  }

  Future<void> _setGatewayIgnoreSsl(bool value) async {
    fnConnectIgnoreSsl = value;
    await _prefs?.setBool(AppState._fnConnectIgnoreSslPrefsKey, value);
    _notifyIfActive();
  }

  Future<bool> _reprobeGateway() async {
    if (fnConnectProbing) return false;
    final profile = savedGatewayProfile;
    final sessionToken = FnConnectClient.tokenFromCookie(gatewayCookie);
    if (profile == null || sessionToken == null) {
      throw StateError(textForLocale(
        '当前登录方式不支持 FN Connect',
        'The current login does not support FN Connect',
      ));
    }

    fnConnectProbing = true;
    _notifyIfActive();
    try {
      FnConnectDiscovery discovery;
      try {
        discovery = await fnConnect.discover(profile.fnId);
      } catch (_) {
        discovery = FnConnectDiscovery.fallback(profile.fnId);
      }
      final candidates = fnConnect.buildCandidates(
        discovery: discovery,
        order: fnConnectOrder,
        disabledGroups: fnConnectDisabledGroups,
      );
      fnConnectCandidates = await fnConnect.probeCandidates(
        candidates: candidates,
        token: sessionToken,
        ignoreSsl: fnConnectIgnoreSsl,
        accessCode: profile.fnAccessCode,
      );
      final best =
          fnConnectCandidates.where((result) => result.reachable).firstOrNull;
      if (best == null) return false;
      if (ApiClient.normalizeServerUrl(best.candidate.appBaseUrl) !=
          ApiClient.normalizeServerUrl(activeUrl)) {
        await switchFnConnectCandidate(best.candidate);
      }
      return true;
    } finally {
      fnConnectProbing = false;
      _notifyIfActive();
    }
  }

  Future<void> _switchGatewayCandidate(FnConnectCandidate candidate) async {
    final sessionToken = FnConnectClient.tokenFromCookie(gatewayCookie);
    final profile = savedGatewayProfile;
    if (sessionToken == null || profile == null) {
      throw StateError(textForLocale(
        '飞牛登录会话不可用',
        'The fnOS login session is unavailable',
      ));
    }

    final verification = (await fnConnect.probeCandidates(
      candidates: [candidate],
      token: sessionToken,
      ignoreSsl: fnConnectIgnoreSsl,
      accessCode: profile.fnAccessCode,
    ))
        .single;
    if (!verification.reachable) {
      throw StateError(textForLocale(
        '链路校验失败：${verification.localizedErrorText(chinese: !isEnglish)}',
        'Link verification failed: '
            '${verification.localizedErrorText(chinese: false)}',
      ));
    }

    final previousUrl = activeUrl;
    final previousCookie = gatewayCookie;
    final nextCookie = FnConnectClient.cookieHeader(
      sessionToken,
      relay: candidate.isRelay,
    );
    activeUrl = candidate.appBaseUrl;
    serverMode = ServerProfileMode.fnosGateway;
    gatewayCookie = nextCookie;
    api.configure(baseUrl: activeUrl, token: token, cookie: gatewayCookie);
    try {
      await _prefs?.setString('active_url', activeUrl);
      await _prefs?.setString(AppState._serverModePrefsKey, serverMode.name);
      await _persistSessionCredentials();
      await _saveServerProfile(
        profile.copyWith(
          activeUrl: activeUrl,
          mode: ServerProfileMode.fnosGateway,
          gatewayCookie: nextCookie,
          gatewayCookieAt: DateTime.now(),
        ),
        replaceProfile: profile,
      );
      _notifyIfActive();
    } catch (_) {
      activeUrl = previousUrl;
      gatewayCookie = previousCookie;
      api.configure(baseUrl: activeUrl, token: token, cookie: gatewayCookie);
      rethrow;
    }
  }

  Future<String?> _recoverCurrentUrl({CancelToken? cancelToken}) async {
    if (_disposed) throw const _StartupCancelled();
    if (_activeUrlRecovery != null) return _activeUrlRecovery;
    _activeUrlRecovery = _recoverActiveUrl(cancelToken: cancelToken);
    try {
      return await _activeUrlRecovery;
    } finally {
      _activeUrlRecovery = null;
    }
  }

  Future<String?> _recoverActiveUrl({CancelToken? cancelToken}) async {
    final gatewayHost = _gatewayHostForProfile(
      server: serverUrl,
      fnId: fnId,
      mode: serverMode,
    );
    if (gatewayHost != null) {
      await _selectGatewayProfileRoute(
        gatewayHost: gatewayHost,
        cancelToken: cancelToken,
      );
      if (cancelToken?.isCancelled ?? false) {
        throw const _StartupCancelled();
      }
      await _prefs?.setString('active_url', activeUrl);
      await _prefs?.setString(AppState._serverModePrefsKey, serverMode.name);
      api.configure(
        baseUrl: activeUrl,
        token: token,
        cookie:
            serverMode == ServerProfileMode.fnosGateway ? gatewayCookie : null,
      );
      _notifyIfActive();
      return activeUrl;
    }
    try {
      final resolution = await resolveBestServerUrl(
        server: serverUrl,
        localServer: localServerUrl,
        force: true,
        cancelToken: cancelToken,
      );
      if (cancelToken?.isCancelled ?? false) {
        throw const _StartupCancelled();
      }
      activeUrl = resolution.resolvedUrl;
      await _prefs?.setString('active_url', activeUrl);
      api.configure(baseUrl: activeUrl, token: token, cookie: gatewayCookie);
      _notifyIfActive();
      return activeUrl;
    } on _StartupCancelled {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) && (cancelToken?.isCancelled ?? false)) {
        throw const _StartupCancelled();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectActiveUrlForCurrentNetwork({
    bool Function()? isCancelled,
    CancelToken? cancelToken,
  }) async {
    final gatewayHost = _gatewayHostForProfile(
      server: serverUrl,
      fnId: fnId,
      mode: serverMode,
    );
    if (gatewayHost != null) {
      await _selectGatewayProfileRoute(
        gatewayHost: gatewayHost,
        quick: true,
        isCancelled: isCancelled,
        cancelToken: cancelToken,
      );
      return;
    }
    if (serverMode == ServerProfileMode.fnosGateway) return;
    try {
      final resolution = await resolveBestServerUrl(
        server: serverUrl,
        localServer: localServerUrl,
        quick: true,
        cancelToken: cancelToken,
      );
      if ((isCancelled?.call() ?? false) ||
          (cancelToken?.isCancelled ?? false)) {
        throw const _StartupCancelled();
      }
      activeUrl = resolution.resolvedUrl;
      await _prefs?.setString('active_url', activeUrl);
    } on _StartupCancelled {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) && (cancelToken?.isCancelled ?? false)) {
        throw const _StartupCancelled();
      }
      // Keep the last working URL; validation/recovery will handle hard failures.
    } catch (_) {
      // Keep the last working URL; validation/recovery will handle hard failures.
    }
  }

  void _loadFnConnectSettings() {
    final storedOrder = _prefs?.getStringList(AppState._fnConnectOrderPrefsKey);
    final order = <FnConnectCandidateGroup>[];
    for (final name in storedOrder ?? const <String>[]) {
      final group = _fnConnectCandidateGroupFromName(name);
      if (group != null && !order.contains(group)) order.add(group);
    }
    for (final group in defaultFnConnectOrder) {
      if (!order.contains(group)) order.add(group);
    }
    fnConnectOrder = order;

    fnConnectDisabledGroups =
        (_prefs?.getStringList(AppState._fnConnectDisabledPrefsKey) ??
                const <String>[])
            .map(_fnConnectCandidateGroupFromName)
            .whereType<FnConnectCandidateGroup>()
            .toSet();
    if (fnConnectDisabledGroups.length ==
        FnConnectCandidateGroup.values.length) {
      fnConnectDisabledGroups = {};
    }
    fnConnectIgnoreSsl =
        _prefs?.getBool(AppState._fnConnectIgnoreSslPrefsKey) ?? true;
  }

  FnConnectCandidateGroup? _fnConnectCandidateGroupFromName(String name) {
    for (final group in FnConnectCandidateGroup.values) {
      if (group.name == name) return group;
    }
    return null;
  }
}
