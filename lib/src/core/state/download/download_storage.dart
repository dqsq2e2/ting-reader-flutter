import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/_helpers.dart' show asMap, readInt, readString;
import 'download_helpers.dart';
import 'download_models.dart';

/// Serializes each file's read/modify/write cycle and replaces completed files.
/// The queue releases entries after success or failure, without owning timers.
class DownloadStorage {
  static const _directoryPreference = 'download_cache_directory';
  final Map<String, Future<void>> _writes = {};
  int _sequence = 0;
  Future<void> _directoryChanges = Future<void>.value();
  Directory? _directory;
  String? _customDirectory;
  Directory? get directory => _directory;
  String? get customDirectory => _customDirectory;
  File? get _indexFile {
    final root = directory;
    return root == null
        ? null
        : File('${root.path}${Platform.pathSeparator}downloads.json');
  }

  Future<void> initialize(void Function() checkActive) async {
    final preferences = await SharedPreferences.getInstance();
    checkActive();
    await configureDirectory(
        preferences.getString(_directoryPreference), checkActive);
  }

  /// Directory validation and preferences have one owner and serialize changes.
  Future<bool> configureDirectory(String? path, void Function() checkActive) {
    final result = _directoryChanges.then((_) async {
      checkActive();
      final custom = path == null || path.trim().isEmpty
          ? null
          : Directory(path.trim()).absolute.path;
      final root = await _resolveDirectory(custom);
      checkActive();
      if (directory?.absolute.path == root.absolute.path &&
          customDirectory == custom) {
        return false;
      }
      final type = await FileSystemEntity.type(root.path);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.directory) {
        throw StateError('Cache location is not a folder: ${root.path}');
      }
      await root.create(recursive: true);
      checkActive();
      final preferences = await SharedPreferences.getInstance();
      checkActive();
      if (custom == null) {
        await preferences.remove(_directoryPreference);
      } else {
        await preferences.setString(_directoryPreference, custom);
      }
      checkActive();
      _directory = root;
      _customDirectory = custom;
      return true;
    });
    _directoryChanges =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<Directory> _resolveDirectory(String? custom) async {
    if (custom != null) return Directory(custom);
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return Directory(
            '${external.path}${Platform.pathSeparator}ting_reader_downloads');
      }
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory(
        '${documents.path}${Platform.pathSeparator}ting_reader_downloads');
  }

  Future<DownloadIndex?> readIndex(void Function() checkActive) async {
    final file = _indexFile;
    if (file == null) return null;
    await _writes[file.absolute.path];
    checkActive();
    if (!await file.exists()) return null;
    DownloadIndex index;
    try {
      index = DownloadIndex.fromJson(jsonDecode(await file.readAsString()));
    } on FormatException {
      index = const DownloadIndex();
    }
    checkActive();
    final present = <LocalDownload>[];
    for (final item in index.downloads) {
      if (await existingFile(item.filePath) != null) present.add(item);
      checkActive();
    }
    for (final task in index.tasks) {
      final size = await fileSize(task.tempPath);
      checkActive();
      if (size > 0) {
        task.receivedBytes = size;
        if (task.totalBytes > 0) {
          task.progress = (size / task.totalBytes).clamp(0, 1);
        }
      }
    }
    return DownloadIndex(
        downloads: present,
        tasks: index.tasks,
        maxConcurrent: index.maxConcurrent);
  }

  Future<void> saveIndex(DownloadIndex index) {
    final file = _indexFile;
    return file == null
        ? Future<void>.value()
        : writeJson(file, index.toJson(directory: customDirectory));
  }

  Future<String?> existingFile(String? path) async =>
      path != null && path.isNotEmpty && await File(path).exists()
          ? path
          : null;

  Future<int> fileSize(String? path) async {
    final existing = await existingFile(path);
    return existing == null ? 0 : File(existing).length();
  }

  Future<void> deleteFile(String? path) async {
    final existing = await existingFile(path);
    if (existing != null) await File(existing).delete();
  }

  void preparePaths(DownloadTask task, {required bool transcode}) {
    final root = directory;
    if (root == null) return;
    final extension =
        transcode ? 'mp3' : downloadPathExtension(task.chapterPath);
    final existingPath = task.filePath;
    if (existingPath != null && task.tempPath != null) {
      if (task.status == DownloadStatus.completed ||
          !transcode ||
          downloadPathExtension(existingPath) == extension) {
        return;
      }
      task.filePath = task.tempPath = null;
    }
    final book = Directory(
        '${root.path}${Platform.pathSeparator}${_safeSegment(task.serverKey)}'
        '${Platform.pathSeparator}${_safeSegment(task.bookId)}');
    final name =
        '${task.chapterIndex.toString().padLeft(4, '0')}_${_safeSegment(task.chapterId)}.$extension';
    task.filePath ??= '${book.path}${Platform.pathSeparator}$name';
    task.tempPath ??= '${task.filePath}.part';
  }

  Directory directoryForTask(DownloadTask task) {
    final path = task.filePath;
    if (path == null) {
      throw StateError('Download paths must be prepared before transfer');
    }
    return File(path).parent;
  }

  Set<String> bookDirectories(String groupKey,
          Iterable<LocalDownload> downloads, Iterable<DownloadTask> tasks) =>
      {
        for (final item in downloads)
          if (item.bookGroupKey == groupKey && item.filePath.isNotEmpty)
            File(item.filePath).parent.path,
        for (final task in tasks)
          if (task.bookGroupKey == groupKey &&
              task.filePath?.isNotEmpty == true)
            directoryForTask(task).path,
      };

  Future<String?> existingCover(Directory directory) async {
    for (final extension in const ['jpg', 'jpeg', 'png', 'webp', 'gif']) {
      final file =
          File('${directory.path}${Platform.pathSeparator}cover.$extension');
      if (await file.exists() && await file.length() > 0) return file.path;
    }
    return null;
  }

  Future<String> saveCover(Directory directory, List<int> bytes,
      {String? contentType,
      required String source,
      required void Function() checkActive}) async {
    final extension = _coverExtension(contentType: contentType, source: source);
    final target =
        File('${directory.path}${Platform.pathSeparator}cover.$extension');
    await _serialize(target, () => _replaceBytes(target, bytes, checkActive));
    return target.path;
  }

  Future<void> rollbackAudio(String file, String partial,
      {required bool keepPartial}) async {
    if (await existingFile(file) == null) return;
    if (keepPartial) {
      await File(file).rename(partial);
    } else {
      await deleteFile(file);
    }
  }

  /// Offline sidecars use a task snapshot so the disk owner is independent of
  /// the live queue and cannot accidentally mutate a running transfer.
  Future<void> cacheMetadata(Directory directory, Map<String, dynamic> task,
      String? localCover, void Function() checkActive) async {
    final book = {
      ...asMap(task['book_metadata']),
      'id': task['book_id'],
      'library_id': task['library_id'],
      'title': task['book_title'],
      'cover_url': task['cover_url'],
      if (localCover != null) 'local_cover_path': localCover,
      'updated_at': DateTime.now().toIso8601String(),
    }..removeWhere((_, value) => value == null || value == '');
    checkActive();
    await writeJson(
        File('${directory.path}${Platform.pathSeparator}book.json'), book,
        checkActive: checkActive);
    checkActive();
    final chapter = {
      'id': task['chapter_id'],
      'book_id': task['book_id'],
      'title': task['chapter_title'],
      'chapter_index': task['chapter_index'],
      'duration': task['duration'],
      'is_extra': task['is_extra'] ?? false,
      'source_path': task['chapter_path'],
      'local_file_path': task['file_path'],
      'downloaded_at': DateTime.now().toIso8601String(),
    }..removeWhere((_, value) => value == null || value == '');
    await updateJson(
        File('${directory.path}${Platform.pathSeparator}chapters.json'),
        (current) {
      final chapters = <String, Map<String, dynamic>>{};
      if (current is List) {
        for (final value in current) {
          final item = asMap(value);
          final id = readString(item, 'id') ?? readString(item, 'chapter_id');
          if (id != null) chapters[id] = item;
        }
      }
      chapters[task['chapter_id'].toString()] = chapter;
      return chapters.values.toList()
        ..sort((a, b) => (readInt(a, 'chapter_index') ?? 0)
            .compareTo(readInt(b, 'chapter_index') ?? 0));
    }, checkActive: checkActive);
  }

  Future<void> cleanBookDirectory(Directory directory) async {
    if (!await directory.exists()) return;
    for (final name in const [
      'book.json',
      'chapters.json',
      'cover.jpg',
      'cover.jpeg',
      'cover.png',
      'cover.webp',
      'cover.gif'
    ]) {
      final file = File('${directory.path}${Platform.pathSeparator}$name');
      if (await file.exists()) await file.delete();
    }
    if (await directory.list(followLinks: false).isEmpty) {
      await directory.delete();
    }
  }

  Future<void> cleanBookDirectories(Iterable<String> paths) async {
    for (final path in paths.toSet()) {
      await cleanBookDirectory(Directory(path));
    }
  }

  Future<void> writeJson(File file, Object value,
      {void Function()? checkActive}) {
    final contents = const JsonEncoder.withIndent('  ').convert(value);
    return _serialize(file, () => _replace(file, contents, checkActive));
  }

  Future<void> updateJson(
    File file,
    Object Function(Object? current) update, {
    void Function()? checkActive,
  }) =>
      _serialize(file, () async {
        checkActive?.call();
        final current =
            await file.exists() ? jsonDecode(await file.readAsString()) : null;
        final contents =
            const JsonEncoder.withIndent('  ').convert(update(current));
        await _replace(file, contents, checkActive);
      });

  Future<void> _serialize(File file, Future<void> Function() operation) {
    final key = file.absolute.path;
    final previous = _writes[key] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    // Keep errors visible to the caller, but allow later writes to recover.
    final settled =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _writes[key] = settled;
    unawaited(settled.then((_) {
      if (identical(_writes[key], settled)) _writes.remove(key);
    }));
    return result;
  }

  Future<void> _replace(
          File target, String contents, void Function()? checkActive) =>
      _replaceBytes(target, utf8.encode(contents), checkActive);

  Future<void> _replaceBytes(
      File target, List<int> bytes, void Function()? checkActive) async {
    checkActive?.call();
    await target.parent.create(recursive: true);
    final staging = File(
      '${target.path}.${DateTime.now().microsecondsSinceEpoch}.${_sequence++}.tmp',
    );
    try {
      await staging.writeAsBytes(bytes, flush: true);
      checkActive?.call();
      await staging.rename(target.path);
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }

  Future<void> flush() async {
    await _directoryChanges;
    while (_writes.isNotEmpty) {
      await Future.wait(_writes.values.toList());
    }
  }
}

String _safeSegment(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .trim();
  if (cleaned.isEmpty) return 'item';
  return cleaned.length > 72 ? cleaned.substring(0, 72) : cleaned;
}

String _coverExtension({String? contentType, required String source}) {
  final type = contentType?.toLowerCase() ?? '';
  if (type.contains('png')) return 'png';
  if (type.contains('webp')) return 'webp';
  if (type.contains('gif')) return 'gif';
  if (type.contains('jpeg') || type.contains('jpg')) return 'jpg';
  final extension = downloadPathExtension(Uri.tryParse(source)?.path ?? source);
  if (const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(extension)) {
    return extension == 'jpeg' ? 'jpg' : extension;
  }
  return 'jpg';
}
