part of '../app_state.dart';

/// Owns preference values, account synchronization and local persistence.
/// It has no access to gateway recovery, saved credentials or playback state.
class _AppPreferences {
  _AppPreferences({
    required ApiClient Function() api,
    required SharedPreferences? Function() preferences,
    required Future<void> Function() ensurePreferences,
    required bool Function() canSync,
    required String Function() serverIdentity,
    required VoidCallback onChanged,
  })  : _api = api,
        _preferences = preferences,
        _ensurePreferences = ensurePreferences,
        _canSync = canSync,
        _serverIdentity = serverIdentity,
        _onChanged = onChanged;

  final ApiClient Function() _api;
  final SharedPreferences? Function() _preferences;
  final Future<void> Function() _ensurePreferences;
  final bool Function() _canSync;
  final String Function() _serverIdentity;
  final VoidCallback _onChanged;
  ApiClient get api => _api();
  SharedPreferences? get _prefs => _preferences();
  Map<String, dynamic> settings = {};
  Locale? locale;
  String get applicationTimeZone => app_time_zone.applicationTimeZone;

  static const _cachedSettingsPrefsKey = 'cached_app_settings';
  static const _localSettingsPrefsKey = 'local_app_settings';
  static const _languagePrefsKey = 'language';
  static const _applicationTimeZonePrefsKey = 'application_time_zone';
  static const _localOnlySettingKeys = <String>{
    'ignore_audio_focus',
    'resume_after_interruption',
    'sidebar_collapsed',
    'player_volume',
  };
  static const _obsoleteLocalSettingKeys = <String>{
    'resume_after_interruption',
  };

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
    _onChanged();
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
      if (changed) _onChanged();
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
    if (changed) _onChanged();
  }

  Future<void> updateSettings(
    Map<String, dynamic> patch, {
    CancelToken? cancelToken,
  }) async {
    final res = await api.post(
      '/api/settings',
      data: patch,
      cancelToken: cancelToken,
    );
    settings = asMap(res.data);
    _applyLocalSettings();
    await _applyLanguageFromSettings();
    await _cacheSettings(settings);
    _onChanged();
  }

  Future<void> updateLocalSettings(Map<String, dynamic> patch) async {
    await _ensurePreferences();
    final normalizedPatch = {...patch};
    final local = {
      ..._readLocalSettings(),
      ...normalizedPatch,
    };
    await _prefs?.setString(_localSettingsPrefsKey, jsonEncode(local));
    _applySettingsPatch(normalizedPatch);
    await _cacheSettings(settings);
    _onChanged();
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
    final identity = _serverIdentity();
    return '$_applicationTimeZonePrefsKey:${base64Url.encode(utf8.encode(identity))}';
  }

  Future<void> setLanguage(String value, {bool syncRemote = true}) async {
    final normalized = normalizeLanguage(value);
    locale = Locale(normalized);
    api.setLanguage(normalized);
    await _prefs?.setString(_languagePrefsKey, normalized);
    _applySettingsPatch({'language': normalized});
    await _cacheSettings(settings);
    _onChanged();
    if (syncRemote && _canSync()) {
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
    _onChanged();
    if (syncRemote && _canSync()) {
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
    final local = _readLocalSettings();
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
}
