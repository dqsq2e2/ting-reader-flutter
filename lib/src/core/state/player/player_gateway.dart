part of '../player_state.dart';

/// Gateway renewal and completion checks for native media playback.
extension _PlayerGateway on PlayerState {
  Future<void> _pauseForGatewayReauthentication() async {
    if (_gatewayReauthenticationPending) return;
    _gatewayReauthenticationPending = true;
    _resumeAfterGatewayReauthentication = _resumeAfterGatewayReauthentication ||
        (hasChapter && (isPlaying || _audio.playing));
    _cancelFocusRecovery(clearResume: true);
    _stopProgressTimers();
    _closeProgressSocket();
    if (_audio.playing) {
      try {
        await _audio.pause();
      } catch (_) {
        // Authentication recovery should still proceed when native pause fails.
      }
    }
    _notifyIfActive();
  }

  Future<void> _restoreAfterGatewayReauthentication() async {
    if (!_gatewayReauthenticationPending) return;
    final shouldResume = _resumeAfterGatewayReauthentication;
    _gatewayReauthenticationPending = false;
    _resumeAfterGatewayReauthentication = false;

    if (!hasChapter || !appState.isAuthenticated) {
      _notifyIfActive();
      return;
    }

    try {
      await _refreshPlaybackSourceAfterGatewayLogin();
      if (shouldResume) {
        unawaited(_resumePlaybackAfterGatewayReauthentication());
      }
      error = null;
    } catch (_) {
      error = appState.textForLocale(
        '飞牛重新登录后恢复播放失败',
        'Unable to resume playback after fnOS sign-in',
      );
    }
    _notifyIfActive();
  }

  Future<void> _resumePlaybackAfterGatewayReauthentication() async {
    try {
      await _playWithSession();
    } catch (_) {
      error = appState.textForLocale(
        '飞牛重新登录后恢复播放失败',
        'Unable to resume playback after fnOS sign-in',
      );
      _notifyIfActive();
    }
  }

  Future<void> _refreshPlaybackSourceAfterGatewayLogin() async {
    final book = currentBook;
    final chapter = currentChapter;
    if (book == null || chapter == null) return;

    final resumePosition = gatewayMediaResumePosition(
      positionSeconds: currentTime,
      furthestPositionSeconds: _furthestChapterPosition,
      expectedDurationSeconds: chapter.duration.toDouble(),
    );
    _suppressPositionUpdates = true;
    try {
      if (_usesGatewaySingleChapterPlayback && !_usingTranscodeStream) {
        final localPath = _localFilePathFromChapter(chapter) ??
            await downloadState.localPathForChapter(chapter.id);
        usingLocalFile = localPath != null;
        await _setGatewaySingleChapterSource(
          book,
          chapter,
          localPath: localPath,
          position: resumePosition,
        );
        _usingAudioQueue = false;
        _usingGatewaySingleChapterSource = true;
      } else if (_usingAudioQueue) {
        final chapterList = chapters.isEmpty ? <Chapter>[chapter] : chapters;
        final chapterIndex = chapterList.indexWhere(
          (item) => item.id == chapter.id,
        );
        await _setAudioQueueWithRedirectRecovery(
          book,
          chapterList,
          initialIndex: chapterIndex >= 0 ? chapterIndex : 0,
          initialPosition:
              Duration(milliseconds: (resumePosition * 1000).round()),
        );
      } else if (_usingTranscodeStream) {
        await _setFallbackTranscodeSource(
          chapter,
          _mediaItemFor(book, chapter, streamOffset: resumePosition),
          resumePosition,
        );
      } else {
        await _setAudioUrlWithRedirectRecovery(
          () => streamUrl(chapter.id),
          mediaItem: _mediaItemFor(
            book,
            chapter,
            streamOffset: resumePosition,
          ),
        );
        if (resumePosition > 0) {
          await _audio.seek(
            Duration(milliseconds: (resumePosition * 1000).round()),
          );
        }
      }
      currentTime = resumePosition;
      _furthestChapterPosition = resumePosition;
      if (chapter.duration > 0) {
        duration = chapter.duration.toDouble();
      }
      await _audio.setSpeed(playbackSpeed);
      await _audio.setVolume(volume);
    } finally {
      _suppressPositionUpdates = false;
    }
  }

