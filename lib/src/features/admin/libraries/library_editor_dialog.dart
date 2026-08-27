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
  bool get _isRss => _type == 'rss';
  bool get _isRemote => _type == 'webdav' || _isRss;

  @override
  void initState() {
    super.initState();
    final library = widget.library;
    _type = library?.libraryType == 'local'
        ? 'local'
        : (library?.libraryType == 'rss' ? 'rss' : 'webdav');
    _nameController = TextEditingController(text: library?.name ?? '');
    _urlController = TextEditingController(text: library?.url ?? '');
    _usernameController = TextEditingController(text: library?.username ?? '');
    _passwordController = TextEditingController();
    _rootPathController = TextEditingController(
      text: (library?.rootPath.isNotEmpty ?? false) ? library!.rootPath : '/',
    );
    _scraperController = TextEditingController(
      text: _isRss
          ? _prettyRssSyncJson(library?.scraperConfig)
          : _prettyLibraryJson(library?.scraperConfig),
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
      _showMessage(context.localeText('请输入 WebDAV 地址', 'Enter a WebDAV URL'));
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
        map['message']?.toString() ??
            (success
                ? context.localeText('连接成功！', 'Connection successful')
                : context.localeText('连接失败', 'Connection failed')),
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage(context.localeText(
          '请求失败，请检查 WebDAV 配置', 'Request failed. Check your WebDAV settings.'));
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
      _showMessage(
          context.localeText('获取刮削源失败', 'Failed to load scraper sources'));
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

    final scraperText = _scraperController.text.trim();
    Object? scraperConfig;
    if (_isRss) {
      // RSS does not run scraper plugins. Keep only the schedule settings,
      // which are stored in the legacy config column for the scheduler.
      scraperConfig = _parseRssSyncConfig(scraperText);
    } else if (scraperText.isNotEmpty) {
      try {
        scraperConfig = jsonDecode(scraperText);
      } catch (_) {
        _showMessage(context.localeText(
            '刮削源配置 JSON 格式错误', 'Scraper source config JSON is invalid'));
        return;
      }
    }
    if (_type == 'webdav' && scraperConfig is Map) {
      scraperConfig['nfo_writing_enabled'] = false;
      scraperConfig['metadata_writing_enabled'] = false;
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
    } else if (_isRss) {
      payload['rss_feed_url'] = _urlController.text.trim();
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
      _showMessage(_editing
          ? context.localeText(
              '修改失败，请检查配置', 'Update failed. Check the configuration.')
          : context.localeText(
              '添加失败，请检查配置', 'Create failed. Check the configuration.'));
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
      if (_isRss) {
        _scraperController.text = _prettyRssSyncJson(null);
      }
      if (_type == 'webdav' && _rootPathController.text.trim().isEmpty) {
        _rootPathController.text = '/';
      }
    });
  }

  Map<String, dynamic> _currentScraperConfig() {
    try {
      final decoded = jsonDecode(_scraperController.text);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return Map<String, dynamic>.from(
      _isRss ? _defaultLibrarySyncConfig : _defaultLibraryScraperConfig,
    );
  }

  void _updateScraperConfig(Map<String, dynamic> updates) {
    final config = _currentScraperConfig()..addAll(updates);
    _scraperController.text = _prettyLibraryJson(config);
    setState(() {});
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
                        _editing
                            ? context.localeText('编辑存储库', 'Edit Library')
                            : context.localeText('添加存储库', 'Add Library'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.commonClose,
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
                        DialogLabel(context.localeText('库类型', 'Library Type'),
                            fontSize: 14),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _LibraryTypeOption(
                                label: context.localeText('RSS订阅', 'RSS'),
                                selected: _isRss,
                                disabled: _editing,
                                onTap: () => _setType('rss'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LibraryTypeOption(
                                label: 'WebDAV',
                                selected: _type == 'webdav',
                                disabled: _editing,
                                onTap: () => _setType('webdav'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LibraryTypeOption(
                                label: context.localeText('本地存储', 'Local'),
                                selected: _isLocal,
                                disabled: _editing,
                                onTap: () => _setType('local'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        DialogLabel(context.localeText('库名称', 'Library Name'),
                            fontSize: 14),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? context.localeText(
                                      '请输入库名称', 'Enter a library name')
                                  : null,
                          decoration: InputDecoration(
                            hintText: context.localeText(
                                '例如：我的 NAS', 'For example: My NAS'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_isLocal)
                          _buildLocalFields()
                        else if (_isRss)
                          _buildRssFields()
                        else
                          _buildWebDavFields(),
                        if (_isRemote) ...[
                          const SizedBox(height: 18),
                          _buildScheduledSyncSettings(),
                        ],
                        if (!_isRss) ...[
                          const SizedBox(height: 18),
                          _ScraperConfigPanel(
                            controller: _scraperController,
                            libraryType: _type,
                            sources: _scraperSources,
                            sourcesLoading: _scraperSourcesLoading,
                          ),
                        ],
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
                          context.l10n.commonCancel,
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
                        label: context.localeText('保存配置', 'Save'),
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
        DialogLabel(context.localeText('WebDAV 地址', 'WebDAV URL'),
            fontSize: 14),
        const SizedBox(height: 8),
        TextFormField(
          controller: _urlController,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) {
              return context.localeText('请输入 WebDAV 地址', 'Enter a WebDAV URL');
            }
            if (!text.startsWith('http://') && !text.startsWith('https://')) {
              return context.localeText('地址需要以 http:// 或 https:// 开头',
                  'URL must start with http:// or https://');
            }
            return null;
          },
          decoration: InputDecoration(
              hintText: context.localeText(
                  'https://nas.local:5006', 'https://nas.local:5006')),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;
            final username = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DialogLabel(context.localeText('用户名', 'Username'),
                    fontSize: 14),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                      hintText: context.localeText('可选', 'Optional')),
                ),
              ],
            );
            final password = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DialogLabel(context.localeText('密码', 'Password'), fontSize: 14),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: _editing
                        ? context.localeText(
                            '不修改请留空', 'Leave blank to keep unchanged')
                        : '',
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
        DialogLabel(context.localeText('根目录', 'Root Path'), fontSize: 14),
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
            label: Text(
              context.localeText('测试连接', 'Test Connection'),
              style: const TextStyle(fontWeight: FontWeight.w700),
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
        DialogLabel(context.localeText('本地目录', 'Local Directory'),
            fontSize: 14),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _urlController,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? context.localeText(
                        '请选择或输入本地路径', 'Choose or enter a local path')
                    : null,
                decoration: InputDecoration(
                    hintText: context.localeText('输入绝对路径，或浏览授权目录',
                        'Enter an absolute path or browse authorized folders')),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: context.localeText('浏览目录', 'Browse folders'),
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder_open_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRssFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DialogLabel(context.localeText('RSS 订阅地址', 'RSS Feed URL'),
            fontSize: 14),
        const SizedBox(height: 8),
        TextFormField(
          controller: _urlController,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) {
              return context.localeText(
                  '请输入 RSS 订阅地址', 'Enter an RSS feed URL');
            }
            if (!text.startsWith('http://') && !text.startsWith('https://')) {
              return context.localeText('地址需要以 http:// 或 https:// 开头',
                  'URL must start with http:// or https://');
            }
            return null;
          },
          decoration: const InputDecoration(
            hintText: 'https://example.com/podcast/feed.xml',
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledSyncSettings() {
    final config = _currentScraperConfig();
    final enabled = config['scheduled_sync_enabled'] == true;
    final configuredInterval = config['scheduled_sync_interval']?.toString();
    const intervals = ['hourly', 'daily', 'weekly', 'monthly'];
    final interval =
        intervals.contains(configuredInterval) ? configuredInterval! : 'daily';

    String intervalLabel(String value) {
      switch (value) {
        case 'hourly':
          return context.localeText('每小时', 'Hourly');
        case 'weekly':
          return context.localeText('每周', 'Weekly');
        case 'monthly':
          return context.localeText('每月', 'Monthly');
        default:
          return context.localeText('每天', 'Daily');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.primary600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DialogLabel(
                context.localeText('定时同步', 'Scheduled Sync'),
                fontSize: 14,
              ),
            ),
            Tooltip(
              message: context.localeText(
                '按所选周期自动执行增量同步。',
                'Automatically run an incremental sync at the selected interval.',
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: AppColors.slate400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.slate800 : AppColors.slate50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.faintBorder),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: enabled,
                  activeColor: AppColors.primary600,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => _updateScraperConfig({
                    'scheduled_sync_enabled': value ?? false,
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: interval,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(10),
                    onChanged: enabled
                        ? (value) {
                            if (value != null) {
                              _updateScraperConfig({
                                'scheduled_sync_interval': value,
                              });
                            }
                          }
                        : null,
                    items: [
                      for (final value in intervals)
                        DropdownMenuItem(
                          value: value,
                          child: Text(intervalLabel(value)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
