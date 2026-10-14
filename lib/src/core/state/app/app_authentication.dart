part of '../app_state.dart';

/// Account login, validation, offline entry and logout workflows.
extension _AppAuthentication on AppState {
  /// One interactive workflow for gateway normalization and access-code
  /// challenges. The view supplies prompts without implementing retry policy.
  Future<void> _loginWithPrompts(
    SavedServerProfile profile, {
    SavedServerProfile? replaceProfile,
    Map<String, dynamic> settingsPatch = const {},
    Future<String?> Function(bool incorrect)? requestAccessCode,
    Future<FnTwofaAnswer?> Function()? requestTwofa,
    ValueChanged<FnConnectStage>? onStage,
    CancelToken? cancelToken,
  }) async {
    final gateway = FnosGateway.tryGatewayHostFromInput(profile.serverUrl) ??
        (profile.isFnosGateway && profile.fnId.trim().isNotEmpty
            ? FnosGateway.hostForFnId(profile.fnId)
            : '');
    var code = profile.fnAccessCode;
    while (true) {
      if (cancelToken?.isCancelled ?? false) {
        throw DioException.requestCancelled(
            requestOptions: RequestOptions(path: '/api/auth/login'),
            reason: 'Login cancelled');
      }
      var incorrect = false;
      try {
        await login(
            server: profile.serverUrl,
            localServer: profile.localServerUrl,
            username: profile.username,
            password: profile.password,
            mode: gateway.isEmpty
                ? ServerProfileMode.direct
                : ServerProfileMode.fnosGateway,
            fnId: gateway,
            fnosUsername: profile.fnosUsername,
            fnosPassword: profile.fnosPassword,
            gatewayCookie: profile.gatewayCookie,
            fnAccessCode: code.isEmpty ? null : code,
            onTwofaRequired: requestTwofa,
            onFnConnectStage: onStage,
            replaceProfile: replaceProfile,
            loginSettingsPatch: settingsPatch,
            cancelToken: cancelToken);
        return;
      } on FnConnectAccessCodeRequiredException {
        if (requestAccessCode == null) rethrow;
      } on FnConnectAccessCodeException {
        if (requestAccessCode == null) rethrow;
        incorrect = true;
      }
      if (cancelToken?.isCancelled ?? false) continue;
      final next = await requestAccessCode(incorrect);
      if (cancelToken?.isCancelled ?? false) continue;
      if (next == null || next.trim().isEmpty) {
        throw const FnConnectAccessCodeRequiredException();
      }
      code = next.trim();
    }
  }

  Future<void> _validateSession({
    bool recordLogin = false,
    bool Function()? isCancelled,
    CancelToken? cancelToken,
  }) async {
    void checkCancelled() {
      if ((isCancelled?.call() ?? false) ||
          (cancelToken?.isCancelled ?? false)) {
        throw const _StartupCancelled();
      }
    }

    connectionError = null;
    try {
      if (recordLogin) {
        await _restoreSessionWithLoginAudit(
          isCancelled: isCancelled,
          cancelToken: cancelToken,
        );
      } else {
        final res = await api.get('/api/me', cancelToken: cancelToken);
        checkCancelled();
        user = _requireAuthenticatedUser(res.data);
      }
      checkCancelled();
      await _prefs?.setString('user', user!.encode());
      needsGatewayLogin = false;
      await _prefs?.remove(AppState._gatewayReloginRequiredPrefsKey);
    } on _StartupCancelled {
      rethrow;
    } catch (error) {
      if (error is DioException &&
          CancelToken.isCancel(error) &&
          (cancelToken?.isCancelled ?? false)) {
        throw const _StartupCancelled();
      }
      if (serverMode == ServerProfileMode.fnosGateway) {
        needsGatewayLogin = fnId.trim().isNotEmpty;
        token = null;
        user = null;
        api.configure(
          baseUrl: activeUrl,
          token: null,
          cookie: gatewayCookie,
        );
        await _clearPersistedToken();
        await _prefs?.remove('user');
        if (needsGatewayLogin) {
          await _prefs?.setBool(AppState._gatewayReloginRequiredPrefsKey, true);
        }
      } else {
        needsGatewayLogin = false;
        await _prefs?.remove(AppState._gatewayReloginRequiredPrefsKey);
      }
      connectionError = textForLocale(
        '连接服务器失败或登录已过期',
        'Failed to connect or session expired',
      );
    }
    _notifyIfActive();
  }

