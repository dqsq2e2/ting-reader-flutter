import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores complete credential records together, so migration cannot delete
/// plaintext until every field has been written and verified.
class CredentialStore {
  CredentialStore(this._storage);

  final FlutterSecureStorage _storage;
  final Map<String, Future<void>> _pending = {};

  Future<Map<String, String>?> read(String key) => _serialized(key, () async {
        final raw = await _storage.read(key: key);
        if (raw == null) return null;
        final Object? decoded;
        try {
          decoded = jsonDecode(raw);
        } on FormatException {
          throw const FormatException('Invalid credential record');
        }
        if (decoded is! Map<String, dynamic> ||
            decoded.values.any((value) => value is! String)) {
          throw const FormatException('Invalid credential record');
        }
        return decoded.map((key, value) => MapEntry(key, value as String));
      });

  Future<void> write(String key, Map<String, String> value) =>
      _serialized(key, () async {
        final encoded = jsonEncode(value);
        await _storage.write(key: key, value: encoded);
        if (await _storage.read(key: key) != encoded) {
          throw StateError('Secure credential storage verification failed');
        }
      });

  Future<void> delete(String key) =>
      _serialized(key, () => _storage.delete(key: key));

  Future<T> _serialized<T>(String key, Future<T> Function() action) {
    final previous = _pending[key] ?? Future<void>.value();
    final result = previous.then((_) => action());
    // A failed operation must not poison subsequent reads or writes.
    final completion = result.then<void>((_) {}, onError: (Object _) {});
    _pending[key] = completion;
    completion.then((_) {
      if (identical(_pending[key], completion)) _pending.remove(key);
    });
    return result;
  }
}
