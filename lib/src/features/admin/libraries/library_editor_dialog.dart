part of '../admin_pages.dart';

class _LibraryEditorDialog extends StatefulWidget {
  const _LibraryEditorDialog({this.library});

  final Library? library;

  @override
  State<_LibraryEditorDialog> createState() => _LibraryEditorDialogState();
}

class _LibraryEditorDialogState extends State<_LibraryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _rootPathController;
  late final TextEditingController _scraperController;
  late String _type;
  bool _saving = false;
  bool _testingConnection = false;
  bool _scraperSourcesLoading = true;
  List<_ScraperSource> _scraperSources = [];

  bool get _editing => widget.library != null;
  bool get _isLocal => _type == 'local';

  @override
  void initState() {
    super.initState();
    final library = widget.library;
    _type = library?.libraryType == 'local' ? 'local' : 'webdav';
    _nameController = TextEditingController(text: library?.name ?? '');
    _urlController = TextEditingController(text: library?.url ?? '');
    _usernameController = TextEditingController(text: library?.username ?? '');
    _passwordController = TextEditingController();
    _rootPathController = TextEditingController(
      text: (library?.rootPath.isNotEmpty ?? false) ? library!.rootPath : '/',
    );
    _scraperController = TextEditingController(
      text: _prettyLibraryJson(library?.scraperConfig),
    );
    _loadScraperSources();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootPathController.dispose();
    _scraperController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (_urlController.text.trim().isEmpty) {
      _showMessage('请输入 WebDAV 地址');
      return;
    }

    setState(() => _testingConnection = true);
    try {
      final res = await AppScope.appOf(context).api.post(
        '/api/libraries/test-connection',
        data: {
          'url': _urlController.text.trim(),
          if (_usernameController.text.trim().isNotEmpty)
            'username': _usernameController.text.trim(),
          if (_passwordController.text.isNotEmpty)
            'password': _passwordController.text,
          'root_path': _rootPathController.text.trim().isEmpty
              ? '/'
              : _rootPathController.text.trim(),
        },
      );
      if (!mounted) return;
      final map = asMap(res.data);
      final success = map['success'] == true;
      _showMessage(
        map['message']?.toString() ?? (success ? '连接成功！' : '连接失败'),
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('请求失败，请检查 WebDAV 配置');
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  Future<void> _loadScraperSources() async {
    setState(() => _scraperSourcesLoading = true);
    try {
      final res = await AppScope.appOf(context).api.get('/api/scraper/sources');
      if (!mounted) return;
      final raw = asMap(res.data)['sources'];
      final sources =
          asMapList(raw).map(_ScraperSource.fromJson).where((source) {
        return source.autoScrape;
      }).toList();
      setState(() => _scraperSources = sources);
    } catch (_) {
      if (!mounted) return;
      _showMessage('获取刮削源失败');
    } finally {
      if (mounted) setState(() => _scraperSourcesLoading = false);
    }
  }

  Future<void> _pickFolder() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => _FolderPickerDialog(
        initialPath: _urlController.text.trim(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _urlController.text = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Object? scraperConfig;
    final scraperText = _scraperController.text.trim();
    if (scraperText.isNotEmpty) {
      try {
        scraperConfig = jsonDecode(scraperText);
      } catch (_) {
        _showMessage('刮削源配置 JSON 格式错误');
        return;
      }
    }

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'library_type': _type,
      'enabled': true,
      if (scraperConfig != null) 'scraper_config': scraperConfig,
    };

    if (_isLocal) {
      payload['path'] = _urlController.text.trim();
      payload['root_path'] = '/';
    } else {
      payload['webdav_url'] = _urlController.text.trim();
      payload['webdav_username'] = _usernameController.text.trim();
      if (_passwordController.text.isNotEmpty || !_editing) {
        payload['webdav_password'] = _passwordController.text;
      }
      payload['root_path'] = _rootPathController.text.trim().isEmpty
          ? '/'
          : _rootPathController.text.trim();
    }

    setState(() => _saving = true);
    try {
      final api = AppScope.appOf(context).api;
      if (_editing) {
        await api.patch('/api/libraries/${widget.library!.id}', data: payload);
      } else {
        await api.post('/api/libraries', data: payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      _showMessage(_editing ? '修改失败，请检查配置' : '添加失败，请检查配置');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _setType(String type) {
    if (_editing || _type == type) return;
    setState(() {
      _type = type;
      if (_type == 'webdav' && _rootPathController.text.trim().isEmpty) {
        _rootPathController.text = '/';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 26, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _editing ? '编辑存储库' : '添加存储库',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const DialogLabel('库类型', fontSize: 14),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _LibraryTypeOption(
                                label: 'WebDAV',
                                selected: !_isLocal,
                                disabled: _editing,
                                onTap: () => _setType('webdav'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LibraryTypeOption(
                                label: '本地存储',
                                selected: _isLocal,
                                disabled: _editing,
                                onTap: () => _setType('local'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const DialogLabel('库名称', fontSize: 14),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? '请输入库名称'
                                  : null,
                          decoration: const InputDecoration(
                            hintText: '例如：我的 NAS',
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_isLocal)
                          _buildLocalFields()
                        else
                          _buildWebDavFields(),
                        const SizedBox(height: 18),
                        _ScraperConfigPanel(
                          controller: _scraperController,
                          libraryType: _type,
                          sources: _scraperSources,
                          sourcesLoading: _scraperSourcesLoading,
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            color: context.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: PrimaryButton(
                        label: '保存配置',
                        icon: Icons.check_rounded,
                        loading: _saving,
                        onPressed: _saving ? null : () => _save(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebDavFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DialogLabel('WebDAV 地址', fontSize: 14),
        const SizedBox(height: 8),
        TextFormField(
          controller: _urlController,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return '请输入 WebDAV 地址';
            if (!text.startsWith('http://') && !text.startsWith('https://')) {
              return '地址需要以 http:// 或 https:// 开头';
            }
            return null;
          },
          decoration: const InputDecoration(hintText: 'https://nas.local:5006'),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;
            final username = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DialogLabel('用户名', fontSize: 14),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(hintText: '可选'),
                ),
              ],
            );
            final password = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DialogLabel('密码', fontSize: 14),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: _editing ? '不修改请留空' : '',
                  ),
                ),
              ],
            );
            if (compact) {
              return Column(
                  children: [username, const SizedBox(height: 14), password]);
            }
            return Row(
              children: [
                Expanded(child: username),
                const SizedBox(width: 14),
                Expanded(child: password),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        const DialogLabel('根目录', fontSize: 14),
        const SizedBox(height: 8),
        TextFormField(
          controller: _rootPathController,
          decoration: const InputDecoration(hintText: '/'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _testingConnection ? null : _testConnection,
            style: TextButton.styleFrom(
              backgroundColor: context.isDark
                  ? AppColors.primary700.withValues(alpha: 0.18)
                  : AppColors.primary50,
              foregroundColor: AppColors.primary600,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _testingConnection
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_rounded, size: 17),
            label: const Text(
              '测试连接',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DialogLabel('选择本地路径（相对 storage/ 目录）', fontSize: 14),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _urlController,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? '请选择或输入本地路径'
                    : null,
                decoration: const InputDecoration(hintText: '例如 audiobooks'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: '浏览目录',
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder_open_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _LibraryTypeOption extends StatelessWidget {
  const _LibraryTypeOption({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? (context.isDark
                    ? AppColors.primary700.withValues(alpha: 0.22)
                    : AppColors.primary50)
                : context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary500 : context.faintBorder,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary600 : context.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
