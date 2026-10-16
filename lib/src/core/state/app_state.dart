import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/api_error.dart';
import '../auth/fn_access_code.dart';
import '../auth/credential_store.dart';
import '../auth/fn_connect_client.dart';
import '../auth/fnos_gateway_auth.dart';
import '../api/plugin_capabilities_api.dart';
import '../document_reader/document_reader.dart';
import '../plugin_extensions/registry.dart';
import '../models/models.dart';
import '../utils/client_device_headers.dart';
import '../utils/application_time_zone.dart' as app_time_zone;
import '../utils/locale.dart';
import '../utils/local_network.dart';

part 'app/app_state_models.dart';
part 'app/app_state_credentials.dart';
part 'app/app_preferences.dart';
part 'app/app_connection_resolver.dart';
part 'app/app_startup.dart';
part 'app/app_authentication.dart';
part 'app/app_gateway.dart';

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
  AppState({FnConnectClient? fnConnect, FlutterSecureStorage? secureStorage})
      : _ownsFnConnect = fnConnect == null,
        fnConnect = fnConnect ?? FnConnectClient(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage() {
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
  late final ClientExtensionRegistryState clientExtensions =
      ClientExtensionRegistryState(
          load: pluginCapabilities.listClientExtensions,
          onChanged: _notifyIfActive);

  void ensureClientExtensions() {
    clientExtensions.sync(offlineMode || token == null
        ? null
        : '${api.baseUrl}|${api.authRevision}|$pluginExtensionRevision');
  }

  static const _serverModePrefsKey = 'server_mode';
  static const _fnIdPrefsKey = 'fn_id';
  static const _gatewayCookiePrefsKey = 'gateway_cookie';
  static const _gatewayReloginRequiredPrefsKey = 'gateway_relogin_required';
  static const _fnConnectOrderPrefsKey = 'fn_connect_order';
  static const _fnConnectDisabledPrefsKey = 'fn_connect_disabled';
  static const _fnConnectIgnoreSslPrefsKey = 'fn_connect_ignore_ssl';
  late final _AppPreferences _preferences = _AppPreferences(
    api: () => api,
    preferences: () => _prefs,
    ensurePreferences: () async {
      _prefs ??= await SharedPreferences.getInstance();
    },
    canSync: () => token != null && !offlineMode,
    serverIdentity: () {
      final gateway = _normalizedGatewayIdentity(fnId);
      return gateway.isNotEmpty
          ? 'fnos:$gateway'
          : 'server:${_normalizeOptionalServerUrl(serverUrl)}';
    },
    onChanged: _notifyIfActive,
  );

  late final _AppConnectionResolver _connections = _AppConnectionResolver(
    preferences: () => _prefs,
    textForLocale: textForLocale,
    onChanged: _notifyIfActive,
  );

  bool _disposed = false;
  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsFnConnect) fnConnect.dispose();
    clientExtensions.dispose();
    pluginCapabilities.invalidateClientExtensionsCache();
    cancelStartup();
    _gatewayRecoveryCancelToken?.cancel('Application state disposed');
    _connections.dispose();
    api.recoverBaseUrl = null;
    api.onGatewaySessionExpired = null;
    api.isGatewaySession = null;
    api.allowBadCertificate = null;
    onGatewayLoginRequired = null;
    onGatewayLoginRestored = null;
    super.dispose();
  }

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage;
  late final CredentialStore _credentials = CredentialStore(_secureStorage);
  Future<String?>? _activeUrlRecovery;
  Future<bool>? _gatewaySessionRecovery;
  CancelToken? _gatewayRecoveryCancelToken;
  Future<void> Function()? onGatewayLoginRequired;
  Future<void> Function()? onGatewayLoginRestored;

  /// 正在进行中的网关静默重登（无重登时为 null）。
  ///
  /// 播放器在音频流异常结束（completed）时必须先等重登尘埃落定，
  /// 再判断会话状态与重建音源——否则会把「重登踢掉旧会话导致的流截断」
  /// 误判为音频流异常。
  Future<void>? get gatewaySessionRecoveryInFlight => _gatewaySessionRecovery;
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
  bool gatewayStartupLoginAttempted = false;
  Map<String, dynamic> get settings => _preferences.settings;
  set settings(Map<String, dynamic> value) => _preferences.settings = value;
  Locale? get locale => _preferences.locale;
  set locale(Locale? value) => _preferences.locale = value;
  String? connectionError;
  String? _startupConnectionTarget;
  bool offlineMode = false;
  List<SavedServerProfile> savedServers = [];
  List<FnConnectCandidateGroup> fnConnectOrder = List.of(defaultFnConnectOrder);
  Set<FnConnectCandidateGroup> fnConnectDisabledGroups = {};
  bool fnConnectIgnoreSsl = true;
  bool fnConnectProbing = false;
  List<FnConnectCandidateResult> fnConnectCandidates = const [];
  RedirectResolution? get lastRedirectResolution =>
      _connections.lastRedirectResolution;
  bool get resolvingRedirect => _connections.resolvingRedirect;
  int _pluginExtensionRevision = 0;

  final bool _ownsFnConnect;
  final FnConnectClient fnConnect;

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

  String get theme => _preferences.theme;
  ThemeMode get themeMode => _preferences.themeMode;
  String get languageCode => _preferences.languageCode;
  bool get isEnglish => _preferences.isEnglish;
  bool get sidebarCollapsed => _preferences.sidebarCollapsed;
  bool get pluginToolMenuEnabled => _preferences.pluginToolMenuEnabled;
  String textForLocale(String zh, String en) =>
      _preferences.textForLocale(zh, en);

  void notifyPluginExtensionsChanged() {
    pluginCapabilities.invalidateClientExtensionsCache();
    _pluginExtensionRevision++;
    notifyListeners();
  }

  void cancelStartup() {
    _startupGeneration++;
    final cancelToken = _startupCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Startup cancelled');
    }
  }

  // These instance methods preserve dynamic dispatch for UI clients and tests.
  Future<void> initialize({bool Function()? isCancelled}) =>
      _initializeSession(isCancelled: isCancelled);
  Future<void> resetToLoginAfterStartupFailure(
          {bool requireGatewayLogin = true}) =>
      _resetAfterStartupFailure(requireGatewayLogin: requireGatewayLogin);
  Future<void> validateConnection(
          {bool recordLogin = false,
          bool Function()? isCancelled,
          CancelToken? cancelToken}) =>
      _validateSession(
          recordLogin: recordLogin,
          isCancelled: isCancelled,
          cancelToken: cancelToken);

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
    String? fnAccessCode,
    Future<FnTwofaAnswer?> Function()? onTwofaRequired,
    ValueChanged<FnConnectStage>? onFnConnectStage,
    SavedServerProfile? replaceProfile,
    Map<String, dynamic> loginSettingsPatch = const {},
    CancelToken? cancelToken,
  }) =>
      _loginSession(
        server: server,
        localServer: localServer,
        username: username,
        password: password,
        mode: mode,
        fnId: fnId,
        fnosUsername: fnosUsername,
        fnosPassword: fnosPassword,
        gatewayCookie: gatewayCookie,
        fnAccessCode: fnAccessCode,
        onTwofaRequired: onTwofaRequired,
        onFnConnectStage: onFnConnectStage,
        replaceProfile: replaceProfile,
        loginSettingsPatch: loginSettingsPatch,
        cancelToken: cancelToken,
      );

  Future<void> loginWithPrompts(
    SavedServerProfile profile, {
    SavedServerProfile? replaceProfile,
    Map<String, dynamic> settingsPatch = const {},
    Future<String?> Function(bool incorrect)? requestAccessCode,
    Future<FnTwofaAnswer?> Function()? requestTwofa,
    ValueChanged<FnConnectStage>? onStage,
    CancelToken? cancelToken,
  }) =>
      _loginWithPrompts(profile,
          replaceProfile: replaceProfile,
          settingsPatch: settingsPatch,
          requestAccessCode: requestAccessCode,
          requestTwofa: requestTwofa,
          onStage: onStage,
          cancelToken: cancelToken);

  Future<void> enterOfflineMode() => _enterOfflineSession();
  Future<void> logout() => _logoutSession();
  Future<void> handleGatewaySessionExpired() async {
    await _handleGatewaySessionExpired();
  }

  Future<void> setFnConnectOrder(List<FnConnectCandidateGroup> order) =>
      _setGatewayOrder(order);
  Future<void> setFnConnectGroupEnabled(
          FnConnectCandidateGroup group, bool enabled) =>
      _setGatewayGroupEnabled(group, enabled);
  Future<void> setFnConnectIgnoreSsl(bool value) => _setGatewayIgnoreSsl(value);
  Future<bool> reprobeFnConnect() => _reprobeGateway();
  Future<void> switchFnConnectCandidate(FnConnectCandidate candidate) =>
      _switchGatewayCandidate(candidate);
  Future<String?> recoverActiveUrl({CancelToken? cancelToken}) =>
      _recoverCurrentUrl(cancelToken: cancelToken);

  /// Recover only a resource owned by the active server and preserve its path
  /// relative to the gateway prefix. Views do not implement route rebasing.
  Future<String?> recoverResourceUrl(String failedUrl,
      {CancelToken? cancelToken}) async {
    if (!usesActiveOrigin(failedUrl)) return null;
    final previous = activeUrl;
    final identity = '$serverUrl|$fnId';
    final recovered = await recoverActiveUrl(cancelToken: cancelToken);
    if (_disposed ||
        (cancelToken?.isCancelled ?? false) ||
        identity != '$serverUrl|$fnId' ||
        recovered == null ||
        recovered == previous) {
      return null;
    }
    final resource = Uri.tryParse(failedUrl);
    final before = Uri.tryParse(previous);
    final after = Uri.tryParse(recovered);
    if (resource == null || before == null || after == null) return null;
    final prefix = before.path.replaceFirst(RegExp(r'/$'), '');
    if (prefix.isNotEmpty &&
        resource.path != prefix &&
        !resource.path.startsWith('$prefix/')) {
      return null;
    }
    final relative = resource.path.substring(prefix.length);
    return after
        .replace(
          path: '${after.path.replaceFirst(RegExp(r'/$'), '')}$relative',
          query: resource.hasQuery ? resource.query : null,
          fragment: resource.hasFragment ? resource.fragment : null,
        )
        .toString();
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
    String fnAccessCode = '',
    SavedServerProfile? replaceProfile,
  }) =>
      _rememberProfile(
          server: server,
          localServer: localServer,
          username: username,
          password: password,
          mode: mode,
          fnId: fnId,
          fnosUsername: fnosUsername,
          fnosPassword: fnosPassword,
          gatewayCookie: gatewayCookie,
          fnAccessCode: fnAccessCode,
          replaceProfile: replaceProfile);
  Future<void> deleteSavedServerProfile(SavedServerProfile profile) =>
      _deleteProfile(profile);

  Future<RedirectResolution> resolveServerUrl(String source,
          {bool force = false}) =>
      _connections.resolveServerUrl(source, force: force);

  Future<RedirectResolution> resolveBestServerUrl(
          {required String server,
          required String localServer,
          bool force = false,
          bool quick = false,
          CancelToken? cancelToken}) =>
      _connections.resolveBestServerUrl(
          server: server,
          localServer: localServer,
          force: force,
          quick: quick,
          cancelToken: cancelToken);

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

  Future<void> loadSettings(
          {bool silent = false,
          bool Function()? isCancelled,
          CancelToken? cancelToken}) =>
      _preferences.loadSettings(
          silent: silent, isCancelled: isCancelled, cancelToken: cancelToken);

  Future<void> loadApplicationTimeZone(
          {bool silent = false, CancelToken? cancelToken}) =>
      _preferences.loadApplicationTimeZone(
          silent: silent, cancelToken: cancelToken);

  Future<void> updateApplicationTimeZone(String value) =>
      _preferences.updateApplicationTimeZone(value);
  Future<void> updateSettings(Map<String, dynamic> patch,
          {CancelToken? cancelToken}) =>
      _preferences.updateSettings(patch, cancelToken: cancelToken);
  Future<void> updateLocalSettings(Map<String, dynamic> patch) =>
      _preferences.updateLocalSettings(patch);
  Future<void> setLanguage(String value, {bool syncRemote = true}) =>
      _preferences.setLanguage(value, syncRemote: syncRemote);
  Future<void> setTheme(String value, {bool syncRemote = true}) =>
      _preferences.setTheme(value, syncRemote: syncRemote);

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

  String? _fnDeviceDidCache;

  /// 飞牛设备 ID（`did`）：首次生成后持久化到安全存储。
  ///
  /// 二步验证勾选「信任本设备」时服务器按 did 记住受信设备，
  /// 因此必须稳定复用同一个 did，不能每次登录重新生成。
  Future<String> _fnDeviceDid() async {
    final cached = _fnDeviceDidCache;
    if (cached != null && cached.isNotEmpty) return cached;
    const key = 'fn_device_did';
    try {
      final stored = await _secureStorage.read(key: key);
      if (stored != null && stored.isNotEmpty) {
        _fnDeviceDidCache = stored;
        return stored;
      }
      final generated = fnConnect.generateDeviceId();
      await _secureStorage.write(key: key, value: generated);
      _fnDeviceDidCache = generated;
      return generated;
    } catch (_) {
      // 安全存储不可用时退化为会话级随机 did（信任设备语义会失效，
      // 但不影响每次登录时手动输入 OTP）。
      return fnConnect.generateDeviceId();
    }
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
}
