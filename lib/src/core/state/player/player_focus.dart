part of '../player_state.dart';

/// Audio focus, interruption handling and headset disconnection.
extension _PlayerAudioFocus on PlayerState {
  Future<void> _setAudioFocusPolicy(bool value) async {
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
    _notifyIfActive();
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
    if (kIsWeb || _disposed) return;
    try {
      final session = await audio_session.AudioSession.instance;
      if (_disposed) return;
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
    if (_disposed ||
        _focusRecoveryInFlight ||
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
      if (_disposed) return;
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
    if (_disposed) return false;
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
    if (_disposed) return false;
    if (!await _activateAudioSessionForPlayback()) return false;
    if (_disposed) return false;
    await _audio.play();
    return true;
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
