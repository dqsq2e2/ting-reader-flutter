part of '../player_state.dart';

/// Audio source construction, local downloads and notification metadata.
extension _PlayerSources on PlayerState {
  bool _canReuseAudioQueue(Book book, List<Chapter> nextChapters) {
    if (book.libraryType == 'source' ||
        _usingSegmentSource ||
        !_usingAudioQueue ||
        _usingTranscodeStream ||
        error != null ||
        _audio.processingState == audio.ProcessingState.completed ||
        _audio.processingState == audio.ProcessingState.idle ||
        !identical(currentBook, book) ||
        _mediaAuthRevision != appState.api.authRevision ||
        chapters.length != nextChapters.length) {
      return false;
    }
    for (var index = 0; index < chapters.length; index++) {
      if (chapters[index].id != nextChapters[index].id ||
          chapters[index].path != nextChapters[index].path) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _seekExistingAudioQueue(
    Chapter chapter,
    int index, {
    required String? localPath,
    required double position,
  }) async {
    if (_failedQueueChapters.contains(chapter.id)) return false;
    final queue = _audio.audioSource;
    if (queue is! audio.ConcatenatingAudioSource ||
        index < 0 ||
        index >= queue.children.length) {
      return false;
    }
    final source = queue.children[index];
    final expected = localPath == null
        ? Uri.parse(streamUrl(chapter.id))
        : Uri.file(localPath);
    if (source is! audio.UriAudioSource || source.uri != expected) return false;
    try {
      // 音源和鉴权未变时直接切换队列索引，不重新加载整本书。
      await _seekAudioQueueToChapter(index, currentBook!, chapter,
          position: position);
      return true;
    } catch (_) {
      // 原生后端不支持队列跳转时，回退到原有的音源加载流程。
      return false;
    }
  }

  String _buildStreamUrl(
    String chapterId, {
    String? transcodeFormat,
    double? seek,
  }) {
    final token = appState.token;
    final params = <String>[
      if (token != null && token.isNotEmpty)
        'token=${Uri.encodeComponent(token)}',
      if (transcodeFormat != null && transcodeFormat.isNotEmpty)
        'transcode=${Uri.encodeComponent(transcodeFormat)}',
      if (seek != null && seek > 0) 'seek=${seek.floor()}',
    ];
    return '${appState.activeUrl}/api/stream/$chapterId'
        '${params.isEmpty ? '' : '?${params.join('&')}'}';
  }

  Future<void> _setAudioUrlWithRedirectRecovery(
    String Function() buildUrl, {
    required MediaItem mediaItem,
    Duration? initialPosition,
  }) async {
    final firstUrl = buildUrl();
    try {
      await _setAudioUrl(
        firstUrl,
        mediaItem,
        initialPosition: initialPosition,
      );
    } catch (_) {
      if (!appState.usesActiveOrigin(firstUrl)) rethrow;
      final previousActiveUrl = appState.activeUrl;
      final recoveredUrl = await appState.recoverActiveUrl();
      if (recoveredUrl == null ||
          recoveredUrl.isEmpty ||
          recoveredUrl == previousActiveUrl) {
        rethrow;
      }
      await _setAudioUrl(
        buildUrl(),
        mediaItem,
        initialPosition: initialPosition,
      );
    }
  }

  Future<void> _setAudioUrl(
    String url,
    MediaItem mediaItem, {
    Duration? initialPosition,
  }) async {
    final authRevision = appState.api.authRevision;
    if (kIsWeb) {
      await _audio.setAudioSource(
        audio.AudioSource.uri(Uri.parse(url), tag: mediaItem),
        initialPosition: initialPosition,
      );
      _mediaAuthRevision = authRevision;
      return;
    }
    final headers = _streamHeaders;
    await _audio.setAudioSource(
      audio.AudioSource.uri(
        Uri.parse(url),
        headers: headers.isEmpty ? null : headers,
        tag: mediaItem,
      ),
      initialPosition: initialPosition,
    );
    _mediaAuthRevision = authRevision;
  }

  Future<void> _setGatewaySingleChapterSource(
    Book book,
    Chapter chapter, {
    required String? localPath,
    required double position,
  }) async {
    final mediaItem = _mediaItemFor(book, chapter);
    // Embedded chapters start partway into the shared file.
    final startPosition = Duration(
      milliseconds: ((chapter.startSeconds + position) * 1000).round(),
    );
    if (localPath != null) {
      await _audio.setAudioSource(
        audio.AudioSource.uri(Uri.file(localPath), tag: mediaItem),
        initialPosition: startPosition,
      );
      _mediaAuthRevision = appState.api.authRevision;
      return;
    }

    await _setAudioUrlWithRedirectRecovery(
      () => streamUrl(chapter.id),
      mediaItem: mediaItem,
      initialPosition: startPosition,
    );
  }

  /// Play one time range of a single-file audiobook. Every embedded chapter
  /// shares the same file, so the source is opened once and positioned at the
  /// chapter start instead of concatenating the file once per chapter.
  Future<void> _setSegmentSource(
    Book book,
    Chapter chapter, {
    required String? localPath,
    required double position,
  }) async {
    final mediaItem = _mediaItemFor(book, chapter);
    final startPosition = Duration(
      milliseconds: ((chapter.startSeconds + position) * 1000).round(),
    );
    if (localPath != null) {
      await _audio.setAudioSource(
        audio.AudioSource.uri(Uri.file(localPath), tag: mediaItem),
        initialPosition: startPosition,
      );
      _mediaAuthRevision = appState.api.authRevision;
      return;
    }
    await _setAudioUrlWithRedirectRecovery(
      () => streamUrl(chapter.id),
      mediaItem: mediaItem,
      initialPosition: startPosition,
    );
  }

  Future<void> _setFallbackTranscodeSource(
    Chapter chapter,
    MediaItem mediaItem,
    double seek,
  ) async {
    await _setMp3TranscodeSource(chapter, mediaItem, seek);
  }

  Future<void> _setMp3TranscodeSource(
    Chapter chapter,
    MediaItem mediaItem,
    double seek,
  ) async {
    await _setAudioUrlWithRedirectRecovery(
      () => streamUrl(
        chapter.id,
        transcodeFormat: 'mp3',
        seek: seek,
      ),
      mediaItem: mediaItem.copyWith(
        duration:
            chapter.duration > 0 ? Duration(seconds: chapter.duration) : null,
        extras: {
          ...?mediaItem.extras,
          'isTranscodedStream': true,
          'streamOffsetSeconds': seek,
        },
      ),
    );
  }

  Future<void> _setAudioQueueWithRedirectRecovery(
    Book book,
    List<Chapter> chapterList, {
    required int initialIndex,
    required Duration initialPosition,
  }) async {
    try {
      await _setAudioQueue(
        book,
        chapterList,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
      );
    } catch (_) {
      final firstUrl = streamUrl(chapterList[initialIndex].id);
      if (!appState.usesActiveOrigin(firstUrl)) rethrow;
      final previousActiveUrl = appState.activeUrl;
      final recoveredUrl = await appState.recoverActiveUrl();
      if (recoveredUrl == null ||
          recoveredUrl.isEmpty ||
          recoveredUrl == previousActiveUrl) {
        rethrow;
      }
      await _setAudioQueue(
        book,
        chapterList,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
      );
    }
  }

  Future<void> _setAudioQueue(
    Book book,
    List<Chapter> chapterList, {
    required int initialIndex,
    required Duration initialPosition,
  }) async {
    final authRevision = appState.api.authRevision;
    final headers = _streamHeaders;
    final sources = <audio.AudioSource>[];
    for (final chapter in chapterList) {
      final embeddedLocalPath = _localFilePathFromChapter(chapter);
      final localPath = embeddedLocalPath ??
          await downloadState.localPathForChapter(chapter.id);
      sources.add(
        audio.AudioSource.uri(
          localPath == null
              ? Uri.parse(streamUrl(chapter.id))
              : Uri.file(localPath),
          headers: localPath == null && headers.isNotEmpty ? headers : null,
          tag: _mediaItemFor(book, chapter),
        ),
      );
    }
    await _audio.setAudioSource(
      audio.ConcatenatingAudioSource(children: sources),
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );
    _mediaAuthRevision = authRevision;
  }

  Map<String, String> get _streamHeaders {
    if (kIsWeb) return const {};
    // streamUrl already authenticates with its token query parameter.
    // just_audio caches the final redirect URI in its header proxy and
    // reapplies supplied headers on later Range requests. Forwarding our
    // Bearer token to a STRM origin can make that origin reject seeking.
    // Keep gateway headers/cookies needed to reach the server, but never
    // supply the redundant application Authorization header to media.
    return Map.of(appState.api.authHeaders)
      ..removeWhere((name, _) => name.toLowerCase() == 'authorization');
  }

  String? _localFilePathFromChapter(Chapter chapter) {
    final raw = chapter.path.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    // API chapter paths belong to the server, even when they are absolute.
    // Offline chapters explicitly use file URIs; indexed downloads are
    // resolved separately through DownloadState.
    if (uri != null && uri.scheme == 'file') return uri.toFilePath();
    return null;
  }

  /// A segmented book stores the whole file under every chapter id. Reuse the
  /// first chapter that has a local copy instead of downloading the audio once
  /// per chapter.
  Future<String?> _sharedSegmentLocalPath(List<Chapter> chapterList) async {
    for (final chapter in chapterList) {
      final localPath = _localFilePathFromChapter(chapter) ??
          await downloadState.localPathForChapter(chapter.id);
      if (localPath != null) return localPath;
    }
    return null;
  }

  MediaItem _mediaItemFor(
    Book book,
    Chapter chapter, {
    double streamOffset = 0,
  }) {
    final authorValue = book.author;
    final narratorValue = book.narrator;
    final artistParts = [
      if (authorValue != null && authorValue.trim().isNotEmpty)
        authorValue.trim(),
      if (narratorValue != null && narratorValue.trim().isNotEmpty)
        narratorValue.trim(),
    ];
    final artUri = _mediaArtUri(book);
    final artHeaders = artUri != null &&
            (artUri.scheme == 'http' || artUri.scheme == 'https') &&
            appState.usesActiveOrigin(artUri.toString())
        ? _streamHeaders
        : null;
    final chapterIndex = chapters.indexWhere((item) => item.id == chapter.id);
    return MediaItem(
      id: chapter.id,
      album: book.title,
      title: chapter.title,
      artist: artistParts.isEmpty ? null : artistParts.join(' / '),
      duration:
          chapter.duration > 0 ? Duration(seconds: chapter.duration) : null,
      artUri: artUri,
      artHeaders: artHeaders == null || artHeaders.isEmpty ? null : artHeaders,
      extras: {
        'bookId': book.id,
        'chapterId': chapter.id,
        if (chapterIndex >= 0) 'queueIndex': chapterIndex,
        if (chapters.isNotEmpty) 'queueCount': chapters.length,
        if (streamOffset > 0) 'streamOffsetSeconds': streamOffset,
      },
    );
  }

  Uri? _mediaArtUri(Book book) {
    final cover = bookCoverUrl(appState, book).trim();
    if (cover.isEmpty) return null;
    if (cover.startsWith('file://')) return Uri.tryParse(cover);
    if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(cover) ||
        cover.startsWith('/data/') ||
        cover.startsWith('/storage/') ||
        cover.startsWith('/var/') ||
        cover.startsWith('/Users/')) {
      return Uri.file(cover);
    }
    return Uri.tryParse(cover);
  }
}
