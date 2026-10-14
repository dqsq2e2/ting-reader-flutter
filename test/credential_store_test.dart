import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ting_reader_flutter/src/core/auth/credential_store.dart';
import 'package:ting_reader_flutter/src/core/state/app_state.dart';

class _FailedStorage extends FlutterSecureStorage {
  _FailedStorage({this.discardWrites = false});

  final bool discardWrites;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (!discardWrites) throw StateError('Keychain unavailable');
  }
}

class _DeleteFailureStorage extends FlutterSecureStorage {
  bool failDeletes = false;

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failDeletes) throw StateError('Keychain unavailable during logout');
    await super.delete(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}

Map<String, Object> _legacyValues() => {
      'server_url': 'http://127.0.0.1:3000',
      'auth_token': 'old-token',
      'gateway_cookie': 'old-cookie',
      'saved_servers': jsonEncode([
        const SavedServerProfile(
          serverUrl: 'https://reader.example',
          activeUrl: 'https://reader.example',
          username: 'reader',
          password: 'password',
          label: 'reader',
          gatewayCookie: 'profile-cookie',
          fnosPassword: 'fnos-password',
          fnAccessCode: 'access-code',
        ).toJson(includeSecrets: true),
      ]),
    };

void main() {
  test('migrates sessions and all profile secrets, then restores after restart',
      () async {
    SharedPreferences.setMockInitialValues(_legacyValues());
    final state = AppState();
    await state.initialize();
    expect(state.token, 'old-token');
    expect(state.gatewayCookie, 'old-cookie');
    expect(state.savedServers.single.password, 'password');
    expect(state.savedServers.single.fnosPassword, 'fnos-password');
    expect(state.savedServers.single.gatewayCookie, 'profile-cookie');
    expect(state.savedServers.single.fnAccessCode, 'access-code');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('gateway_cookie'), isNull);
    final profiles =
        (jsonDecode(prefs.getString('saved_servers')!) as List).single as Map;
    for (final field in [
      'password',
      'fnos_password',
      'gateway_cookie',
      'fn_access_code',
    ]) {
      expect(profiles.containsKey(field), isFalse);
    }
    state.dispose();
    final restored = AppState();
    await restored.initialize();
    expect(restored.token, 'old-token');
    expect(restored.savedServers.single.gatewayCookie, 'profile-cookie');
    await restored.logout();
    restored.dispose();
    final loggedOut = AppState();
    await loggedOut.initialize();
    expect(loggedOut.token, isNull);
    expect(loggedOut.gatewayCookie, isNull);
    loggedOut.dispose();
  });

  for (final discardWrites in [false, true]) {
    test('failed migration keeps old values (discard: $discardWrites)',
        () async {
      final legacy = _legacyValues();
      SharedPreferences.setMockInitialValues(legacy);
      final state =
          AppState(secureStorage: _FailedStorage(discardWrites: discardWrites));
      await expectLater(state.initialize(), throwsStateError);
      final prefs = await SharedPreferences.getInstance();
      for (final entry in legacy.entries) {
        expect(prefs.get(entry.key), entry.value);
      }
      state.dispose();
    });
  }

  test('credential records isolate servers and deletion keeps other records',
      () async {
    final store = CredentialStore(const FlutterSecureStorage());
    await store.write('server-a', {'token': 'a'});
    await store.write('server-b', {'token': 'b'});
    await store.delete('server-a');
    expect(await store.read('server-a'), isNull);
    expect(await store.read('server-b'), {'token': 'b'});
  });

  test('concurrent credential updates complete in order and remain readable',
      () async {
    final store = CredentialStore(const FlutterSecureStorage());
    await Future.wait([
      for (var index = 0; index < 20; index++)
        store.write('session', {'token': '$index'}),
    ]);
    expect(await store.read('session'), {'token': '19'});
    await store.delete('session');
    expect(await store.read('session'), isNull);
  });

  test('logout remains effective when deleting secure storage fails', () async {
    SharedPreferences.setMockInitialValues(_legacyValues());
    final storage = _DeleteFailureStorage();
    final state = AppState(secureStorage: storage);
    await state.initialize();
    storage.failDeletes = true;
    final prefs = await SharedPreferences.getInstance();
    final scope = prefs.getString('active_session_scope')!;
    await expectLater(state.logout(), throwsStateError);
    expect(state.token, isNull);
    expect(await const FlutterSecureStorage().read(key: scope), isNotNull);
    state.dispose();
    final restored = AppState();
    await restored.initialize();
    expect(restored.token, isNull);
    expect(restored.gatewayCookie, isNull);
    restored.dispose();
  });

  test('deleting one profile keeps another server credentials intact',
      () async {
    final legacy = _legacyValues();
    final profile = SavedServerProfile.fromJson(
      (jsonDecode(legacy['saved_servers'] as String) as List).single
          as Map<String, dynamic>,
    );
    legacy['saved_servers'] = jsonEncode([
      profile.toJson(includeSecrets: true),
      profile
          .copyWith(
            serverUrl: 'https://another.example',
            activeUrl: 'https://another.example',
            password: 'another-password',
          )
          .toJson(includeSecrets: true),
    ]);
    SharedPreferences.setMockInitialValues(legacy);
    final state = AppState();
    await state.initialize();
    await state.deleteSavedServerProfile(state.savedServers.first);
    expect(state.savedServers.single.serverUrl, 'https://another.example');
    state.dispose();
    final restored = AppState();
    await restored.initialize();
    expect(restored.savedServers.single.password, 'another-password');
    restored.dispose();
  });

  test('corrupt credential records do not expose their raw contents', () async {
    FlutterSecureStorage.setMockInitialValues({
      'corrupt': '{"token":"private-token"',
    });
    final store = CredentialStore(const FlutterSecureStorage());
    try {
      await store.read('corrupt');
      fail('Corrupt credential record was accepted');
    } on FormatException catch (error) {
      expect(error.toString(), isNot(contains('private-token')));
    }
  });

  test('profile metadata serialization omits every credential by default', () {
    final profile = SavedServerProfile.fromJson(
      (jsonDecode(_legacyValues()['saved_servers'] as String) as List).single
          as Map<String, dynamic>,
    );
    expect(profile.toJson().keys, isNot(contains('password')));
    expect(profile.toJson().keys, isNot(contains('gateway_cookie')));
    expect(profile.toJson().keys, isNot(contains('fn_access_code')));
  });

  test('preferences remain isolated from credentials and other app states',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    final other = AppState();
    addTearDown(state.dispose);
    addTearDown(other.dispose);
    await state.setLanguage('en', syncRemote: false);
    await state.setTheme('dark', syncRemote: false);
    await state.updateLocalSettings({'player_volume': 0.35});
    expect(state.languageCode, 'en');
    expect(state.theme, 'dark');
    expect(state.settings['player_volume'], 0.35);
    expect(other.languageCode, 'zh');
    expect(other.theme, 'system');
    expect(other.settings, isEmpty);
    expect(state.token, isNull);
    expect(state.savedServers, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('saved_servers'), isNull);

    final restarted = AppState();
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.languageCode, 'en');
    expect(restarted.theme, 'dark');
    expect(restarted.settings['player_volume'], 0.35);
    expect(restarted.token, isNull);
  });
}
