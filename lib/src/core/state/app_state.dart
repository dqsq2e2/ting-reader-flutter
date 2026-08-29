import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../auth/fn_connect_client.dart';
import '../auth/fnos_gateway_auth.dart';
import '../api/plugin_capabilities_api.dart';
import '../document_reader/document_reader.dart';
import '../models/models.dart';
import '../utils/client_device_headers.dart';
import '../utils/application_time_zone.dart' as app_time_zone;
import '../utils/locale.dart';
import '../utils/local_network.dart';

part 'app/app_state_models.dart';

bool _isFnosGatewayModeValue(Object? value) {
  final normalized = value
          ?.toString()
          .trim()
          .toLowerCase()
          .replaceAll('_', '')
          .replaceAll('-', '') ??
      '';
  return normalized == 'fnosgateway' || normalized == 'gateway';
}

class AppState extends ChangeNotifier {
  AppState() {
    app_time_zone.initializeApplicationTimeZones();
    api.isGatewaySession = () =>
        serverMode == ServerProfileMode.fnosGateway && fnId.trim().isNotEmpty;
    api.allowBadCertificate =
        () => serverMode == ServerProfileMode.fnosGateway && fnConnectIgnoreSsl;
    api.onGatewaySessionExpired = _handleGatewaySessionExpired;
  }

  final ApiClient api = ApiClient();
  late final PluginCapabilitiesApi pluginCapabilities =
      PluginCapabilitiesApi(api);
  late final DocumentReaderClient documentReader =
      DocumentReaderClient(pluginCapabilities);

  static const _cachedSettingsPrefsKey = 'cached_app_settings';
  static const _localSettingsPrefsKey = 'local_app_settings';
  static const _languagePrefsKey = 'language';
  static const _applicationTimeZonePrefsKey = 'application_time_zone';
  static const _serverModePrefsKey = 'server_mode';
  static const _fnIdPrefsKey = 'fn_id';
  static const _gatewayCookiePrefsKey = 'gateway_cookie';
  static const _gatewayReloginRequiredPrefsKey = 'gateway_relogin_required';
  static const _fnConnectOrderPrefsKey = 'fn_connect_order';
  static const _fnConnectDisabledPrefsKey = 'fn_connect_disabled';
  static const _fnConnectIgnoreSslPrefsKey = 'fn_connect_ignore_ssl';
  static const _localOnlySettingKeys = <String>{
    'ignore_audio_focus',
    'resume_after_interruption',
    'sidebar_collapsed',
  };
  static const _obsoleteLocalSettingKeys = <String>{
    'resume_after_interruption',
  };

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool? _secureCredentialStorageAvailable;
  Map<String, String> _redirectCache = {};
  Future<String?>? _activeUrlRecovery;
  Future<bool>? _gatewaySessionRecovery;
  Future<void> Function()? onGatewayLoginRequired;
  Future<void> Function()? onGatewayLoginRestored;
  CancelToken? _startupCancelToken;
  int _startupGeneration = 0;
  User? user;
  String? token;
  String serverUrl = 'http://localhost:3000';
  String localServerUrl = '';
  String activeUrl = 'http://localhost:3000';
  ServerProfileMode serverMode = ServerProfileMode.direct;
  String fnId = '';
  String? gatewayCookie;
  bool needsGatewayLogin = false;
  Map<String, dynamic> settings = {};
  Locale? locale;
  String? connectionError;
  String? _startupConnectionTarget;
  bool offlineMode = false;
  List<SavedServerProfile> savedServers = [];
  List<FnConnectCandidateGroup> fnConnectOrder = List.of(defaultFnConnectOrder);
  Set<FnConnectCandidateGroup> fnConnectDisabledGroups = {};
  bool fnConnectIgnoreSsl = true;
  bool fnConnectProbing = false;
  List<FnConnectCandidateResult> fnConnectCandidates = const [];
  RedirectResolution? lastRedirectResolution;
  bool resolvingRedirect = false;
  int _pluginExtensionRevision = 0;

  final FnConnectClient fnConnect = FnConnectClient();

  bool get isAuthenticated {
    final currentToken = token?.trim() ?? '';
    final currentUser = user;
    final hasValidUser = currentUser != null &&
        currentUser.id.trim().isNotEmpty &&
        currentUser.username.trim().isNotEmpty &&
        currentUser.role.trim().isNotEmpty;
    return (currentToken.isNotEmpty && hasValidUser) || offlineMode;
  }

  bool get isAdmin => user?.isAdmin ?? false;
  String? get startupConnectionTarget => _startupConnectionTarget;
  String get applicationTimeZone => app_time_zone.applicationTimeZone;
  int get pluginExtensionRevision => _pluginExtensionRevision;

  SavedServerProfile? get savedGatewayProfile {
    final normalizedFnId = _normalizedGatewayIdentity(fnId);
    if (normalizedFnId.isEmpty) {
      return null;
    }
    for (final profile in savedServers) {
      if (_normalizedGatewayIdentity(profile.fnId) == normalizedFnId) {
        return profile;
      }
    }
    return null;
  }

  SavedServerProfile? get activeProfile {
    if (serverMode == ServerProfileMode.fnosGateway && fnId.trim().isNotEmpty) {
      return savedGatewayProfile;
    }
    for (final profile in savedServers) {
      if (profile.mode == ServerProfileMode.direct &&
          _normalizeOptionalServerUrl(profile.serverUrl) ==
              _normalizeOptionalServerUrl(serverUrl) &&
          _normalizeOptionalServerUrl(profile.localServerUrl) ==
              _normalizeOptionalServerUrl(localServerUrl) &&
          profile.username == user?.username) {
        return profile;
      }
    }
    return null;
  }