  Future<void> _restoreSessionWithLoginAudit({
    bool Function()? isCancelled,
    CancelToken? cancelToken,
  }) async {
    void checkCancelled() {
      if ((isCancelled?.call() ?? false) ||
          (cancelToken?.isCancelled ?? false)) {
        throw const _StartupCancelled();
      }
    }

    final currentToken = token;
    if (currentToken == null || currentToken.isEmpty) {
      throw StateError('missing token');
    }

    try {
      final res = await api.post(
        '/api/auth/token-login',
        data: {'token': currentToken},
        cancelToken: cancelToken,
      );
      checkCancelled();
      final map = asMap(res.data);
      token = map['token']?.toString() ?? currentToken;
      user = _requireAuthenticatedUser(map['user']);
      api.configure(
        baseUrl: activeUrl,
        token: token,
        cookie:
            serverMode == ServerProfileMode.fnosGateway ? gatewayCookie : null,
      );
      await _persistSessionCredentials();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) && (cancelToken?.isCancelled ?? false)) {
        throw const _StartupCancelled();
      }
      final status = error.response?.statusCode;
      if (status != 404 && status != 405) rethrow;
      final res = await api.get('/api/me', cancelToken: cancelToken);
      checkCancelled();
      user = _requireAuthenticatedUser(res.data);
    }
  }

  Future<void> _loginSession({
    required String server,
    String localServer = '',
    required String username,
    required String password,
    ServerProfileMode mode = ServerProfileMode.direct,
    String fnId = '',
    String fnosUsername = '',
    String fnosPassword = '',
    String? gatewayCookie,
    String? fnAccessCode,
    Future<FnTwofaAnswer?> Function()? onTwofaRequired,
    ValueChanged<FnConnectStage>? onFnConnectStage,
    SavedServerProfile? replaceProfile,
    Map<String, dynamic> loginSettingsPatch = const {},
    CancelToken? cancelToken,
  }) async {
    _throwIfLoginCancelled(cancelToken);
    connectionError = null;
    api.setClientHeaders(await buildClientDeviceHeaders());
    _throwIfLoginCancelled(cancelToken);

    final detectedGatewayHost = _gatewayHostForProfile(
      server: server,
      fnId: fnId,
      mode: mode,
    );
    final hasGatewayProfile = detectedGatewayHost != null;
    final resumePlaybackAfterGatewayLogin =
        hasGatewayProfile && needsGatewayLogin;
    Map<String, dynamic> map;
    var resolvedGatewayCookie = gatewayCookie?.trim() ?? '';
    // 访问码来源优先级：本次登录输入 > 被替换/编辑的配置中已保存的值。
    var resolvedAccessCode = (fnAccessCode?.trim().isNotEmpty == true)
        ? fnAccessCode!.trim()
        : (replaceProfile?.fnAccessCode.trim() ?? '');

    Future<Map<String, dynamic>> loginWithGatewaySession(
      String gatewayHost,
    ) async {
      final localResolution = localServerUrl.isEmpty
          ? null
          : await _tryResolveLocalServer(
              localServerUrl,
              quick: true,
              cancelToken: cancelToken,
            );
      _throwIfLoginCancelled(cancelToken);
      if (localResolution != null) {
        serverMode = ServerProfileMode.direct;
        activeUrl = localResolution.resolvedUrl;
        api.configure(baseUrl: activeUrl, token: null, cookie: null);
        return _loginToTingReader(
          username,
          password,
          cancelToken: cancelToken,
        );
      }

      serverMode = ServerProfileMode.fnosGateway;
      activeUrl = FnosGateway.appUriForHost(gatewayHost).toString();
      api.configure(
        baseUrl: activeUrl,
        token: null,
        cookie: resolvedGatewayCookie.isEmpty ? null : resolvedGatewayCookie,
      );
      // 不再提供 WebView 登录回退：网关会话失效时直接把原始错误抛给调用方，
      // 让登录问题暴露出来，而不是被内嵌登录页掩盖。
      return _loginToTingReader(
        username,
        password,
        cancelToken: cancelToken,
      );
    }

    if (hasGatewayProfile) {
      final gatewayHost = detectedGatewayHost;
      this.fnId = gatewayHost;
      serverUrl = FnosGateway.originUriForHost(gatewayHost).toString();
      localServerUrl = _normalizeOptionalServerUrl(localServer);
      // 访问码头要赶在 TR 应用层登录（/api/auth/login）之前生效：
      // 该请求同样穿过统一网关，缺少 x-access-code 会被网关 401 拦下。
      api.setGatewayExtraHeaders(
        resolvedAccessCode.isNotEmpty
            ? FnAccessCode.headers(resolvedAccessCode)
            : const {},
      );

      if (fnosUsername.trim().isNotEmpty && fnosPassword.isNotEmpty) {
        try {
          final result = await fnConnect.loginAndConnect(
            fnId: gatewayHost,
            username: fnosUsername.trim(),
            password: fnosPassword,
            order: fnConnectOrder,
            disabledGroups: fnConnectDisabledGroups,
            ignoreSsl: fnConnectIgnoreSsl,
            accessCode: resolvedAccessCode.isEmpty ? null : resolvedAccessCode,
            deviceId: await _fnDeviceDid(),
            onTwofaRequired: onTwofaRequired,
            onStage: onFnConnectStage,
            cancelToken: cancelToken,
          );
          fnConnectCandidates = result.candidates;
          this.fnId = result.session.relayHost;
          serverUrl = 'https://${result.session.relayHost}';
          activeUrl = result.appBaseUrl;
          serverMode = ServerProfileMode.fnosGateway;
          resolvedGatewayCookie = result.cookie;
          api.configure(
            baseUrl: activeUrl,
            token: null,
            cookie: resolvedGatewayCookie,
          );
          onFnConnectStage?.call(FnConnectStage.tingReaderLogin);
          map = await _loginToTingReader(
            username,
            password,
            cancelToken: cancelToken,
          );
        } on FnConnectAccessCodeRequiredException {
          // 访问码相关错误必须原样上抛：登录页凭类型弹出访问码输入框。
          rethrow;
        } on FnConnectAccessCodeException {
          rethrow;
        } on FnConnectTwofaInvalidException {
          throw StateError(textForLocale(
            '二步验证码错误或已过期，请重新登录并输入新的动态验证码',
            'The two-step code is wrong or expired. Sign in again with a fresh code',
          ));
        } on FnConnectTwofaRequiredException {
          rethrow;
        } on FnConnectTwofaSetupRequiredException {
          rethrow;
        } on FnConnectTwofaCancelledException {
          rethrow;
        } on FnConnectAuthenticationException {
          throw StateError(textForLocale(
            '飞牛账号或密码错误',
            'Incorrect fnOS username or password',
          ));
        } on FnConnectProtocolException {
          // A failed fnOS handshake/probe did not establish a usable session.
          // Falling back with an empty or stale cookie hides it behind HTTP 302.
          rethrow;
        }
      } else {
        _throwIfLoginCancelled(cancelToken);
        map = await loginWithGatewaySession(gatewayHost);
      }
    } else {
      serverUrl = _normalizeOptionalServerUrl(server);
      localServerUrl = _normalizeOptionalServerUrl(localServer);
      final resolution = await resolveBestServerUrl(
        server: serverUrl,
        localServer: localServerUrl,
        force: true,
        cancelToken: cancelToken,
      );
      activeUrl = resolution.resolvedUrl;
      serverMode = ServerProfileMode.direct;
      this.fnId = '';
      resolvedGatewayCookie = '';
      api.configure(baseUrl: activeUrl, token: null, cookie: null);
      map = await _loginToTingReader(
        username,
        password,
        cancelToken: cancelToken,
      );
    }

    _throwIfLoginCancelled(cancelToken);
    token = map['token']?.toString();
    user = _requireAuthenticatedUser(map['user']);
    this.gatewayCookie = hasGatewayProfile && resolvedGatewayCookie.isNotEmpty
        ? resolvedGatewayCookie
        : null;
    api.configure(
      baseUrl: activeUrl,
      token: token,
      cookie: serverMode == ServerProfileMode.fnosGateway
          ? this.gatewayCookie
          : null,
    );
    // 访问码头与 token/cookie 解耦：整个网关会话期间所有请求
    // （含原生音频流）都要携带；直连模式清空。
    api.setGatewayExtraHeaders(
      hasGatewayProfile && resolvedAccessCode.isNotEmpty
          ? FnAccessCode.headers(resolvedAccessCode)
          : const {},
    );
    needsGatewayLogin = false;

    _throwIfLoginCancelled(cancelToken);
    _prefs ??= await SharedPreferences.getInstance();
    await _persistSessionCredentials();
    await _prefs?.setString('server_url', serverUrl);
    await _prefs?.setString('local_server_url', localServerUrl);
    await _prefs?.setString('active_url', activeUrl);
    await _prefs?.setString(AppState._serverModePrefsKey, serverMode.name);
    await _prefs?.setString(AppState._fnIdPrefsKey, this.fnId);
    await _prefs?.setString('user', user!.encode());
    await _prefs?.remove(AppState._gatewayReloginRequiredPrefsKey);
    await _saveServerProfile(
      SavedServerProfile(
        serverUrl: serverUrl,
        localServerUrl: localServerUrl,
        activeUrl: activeUrl,
        username: username,
        password: password,
        label: username,
        mode: hasGatewayProfile
            ? ServerProfileMode.fnosGateway
            : ServerProfileMode.direct,
        fnId: hasGatewayProfile ? this.fnId : '',
        fnosUsername: hasGatewayProfile ? fnosUsername.trim() : '',
        fnosPassword: hasGatewayProfile ? fnosPassword : '',
        gatewayCookie: hasGatewayProfile ? (this.gatewayCookie ?? '') : '',
        fnAccessCode: hasGatewayProfile ? resolvedAccessCode : '',
        gatewayCookieAt: hasGatewayProfile && this.gatewayCookie != null
            ? DateTime.now()
            : null,
        lastLoginAt: DateTime.now(),
      ),
      replaceProfile: replaceProfile,
    );
    _throwIfLoginCancelled(cancelToken);
    if (loginSettingsPatch.isEmpty) {
      await loadSettings(
        silent: true,
        cancelToken: cancelToken,
      );
    } else {
      try {
        await updateSettings(
          loginSettingsPatch,
          cancelToken: cancelToken,
        );
      } catch (_) {
        _throwIfLoginCancelled(cancelToken);
        await loadSettings(
          silent: true,
          cancelToken: cancelToken,
        );
        _preferences._applySettingsPatch(loginSettingsPatch);
        await _preferences._applyLanguageFromSettings();
        await _preferences._cacheSettings(settings);
      }
    }
    await loadApplicationTimeZone(
      silent: true,
      cancelToken: cancelToken,
    );
    _throwIfLoginCancelled(cancelToken);
    _notifyIfActive();
    if (resumePlaybackAfterGatewayLogin) {
      await _notifyGatewayLoginRestored();
    }
  }

  Future<Map<String, dynamic>> _loginToTingReader(
    String username,
    String password, {
    CancelToken? cancelToken,
  }) async {
    _throwIfLoginCancelled(cancelToken);
    final response = await api.post(
      '/api/auth/login',
      data: {'username': username, 'password': password},
      cancelToken: cancelToken,
    );
    _throwIfLoginCancelled(cancelToken);
    final map = asMap(response.data);
    final loginToken = map['token']?.toString().trim() ?? '';
    if (loginToken.isEmpty) {
      throw const _GatewaySessionExpired();
    }
    _requireAuthenticatedUser(map['user']);
    return map;
  }

  void _throwIfLoginCancelled(CancelToken? cancelToken) {
    if (cancelToken?.isCancelled ?? false) {
      throw cancelToken!.cancelError ??
          DioException.requestCancelled(
            requestOptions: RequestOptions(),
            reason: 'Login cancelled',
          );
    }
  }

  User _requireAuthenticatedUser(Object? value) {
    final map = asMap(value);
    final id = map['id']?.toString().trim() ?? '';
    final username = map['username']?.toString().trim() ?? '';
    final role = map['role']?.toString().trim() ?? '';
    if (id.isEmpty || username.isEmpty || role.isEmpty) {
      // fnOS Connect can return the frontend HTML with HTTP 200 when its
      // gateway session has expired. Do not turn that HTML into an empty User;
      // it must follow the normal gateway re-login path.
      throw const _GatewaySessionExpired();
    }
    return User.fromJson(map);
  }

  Future<void> _enterOfflineSession() async {
    _prefs ??= await SharedPreferences.getInstance();
    offlineMode = true;
    token = null;
    user = const User(
      id: 'offline',
      username: 'Offline User',
      role: 'user',
    );
    connectionError = null;
    _preferences._loadCachedSettings();
    api.configure(baseUrl: activeUrl, token: null, cookie: null);
    _notifyIfActive();
  }

  Future<void> _logoutSession() async {
    final loginPreferences = <String, dynamic>{
      'language': languageCode,
      'theme': theme,
    };
    token = null;
    user = null;
    offlineMode = false;
    connectionError = null;
    settings = {};
    _preferences._applySettingsPatch(loginPreferences);
    needsGatewayLogin = false;
    api.configure(baseUrl: activeUrl, token: null, cookie: null);
    api.setGatewayExtraHeaders(const {});
    await _clearPersistedSession();
    await _prefs?.remove('user');
    gatewayCookie = null;
    await _prefs?.remove(AppState._gatewayReloginRequiredPrefsKey);
    await _preferences._cacheSettings(settings);
    _notifyIfActive();
  }
}
