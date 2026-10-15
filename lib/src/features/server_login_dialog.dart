part of 'login_page.dart';

class _ServerLoginDialog extends StatefulWidget {
  const _ServerLoginDialog({this.profile, this.asPage = false});

  final SavedServerProfile? profile;
  final bool asPage;

  @override
  State<_ServerLoginDialog> createState() => _ServerLoginDialogState();
}

class _ServerLoginDialogState extends State<_ServerLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  late _ServerLoginMode _mode;
  late final TextEditingController _fnIdController;
  late final TextEditingController _serverController;
  late final TextEditingController _localServerController;
  late final TextEditingController _fnosUsernameController;
  late final TextEditingController _fnosPasswordController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool get _hasAnyLinkAddress =>
      _serverController.text.trim().isNotEmpty ||
      _localServerController.text.trim().isNotEmpty;

  bool get _modeLocked => widget.profile != null;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _mode = profile == null || profile.isFnosGateway
        ? _ServerLoginMode.fnid
        : _ServerLoginMode.link;
    _fnIdController = TextEditingController(
      text: profile != null && profile.isFnosGateway
          ? FnosGateway.fnIdLabel(profile.fnId)
          : '',
    );
    _serverController = TextEditingController(
      text: profile != null && !profile.isFnosGateway ? profile.serverUrl : '',
    );
    _localServerController =
        TextEditingController(text: profile?.localServerUrl ?? '');
    _fnosUsernameController =
        TextEditingController(text: profile?.fnosUsername ?? '');
    _fnosPasswordController =
        TextEditingController(text: profile?.fnosPassword ?? '');
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _passwordController = TextEditingController(text: profile?.password ?? '');
    _serverController.addListener(_handleWanAddressChanged);
    _localServerController.addListener(_refresh);
  }

  @override
  void dispose() {
    _fnIdController.dispose();
    _serverController
      ..removeListener(_handleWanAddressChanged)
      ..dispose();
    _localServerController
      ..removeListener(_refresh)
      ..dispose();
    _fnosUsernameController.dispose();
    _fnosPasswordController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _handleWanAddressChanged() {
    if (!_modeLocked && _mode == _ServerLoginMode.link) {
      final value = _serverController.text.trim().toLowerCase();
      final detected = value.contains('.')
          ? FnosGateway.tryGatewayHostFromInput(value)
          : null;
      if (detected != null) {
        _fnIdController.text = FnosGateway.fnIdLabel(detected);
        _mode = _ServerLoginMode.fnid;
      }
    }
    _refresh();
  }

  void _submit() {
    final currentStateValue = _formKey.currentState;
    if (currentStateValue == null || !currentStateValue.validate()) return;
    final isFnid = _mode == _ServerLoginMode.fnid;
    final gatewayHost = isFnid
        ? FnosGateway.tryGatewayHostFromInput(_fnIdController.text)
        : null;
    Navigator.pop(
      context,
      _ServerLoginDraft(
        serverUrl: isFnid
            ? _fnIdController.text.trim()
            : _serverController.text.trim(),
        localServerUrl: isFnid ? '' : _localServerController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        mode: isFnid ? ServerProfileMode.fnosGateway : ServerProfileMode.direct,
        fnId: gatewayHost ?? '',
        fnosUsername: isFnid ? _fnosUsernameController.text.trim() : '',
        fnosPassword: isFnid ? _fnosPasswordController.text : '',
        // 访问码不在编辑页展示：保留资料中已保存的值，
        // 缺失或失效时登录流程会弹出访问码输入框单独询问。
        fnAccessCode: isFnid ? (widget.profile?.fnAccessCode ?? '') : '',
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
              SegmentedButton<_ServerLoginMode>(
                segments: [
                  ButtonSegment(
                    value: _ServerLoginMode.fnid,
                    icon: const FnosLogo(width: 20, height: 16),
                    label: Text(context.localeText('FNID 登录', 'FNID Login')),
                  ),
                  ButtonSegment(
                    value: _ServerLoginMode.link,
                    icon: Icon(
                      Icons.link_rounded,
                      size: 18,
                      color: Colors.green.shade600,
                    ),
                    label: Text(context.localeText('链接登录', 'Link')),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: _modeLocked
                    ? null
                    : (selection) {
                        setState(() => _mode = selection.first);
                      },
              ),
              const SizedBox(height: 18),
              if (_mode == _ServerLoginMode.fnid) ...[
                _Field(
                  controller: _fnIdController,
                  label: context.localeText('飞牛 ID', 'FNID'),
                  hint: context.localeText(
                    '例如: fnid 或 fnid.fnos.net',
                    'e.g. fnid or fnid.fnos.net',
                  ),
                  icon: Icons.key_rounded,
                  validator: (value) => FnosGateway.tryGatewayHostFromInput(
                            value ?? '',
                          ) ==
                          null
                      ? context.localeText('请输入有效的 FNID', 'Enter a valid FNID')
                      : null,
                ),
                const SizedBox(height: 18),
                _CredentialSectionLabel(
                  context.localeText(
                    '飞牛账号（用于网关登录）',
                    'fnOS account (for gateway)',
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _fnosUsernameController,
                  label: context.localeText('用户名', 'Uername'),
                  hint: context.localeText('请输入飞牛用户名', 'Enter fnOS username'),
                  icon: Icons.person_outline_rounded,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.localeText(
                          '请输入飞牛用户名',
                          'Enter fnOS username',
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _fnosPasswordController,
                  label: context.localeText('密码', 'Password'),
                  hint: context.localeText('请输入飞牛密码', 'Enter fnOS password'),
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: (value) => value == null || value.isEmpty
                      ? context.localeText('请输入飞牛密码', 'Enter fnOS password')
                      : null,
                ),
              ] else ...[
                _Field(
                  controller: _serverController,
                  label: context.localeText('广域网地址', 'WAN address'),
                  hint: context.localeText(
                    '例如: https://reader.example.com',
                    'e.g. https://reader.example.com',
                  ),
                  icon: Icons.public_rounded,
                  validator: (_) =>
                      _hasAnyLinkAddress ? null : l10n.authRequireAnyServer,
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
                  text: _hasAnyLinkAddress
                      ? l10n.authBothAddressHint
                      : l10n.authOneAddressHint,
                ),
              ],
              const SizedBox(height: 18),
              _CredentialSectionLabel(
                context.localeText('Ting Reader 账号', 'Ting Reader account'),
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _usernameController,
                label: context.localeText('用户名', 'Username'),
                hint: l10n.authUsernameHint,
                icon: Icons.person_rounded,
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.authUsernameHint
                    : null,
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _passwordController,
                label: context.localeText('密码', 'Password'),
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

enum _ServerLoginMode { fnid, link }

class _CredentialSectionLabel extends StatelessWidget {
  const _CredentialSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: context.faintBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              color: context.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.faintBorder)),
      ],
    );
  }
}

class _ServerLoginDraft {
  const _ServerLoginDraft({
    required this.serverUrl,
    required this.localServerUrl,
    required this.username,
    required this.password,
    required this.mode,
    required this.fnId,
    required this.fnosUsername,
    required this.fnosPassword,
    this.fnAccessCode = '',
  }) : deleted = false;

  const _ServerLoginDraft.deleted()
      : serverUrl = '',
        localServerUrl = '',
        username = '',
        password = '',
        mode = ServerProfileMode.direct,
        fnId = '',
        fnosUsername = '',
        fnosPassword = '',
        fnAccessCode = '',
        deleted = true;

  final String serverUrl;
  final String localServerUrl;
  final String username;
  final String password;
  final ServerProfileMode mode;
  final String fnId;
  final String fnosUsername;
  final String fnosPassword;
  final String fnAccessCode;
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
