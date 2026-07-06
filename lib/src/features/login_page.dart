import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/state/app_state.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/external_links.dart';
import '../core/utils/locale.dart';
import '../shared/app_scope.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  String? _error;
  String? _loginStage;

  Future<void> _loginWithProfile(SavedServerProfile profile) async {
    await _login(
      server: profile.serverUrl,
      localServer: profile.localServerUrl,
      username: profile.username,
      password: profile.password,
      replaceProfile: profile,
    );
  }

  Future<void> _login({
    required String server,
    required String localServer,
    required String username,
    required String password,
    SavedServerProfile? replaceProfile,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
      _loginStage = context.l10n.startupConnecting;
    });

    try {
      await AppScope.appOf(context).login(
        server: server,
        localServer: localServer,
        username: username,
        password: password,
        replaceProfile: replaceProfile,
      );
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _error = _loginErrorMessage(error));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _loginErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loginStage = null;
        });
      }
    }
  }

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
    await _login(
      server: result.serverUrl,
      localServer: result.localServerUrl,
      username: result.username,
      password: result.password,
      replaceProfile: profile,
    );
  }

  Future<void> _offlineLogin() async {
    await AppScope.appOf(context).enterOfflineMode();
  }

  String _loginErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      final status = error.response?.statusCode;
      final uri = error.requestOptions.uri.toString();
      final parts = <String>[
        context.l10n.authLoginFailed,
        if (status != null) 'HTTP $status',
        if (error.message != null && error.message!.isNotEmpty) error.message!,
        uri,
      ];
      return parts.join('：');
    }
    final text = error.toString().replaceFirst('Bad state: ', '');
    return text.isEmpty ? context.l10n.authLoginFailedFallback : text;
  }

  @override
  Widget build(BuildContext context) {
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
                    const _LoginBrand(),
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
                            loading: _loading,
                            onLogin: () => _loginWithProfile(profile),
                            onEdit: () => _openServerDialog(profile),
                          ),
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBox(message: _error!),
                    ],
                    if (_loginStage != null) ...[
                      const SizedBox(height: 8),
                      _InfoBox(
                        icon: Icons.sync_rounded,
                        text: _loginStage!,
                        spinning: true,
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

class _LoginBrand extends StatelessWidget {
  const _LoginBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/images/logo.png', width: 74, height: 74),
        const SizedBox(height: 14),
        const Text(
          'Ting Reader',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.authTagline,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedText),
        ),
      ],
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          context.localeText('登录即表示您已阅读并同意', 'By signing in, you agree to'),
          style: TextStyle(color: context.mutedText, fontSize: 12),
        ),
        _LegalLink(
          label: context.localeText('用户协议', 'User Agreement'),
          url: userAgreementUrl,
        ),
        Text(
          context.localeText('和', 'and'),
          style: TextStyle(color: context.mutedText, fontSize: 12),
        ),
        _LegalLink(
          label: context.localeText('隐私协议', 'Privacy Policy'),
          url: privacyPolicyUrl,
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openExternalUrl(url),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary600,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary600,
          ),
        ),
      ),
    );
  }
}

