import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/auth/fn_connect_client.dart';
import '../core/auth/fnos_gateway_auth.dart';
import '../core/api/api_error.dart';
import '../core/state/app_state.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/external_links.dart';
import '../core/utils/locale.dart';
import '../shared/app_scope.dart';
import '../shared/fnos_logo.dart';

part 'login_presentation.dart';

part 'login_prompts.dart';

part 'server_login_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  String? _error;
  String? _loginStage;
  String? _activeProfileKey;
  CancelToken? _loginCancelToken;
  int _loginAttempt = 0;
  bool _automaticGatewayLoginStarted = false;
  bool _languageChanged = false;
  bool _themeChanged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutomaticGatewayLogin();
    });
  }

  @override
  void dispose() {
    _loginAttempt++;
    _loginCancelToken?.cancel('Login page closed');
    super.dispose();
  }

  Future<void> _tryAutomaticGatewayLogin() async {
    if (!mounted || _automaticGatewayLoginStarted) return;
    final appState = AppScope.appOf(context);
    if (appState.gatewayStartupLoginAttempted) return;
    if (!appState.needsGatewayLogin) return;
    final profile = appState.savedGatewayProfile;
    if (profile == null) return;
    _automaticGatewayLoginStarted = true;
    // The marker is set only after the cached gateway session has failed
    // validation. Do not send that same stale cookie once more; go straight
    // into the fnOS login flow and obtain a fresh session.
    await _loginWithProfile(
      appState.needsGatewayLogin
          ? profile.copyWith(gatewayCookie: '')
          : profile,
    );
  }

  Future<void> _loginWithProfile(
    SavedServerProfile profile, {
    String? fnAccessCode,
  }) async {
    await _login(
      server: profile.serverUrl,
      localServer: profile.localServerUrl,
      username: profile.username,
      password: profile.password,
      mode: profile.mode,
      fnId: profile.fnId,
      fnosUsername: profile.fnosUsername,
      fnosPassword: profile.fnosPassword,
      gatewayCookie: profile.gatewayCookie,
      fnAccessCode: fnAccessCode ??
          (profile.fnAccessCode.isNotEmpty ? profile.fnAccessCode : null),
      activeProfile: profile,
      replaceProfile: profile,
    );
  }

  Future<void> _login({
    required String server,
    required String localServer,
    required String username,
    required String password,
    ServerProfileMode mode = ServerProfileMode.direct,
    String fnId = '',
    String fnosUsername = '',
    String fnosPassword = '',
    String gatewayCookie = '',
    String? fnAccessCode,
    SavedServerProfile? activeProfile,
    SavedServerProfile? replaceProfile,
  }) async {
    _loginCancelToken?.cancel('Login attempt replaced');
    final attempt = ++_loginAttempt;
    final cancelToken = CancelToken();
    _loginCancelToken = cancelToken;
    setState(() {
      _loading = true;
      _error = null;
      _loginStage = context.l10n.startupConnecting;
      _activeProfileKey =
          activeProfile == null ? null : _serverProfileKey(activeProfile);
    });

    try {
      final appState = AppScope.appOf(context);
      final loginSettingsPatch = <String, dynamic>{
        if (_languageChanged) 'language': appState.languageCode,
        if (_themeChanged) 'theme': appState.theme,
      };
      await appState.loginWithPrompts(
        SavedServerProfile(
          serverUrl: server,
          localServerUrl: localServer,
          activeUrl: server,
          username: username,
          password: password,
          label: '',
          mode: mode,
          fnId: fnId,
          fnosUsername: fnosUsername,
          fnosPassword: fnosPassword,
          gatewayCookie: gatewayCookie,
          fnAccessCode: fnAccessCode ?? '',
        ),
        requestAccessCode: (incorrect) async {
          if (!mounted || cancelToken.isCancelled || attempt != _loginAttempt) {
            return null;
          }
          return _promptAccessCode(errorHint: incorrect);
        },
        requestTwofa: () async {
          if (!mounted || cancelToken.isCancelled || attempt != _loginAttempt) {
            return null;
          }
          if (mounted && !cancelToken.isCancelled && attempt == _loginAttempt) {
            setState(() {
              _loginStage = context.localeText(
                '需要二步验证',
                'Two-step verification required',
              );
            });
          }
          final answer = await _promptTwofaAnswer();
          if (mounted && !cancelToken.isCancelled && attempt == _loginAttempt) {
            setState(() {
              _loginStage = context.l10n.startupConnecting;
            });
          }
          return answer;
        },
        onStage: (stage) {
          if (!mounted || cancelToken.isCancelled || attempt != _loginAttempt) {
            return;
          }
          setState(() {
            _loginStage = switch (stage) {
              FnConnectStage.resolving => context.localeText(
                  '正在解析飞牛服务地址…',
                  'Resolving fnOS service…',
                ),
              FnConnectStage.signingIn => context.localeText(
                  '正在登录飞牛账号…',
                  'Signing in to fnOS…',
                ),
              FnConnectStage.probing => context.localeText(
                  '正在选择最快连接…',
                  'Selecting the best connection…',
                ),
              FnConnectStage.tingReaderLogin => context.localeText(
                  '正在登录 Ting Reader…',
                  'Signing in to Ting Reader…',
                ),
            };
          });
        },
        replaceProfile: replaceProfile,
        settingsPatch: loginSettingsPatch,
        cancelToken: cancelToken,
      );
    } on FnConnectTwofaSetupRequiredException {
      if (cancelToken.isCancelled || !mounted) return;
      setState(() {
        _error = context.localeText(
          '该飞牛账号被管理员要求启用双重验证，请先在飞牛网页端「个人设置 → 双重验证」完成绑定后再登录',
          'This fnOS account must set up two-factor authentication first. Complete it in the fnOS web settings, then sign in',
        );
      });
    } on FnConnectTwofaCancelledException {
      if (cancelToken.isCancelled || !mounted) return;
      // 用户主动取消二步验证：不显示错误，回到可重试状态。
    } on FnConnectTwofaRequiredException {
      if (cancelToken.isCancelled || !mounted) return;
      setState(() {
        _error = context.localeText(
          '飞牛账号已开启二步验证，请重新登录并输入动态验证码',
          'Two-step verification is enabled. Sign in again and enter the one-time code',
        );
      });
    } on DioException catch (error) {
      if (cancelToken.isCancelled || CancelToken.isCancel(error)) return;
      if (!mounted) return;
      setState(() => _error = _loginErrorMessage(error));
    } catch (error) {
      if (cancelToken.isCancelled) return;
      if (!mounted) return;
      setState(() => _error = _loginErrorMessage(error));
    } finally {
      if (identical(_loginCancelToken, cancelToken)) {
        _loginCancelToken = null;
      }
      if (mounted && attempt == _loginAttempt) {
        setState(() {
          _loading = false;
          _loginStage = null;
          _activeProfileKey = null;
        });
      }
    }
  }

  void _cancelLogin() {
    final cancelToken = _loginCancelToken;
    if (cancelToken == null || cancelToken.isCancelled) return;
    ++_loginAttempt;
    cancelToken.cancel(context.l10n.commonCancel);
    _loginCancelToken = null;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loginStage = null;
      _activeProfileKey = null;
    });
  }

  /// 二步验证（OTP）输入弹窗：飞牛账号开启双重验证后，
  /// `user.login` 只返回挑战，需要用户补一次 6 位动态验证码。
  Future<FnTwofaAnswer?> _promptTwofaAnswer() {
    var trustDevice = false;
    return _showCredentialPrompt<FnTwofaAnswer>(
      builder: (dialogContext, codeController) {
        void confirm() {
          final code = codeController.text.trim();
          if (code.isEmpty) return;
          Navigator.of(dialogContext).pop(
            FnTwofaAnswer(code: code, trustDevice: trustDevice),
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _GatewayAuthPromptDialog(
              icon: Icons.phonelink_lock_rounded,
              title: context.localeText('二步验证', 'Two-step verification'),
              description: context.localeText(
                '该飞牛账号已开启双重验证，请输入身份验证器上的 6 位动态验证码。',
                'This fnOS account has two-factor authentication enabled. Enter the 6-digit code from your authenticator.',
              ),
              fieldLabel: context.localeText('动态验证码', 'One-time code'),
              fieldHint: context.localeText(
                '请输入 6 位动态验证码',
                'Enter the 6-digit code',
              ),
              fieldIcon: Icons.pin_outlined,
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              confirmLabel: context.localeText('验证', 'Verify'),
              onConfirm: confirm,
              belowField: CheckboxListTile(
                value: trustDevice,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary600,
                checkboxShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                title: Text(
                  context.localeText('信任本设备', 'Trust this device'),
                  style: const TextStyle(fontSize: 14),
                ),
                onChanged: (value) {
                  setDialogState(() => trustDevice = value ?? false);
                },
              ),
            );
          },
        );
      },
    );
  }

  /// 访问码输入弹窗（服务器开启访问码但本地未保存/保存错误时弹出）。
  Future<String?> _promptAccessCode({bool errorHint = false}) {
    var obscure = true;
    return _showCredentialPrompt<String>(
      builder: (dialogContext, codeController) {
        void confirm() {
          final code = codeController.text.trim();
          if (code.isEmpty) return;
          Navigator.of(dialogContext).pop(code);
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _GatewayAuthPromptDialog(
              icon: Icons.verified_user_outlined,
              title: context.localeText('输入访问码', 'Enter access code'),
              description: errorHint
                  ? context.localeText(
                      '访问码错误，请重新输入服务器访问码。',
                      'Incorrect access code. Enter the server access code again.',
                    )
                  : context.localeText(
                      '该服务器已开启访问码保护，请输入访问码后继续登录。',
                      'This server is protected by an access code. Enter it to continue signing in.',
                    ),
              descriptionIsError: errorHint,
              fieldLabel: context.localeText('访问码', 'Access code'),
              fieldHint: context.localeText(
                '请输入服务器访问码',
                'Enter the server access code',
              ),
              fieldIcon: Icons.key_rounded,
              controller: codeController,
              obscureText: obscure,
              fieldSuffix: IconButton(
                onPressed: () => setDialogState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.slate400,
                ),
                splashRadius: 18,
              ),
              confirmLabel: context.localeText('继续', 'Continue'),
              onConfirm: confirm,
            );
          },
        );
      },
    );
  }

  Future<T?> _showCredentialPrompt<T>({
    required Widget Function(BuildContext, TextEditingController) builder,
  }) =>
      showDialog<T>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _CredentialPrompt(builder: builder),
      );

  Future<void> _openServerDialog([SavedServerProfile? profile]) async {
    final result = await Navigator.of(context).push<_ServerLoginDraft>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _ServerLoginDialog(
          profile: profile,
          asPage: true,
        ),
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    if (result.deleted) {
      if (profile != null) {
        await AppScope.appOf(context).deleteSavedServerProfile(profile);
      }
      return;
    }
    final appState = AppScope.appOf(context);
    final rememberedProfile = await appState.rememberServerProfile(
      server: result.serverUrl,
      localServer: result.localServerUrl,
      username: result.username,
      password: result.password,
      mode: result.mode,
      fnId: result.fnId,
      fnosUsername: result.fnosUsername,
      fnosPassword: result.fnosPassword,
      fnAccessCode: result.fnAccessCode,
      replaceProfile: profile,
    );
    if (!mounted) return;
    await _login(
      server: rememberedProfile.serverUrl,
      localServer: rememberedProfile.localServerUrl,
      username: rememberedProfile.username,
      password: rememberedProfile.password,
      mode: rememberedProfile.mode,
      fnId: rememberedProfile.fnId,
      fnosUsername: rememberedProfile.fnosUsername,
      fnosPassword: rememberedProfile.fnosPassword,
      fnAccessCode: rememberedProfile.fnAccessCode,
      activeProfile: rememberedProfile,
      replaceProfile: profile,
    );
  }

  Future<void> _offlineLogin() async {
    await AppScope.appOf(context).enterOfflineMode();
  }

  Future<void> _changeLanguage(String value) async {
    setState(() => _languageChanged = true);
    await AppScope.appOf(context).setLanguage(value, syncRemote: false);
  }

  Future<void> _changeTheme(String value) async {
    setState(() => _themeChanged = true);
    await AppScope.appOf(context).setTheme(value, syncRemote: false);
  }

  String _loginErrorMessage(Object error) {
    return ApiError.messageFor(error, fallback: context.l10n.authLoginFailed);
  }

  @override
  Widget build(BuildContext context) {
    final loginStageValue = _loginStage;
    final errorValue = _error;
    final appState = AppScope.appOf(context);
    final profiles = appState.savedServers;
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.faintBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: context.isDark ? 0.24 : 0.08,
                      ),
                      blurRadius: 30,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        const _LoginBrand(),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: _LoginPreferencesBar(
                            language: appState.languageCode,
                            theme: appState.theme,
                            enabled: !_loading,
                            onLanguage: _changeLanguage,
                            onTheme: _changeTheme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.authServers,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed:
                              _loading ? null : () => _openServerDialog(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(l10n.authAdd),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (profiles.isEmpty)
                      _EmptyServerCard(
                        onAdd: _loading ? null : () => _openServerDialog(),
                      )
                    else
                      ...profiles.map(
                        (profile) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ServerProfileCard(
                            profile: profile,
                            busy: _loading,
                            connecting: _loading &&
                                _serverProfileKey(profile) == _activeProfileKey,
                            onLogin: () => _loginWithProfile(profile),
                            onEdit: () => _openServerDialog(profile),
                          ),
                        ),
                      ),
                    if (errorValue != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBox(message: errorValue),
                    ],
                    if (loginStageValue != null) ...[
                      const SizedBox(height: 8),
                      _InfoBox(
                        icon: Icons.sync_rounded,
                        text: loginStageValue,
                        spinning: true,
                        onCancel: _loading ? _cancelLogin : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _offlineLogin,
                      icon: const Icon(Icons.cloud_off_rounded, size: 18),
                      label: Text(l10n.authOfflineLogin),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _LegalLinks(),
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

String _serverProfileKey(SavedServerProfile profile) {
  final local = profile.localServerUrl.trim().toLowerCase();
  final username = profile.username.trim().toLowerCase();
  final gatewayHost = FnosGateway.tryGatewayHostFromInput(profile.fnId) ??
      FnosGateway.tryGatewayHostFromInput(profile.serverUrl);
  if (gatewayHost != null) {
    final label = FnosGateway.fnIdLabel(gatewayHost);
    return 'gateway|$label|$local|$username';
  }
  return 'direct|${profile.serverUrl.trim().toLowerCase()}|$local|$username';
}

class _ServerProfileCard extends StatelessWidget {
  const _ServerProfileCard({
    required this.profile,
    required this.busy,
    required this.connecting,
    required this.onLogin,
    required this.onEdit,
  });

  final SavedServerProfile profile;
  final bool busy;
  final bool connecting;
  final VoidCallback onLogin;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.isDark ? AppColors.slate800 : AppColors.slate50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: busy ? null : onLogin,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.faintBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: profile.isFnosGateway
                    ? const Center(
                        child: FnosLogo(width: 27, height: 22),
                      )
                    : const Icon(
                        Icons.dns_rounded,
                        color: AppColors.primary700,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.username.isNotEmpty
                                ? profile.username
                                : profile.label.isNotEmpty
                                    ? profile.label
                                    : context.l10n.authUnnamedServer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: profile.isFnosGateway
                                ? Colors.teal.withValues(alpha: 0.1)
                                : context.isDark
                                    ? AppColors.slate600
                                    : AppColors.slate200.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            profile.isFnosGateway
                                ? context.localeText('飞牛服务', 'fnOS')
                                : context.localeText('直连', 'Direct'),
                            style: TextStyle(
                              color: profile.isFnosGateway
                                  ? Colors.teal.shade700
                                  : context.isDark
                                      ? AppColors.slate50
                                      : AppColors.slate700,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _serverProfileSubtitle(context, profile),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.l10n.authEdit,
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_rounded, size: 20),
              ),
              if (connecting)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

String _serverProfileSubtitle(
    BuildContext context, SavedServerProfile profile) {
  final l10n = context.l10n;
  if (profile.isFnosGateway) {
    final parts = <String>[
      context.localeText('飞牛服务', 'fnOS service'),
      if (profile.fnId.isNotEmpty) profile.fnId,
      if (profile.username.isNotEmpty) profile.username,
    ];
    return parts.join(' · ');
  }
  final parts = <String>[
    if (profile.localServerUrl.isNotEmpty)
      l10n.authLanPrefix(profile.localServerUrl),
    if (profile.serverUrl.isNotEmpty) l10n.authWanPrefix(profile.serverUrl),
    if (profile.username.isNotEmpty) profile.username,
  ];
  return parts.isEmpty ? l10n.authNoSavedAddress : parts.join(' · ');
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.16)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red, height: 1.35),
      ),
    );
  }
}

/// 网关登录过程中的询问弹窗（二步验证 / 访问码）。
/// 视觉语言与服务器登录卡片保持一致：卡片底色、18px 圆角、
/// 主色图标徽章、InfoBox 风格说明条、主题输入框与主色按钮。
/// The route owns the controller until its closing animation removes the form.
class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.text,
    this.spinning = false,
    this.onCancel,
  });

  final IconData icon;
  final String text;
  final bool spinning;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final iconWidget = spinning
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 16, color: AppColors.primary600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.primary600.withValues(alpha: 0.12)
            : AppColors.primary50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.isDark
              ? AppColors.primary600.withValues(alpha: 0.24)
              : AppColors.primary100,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: iconWidget,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.isDark ? AppColors.slate300 : AppColors.slate600,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          if (onCancel != null) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(context.l10n.commonCancel),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.obscureText = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: context.isDark ? AppColors.slate300 : AppColors.slate700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.slate400, size: 20),
          ),
        ),
      ],
    );
  }
}
