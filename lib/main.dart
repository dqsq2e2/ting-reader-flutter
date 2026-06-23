import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'src/features/login/login_page.dart';
import 'src/core/state/app_state.dart';
import 'src/core/state/download_state.dart';
import 'src/core/state/player_state.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/shell/app_shell.dart';
import 'src/shared/app_scope.dart';
import 'src/shared/common/common_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _initializeNativeAudioBackend();
  await _initializeBackgroundAudio();
  await _requestNotificationPermission();

  final appState = AppState();
  final downloadState = DownloadState(appState);
  final playerState = PlayerState(appState, downloadState);

  runApp(
    AppScope(
      appState: appState,
      downloadState: downloadState,
      playerState: playerState,
      child: const TingReaderApp(),
    ),
  );
}

const _permissionsChannel = MethodChannel('ting_reader/permissions');

void _initializeNativeAudioBackend() {
  if (kIsWeb) return;
  if (defaultTargetPlatform == TargetPlatform.linux) {
    JustAudioMediaKit.ensureInitialized(linux: true, windows: false);
  }
}

Future<void> _requestNotificationPermission() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _permissionsChannel
        .invokeMethod<bool>('requestNotificationPermission');
  } catch (_) {
    // Notification permission is best-effort; playback still works in-app.
  }
}

Future<void> _initializeBackgroundAudio() async {
  if (kIsWeb) return;
  final supported = switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS =>
      true,
    _ => false,
  };
  if (!supported) return;

  await JustAudioBackground.init(
    androidNotificationChannelId: 'cn.tingreader.audio.playback',
    androidNotificationChannelName: 'Ting Reader 播放',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
    fastForwardInterval: const Duration(seconds: 15),
    rewindInterval: const Duration(seconds: 15),
  );
}

class TingReaderApp extends StatelessWidget {
  const TingReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'Ting Reader',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: appState.themeMode,
          builder: (context, child) {
            final content = child ?? const SizedBox.shrink();
            final brightness = Theme.of(context).brightness;
            final isDark = brightness == Brightness.dark;
            final background = Theme.of(context).scaffoldBackgroundColor;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness:
                    isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: background,
                systemNavigationBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarDividerColor: Colors.transparent,
              ),
              child: content,
            );
          },
          home: const StartupGate(),
        );
      },
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _started = false;
  bool _booting = true;
  bool _cancelled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final appState = AppScope.appOf(context);
    final downloadState = AppScope.downloadOf(context);
    final playerState = AppScope.playerOf(context);
    try {
      await appState.initialize(isCancelled: () => _cancelled);
      if (_cancelled) return;
      await playerState.applySettings(appState.settings);
      try {
        await downloadState.initialize();
      } catch (_) {
        // Downloads are recoverable local state; keep the app bootable.
      }
    } catch (_) {
      if (!_cancelled) {
        await appState.resetToLoginAfterStartupFailure();
      }
    } finally {
      if (mounted && !_cancelled) {
        setState(() => _booting = false);
      }
    }
  }

  Future<void> _cancelStartup() async {
    if (!_booting || _cancelled) return;
    setState(() => _cancelled = true);
    await AppScope.appOf(context).resetToLoginAfterStartupFailure();
    if (!mounted) return;
    setState(() => _booting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return StartupConnectionPage(onCancel: () {
        _cancelStartup();
      });
    }

    final appState = AppScope.appOf(context);
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return appState.isAuthenticated ? const AppShell() : const LoginPage();
      },
    );
  }
}

class StartupConnectionPage extends StatelessWidget {
  const StartupConnectionPage({super.key, required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final target = appState.activeUrl.isNotEmpty
        ? appState.activeUrl
        : (appState.localServerUrl.isNotEmpty
            ? appState.localServerUrl
            : appState.serverUrl);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ConnectionStatusCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/logo.png',
                        width: 72, height: 72),
                    const SizedBox(height: 18),
                    const Text(
                      '正在连接服务器',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      appState.resolvingRedirect
                          ? '正在检测局域网和广域网访问地址'
                          : '正在恢复登录并同步服务器数据',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? AppColors.slate800
                            : AppColors.slate50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.faintBorder),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              target,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.isDark
                                    ? AppColors.slate200
                                    : AppColors.slate700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('取消并选择服务器'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