class _EmptyServerCard extends StatelessWidget {
  const _EmptyServerCard({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.dns_rounded, size: 30, color: context.mutedText),
          const SizedBox(height: 10),
          Text(
            context.l10n.authNoServer,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.authNoServerDescription,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(context.l10n.authAddServer),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerProfileCard extends StatelessWidget {
  const _ServerProfileCard({
    required this.profile,
    required this.loading,
    required this.onLogin,
    required this.onEdit,
  });

  final SavedServerProfile profile;
  final bool loading;
  final VoidCallback onLogin;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.isDark ? AppColors.slate800 : AppColors.slate50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onLogin,
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
                child: const Icon(
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
                    Text(
                      profile.label.isNotEmpty
                          ? profile.label
                          : (profile.username.isEmpty
                              ? context.l10n.authUnnamedServer
                              : profile.username),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
                onPressed: loading ? null : onEdit,
                icon: const Icon(Icons.edit_rounded, size: 20),
              ),
              if (loading)
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

class _ServerLoginDialog extends StatefulWidget {
  const _ServerLoginDialog({this.profile, this.asPage = false});

  final SavedServerProfile? profile;
  final bool asPage;

  @override
  State<_ServerLoginDialog> createState() => _ServerLoginDialogState();
}

class _ServerLoginDialogState extends State<_ServerLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serverController;
  late final TextEditingController _localServerController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool get _hasAnyServerAddress =>
      _serverController.text.trim().isNotEmpty ||
      _localServerController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _serverController = TextEditingController(text: profile?.serverUrl ?? '');
    _localServerController =
        TextEditingController(text: profile?.localServerUrl ?? '');
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _passwordController = TextEditingController(text: profile?.password ?? '');
    _serverController.addListener(_refresh);
    _localServerController.addListener(_refresh);
  }

  @override
  void dispose() {
    _serverController
      ..removeListener(_refresh)
      ..dispose();
    _localServerController
      ..removeListener(_refresh)
      ..dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ServerLoginDraft(
        serverUrl: _serverController.text.trim(),
        localServerUrl: _localServerController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  void _delete() {
    Navigator.pop(context, const _ServerLoginDraft.deleted());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: widget.asPage ? Border.all(color: context.faintBorder) : null,
          boxShadow: widget.asPage
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: context.isDark ? 0.24 : 0.08,
                    ),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ]
              : null,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.profile == null
                          ? l10n.authAddServer
                          : l10n.authEditServer,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: widget.asPage ? l10n.authBack : l10n.commonClose,
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      widget.asPage
                          ? Icons.arrow_back_rounded
                          : Icons.close_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _serverController,
                label: l10n.authWanAddress,
                hint: l10n.authWanHint,
                icon: Icons.public_rounded,
                validator: (_) =>
                    _hasAnyServerAddress ? null : l10n.authRequireAnyServer,
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _localServerController,
                label: l10n.authLanAddress,
                hint: l10n.authLanHint,
                icon: Icons.router_rounded,
              ),
              const SizedBox(height: 12),
              _InfoBox(
                icon: Icons.info_outline_rounded,
                text: _hasAnyServerAddress
                    ? l10n.authBothAddressHint
                    : l10n.authOneAddressHint,
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _usernameController,
                label: l10n.settingsUsername,
                hint: l10n.authUsernameHint,
                icon: Icons.person_rounded,
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.authUsernameHint
                    : null,
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _passwordController,
                label: l10n.authPassword,
                hint: l10n.authPasswordHint,
                icon: Icons.lock_rounded,
                obscureText: true,
                onSubmitted: (_) => _submit(),
                validator: (value) => value == null || value.isEmpty
                    ? l10n.authPasswordHint
                    : null,
              ),
              const SizedBox(height: 20),
              _ServerLoginActions(
                canDelete: widget.profile != null,
                onCancel: () => Navigator.pop(context),
                onDelete: _delete,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.asPage) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SingleChildScrollView(child: content),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _ServerLoginDraft {
  const _ServerLoginDraft({
    required this.serverUrl,
    required this.localServerUrl,
    required this.username,
    required this.password,
  }) : deleted = false;

  const _ServerLoginDraft.deleted()
      : serverUrl = '',
        localServerUrl = '',
        username = '',
        password = '',
        deleted = true;

  final String serverUrl;
  final String localServerUrl;
  final String username;
  final String password;
  final bool deleted;
}

class _ServerLoginActions extends StatelessWidget {
  const _ServerLoginActions({
    required this.canDelete,
    required this.onCancel,
    required this.onDelete,
    required this.onSubmit,
  });

  final bool canDelete;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final deleteButton = TextButton.icon(
      onPressed: canDelete ? onDelete : null,
      style: TextButton.styleFrom(
        foregroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      label: Text(l10n.commonDelete),
    );
    final cancelButton = TextButton(
      onPressed: onCancel,
      child: Text(l10n.commonCancel),
    );
    final saveButton = ElevatedButton.icon(
      onPressed: onSubmit,
      icon: const Icon(Icons.login_rounded, size: 18),
      label: Text(l10n.authSaveAndLogin),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final actions = Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            if (compact && canDelete) deleteButton,
            cancelButton,
            saveButton,
          ],
        );
        if (compact || !canDelete) {
          return Align(alignment: Alignment.centerRight, child: actions);
        }
        return Row(
          children: [
            deleteButton,
            const Spacer(),
            actions,
          ],
        );
      },
    );
  }
}

String _serverProfileSubtitle(
    BuildContext context, SavedServerProfile profile) {
  final l10n = context.l10n;
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

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.text,
    this.spinning = false,
  });

  final IconData icon;
  final String text;
  final bool spinning;

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