  bool get _usesGatewaySingleChapterPlayback =>
      !appState.offlineMode &&
      !appState.needsGatewayLogin &&
      (appState.token?.trim().isNotEmpty ?? false) &&
      (appState.api.isGatewaySession?.call() ?? false);

  Future<void> _handlePlaybackCompleted(audio.PlayerState state) async {
    // Native queues advance themselves; single transcode streams do not.
    if (_usingAudioQueue ||
        (!_usingGatewaySingleChapterSource && !_usingTranscodeStream)) {
      await sendProgress();
      return;
    }
    final completionOperation = (play: _playGeneration, seek: _seekGeneration);
    final playGeneration = completionOperation.play;
    if (_completedPlaybackOperation == completionOperation ||
        _suppressPositionUpdates ||
        _gatewayReauthenticationPending ||
        appState.needsGatewayLogin ||
        _advancingFromOutro) {
      return;
    }

    final chapter = currentChapter;
    if (chapter == null) return;
    bool isActiveCompletion() =>
        _isActivePlay(playGeneration, chapter.id) &&
        _seekGeneration == completionOperation.seek;

    _completedPlaybackOperation = completionOperation;
    final shouldResume = state.playing || isPlaying || _audio.playing;
    _resumeAfterGatewayReauthentication =
        _resumeAfterGatewayReauthentication || shouldResume;
    _stopProgressTimers();
    var shouldAdvance = false;

    try {
      // fnid 静默重登会签发新 fnos-token 并短暂清空 TR token（token=null→新
      // JWT），旧网关会话被踢导致正在播放的流被截断——这正是本次 completed
      // 的最常见来源。此时 appState.token / authRevision / cookie 都处于
      // 中间态，必须等重登尘埃落定再判断，否则会把「重登踢流」误判为
      // 「非网关播放」而错误跳章，或带着无鉴权的 URL 重建音源失败。
      await _waitForGatewayAuthToSettle();
      if (!isActiveCompletion() ||
          _gatewayReauthenticationPending ||
          appState.needsGatewayLogin) {
        return;
      }

      if (!_usesGatewaySingleChapterPlayback) {
        _resumeAfterGatewayReauthentication = false;
        await sendProgress();
        shouldAdvance = shouldResume &&
            _audio.playing &&
            isActiveCompletion() &&
            !_gatewayReauthenticationPending &&
            !appState.needsGatewayLogin &&
            !_advancingFromOutro;
        return;
      }

      final observedPosition = gatewayMediaResumePosition(
        positionSeconds: currentTime,
        furthestPositionSeconds: _furthestChapterPosition,
        expectedDurationSeconds: chapter.duration.toDouble(),
      );
      currentTime = observedPosition;
      _furthestChapterPosition = observedPosition;
      if (chapter.duration > 0) {
        duration = chapter.duration.toDouble();
      }
      _notifyIfActive();

      // Native media requests bypass Dio and fnOS may return HTTP 200 with an
      // "invalid token" body. Verify the gateway before advancing.
      final sourceAuthWasStale =
          _mediaAuthRevision != appState.api.authRevision;
      final probeResult = await _probeGatewaySession();
      if (!isActiveCompletion()) return;
      if (probeResult == _GatewaySessionProbeResult.expired) return;
      if (probeResult == _GatewaySessionProbeResult.unavailable) {
        if ((sourceAuthWasStale ||
                _mediaAuthRevision != appState.api.authRevision) &&
            await _resumeAfterSilentGatewayRenewal(shouldResume)) {
          return;
        }
        _resumeAfterGatewayReauthentication = false;
        await _pauseAfterGatewayMediaFailure();
        error = appState.textForLocale(
          '无法验证飞牛登录状态，播放已暂停',
          'Unable to verify the fnOS session. Playback is paused',
        );
        _notifyIfActive();
        return;
      }

      if (_gatewayReauthenticationPending || appState.needsGatewayLogin) {
        return;
      }

      // 落在「跳片尾」区间内的流结束：跳过片尾本来就会在此时切下一章，
      // 按正常章末处理（自动跳转），而不是当作「音频流异常结束」。
      final book = currentBook;
      final skipOutro = book?.skipOutro ?? 0;
      final endedInSkipOutroZone = book != null &&
          skipOutro > 0 &&
          chapter.duration > 0 &&
          chapter.duration.toDouble() - observedPosition <=
              skipOutro + _skipOutroZoneToleranceSeconds;
      final prematureCompletion = !usingLocalFile &&
          !endedInSkipOutroZone &&
          isPrematureGatewayMediaCompletion(
            positionSeconds: observedPosition,
            expectedDurationSeconds: chapter.duration.toDouble(),
          );
      if (prematureCompletion &&
          _mediaAuthRevision != appState.api.authRevision &&
          await _resumeAfterSilentGatewayRenewal(shouldResume)) {
        return;
      }
      if (prematureCompletion) {
        _resumeAfterGatewayReauthentication = false;
        await _pauseAfterGatewayMediaFailure();
        error = appState.textForLocale(
          '音频流异常结束，已停止自动跳转章节',
          'The audio stream ended unexpectedly. Automatic chapter advance was stopped',
        );
        _notifyIfActive();
        return;
      }

      _resumeAfterGatewayReauthentication = false;
      await sendProgress();
      if (!isActiveCompletion() ||
          _gatewayReauthenticationPending ||
          appState.needsGatewayLogin) {
        return;
      }
      // 跳片尾流程（_handleSkipOutro）已接管切章时，这里不再重复跳转，
      // 避免「completed 跳一次 + skipOutro 再跳一次」的双跳。
      shouldAdvance = shouldResume && _audio.playing && !_advancingFromOutro;
    } finally {
      if (!shouldAdvance &&
          _completedPlaybackOperation == completionOperation) {
        _completedPlaybackOperation = null;
      }
      if (shouldAdvance) {
        unawaited(nextChapter());
      }
    }
  }

