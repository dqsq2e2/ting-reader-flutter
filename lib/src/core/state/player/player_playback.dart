part of '../player_state.dart';

/// Chapter switching, seeking, sleep policy and playback commands.
extension _PlayerPlayback on PlayerState {
  void _startEpisodeSleep(int episodes) =>
      _sleep.chapterCount(episodes, currentChapter?.id);
  void _cancelEpisodeSleep() => _sleep.cancel();
  bool _checkEpisodeSleepOnChapterChange() =>
      _sleep.chapterChanged(currentChapter?.id);

  /// 队列模式下集数用完时确定性停止底层音频。
  Future<void> _pauseForEpisodeSleep() async {
    _cancelFocusRecovery(clearResume: true);
    // Android/Windows 在队列切集时可能先上报 playing=false，导致 pause()
    // 短路而未通知原生播放器。stop() 始终停掉平台播放器，同时保留音源状态。
    await _audio.stop();
    await sendProgress();
  }

  /// Whether the chapter list describes time ranges of one shared file.
  bool _isSegmentChapterList(List<Chapter> list) {
    if (list.length < 2) return false;
    final path = list.first.path;
    return list.every(
      (item) => item.isSegmented && item.path == path,
    );
  }

  Future<void> _playChapter(
    Book book,
    List<Chapter> chapterList,
    Chapter chapter, {
    double? startAt,
    bool autoPlay = true,
  }) async {
    final playGeneration = ++_playGeneration;
    _connectingPlayback = true;
    _sourceCatalogue?.dispose();
    _sourceCatalogue = null;
    _cancelFocusRecovery(clearResume: true);
    // 清除可能残留的抑制标记，确保用户手动切集时正常起播；
    // 睡眠定时的监听器会在 notifyListeners 期间重新设置它。
    _suppressAutoPlay = false;
    await applySettings(appState.settings);
    if (_disposed || playGeneration != _playGeneration) return;
    if (currentBook?.id != book.id) _failedQueueChapters.clear();
    final nextChapters = sortChaptersForPlayback([
      ...chapterList,
      if (chapterList.every((item) => item.id != chapter.id)) chapter,
    ]);
    final reuseQueue = _canReuseAudioQueue(book, nextChapters);
    currentBook = book;
    chapters = nextChapters;
    final useSegmentSource = _isSegmentChapterList(chapters);
    final resumePosition = startAt ?? _startPositionFor(book, chapter);
    final chapterIndex = chapters.indexWhere((item) => item.id == chapter.id);
    final initialIndex = chapterIndex >= 0 ? chapterIndex : 0;
    final targetChapter = chapters[initialIndex];
    currentChapter = targetChapter;
    _advancingFromOutro = false;
    _segmentAdvancing = false;
    currentTime = resumePosition;
    _furthestChapterPosition = resumePosition;
    duration = targetChapter.duration.toDouble();
    error = null;
    usingLocalFile = false;
    isMiniCollapsed = false;
    _seekGeneration++;
    _applyingQueueStartSeek = false;
    _suppressPositionUpdates = true;
    _usingTranscodeStream = false;
    _usingAudioQueue = reuseQueue;
    _usingGatewaySingleChapterSource = false;
    _usingSegmentSource = false;
    _clearTranscodeClock();
    // 按集数睡眠：集数用完则阻止后续 _playWithSession 起播，并暂停旧音频。
    if (_checkEpisodeSleepOnChapterChange()) {
      _suppressAutoPlay = true;
    }
    _notifyIfActive();
    await _waitForPendingTranscodeSeek();
    if (!_isActivePlay(playGeneration, targetChapter.id)) return;

    // Online source URLs may expire: resolve only the chapter being played.
    final useGatewaySingleChapter =
        _usesGatewaySingleChapterPlayback || book.libraryType == 'source';
    String? localPath;
    try {
      // Segmented books share one file; prefer the file already downloaded for
      // the first chapter instead of downloading the same audio per chapter.
      localPath = useSegmentSource
          ? await _sharedSegmentLocalPath(chapters)
          : (_localFilePathFromChapter(targetChapter) ??
              await downloadState.localPathForChapter(targetChapter.id));
      if (!_isActivePlay(playGeneration, targetChapter.id)) return;
      usingLocalFile = localPath != null;
      if (useGatewaySingleChapter) {
        await _setGatewaySingleChapterSource(
          book,
          targetChapter,
          localPath: localPath,
          position: resumePosition,
        );
      } else if (useSegmentSource) {
        await _setSegmentSource(
          book,
          targetChapter,
          localPath: localPath,
          position: resumePosition,
        );
      } else {
        final reused = reuseQueue &&
            await _seekExistingAudioQueue(targetChapter, initialIndex,
                localPath: localPath, position: resumePosition);
        if (!_isActivePlay(playGeneration, targetChapter.id)) return;
        if (!reused) {
          _usingAudioQueue = false;
          await _setAudioQueueWithRedirectRecovery(
            book,
            chapters,
            initialIndex: initialIndex,
            initialPosition:
                Duration(milliseconds: (resumePosition * 1000).round()),
          );
        }
      }
      if (!_isActivePlay(playGeneration, targetChapter.id)) return;
      _usingAudioQueue = !useGatewaySingleChapter && !useSegmentSource;
      _usingGatewaySingleChapterSource = useGatewaySingleChapter;
      _usingSegmentSource = useSegmentSource;
      currentTime = resumePosition;
      _suppressPositionUpdates = false;
      final loadedDuration = _audio.duration;
      if (targetChapter.duration <= 0 &&
          !targetChapter.isSegmented &&
          loadedDuration != null) {
        _syncDiscoveredChapterDuration(
          targetChapter,
          loadedDuration.inMilliseconds / 1000,
        );
      }
      await _audio.setSpeed(playbackSpeed);
      await _audio.setVolume(volume);
      if (!_isActivePlay(playGeneration, targetChapter.id)) return;
      if (autoPlay) await _playWithSession();
      _failedQueueChapters.remove(targetChapter.id);
      _startProgressTimer();
    } catch (err) {
      if (!_isActivePlay(playGeneration, targetChapter.id)) return;
      if (useGatewaySingleChapter && localPath == null) {
        final previousResume = _resumeAfterGatewayReauthentication;
        _resumeAfterGatewayReauthentication = !_suppressAutoPlay;
        final probeResult = await _probeGatewaySession();
        if (probeResult != _GatewaySessionProbeResult.expired) {
          _resumeAfterGatewayReauthentication = previousResume;
        }
        if (!_isActivePlay(playGeneration, targetChapter.id)) return;
        if (probeResult == _GatewaySessionProbeResult.expired) {
          _suppressPositionUpdates = false;
          return;
        }
      }
      usingLocalFile = false;
      _usingAudioQueue = false;
      _usingGatewaySingleChapterSource = useGatewaySingleChapter;
      _usingSegmentSource = false;
      _usingTranscodeStream = true;
      duration = targetChapter.duration.toDouble();
      _clock.running = false;
      _resetTranscodeClock(resumePosition);
      _suppressPositionUpdates = true;
      error = null;
      try {
        await _setFallbackTranscodeSource(
          targetChapter,
          _mediaItemFor(
            book,
            targetChapter,
            streamOffset: resumePosition,
          ),
          targetChapter.startSeconds + resumePosition,
        );
        if (!_isActivePlay(playGeneration, targetChapter.id)) return;
        currentTime = resumePosition;
        _suppressPositionUpdates = false;
        await _audio.setSpeed(playbackSpeed);
        await _audio.setVolume(volume);
        if (resumePosition > 0) {
          currentTime = resumePosition;
          _notifyIfActive();
        }
        if (!_isActivePlay(playGeneration, targetChapter.id)) return;
        if (autoPlay) await _playWithSession();
        _failedQueueChapters.remove(targetChapter.id);
        _startProgressTimer();
      } catch (_) {
        if (!_isActivePlay(playGeneration, targetChapter.id)) return;
        _suppressPositionUpdates = false;
        error = appState.textForLocale(
          '音频播放失败',
          'Audio playback failed',
        );
        _notifyIfActive();
      }
    } finally {
      if (_isActivePlay(playGeneration, targetChapter.id)) {
        _connectingPlayback = false;
        _notifyIfActive();
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (!hasChapter) return;
    if (_connectingPlayback && error == null) return;
    if (_gatewayReauthenticationPending) {
      _resumeAfterGatewayReauthentication = false;
      if (_audio.playing) await _audio.pause();
      return;
    }
    if (error != null ||
        (!_audio.playing &&
            (_audio.processingState == audio.ProcessingState.completed ||
                _audio.processingState == audio.ProcessingState.idle))) {
      final atEnd = _audio.processingState == audio.ProcessingState.completed;
      await playChapter(currentBook!, chapters, currentChapter!,
          startAt: atEnd
              ? _introPositionFor(currentBook!, currentChapter!)
              : currentTime);
      return;
    }
    _cancelFocusRecovery(clearResume: true);
    // 用户手动操作，清除睡眠定时设置的自动暂停标记。
    _suppressAutoPlay = false;
    if (_audio.playing) {
      await _audio.pause();
      await sendProgress();
    } else {
      await _playWithSession();
      _startProgressTimer();
    }
  }

  /// 仅暂停播放，不会在未播放时触发播放。用于睡眠定时等需要确定性地暂停的场景。
  Future<void> _pausePlayback() async {
    if (!hasChapter) return;
    if (_gatewayReauthenticationPending) {
      _resumeAfterGatewayReauthentication = false;
    }
    _cancelFocusRecovery(clearResume: true);
    if (_audio.playing) {
      await _audio.pause();
      if (!_gatewayReauthenticationPending) {
        await sendProgress();
      }
    }
  }

  Future<void> _seekPlayback(double seconds) async {
    final target =
        duration > 0 ? seconds.clamp(0, duration).toDouble() : seconds;
    final seekGeneration = ++_seekGeneration;
    currentTime = target;
    _furthestChapterPosition = target;
    _notifyIfActive();
    final chapter = currentChapter;
    if (_usingTranscodeStream && chapter != null) {
      _resetTranscodeClock(target);
      _suppressPositionUpdates = true;
      final resumePlayback = isPlaying || _audio.playing;
      final book = currentBook;
      try {
        final mediaItem = book == null
            ? MediaItem(
                id: chapter.id,
                title: chapter.title,
                duration: duration > 0
                    ? Duration(milliseconds: (duration * 1000).round())
                    : null,
                extras: {
                  if (target > 0) 'streamOffsetSeconds': target,
                },
              )
            : _mediaItemFor(
                book,
                chapter,
                streamOffset: target,
              );
        await _queueTranscodeSeek(() async {
          if (seekGeneration != _seekGeneration) return;
          // The transcode endpoint seeks by absolute file position.
          await _setMp3TranscodeSource(
            chapter,
            mediaItem,
            chapter.startSeconds + target,
          );
          if (seekGeneration != _seekGeneration) return;
          await _audio.setSpeed(playbackSpeed);
          await _audio.setVolume(volume);
          if (resumePlayback) await _playWithSession();
          error = null;
        });
      } catch (_) {
        if (seekGeneration != _seekGeneration) return;
        error = appState.textForLocale(
          '跳转失败',
          'Seek failed',
        );
        _notifyIfActive();
      } finally {
        if (seekGeneration == _seekGeneration) {
          _suppressPositionUpdates = false;
          currentTime = _clampPlaybackTime(target);
          _notifyIfActive();
        }
      }
    } else {
      // Positions inside an embedded chapter are relative; the media element
      // seeks on the absolute file timeline.
      final offset = chapter?.startSeconds ?? 0;
      await _audio.seek(
        Duration(milliseconds: ((target + offset) * 1000).round()),
      );
    }
    if (seekGeneration != _seekGeneration) return;
    await sendProgress();
  }

  Future<void> _waitForPendingTranscodeSeek() async {
    await _transcodeSeekQueue.catchError((_) {});
  }

  Future<void> _queueTranscodeSeek(Future<void> Function() action) {
    final next = _transcodeSeekQueue.catchError((_) {}).then((_) => action());
    _transcodeSeekQueue = next.catchError((_) {});
    return next;
  }

  void _syncDiscoveredChapterDuration(Chapter chapter, double seconds) {
    final rounded = seconds.round();
    if (rounded <= 0) return;
    if (_usingTranscodeStream || _suppressPositionUpdates) return;
    if (_durationSynced.contains(chapter.id) ||
        _durationSyncing.contains(chapter.id)) {
      return;
    }
    _durationSyncing.add(chapter.id);
    Future<void>(() async {
      if (_disposed) return;
      try {
        await appState.api.patch(
          '/api/chapters/${chapter.id}',
          data: {'duration': rounded},
        );
        if (_disposed) return;
        final updatedChapter = chapter.copyWith(duration: rounded);
        chapters = [
          for (final item in chapters)
            if (item.id == chapter.id)
              item.copyWith(duration: rounded)
            else
              item,
        ];
        if (currentChapter?.id == chapter.id) {
          currentChapter = updatedChapter;
          duration = rounded.toDouble();
          _notifyIfActive();
        }
        _durationSynced.add(chapter.id);
      } catch (_) {
        // Duration discovery should never interrupt playback.
      } finally {
        _durationSyncing.remove(chapter.id);
      }
    });
  }

  Future<void> _nextChapter({bool fromOutro = false}) async {
    if (!fromOutro) {
      _advancingFromOutro = false;
    }
    final chapter = currentChapter;
    final book = currentBook;
    if (chapter == null || book == null || chapters.isEmpty) return;
    final index = chapters.indexWhere((item) => item.id == chapter.id);
    if (!_usingTranscodeStream &&
        _usingAudioQueue &&
        _audio.hasNext &&
        index >= 0 &&
        index < chapters.length - 1 &&
        !_failedQueueChapters.contains(chapters[index + 1].id)) {
      await _seekAudioQueueToChapter(index + 1, book, chapters[index + 1]);
      _advancingFromOutro = false;
      return;
    }
    if (index >= 0 && index < chapters.length - 1) {
      await playChapter(book, chapters, chapters[index + 1]);
    } else if (book.libraryType == 'source' &&
        await _playAdjacentSourcePage(book, chapter, 1)) {
      return;
    } else {
      await _audio.pause();
      await sendProgress();
    }
  }

  Future<void> _previousChapter() async {
    _advancingFromOutro = false;
    final chapter = currentChapter;
    final book = currentBook;
    if (chapter == null || book == null || chapters.isEmpty) return;
    final index = chapters.indexWhere((item) => item.id == chapter.id);
    if (!_usingTranscodeStream &&
        _usingAudioQueue &&
        _audio.hasPrevious &&
        index > 0 &&
        !_failedQueueChapters.contains(chapters[index - 1].id)) {
      await _seekAudioQueueToChapter(index - 1, book, chapters[index - 1]);
      return;
    }
    if (index > 0) {
      await playChapter(book, chapters, chapters[index - 1]);
    } else if (book.libraryType == 'source') {
      await _playAdjacentSourcePage(book, chapter, -1);
    }
  }

  Future<bool> _playAdjacentSourcePage(
      Book book, Chapter chapter, int direction) async {
    if (_sourceCatalogue != null) return true;
    final generation = _playGeneration;
    final catalogue = ChapterCatalogue(appState.api, book.id);
    _sourceCatalogue = catalogue;
    try {
      final page = await catalogue.adjacentPage(chapter, direction);
      if (!_isActivePlay(generation, chapter.id)) return true;
      if (page == null || page.chapters.isEmpty) return false;
      final next = direction < 0 ? page.chapters.last : page.chapters.first;
      if (next.id == chapter.id) return false;
      await playChapter(book, page.chapters, next);
      return true;
    } catch (failure) {
      if (_isActivePlay(generation, chapter.id)) {
        error = ApiError.messageFor(failure);
        _notifyIfActive();
      }
      return true;
    } finally {
      catalogue.dispose();
      if (identical(_sourceCatalogue, catalogue)) _sourceCatalogue = null;
    }
  }

  double _startPositionFor(Book book, Chapter chapter) {
    final intro = _introPositionFor(book, chapter);
    final progress = chapter.progressPosition;
    if (progress != null &&
        progress.isFinite &&
        progress > intro &&
        chapter.duration > 0 &&
        progress / chapter.duration < 0.95) {
      return progress;
    }
    return intro;
  }

  double _introPositionFor(Book book, Chapter chapter) {
    if (book.skipIntro <= 0 ||
        (chapter.duration > 0 &&
            chapter.duration <= book.skipIntro + book.skipOutro)) {
      return 0;
    }
    return book.skipIntro.toDouble();
  }

  Future<void> _seekAudioQueueToChapter(
    int index,
    Book book,
    Chapter chapter, {
    double? position,
  }) async {
    final seekGeneration = ++_seekGeneration;
    final playGeneration = _playGeneration;
    final wasPlaying = isPlaying || _audio.playing;
    _applyingQueueStartSeek = true;
    try {
      final localPath = _localFilePathFromChapter(chapter) ??
          await downloadState.localPathForChapter(chapter.id);
      if (_disposed ||
          playGeneration != _playGeneration ||
          seekGeneration != _seekGeneration) {
        return;
      }
      final queue = _audio.audioSource;
      if (localPath != null &&
          queue is audio.ConcatenatingAudioSource &&
          index < queue.children.length) {
        final source = queue.children[index];
        if (source is audio.UriAudioSource &&
            source.uri != Uri.file(localPath)) {
          await _playChapter(book, List.of(chapters), chapter,
              startAt: position ?? _startPositionFor(book, chapter),
              autoPlay: wasPlaying &&
                  (isPlaying || _audio.playing) &&
                  !_suppressAutoPlay);
          return;
        }
      }
      final start = position ?? _startPositionFor(book, chapter);
      final seekPosition = Duration(milliseconds: (start * 1000).round());
      if (_audio.currentIndex != index) {
        await _audio.seek(seekPosition, index: index);
      }
      if (start > 0) {
        final ready = Completer<void>();
        final subscription = _audio.playbackEventStream.listen(
          (event) {
            if (!ready.isCompleted &&
                event.currentIndex == index &&
                event.processingState == audio.ProcessingState.ready) {
              ready.complete();
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!ready.isCompleted) ready.completeError(error, stack);
          },
          onDone: () {
            if (!ready.isCompleted) {
              ready.completeError(StateError('Playback ended before ready'));
            }
          },
        );
        try {
          await ready.future.timeout(const Duration(seconds: 15));
        } finally {
          await subscription.cancel();
        }
        if (!_isActivePlay(playGeneration, chapter.id) ||
            seekGeneration != _seekGeneration ||
            _audio.currentIndex != index) {
          return;
        }
        await _audio.seek(seekPosition);
        if (_isActivePlay(playGeneration, chapter.id) &&
            seekGeneration == _seekGeneration) {
          currentTime = start;
          _furthestChapterPosition = start;
          _notifyIfActive();
        }
      }
    } finally {
      if (seekGeneration == _seekGeneration) _applyingQueueStartSeek = false;
    }
  }

  void _syncChapterFromAudioIndex(int? index) {
    if (!_usingAudioQueue) return;
    if (index == null || index < 0 || index >= chapters.length) return;
    for (var candidate = _currentChapterIndex + 1;
        candidate <= index;
        candidate++) {
      if (candidate >= 0 &&
          _failedQueueChapters.contains(chapters[candidate].id)) {
        unawaited(_recoverQueueChapter(chapters[candidate]));
        return;
      }
    }
    final nextChapter = chapters[index];
    if (currentChapter?.id == nextChapter.id) return;
    final book = currentBook;
    final startPosition =
        book == null ? 0.0 : _startPositionFor(book, nextChapter);
    currentChapter = nextChapter;
    currentTime = startPosition;
    _furthestChapterPosition = startPosition;
    duration = nextChapter.duration.toDouble();
    _clearTranscodeClock();
    _usingTranscodeStream = false;
    _advancingFromOutro = false;
    final queue = _audio.audioSource;
    final source =
        queue is audio.ConcatenatingAudioSource && index < queue.children.length
            ? queue.children[index]
            : null;
    usingLocalFile =
        source is audio.UriAudioSource && source.uri.scheme == 'file';
    // 按集数睡眠：队列模式下集数用完则直接暂停音频。
    final shouldStopForSleep = _checkEpisodeSleepOnChapterChange();
    _notifyIfActive();
    if (shouldStopForSleep) {
      unawaited(_pauseForEpisodeSleep());
      return;
    }
    if (!_applyingQueueStartSeek && book != null) {
      final playGeneration = _playGeneration;
      final seekGeneration = _seekGeneration;
      Future<void>(() async {
        if (!_isActivePlay(playGeneration, nextChapter.id) ||
            seekGeneration != _seekGeneration ||
            _audio.currentIndex != index) {
          return;
        }
        await _seekAudioQueueToChapter(index, book, nextChapter);
      }).catchError((Object failure) {
        if (_isActivePlay(playGeneration, nextChapter.id)) {
          _handleNativePlaybackError(failure);
        }
      });
    }
    _startProgressTimer();
  }

  void _handleSkipOutro() {
    final book = currentBook;
    final chapter = currentChapter;
    if (book == null ||
        chapter == null ||
        _advancingFromOutro ||
        _suppressPositionUpdates ||
        !_audio.playing) {
      return;
    }
    if (book.skipOutro <= 0 || duration <= 0) return;
    final minChapterDuration = book.skipIntro + book.skipOutro;
    if (duration > minChapterDuration &&
        duration - currentTime <= book.skipOutro) {
      _advancingFromOutro = true;
      final playGeneration = _playGeneration;
      final seekGeneration = _seekGeneration;
      Future<void>(() async {
        if (!_isActivePlay(playGeneration, chapter.id) ||
            seekGeneration != _seekGeneration ||
            !_advancingFromOutro ||
            !_audio.playing) {
          return;
        }
        final activeBook = currentBook;
        if (activeBook == null ||
            activeBook.skipOutro <= 0 ||
            duration <= activeBook.skipIntro + activeBook.skipOutro ||
            duration - currentTime > activeBook.skipOutro) {
          _advancingFromOutro = false;
          return;
        }
        unawaited(sendProgress());
        await nextChapter(fromOutro: true);
      }).catchError((Object failure) {
        if (_isActivePlay(playGeneration, chapter.id)) {
          _handleNativePlaybackError(failure);
        }
      });
    }
  }

  void _handleNativePlaybackError(Object failure) {
    if (_disposed) return;
    final details = failure is PlatformException
        ? failure.details
        : failure is audio.PlayerException
            ? failure.details
            : null;
    final index = details is Map ? details['index'] : null;
    if (_audio.audioSource is audio.ConcatenatingAudioSource &&
        !_usingTranscodeStream &&
        index is int &&
        index >= 0 &&
        index < chapters.length) {
      final failedChapter = chapters[index];
      _failedQueueChapters.add(failedChapter.id);
      // 预加载后续章节失败时，先让当前章节继续播放。
      if (failedChapter.id != currentChapter?.id) return;
      if (_suppressPositionUpdates) return;
      if (_lastRecoveredQueueChapterId != failedChapter.id) {
        unawaited(_recoverQueueChapter(failedChapter));
        return;
      }
    }
    if (_suppressPositionUpdates) return;
    error = ApiError.messageFor(failure);
    _usingAudioQueue = false;
    _suppressPositionUpdates = true;
    ++_playGeneration;
    _cancelFocusRecovery(clearResume: true);
    _stopProgressTimers();
    final generation = _playGeneration;
    unawaited(_audio.stop().catchError((Object stopFailure) {
      if (!_disposed && generation == _playGeneration) {
        error = ApiError.messageFor(stopFailure);
        _notifyIfActive();
      }
    }));
    _notifyIfActive();
  }

  Future<void> _recoverQueueChapter(Chapter chapter) async {
    final book = currentBook;
    if (book == null || _disposed || _recoveringQueueFailure) return;
    final resume = isPlaying || _audio.playing;
    final position = currentChapter?.id == chapter.id
        ? currentTime
        : _startPositionFor(book, chapter);
    var generation = ++_playGeneration;
    final seekGeneration = _seekGeneration;
    final focusGeneration = _focusGeneration;
    _recoveringQueueFailure = true;
    _lastRecoveredQueueChapterId = chapter.id;
    _usingAudioQueue = false;
    _suppressPositionUpdates = true;
    _advancingFromOutro = false;
    try {
      await _audio.stop();
      if (_disposed || generation != _playGeneration) return;
      if (seekGeneration != _seekGeneration ||
          focusGeneration != _focusGeneration) {
        return;
      }
      // 丢弃失败的原生队列，重新加载指定章节；不支持的格式沿用 MP3 转码回退。
      generation = _playGeneration + 1;
      await _playChapter(book, List.of(chapters), chapter,
          startAt: position, autoPlay: resume);
    } catch (failure) {
      if (!_disposed && generation == _playGeneration) {
        error = ApiError.messageFor(failure);
        _notifyIfActive();
      }
    } finally {
      _recoveringQueueFailure = false;
    }
  }

  /// Embedded chapters end before the shared file does, so the segment
  /// boundary advances playback exactly once.
  void _handleSegmentEnd() {
    if (!_usingSegmentSource ||
        _usingTranscodeStream ||
        _segmentAdvancing ||
        _advancingFromOutro ||
        _suppressPositionUpdates ||
        !_audio.playing) {
      return;
    }
    final chapter = currentChapter;
    if (chapter == null) return;
    if (duration <= 0 || _chapterEndSeconds <= _chapterStartSeconds) return;
    if (currentTime < duration - 0.2) return;
    final playGeneration = _playGeneration;
    final seekGeneration = _seekGeneration;
    _segmentAdvancing = true;
    Future<void>(() async {
      try {
        if (!_isActivePlay(playGeneration, chapter.id) ||
            seekGeneration != _seekGeneration ||
            !_usingSegmentSource ||
            _suppressPositionUpdates ||
            !_audio.playing ||
            currentTime < duration - 0.2) {
          return;
        }
        unawaited(sendProgress());
        await nextChapter(fromOutro: true);
      } finally {
        if (playGeneration == _playGeneration) _segmentAdvancing = false;
      }
    }).catchError((Object failure) {
      if (_isActivePlay(playGeneration, chapter.id)) {
        _handleNativePlaybackError(failure);
      }
    });
  }
}

/// Tracks full-chapter time when native duration describes only a partial
/// transcoded response. The player chooses when the clock is running.
class _TranscodeClock {
  double _position = 0;
  DateTime? _startedAt;
  bool running = false;

  double position({required double speed, required double duration}) {
    var value = _position;
    final startedAt = _startedAt;
    if (startedAt != null && running) {
      value +=
          DateTime.now().difference(startedAt).inMilliseconds / 1000 * speed;
    }
    return clamp(value, duration);
  }

  void reset(double value, double duration) {
    _position = clamp(value, duration);
    _startedAt = DateTime.now();
  }

  void clear() {
    _position = 0;
    _startedAt = null;
    running = false;
  }

  static double clamp(double value, double duration) {
    final normalized = value.isFinite ? value : 0.0;
    if (duration > 0) return normalized.clamp(0, duration).toDouble();
    return normalized < 0 ? 0 : normalized;
  }
}