  bool get fnConnectCurrentIsRelay {
    final cookie = gatewayCookie?.toLowerCase() ?? '';
    return cookie.split(';').any((part) => part.trim() == 'mode=relay');
  }

  String get theme {
    final nested = asMap(settings['settings_json']);
    final value = (settings['theme'] ?? nested['theme'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (value == 'light' || value == 'dark') return value;
    return 'system';
  }

  ThemeMode get themeMode {
    if (theme == 'light') return ThemeMode.light;
    if (theme == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  String get languageCode => locale?.languageCode ?? 'zh';

  bool get isEnglish => languageCode.toLowerCase().startsWith('en');

  bool get sidebarCollapsed => _boolSetting('sidebar_collapsed');

  bool get pluginToolMenuEnabled =>
      _boolSetting('plugin_tool_menu_enabled', fallback: true);

  String textForLocale(String zh, String en) => isEnglish ? en : zh;

  bool _boolSetting(String key, {bool fallback = false}) {
    final nested = asMap(settings['settings_json']);
    final value = settings[key] ?? nested[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return fallback;
  }

  void notifyPluginExtensionsChanged() {
    pluginCapabilities.invalidateClientExtensionsCache();
    _pluginExtensionRevision++;
    notifyListeners();
  }

  Future<void> handleGatewaySessionExpired() async {
    await _handleGatewaySessionExpired();
  }

  Future<bool> _handleGatewaySessionExpired() async {
    final activeRecovery = _gatewaySessionRecovery;
    if (activeRecovery != null) {
      return activeRecovery;
    }

    if (serverMode != ServerProfileMode.fnosGateway ||
        fnId.trim().isEmpty ||
        token == null ||
        token!.trim().isEmpty ||
        offlineMode) {
      return false;
    }

    final recovery = _recoverGatewaySessionSilently();
    _gatewaySessionRecovery = recovery;
    try {
      return await recovery;
    } finally {
      if (identical(_gatewaySessionRecovery, recovery)) {
        _gatewaySessionRecovery = null;
      }
    }
  }

  Future<bool> _recoverGatewaySessionSilently() async {
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
      );
      fnConnectCandidates = result.candidates;
      serverMode = ServerProfileMode.fnosGateway;
      fnId = result.session.relayHost;
      serverUrl = 'https://${result.session.relayHost}';
      activeUrl = result.appBaseUrl;
      gatewayCookie = result.cookie;
      token = null;
      user = null;
      api.configure(baseUrl: activeUrl, token: null, cookie: gatewayCookie);

      final map = await _loginToTingReader(profile.username, profile.password);
      token = map['token']?.toString();
      user = _requireAuthenticatedUser(map['user']);
      api.configure(baseUrl: activeUrl, token: token, cookie: gatewayCookie);
      needsGatewayLogin = false;
      connectionError = null;

      await _persistAuthenticatedGatewayState();
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
      notifyListeners();
      await _notifyGatewayLoginRestored();
      return true;
    } catch (_) {
      await _markGatewayLoginRequired();
      return false;
    }
  }

  Future<void> _persistAuthenticatedGatewayState() async {
    await _prefs?.setString('server_url', serverUrl);
    await _prefs?.setString('local_server_url', localServerUrl);
    await _prefs?.setString('active_url', activeUrl);
    await _prefs?.setString(_serverModePrefsKey, serverMode.name);
    await _prefs?.setString(_fnIdPrefsKey, fnId);
    await _prefs?.setString(_gatewayCookiePrefsKey, gatewayCookie ?? '');
    await _prefs?.setString('auth_token', token ?? '');
    await _prefs?.setString('user', user!.encode());
    await _prefs?.remove(_gatewayReloginRequiredPrefsKey);
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
    await _prefs?.remove('auth_token');
    await _prefs?.remove('user');
    await _prefs?.setBool(_gatewayReloginRequiredPrefsKey, true);
    notifyListeners();
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

  void cancelStartup() {
    _startupGeneration++;
    final cancelToken = _startupCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Startup cancelled');
    }
  }

  Future<void> initialize({bool Function()? isCancelled}) async {
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
      _prefs = await SharedPreferences.getInstance();
      checkCancelled();
      _loadRedirectCache();
      api.recoverBaseUrl = (_, requestCancelToken) =>
          recoverActiveUrl(cancelToken: requestCancelToken);
      final storedServerUrl = _prefs!.getString('server_url');
      final storedLocalServerUrl = _prefs!.getString('local_server_url');
      final storedActiveUrl = _prefs!.getString('active_url');
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
      fnId = _prefs!.getString(_fnIdPrefsKey) ?? fnId;
      gatewayCookie = _prefs!.getString(_gatewayCookiePrefsKey);
      needsGatewayLogin =
          _prefs!.getBool(_gatewayReloginRequiredPrefsKey) ?? false;
      token = _prefs!.getString('auth_token');
      savedServers = await _loadSavedServers();
      _loadFnConnectSettings();
      _loadLocalLanguage();
      _loadCachedSettings();
      _loadLocalApplicationTimeZone();
      notifyListeners();
      api.setClientHeaders(await buildClientDeviceHeaders());
      checkCancelled();
      final hasPersistedServerConfig = _prefs!.containsKey('server_url') ||
          _prefs!.containsKey('local_server_url');

      final rawUser = _prefs!.getString('user');
      if (rawUser != null) {
        try {
          user = _requireAuthenticatedUser(jsonDecode(rawUser));
        } catch (_) {
          user = null;
        }
      }

      final persistedGatewayHost = _gatewayHostForProfile(
        server: serverUrl,
        fnId: fnId,
        mode: serverMode,
      );
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
        await _prefs!.setBool(_gatewayReloginRequiredPrefsKey, true);
      }

      if (persistedGatewayHost != null) {
        await _selectGatewayProfileRoute(
          gatewayHost: persistedGatewayHost,
          quick: true,
          isCancelled: isStartupCancelled,
          cancelToken: cancelToken,
        );
        _startupConnectionTarget = _firstNonEmptyUrl([activeUrl]);
        notifyListeners();
        checkCancelled();
      } else if (token != null && user != null && hasPersistedServerConfig) {
        await _selectActiveUrlForCurrentNetwork(
          isCancelled: isStartupCancelled,
          cancelToken: cancelToken,
        );
        _startupConnectionTarget = _firstNonEmptyUrl([activeUrl]);
        notifyListeners();
        checkCancelled();
      }
      api.configure(
        baseUrl: activeUrl,
        token: token,
        cookie:
            serverMode == ServerProfileMode.fnosGateway ? gatewayCookie : null,
      );

      if (token != null && user != null) {
        await validateConnection(
          recordLogin: true,
          isCancelled: isStartupCancelled,
          cancelToken: cancelToken,
        );
        checkCancelled();
        if (connectionError == null && user != null) {
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

  Future<void> resetToLoginAfterStartupFailure({
    bool requireGatewayLogin = true,
  }) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _loadRedirectCache();
      final storedServerUrl = _prefs!.getString('server_url');
      final storedLocalServerUrl = _prefs!.getString('local_server_url');
      final storedActiveUrl = _prefs!.getString('active_url');
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
      fnId = _prefs!.getString(_fnIdPrefsKey) ?? fnId;
      gatewayCookie = _prefs!.getString(_gatewayCookiePrefsKey);
      final persistedGatewayHost = _gatewayHostForProfile(
        server: serverUrl,
        fnId: fnId,
        mode: serverMode,
      );
      if (persistedGatewayHost != null) fnId = persistedGatewayHost;
      needsGatewayLogin = requireGatewayLogin && persistedGatewayHost != null;
      savedServers = await _loadSavedServers();
      _loadFnConnectSettings();
      await _prefs?.remove('auth_token');
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
      await _prefs?.setBool(_gatewayReloginRequiredPrefsKey, true);
    } else {
      await _prefs?.remove(_gatewayReloginRequiredPrefsKey);
    }
    _loadCachedSettings();
    api.configure(
      baseUrl: activeUrl,
      token: null,
      cookie:
          serverMode == ServerProfileMode.fnosGateway ? gatewayCookie : null,
    );
    notifyListeners();
  }

  Future<void> validateConnection({
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
      await _prefs?.remove(_gatewayReloginRequiredPrefsKey);
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
        await _prefs?.remove('auth_token');
        await _prefs?.remove('user');
        if (needsGatewayLogin) {
          await _prefs?.setBool(_gatewayReloginRequiredPrefsKey, true);
        }
      } else {
        needsGatewayLogin = false;
        await _prefs?.remove(_gatewayReloginRequiredPrefsKey);
      }
      connectionError = textForLocale(
        '连接服务器失败或登录已过期',
        'Failed to connect or session expired',
      );
    }
    notifyListeners();
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
      await _prefs?.setString('auth_token', token ?? '');
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

  Future<SavedServerProfile> rememberServerProfile({
    required String server,
    String localServer = '',
    required String username,
    required String password,
    ServerProfileMode mode = ServerProfileMode.direct,
    String fnId = '',
    String fnosUsername = '',
    String fnosPassword = '',
    String gatewayCookie = '',
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
    );
    await _saveServerProfile(profile, replaceProfile: replaceProfile);
    notifyListeners();
    return profile;
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
        await _prefs?.remove(_gatewayReloginRequiredPrefsKey);
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

  Future<void> login({
    required String server,
    String localServer = '',
    required String username,
    required String password,
    ServerProfileMode mode = ServerProfileMode.direct,
    String fnId = '',
    String fnosUsername = '',
    String fnosPassword = '',
    String? gatewayCookie,
    ValueChanged<FnConnectStage>? onFnConnectStage,
    Future<FnosGatewayLoginResult?> Function()? acquireGatewayLogin,
    SavedServerProfile? replaceProfile,
    Map<String, dynamic> loginSettingsPatch = const {},
  }) async {
    connectionError = null;
    api.setClientHeaders(await buildClientDeviceHeaders());

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
    var usedWebGatewayLogin = false;

    Future<Map<String, dynamic>> loginWithGatewaySession(
      String gatewayHost,
    ) async {
      final localResolution = localServerUrl.isEmpty
          ? null
          : await _tryResolveLocalServer(localServerUrl, quick: true);
      if (localResolution != null) {
        serverMode = ServerProfileMode.direct;
        activeUrl = localResolution.resolvedUrl;
        api.configure(baseUrl: activeUrl, token: null, cookie: null);
        return _loginToTingReader(username, password);
      }

      serverMode = ServerProfileMode.fnosGateway;
      activeUrl = FnosGateway.appUriForHost(gatewayHost).toString();
      api.configure(
        baseUrl: activeUrl,
        token: null,
        cookie: resolvedGatewayCookie.isEmpty ? null : resolvedGatewayCookie,
      );
      try {
        return await _loginToTingReader(username, password);
      } catch (error) {
        if (resolvedGatewayCookie.isNotEmpty &&
            !_shouldRefreshGatewayCookie(error)) {
          rethrow;
        }

        onFnConnectStage?.call(FnConnectStage.webFallback);
        final refreshedLogin = await acquireGatewayLogin?.call();
        if (refreshedLogin == null || refreshedLogin.cookie.trim().isEmpty) {
          throw StateError(textForLocale(
            '飞牛登录已取消或未完成',
            'fnOS login was cancelled or not completed',
          ));
        }
        resolvedGatewayCookie = refreshedLogin.cookie.trim();
        if (FnosGateway.isGatewayHostForFnId(
          this.fnId,
          refreshedLogin.gatewayHost,
        )) {
          final refreshedHost = refreshedLogin.gatewayHost;
          activeUrl = FnosGateway.appUriForHost(refreshedHost).toString();
          serverUrl = FnosGateway.originUriForHost(refreshedHost).toString();
          this.fnId = refreshedHost;
        }
        api.configure(
          baseUrl: activeUrl,
          token: null,
          cookie: resolvedGatewayCookie,
        );
        final result = await _loginToTingReader(username, password);
        usedWebGatewayLogin = true;
        return result;
      }
    }

    if (hasGatewayProfile) {
      final gatewayHost = detectedGatewayHost;
      this.fnId = gatewayHost;
      serverUrl = FnosGateway.originUriForHost(gatewayHost).toString();
      localServerUrl = _normalizeOptionalServerUrl(localServer);

      if (fnosUsername.trim().isNotEmpty && fnosPassword.isNotEmpty) {
        try {
          final result = await fnConnect.loginAndConnect(
            fnId: gatewayHost,
            username: fnosUsername.trim(),
            password: fnosPassword,
            order: fnConnectOrder,
            disabledGroups: fnConnectDisabledGroups,
            ignoreSsl: fnConnectIgnoreSsl,
            onStage: onFnConnectStage,
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
          map = await _loginToTingReader(username, password);
        } on FnConnectAuthenticationException {
          throw StateError(textForLocale(
            '飞牛账号或密码错误',
            'Incorrect fnOS username or password',
          ));
        } on FnConnectProtocolException {
          map = await loginWithGatewaySession(gatewayHost);
        }
      } else {
        map = await loginWithGatewaySession(gatewayHost);
      }
    } else {
      serverUrl = _normalizeOptionalServerUrl(server);
      localServerUrl = _normalizeOptionalServerUrl(localServer);
      final resolution = await resolveBestServerUrl(
        server: serverUrl,
        localServer: localServerUrl,
        force: true,
      );
      activeUrl = resolution.resolvedUrl;
      serverMode = ServerProfileMode.direct;
      this.fnId = '';
      resolvedGatewayCookie = '';
      api.configure(baseUrl: activeUrl, token: null, cookie: null);
      map = await _loginToTingReader(username, password);
    }

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
    needsGatewayLogin = false;

    if (usedWebGatewayLogin) {
      final verifiedUser = await api.get('/api/me');
      user = _requireAuthenticatedUser(verifiedUser.data);
    }

    await _prefs?.setString('server_url', serverUrl);
    await _prefs?.setString('local_server_url', localServerUrl);
    await _prefs?.setString('active_url', activeUrl);
    await _prefs?.setString(_serverModePrefsKey, serverMode.name);
    await _prefs?.setString(_fnIdPrefsKey, this.fnId);
    if (resolvedGatewayCookie.isEmpty) {
      await _prefs?.remove(_gatewayCookiePrefsKey);
    } else {
      await _prefs?.setString(
        _gatewayCookiePrefsKey,
        resolvedGatewayCookie,
      );
    }
    await _prefs?.setString('auth_token', token ?? '');
    await _prefs?.setString('user', user!.encode());
    await _prefs?.remove(_gatewayReloginRequiredPrefsKey);
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
        gatewayCookieAt: hasGatewayProfile && this.gatewayCookie != null
            ? DateTime.now()
            : null,
        lastLoginAt: DateTime.now(),
      ),
      replaceProfile: replaceProfile,
    );
    if (loginSettingsPatch.isEmpty) {
      await loadSettings(silent: true);
    } else {
      try {
        await updateSettings(loginSettingsPatch);
      } catch (_) {
        await loadSettings(silent: true);
        _applySettingsPatch(loginSettingsPatch);
        await _applyLanguageFromSettings();
        await _cacheSettings(settings);
      }
    }
    await loadApplicationTimeZone(silent: true);
    notifyListeners();
    if (resumePlaybackAfterGatewayLogin) {
      await _notifyGatewayLoginRestored();
    }
  }

  Future<Map<String, dynamic>> _loginToTingReader(
    String username,
    String password,
  ) async {
    final response = await api.post(
      '/api/auth/login',
      data: {'username': username, 'password': password},
    );
    final map = asMap(response.data);
    final loginToken = map['token']?.toString().trim() ?? '';
    if (loginToken.isEmpty) {
      throw const _GatewaySessionExpired();
    }
    _requireAuthenticatedUser(map['user']);
    return map;
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

  bool _shouldRefreshGatewayCookie(Object error) {
    if (error is! DioException) return true;
    final status = error.response?.statusCode;
    if (status == 301 ||
        status == 302 ||
        status == 303 ||
        status == 307 ||
        status == 308 ||
        status == 401 ||
        status == 403) {
      return true;
    }
    final data = error.response?.data;
    if (data is Map && data['error'] != null) return false;
    return true;
  }

  Future<void> setFnConnectOrder(List<FnConnectCandidateGroup> order) async {
    final normalized = <FnConnectCandidateGroup>[];
    for (final group in [...order, ...defaultFnConnectOrder]) {
      if (!normalized.contains(group)) normalized.add(group);
    }
    fnConnectOrder = normalized;
    await _prefs?.setStringList(
      _fnConnectOrderPrefsKey,
      normalized.map((group) => group.name).toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> setFnConnectGroupEnabled(
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
      _fnConnectDisabledPrefsKey,
      next.map((item) => item.name).toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> setFnConnectIgnoreSsl(bool value) async {
    fnConnectIgnoreSsl = value;
    await _prefs?.setBool(_fnConnectIgnoreSslPrefsKey, value);
    notifyListeners();
  }

  Future<void> reprobeFnConnect() async {
    if (fnConnectProbing) return;
    final profile = savedGatewayProfile;
    final sessionToken = FnConnectClient.tokenFromCookie(gatewayCookie);
    if (profile == null || sessionToken == null) {
      throw StateError(textForLocale(
        '当前登录方式不支持 FN Connect',
        'The current login does not support FN Connect',
      ));
    }

    fnConnectProbing = true;
    notifyListeners();
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
      );
      final best =
          fnConnectCandidates.where((result) => result.reachable).firstOrNull;
      if (best != null &&
          ApiClient.normalizeServerUrl(best.candidate.appBaseUrl) !=
              ApiClient.normalizeServerUrl(activeUrl)) {
        await switchFnConnectCandidate(best.candidate);
      }
    } finally {
      fnConnectProbing = false;
      notifyListeners();
    }
  }

  Future<void> switchFnConnectCandidate(FnConnectCandidate candidate) async {
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
      await _prefs?.setString(_serverModePrefsKey, serverMode.name);
      await _prefs?.setString(_gatewayCookiePrefsKey, nextCookie);
      await _saveServerProfile(
        profile.copyWith(
          activeUrl: activeUrl,
          mode: ServerProfileMode.fnosGateway,
          gatewayCookie: nextCookie,
          gatewayCookieAt: DateTime.now(),
        ),
        replaceProfile: profile,
      );
      notifyListeners();
    } catch (_) {
      activeUrl = previousUrl;
      gatewayCookie = previousCookie;
      api.configure(baseUrl: activeUrl, token: token, cookie: gatewayCookie);
      rethrow;
    }
  }

  Future<void> enterOfflineMode() async {
    _prefs ??= await SharedPreferences.getInstance();
    offlineMode = true;
    token = null;
    user = const User(
      id: 'offline',
      username: 'Offline User',
      role: 'user',
    );
    connectionError = null;
    _loadCachedSettings();
    api.configure(baseUrl: activeUrl, token: null, cookie: null);
    notifyListeners();
  }

  Future<RedirectResolution> resolveServerUrl(
    String source, {
    bool force = false,
  }) async {
    final normalizedSource = ApiClient.normalizeServerUrl(source);
    if (!force && _redirectCache.containsKey(normalizedSource)) {
      final result = RedirectResolution(
        sourceUrl: normalizedSource,
        resolvedUrl: _redirectCache[normalizedSource]!,
        fromCache: true,
      );
      lastRedirectResolution = result;
      notifyListeners();
      return result;
    }

    resolvingRedirect = true;
    notifyListeners();
    try {
      final resolved = await _probeRedirectTarget(normalizedSource);
      if (resolved == null) {
        throw StateError(textForLocale(
          '无法连接服务器',
          'Unable to connect to server',
        ));
      }
      _redirectCache[normalizedSource] = resolved;
      await _saveRedirectCache();
      final result = RedirectResolution(
        sourceUrl: normalizedSource,
        resolvedUrl: resolved,
        fromCache: false,
      );
      lastRedirectResolution = result;
      return result;
    } finally {
      resolvingRedirect = false;
      notifyListeners();
    }
  }

  Future<RedirectResolution> resolveBestServerUrl({
    required String server,
    required String localServer,
    bool force = false,
    bool quick = false,
    CancelToken? cancelToken,
  }) async {
    void checkCancelled() {
      if (cancelToken?.isCancelled ?? false) {
        throw const _StartupCancelled();
      }
    }

    final candidates = await _serverCandidates(
      server: server,
      localServer: localServer,
    );
    checkCancelled();
    if (candidates.isEmpty) {
      throw StateError(textForLocale(
        '请填写广域网地址或局域网地址',
        'Enter a WAN or LAN server address',
      ));
    }

    resolvingRedirect = true;
    notifyListeners();
    try {
      for (final candidate in candidates) {
        checkCancelled();
        final resolution = await _resolveReachableServerUrl(
          candidate,
          force: force,
          quick: quick,
          cancelToken: cancelToken,
        );
        checkCancelled();
        if (resolution != null) {
          lastRedirectResolution = resolution;
          return resolution;
        }
      }
      throw StateError(textForLocale(
        '无法连接服务器',
        'Unable to connect to server',
      ));
    } finally {
      resolvingRedirect = false;
      notifyListeners();
    }
  }

  Future<String?> recoverActiveUrl({CancelToken? cancelToken}) async {
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
      await _prefs?.setString(_serverModePrefsKey, serverMode.name);
      api.configure(
        baseUrl: activeUrl,
        token: token,
        cookie:
            serverMode == ServerProfileMode.fnosGateway ? gatewayCookie : null,
      );
      notifyListeners();
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
      notifyListeners();
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

  bool usesActiveOrigin(String url) {
    final uri = Uri.tryParse(url);
    final activeUri = Uri.tryParse(activeUrl);
    if (uri == null || activeUri == null) return false;
    if (uri.host.isEmpty || activeUri.host.isEmpty) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return uri.scheme == activeUri.scheme &&
        uri.host == activeUri.host &&
        uri.port == activeUri.port;
  }

  Future<void> logout() async {
    final loginPreferences = <String, dynamic>{
      'language': languageCode,
      'theme': theme,
    };
    token = null;
    user = null;
    offlineMode = false;
    connectionError = null;
    settings = {};
    _applySettingsPatch(loginPreferences);
    needsGatewayLogin = false;
    api.configure(baseUrl: activeUrl, token: null, cookie: null);
    await _prefs?.remove('auth_token');
    await _prefs?.remove('user');
    await _prefs?.remove(_gatewayCookiePrefsKey);
    await _prefs?.remove(_gatewayReloginRequiredPrefsKey);
    await _cacheSettings(settings);
    notifyListeners();
  }

  Future<void> loadSettings({
    bool silent = false,
    bool Function()? isCancelled,
    CancelToken? cancelToken,
  }) async {
    try {
      final res = await api.get('/api/settings', cancelToken: cancelToken);
      if ((isCancelled?.call() ?? false) ||
          (cancelToken?.isCancelled ?? false)) {
        throw const _StartupCancelled();
      }
      settings = asMap(res.data);
      _applyLocalSettings();
      await _applyLanguageFromSettings();
      await _cacheSettings(settings);
    } on _StartupCancelled {
      rethrow;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) && (cancelToken?.isCancelled ?? false)) {
        throw const _StartupCancelled();
      }
      if (!silent) rethrow;
    } catch (_) {
      if (!silent) rethrow;
    }
    notifyListeners();
  }

  /// Reads the administrator-controlled display time zone. The server keeps
  /// timestamps in UTC; this value only changes how the client renders them.
  Future<void> loadApplicationTimeZone({
    bool silent = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await api.get(
        '/api/system/time-zone',
        cancelToken: cancelToken,
      );
      final value = asMap(response.data)['time_zone']?.toString();
      if (value == null ||
          !app_time_zone.isSupportedApplicationTimeZone(value)) {
        return;
      }
      final changed = await _setApplicationTimeZone(value);
      if (changed) notifyListeners();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) && (cancelToken?.isCancelled ?? false)) {
        throw const _StartupCancelled();
      }
      if (!silent) rethrow;
    } catch (_) {
      if (!silent) rethrow;
    }
  }

  /// Updates the application-wide display time zone. Only the server's admin
  /// authorization decides who may persist this value.
  Future<void> updateApplicationTimeZone(String value) async {
    final normalized = value.trim();
    if (!app_time_zone.isSupportedApplicationTimeZone(normalized)) {
      throw ArgumentError.value(value, 'value', 'Unsupported IANA time zone');
    }
    final response = await api.put(
      '/api/system/time-zone',
      data: {'time_zone': normalized},
    );
    final stored = asMap(response.data)['time_zone']?.toString();
    final next = app_time_zone.isSupportedApplicationTimeZone(stored ?? '')
        ? stored!
        : normalized;
    final changed = await _setApplicationTimeZone(next);
    if (changed) notifyListeners();
  }

  Future<void> updateSettings(Map<String, dynamic> patch) async {
    final res = await api.post('/api/settings', data: patch);
    settings = asMap(res.data);
    _applyLocalSettings();
    await _applyLanguageFromSettings();
    await _cacheSettings(settings);
    notifyListeners();
  }

  Future<void> updateLocalSettings(Map<String, dynamic> patch) async {
    _prefs ??= await SharedPreferences.getInstance();
    final normalizedPatch = _normalizeLocalSettingsPatch(patch);
    final local = {
      ..._readLocalSettings(),
      ...normalizedPatch,
    };
    await _prefs?.setString(_localSettingsPrefsKey, jsonEncode(local));
    _applySettingsPatch(normalizedPatch);
    await _cacheSettings(settings);
    notifyListeners();
  }

  void _loadCachedSettings() {
    final raw = _prefs?.getString(_cachedSettingsPrefsKey);
    if (raw == null || raw.isEmpty) {
      _applyLocalSettings();
      return;
    }
    try {
      settings = asMap(jsonDecode(raw));
    } catch (_) {
      settings = {};
    }
    _applyLocalSettings();
    _applyLanguageFromSettingsSync();
  }

  Future<void> _cacheSettings(Map<String, dynamic> value) async {
    await _prefs?.setString(_cachedSettingsPrefsKey, jsonEncode(value));
  }

  void _loadLocalLanguage() {
    final stored = _prefs?.getString(_languagePrefsKey);
    locale = Locale(normalizeLanguage(stored));
    api.setLanguage(languageCode);
  }

  void _loadLocalApplicationTimeZone() {
    app_time_zone.setApplicationTimeZone(
      _prefs?.getString(_applicationTimeZonePrefsKeyForServer),
    );
  }

  Future<bool> _setApplicationTimeZone(String value) async {
    final normalized = app_time_zone.normalizeApplicationTimeZone(value);
    final changed = normalized != applicationTimeZone;
    app_time_zone.setApplicationTimeZone(normalized);
    await _prefs?.setString(_applicationTimeZonePrefsKeyForServer, normalized);
    return changed;
  }

  String get _applicationTimeZonePrefsKeyForServer {
    final gatewayIdentity = _normalizedGatewayIdentity(fnId);
    final identity = gatewayIdentity.isNotEmpty
        ? 'fnos:$gatewayIdentity'
        : 'server:${_normalizeOptionalServerUrl(serverUrl)}';
    return '$_applicationTimeZonePrefsKey:${base64Url.encode(utf8.encode(identity))}';
  }

  Future<void> setLanguage(String value, {bool syncRemote = true}) async {
    final normalized = normalizeLanguage(value);
    locale = Locale(normalized);
    api.setLanguage(normalized);
    await _prefs?.setString(_languagePrefsKey, normalized);
    _applySettingsPatch({'language': normalized});
    await _cacheSettings(settings);
    notifyListeners();
    if (syncRemote && token != null && !offlineMode) {
      try {
        await updateSettings({'language': normalized});
      } catch (_) {
        // Keep the local language choice even if account sync is unavailable.
      }
    }
  }

  Future<void> setTheme(String value, {bool syncRemote = true}) async {
    final normalized = switch (value.trim().toLowerCase()) {
      'light' => 'light',
      'dark' => 'dark',
      _ => 'system',
    };
    _applySettingsPatch({'theme': normalized});
    await _cacheSettings(settings);
    notifyListeners();
    if (syncRemote && token != null && !offlineMode) {
      try {
        await updateSettings({'theme': normalized});
      } catch (_) {
        // Keep the local theme choice even if account sync is unavailable.
      }
    }
  }

  Future<void> _applyLanguageFromSettings() async {
    final next = _languageFromSettings();
    if (next == null) return;
    locale = Locale(next);
    api.setLanguage(next);
    await _prefs?.setString(_languagePrefsKey, next);
  }

  void _applyLanguageFromSettingsSync() {
    final next = _languageFromSettings();
    if (next == null) return;
    locale = Locale(next);
    api.setLanguage(next);
  }

  String? _languageFromSettings() {
    final nested = asMap(settings['settings_json']);
    final value = settings['language'] ?? nested['language'];
    if (value == null) return null;
    return normalizeLanguage(value.toString());
  }

  Map<String, dynamic> _readLocalSettings() {
    final raw = _prefs?.getString(_localSettingsPrefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final local = asMap(jsonDecode(raw));
      for (final key in _obsoleteLocalSettingKeys) {
        local.remove(key);
      }
      final nested = asMap(local['settings_json']);
      if (nested.isNotEmpty) {
        for (final key in _obsoleteLocalSettingKeys) {
          nested.remove(key);
        }
        local['settings_json'] = nested;
      }
      return local;
    } catch (_) {
      return {};
    }
  }

  void _applyLocalSettings() {
    settings = _withoutLocalOnlySettings(settings);
    final local = _normalizeLocalSettingsPatch(_readLocalSettings());
    if (local.isEmpty) return;
    _applySettingsPatch(local);
  }

  Map<String, dynamic> _withoutLocalOnlySettings(Map<String, dynamic> source) {
    final next = {...source};
    for (final key in _localOnlySettingKeys) {
      next.remove(key);
    }
    if (next.containsKey('settings_json')) {
      final nested = {...asMap(next['settings_json'])};
      for (final key in _localOnlySettingKeys) {
        nested.remove(key);
      }
      next['settings_json'] = nested;
    }
    return next;
  }

  void _applySettingsPatch(Map<String, dynamic> patch) {
    settings = {
      ...settings,
      ...patch,
    };
    const nestedKey = 'settings_json';
    final nested = {
      ...asMap(settings[nestedKey]),
      ...patch,
    };
    settings[nestedKey] = nested;
  }

  Map<String, dynamic> _normalizeLocalSettingsPatch(
    Map<String, dynamic> patch,
  ) {
    final normalized = {...patch};
    return normalized;
  }

  String? _firstNonEmptyUrl(Iterable<String?> values) {
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  Future<void> updateCurrentUser(User next) async {
    user = next;
    await _prefs?.setString('user', next.encode());
    notifyListeners();
  }

  void _loadRedirectCache() {
    final raw = _prefs?.getString('redirect_cache');
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _redirectCache = decoded.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    } catch (_) {
      _redirectCache = {};
    }
  }

  Future<void> _saveRedirectCache() async {
    await _prefs?.setString('redirect_cache', jsonEncode(_redirectCache));
  }

  void _loadFnConnectSettings() {
    final storedOrder = _prefs?.getStringList(_fnConnectOrderPrefsKey);
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
        (_prefs?.getStringList(_fnConnectDisabledPrefsKey) ?? const <String>[])
            .map(_fnConnectCandidateGroupFromName)
            .whereType<FnConnectCandidateGroup>()
            .toSet();
    if (fnConnectDisabledGroups.length ==
        FnConnectCandidateGroup.values.length) {
      fnConnectDisabledGroups = {};
    }
    fnConnectIgnoreSsl = _prefs?.getBool(_fnConnectIgnoreSslPrefsKey) ?? true;
  }

  FnConnectCandidateGroup? _fnConnectCandidateGroupFromName(String name) {
    for (final group in FnConnectCandidateGroup.values) {
      if (group.name == name) return group;
    }
    return null;
  }

  Future<List<SavedServerProfile>> _loadSavedServers() async {
    final raw = _prefs?.getString('saved_servers');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
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
      if (_secureCredentialStorageAvailable == true &&
          profiles.any(
            (profile) =>
                profile.password.isNotEmpty || profile.fnosPassword.isNotEmpty,
          )) {
        await _persistSavedServers(hydrated);
      }
      return hydrated;
    } catch (_) {
      return const [];
    }
  }

