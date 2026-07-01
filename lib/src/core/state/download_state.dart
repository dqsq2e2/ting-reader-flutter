import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../utils/urls.dart';
import 'app_state.dart';

part 'download/download_models.dart';
part 'download/download_helpers.dart';

/// In-memory download queue, on-disk index, and HTTP engine.
///
/// Persistence layout under the user-chosen cache directory:
///   - `downloads.json`                – combined index (downloads + tasks)
///   - `<serverKey>/<bookId>/<chapterIndex>_<chapterId>.<ext>` – audio file
///   - `<serverKey>/<bookId>/cover.<ext>`                       – cached cover
///   - `<serverKey>/<bookId>/book.json`, `chapters.json`        – metadata
class DownloadState extends ChangeNotifier {
  DownloadState(this.appState);

  static const _cacheDirectoryPrefsKey = 'download_cache_directory';

  final AppState appState;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(minutes: 30),
    ),
  );

  Directory? _rootDir;
  File? _indexFile;
  String? _customCacheDirectory;
  int _maxConcurrentDownloads = 2;
  final Map<String, LocalDownload> _downloads = {};
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, CancelToken> _tokens = {};
  final Map<String, Future<void>> _running = {};
  final Map<String, List<Completer<LocalDownload>>> _waiters = {};

  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  String? get cacheDirectoryPath => _rootDir?.path;

  String? get customCacheDirectory => _customCacheDirectory;

  bool get usingCustomCacheDirectory =>
      _customCacheDirectory != null && _customCacheDirectory!.isNotEmpty;

  int get runningCount => _tasks.values
      .where((task) => task.status == DownloadStatus.downloading)
      .length;

  int get queuedCount => _tasks.values
      .where((task) => task.status == DownloadStatus.queued)
      .length;

  int get pausedCount => _tasks.values
      .where((task) => task.status == DownloadStatus.paused)
      .length;

  int get failedCount => _tasks.values
      .where((task) => task.status == DownloadStatus.failed)
      .length;

  List<LocalDownload> get downloads {
    final list = _downloads.values.toList();
    list.sort((a, b) {
      final byBook = a.bookTitle.compareTo(b.bookTitle);
      if (byBook != 0) return byBook;
      return a.chapterIndex.compareTo(b.chapterIndex);
    });
    return list;
  }

  List<DownloadTask> get activeTasks {
    final list = _tasks.values
        .where((task) => task.status != DownloadStatus.completed)
        .toList();
    list.sort((a, b) {
      final byStatus = _statusSort(a.status).compareTo(_statusSort(b.status));
      if (byStatus != 0) return byStatus;
      final byBook = a.bookTitle.compareTo(b.bookTitle);
      if (byBook != 0) return byBook;
      return a.chapterIndex.compareTo(b.chapterIndex);
    });
    return list;
  }

  int get totalSize =>
      _downloads.values.fold(0, (sum, item) => sum + item.fileSize);

  String get _currentServerKey {
    final rawServer = appState.serverUrl.trim().isNotEmpty
        ? appState.serverUrl
        : appState.localServerUrl.trim().isNotEmpty
            ? appState.localServerUrl
            : appState.activeUrl;
    return ApiClient.normalizeServerUrl(rawServer);
  }

  String? get _currentServerName {
    final raw = appState.serverUrl.trim().isNotEmpty
        ? appState.serverUrl
        : appState.localServerUrl.trim().isNotEmpty
            ? appState.localServerUrl
            : appState.activeUrl;
    final uri = Uri.tryParse(ApiClient.normalizeServerUrl(raw));
    final host = uri?.host;
    if (host == null || host.isEmpty) return null;
    return host;
  }

  String _currentRecordKey(String itemId) =>
      downloadRecordKey(_currentServerKey, itemId);

  String _legacyRecordKey(String itemId) =>
      downloadRecordKey(legacyDownloadServerKey, itemId);

  String? _downloadKeyFor(String idOrKey) {
    if (_downloads.containsKey(idOrKey)) return idOrKey;
    final current = _currentRecordKey(idOrKey);
    if (_downloads.containsKey(current)) return current;
    final legacy = _legacyRecordKey(idOrKey);
    if (_downloads.containsKey(legacy)) return legacy;
    return null;
  }

  String? _taskKeyFor(String idOrKey) {
    if (_tasks.containsKey(idOrKey)) return idOrKey;
    final current = _currentRecordKey(idOrKey);
    if (_tasks.containsKey(current)) return current;
    final legacy = _legacyRecordKey(idOrKey);
    if (_tasks.containsKey(legacy)) return legacy;
    return null;
  }

  String? _bookGroupKeyFor(String idOrKey) {
    if (_downloads.values.any((item) => item.bookGroupKey == idOrKey) ||
        _tasks.values.any((task) => task.bookGroupKey == idOrKey)) {
      return idOrKey;
    }
    final current = _currentRecordKey(idOrKey);
    if (_downloads.values.any((item) => item.bookGroupKey == current) ||
        _tasks.values.any((task) => task.bookGroupKey == current)) {
      return current;
    }
    final legacy = _legacyRecordKey(idOrKey);
    if (_downloads.values.any((item) => item.bookGroupKey == legacy) ||
        _tasks.values.any((task) => task.bookGroupKey == legacy)) {
      return legacy;
    }
    return null;
  }

  bool hasChapter(String chapterId) => findByChapter(chapterId) != null;

  LocalDownload? findByChapter(String chapterId) {
    return _downloads[_currentRecordKey(chapterId)] ??
        _downloads[_legacyRecordKey(chapterId)];
  }

  DownloadTask? taskForChapter(String chapterId) {
    return _tasks[_currentRecordKey(chapterId)] ??
        _tasks[_legacyRecordKey(chapterId)];
  }

  Future<void> initialize() async {
    if (kIsWeb) {
      notifyListeners();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _customCacheDirectory =
        _normalizeDirectoryPath(prefs.getString(_cacheDirectoryPrefsKey));
    await _useRootDirectory(await _resolveRootDirectory(_customCacheDirectory));
    await _loadIndex();
    _pumpQueue();
  }

  Future<void> setCacheDirectory(String? path) async {
    if (kIsWeb) return;
    final nextCustom = _normalizeDirectoryPath(path);
    final nextRoot = await _resolveRootDirectory(nextCustom);
    final currentRoot = _rootDir?.absolute.path;
    if (currentRoot == nextRoot.absolute.path &&
        _customCacheDirectory == nextCustom) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (nextCustom == null) {
      await prefs.remove(_cacheDirectoryPrefsKey);
    } else {
      await prefs.setString(_cacheDirectoryPrefsKey, nextCustom);
    }
    _customCacheDirectory = nextCustom;
    await _useRootDirectory(nextRoot);
    await _saveIndex();
    notifyListeners();
  }

  Future<void> setMaxConcurrentDownloads(int value) async {
    final next = value.clamp(1, 6).toInt();
    if (_maxConcurrentDownloads == next) return;
    _maxConcurrentDownloads = next;
    await _saveIndex();
    notifyListeners();
    _pumpQueue();
  }

  Future<String?> localPathForChapter(String chapterId) async {
    if (kIsWeb) return null;
    final key = _downloadKeyFor(chapterId);
    if (key == null) return null;
    return _localPathForDownloadKey(key);
  }

  Future<String?> localPathForDownload(LocalDownload download) async {
    if (kIsWeb) return null;
    return _localPathForDownloadKey(download.storageKey);
  }

  Future<String?> _localPathForDownloadKey(String key) async {
    final item = _downloads[key];
    if (item == null || item.filePath.isEmpty) return null;
    final file = File(item.filePath);
    if (await file.exists()) return item.filePath;
    _downloads.remove(key);
    await _saveIndex();
    notifyListeners();
    return null;
  }

  DownloadTask queueChapter(
    Book book,
    Chapter chapter, {
    bool transcode = false,
  }) {
    if (kIsWeb || _rootDir == null) {
      throw StateError(appState.textForLocale(
        '当前预览环境不支持本机下载，请在移动端或桌面端使用。',
        'Local downloads are unavailable in preview. Use the mobile or desktop app.',
      ));
    }
    final key = _currentRecordKey(chapter.id);
    final existingTask = _tasks[key];
    if (existingTask != null) return existingTask;
    final task = DownloadTask.fromBookChapter(
      book,
      chapter,
      serverKey: _currentServerKey,
      serverName: _currentServerName,
      transcode: transcode,
    );
    _prepareTaskPaths(task);
    _tasks[task.storageKey] = task;
    unawaited(_saveIndex());
    notifyListeners();
    _pumpQueue();
    return task;
  }

  Future<int> queueBook(Book book, List<Chapter> chapters) async {
    var queued = 0;
    final ordered = [...chapters]
      ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    for (final chapter in ordered) {
      if (hasChapter(chapter.id)) continue;
      final before = _tasks.containsKey(_currentRecordKey(chapter.id));
      queueChapter(book, chapter);
      if (!before) queued++;
    }
    return queued;
  }

  Future<LocalDownload> downloadChapter(
    Book book,
    Chapter chapter, {
    bool transcode = false,
  }) async {
    final existing = await localPathForChapter(chapter.id);
    if (existing != null) {
      return findByChapter(chapter.id)!;
    }
    final task = queueChapter(book, chapter, transcode: transcode);
    final completer = Completer<LocalDownload>();
    _waiters.putIfAbsent(task.storageKey, () => []).add(completer);
    return completer.future;
  }

  Future<int> downloadBook(Book book, List<Chapter> chapters) {
    return queueBook(book, chapters);
  }

  Future<void> pauseTask(String chapterId) async {
    final key = _taskKeyFor(chapterId);
    if (key == null) return;
    final task = _tasks[key];
    if (task == null) return;
    if (task.status == DownloadStatus.downloading) {
      task.status = DownloadStatus.paused;
      task.error = null;
      task.touch();
      _tokens.remove(key)?.cancel('paused');
    } else if (task.status == DownloadStatus.queued) {
      task.status = DownloadStatus.paused;
      task.error = null;
      task.touch();
    }
    await _saveIndex();
    notifyListeners();
    _pumpQueue();
  }

  Future<void> resumeTask(String chapterId) async {
    final key = _taskKeyFor(chapterId);
    if (key == null) return;
    final task = _tasks[key];
    if (task == null || _downloads.containsKey(task.storageKey)) return;
    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.queued) {
      return;
    }
    task.status = DownloadStatus.queued;
    task.error = null;
    task.touch();
    await _saveIndex();
    notifyListeners();
    _pumpQueue();
  }

  Future<void> retryTask(String chapterId) => resumeTask(chapterId);

  Future<void> deleteTask(String chapterId) async {
    final key = _taskKeyFor(chapterId) ?? chapterId;
    _tokens.remove(key)?.cancel('deleted');
    _running.remove(key);
    final task = _tasks.remove(key);
    if (!kIsWeb && task != null) {
      final tempPath = task.tempPath;
      if (tempPath != null && tempPath.isNotEmpty) {
        final temp = File(tempPath);
        if (await temp.exists()) await temp.delete();
      }
    }
    _completeWaitersWithError(
      key,
      StateError(appState.textForLocale(
        '下载任务已删除',
        'Download task was deleted',
      )),
    );
    await _saveIndex();
    notifyListeners();
    _pumpQueue();
  }

  Future<void> deleteChapter(String chapterId) async {
    final downloadKey = _downloadKeyFor(chapterId);
    final taskKey = _taskKeyFor(chapterId);
    final itemBefore = downloadKey == null ? null : _downloads[downloadKey];
    final taskBefore = taskKey == null ? null : _tasks[taskKey];
    final groupKey = itemBefore?.bookGroupKey ?? taskBefore?.bookGroupKey;
    final dirs = groupKey == null ? <String>{} : _bookDirPaths(groupKey);
    if (taskKey != null) await deleteTask(taskKey);
    final item = downloadKey == null ? null : _downloads.remove(downloadKey);
    if (!kIsWeb && item != null && item.filePath.isNotEmpty) {
      final file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    if (!kIsWeb && groupKey != null && _rootDir != null) {
      final hasRemaining =
          _downloads.values.any((item) => item.bookGroupKey == groupKey) ||
              _tasks.values.any((task) => task.bookGroupKey == groupKey);
      if (!hasRemaining) {
        for (final path in dirs) {
          final dir = Directory(path);
          if (await dir.exists()) await dir.delete(recursive: true);
        }
      }
    }
    await _saveIndex();
    notifyListeners();
  }

  Future<void> deleteBook(String bookId) async {
    final groupKey = _bookGroupKeyFor(bookId) ?? bookId;
    final dirs = _bookDirPaths(groupKey);
    final downloadedIds = _downloads.values
        .where((item) => item.bookGroupKey == groupKey)
        .map((item) => item.storageKey)
        .toList();
    final taskIds = _tasks.values
        .where((task) => task.bookGroupKey == groupKey)
        .map((task) => task.storageKey)
        .toList();
    for (final id in {...downloadedIds, ...taskIds}) {
      await deleteChapter(id);
    }
    if (!kIsWeb && _rootDir != null) {
      for (final path in dirs) {
        final dir = Directory(path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    }
  }

  Future<void> clearAll() async {
    final ids = {..._downloads.keys, ..._tasks.keys}.toList();
    for (final id in ids) {
      await deleteChapter(id);
    }
  }

  Future<void> clearFinishedTasks() async {
    _tasks.removeWhere((_, task) => task.status == DownloadStatus.completed);
    await _saveIndex();
    notifyListeners();
  }

  Future<void> _loadIndex() async {
    final file = _indexFile;
    if (file == null || !await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      final downloadItems = decoded is List
          ? decoded
          : decoded is Map
              ? decoded['downloads']
              : const [];
      final taskItems = decoded is Map ? decoded['tasks'] : const <dynamic>[];
      final settings = decoded is Map ? asMap(decoded['settings']) : {};
      _maxConcurrentDownloads =
          (_int(settings['max_concurrent_downloads']) ?? 2).clamp(1, 6).toInt();
      _downloads
        ..clear()
        ..addEntries(
          (downloadItems is List ? downloadItems : const [])
              .map((item) => LocalDownload.fromJson(asMap(item)))
              .where((item) =>
                  item.chapterId.isNotEmpty && item.filePath.isNotEmpty)
              .map((item) => MapEntry(item.storageKey, item)),
        );
      _tasks
        ..clear()
        ..addEntries(
          (taskItems is List ? taskItems : const [])
              .map((item) => DownloadTask.fromJson(asMap(item)))
              .where((task) =>
                  task.chapterId.isNotEmpty &&
                  task.bookId.isNotEmpty &&
                  task.chapterPath.isNotEmpty &&
                  !_downloads.containsKey(task.storageKey))
              .map((task) => MapEntry(task.storageKey, task)),
        );
    } catch (_) {
      _downloads.clear();
      _tasks.clear();
    }
    await _pruneMissingFiles();
    await _refreshPartialSizes();
    notifyListeners();
  }

  Future<void> _pruneMissingFiles() async {
    final missing = <String>[];
    for (final entry in _downloads.entries) {
      if (!await File(entry.value.filePath).exists()) {
        missing.add(entry.key);
      }
    }
    if (missing.isEmpty) return;
    for (final id in missing) {
      _downloads.remove(id);
    }
    await _saveIndex();
  }

  Future<void> _refreshPartialSizes() async {
    for (final task in _tasks.values) {
      final tempPath = task.tempPath;
      if (tempPath == null || tempPath.isEmpty) continue;
      final temp = File(tempPath);
      if (!await temp.exists()) continue;
      task.receivedBytes = await temp.length();
      if (task.totalBytes > 0) {
        task.progress = (task.receivedBytes / task.totalBytes).clamp(0, 1);
      }
    }
  }

  Future<void> _saveIndex() async {
    final file = _indexFile;
    if (file == null) return;
    final tasks = _tasks.values
        .where((task) => task.status != DownloadStatus.completed)
        .map((task) => task.toJson())
        .toList();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        {
          'version': 2,
          'settings': {
            'max_concurrent_downloads': _maxConcurrentDownloads,
            if (_customCacheDirectory != null)
              'cache_directory': _customCacheDirectory,
          },
          'downloads': _downloads.values.map((item) => item.toJson()).toList(),
          'tasks': tasks,
        },
      ),
      flush: true,
    );
  }

  void _pumpQueue() {
    if (kIsWeb || _rootDir == null) return;
    while (_running.length < _maxConcurrentDownloads) {
      DownloadTask? next;
      for (final task in _tasks.values) {
        if (task.status == DownloadStatus.queued && _canRunTask(task)) {
          next = task;
          break;
        }
      }
      if (next == null) return;
      _startTask(next);
    }
  }

  void _startTask(DownloadTask task) {
    if (!_canRunTask(task)) return;
    final key = task.storageKey;
    if (_running.containsKey(key)) return;
    final token = CancelToken();
    _tokens[key] = token;
    task.status = DownloadStatus.downloading;
    task.error = null;
    task.touch();
    notifyListeners();
    _running[key] = _runTask(task, token).whenComplete(() {
      _running.remove(key);
      _tokens.remove(key);
      _pumpQueue();
    });
  }

  Future<void> _runTask(DownloadTask task, CancelToken token) async {
    _prepareTaskPaths(task);
    await _saveIndex();

    var tempPath = task.tempPath;
    var filePath = task.filePath;
    if (tempPath == null || filePath == null) return;

    var tempFile = File(tempPath);
    if (!await tempFile.parent.exists()) {
      await tempFile.parent.create(recursive: true);
    }
    final transcode = _shouldTranscode(task);
    if (transcode && await tempFile.exists()) {
      await tempFile.delete();
    }
    final existingBytes = await tempFile.exists() ? await tempFile.length() : 0;
    task.receivedBytes = existingBytes;
    if (task.totalBytes > 0) {
      task.progress = (existingBytes / task.totalBytes).clamp(0, 1);
    }
    notifyListeners();

    IOSink? sink;
    var append = false;
    var receivedThisRequest = 0;
    try {
      final headers = <String, dynamic>{
        if (appState.token != null && appState.token!.isNotEmpty)
          'Authorization': 'Bearer ${appState.token}',
        if (existingBytes > 0) 'Range': 'bytes=$existingBytes-',
      };
      final response = await _dio.get<ResponseBody>(
        _streamUrl(task.chapterId, transcode: transcode),
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 500,
        ),
      );
      if (response.statusCode == 416) {
        if (await tempFile.exists()) await tempFile.delete();
        task.receivedBytes = 0;
        task.totalBytes = 0;
        task.progress = 0;
        task.status = DownloadStatus.queued;
        await _saveIndex();
        notifyListeners();
        return;
      }
      if (response.statusCode == null || response.statusCode! >= 400) {
        throw StateError('HTTP ${response.statusCode}');
      }

      append = existingBytes > 0 && response.statusCode == 206;
      if (existingBytes > 0 && !append && await tempFile.exists()) {
        await tempFile.delete();
        task.receivedBytes = 0;
      }

      if (!append && !transcode) {
        final responseExtension =
            _downloadExtensionFromHeaders(response.headers);
        if (responseExtension != null &&
            responseExtension != _extensionFromPath(filePath)) {
          filePath = _replacePathExtension(filePath, responseExtension);
          tempPath = '$filePath.part';
          task.filePath = filePath;
          task.tempPath = tempPath;
          tempFile = File(tempPath);
          if (!await tempFile.parent.exists()) {
            await tempFile.parent.create(recursive: true);
          }
        }
      }

      final responseBody = response.data;
      if (responseBody == null) {
        throw StateError(appState.textForLocale(
          '响应体为空',
          'Empty response body',
        ));
      }
      final contentRange = response.headers.value('content-range');
      final rangeTotal = _parseContentRangeTotal(contentRange);
      final contentLength =
          int.tryParse(response.headers.value('content-length') ?? '');
      final totalBytes = rangeTotal ??
          (contentLength == null
              ? task.totalBytes
              : contentLength + (append ? existingBytes : 0));
      task.totalBytes = totalBytes > 0
          ? totalBytes
          : _estimatedDownloadBytes(task, transcode);

      sink =
          tempFile.openWrite(mode: append ? FileMode.append : FileMode.write);
      await for (final chunk in responseBody.stream) {
        sink.add(chunk);
        receivedThisRequest += chunk.length;
        task.receivedBytes = (append ? existingBytes : 0) + receivedThisRequest;
        if (task.totalBytes <= 0) {
          task.totalBytes = _estimatedDownloadBytes(task, transcode);
        }
        if (task.totalBytes > 0) {
          task.progress = (task.receivedBytes / task.totalBytes).clamp(0, 1);
        }
        task.touch();
        notifyListeners();
      }
      await sink.flush();
      await sink.close();
      sink = null;

      final file = File(filePath);
      if (await file.exists()) await file.delete();
      await tempFile.rename(file.path);
      final size = await file.length();
      final localCoverPath = await _cacheBookResources(task, token);
      final item = LocalDownload(
        chapterId: task.chapterId,
        bookId: task.bookId,
        bookTitle: task.bookTitle,
        chapterTitle: task.chapterTitle,
        chapterIndex: task.chapterIndex,
        filePath: file.path,
        fileSize: size,
        createdAt: DateTime.now(),
        coverUrl: task.coverUrl,
        localCoverPath: localCoverPath,
        libraryId: task.libraryId,
        duration: task.duration,
        isExtra: task.isExtra,
        bookMetadata: task.bookMetadata,
        serverKey: task.serverKey,
        serverName: task.serverName,
      );
      _downloads[task.storageKey] = item;
      task.status = DownloadStatus.completed;
      task.progress = 1;
      task.receivedBytes = size;
      task.totalBytes = size;
      task.touch();
      _completeWaiters(task.storageKey, item);
      await _saveIndex();
      notifyListeners();
      unawaited(Future<void>.delayed(const Duration(seconds: 2), () async {
        if (_tasks[task.storageKey]?.status == DownloadStatus.completed) {
          _tasks.remove(task.storageKey);
          await _saveIndex();
          notifyListeners();
        }
      }));
    } catch (error) {
      await sink?.close();
      if (error is DioException &&
          CancelToken.isCancel(error) &&
          task.status == DownloadStatus.paused) {
        await _saveIndex();
        notifyListeners();
        return;
      }
      if (!_tasks.containsKey(task.storageKey)) return;
      task.status = DownloadStatus.failed;
      task.error = error.toString();
      task.touch();
      _completeWaitersWithError(task.chapterId, error);
      await _saveIndex();
      notifyListeners();
    }
  }

  bool _canRunTask(DownloadTask task) {
    return task.serverKey == legacyDownloadServerKey ||
        task.serverKey == _currentServerKey;
  }

  void _prepareTaskPaths(DownloadTask task) {
    final root = _rootDir;
    if (root == null) {
      return;
    }
    final sourceExtension = _extensionFromPath(task.chapterPath);
    final shouldTranscode = _shouldTranscode(task);
    final extension = shouldTranscode ? 'mp3' : sourceExtension;
    if (task.filePath != null && task.tempPath != null) {
      final currentExtension = _extensionFromPath(task.filePath!);
      if (task.status == DownloadStatus.completed ||
          currentExtension == extension) {
        return;
      }
      task.filePath = null;
      task.tempPath = null;
    }
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}${_safeSegment(task.serverKey)}'
      '${Platform.pathSeparator}${_safeSegment(task.bookId)}',
    );
    final fileName =
        '${task.chapterIndex.toString().padLeft(4, '0')}_${_safeSegment(task.chapterId)}.$extension';
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    task.filePath ??= file.path;
    task.tempPath ??= '${file.path}.part';
  }

  Directory _bookDir(String bookId) {
    final root = _rootDir!;
    return Directory(
      '${root.path}${Platform.pathSeparator}${_safeSegment(_currentServerKey)}'
      '${Platform.pathSeparator}${_safeSegment(bookId)}',
    );
  }

  Directory _bookDirForTask(DownloadTask task) {
    final filePath = task.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      return File(filePath).parent;
    }
    return _bookDir(task.bookId);
  }

  Set<String> _bookDirPaths(String groupKey) {
    final paths = <String>{};
    for (final item in _downloads.values) {
      if (item.bookGroupKey == groupKey && item.filePath.isNotEmpty) {
        paths.add(File(item.filePath).parent.path);
      }
    }
    for (final task in _tasks.values) {
      if (task.bookGroupKey == groupKey) {
        final filePath = task.filePath;
        if (filePath != null && filePath.isNotEmpty) {
          paths.add(File(filePath).parent.path);
        }
      }
    }
    return paths;
  }

  Future<String?> _cacheBookResources(
    DownloadTask task,
    CancelToken token,
  ) async {
    final dir = _bookDirForTask(task);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final localCoverPath = await _cacheCover(task, dir, token);
    await _writeBookMetadata(task, dir, localCoverPath);
    await _writeChapterMetadata(task, dir);
    return localCoverPath;
  }

  Future<String?> _cacheCover(
    DownloadTask task,
    Directory dir,
    CancelToken token,
  ) async {
    final existing = await _existingCoverPath(dir);
    if (existing != null) return existing;

    final source = coverUrl(
      appState,
      url: task.coverUrl,
      libraryId: task.libraryId,
      bookId: task.bookId,
    );
    if (source.isEmpty) return null;

    try {
      final headers = <String, dynamic>{
        if (appState.token != null && appState.token!.isNotEmpty)
          'Authorization': 'Bearer ${appState.token}',
      };
      final response = await _dio.get<List<int>>(
        source,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      final extension = _coverExtension(
        contentType: response.headers.value('content-type'),
        source: source,
      );
      final file = File('${dir.path}${Platform.pathSeparator}cover.$extension');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      return null;
    }
  }

  Future<String?> _existingCoverPath(Directory dir) async {
    for (final extension in const ['jpg', 'jpeg', 'png', 'webp', 'gif']) {
      final file = File('${dir.path}${Platform.pathSeparator}cover.$extension');
      if (await file.exists() && await file.length() > 0) return file.path;
    }
    return null;
  }

  Future<void> _writeBookMetadata(
    DownloadTask task,
    Directory dir,
    String? localCoverPath,
  ) async {
    final file = File('${dir.path}${Platform.pathSeparator}book.json');
    final metadata = {
      ...task.bookMetadata,
      'id': task.bookId,
      'library_id': task.libraryId,
      'title': task.bookTitle,
      if (task.coverUrl != null) 'cover_url': task.coverUrl,
      if (localCoverPath != null) 'local_cover_path': localCoverPath,
      'updated_at': DateTime.now().toIso8601String(),
    }..removeWhere((_, value) => value == null || value == '');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata),
      flush: true,
    );
  }

  Future<void> _writeChapterMetadata(DownloadTask task, Directory dir) async {
    final file = File('${dir.path}${Platform.pathSeparator}chapters.json');
    final existing = <String, Map<String, dynamic>>{};
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          for (final item in decoded) {
            final map = asMap(item);
            final id = _string(map['id']) ?? _string(map['chapter_id']);
            if (id != null) existing[id] = map;
          }
        }
      } catch (_) {
        existing.clear();
      }
    }

    existing[task.chapterId] = {
      'id': task.chapterId,
      'book_id': task.bookId,
      'title': task.chapterTitle,
      'chapter_index': task.chapterIndex,
      'duration': task.duration,
      'is_extra': task.isExtra,
      'source_path': task.chapterPath,
      'local_file_path': task.filePath,
      'downloaded_at': DateTime.now().toIso8601String(),
    }..removeWhere((_, value) => value == null || value == '');

    final chapters = existing.values.toList()
      ..sort((a, b) => (_int(a['chapter_index']) ?? 0)
          .compareTo(_int(b['chapter_index']) ?? 0));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(chapters),
      flush: true,
    );
  }

  bool _shouldTranscode(DownloadTask task) {
    final sourceExtension = _extensionFromPath(task.chapterPath);
    if (task.transcode ||
        _alwaysTranscodeDownloadExtensions.contains(sourceExtension)) {
      return true;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return _androidTranscodeDownloadExtensions.contains(sourceExtension);
    }
    return false;
  }

  int _estimatedDownloadBytes(DownloadTask task, bool transcode) {
    if (!transcode || task.duration == null || task.duration! <= 0) return 0;
    const estimatedMp3BytesPerSecond = 16000;
    return task.duration! * estimatedMp3BytesPerSecond;
  }

  String _streamUrl(String chapterId, {bool transcode = false}) {
    final params = <String, String>{
      'download': '1',
      if (appState.token != null && appState.token!.isNotEmpty)
        'token': appState.token!,
      if (transcode) 'transcode': 'mp3',
    };
    final base = '${appState.activeUrl}/api/stream/$chapterId';
    if (params.isEmpty) return base;
    return Uri.parse(base).replace(queryParameters: params).toString();
  }

  void _completeWaiters(String chapterId, LocalDownload item) {
    final waiters = _waiters.remove(chapterId) ?? const [];
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete(item);
    }
  }

  void _completeWaitersWithError(String chapterId, Object error) {
    final waiters = _waiters.remove(chapterId) ?? const [];
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.completeError(error);
    }
  }

  Future<void> _useRootDirectory(Directory dir) async {
    if (await dir.exists()) {
      final type = await FileSystemEntity.type(dir.path);
      if (type != FileSystemEntityType.directory) {
        throw StateError(appState.textForLocale(
          '缓存位置不是文件夹：${dir.path}',
          'Cache location is not a folder: ${dir.path}',
        ));
      }
    } else {
      await dir.create(recursive: true);
    }
    _rootDir = dir;
    _indexFile = File('${dir.path}${Platform.pathSeparator}downloads.json');
  }

  Future<Directory> _resolveRootDirectory(String? customPath) async {
    final path = _normalizeDirectoryPath(customPath);
    if (path != null) return Directory(path);
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return Directory(
          '${external.path}${Platform.pathSeparator}ting_reader_downloads',
        );
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    return Directory(
      '${docs.path}${Platform.pathSeparator}ting_reader_downloads',
    );
  }
}
