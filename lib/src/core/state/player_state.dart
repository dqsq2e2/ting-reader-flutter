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

import '../models/models.dart';
import '../utils/chapter_sort.dart';
import '../utils/urls.dart';
import 'app_state.dart';
import 'download_state.dart';

class PlayerState extends ChangeNotifier with WidgetsBindingObserver {
  PlayerState(this.appState, this.downloadState) {
    WidgetsBinding.instance.addObserver(this);
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
        unawaited(sendProgress());
      }
      notifyListeners();
    });
    _completeSub = _audio.playerStateStream.listen((state) {
      if (state.processingState == audio.ProcessingState.completed) {
        unawaited(sendProgress());
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
  bool _suppressPositionUpdates = false;
  bool _applyingQueueStartSeek = false;
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
    final nested = asMap(settings['settings_json'] ?? settings['settingsJson']);
    final next = _boolSetting(
      settings,
      'ignore_audio_focus',
      'ignoreAudioFocus',
      nested: nested,
      fallback: false,
    );
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
      return session.setActive(true);
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
    await _audioSessionReady;
    if (!await _activateAudioSessionForPlayback()) return false;
    await _audio.play();
    return true;
  }

  Future<void> playChapter(
    Book book,
    List<Chapter> chapterList,
    Chapter chapter, {
    double? startAt,
  }) async {
    _cancelFocusRecovery(clearResume: true);
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
    duration = targetChapter.duration.toDouble();
    error = null;
    usingLocalFile = false;
    isMiniCollapsed = false;
    _seekGeneration++;
    _suppressPositionUpdates = true;
    _usingTranscodeStream = false;
    _usingAudioQueue = false;
    _clearTranscodeClock();
    notifyListeners();
    await _waitForPendingTranscodeSeek();
    if (!_isActivePlay(playGeneration, targetChapter.id)) return;

    try {
      final localPath = _localFilePathFromChapter(targetChapter) ??
          await downloadState.localPathForChapter(targetChapter.id);
      if (!_isActivePlay(playGeneration, targetChapter.id)) return;
      usingLocalFile = localPath != null;
      await _setAudioQueueWithRedirectRecovery(
        book,
        chapters,
        initialIndex: initialIndex,
        initialPosition:
            Duration(milliseconds: (resumePosition * 1000).round()),
      );
      if (!_isActivePlay(playGeneration, targetChapter.id)) return;
      _usingAudioQueue = true;
      currentTime = resumePosition;
      _suppressPositionUpdates = false;
      await _audio.setSpeed(playbackSpeed);
      await _audio.setVolume(volume);
      if (!_isActivePlay(playGeneration, targetChapter.id)) return;
      await _playWithSession();
      _startProgressTimer();
    } catch (err) {
      if (!_isActivePlay(playGeneration, targetChapter.id)) return;
      usingLocalFile = false;
      _usingAudioQueue = false;
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
        error = '音频播放失败';
        notifyListeners();
      }
    }
  }

  Future<void> togglePlay() async {
    if (!hasChapter) return;
    _cancelFocusRecovery(clearResume: true);
    if (_audio.playing) {
      await _audio.pause();
      await sendProgress();
    } else {
      await _playWithSession();
      _startProgressTimer();
    }
  }

  Future<void> seek(double seconds) async {
    final target =
        duration > 0 ? seconds.clamp(0, duration).toDouble() : seconds;
    final seekGeneration = ++_seekGeneration;
    currentTime = target;
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
        error = '跳转失败';
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
  }) async {
    final firstUrl = buildUrl();
    try {
      await _setAudioUrl(firstUrl, mediaItem);
    } catch (_) {
      if (!appState.usesActiveOrigin(firstUrl)) rethrow;
      final previousActiveUrl = appState.activeUrl;
      final recoveredUrl = await appState.recoverActiveUrl();
      if (recoveredUrl == null ||
          recoveredUrl.isEmpty ||
          recoveredUrl == previousActiveUrl) {
        rethrow;
      }
      await _setAudioUrl(buildUrl(), mediaItem);
    }
  }

  Future<void> _setAudioUrl(String url, MediaItem mediaItem) {
    if (kIsWeb) {
      return _audio.setAudioSource(
        audio.AudioSource.uri(Uri.parse(url), tag: mediaItem),
      );
    }
    final headers = <String, String>{
      ...appState.api.clientHeaders,
      if (appState.token != null && appState.token!.isNotEmpty)
        'Authorization': 'Bearer ${appState.token}',
    };
    return _audio.setAudioSource(
      audio.AudioSource.uri(
        Uri.parse(url),
        headers: headers.isEmpty ? null : headers,
        tag: mediaItem,
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
    return {
      ...appState.api.clientHeaders,
      if (appState.token != null && appState.token!.isNotEmpty)
        'Authorization': 'Bearer ${appState.token}',
    };
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
    duration = nextChapter.duration.toDouble();
    _clearTranscodeClock();
    _usingTranscodeStream = false;
    _advancingFromOutro = false;
    usingLocalFile = _localFilePathFromChapter(nextChapter) != null ||
        downloadState.hasChapter(nextChapter.id);
    notifyListeners();
    if (!_applyingQueueStartSeek && startPosition > 0 && book != null) {
      unawaited(_seekAudioQueueToChapter(index, book, nextChapter));
    }
    _startProgressTimer();
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
    if (appState.offlineMode) return;
    unawaited(
      _sendProgressByWebSocket(
        book,
        chapter,
        playbackStart: playbackStart,
      ),
    );
    await _sendProgressByHttp(
      book,
      chapter,
      playbackStart: playbackStart,
    );
  }

  Future<void> _sendCurrentProgressByWebSocket() async {
    final book = currentBook;
    final chapter = currentChapter;
    if (book == null || chapter == null || appState.offlineMode) return;
    await _sendProgressByWebSocket(book, chapter);
  }

  Future<void> _sendCurrentProgressByHttp() async {
    final book = currentBook;
    final chapter = currentChapter;
    if (book == null || chapter == null || appState.offlineMode) return;
    await _sendProgressByHttp(book, chapter);
  }

  Future<void> _sendProgressByHttp(
    Book book,
    Chapter chapter, {
    double? playbackStart,
  }) async {
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

  Future<void> _sendProgressByWebSocket(
    Book book,
    Chapter chapter, {
    double? playbackStart,
  }) async {
    if (kIsWeb) return;
    final token = appState.token;
    if (token == null || token.isEmpty || appState.offlineMode) return;
    try {
      final socket = await _ensureProgressSocket();
      if (socket == null) return;
      socket.add(
        jsonEncode({
          'type': 'progress_update',
          'book_id': book.id,
          'chapter_id': chapter.id,
          'position': currentTime.floor(),
          if (playbackStart != null) 'playback_start': playbackStart.floor(),
        }),
      );
    } catch (_) {
      // HTTP sync is kept as a separate fallback, matching the web client.
    }
  }

  Future<WebSocket?> _ensureProgressSocket() async {
    if (_progressSocket != null) return _progressSocket;
    if (_progressSocketConnecting) return null;
    _progressSocketConnecting = true;
    try {
      final uri = _progressWebSocketUri();
      if (uri == null) return null;
      final socket = await WebSocket.connect(uri.toString()).timeout(
        const Duration(seconds: 5),
      );
      _progressSocket = socket;
      _progressSocketSub = socket.listen(
        _handleProgressSocketMessage,
        onDone: _closeProgressSocket,
        onError: (_) => _closeProgressSocket(),
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
    } catch (_) {
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
      final data = jsonDecode(message.toString());
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

  void _closeProgressSocket() {
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
      return '《${chapter.title}》已下载到本机';
    }
    final task = downloadState.queueChapter(book, chapter);
    if (task.status == DownloadStatus.paused) {
      await downloadState.resumeTask(chapter.id);
      return '《${chapter.title}》已继续下载';
    }
    if (task.status == DownloadStatus.failed) {
      await downloadState.retryTask(chapter.id);
      return '《${chapter.title}》已重新加入下载队列';
    }
    return '《${chapter.title}》已加入下载队列';
  }

  void _startProgressTimer() {
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
  String snake,
  String camel, {
  Map<String, dynamic> nested = const {},
  bool fallback = false,
}) {
  for (final source in [data, nested]) {
    final value = source[snake] ?? source[camel];
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