  Future<SavedServerProfile> _hydrateServerProfileSecrets(
    SavedServerProfile profile,
  ) async {
    try {
      final key = _serverProfileSecretKey(profile);
      final storedPassword = await _secureStorage.read(key: '$key.tr');
      final storedFnosPassword = await _secureStorage.read(key: '$key.fnos');
      final password = storedPassword ?? profile.password;
      final fnosPassword = storedFnosPassword ?? profile.fnosPassword;
      if (storedPassword == null && profile.password.isNotEmpty) {
        await _secureStorage.write(key: '$key.tr', value: profile.password);
      }
      if (storedFnosPassword == null && profile.fnosPassword.isNotEmpty) {
        await _secureStorage.write(
          key: '$key.fnos',
          value: profile.fnosPassword,
        );
      }
      _secureCredentialStorageAvailable = true;
      return profile.copyWith(
        password: password,
        fnosPassword: fnosPassword,
      );
    } catch (_) {
      _secureCredentialStorageAvailable = false;
      return profile;
    }
  }

  Future<void> _storeServerProfileSecrets(
    SavedServerProfile profile, {
    SavedServerProfile? replaceProfile,
  }) async {
    try {
      final key = _serverProfileSecretKey(profile);
      await _secureStorage.write(key: '$key.tr', value: profile.password);
      if (profile.fnosPassword.isEmpty) {
        await _secureStorage.delete(key: '$key.fnos');
      } else {
        await _secureStorage.write(
          key: '$key.fnos',
          value: profile.fnosPassword,
        );
      }
      if (replaceProfile != null) {
        final replacedKey = _serverProfileSecretKey(replaceProfile);
        if (replacedKey != key) {
          await _secureStorage.delete(key: '$replacedKey.tr');
          await _secureStorage.delete(key: '$replacedKey.fnos');
        }
      }
      _secureCredentialStorageAvailable = true;
    } catch (_) {
      _secureCredentialStorageAvailable = false;
    }
  }