  /// 等待进行中的 fnid 静默重登完成（无重登时立即返回）。
  ///
  /// 只等不重试：重登失败会走既有的「网关会话失效」通道
  /// （_markGatewayLoginRequired → needsGatewayLogin），由调用方随后判断。
  Future<void> _waitForGatewayAuthToSettle() async {
    if (!(appState.api.isGatewaySession?.call() ?? false)) return;
    final recovery = appState.gatewaySessionRecoveryInFlight;
    if (recovery == null) return;
    try {
      await recovery.timeout(const Duration(seconds: 45));
    } catch (_) {
      // 重登超时/失败：继续往下走，由会话探测（_probeGatewaySession）
      // 与 needsGatewayLogin 检查给出最终结论。
    }
  }

  Future<bool> _resumeAfterSilentGatewayRenewal(bool shouldResume) async {
    try {
      // 重建音源前必须等静默重登完成：token 置空窗口内构造的 streamUrl
      // 不带鉴权参数，setAudioSource 必然 401，进而误报「音频流异常结束」。
      await _waitForGatewayAuthToSettle();
      await _refreshPlaybackSourceAfterGatewayLogin();
      _resumeAfterGatewayReauthentication = false;
      error = null;
      if (shouldResume) {
        await _playWithSession();
      }
      if (_audio.playing) _startProgressTimer();
      _notifyIfActive();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<_GatewaySessionProbeResult> _probeGatewaySession() async {
    try {
      await appState.api.get('/api/me');
      return _GatewaySessionProbeResult.valid;
    } catch (_) {
      if (_gatewayReauthenticationPending || appState.needsGatewayLogin) {
        return _GatewaySessionProbeResult.expired;
      }
      return _GatewaySessionProbeResult.unavailable;
    }
  }

  Future<void> _pauseAfterGatewayMediaFailure() async {
    _stopProgressTimers();
    if (!_audio.playing) return;
    try {
      await _audio.pause();
    } catch (_) {
      isPlaying = false;
    }
  }
}

enum _GatewaySessionProbeResult { valid, expired, unavailable }

/// 「跳片尾区间」判定的冗余秒数：音频流在 skipOutro 区间内被截断时，
/// 视为跳片尾语义下的正常章末（自动切下一章），而非「音频流异常结束」。
const double _skipOutroZoneToleranceSeconds = 2.0;
