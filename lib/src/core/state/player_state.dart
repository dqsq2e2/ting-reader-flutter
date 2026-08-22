import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart' as audio;
import 'package:just_audio_background/just_audio_background.dart'
    as audio_background;

import '../api/api_client.dart';
import '../models/models.dart';
import '../utils/chapter_sort.dart';
import '../utils/urls.dart';
import 'app_state.dart';
import 'download_state.dart';
import 'gateway_media_guard.dart';

class PlayerState extends ChangeNotifier with WidgetsBindingObserver {
  PlayerState(this.appState, this.downloadState) {
    WidgetsBinding.instance.addObserver(this);
    appState.onGatewayLoginRequired = _pauseForGatewayReauthentication;
    appState.onGatewayLoginRestored = _restoreAfterGatewayReauthentication;
    // Interruption policy is managed here because Android distinguishes
    // transient focus loss (which sends a later gain event) from permanent
    // focus loss (which does not). Audio-session activation is also requested
    // by just_audio_background at its lowest play entry point so notification
    // and headset controls cannot accidentally resume without audio focus.
    _audio = audio.AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: false,
    );
    _positionSub = _audio.positionStream.listen((position) {
      if (_suppressPositionUpdates) return;
      currentTime = _displayTimeForAudioPosition(position);
      if (currentTime > _furthestChapterPosition) {
        _furthestChapterPosition = currentTime;
      }
      _handleSkipOutro();
      notifyListeners();
    });
    _durationSub = _audio.durationStream.listen((durationValue) {
      if (durationValue != null) {
        final chapter = currentChapter;
        final chapterDuration = chapter?.duration.toDouble() ?? 0;
        final discoveredDuration = durationValue.inMilliseconds / 1000;
        duration = _usingTranscodeStream && chapterDuration > 0
            ? chapterDuration
            : discoveredDuration;
        if (chapter != null && chapter.duration <= 0) {
          _syncDiscoveredChapterDuration(chapter, discoveredDuration);
        }
        notifyListeners();
      }
    });
    _playingSub = _audio.playingStream.listen((playing) {
      if (_usingTranscodeStream && playing != isPlaying) {
        _resetTranscodeClock(currentTime);
      }
      isPlaying = playing;
      if (playing) {
        _cancelFocusRecovery(clearResume: true);
        _startProgressTimer();
      } else {
        _stopProgressTimers();
        if (!_gatewayReauthenticationPending) {
          unawaited(sendProgress());
        }
      }
      notifyListeners();
    });
    _completeSub = _audio.playerStateStream.listen((state) {
      if (state.processingState == audio.ProcessingState.completed) {
        unawaited(_handlePlaybackCompleted(state));
      }
    });
    _indexSub = _audio.currentIndexStream.listen(_syncChapterFromAudioIndex);
    if (!kIsWeb) {
      audio_background.JustAudioBackground.setSeekHandler(
        (position) => seek(position.inMilliseconds / 1000),
      );
      audio_background.JustAudioBackground.setChapterNavigationHandlers(
        onNext: nextChapter,
        onPrevious: previousChapter,
        hasNext: () => _canMoveChapter(1),
        hasPrevious: () => _canMoveChapter(-1),
      );
      audio_background.JustAudioBackground.setAudioFocusEnabled(true);
    }
    _audioSessionReady = _initializeAudioSession();
  }

  final AppState appState;
  final DownloadState downloadState;
  late final audio.AudioPlayer _audio;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<audio.PlayerState>? _completeSub;
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<audio_session.AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;
  StreamSubscription<audio_session.AudioDevicesChangedEvent>?
      _devicesChangedSub;
  late final Future<void> _audioSessionReady;
  Timer? _focusRecoveryTimer;
  bool _focusRecoveryInFlight = false;
  int _inactiveAudioChecks = 0;
  WebSocket? _progressSocket;
  StreamSubscription<dynamic>? _progressSocketSub;
  Timer? _progressSocketPingTimer;
  bool _progressSocketConnecting = false;
  Timer? _progressWsTimer;
  Timer? _progressTimer;
  Future<void> _transcodeSeekQueue = Future<void>.value();
  int _seekGeneration = 0;
  int _playGeneration = 0;
  final Set<String> _durationSyncing = {};
  final Set<String> _durationSynced = {};
  bool _usingTranscodeStream = false;
  bool _usingAudioQueue = false;
  bool _usingGatewaySingleChapterSource = false;
  bool _suppressPositionUpdates = false;
  bool _applyingQueueStartSeek = false;
  int? _handlingGatewayMediaCompletionGeneration;
  bool _gatewayReauthenticationPending = false;
  bool _resumeAfterGatewayReauthentication = false;
  double _furthestChapterPosition = 0;
  // 睡眠定时按集数：集数用完时阻止 playChapter 的 _playWithSession 自动起播，
  // 并在 _playWithSession 中暂停仍在播放的旧音频。
  bool _suppressAutoPlay = false;
  // 按集数睡眠：剩余可播集数（含当前集）。章节切换时递减，归零即暂停。
  int? _sleepEpisodesRemaining;
  String? _sleepEpisodeChapterId;
  double _transcodeClockPosition = 0;
  DateTime? _transcodeClockStartedAt;

  Book? currentBook;
  Chapter? currentChapter;
  List<Chapter> chapters = [];
  bool isPlaying = false;
  bool isExpanded = false;
  bool isMiniCollapsed = false;
  double currentTime = 0;
  double duration = 0;
  double playbackSpeed = 1;
  double volume = 1;
  String? error;
  bool ignoreAudioFocus = false;
  bool usingLocalFile = false;
  bool _advancingFromOutro = false;
  // Always enabled: an interruption resumes only if playback was active when
  // it began. Headset disconnection explicitly clears this flag.
  bool _resumeAfterInterruption = false;

  bool get hasChapter => currentBook != null && currentChapter != null;

  int get _currentChapterIndex {
    final chapter = currentChapter;
    if (chapter == null) return -1;
    return chapters.indexWhere((item) => item.id == chapter.id);
  }

  bool _canMoveChapter(int offset) {
    final index = _currentChapterIndex;
    if (index < 0) return false;
    final target = index + offset;
    return target >= 0 && target < chapters.length;
  }

  bool _isActivePlay(int generation, String chapterId) {
    return generation == _playGeneration && currentChapter?.id == chapterId;
  }

  void setExpanded(bool value) {
    if (isExpanded == value) return;
    isExpanded = value;
    if (value) isMiniCollapsed = false;
    notifyListeners();
  }

  void setMiniCollapsed(bool value) {
    if (isMiniCollapsed == value) return;
    isMiniCollapsed = value;
    notifyListeners();
  }

  Future<void> applySettings(Map<String, dynamic> settings) async {
    final nested = asMap(settings['settings_json']);
    final nextSpeed = _resolvePlaybackSpeedSetting(
      settings,
      nested: nested,
    );
    final next = _boolSetting(
      settings,
      'ignore_audio_focus',
      nested: nested,
      fallback: false,
    );
    await setSpeed(nextSpeed);
    await setIgnoreAudioFocus(next);
  }

  Future<void> setIgnoreAudioFocus(bool value) async {
    if (!kIsWeb) {
      audio_background.JustAudioBackground.setAudioFocusEnabled(
        !value || defaultTargetPlatform != TargetPlatform.android,
      );
    }
    await _audioSessionReady;
    if (ignoreAudioFocus == value) return;
    ignoreAudioFocus = value;
    _cancelFocusRecovery(clearResume: value);
    await _configureAudioSession();
    if (ignoreAudioFocus) {
      await _deactivateAudioSession();
    } else if (isPlaying || _audio.playing) {
      await _activateAudioSessionForPlayback();
    }
    notifyListeners();
  }

  Future<void> _initializeAudioSession() async {
    await _configureAudioSession();
    await _bindAudioSessionEvents();
  }

  Future<void> _configureAudioSession() async {
    if (kIsWeb) return;
    try {
      final session = await audio_session.AudioSession.instance;
      final config = ignoreAudioFocus
          ? const audio_session.AudioSessionConfiguration(
              avAudioSessionCategory:
                  audio_session.AVAudioSessionCategory.playback,
              avAudioSessionCategoryOptions:
                  audio_session.AVAudioSessionCategoryOptions.mixWithOthers,
              avAudioSessionMode: audio_session.AVAudioSessionMode.spokenAudio,
              androidAudioAttributes: audio_session.AndroidAudioAttributes(
                contentType: audio_session.AndroidAudioContentType.speech,
                usage: audio_session.AndroidAudioUsage.media,
              ),
              androidAudioFocusGainType:
                  audio_session.AndroidAudioFocusGainType.gain,
              androidWillPauseWhenDucked: false,
            )
          : const audio_session.AudioSessionConfiguration.speech();
      await session.configure(config);
    } catch (_) {
      // Unsupported platforms should not block in-app playback.
    }
  }

  Future<bool> _activateAudioSessionForPlayback() async {
    if (kIsWeb) return true;
    if (ignoreAudioFocus && defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }
    try {
      final session = await audio_session.AudioSession.instance;
      return await session.setActive(true);
    } catch (_) {
      return defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS;
    }
  }

  Future<void> _deactivateAudioSession() async {
    if (kIsWeb) return;
    try {
      final session = await audio_session.AudioSession.instance;
      await session.setActive(false);
    } catch (_) {
      // Releasing focus is best effort when switching to mix mode.
    }
  }

  Future<void> _bindAudioSessionEvents() async {
    if (kIsWeb) return;
    try {
      final session = await audio_session.AudioSession.instance;
      _interruptionSub =
          session.interruptionEventStream.listen(_handleInterruption);
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        _pauseForDisconnectedOutput();
      });
      _devicesChangedSub =
          session.devicesChangedEventStream.listen(_handleAudioDevicesChanged);
    } catch (_) {
      // Audio session events are best effort.
    }
  }

  void _handleAudioDevicesChanged(
    audio_session.AudioDevicesChangedEvent event,
  ) {
    final personalOutputRemoved = event.devicesRemoved.any(
      (device) =>
          device.isOutput &&
          _personalAudioDeviceTypeNames.contains(device.type.name),
    );
    if (personalOutputRemoved) _pauseForDisconnectedOutput();
  }

  void _pauseForDisconnectedOutput() {
    // Headset unplugged: always pause, never auto-resume.
    _cancelFocusRecovery(clearResume: true);
    unawaited(_audio.pause());
    unawaited(sendProgress());
  }

  void _handleInterruption(audio_session.AudioInterruptionEvent event) {
    if (ignoreAudioFocus) return;
    if (event.begin) {
      if (isPlaying || _audio.playing) {
        _resumeAfterInterruption = true;
        unawaited(_audio.pause());
        unawaited(sendProgress());
      }
      if (_resumeAfterInterruption &&
          event.type == audio_session.AudioInterruptionType.unknown &&
          defaultTargetPlatform == TargetPlatform.android) {
        _startPermanentFocusRecovery();
      }
      return;
    }
    if (_resumeAfterInterruption &&
        event.type != audio_session.AudioInterruptionType.unknown) {
      unawaited(_resumeAfterFocusReturned());
    }
  }

  void _startPermanentFocusRecovery() {
    if (_focusRecoveryTimer != null) return;
    _inactiveAudioChecks = 0;
    _focusRecoveryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tryRecoverPermanentFocusLoss());
    });
  }

  Future<void> _tryRecoverPermanentFocusLoss() async {
    if (_focusRecoveryInFlight ||
        !_resumeAfterInterruption ||
        ignoreAudioFocus ||
        isPlaying ||
        _audio.playing) {
      if (!_resumeAfterInterruption || ignoreAudioFocus || isPlaying) {
        _cancelFocusRecovery();
      }
      return;
    }
    _focusRecoveryInFlight = true;
    try {
      final manager = audio_session.AndroidAudioManager();
      if (await manager.isMusicActive()) {
        _inactiveAudioChecks = 0;
        return;
      }
      // Avoid stealing focus during a short buffering gap in the other app.
      _inactiveAudioChecks++;
      if (_inactiveAudioChecks < 2) return;
      await _resumeAfterFocusReturned();
    } catch (_) {
      // Keep waiting. Transient interruptions still recover from their normal
      // focus-gain event even if this Android-only fallback is unavailable.
    } finally {
      _focusRecoveryInFlight = false;
    }
  }

  Future<void> _resumeAfterFocusReturned() async {
    if (!_resumeAfterInterruption || ignoreAudioFocus) return;
    if (!await _playWithSession()) return;
    _resumeAfterInterruption = false;
    _cancelFocusRecovery();
  }

  void _cancelFocusRecovery({bool clearResume = false}) {
    _focusRecoveryTimer?.cancel();
    _focusRecoveryTimer = null;
    _inactiveAudioChecks = 0;
    if (clearResume) _resumeAfterInterruption = false;
  }

  Future<bool> _playWithSession() async {
    if (_gatewayReauthenticationPending) {
      if (appState.needsGatewayLogin) return false;
      _gatewayReauthenticationPending = false;
      _resumeAfterGatewayReauthentication = false;
    }
    if (_suppressAutoPlay) {
      _suppressAutoPlay = false;
      // playing 状态可能先于原生播放器变为 false，pause() 会因此直接返回。
      // stop() 不依赖 playing 状态，并会保留音源和当前位置供用户继续播放。
      await _audio.stop();
      return false;
    }
    await _audioSessionReady;
    if (!await _activateAudioSessionForPlayback()) return false;
    await _audio.play();
    return true;
  }

  /// 开启按集数睡眠定时。episodes=1 表示播完本集即停。
  void startEpisodeSleepTimer(int episodes) {
    if (episodes <= 0) return;
    _sleepEpisodesRemaining = episodes;
    _sleepEpisodeChapterId = currentChapter?.id;
    notifyListeners();
  }

  /// 取消按集数睡眠定时。
  void cancelEpisodeSleepTimer() {
    _sleepEpisodesRemaining = null;
    _sleepEpisodeChapterId = null;
    notifyListeners();
  }

  /// 当前剩余集数（含当前集），null 表示未开启。
  int? get sleepEpisodesRemaining => _sleepEpisodesRemaining;

  /// 在 currentChapter 更新后、notifyListeners 前调用。
  /// 返回 true 表示集数已用完，调用方应阻止自动起播。
  bool _checkEpisodeSleepOnChapterChange() {
    final newChapterId = currentChapter?.id;
    if (newChapterId == null || newChapterId == _sleepEpisodeChapterId) {
      return false;
    }
    _sleepEpisodeChapterId = newChapterId;
    final remaining = _sleepEpisodesRemaining;
    if (remaining == null) return false;
    if (remaining <= 1) {
      _sleepEpisodesRemaining = null;
      return true;
    }
    _sleepEpisodesRemaining = remaining - 1;
    return false;
  }

  /// 队列模式下集数用完时确定性停止底层音频。
  Future<void> _pauseForEpisodeSleep() async {
    _cancelFocusRecovery(clearResume: true);
    // Android/Windows 在队列切集时可能先上报 playing=false，导致 pause()
    // 短路而未通知原生播放器。stop() 始终停掉平台播放器，同时保留音源状态。
    await _audio.stop();
    await sendProgress();
  }

  Future<void> playChapter(
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
    notifyListeners();
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
          notifyListeners();
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
        notifyListeners();
      }
    }
  }

  Future<void> togglePlay() async {
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
  Future<void> pause() async {
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
    notifyListeners();
  }

  Future<void> _restoreAfterGatewayReauthentication() async {
    if (!_gatewayReauthenticationPending) return;
    final shouldResume = _resumeAfterGatewayReauthentication;
    _gatewayReauthenticationPending = false;
    _resumeAfterGatewayReauthentication = false;

    if (!hasChapter || !appState.isAuthenticated) {
      notifyListeners();
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
    notifyListeners();
  }

  Future<void> _resumePlaybackAfterGatewayReauthentication() async {
    try {
      await _playWithSession();
    } catch (_) {
      error = appState.textForLocale(
        '飞牛重新登录后恢复播放失败',
        'Unable to resume playback after fnOS sign-in',
      );
      notifyListeners();
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

  Future<void> seek(double seconds) async {
    final target =
        duration > 0 ? seconds.clamp(0, duration).toDouble() : seconds;
    final seekGeneration = ++_seekGeneration;
    currentTime = target;
    _furthestChapterPosition = target;
    notifyListeners();
    if (_usingTranscodeStream && currentChapter != null) {
      _resetTranscodeClock(target);
      _suppressPositionUpdates = true;
      final resumePlayback = isPlaying || _audio.playing;
      final book = currentBook;
      try {
        final mediaItem = book == null
            ? MediaItem(
                id: currentChapter!.id,
                title: currentChapter!.title,
                duration: duration > 0
                    ? Duration(milliseconds: (duration * 1000).round())
                    : null,
                extras: {
                  if (target > 0) 'streamOffsetSeconds': target,
                },
              )
            : _mediaItemFor(
                book,
                currentChapter!,
                streamOffset: target,
              );
        await _queueTranscodeSeek(() async {
          if (seekGeneration != _seekGeneration) return;
          await _setMp3TranscodeSource(currentChapter!, mediaItem, target);
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
        notifyListeners();
      } finally {
        if (seekGeneration == _seekGeneration) {
          _suppressPositionUpdates = false;
          currentTime = _clampPlaybackTime(target);
          notifyListeners();
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

  double _displayTimeForAudioPosition(Duration position) {
    final rawSeconds = position.inMilliseconds / 1000;
    if (!_usingTranscodeStream) {
      return _clampPlaybackTime(rawSeconds);
    }
    return _expectedTranscodeTime();
  }

  double _expectedTranscodeTime() {
    final startedAt = _transcodeClockStartedAt;
    var expected = _transcodeClockPosition;
    if (startedAt != null && isPlaying) {
      expected += DateTime.now().difference(startedAt).inMilliseconds /
          1000 *
          playbackSpeed;
    }
    return _clampPlaybackTime(expected);
  }

  double _clampPlaybackTime(double seconds) {
    final normalized = seconds.isFinite ? seconds : 0.0;
    if (duration > 0) {
      return normalized.clamp(0, duration).toDouble();
    }
    return normalized < 0 ? 0 : normalized;
  }

  void _resetTranscodeClock(double position) {
    final clamped = _clampPlaybackTime(position);
    _transcodeClockPosition = clamped;
    _transcodeClockStartedAt = DateTime.now();
    currentTime = clamped;
  }

  void _clearTranscodeClock() {
    _transcodeClockPosition = 0;
    _transcodeClockStartedAt = null;
  }

  void _syncDiscoveredChapterDuration(Chapter chapter, double seconds) {
    final rounded = seconds.round();
    if (rounded <= 0) return;
    if (_usingTranscodeStream && currentTime > 1) return;
    if (_durationSynced.contains(chapter.id) ||
        _durationSyncing.contains(chapter.id)) {
      return;
    }
    _durationSyncing.add(chapter.id);
    Future<void>(() async {
      try {
        await appState.api.patch(
          '/api/chapters/${chapter.id}',
          data: {'duration': rounded},
        );
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
          notifyListeners();
        }
        _durationSynced.add(chapter.id);
      } catch (_) {
        // Duration discovery should never interrupt playback.
      } finally {
        _durationSyncing.remove(chapter.id);
      }
    });
  }

  Future<void> setSpeed(double speed) async {
    playbackSpeed = speed;
    await _audio.setSpeed(speed);
    notifyListeners();
  }

  Future<void> setPlayerVolume(double value) async {
    volume = value.clamp(0, 1);
    await _audio.setVolume(volume);
    notifyListeners();
  }

  Future<void> setVolume(double value) => setPlayerVolume(value);

  void replaceCurrentBook(Book book) {
    currentBook = book;
    notifyListeners();
  }

  Future<void> nextChapter() async {
    _advancingFromOutro = false;
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
      return;
    }
    if (index >= 0 && index < chapters.length - 1) {
      await playChapter(book, chapters, chapters[index + 1]);
    } else {
      await _audio.pause();
      await sendProgress();
    }
  }

  Future<void> previousChapter() async {
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

  String streamUrl(
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
  }) {
    if (kIsWeb) {
      return _audio.setAudioSource(
        audio.AudioSource.uri(Uri.parse(url), tag: mediaItem),
        initialPosition: initialPosition,
      );
    }
    final headers = appState.api.authHeaders;
    return _audio.setAudioSource(
      audio.AudioSource.uri(
        Uri.parse(url),
        headers: headers.isEmpty ? null : headers,
        tag: mediaItem,
      ),
      initialPosition: initialPosition,
    );
  }

  Future<void> _setGatewaySingleChapterSource(
    Book book,
    Chapter chapter, {
    required String? localPath,
    required double position,
  }) async {
    final mediaItem = _mediaItemFor(book, chapter);
    if (localPath != null) {
      await _audio.setAudioSource(
        audio.AudioSource.uri(Uri.file(localPath), tag: mediaItem),
        initialPosition: Duration(
          milliseconds: (position * 1000).round(),
        ),
      );
      return;
    }

    await _setAudioUrlWithRedirectRecovery(
      () => streamUrl(chapter.id),
      mediaItem: mediaItem,
      initialPosition: Duration(
        milliseconds: (position * 1000).round(),
      ),
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
      mediaItem: mediaItem,
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
  }

  Map<String, String> get _streamHeaders {
    if (kIsWeb) return const {};
    return appState.api.authHeaders;
  }

  String? _localFilePathFromChapter(Chapter chapter) {
    final raw = chapter.path.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'file') return uri.toFilePath();
    if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(raw) ||
        raw.startsWith('/data/') ||
        raw.startsWith('/storage/') ||
        raw.startsWith('/var/') ||
        raw.startsWith('/Users/')) {
      return raw;
    }
    return null;
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
    notifyListeners();
    if (shouldStopForSleep) {
      unawaited(_pauseForEpisodeSleep());
      return;
    }
    if (!_applyingQueueStartSeek && startPosition > 0 && book != null) {
      unawaited(_seekAudioQueueToChapter(index, book, nextChapter));
    }
    _startProgressTimer();
  }

  bool get _usesGatewaySingleChapterPlayback =>
      !appState.offlineMode &&
      !appState.needsGatewayLogin &&
      (appState.token?.trim().isNotEmpty ?? false) &&
      (appState.api.isGatewaySession?.call() ?? false);

  Future<void> _handlePlaybackCompleted(audio.PlayerState state) async {
    if (!_usingGatewaySingleChapterSource || _usingAudioQueue) {
      await sendProgress();
      return;
    }
    if (!_usesGatewaySingleChapterPlayback) {
      await sendProgress();
      if (!_gatewayReauthenticationPending && !appState.needsGatewayLogin) {
        unawaited(nextChapter());
      }
      return;
    }
    final playGeneration = _playGeneration;
    if (_handlingGatewayMediaCompletionGeneration == playGeneration ||
        _suppressPositionUpdates ||
        _gatewayReauthenticationPending ||
        appState.needsGatewayLogin) {
      return;
    }

    final chapter = currentChapter;
    if (chapter == null) return;
    _handlingGatewayMediaCompletionGeneration = playGeneration;
    final shouldResume = state.playing || isPlaying || _audio.playing;
    _resumeAfterGatewayReauthentication =
        _resumeAfterGatewayReauthentication || shouldResume;
    _stopProgressTimers();
    var shouldAdvance = false;

    try {
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
      notifyListeners();

      // Native media requests bypass Dio and fnOS may return HTTP 200 with an
      // "invalid token" body. Verify the gateway before advancing.
      final probeResult = await _probeGatewaySession();
      if (!_isActivePlay(playGeneration, chapter.id)) return;
      if (probeResult == _GatewaySessionProbeResult.expired) return;
      if (probeResult == _GatewaySessionProbeResult.unavailable) {
        _resumeAfterGatewayReauthentication = false;
        await _pauseAfterGatewayMediaFailure();
        error = appState.textForLocale(
          '无法验证飞牛登录状态，播放已暂停',
          'Unable to verify the fnOS session. Playback is paused',
        );
        notifyListeners();
        return;
      }

      if (_gatewayReauthenticationPending || appState.needsGatewayLogin) {
        return;
      }

      if (!usingLocalFile &&
          isPrematureGatewayMediaCompletion(
            positionSeconds: observedPosition,
            expectedDurationSeconds: chapter.duration.toDouble(),
          )) {
        _resumeAfterGatewayReauthentication = false;
        await _pauseAfterGatewayMediaFailure();
        error = appState.textForLocale(
          '音频流异常结束，已停止自动跳转章节',
          'The audio stream ended unexpectedly. Automatic chapter advance was stopped',
        );
        notifyListeners();
        return;
      }

      _resumeAfterGatewayReauthentication = false;
      await sendProgress();
      if (!_isActivePlay(playGeneration, chapter.id) ||
          _gatewayReauthenticationPending ||
          appState.needsGatewayLogin) {
        return;
      }
      shouldAdvance = shouldResume;
    } finally {
      if (_handlingGatewayMediaCompletionGeneration == playGeneration) {
        _handlingGatewayMediaCompletionGeneration = null;
      }
    }
    if (shouldAdvance) {
      unawaited(nextChapter());
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

  MediaItem _mediaItemFor(
    Book book,
    Chapter chapter, {
    double streamOffset = 0,
  }) {
    final artistParts = [
      if ((book.narrator ?? '').trim().isNotEmpty) book.narrator!.trim(),
      if ((book.author ?? '').trim().isNotEmpty) book.author!.trim(),
    ];
    final artUri = _mediaArtUri(book);
    final artHeaders = artUri != null &&
            (artUri.scheme == 'http' || artUri.scheme == 'https') &&
            appState.usesActiveOrigin(artUri.toString())
        ? _streamHeaders
        : null;
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

  Future<void> sendProgress({double? playbackStart}) async {
    final book = currentBook;
    final chapter = currentChapter;
    if (book == null || chapter == null) return;
    if (appState.offlineMode || _gatewayReauthenticationPending) return;
    final sentByWebSocket = await _sendProgressByWebSocket(
      book,
      chapter,
      playbackStart: playbackStart,
    );
    if (sentByWebSocket || _gatewayReauthenticationPending) return;
    await _sendProgressByHttp(
      book,
      chapter,
      playbackStart: playbackStart,
    );
  }

  Future<void> _sendCurrentProgressByWebSocket() async {
    final book = currentBook;
    final chapter = currentChapter;
    if (book == null ||
        chapter == null ||
        appState.offlineMode ||
        _gatewayReauthenticationPending) {
      return;
    }
    await _sendProgressByWebSocket(book, chapter);
  }

  Future<void> _sendCurrentProgressByHttp() async {
    final book = currentBook;
    final chapter = currentChapter;
    if (book == null ||
        chapter == null ||
        appState.offlineMode ||
        _gatewayReauthenticationPending) {
      return;
    }
    if (!kIsWeb &&
        _progressSocket != null &&
        !_usesGatewaySingleChapterPlayback) {
      return;
    }
    await _sendProgressByHttp(book, chapter);
  }

  Future<void> _sendProgressByHttp(
    Book book,
    Chapter chapter, {
    double? playbackStart,
  }) async {
    if (_gatewayReauthenticationPending) return;
    try {
      await appState.api.post(
        '/api/progress',
        data: {
          'book_id': book.id,
          'chapter_id': chapter.id,
          'position': currentTime,
          'duration': duration > 0 ? duration : chapter.duration,
          if (playbackStart != null) 'playback_start': playbackStart,
        },
      );
    } catch (_) {
      // Playback should keep going even when background progress sync fails.
    }
  }

  Future<bool> _sendProgressByWebSocket(
    Book book,
    Chapter chapter, {
    double? playbackStart,
  }) async {
    if (kIsWeb) return false;
    final token = appState.token;
    if (token == null ||
        token.isEmpty ||
        appState.offlineMode ||
        _gatewayReauthenticationPending) {
      return false;
    }
    try {
      final socket = await _ensureProgressSocket();
      if (socket == null) return false;
      socket.add(
        jsonEncode({
          'type': 'progress_update',
          'book_id': book.id,
          'chapter_id': chapter.id,
          'position': currentTime.floor(),
          if (playbackStart != null) 'playback_start': playbackStart.floor(),
        }),
      );
      return true;
    } catch (error) {
      if (_isInvalidGatewayTokenResult(error)) {
        _triggerGatewayReauthentication();
      }
      _closeProgressSocket();
      return false;
    }
  }

  Future<WebSocket?> _ensureProgressSocket() async {
    if (_progressSocket != null) return _progressSocket;
    if (_progressSocketConnecting) return null;
    _progressSocketConnecting = true;
    try {
      final uri = _progressWebSocketUri();
      if (uri == null) return null;
      final headers = appState.api.authHeaders;
      final socket = await WebSocket.connect(
        uri.toString(),
        headers: headers.isEmpty ? null : headers,
      ).timeout(
        const Duration(seconds: 5),
      );
      if (_gatewayReauthenticationPending) {
        await socket.close();
        return null;
      }
      _progressSocket = socket;
      _progressSocketSub = socket.listen(
        _handleProgressSocketMessage,
        onDone: () => _handleProgressSocketDone(socket),
        onError: (Object error) => _handleProgressSocketError(socket, error),
        cancelOnError: true,
      );
      _progressSocketPingTimer?.cancel();
      _progressSocketPingTimer =
          Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _progressSocket?.add(jsonEncode({'type': 'ping'}));
        } catch (_) {
          _closeProgressSocket();
        }
      });
      return socket;
    } catch (error) {
      if (_isInvalidGatewayTokenResult(error)) {
        _triggerGatewayReauthentication();
      }
      _closeProgressSocket();
      return null;
    } finally {
      _progressSocketConnecting = false;
    }
  }

  Uri? _progressWebSocketUri() {
    final token = appState.token;
    if (token == null || token.isEmpty) return null;
    final base = Uri.tryParse(appState.activeUrl);
    if (base == null || base.host.isEmpty) return null;
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(
      scheme: scheme,
      path: '${basePath.isEmpty ? '' : basePath}/api/ws',
      queryParameters: {'token': token},
    );
  }

  void _handleProgressSocketMessage(dynamic message) {
    if (message == null) return;
    try {
      final rawMessage = message is List<int>
          ? utf8.decode(message, allowMalformed: true)
          : message.toString();
      if (_isInvalidGatewayTokenResult(rawMessage)) {
        _triggerGatewayReauthentication();
        return;
      }
      final data = jsonDecode(rawMessage);
      if (_isInvalidGatewayTokenResult(data)) {
        _triggerGatewayReauthentication();
        return;
      }
      if (data is! Map) return;
      if (data['type'] != 'progress_updated') return;
      final bookId = data['book_id']?.toString();
      final chapterId = data['chapter_id']?.toString();
      final position = _doubleValue(data['position']);
      if (position == null) return;
      if (currentBook?.id != bookId || currentChapter?.id != chapterId) return;
      final delta = (position - currentTime).abs();
      if (delta > 3 && !_audio.playing) {
        currentTime = _clampPlaybackTime(position);
        notifyListeners();
      }
    } catch (_) {
      // Bad realtime packets should not affect playback.
    }
  }

  void _handleProgressSocketDone(WebSocket socket) {
    if (_isInvalidGatewayTokenResult(socket.closeReason)) {
      _triggerGatewayReauthentication();
    }
    _closeProgressSocket(expectedSocket: socket);
  }

  void _handleProgressSocketError(WebSocket socket, Object error) {
    if (_isInvalidGatewayTokenResult(error)) {
      _triggerGatewayReauthentication();
    }
    _closeProgressSocket(expectedSocket: socket);
  }

  bool _isInvalidGatewayTokenResult(Object? result) {
    if (!(appState.api.isGatewaySession?.call() ?? false)) return false;
    return ApiClient.isInvalidGatewayTokenPayload(result);
  }

  void _triggerGatewayReauthentication() {
    _closeProgressSocket();
    unawaited(appState.handleGatewaySessionExpired());
  }

  void _closeProgressSocket({WebSocket? expectedSocket}) {
    if (expectedSocket != null && !identical(_progressSocket, expectedSocket)) {
      return;
    }
    _progressSocketPingTimer?.cancel();
    _progressSocketPingTimer = null;
    _progressSocketSub?.cancel();
    _progressSocketSub = null;
    final socket = _progressSocket;
    _progressSocket = null;
    try {
      socket?.close();
    } catch (_) {
      // Ignore socket teardown errors.
    }
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
        await nextChapter();
      });
    }
  }

  Future<String> cacheCurrentChapter() async {
    return downloadCurrentChapter();
  }

  Future<String> downloadCurrentChapter() async {
    final book = currentBook;
    final chapter = currentChapter;
    if (book == null || chapter == null) {
      throw StateError('No active chapter to download');
    }
    if (downloadState.hasChapter(chapter.id)) {
      return appState.textForLocale(
        '《${chapter.title}》已下载到本机',
        '"${chapter.title}" is already downloaded',
      );
    }
    final task = downloadState.queueChapter(book, chapter);
    if (task.status == DownloadStatus.paused) {
      await downloadState.resumeTask(chapter.id);
      return appState.textForLocale(
        '《${chapter.title}》已继续下载',
        'Resumed "${chapter.title}"',
      );
    }
    if (task.status == DownloadStatus.failed) {
      await downloadState.retryTask(chapter.id);
      return appState.textForLocale(
        '《${chapter.title}》已重新加入下载队列',
        'Requeued "${chapter.title}"',
      );
    }
    return appState.textForLocale(
      '《${chapter.title}》已加入下载队列',
      'Added "${chapter.title}" to download queue',
    );
  }

  void _startProgressTimer() {
    if (_gatewayReauthenticationPending ||
        !_audio.playing ||
        _audio.processingState == audio.ProcessingState.completed) {
      return;
    }
    _stopProgressTimers();
    unawaited(sendProgress(playbackStart: currentTime));
    _progressWsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_sendCurrentProgressByWebSocket());
    });
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_sendCurrentProgressByHttp());
    });
  }

  void _stopProgressTimers() {
    _progressWsTimer?.cancel();
    _progressWsTimer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(sendProgress());
    }
  }

  @override
  void dispose() {
    if (appState.onGatewayLoginRequired == _pauseForGatewayReauthentication) {
      appState.onGatewayLoginRequired = null;
    }
    if (appState.onGatewayLoginRestored ==
        _restoreAfterGatewayReauthentication) {
      appState.onGatewayLoginRestored = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _stopProgressTimers();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completeSub?.cancel();
    _indexSub?.cancel();
    _interruptionSub?.cancel();
    _noisySub?.cancel();
    _devicesChangedSub?.cancel();
    _cancelFocusRecovery(clearResume: true);
    if (!kIsWeb) {
      audio_background.JustAudioBackground.setSeekHandler(null);
      audio_background.JustAudioBackground.setChapterNavigationHandlers();
      audio_background.JustAudioBackground.setAudioFocusEnabled(true);
    }
    _closeProgressSocket();
    _audio.dispose();
    super.dispose();
  }
}

enum _GatewaySessionProbeResult { valid, expired, unavailable }

const _personalAudioDeviceTypeNames = <String>{
  'wiredHeadset',
  'wiredHeadphones',
  'bluetoothSco',
  'bluetoothA2dp',
  'bluetoothLe',
  'usbAudio',
  'hearingAid',
};

bool _boolSetting(
  Map<String, dynamic> data,
  String key, {
  Map<String, dynamic> nested = const {},
  bool fallback = false,
}) {
  for (final source in [data, nested]) {
    final value = source[key];
    if (value == null) continue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
  }
  return fallback;
}

double? _doubleValue(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

double _resolvePlaybackSpeedSetting(
  Map<String, dynamic> settings, {
  Map<String, dynamic>? nested,
}) {
  final nestedSettings = nested ?? asMap(settings['settings_json']);
  for (final source in [settings, nestedSettings]) {
    final value = source['playback_speed'];
    final parsed = _doubleValue(value);
    if (parsed != null && parsed.isFinite && parsed > 0) {
      return parsed;
    }
  }
  return 1.0;
}