  Future<void> _deleteServerProfileSecrets(SavedServerProfile profile) async {
    try {
      final key = _serverProfileSecretKey(profile);
      await _secureStorage.delete(key: '$key.tr');
      await _secureStorage.delete(key: '$key.fnos');
    } catch (_) {
      // The profile is still deleted when a platform keychain is unavailable.
    }
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
    final includeSecrets = _secureCredentialStorageAvailable == false;
    await _prefs?.setString(
      'saved_servers',
      jsonEncode(
        profiles
            .map((item) => item.toJson(includeSecrets: includeSecrets))
            .toList(),
      ),
    );
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
    savedServers = next.take(8).toList();
    await _storeServerProfileSecrets(
      profile,
      replaceProfile: replaceProfile,
    );
    await _persistSavedServers(savedServers);
  }

  Future<void> deleteSavedServerProfile(SavedServerProfile profile) async {
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
    await _deleteServerProfileSecrets(profile);
    await _persistSavedServers(savedServers);
    notifyListeners();
  }

  Future<List<String>> _serverCandidates({
    required String server,
    required String localServer,
  }) async {
    final wideArea = _normalizeOptionalServerUrl(server);
    final localArea = _normalizeOptionalServerUrl(localServer);
    if (localArea.isEmpty) return wideArea.isEmpty ? const [] : [wideArea];
    if (wideArea.isEmpty) return [localArea];
    if (wideArea == localArea) return [localArea];

    final sameSubnet = await isServerOnCurrentIpv4Subnet(localArea);
    return sameSubnet == false ? [wideArea, localArea] : [localArea, wideArea];
  }

