import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/models.dart';
import '../../../core/plugin_extensions/types.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/home_layout.dart';
import '../../../core/utils/locale.dart';
import '../../../shared/app_scope.dart';
import '../../../shared/common/common_widgets.dart';
import '../../../shared/plugin_extensions/plugin_extension_host.dart';

part 'settings_sections.dart';
part 'settings_components.dart';
part 'settings_dialogs.dart';

class PersonalizationPage extends StatefulWidget {
  const PersonalizationPage({
    super.key,
    this.openDownloads,
    this.onBack,
  });

  final VoidCallback? openDownloads;
  final VoidCallback? onBack;

  @override
  State<PersonalizationPage> createState() => _PersonalizationPageState();
}

class _PersonalizationPageState extends State<PersonalizationPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _widgetCssController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _accountSaving = false;
  bool _saved = false;
  bool _accountSaved = false;

  String _theme = 'system';
  String _language = 'zh';
  HomeLayoutSettings _homeLayout = const HomeLayoutSettings();
  double _playbackSpeed = 1.0;
  bool _autoPreload = true;
  bool _autoCache = false;
  bool _ignoreAudioFocus = false;
  String _widgetEmbedType = 'private';

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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySettings(Map<String, dynamic> data) {
    final nested = asMap(data['settings_json']);
    _homeLayout = HomeLayoutSettings.fromSettings(data);
    final theme = _stringValue(data, 'theme', fallback: 'system');
    _theme = theme == 'auto' ? 'system' : theme;
    _language = normalizeLanguage(
      _stringValue(data, 'language',
          nested: nested, fallback: appStateLanguage),
    );
    _playbackSpeed =
        _numValue(data, 'playback_speed', fallback: 1.0).toDouble();
    _autoPreload = _boolValue(
      data,
      'auto_preload',
      nested: nested,
      fallback: true,
    );
    _autoCache = _boolValue(
      data,
      'auto_cache',
      nested: nested,
      fallback: false,
    );
    _ignoreAudioFocus = _boolValue(
      data,
      'ignore_audio_focus',
      nested: nested,
      fallback: false,
    );
    final widgetCss = _stringValue(
      data,
      'widget_css',
      nested: nested,
      fallback: '',
    );
    if (_widgetCssController.text != widgetCss) {
      _widgetCssController.text = widgetCss;
    }
  }

  String get appStateLanguage => AppScope.appOf(context).languageCode;

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
      if (patch.containsKey('language')) {
        await appState.setLanguage(_language, syncRemote: false);
      }
      if (patch.containsKey('playback_speed')) {
        await playerState.setSpeed(_playbackSpeed);
      }
      if (patch.containsKey('ignore_audio_focus')) {
        await playerState.setIgnoreAudioFocus(_ignoreAudioFocus);
      }
      if (!mounted) return;
      setState(() => _saved = true);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack(context.l10n.commonSaveFailed(error.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAudioFocusSettings({
    required bool ignoreAudioFocus,
  }) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saved = false;
      _ignoreAudioFocus = ignoreAudioFocus;
    });

    final appState = AppScope.appOf(context);
    final playerState = AppScope.playerOf(context);
    try {
      await appState.updateLocalSettings({
        'ignore_audio_focus': ignoreAudioFocus,
      });
      _applySettings(appState.settings);
      await playerState.setIgnoreAudioFocus(_ignoreAudioFocus);
      if (!mounted) return;
      setState(() => _saved = true);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack(context.l10n.commonSaveFailed(error.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveHomeLayout(HomeLayoutSettings next) async {
    setState(() => _homeLayout = next);
    await _saveSettings({'home_layout': next.toJson()});
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
      _showSnack(context.l10n.settingsAccountUpdateFailed(error.toString()));
    } finally {
      if (mounted) setState(() => _accountSaving = false);
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

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showSnack(context.l10n.settingsCopied);
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
    final l10n = context.l10n;
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
                final header = HeaderText(
                  icon: Icons.settings_rounded,
                  title: l10n.settingsTitle,
                  subtitle: l10n.settingsSubtitle,
                );
                final saved = _SavedBadge(
                  visible: _saved,
                  label: l10n.commonSaved,
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
                    Expanded(child: header),
                    saved,
                  ],
                );
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: PluginExtensionSlot(
                slot: ClientExtensionSlot.settingsSection,
                extensionContext: {
                  'page': 'settings',
                  'user_id': appState.user?.id,
                  'role': appState.user?.role,
                  'language': _language,
                  'theme': _theme,
                },
              ),
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
            _LanguageSection(
              language: _language,
              onLanguage: (value) {
                setState(() => _language = value);
                _saveSettings({'language': value});
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
                _saveAudioFocusSettings(ignoreAudioFocus: value);
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
            const SafeBottomSpacer(),
          ],
        ),
      ],
    );
  }
}
