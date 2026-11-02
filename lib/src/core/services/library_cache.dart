import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Bounded, account-scoped snapshots and artwork. Credentials are never keys on disk.
class LibraryCache {
  LibraryCache(
      {Directory? directory,
      this.maxEntries = 96,
      this.maxBytes = 64 * 1024 * 1024})
      : _directoryOverride = directory;

  final Directory? _directoryOverride;
  final int maxEntries;
  final int maxBytes;
  final _snapshots = <String, Map<String, dynamic>>{};
  final _snapshotSizes = <String, int>{};
  final _pending = <String, List<int>>{};
  int _memoryBytes = 0;
  int _pendingBytes = 0;
  bool _saving = false;
  final _covers = <String, Future<File?>>{};
  final _requests = <CancelToken>{};
  Future<Directory>? _directory;
  Future<void> _writes = Future.value();
  bool _disposed = false;

  String _key(String identity, String resource) =>
      sha256.convert(utf8.encode('$identity\n$resource')).toString();

  Future<Directory> _root() => _directory ??= () async {
        final directory = _directoryOverride ??
            Directory(
                '${(await getTemporaryDirectory()).path}/library-cache-v1');
        return directory.create(recursive: true);
      }();

  Map<String, dynamic>? peek(String identity, String resource) {
    if (_disposed) return null;
    final key = _key(identity, resource);
    final value = _snapshots.remove(key);
    if (value != null) _snapshots[key] = value;
    return value == null ? null : Map.of(value);
  }

  void _remember(String key, Map<String, dynamic> value, int size) {
    _memoryBytes -= _snapshotSizes.remove(key) ?? 0;
    _snapshots.remove(key);
    if (size > 4 * 1024 * 1024 || size > maxBytes) return;
    _snapshots[key] = Map.of(value);
    _snapshotSizes[key] = size;
    _memoryBytes += size;
    while (_snapshots.length > 32 ||
        _memoryBytes > 8 * 1024 * 1024 ||
        _memoryBytes > maxBytes) {
      final oldest = _snapshots.keys.first;
      _memoryBytes -= _snapshotSizes.remove(oldest)!;
      _snapshots.remove(oldest);
    }
  }

  Future<Map<String, dynamic>?> read(String identity, String resource) async {
    if (_disposed) return null;
    final memory = peek(identity, resource);
    if (memory != null) return memory;
    try {
      final key = _key(identity, resource);
      final file = File('${(await _root()).path}/$key.json');
      if (!await file.exists() || await file.length() > 4 * 1024 * 1024) {
        return null;
      }
      final bytes = await file.readAsBytes();
      final value = jsonDecode(utf8.decode(bytes));
      if (_disposed || value is! Map<String, dynamic>) return null;
      _remember(key, value, bytes.length);
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
      String identity, String resource, Map<String, dynamic> value) {
    if (_disposed) return Future.value();
    final key = _key(identity, resource);
    // Snapshot before awaiting: callers may replace their visible state meanwhile.
    final bytes = utf8.encode(jsonEncode(value));
    _remember(key, value, bytes.length);
    if (bytes.length > 4 * 1024 * 1024) return Future.value();
    return _save('$key.json', bytes);
  }

  Future<void> _save(String name, List<int> bytes) {
    if (_disposed || bytes.length > maxBytes) return Future.value();
    _pendingBytes -= _pending.remove(name)?.length ?? 0;
    _pending[name] = bytes;
    _pendingBytes += bytes.length;
    while (_pending.length > 32 || _pendingBytes > 16 * 1024 * 1024) {
      _pendingBytes -= _pending.remove(_pending.keys.first)!.length;
    }
    if (!_saving) {
      _saving = true;
      _writes = _drain();
    }
    return _writes;
  }

  Future<void> _drain() async {
    while (!_disposed && _pending.isNotEmpty) {
      final name = _pending.keys.first;
      final bytes = _pending.remove(name)!;
      _pendingBytes -= bytes.length;
      try {
        final root = await _root();
        final file = File('${root.path}/$name');
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsBytes(bytes, flush: true);
        if (_disposed) {
          await temporary.delete();
          break;
        }
        if (await file.exists()) await file.delete();
        await temporary.rename(file.path);
        await _prune(root);
      } catch (_) {
        // Cache failures never prevent browsing or playback.
      }
    }
    _saving = false;
  }

  Future<void> _prune(Directory root) async {
    final files = <({File file, FileStat stat})>[];
    await for (final entry in root.list()) {
      if (entry is File) files.add((file: entry, stat: await entry.stat()));
    }
    files.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    var bytes = files.fold(0, (int sum, item) => sum + item.stat.size);
    var count = files.length;
    for (final entry in files) {
      if (count <= maxEntries && bytes <= maxBytes) break;
      await entry.file.delete();
      count--;
      bytes -= entry.stat.size;
    }
  }

  String coverResource(String url, {required bool serverResource}) {
    final uri = Uri.parse(url);
    if (!serverResource) return 'cover:$url';
    final path = uri.path;
    final api = path.indexOf('/api/');
    return 'cover:${Uri(path: api < 0 ? path : path.substring(api), queryParameters: Map.of(uri.queryParameters)..remove('token'))}';
  }

  Future<File?> cover(String identity, String resource,
      Future<List<int>> Function(CancelToken token) fetch,
      {void Function(File)? onUpdated}) async {
    if (_disposed) return null;
    final key = _key(identity, resource);
    try {
      final file = File('${(await _root()).path}/$key.img');
      if (_disposed) return null;
      if (await file.exists()) {
        final stat = await file.stat();
        if (stat.size > 0 && stat.size <= 8 * 1024 * 1024) {
          if (DateTime.now().difference(stat.modified) >
              const Duration(minutes: 15)) {
            unawaited(_loadCover(key, fetch).then((updated) {
              if (updated != null && !_disposed) onUpdated?.call(updated);
            }));
          }
          return file;
        }
      }
      return _loadCover(key, fetch);
    } catch (_) {
      return null;
    }
  }

  Future<File?> _loadCover(
          String key, Future<List<int>> Function(CancelToken token) fetch) =>
      _covers[key] ??= () async {
        final token = CancelToken();
        _requests.add(token);
        try {
          final bytes = await fetch(token);
          if (_disposed ||
              token.isCancelled ||
              bytes.isEmpty ||
              bytes.length > 8 * 1024 * 1024) {
            return null;
          }
          await _save('$key.img', bytes);
          final file = File('${(await _root()).path}/$key.img');
          return !_disposed && await file.exists() ? file : null;
        } catch (_) {
          return null;
        } finally {
          _requests.remove(token);
        }
      }()
          .whenComplete(() => _covers.remove(key));

  Future<void> flush() => _writes;

  void dispose() {
    _disposed = true;
    for (final token in _requests) {
      token.cancel('Library cache disposed');
    }
    _snapshots.clear();
    _snapshotSizes.clear();
    _pending.clear();
    _memoryBytes = _pendingBytes = 0;
    _covers.clear();
  }
}