  String _normalizeOptionalServerUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    return ApiClient.normalizeServerUrl(trimmed);
  }

  ServerProfileMode _serverProfileModeFromPrefs() {
    final value = _prefs?.getString(_serverModePrefsKey);
    return _isFnosGatewayModeValue(value)
        ? ServerProfileMode.fnosGateway
        : ServerProfileMode.direct;
  }

  Future<RedirectResolution?> _resolveReachableServerUrl(
    String normalizedSource, {
    required bool force,
    bool quick = false,
    CancelToken? cancelToken,
  }) async {
    void checkCancelled() {
      if (cancelToken?.isCancelled ?? false) {
        throw const _StartupCancelled();
      }
    }

    if (normalizedSource.isEmpty) return null;

    final cached = _redirectCache[normalizedSource];
    if (!force && cached != null && cached.isNotEmpty) {
      final resolved = await _probeRedirectTarget(
        normalizedSource,
        quick: quick,
        cancelToken: cancelToken,
      );
      checkCancelled();
      if (resolved != null) {
        _redirectCache[normalizedSource] = resolved;
        await _saveRedirectCache();
        return RedirectResolution(
          sourceUrl: normalizedSource,
          resolvedUrl: resolved,
          fromCache: resolved == cached,
        );
      }

      if (cached != normalizedSource) {
        final reachable = await _probeRedirectTarget(
          cached,
          quick: quick,
          cancelToken: cancelToken,
        );
        checkCancelled();
        if (reachable != null) {
          return RedirectResolution(
            sourceUrl: normalizedSource,
            resolvedUrl: cached,
            fromCache: true,
          );
        }
      }

      _redirectCache.remove(normalizedSource);
      await _saveRedirectCache();
      return null;
    }

    final resolved = await _probeRedirectTarget(
      normalizedSource,
      quick: quick,
      cancelToken: cancelToken,
    );
    checkCancelled();
    if (resolved == null) return null;
    _redirectCache[normalizedSource] = resolved;
    await _saveRedirectCache();
    return RedirectResolution(
      sourceUrl: normalizedSource,
      resolvedUrl: resolved,
      fromCache: false,
    );
  }

  Future<String?> _probeRedirectTarget(
    String sourceUrl, {
    bool quick = false,
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const _StartupCancelled();
    }
    final dio = Dio(
      BaseOptions(
        connectTimeout:
            quick ? const Duration(seconds: 3) : const Duration(seconds: 8),
        receiveTimeout:
            quick ? const Duration(seconds: 4) : const Duration(seconds: 12),
        followRedirects: true,
        maxRedirects: 8,
        validateStatus: (_) => true,
      ),
    );

    for (final path in ['/api/health', '/api/me']) {
      try {
        final response = await dio.getUri<dynamic>(
          Uri.parse('$sourceUrl$path'),
          options: Options(responseType: ResponseType.plain),
          cancelToken: cancelToken,
        );
        if (_isBackendProbeResponse(path, response)) {
          return ApiClient.originFromUri(response.realUri);
        }
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) rethrow;
        // Try the next probe path.
      } catch (_) {
        // Try the next probe path.
      }
    }

    return null;
  }

  bool _isBackendProbeResponse(String path, Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (path == '/api/health') {
      if (status < 200 || status >= 300) return false;
      final data = response.data;
      if (data is Map) {
        return data['status']?.toString().toLowerCase() == 'healthy';
      }
      final text = data?.toString() ?? '';
      return text.contains('"status"') && text.contains('healthy');
    }
    return status == 401 || status == 403;
  }
}
