import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/client_update_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/external_links.dart';
import '../../utils/home_layout.dart';
import '../../widgets/app_scope.dart';
import '../../widgets/common_widgets.dart';

part 'settings_sections.dart';
part 'settings_components.dart';
part 'settings_dialogs.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.openDownloads,
    this.onBack,
  });

  final VoidCallback? openDownloads;
  final VoidCallback? onBack;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _clientUpdateService = ClientUpdateService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _widgetCssController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _accountSaving = false;
  bool _saved = false;
  bool _accountSaved = false;
  bool _checkingUpdate = false;
  bool _checkingClientUpdate = false;
  bool _downloadingClientUpdate = false;
  bool _showAbout = false;

  String _theme = 'system';
  HomeLayoutSettings _homeLayout = const HomeLayoutSettings();
  double _playbackSpeed = 1.0;
  bool _autoPreload = true;
  bool _autoCache = false;
  bool _ignoreAudioFocus = false;
  bool _resumeAfterInterruption = false;
  String _widgetEmbedType = 'private';
  String _backendVersion = '';
  String _clientVersion = '';
  double _clientDownloadProgress = 0;
  Map<String, dynamic>? _backendUpdate;
  ClientReleaseInfo? _clientUpdate;

  @override
  void initState() {
    super.initState();
    _usernameController.text = '';
    _load();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _widgetCssController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appState = AppScope.appOf(context);
    _usernameController.text = appState.user?.username ?? '';
    try {
      await appState.loadSettings(silent: true);
      _applySettings(appState.settings);

      try {
        _clientVersion = await _clientUpdateService.currentVersionLabel();
      } catch (_) {
        _clientVersion = 'Unknown';
      }

      try {
        final healthRes = await appState.api.get('/api/health');
        final version = asMap(healthRes.data)['version'];
        if (version != null) {
          _backendVersion = version.toString();
        }
      } catch (_) {
        // Version is nice-to-have; settings should still render if health fails.
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySettings(Map<String, dynamic> data) {
    final nested = asMap(data['settings_json'] ?? data['settingsJson']);
    _homeLayout = HomeLayoutSettings.fromSettings(data);
    final theme = _stringValue(data, 'theme', fallback: 'system');
    _theme = theme == 'auto' ? 'system' : theme;
    _playbackSpeed =
        _numValue(data, 'playback_speed', 'playbackSpeed', fallback: 1.0)
            .toDouble();
    _autoPreload = _boolValue(
      data,
      'auto_preload',
      'autoPreload',
      nested: nested,
      fallback: true,
    );
    _autoCache = _boolValue(
      data,
      'auto_cache',
      'autoCache',
      nested: nested,
      fallback: false,
    );
    _ignoreAudioFocus = _boolValue(
      data,
      'ignore_audio_focus',
      'ignoreAudioFocus',
      nested: nested,
      fallback: false,
    );
    _resumeAfterInterruption = _boolValue(
      data,
      'resume_after_interruption',
      'resumeAfterInterruption',
      nested: nested,
      fallback: false,
    );
    final widgetCss = _stringValue(
      data,
      'widget_css',
      camel: 'widgetCss',
      nested: nested,
      fallback: '',
    );
    if (_widgetCssController.text != widgetCss) {
      _widgetCssController.text = widgetCss;
    }
  }

  Future<void> _saveSettings(Map<String, dynamic> patch) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saved = false;
    });

    final appState = AppScope.appOf(context);
    final playerState = AppScope.playerOf(context);
    try {
      await appState.updateSettings(patch);
      _applySettings(appState.settings);
      if (patch.containsKey('playback_speed')) {
        await playerState.setSpeed(_playbackSpeed);
      }
      if (patch.containsKey('ignore_audio_focus') ||
          patch.containsKey('ignoreAudioFocus')) {
        await playerState.setIgnoreAudioFocus(_ignoreAudioFocus);
      }
      if (patch.containsKey('resume_after_interruption') ||
          patch.containsKey('resumeAfterInterruption')) {
        await playerState.setResumeAfterInterruption(
          _resumeAfterInterruption,
        );
      }
      if (!mounted) return;
      setState(() => _saved = true);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack('保存失败: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveLocalSettings(Map<String, dynamic> patch) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saved = false;
    });

    final appState = AppScope.appOf(context);
    final playerState = AppScope.playerOf(context);
    try {
      await appState.updateLocalSettings(patch);
      _applySettings(appState.settings);
      if (patch.containsKey('ignoreAudioFocus') ||
          patch.containsKey('ignore_audio_focus')) {
        await playerState.setIgnoreAudioFocus(_ignoreAudioFocus);
      }
      if (!mounted) return;
      setState(() => _saved = true);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack('保存失败: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveHomeLayout(HomeLayoutSettings next) async {
    setState(() => _homeLayout = next);
    await _saveSettings({'homeLayout': next.toJson()});
  }

  Future<void> _saveAccount() async {
    if (_accountSaving) return;
    final appState = AppScope.appOf(context);
    final patch = <String, dynamic>{};
    final username = _usernameController.text.trim();
    if (username.isNotEmpty && username != appState.user?.username) {
      patch['username'] = username;
    }
    if (_passwordController.text.isNotEmpty) {
      patch['password'] = _passwordController.text;
    }

    if (patch.isEmpty) {
      setState(() => _accountSaved = true);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _accountSaved = false);
      });
      return;
    }

    setState(() {
      _accountSaving = true;
      _accountSaved = false;
    });
    try {
      final res = await appState.api.patch('/api/me', data: patch);
      final user = User.fromJson(asMap(res.data));
      await appState.updateCurrentUser(user);
      _passwordController.clear();
      if (!mounted) return;
      setState(() => _accountSaved = true);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _accountSaved = false);
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack('账号更新失败: $error');
    } finally {
      if (mounted) setState(() => _accountSaving = false);
    }
  }

  Future<void> _checkBackendUpdate() async {
    if (_checkingUpdate || _backendVersion.isEmpty) return;
    setState(() => _checkingUpdate = true);
    try {
      final res =
          await AppScope.appOf(context).api.get('/api/system/check-update');
      final data = asMap(res.data);
      final remote = _stringValue(data, 'version').replaceFirst('v', '');
      final current = _backendVersion.replaceFirst('v', '');
      if (remote.isNotEmpty && remote != current) {
        setState(() => _backendUpdate = data);
      } else {
        _showSnack('服务端已是最新版本');
      }
    } catch (error) {
      _showSnack('检查服务端更新失败: $error');
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _checkClientUpdate() async {
    if (_checkingClientUpdate) return;
    setState(() => _checkingClientUpdate = true);
    try {
      final latest = await _clientUpdateService.fetchLatest();
      if (latest == null || !latest.hasDownload) {
        _showSnack('当前平台请前往官网下载客户端');
        await _clientUpdateService.openDownloadPage();
        return;
      }
      final current = await _clientUpdateService.currentVersion();
      if (_clientUpdateService.isNewer(latest.version, current)) {
        setState(() => _clientUpdate = latest);
      } else {
        _showSnack('客户端已是最新版本');
      }
    } catch (error) {
      _showSnack('检查客户端更新失败: $error');
    } finally {
      if (mounted) setState(() => _checkingClientUpdate = false);
    }
  }

  Future<void> _downloadClientUpdate() async {
    final update = _clientUpdate;
    if (update == null) return;
    if (_clientUpdateService.canInstallDirectly) {
      setState(() {
        _downloadingClientUpdate = true;
        _clientDownloadProgress = 0;
      });
    } else {
      setState(() => _clientUpdate = null);
    }
    try {
      await _clientUpdateService.openOrInstall(
        update,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _clientDownloadProgress = progress.clamp(0, 1));
        },
      );
      if (!mounted) return;
      setState(() {
        _clientUpdate = null;
        _downloadingClientUpdate = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _downloadingClientUpdate = false);
      _showSnack('下载客户端更新失败: $error');
    }
  }

  void _showSnack(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.slate900,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.only(left: 96, right: 96, bottom: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String get _clientOrigin {
    final uri = Uri.base;
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      final port = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$port';
    }
    return AppScope.appOf(context).activeUrl;
  }

  String get _widgetTokenSuffix {
    final token = AppScope.appOf(context).token;
    if (_widgetEmbedType != 'private' || token == null || token.isEmpty) {
      return '';
    }
    return '?token=$token';
  }

  String get _iframeCode {
    return '<iframe src="$_clientOrigin/widget$_widgetTokenSuffix" width="100%" height="150" frameborder="0" allow="autoplay; fullscreen"></iframe>';
  }

  String get _fixedBottomCode {
    return '<div style="position: fixed; bottom: 0; left: 0; width: 100%; z-index: 9999;">\n'
        '  $_iframeCode\n'
        '</div>';
  }

  String get _floatingCode {
    return '<div style="position: fixed; bottom: 20px; right: 20px; width: 350px; height: 150px; z-index: 9999; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.15);">\n'
        '  <iframe src="$_clientOrigin/widget$_widgetTokenSuffix" width="100%" height="100%" frameborder="0" allow="autoplay; fullscreen"></iframe>\n'
        '</div>';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final appState = AppScope.appOf(context);
    final platform = Theme.of(context).platform;
    final isMobilePlatform =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    return Stack(
      children: [
        PageListView(
          children: [
            if (widget.onBack != null) ...[
              AppBackButton(onPressed: widget.onBack!),
              const SizedBox(height: 24),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                const header = HeaderText(
                  icon: Icons.settings_rounded,
                  title: '个性化设置',
                  subtitle: '定制您的听书体验',
                );
                final saved = _SavedBadge(
                  visible: _saved,
                  label: '已保存',
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      if (_saved) ...[
                        const SizedBox(height: 12),
                        saved,
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    const Expanded(child: header),
                    saved,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _AccountSection(
              usernameController: _usernameController,
              passwordController: _passwordController,
              saving: _accountSaving,
              saved: _accountSaved,
              onSave: _saveAccount,
            ),
            const SizedBox(height: 24),
            _AppearanceSection(
              theme: _theme,
              onTheme: (value) {
                setState(() => _theme = value);
                _saveSettings({'theme': value});
              },
            ),
            const SizedBox(height: 24),
            _HomeLayoutSection(
              value: _homeLayout,
              onChanged: _saveHomeLayout,
            ),
            const SizedBox(height: 24),
            _PlaybackSection(
              playbackSpeed: _playbackSpeed,
              autoPreload: _autoPreload,
              autoCache: _autoCache,
              ignoreAudioFocus: _ignoreAudioFocus,
              resumeAfterInterruption: _resumeAfterInterruption,
              showAudioFocusSetting: isMobilePlatform,
              onSpeed: (value) {
                setState(() => _playbackSpeed = value);
                _saveSettings({'playback_speed': value});
              },
              onAutoPreload: (value) {
                setState(() => _autoPreload = value);
                _saveSettings({'auto_preload': value});
              },
              onAutoCache: (value) {
                setState(() => _autoCache = value);
                _saveSettings({'auto_cache': value});
              },
              onIgnoreAudioFocus: (value) {
                setState(() => _ignoreAudioFocus = value);
                _saveLocalSettings({'ignoreAudioFocus': value});
              },
              onResumeAfterInterruption: (value) {
                setState(() => _resumeAfterInterruption = value);
                _saveSettings({'resumeAfterInterruption': value});
              },
            ),
            if (appState.isAdmin && !isMobilePlatform) ...[
              const SizedBox(height: 24),
              _WidgetSection(
                controller: _widgetCssController,
                embedType: _widgetEmbedType,
                iframeCode: _iframeCode,
                fixedBottomCode: _fixedBottomCode,
                floatingCode: _floatingCode,
                onEmbedType: (value) =>
                    setState(() => _widgetEmbedType = value),
                onSaveCss: () => _saveSettings({
                  'widget_css': _widgetCssController.text,
                }),
                onCopy: _copy,
              ),
            ],
            const SizedBox(height: 34),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _showAbout = true),
                child: const Text(
                  '关于 Ting Reader',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Center(
              child: Text(
                '©2026 Ting Reader.保留所有权利。',
                style: TextStyle(
                  color: context.mutedText.withOpacity(0.62),
                  fontSize: 12,
                ),
              ),
            ),
            const SafeBottomSpacer(),
          ],
        ),
        if (_showAbout)
          _AboutDialog(
            backendVersion: _backendVersion,
            clientVersion: _clientVersion,
            checkingBackend: _checkingUpdate,
            checkingClient: _checkingClientUpdate,
            onClose: () => setState(() => _showAbout = false),
            onCheckBackendUpdate: _checkBackendUpdate,
            onCheckClientUpdate: _checkClientUpdate,
            onOpenWebsite: () => openExternalUrl(tingReaderWebsiteUrl),
          ),
        if (_backendUpdate != null)
          _BackendUpdateDialog(
            update: _backendUpdate!,
            onClose: () => setState(() => _backendUpdate = null),
            onOpenUpdate: () {
              final url = _stringValue(
                _backendUpdate!,
                'download_url',
                camel: 'downloadUrl',
                fallback: 'https://www.tingreader.cn/guide/update',
              );
              setState(() => _backendUpdate = null);
              openExternalUrl(url);
            },
          ),
        if (_clientUpdate != null)
          _ClientUpdateDialog(
            update: _clientUpdate!,
            actionLabel: _clientUpdateService.updateActionLabel,
            onClose: () => setState(() => _clientUpdate = null),
            onDownload: _downloadClientUpdate,
          ),
        if (_downloadingClientUpdate)
          _ClientDownloadDialog(progress: _clientDownloadProgress),
      ],
    );
  }
}
