part of '../app_state.dart';

extension _AppSessionRecovery on AppState {
  void _cancelDirectSessionRecovery() {
    _directRecoveryGeneration++;
    _directRecoveryCancelToken?.cancel('会话已切换');
    _directRecoveryCancelToken = null;
    _directSessionRecovery = null;
    _directRetryAfter = null;
    _directRetryIdentity = null;
    _sessionMonitor.cancel();
  }

  Future<bool> _handleDirectSessionExpired() async {
    if (_disposed ||
        offlineMode ||
        serverMode != ServerProfileMode.direct ||
        user == null ||
        (token?.isEmpty ?? true)) {
      return false;
    }
    final existing = _directSessionRecovery;
    if (existing != null) return existing;
    final identity = _sessionIdentity;
    if (_directRetryIdentity == identity &&
        (_directRetryAfter?.isAfter(DateTime.now()) ?? false)) {
      return false;
    }
    final cancellation = CancelToken();
    _directRecoveryCancelToken = cancellation;
    final recovery = _recoverDirectSession(cancellation);
    _directSessionRecovery = recovery;
    try {
      return await recovery;
    } finally {
      if (identical(_directSessionRecovery, recovery)) {
        _directSessionRecovery = null;
        _directRecoveryCancelToken = null;
      }
    }
  }

  Future<bool> _recoverDirectSession(CancelToken cancellation) async {
    final identity = _sessionIdentity;
    final generation = _directRecoveryGeneration;
    final expiredToken = token;
    final userId = user!.id;
    bool current() =>
        !_disposed &&
        !cancellation.isCancelled &&
        !offlineMode &&
        generation == _directRecoveryGeneration &&
        identity == _sessionIdentity;
    final profile = activeProfile;
    if (profile == null || profile.password.isEmpty) {
      await _requireDirectLogin(cancellation);
      return false;
    }
    // 独立客户端登录，避免并发请求临时丢失旧 token，也避免递归重登。
    final loginApi = ApiClient()
      ..configure(baseUrl: activeUrl)
      ..setLanguage(languageCode)
      ..setClientHeaders(api.clientHeaders);
    try {
      final response = await loginApi.post('/api/auth/login',
          data: {'username': profile.username, 'password': profile.password},
          cancelToken: cancellation);
      if (!current() || token != expiredToken) return false;
      final data = asMap(response.data);
      final renewedToken = data['token']?.toString().trim() ?? '';
      final renewedUser = _requireAuthenticatedUser(data['user']);
      if (renewedToken.isEmpty || renewedUser.id != userId) {
        await _requireDirectLogin(cancellation);
        return false;
      }
      _prefs ??= await SharedPreferences.getInstance();
      if (!current() || token != expiredToken) return false;
      final secretKey = _sessionSecretKey();
      await _credentials
          .write(secretKey, {'token': renewedToken, 'cookie': ''});
      if (!current() || token != expiredToken) return false;
      token = renewedToken;
      user = renewedUser;
      api.configure(baseUrl: activeUrl, token: renewedToken);
      await _prefs?.setString(
          _AppStateCredentials._sessionScopePrefsKey, secretKey);
      if (!current() || token != renewedToken) return false;
      await _prefs?.setString('user', renewedUser.encode());
      if (!current() || token != renewedToken) return false;
      await _prefs
          ?.remove(_AppStateCredentials._sessionRestoreDisabledPrefsKey);
      if (!current() || token != renewedToken) return false;
      needsDirectLogin = false;
      connectionError = null;
      _directRetryAfter = null;
      _directRetryIdentity = null;
      // token 更新后复用播放器恢复流程，保留曲目和暂停状态。
      await _notifyGatewayLoginRequired();
      if (!current() || token != renewedToken) return false;
      _notifyIfActive();
      await _notifyGatewayLoginRestored();
      return current();
    } on DioException catch (failure) {
      if (!current()) return false;
      final status = failure.response?.statusCode;
      if (status == 401 || status == 403) {
        await _requireDirectLogin(cancellation);
      } else {
        // 超时、断网和服务端错误不等于密码失效，保留会话并限速重试。
        _directRetryIdentity = identity;
        _directRetryAfter = DateTime.now().add(const Duration(seconds: 30));
      }
      return false;
    } catch (_) {
      if (current()) {
        _directRetryIdentity = identity;
        _directRetryAfter = DateTime.now().add(const Duration(seconds: 30));
      }
      return false;
    } finally {
      loginApi.close();
    }
  }

  Future<void> _requireDirectLogin(CancelToken cancellation) async {
    final identity = _sessionIdentity;
    await _notifyGatewayLoginRequired();
    if (_disposed || cancellation.isCancelled || identity != _sessionIdentity) {
      return;
    }
    needsDirectLogin = true;
    connectionError = textForLocale('登录已过期，请重新登录；无需退出客户端。',
        'Your session expired. Sign in again without restarting the app.');
    try {
      final key = _sessionSecretKey();
      final stored = await _credentials.read(key);
      if (_disposed ||
          cancellation.isCancelled ||
          identity != _sessionIdentity) {
        return;
      }
      if (stored != null) {
        await _credentials.write(key, {...stored, 'token': ''});
      }
      if (_disposed ||
          cancellation.isCancelled ||
          identity != _sessionIdentity) {
        return;
      }
      await _prefs?.remove('auth_token');
    } catch (_) {
      // 安全存储暂不可用时，仍允许在应用内重新登录。
    }
    if (_disposed || cancellation.isCancelled || identity != _sessionIdentity) {
      return;
    }
    token = null;
    user = null;
    api.configure(baseUrl: activeUrl);
    await _prefs?.remove('user');
    _notifyIfActive();
  }
}
