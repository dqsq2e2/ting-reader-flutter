import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/plugin_capabilities_api.dart';
import '../document_reader/document_reader.dart';
import '../models/models.dart';
import '../utils/client_device_headers.dart';
import '../utils/locale.dart';
import '../utils/local_network.dart';

part 'app/app_state_models.dart';

class AppState extends ChangeNotifier {
  final ApiClient api = ApiClient();
  late final PluginCapabilitiesApi pluginCapabilities =
      PluginCapabilitiesApi(api);
  late final DocumentReaderClient documentReader =
      DocumentReaderClient(pluginCapabilities);

  static const _cachedSettingsPrefsKey = 'cached_app_settings';
  static const _localSettingsPrefsKey = 'local_app_settings';
  static const _languagePrefsKey = 'language';
  static const _localOnlySettingKeys = <String>{
    'ignore_audio_focus',
    'resume_after_interruption',
  };
  static const _obsoleteLocalSettingKeys = <String>{
    'resume_after_interruption',
  };

  SharedPreferences? _prefs;
  Map<String, String> _redirectCache = {};
  Future<String?>? _activeUrlRecovery;
  User? user;
  String? token;
  String serverUrl = 'http://localhost:3000';
  String localServerUrl = '';
  String activeUrl = 'http://localhost:3000';
  Map<String, dynamic> settings = {};
  Locale? locale;
  String? connectionError;
  bool offlineMode = false;
  List<SavedServerProfile> savedServers = [];
  RedirectResolution? lastRedirectResolution;
  bool resolvingRedirect = false;
  int _pluginExtensionRevision = 0;

  bool get isAuthenticated => (token != null && user != null) || offlineMode;
  bool get isAdmin => user?.isAdmin ?? false;
  int get pluginExtensionRevision => _pluginExtensionRevision;

  ThemeMode get themeMode {
    final theme = (settings['theme'] ?? '').toString();
    if (theme == 'light') return ThemeMode.light;
    if (theme == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  String get languageCode => locale?.languageCode ?? 'zh';

  bool get isEnglish => languageCode.toLowerCase().startsWith('en');

  String textForLocale(String zh, String en) => isEnglish ? en : zh;

  void notifyPluginExtensionsChanged() {
    _pluginExtensionRevision++;
    notifyListeners();
  }

  Future<void> initialize({bool Function()? isCancelled}) async {
    void checkCancelled() {
      if (isCancelled?.call() ?? false) throw const _StartupCancelled();
    }

    _prefs = await SharedPreferences.getInstance();
    checkCancelled();
    _loadRedirectCache();
    api.recoverBaseUrl = (_) => recoverActiveUrl();
    serverUrl = _prefs!.getString('server_url') ?? serverUrl;
    localServerUrl = _prefs!.getString('local_server_url') ?? localServerUrl;
    activeUrl = _prefs!.getString('active_url') ??
        (localServerUrl.isNotEmpty ? localServerUrl : serverUrl);
    token = _prefs!.getString('auth_token');
    savedServers = _loadSavedServers();
    _loadLocalLanguage();
    api.setClientHeaders(await buildClientDeviceHeaders());
    checkCancelled();
    final hasPersistedServerConfig = _prefs!.containsKey('server_url') ||
        _prefs!.containsKey('local_server_url');

    final rawUser = _prefs!.getString('user');
    if (rawUser != null) {
      try {
        user = User.fromJson(asMap(jsonDecode(rawUser)));
      } catch (_) {
        user = null;
      }
    }

    if (token != null && user != null && hasPersistedServerConfig) {
      await _selectActiveUrlForCurrentNetwork(isCancelled: isCancelled);
      checkCancelled();
    }
    api.configure(baseUrl: activeUrl, token: token);

    if (token != null && user != null) {
      await validateConnection(
        recordLogin: true,
        isCancelled: isCancelled,
      );
      checkCancelled();
      if (connectionError == null && user != null) {
        await loadSettings(silent: true, isCancelled: isCancelled);
      }
    } else {
      _loadCachedSettings();
    }
  }

  Future<void> resetToLoginAfterStartupFailure() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _loadRedirectCache();
      serverUrl = _prefs!.getString('server_url') ?? serverUrl;
      localServerUrl = _prefs!.getString('local_server_url') ?? localServerUrl;
      activeUrl = _prefs!.getString('active_url') ??
          (localServerUrl.isNotEmpty ? localServerUrl : serverUrl);
      savedServers = _loadSavedServers();
      await _prefs?.remove('auth_token');
      await _prefs?.remove('user');
    } catch (_) {
      // Keep a clean login screen even when persisted startup state is broken.
    }
    api.recoverBaseUrl = (_) => recoverActiveUrl();
    try {
      api.setClientHeaders(await buildClientDeviceHeaders());
    } catch (_) {
      api.setClientHeaders(const {});
    }
    token = null;
    user = null;
    offlineMode = false;
    connectionError = null;
    _loadCachedSettings();
    api.configure(baseUrl: activeUrl, token: null);
    notifyListeners();
  }

