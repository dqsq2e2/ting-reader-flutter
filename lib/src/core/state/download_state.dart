import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../utils/urls.dart';
import 'app_state.dart';
import 'download/download_helpers.dart';
import 'download/download_models.dart';
import 'download/download_storage.dart';
import 'download/download_transfer.dart';

export 'download/download_models.dart';

/// Owns task states, scheduling, waiters and cancellation. Transfers and disk
/// snapshots have separate owners, independent of application and UI state.
///
/// Persistence layout under the user-chosen cache directory:
///   - `downloads.json`                – combined index (downloads + tasks)
///   - `<serverKey>/<bookId>/<chapterIndex>_<chapterId>.<ext>` – audio file
///   - `<serverKey>/<bookId>/cover.<ext>`                       – cached cover
///   - `<serverKey>/<bookId>/book.json`, `chapters.json`        – metadata
class DownloadState extends ChangeNotifier {
  DownloadState(this.appState, {Dio? httpClient})
      : _transfer = DownloadTransfer(httpClient: httpClient);

  final AppState appState;
  final DownloadTransfer _transfer;
  final DownloadStorage _storage = DownloadStorage();
  final Map<String, Timer> _completionTimers = {};
  bool _disposed = false;
  Future<void>? _initialization;

  int _maxConcurrentDownloads = 2;
  final Map<String, LocalDownload> _downloads = {};
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, CancelToken> _tokens = {};
  final Map<String, Future<void>> _running = {};
  final Map<String, Future<void>> _deletions = {};
  final Map<String, List<Completer<LocalDownload>>> _waiters = {};

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  void _checkTask(DownloadTask task, CancelToken token) {
    if (_disposed || !identical(_tasks[task.storageKey], task)) {
      if (!token.isCancelled) token.cancel('download stopped');
    }
    final cancellation = token.cancelError;
    if (cancellation != null) throw cancellation;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final timer in _completionTimers.values) {
      timer.cancel();
    }
    _completionTimers.clear();
    for (final token in _tokens.values) {
      if (!token.isCancelled) token.cancel('download state disposed');
    }
    _transfer.dispose();
    for (final key in _waiters.keys.toList()) {
      _completeWaitersWithError(key, StateError('Download state disposed'));
    }
    super.dispose();
  }

  /// Wait until cancellation and all already-submitted disk writes have settled.
  Future<void> close() async {
    dispose();
    await Future.wait(_running.values.toList());
    await Future.wait(_deletions.values.toList());
    await _storage.flush();
  }

  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  String? get cacheDirectoryPath => _storage.directory?.path;

  String? get customCacheDirectory => _storage.customDirectory;

  bool get usingCustomCacheDirectory =>
      _storage.customDirectory?.isNotEmpty == true;

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
      final byStatus = downloadStatusOrder(a.status)
          .compareTo(downloadStatusOrder(b.status));
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
    final uri = Uri.tryParse(_currentServerKey);
    final host = uri?.host;
    if (host == null || host.isEmpty) return null;
    return host;
  }

  String _currentRecordKey(String itemId) =>
      downloadRecordKey(_currentServerKey, itemId);

  String _legacyRecordKey(String itemId) =>
      downloadRecordKey(legacyDownloadServerKey, itemId);

  String? _downloadKeyFor(String idOrKey) =>
      _findRecordKey(_downloads.keys, idOrKey);
  String? _taskKeyFor(String idOrKey) => _findRecordKey(_tasks.keys, idOrKey);

  String? _bookGroupKeyFor(String idOrKey) {
    return _findRecordKey({
      ..._downloads.values.map((item) => item.bookGroupKey),
      ..._tasks.values.map((task) => task.bookGroupKey),
    }, idOrKey);
  }

  String? _findRecordKey(Iterable<String> keys, String idOrKey) {
    for (final candidate in [
      idOrKey,
      _currentRecordKey(idOrKey),
      _legacyRecordKey(idOrKey)
    ]) {
      if (keys.contains(candidate)) return candidate;
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

  bool canQueueChapter(String chapterId) =>
      !hasChapter(chapterId) && taskForChapter(chapterId) == null;

  /// Every single-chapter entry follows the same start/resume policy.
  /// Batch selection can preserve existing paused tasks.
  Future<DownloadRequestResult> requestChapter(
    Book book,
    Chapter chapter, {
    bool transcode = false,
    bool resumeExisting = true,
  }) async {
    _checkActive();
    if (hasChapter(chapter.id)) {
      return const DownloadRequestResult(DownloadRequestOutcome.downloaded);
    }
    final task = taskForChapter(chapter.id);
    if (task != null) {
      if (resumeExisting &&
          (task.status == DownloadStatus.paused ||
              task.status == DownloadStatus.failed)) {
        await resumeTask(task.storageKey);
        _checkActive();
        return DownloadRequestResult(DownloadRequestOutcome.resumed,
            status: task.status);
      }
      return DownloadRequestResult(DownloadRequestOutcome.existing,
          status: task.status);
    }
    final queued = queueChapter(book, chapter, transcode: transcode);
    return DownloadRequestResult(DownloadRequestOutcome.queued,
        status: queued.status);
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (_disposed) return;
    if (kIsWeb) {
      _notifyIfActive();
      return;
    }
    await _storage.initialize(_checkActive);
    if (_disposed) return;
    await _loadIndex();
    _pumpQueue();
  }

  Future<void> setCacheDirectory(String? path) async {
    if (_disposed || kIsWeb) return;
    await _initialization;
    if (_disposed) return;
    if (!await _storage.configureDirectory(path, _checkActive)) return;
    await _saveIndex();
    _notifyIfActive();
  }

  Future<void> setMaxConcurrentDownloads(int value) async {
    final next = value.clamp(1, 6).toInt();
    if (_maxConcurrentDownloads == next) return;
    _maxConcurrentDownloads = next;
    await _saveIndex();
    _notifyIfActive();
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
    if (await _storage.existingFile(item.filePath) != null) {
      return item.filePath;
    }
    _downloads.remove(key);
    await _saveIndex();
    _notifyIfActive();
    return null;
  }

  DownloadTask queueChapter(
    Book book,
    Chapter chapter, {
    bool transcode = false,
  }) {
    if (_disposed) throw StateError("Download state disposed");
    if (kIsWeb || _storage.directory == null) {
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
    _storage.preparePaths(task, transcode: shouldTranscodeDownload(task));
    _tasks[task.storageKey] = task;
    _saveIndexInBackground();
    _notifyIfActive();
    _pumpQueue();
    return task;
  }

  Future<int> queueBook(Book book, List<Chapter> chapters) async {
    var queued = 0;
    final ordered = [...chapters]
      ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    for (final chapter in ordered) {
      final result = await requestChapter(book, chapter, resumeExisting: false);
      if (result.outcome == DownloadRequestOutcome.queued) queued++;
    }
    return queued;
  }

  Future<LocalDownload> downloadChapter(
    Book book,
    Chapter chapter, {
    bool transcode = false,
  }) async {
    if (_disposed) throw StateError('Download state disposed');
    final serverKey = _currentServerKey;
    final existingKey = _downloadKeyFor(chapter.id);
    final existing = existingKey == null ? null : _downloads[existingKey];
    if (existing != null &&
        await _storage.existingFile(existing.filePath) != null) {
      return existing;
    }
    if (_disposed) throw StateError('Download state disposed');
    if (_currentServerKey != serverKey) {
      throw StateError('Server changed during download setup');
    }
    final task = queueChapter(book, chapter, transcode: transcode);
    final completer = Completer<LocalDownload>();
    _waiters.putIfAbsent(task.storageKey, () => []).add(completer);
    if (task.status == DownloadStatus.failed ||
        task.status == DownloadStatus.paused) {
      await resumeTask(task.storageKey);
    }
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
      final token = _tokens[key];
      if (token != null && !token.isCancelled) token.cancel('paused');
    } else if (task.status == DownloadStatus.queued) {
      task.status = DownloadStatus.paused;
      task.error = null;
      task.touch();
    }
    _completeWaitersWithError(key, StateError('Download paused'));
    await _running[key];
    await _saveIndex();
    _notifyIfActive();
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
    await _running[key];
    if (_disposed || !identical(_tasks[key], task)) return;
    task.status = DownloadStatus.queued;
    task.error = null;
    task.touch();
    await _saveIndex();
    _notifyIfActive();
    _pumpQueue();
  }

  Future<void> retryTask(String chapterId) => resumeTask(chapterId);

  Future<void> _deleteLocked(String key, Future<void> Function() operation) {
    final pending = _deletions[key];
    if (pending != null) return pending;
    late final Future<void> result;
    result = operation().whenComplete(() {
      if (identical(_deletions[key], result)) _deletions.remove(key);
      _pumpQueue();
    });
    _deletions[key] = result;
    return result;
  }

  Future<void> deleteTask(String chapterId) {
    final key = _taskKeyFor(chapterId) ?? _currentRecordKey(chapterId);
    return _deleteLocked(key, () => _deleteTask(key));
  }

  Future<void> _deleteTask(String key) async {
    final token = _tokens[key];
    if (token != null && !token.isCancelled) token.cancel('deleted');
    _completionTimers.remove(key)?.cancel();
    final task = _tasks.remove(key);
    _completeWaitersWithError(key, StateError('Download task deleted'));
    await _running[key];
    if (!kIsWeb && task != null) {
      final tempPath = task.tempPath;
      if (tempPath != null && tempPath.isNotEmpty) {
        await _storage.deleteFile(tempPath);
      }
    }
    await _saveIndex();
    _notifyIfActive();
    _pumpQueue();
  }

  Future<void> deleteChapter(String chapterId) {
    final key = _downloadKeyFor(chapterId) ??
        _taskKeyFor(chapterId) ??
        _currentRecordKey(chapterId);
    return _deleteLocked(key, () => _deleteChapter(key));
  }

  Future<void> _deleteChapter(String chapterId) async {
    final downloadKey = _downloadKeyFor(chapterId);
    final taskKey = _taskKeyFor(chapterId);
    final itemBefore = downloadKey == null ? null : _downloads[downloadKey];
    final taskBefore = taskKey == null ? null : _tasks[taskKey];
    final groupKey = itemBefore?.bookGroupKey ?? taskBefore?.bookGroupKey;
    final dirs = groupKey == null
        ? <String>{}
        : _storage.bookDirectories(groupKey, _downloads.values, _tasks.values);
    if (taskKey != null) await _deleteTask(taskKey);
    final item = _downloads.remove(downloadKey ?? taskKey ?? chapterId);
    if (!kIsWeb && item != null && item.filePath.isNotEmpty) {
      await _storage.deleteFile(item.filePath);
    }
    if (!kIsWeb && groupKey != null && _storage.directory != null) {
      final hasRemaining =
          _downloads.values.any((item) => item.bookGroupKey == groupKey) ||
              _tasks.values.any((task) => task.bookGroupKey == groupKey);
      if (!hasRemaining) {
        await _storage.cleanBookDirectories(dirs);
      }
    }
    await _saveIndex();
    _notifyIfActive();
  }

  Future<void> deleteBook(String bookId) {
    final groupKey = _bookGroupKeyFor(bookId) ?? bookId;
    return _deleteLocked('book:$groupKey', () => _deleteBook(groupKey));
  }

  Future<void> _deleteBook(String groupKey) async {
    final dirs =
        _storage.bookDirectories(groupKey, _downloads.values, _tasks.values);
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
    if (!kIsWeb && _storage.directory != null) {
      await _storage.cleanBookDirectories(dirs);
    }
  }

  Future<void> clearAll() => _deleteLocked('*', _clearAll);

  Future<void> _clearAll() async {
    final ids = {..._downloads.keys, ..._tasks.keys}.toList();
    for (final id in ids) {
      await deleteChapter(id);
    }
  }

  Future<void> clearFinishedTasks() async {
    _tasks.removeWhere((_, task) => task.status == DownloadStatus.completed);
    await _saveIndex();
    _notifyIfActive();
  }

  void _checkActive() {
    if (_disposed) throw StateError('Download state disposed');
  }

  Future<void> _loadIndex() async {
    if (_disposed) return;
    final index = await _storage.readIndex(_checkActive);
    if (index == null || _disposed) return;
    _maxConcurrentDownloads = index.maxConcurrent;
    _downloads
      ..clear()
      ..addEntries(
          index.downloads.map((item) => MapEntry(item.storageKey, item)));
    _tasks
      ..clear()
      ..addEntries(index.tasks.map((task) => MapEntry(task.storageKey, task)));
    await _saveIndex();
    _notifyIfActive();
  }

  Future<void> _saveIndex() => _disposed
      ? Future<void>.value()
      : _storage.saveIndex(DownloadIndex(
          downloads: _downloads.values.toList(),
          tasks: _tasks.values.toList(),
          maxConcurrent: _maxConcurrentDownloads));

  void _saveIndexInBackground() {
    unawaited(_saveIndex().catchError((Object error, StackTrace stack) {
      debugPrint('Failed to save download index: $error');
    }));
  }

  void _pumpQueue() {
    if (_disposed || kIsWeb || _storage.directory == null) return;
    while (_running.length < _maxConcurrentDownloads) {
      DownloadTask? next;
      for (final task in _tasks.values) {
        if (task.status == DownloadStatus.queued &&
            !_running.containsKey(task.storageKey) &&
            _canRunTask(task)) {
          next = task;
          break;
        }
      }
      if (next == null) return;
      _startTask(next);
    }
  }

  void _startTask(DownloadTask task) {
    if (_disposed || !_canRunTask(task)) return;
    final key = task.storageKey;
    if (_running.containsKey(key)) return;
    final token = CancelToken();
    _tokens[key] = token;
    task.status = DownloadStatus.downloading;
    task.error = null;
    task.touch();
    _notifyIfActive();
    _running[key] = _runTask(task, token).whenComplete(() {
      _running.remove(key);
      _tokens.remove(key);
      _pumpQueue();
    });
  }

  Future<void> _runTask(DownloadTask task, CancelToken token) async {
    try {
      _checkTask(task, token);
      final transcode = shouldTranscodeDownload(task);
      // Capture the authenticated source before a disk operation can yield.
      final requestUrl = _streamUrl(task.chapterId, transcode: transcode);
      final requestHeaders =
          Map<String, dynamic>.from(appState.api.authHeaders);
      final coverSource = coverUrl(appState,
          url: task.coverUrl, libraryId: task.libraryId, bookId: task.bookId);
      _storage.preparePaths(task, transcode: transcode);
      await _saveIndex();
      _checkTask(task, token);
      final item = await _transfer.run(task, token,
          storage: _storage,
          transcode: transcode,
          requestUrl: requestUrl,
          coverSource: coverSource,
          requestHeaders: requestHeaders,
          checkActive: () => _checkTask(task, token),
          onProgress: _notifyIfActive,
          retainPartial: () => identical(_tasks[task.storageKey], task));
      if (item != null &&
          (_disposed ||
              token.isCancelled ||
              !identical(_tasks[task.storageKey], task))) {
        final rollbackPath = task.tempPath;
        if (rollbackPath == null) {
          throw StateError('Download temporary path is missing');
        }
        await _storage.rollbackAudio(item.filePath, rollbackPath,
            keepPartial: identical(_tasks[task.storageKey], task));
      }
      _checkTask(task, token);
      if (item == null) {
        task.status = DownloadStatus.queued;
        await _saveIndex();
        _notifyIfActive();
        return;
      }
      _downloads[task.storageKey] = item;
      task.status = DownloadStatus.completed;
      task.progress = 1;
      task.receivedBytes = task.totalBytes = item.fileSize;
      task.touch();
      await _saveIndex();
      _checkTask(task, token);
      _completeWaiters(task.storageKey, item);
      _notifyIfActive();
      _completionTimers.remove(task.storageKey)?.cancel();
      _completionTimers[task.storageKey] =
          Timer(const Duration(seconds: 2), () {
        _completionTimers.remove(task.storageKey);
        if (!_disposed &&
            identical(_tasks[task.storageKey], task) &&
            task.status == DownloadStatus.completed) {
          _tasks.remove(task.storageKey);
          _saveIndexInBackground();
          _notifyIfActive();
        }
      });
    } catch (error) {
      if (_disposed || !identical(_tasks[task.storageKey], task)) return;
      if (error is DioException &&
          CancelToken.isCancel(error) &&
          task.status == DownloadStatus.paused) {
        await _saveIndex();
        _notifyIfActive();
        return;
      }
      task.status = DownloadStatus.failed;
      task.error = error.toString();
      task.touch();
      _completeWaitersWithError(task.storageKey, error);
      try {
        await _saveIndex();
      } catch (error) {
        debugPrint('Failed to persist failed download: $error');
      }
      _notifyIfActive();
    }
  }

  bool _canRunTask(DownloadTask task) {
    return !_deletions.containsKey('*') &&
        !_deletions.containsKey(task.storageKey) &&
        !_deletions.containsKey('book:${task.bookGroupKey}') &&
        (task.serverKey == legacyDownloadServerKey ||
            task.serverKey == _currentServerKey);
  }

  String _streamUrl(String chapterId, {bool transcode = false}) {
    final token = appState.token;
    final params = <String, String>{
      'download': '1',
      if (token != null && token.isNotEmpty) 'token': token,
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
}
