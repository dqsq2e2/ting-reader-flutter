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

  Future<void> _playChapter(
    Book book,
    List<Chapter> chapterList,
    Chapter chapter, {
    double? startAt,
  }) async {
    _cancelFocusRecovery(clearResume: true);
    // 清除可能残留的抑制标记，确保用户手动切集时正常起播；
    // 睡眠定时的监听器会在 notifyListeners 期间重新设置它。
    _suppressAutoPlay = false;
    await applySettings(appState.settings);
    final playGeneration = ++_playGeneration;
    currentBook = book;
    chapters = sortChaptersForPlayback(chapterList);
    if (chapters.every((item) => item.id != chapter.id)) {
      chapters = sortChaptersForPlayback([...chapters, chapter]);
    }
    final resumePosition = startAt ?? _startPositionFor(book, chapter);
    final chapterIndex = chapters.indexWhere((item) => item.id == chapter.id);
    final initialIndex = chapterIndex >= 0 ? chapterIndex : 0;
    final targetChapter = chapters[initialIndex];
    currentChapter = targetChapter;
    _advancingFromOutro = false;
    currentTime = resumePosition;
    _furthestChapterPosition = resumePosition;
    duration = targetChapter.duration.toDouble();
    error = null;
    usingLocalFile = false;
    isMiniCollapsed = false;
    _seekGeneration++;
    _suppressPositionUpdates = true;
    _usingTranscodeStream = false;
    _usingAudioQueue = false;
    _usingGatewaySingleChapterSource = false;
    _clearTranscodeClock();
    // 按集数睡眠：集数用完则阻止后续 _playWithSession 起播，并暂停旧音频。
    if (_checkEpisodeSleepOnChapterChange()) {
      _suppressAutoPlay = true;
    }
    _notifyIfActive();
    await _waitForPendingTranscodeSeek();
    if (!_isActivePlay(playGeneration, targetChapter.id)) return;

    final useGatewaySingleChapter = _usesGatewaySingleChapterPlayback;
    String? localPath;
    try {
      localPath = _localFilePathFromChapter(targetChapter) ??
          await downloadState.localPathForChapter(targetChapter.id);
      if (!_isActivePlay(playGeneration, targetChapter.id)) return;
      usingLocalFile = localPath != null;
      if (useGatewaySingleChapter) {
        await _setGatewaySingleChapterSource(
          book,
          targetChapter,
          localPath: localPath,
          position: resumePosition,
        );
      } else {
        await _setAudioQueueWithRedirectRecovery(
          book,
          chapters,
          initialIndex: initialIndex,
          initialPosition:
              Duration(milliseconds: (resumePosition * 1000).round()),
        );
      }
      if (!_isActivePlay(playGeneration, targetChapter.id)) return;
      _usingAudioQueue = !useGatewaySingleChapter;
      _usingGatewaySingleChapterSource = useGatewaySingleChapter;
      currentTime = resumePosition;
      _suppressPositionUpdates = false;
      final loadedDuration = _audio.duration;
      if (targetChapter.duration <= 0 && loadedDuration != null) {
        _syncDiscoveredChapterDuration(
          targetChapter,
          loadedDuration.inMilliseconds / 1000,
        );
      }
      await _audio.setSpeed(playbackSpeed);
      await _audio.setVolume(volume);
      if (!_isActivePlay(playGeneration, targetChapter.id)) return;
      await _playWithSession();
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
          resumePosition,
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
        await _playWithSession();
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
    }
  }

  Future<void> _togglePlayback() async {
    if (!hasChapter) return;
    if (_gatewayReauthenticationPending) {
      _resumeAfterGatewayReauthentication = false;
      if (_audio.playing) await _audio.pause();
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
          await _setMp3TranscodeSource(chapter, mediaItem, target);
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
      await _audio.seek(Duration(milliseconds: (target * 1000).round()));
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
        index < chapters.length - 1) {
      await _seekAudioQueueToChapter(index + 1, book, chapters[index + 1]);
      _advancingFromOutro = false;
      return;
    }
    if (index >= 0 && index < chapters.length - 1) {
      await playChapter(book, chapters, chapters[index + 1]);
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
        index > 0) {
      await _seekAudioQueueToChapter(index - 1, book, chapters[index - 1]);
      return;
    }
    if (index > 0) {
      await playChapter(book, chapters, chapters[index - 1]);
    }
  }

  double _startPositionFor(Book book, Chapter chapter) {
    final progress = chapter.progressPosition;
    if (progress != null &&
        chapter.duration > 0 &&
        progress / chapter.duration < 0.95) {
      return progress;
    }
    return book.skipIntro.toDouble();
  }

  Future<void> _seekAudioQueueToChapter(
    int index,
    Book book,
    Chapter chapter,
  ) async {
    final start = _startPositionFor(book, chapter);
    _applyingQueueStartSeek = true;
    try {
      await _audio.seek(
        Duration(milliseconds: (start * 1000).round()),
        index: index,
      );
    } finally {
      _applyingQueueStartSeek = false;
    }
  }

  void _syncChapterFromAudioIndex(int? index) {
    if (!_usingAudioQueue) return;
    if (index == null || index < 0 || index >= chapters.length) return;
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
    usingLocalFile = _localFilePathFromChapter(nextChapter) != null ||
        downloadState.hasChapter(nextChapter.id);
    // 按集数睡眠：队列模式下集数用完则直接暂停音频。
    final shouldStopForSleep = _checkEpisodeSleepOnChapterChange();
    _notifyIfActive();
    if (shouldStopForSleep) {
      unawaited(_pauseForEpisodeSleep());
      return;
    }
    if (!_applyingQueueStartSeek && startPosition > 0 && book != null) {
      unawaited(_seekAudioQueueToChapter(index, book, nextChapter));
    }
    _startProgressTimer();
  }

  void _handleSkipOutro() {
    final book = currentBook;
    final chapter = currentChapter;
    if (book == null || chapter == null || _advancingFromOutro) return;
    if (book.skipOutro <= 0 || duration <= 0) return;
    final minChapterDuration = book.skipIntro + book.skipOutro + 10;
    if (duration > minChapterDuration &&
        duration - currentTime <= book.skipOutro) {
      _advancingFromOutro = true;
      Future<void>(() async {
        await sendProgress();
        await nextChapter(fromOutro: true);
      });
    }
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
