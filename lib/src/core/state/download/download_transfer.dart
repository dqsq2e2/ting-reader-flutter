import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'download_helpers.dart';
import 'download_models.dart';
import 'download_storage.dart';

/// Owns HTTP streams and transfer cleanup. Scheduling and terminal task states
/// belong to DownloadState; storage owns layouts, indexes and shared book assets.
class DownloadTransfer {
  DownloadTransfer({Dio? httpClient})
      : _dio = httpClient ??
            Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(minutes: 30)));
  final Dio _dio;
  void dispose() => _dio.close(force: true);

  /// null means a stale byte range was discarded and needs a fresh request.
  Future<LocalDownload?> run(
    DownloadTask task,
    CancelToken token, {
    required DownloadStorage storage,
    required bool transcode,
    required String requestUrl,
    required String coverSource,
    required Map<String, dynamic> requestHeaders,
    required void Function() checkActive,
    required void Function() onProgress,
    required bool Function() retainPartial,
  }) async {
    IOSink? sink;
    File? promotedFile;
    File? partialFile;
    ResponseBody? body;
    var bodyConsumed = false;
    try {
      checkActive();
      storage.preparePaths(task, transcode: transcode);
      var tempPath = task.tempPath;
      var filePath = task.filePath;
      if (tempPath == null || filePath == null) {
        throw StateError('Missing download file paths');
      }

      var tempFile = File(tempPath);
      if (!await tempFile.parent.exists()) {
        await tempFile.parent.create(recursive: true);
      }
      if (transcode && await tempFile.exists()) {
        await tempFile.delete();
      }
      final existingBytes =
          await tempFile.exists() ? await tempFile.length() : 0;
      task.receivedBytes = existingBytes;
      if (task.totalBytes > 0) {
        task.progress = (existingBytes / task.totalBytes).clamp(0, 1);
      }
      onProgress();

      var append = false;
      var receivedThisRequest = 0;
      checkActive();
      final headers = <String, dynamic>{
        ...requestHeaders,
        if (existingBytes > 0) 'Range': 'bytes=$existingBytes-',
      };
      final response = await _dio.get<ResponseBody>(
        requestUrl,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 500,
        ),
      );
      body = response.data;
      checkActive();
      if (response.statusCode == 416) {
        bodyConsumed = true;
        await body?.stream.take(0).drain<void>();
        if (existingBytes == 0) {
          throw StateError('HTTP 416 without a partial download');
        }
        if (await tempFile.exists()) await tempFile.delete();
        task.receivedBytes = 0;
        task.totalBytes = 0;
        task.progress = 0;
        onProgress();
        return null;
      }
      if ((response.statusCode ?? 500) >= 400) {
        bodyConsumed = true;
        await body?.stream.take(0).drain<void>();
        throw StateError('HTTP ${response.statusCode}');
      }

      append = existingBytes > 0 && response.statusCode == 206;
      if (append) {
        final range = response.headers.value('content-range');
        final start =
            RegExp(r'^bytes (\d+)-').firstMatch(range ?? '')?.group(1);
        if (int.tryParse(start ?? '') != existingBytes) {
          bodyConsumed = true;
          await body?.stream.take(0).drain<void>();
          throw StateError('Server returned a mismatched download range');
        }
      }
      if (existingBytes > 0 && !append && await tempFile.exists()) {
        await tempFile.delete();
        task.receivedBytes = 0;
      }

      if (!append && !transcode) {
        final responseExtension =
            downloadExtensionFromHeaders(response.headers);
        if (responseExtension != null &&
            responseExtension != downloadPathExtension(filePath)) {
          filePath = replaceDownloadExtension(filePath, responseExtension);
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
        throw StateError('Empty response body');
      }
      final contentRange = response.headers.value('content-range');
      final rangeTotal = parseDownloadRangeTotal(contentRange);
      final contentLength =
          int.tryParse(response.headers.value('content-length') ?? '');
      final totalBytes = rangeTotal ??
          (contentLength == null
              ? task.totalBytes
              : contentLength + (append ? existingBytes : 0));
      task.totalBytes =
          totalBytes > 0 ? totalBytes : estimatedDownloadBytes(task, transcode);

      sink =
          tempFile.openWrite(mode: append ? FileMode.append : FileMode.write);
      bodyConsumed = true;
      await sink.addStream(responseBody.stream.map((chunk) {
        checkActive();
        receivedThisRequest += chunk.length;
        task.receivedBytes = (append ? existingBytes : 0) + receivedThisRequest;
        if (task.totalBytes <= 0) {
          task.totalBytes = estimatedDownloadBytes(task, transcode);
        }
        if (task.totalBytes > 0) {
          task.progress = (task.receivedBytes / task.totalBytes).clamp(0, 1);
        }
        task.touch();
        onProgress();
        return chunk;
      }));
      await sink.flush();
      await sink.close();
      sink = null;
      if (await tempFile.length() == 0) {
        throw StateError('Empty audio response');
      }

      final localCoverPath = await _cacheBookResources(storage, task, token,
          coverSource, requestUrl, requestHeaders, checkActive);
      checkActive();
      final file = File(filePath);
      if (await file.exists()) await file.delete();
      checkActive();
      await tempFile.rename(file.path);
      promotedFile = file;
      partialFile = tempFile;
      checkActive();
      final size = await file.length();
      checkActive();
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
      promotedFile = null;
      return item;
    } catch (_) {
      if (!bodyConsumed) {
        try {
          await body?.stream.take(0).drain<void>();
        } catch (_) {/* Keep the original error. */}
      }
      try {
        await sink?.close();
      } catch (_) {/* Keep the original error. */}
      if (promotedFile != null && partialFile != null) {
        try {
          await storage.rollbackAudio(promotedFile.path, partialFile.path,
              keepPartial: retainPartial());
        } catch (error) {
          debugPrint('Failed to clean up unfinished download: $error');
        }
      }
      rethrow;
    }
  }

  Future<String?> _cacheBookResources(
      DownloadStorage storage,
      DownloadTask task,
      CancelToken token,
      String coverSource,
      String requestUrl,
      Map<String, dynamic> requestHeaders,
      void Function() checkActive) async {
    final directory = storage.directoryForTask(task);
    await directory.create(recursive: true);
    checkActive();
    final cover = await _cacheCover(storage, directory, token, coverSource,
        requestUrl, requestHeaders, checkActive);
    checkActive();
    await storage.cacheMetadata(directory, task.toJson(), cover, checkActive);
    return cover;
  }

  Future<String?> _cacheCover(
      DownloadStorage storage,
      Directory directory,
      CancelToken token,
      String source,
      String requestUrl,
      Map<String, dynamic> requestHeaders,
      void Function() checkActive) async {
    final existing = await storage.existingCover(directory);
    checkActive();
    if (existing != null || source.isEmpty) return existing;
    try {
      final response = await _dio.get<List<int>>(source,
          cancelToken: token,
          options: Options(
              responseType: ResponseType.bytes,
              headers: {
                if (Uri.parse(source).origin == Uri.parse(requestUrl).origin)
                  ...requestHeaders
              },
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 400));
      checkActive();
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      return await storage.saveCover(directory, bytes,
          contentType: response.headers.value('content-type'),
          source: source,
          checkActive: checkActive);
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      checkActive();
      return null;
    }
  }
}
