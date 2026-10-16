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
import '../api/api_error.dart';
import '../models/models.dart';
import '../utils/chapter_sort.dart';
import '../utils/urls.dart';
import 'app_state.dart';
import 'download_state.dart';
import 'gateway_media_guard.dart';
import 'books_state.dart';
import 'player/playback_sleep.dart';

part 'player/player_progress.dart';
part 'player/player_focus.dart';
part 'player/player_playback.dart';
part 'player/player_gateway.dart';
part 'player/player_source.dart';

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
        duration = _usingTranscodeStream ? chapterDuration : discoveredDuration;
        if (chapter != null && chapter.duration <= 0) {
          _syncDiscoveredChapterDuration(chapter, discoveredDuration);
        }
        notifyListeners();
      }
    });
    _playingSub = _audio.playingStream.listen((playing) {
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
      if (_usingTranscodeStream) {
        _resetTranscodeClock(_expectedTranscodeTime());
        _clock.running = state.playing &&
            state.processingState == audio.ProcessingState.ready;
      }
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
  late final _PlayerProgress _progress = _PlayerProgress(
    appState: appState,
    snapshot: () {
      final book = currentBook;
      final chapter = currentChapter;
      return book == null || chapter == null
          ? null
          : (
              book: book,
              chapter: chapter,
              position: currentTime,
              duration: duration,
            );
    },
    suspended: () => _gatewayReauthenticationPending,
    needsHttpFallback: () => _usesGatewaySingleChapterPlayback,
    onRemotePosition: (bookId, chapterId, position) {
      if (_disposed ||
          currentBook?.id != bookId ||
          currentChapter?.id != chapterId) {
        return;
      }
      if ((position - currentTime).abs() > 3 && !_audio.playing) {
        currentTime = _clampPlaybackTime(position);
        _notifyIfActive();
      }
    },
  );
  final _TranscodeClock _clock = _TranscodeClock();
  bool _disposed = false;
  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

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
  ({int play, int seek})? _completedPlaybackOperation;
  bool _gatewayReauthenticationPending = false;
  bool _resumeAfterGatewayReauthentication = false;
  int _mediaAuthRevision = -1;
  double _furthestChapterPosition = 0;
  // 睡眠定时按集数：集数用完时阻止 playChapter 的 _playWithSession 自动起播，
  // 并在 _playWithSession 中暂停仍在播放的旧音频。
  bool _suppressAutoPlay = false;
  // 按集数睡眠：剩余可播集数（含当前集）。章节切换时递减，归零即暂停。
  late final PlaybackSleep _sleep = PlaybackSleep(
    isPlaying: () => isPlaying,
    onChanged: _notifyIfActive,
    onExpire: () async {
      try {
        await pause();
      } catch (failure) {
        if (!_disposed) {
          error = ApiError.messageFor(failure);
          _notifyIfActive();
        }
      }
    },
  );
  late final BookOperations _bookOperations = BookOperations(appState.api);

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
  bool _volumeInitialized = false;
  bool _speedInitialized = false;
  String? error;
  // Allow other apps to keep playing audio by default.
  bool ignoreAudioFocus = true;
  bool usingLocalFile = false;
  bool _advancingFromOutro = false;
  // Always enabled: an interruption resumes only if playback was active when
  // it began. Headset disconnection explicitly clears this flag.
  bool _resumeAfterInterruption = false;

  bool get hasChapter => currentBook != null && currentChapter != null;

  void updateBookMetadata(Book book) {
    if (currentBook?.id != book.id) return;
    currentBook = book;
    notifyListeners();
  }

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
    return !_disposed &&
        generation == _playGeneration &&
        currentChapter?.id == chapterId;
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
      fallback: true,
    );
    final nextVolume = _doubleValue(settings['player_volume']) ??
        _doubleValue(nested['player_volume']);
    if (!_speedInitialized) await setSpeed(nextSpeed);
    if (!_volumeInitialized) {
      await _setPlayerVolume(nextVolume ?? 1, persist: false);
    }
    await setIgnoreAudioFocus(next);
  }

  Future<void> setIgnoreAudioFocus(bool value) => _setAudioFocusPolicy(value);
  void startEpisodeSleepTimer(int episodes) => _startEpisodeSleep(episodes);
  void cancelEpisodeSleepTimer() => _cancelEpisodeSleep();
  int? get sleepEpisodesRemaining => _sleep.episodes;
  int? get sleepRemainingSeconds => _sleep.seconds;
  void startSleepTimer(int minutes) => _sleep.minutes(minutes);
  void cancelSleepTimer() => _sleep.cancel();
  Future<void> savePlaybackSettings(Book book, int intro, int outro) async {
    final saved = await _bookOperations.save(
        book.id, {'skip_intro': intro, 'skip_outro': outro},
        original: book);
    if (!_disposed) updateBookMetadata(saved);
  }

  Future<void> playChapter(
          Book book, List<Chapter> chapterList, Chapter chapter,
          {double? startAt}) =>
      _playChapter(book, chapterList, chapter, startAt: startAt);
  Future<void> togglePlay() => _togglePlayback();
  Future<void> pause() => _pausePlayback();
  Future<void> seek(double seconds) => _seekPlayback(seconds);
  Future<void> nextChapter({bool fromOutro = false}) =>
      _nextChapter(fromOutro: fromOutro);
  Future<void> previousChapter() => _previousChapter();
  String streamUrl(String chapterId, {String? transcodeFormat, double? seek}) =>
      _buildStreamUrl(chapterId, transcodeFormat: transcodeFormat, seek: seek);

  double _displayTimeForAudioPosition(Duration position) {
    final rawSeconds = position.inMilliseconds / 1000;
    if (!_usingTranscodeStream) {
      return _clampPlaybackTime(rawSeconds);
    }
    return _expectedTranscodeTime();
  }

  double _expectedTranscodeTime() =>
      _clock.position(speed: playbackSpeed, duration: duration);

  double _clampPlaybackTime(double seconds) =>
      _TranscodeClock.clamp(seconds, duration);

  void _resetTranscodeClock(double position) {
    _clock.reset(position, duration);
    currentTime = _clampPlaybackTime(position);
  }

  void _clearTranscodeClock() => _clock.clear();

  Future<void> setSpeed(double speed) async {
    if (!speed.isFinite) return;
    final normalized = (speed.clamp(0.5, 3.0) * 10).round() / 10;
    if (_usingTranscodeStream) {
      _resetTranscodeClock(_expectedTranscodeTime());
    }
    playbackSpeed = normalized;
    _speedInitialized = true;
    await _audio.setSpeed(normalized);
    notifyListeners();
  }

  Future<void> setPlayerVolume(double value) async {
    await _setPlayerVolume(value);
  }

  Future<void> _setPlayerVolume(double value, {bool persist = true}) async {
    if (!value.isFinite) return;
    volume = value.clamp(0, 1).toDouble();
    _volumeInitialized = true;
    await _audio.setVolume(volume);
    notifyListeners();
    if (persist) {
      await appState.updateLocalSettings({'player_volume': volume});
    }
  }

  Future<void> setVolume(double value) => setPlayerVolume(value);

  void replaceCurrentBook(Book book) {
    currentBook = book;
    notifyListeners();
  }

  Future<void> sendProgress({double? playbackStart}) =>
      _progress.send(playbackStart: playbackStart);

  void _closeProgressSocket() => _progress.closeSocket();

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
    if (_disposed ||
        _gatewayReauthenticationPending ||
        !_audio.playing ||
        _audio.processingState == audio.ProcessingState.completed) {
      return;
    }
    _progress.start(currentTime);
  }

  void _stopProgressTimers() => _progress.stop();

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
    _disposed = true;
    _sleep.dispose();
    _bookOperations.dispose();
    _playGeneration++;
    _seekGeneration++;
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
    _progress.dispose();
    _audio.dispose();
    super.dispose();
  }
}

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
      return (parsed.clamp(0.5, 3.0) * 10).round() / 10;
    }
  }
  return 1.0;
}