  Future<void> validateConnection({
    bool recordLogin = false,
    bool Function()? isCancelled,
  }) async {
    void checkCancelled() {
      if (isCancelled?.call() ?? false) throw const _StartupCancelled();
    }

    connectionError = null;
    try {
      if (recordLogin) {
        await _restoreSessionWithLoginAudit(isCancelled: isCancelled);
      } else {
        final res = await api.get('/api/me');
        checkCancelled();
        user = User.fromJson(asMap(res.data));
      }
      checkCancelled();
      await _prefs?.setString('user', user!.encode());
    } on _StartupCancelled {
      rethrow;
    } catch (_) {
      connectionError = textForLocale(
        '连接服务器失败或登录已过期',
        'Failed to connect or session expired',
      );
    }
    notifyListeners();
  }

  Future<void> _restoreSessionWithLoginAudit({
    bool Function()? isCancelled,
  }) async {
    void checkCancelled() {
      if (isCancelled?.call() ?? false) throw const _StartupCancelled();
    }

    final currentToken = token;
    if (currentToken == null || currentToken.isEmpty) {
      throw StateError('missing token');
    }

    try {
      final res = await api.post(
        '/api/auth/token-login',
        data: {'token': currentToken},
      );
      checkCancelled();
      final map = asMap(res.data);
      token = map['token']?.toString() ?? currentToken;
      user = User.fromJson(asMap(map['user']));
      api.configure(baseUrl: activeUrl, token: token);
      await _prefs?.setString('auth_token', token ?? '');
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status != 404 && status != 405) rethrow;
      final res = await api.get('/api/me');
      checkCancelled();
      user = User.fromJson(asMap(res.data));
    }
  }

  Future<void> login({
    required String server,
    String localServer = '',
    required String username,
    required String password,
    SavedServerProfile? replaceProfile,
  }) async {
    connectionError = null;
    serverUrl = _normalizeOptionalServerUrl(server);
    localServerUrl = _normalizeOptionalServerUrl(localServer);
    final resolution = await resolveBestServerUrl(
      server: serverUrl,
      localServer: localServerUrl,
      force: true,
    );
    activeUrl = resolution.resolvedUrl;
    api.configure(baseUrl: activeUrl, token: null);
    api.setClientHeaders(await buildClientDeviceHeaders());

    final res = await api.post(
      '/api/auth/login',
      data: {'username': username, 'password': password},
    );
    final map = asMap(res.data);

    token = map['token']?.toString();
    user = User.fromJson(asMap(map['user']));
    api.configure(baseUrl: activeUrl, token: token);

    await _prefs?.setString('server_url', serverUrl);
    await _prefs?.setString('local_server_url', localServerUrl);
    await _prefs?.setString('active_url', activeUrl);
    await _prefs?.setString('auth_token', token ?? '');
    await _prefs?.setString('user', user!.encode());
    await _saveServerProfile(
      SavedServerProfile(
        serverUrl: serverUrl,
        localServerUrl: localServerUrl,
        activeUrl: activeUrl,
        username: username,
        password: password,
        label: username,
        lastLoginAt: DateTime.now(),
      ),
      replaceProfile: replaceProfile,
    );
    await loadSettings(silent: true);
    notifyListeners();
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
    api.configure(baseUrl: activeUrl, token: null);
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
  }) async {
    final candidates = await _serverCandidates(
      server: server,
      localServer: localServer,
    );
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
        final resolution = await _resolveReachableServerUrl(
          candidate,
          force: force,
          quick: quick,
        );
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

  Future<String?> recoverActiveUrl() async {
    if (_activeUrlRecovery != null) return _activeUrlRecovery;
    _activeUrlRecovery = _recoverActiveUrl();
    try {
      return await _activeUrlRecovery;
    } finally {
      _activeUrlRecovery = null;
    }
  }

  Future<String?> _recoverActiveUrl() async {
    try {
      final resolution = await resolveBestServerUrl(
        server: serverUrl,
        localServer: localServerUrl,
        force: true,
      );
      activeUrl = resolution.resolvedUrl;
      await _prefs?.setString('active_url', activeUrl);
      api.configure(baseUrl: activeUrl, token: token);
      notifyListeners();
      return activeUrl;
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectActiveUrlForCurrentNetwork({
    bool Function()? isCancelled,
  }) async {
    try {
      final resolution = await resolveBestServerUrl(
        server: serverUrl,
        localServer: localServerUrl,
        quick: true,
      );
      if (isCancelled?.call() ?? false) throw const _StartupCancelled();
      activeUrl = resolution.resolvedUrl;
      await _prefs?.setString('active_url', activeUrl);
    } on _StartupCancelled {
      rethrow;
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
    token = null;
    user = null;
    offlineMode = false;
    connectionError = null;
    settings = {};
    api.configure(baseUrl: activeUrl, token: null);
    await _prefs?.remove('auth_token');
    await _prefs?.remove('user');
    notifyListeners();
  }

  Future<void> loadSettings({
    bool silent = false,
    bool Function()? isCancelled,
  }) async {
    try {
      final res = await api.get('/api/settings');
      if (isCancelled?.call() ?? false) throw const _StartupCancelled();
      settings = asMap(res.data);
      _applyLocalSettings();
      await _applyLanguageFromSettings();
      await _cacheSettings(settings);
    } on _StartupCancelled {
      rethrow;
    } catch (_) {
      if (!silent) rethrow;
    }
    notifyListeners();
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

  List<SavedServerProfile> _loadSavedServers() {
    final raw = _prefs?.getString('saved_servers');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((item) => SavedServerProfile.fromJson(asMap(item)))
          .where((item) =>
              item.serverUrl.isNotEmpty || item.localServerUrl.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
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
    ) {
      if (server == null || local == null) return false;
      return _normalizeOptionalServerUrl(item.serverUrl) == server &&
          _normalizeOptionalServerUrl(item.localServerUrl) == local &&
          item.username == username;
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
          )) {
            return false;
          }
          if (replaceProfile != null &&
              sameProfile(
                item,
                normalizedReplaceServer,
                normalizedReplaceLocal,
                replaceProfile.username,
              )) {
            return false;
          }
          return true;
        },
      ),
    ];
    savedServers = next.take(8).toList();
    await _prefs?.setString(
      'saved_servers',
      jsonEncode(savedServers.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteSavedServerProfile(SavedServerProfile profile) async {
    final normalizedServer = _normalizeOptionalServerUrl(profile.serverUrl);
    final normalizedLocal = _normalizeOptionalServerUrl(profile.localServerUrl);
    savedServers = savedServers
        .where(
          (item) =>
              _normalizeOptionalServerUrl(item.serverUrl) != normalizedServer ||
              _normalizeOptionalServerUrl(item.localServerUrl) !=
                  normalizedLocal ||
              item.username != profile.username,
        )
        .toList();
    await _prefs?.setString(
      'saved_servers',
      jsonEncode(savedServers.map((item) => item.toJson()).toList()),
    );
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

  Future<RedirectResolution?> _resolveReachableServerUrl(
    String normalizedSource, {
    required bool force,
    bool quick = false,
  }) async {
    if (normalizedSource.isEmpty) return null;

    final cached = _redirectCache[normalizedSource];
    if (!force && cached != null && cached.isNotEmpty) {
      final reachable = await _probeRedirectTarget(cached, quick: quick);
      if (reachable != null) {
        return RedirectResolution(
          sourceUrl: normalizedSource,
          resolvedUrl: cached,
          fromCache: true,
        );
      }
      _redirectCache.remove(normalizedSource);
      await _saveRedirectCache();
    }

    final resolved = await _probeRedirectTarget(normalizedSource, quick: quick);
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
  }) async {
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
        );
        if (_isBackendProbeResponse(path, response)) {
          return _originFromUri(response.realUri);
        }
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

  String _originFromUri(Uri uri) {
    final needsPort = uri.hasPort &&
        !((uri.scheme == 'http' && uri.port == 80) ||
            (uri.scheme == 'https' && uri.port == 443));
    return '${uri.scheme}://${uri.host}${needsPort ? ':${uri.port}' : ''}';
  }
}
