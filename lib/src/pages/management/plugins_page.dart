part of 'management_pages.dart';

class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key});

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

enum _PluginTab { store, installed, updates }

class _PluginsPageState extends State<PluginsPage> {
  bool _installedLoading = true;
  bool _storeLoading = false;
  List<PluginItem> _installed = [];
  List<PluginItem> _store = [];
  _PluginTab _tab = _PluginTab.store;
  String _category = 'all';
  String _query = '';
  String? _installingId;
  bool _uploadingPlugin = false;
  final Set<String> _expandedDescriptions = {};

  @override
  void initState() {
    super.initState();
    _loadInstalled();
    _loadStore();
  }

  Future<void> _loadInstalled() async {
    setState(() => _installedLoading = true);
    try {
      final res = await AppScope.appOf(context).api.get('/api/v1/plugins');
      if (!mounted) return;
      setState(() {
        _installed = asMapList(res.data).map(PluginItem.fromJson).toList();
      });
    } finally {
      if (mounted) setState(() => _installedLoading = false);
    }
  }

  Future<void> _loadStore({bool clearCache = false}) async {
    setState(() => _storeLoading = true);
    try {
      final api = AppScope.appOf(context).api;
      if (clearCache) await api.post('/api/v1/store/cache/clear');
      final res = await api.get('/api/v1/store/plugins');
      if (!mounted) return;
      setState(() {
        _store = asMapList(res.data).map(PluginItem.fromJson).toList();
      });
    } finally {
      if (mounted) setState(() => _storeLoading = false);
    }
  }

  Future<void> _refresh() {
    if (_tab == _PluginTab.installed) return _loadInstalled();
    return _loadStore(clearCache: true);
  }

  Future<void> _reload(String id) async {
    await AppScope.appOf(context).api.post('/api/v1/plugins/$id/reload');
    if (!mounted) return;
    _showSnack('Plugin reloaded successfully!');
    await _loadInstalled();
  }

  Future<void> _install(PluginItem item) async {
    setState(() => _installingId = item.id);
    try {
      await AppScope.appOf(context).api.post(
        '/api/v1/store/install',
        data: {'plugin_id': item.id, 'pluginId': item.id},
      );
      if (!mounted) return;
      _showSnack('Plugin installed successfully!');
      await Future.wait([_loadInstalled(), _loadStore()]);
    } catch (_) {
      if (mounted) _showSnack('安装插件失败');
    } finally {
      if (mounted) setState(() => _installingId = null);
    }
  }

  Future<void> _uploadPlugin() async {
    if (_uploadingPlugin) return;
    final api = AppScope.appOf(context).api;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (!mounted) return;
    final file = picked?.files.single;
    final path = file?.path;
    final bytes = file?.bytes;
    if (file == null || (path == null && bytes == null)) return;

    setState(() => _uploadingPlugin = true);
    try {
      final uploadFile = path != null
          ? await MultipartFile.fromFile(path, filename: file.name)
          : MultipartFile.fromBytes(bytes!, filename: file.name);
      final formData = FormData.fromMap({
        'file': uploadFile,
      });
      await api.post('/api/v1/plugins/install', data: formData);
      if (!mounted) return;
      _showSnack('Plugin installed successfully!');
      await Future.wait([_loadInstalled(), _loadStore()]);
    } catch (_) {
      if (mounted) _showSnack('安装插件失败');
    } finally {
      if (mounted) setState(() => _uploadingPlugin = false);
    }
  }

  Future<void> _delete(PluginItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('卸载插件？'),
        content: Text('确定要卸载 ${item.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('卸载'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await AppScope.appOf(context).api.delete('/api/v1/plugins/${item.id}');
    if (!mounted) return;
    _showSnack('Plugin uninstalled successfully!');
    await _loadInstalled();
  }

  Future<void> _configure(PluginItem item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _PluginConfigDialog(plugin: item),
    );
    if (saved == true) await _loadInstalled();
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _toggleDescription(String id) {
    setState(() {
      if (_expandedDescriptions.contains(id)) {
        _expandedDescriptions.remove(id);
      } else {
        _expandedDescriptions.add(id);
      }
    });
  }

  String? _installedVersion(String pluginId) {
    final exact = _installed.where((item) => item.id == pluginId);
    if (exact.isNotEmpty) return exact.first.version;
    final base = _basePluginId(pluginId);
    final baseMatch =
        _installed.where((item) => _basePluginId(item.id) == base);
    if (baseMatch.isNotEmpty) return baseMatch.first.version;
    return null;
  }

  bool _hasUpdate(PluginItem item) {
    final installed = _installedVersion(item.id);
    if (installed == null) return false;
    return _comparePluginVersions(item.version, installed) > 0;
  }

  bool _matches(PluginItem item) {
    if (_category != 'all' && item.pluginType != _category) return false;
    if (_query.trim().isEmpty) return true;
    final query = _query.trim().toLowerCase();
    final haystack = '${item.name} ${item.description ?? ''} '
            '${item.longDescription ?? ''} ${item.author ?? ''}'
        .toLowerCase();
    return haystack.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final updateCount = _store.where(_hasUpdate).length;
    final installedItems = _installed.where(_matches).toList();
    final storeItems = _store
        .where((item) {
          if (_tab == _PluginTab.store && _installedVersion(item.id) != null) {
            return false;
          }
          if (_tab == _PluginTab.updates && !_hasUpdate(item)) return false;
          return true;
        })
        .where(_matches)
        .toList();
    final activeItems =
        _tab == _PluginTab.installed ? installedItems : storeItems;
    final activeLoading =
        _tab == _PluginTab.installed ? _installedLoading : _storeLoading;

    return PageListView(
      onRefresh: _refresh,
      children: [
        _PluginTopBar(
          tab: _tab,
          installedCount: _installed.length,
          updateCount: updateCount,
          refreshing: activeLoading,
          uploading: _uploadingPlugin,
          onTabChanged: (tab) {
            setState(() => _tab = tab);
            if (tab != _PluginTab.installed && _store.isEmpty) _loadStore();
          },
          onRefresh: _refresh,
          onUpload: _uploadPlugin,
        ),
        const SizedBox(height: 16),
        _PluginFilterBar(
          category: _category,
          query: _query,
          onCategoryChanged: (value) => setState(() => _category = value),
          onQueryChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        if (activeLoading)
          const SizedBox(height: 220, child: LoadingView(label: '加载插件中...'))
        else if (activeItems.isEmpty)
          _PluginEmptyState(tab: _tab)
        else
          _PluginGrid(
            items: activeItems,
            tab: _tab,
            installingId: _installingId,
            expandedDescriptions: _expandedDescriptions,
            installedVersionFor: _installedVersion,
            hasUpdate: _hasUpdate,
            onToggleDescription: _toggleDescription,
            onInstall: _install,
            onReload: _reload,
            onDelete: _delete,
            onConfigure: _configure,
          ),
        const SafeBottomSpacer(),
      ],
    );
  }
}

class _PluginTopBar extends StatelessWidget {
  const _PluginTopBar({
    required this.tab,
    required this.installedCount,
    required this.updateCount,
    required this.refreshing,
    required this.uploading,
    required this.onTabChanged,
    required this.onRefresh,
    required this.onUpload,
  });

  final _PluginTab tab;
  final int installedCount;
  final int updateCount;
  final bool refreshing;
  final bool uploading;
  final ValueChanged<_PluginTab> onTabChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onUpload;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabs = Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.slate800 : AppColors.slate100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PluginTabButton(
                label: '全部',
                selected: tab == _PluginTab.store,
                onTap: () => onTabChanged(_PluginTab.store),
              ),
              _PluginTabButton(
                label: '已安装',
                count: installedCount == 0 ? null : installedCount,
                selected: tab == _PluginTab.installed,
                onTap: () => onTabChanged(_PluginTab.installed),
              ),
              _PluginTabButton(
                label: '可升级',
                count: updateCount == 0 ? null : updateCount,
                alert: updateCount > 0,
                selected: tab == _PluginTab.updates,
                onTap: () => onTabChanged(_PluginTab.updates),
              ),
            ],
          ),
        );

        final refresh = OutlinedButton.icon(
          onPressed: refreshing ? null : () => onRefresh(),
          style: OutlinedButton.styleFrom(
            backgroundColor: context.cardColor,
            foregroundColor:
                context.isDark ? AppColors.slate200 : AppColors.slate700,
            side: BorderSide(color: context.faintBorder),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: refreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
          label: Text(tab == _PluginTab.installed ? '刷新列表' : '更新插件列表'),
        );

        final manualInstall = OutlinedButton.icon(
          onPressed: uploading ? null : () => onUpload(),
          style: OutlinedButton.styleFrom(
            backgroundColor: context.cardColor,
            foregroundColor:
                context.isDark ? AppColors.slate200 : AppColors.slate700,
            side: BorderSide(color: context.faintBorder),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_rounded, size: 18),
          label: const Text('手动安装'),
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (tab == _PluginTab.installed) manualInstall,
            refresh,
          ],
        );

        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [tabs, const SizedBox(height: 12), actions],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [tabs, actions],
        );
      },
    );
  }
}

class _PluginTabButton extends StatelessWidget {
  const _PluginTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.alert = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? (context.isDark ? AppColors.slate700 : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary600 : context.mutedText,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: alert
                      ? const Color(0xffef4444)
                      : (selected ? AppColors.primary50 : AppColors.slate200),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: alert
                        ? Colors.white
                        : (selected
                            ? AppColors.primary600
                            : AppColors.slate600),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PluginFilterBar extends StatelessWidget {
  const _PluginFilterBar({
    required this.category,
    required this.query,
    required this.onCategoryChanged,
    required this.onQueryChanged,
  });

  final String category;
  final String query;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    const categories = [
      ('all', '全部'),
      ('scraper', '元数据'),
      ('format', '格式'),
      ('utility', '工具'),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.faintBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chips = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in categories)
                _PluginCategoryChip(
                  label: item.$2,
                  selected: category == item.$1,
                  onTap: () => onCategoryChanged(item.$1),
                ),
            ],
          );
          final search = SizedBox(
            width: constraints.maxWidth < 760 ? double.infinity : 288,
            child: TextField(
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                hintText: '搜索插件',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [chips, const SizedBox(height: 12), search],
            );
          }
          return Row(
            children: [
              Expanded(child: chips),
              const SizedBox(width: 16),
              search,
            ],
          );
        },
      ),
    );
  }
}

class _PluginCategoryChip extends StatelessWidget {
  const _PluginCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (context.isDark
                  ? AppColors.primary700.withOpacity(0.24)
                  : AppColors.primary50)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary600 : context.mutedText,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _PluginGrid extends StatelessWidget {
  const _PluginGrid({
    required this.items,
    required this.tab,
    required this.installingId,
    required this.expandedDescriptions,
    required this.installedVersionFor,
    required this.hasUpdate,
    required this.onToggleDescription,
    required this.onInstall,
    required this.onReload,
    required this.onDelete,
    required this.onConfigure,
  });

  final List<PluginItem> items;
  final _PluginTab tab;
  final String? installingId;
  final Set<String> expandedDescriptions;
  final String? Function(String id) installedVersionFor;
  final bool Function(PluginItem item) hasUpdate;
  final ValueChanged<String> onToggleDescription;
  final ValueChanged<PluginItem> onInstall;
  final ValueChanged<String> onReload;
  final ValueChanged<PluginItem> onDelete;
  final ValueChanged<PluginItem> onConfigure;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1120 ? 3 : (width >= 740 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 318,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final installedVersion = installedVersionFor(item.id);
            return _PluginCard(
              item: item,
              installed:
                  tab == _PluginTab.installed || installedVersion != null,
              installedVersion: installedVersion,
              hasUpdate: hasUpdate(item),
              installing: installingId == item.id,
              expanded: expandedDescriptions.contains(item.id),
              onToggleDescription: () => onToggleDescription(item.id),
              onInstall:
                  tab == _PluginTab.installed ? null : () => onInstall(item),
              onReload:
                  tab == _PluginTab.installed ? () => onReload(item.id) : null,
              onDelete:
                  tab == _PluginTab.installed ? () => onDelete(item) : null,
              onConfigure:
                  tab == _PluginTab.installed && item.configSchema != null
                      ? () => onConfigure(item)
                      : null,
            );
          },
        );
      },
    );
  }
}

class _PluginCard extends StatelessWidget {
  const _PluginCard({
    required this.item,
    required this.installed,
    required this.hasUpdate,
    required this.installing,
    required this.expanded,
    required this.onToggleDescription,
    this.installedVersion,
    this.onInstall,
    this.onReload,
    this.onDelete,
    this.onConfigure,
  });

  final PluginItem item;
  final bool installed;
  final String? installedVersion;
  final bool hasUpdate;
  final bool installing;
  final bool expanded;
  final VoidCallback onToggleDescription;
  final VoidCallback? onInstall;
  final VoidCallback? onReload;
  final VoidCallback? onDelete;
  final VoidCallback? onConfigure;

  @override
  Widget build(BuildContext context) {
    final description = item.longDescription ?? item.description ?? '暂无描述';
    final typeStyle = _pluginTypeStyle(item.pluginType, context);
    final supports = item.supportedExtensions;

    return TingCard(
      radius: 8,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeStyle.background,
                  border: Border.all(color: typeStyle.border),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _pluginTypeIcon(item.pluginType),
                  color: typeStyle.foreground,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          _formatPluginVersion(item.version),
                          style:
                              TextStyle(color: context.mutedText, fontSize: 12),
                        ),
                        if (hasUpdate && installedVersion != null)
                          Text(
                            _formatPluginVersion(installedVersion),
                            style: const TextStyle(
                              color: AppColors.slate400,
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        if (item.author != null)
                          Text(
                            item.author!,
                            style: TextStyle(
                                color: context.mutedText, fontSize: 12),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              installed && onInstall == null
                  ? _PluginStateBadge(state: item.state)
                  : _StorePluginBadge(
                      installed: installed,
                      hasUpdate: hasUpdate,
                    ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onToggleDescription,
            borderRadius: BorderRadius.circular(8),
            child: Text(
              description,
              maxLines: expanded ? 7 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.isDark ? AppColors.slate300 : AppColors.slate600,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PluginInfoChip(
                label: _pluginTypeLabel(item.pluginType),
                icon: Icons.sell_rounded,
                color: typeStyle.foreground,
                background: typeStyle.background,
                border: typeStyle.border,
              ),
              _PluginInfoChip(
                label: _pluginRuntimeLabel(item.runtime),
                icon: Icons.memory_rounded,
              ),
              if (supports.isNotEmpty)
                _PluginInfoChip(
                  label: supports.length > 4
                      ? '${supports.take(4).join(', ')} +${supports.length - 4}'
                      : supports.join(', '),
                  icon: Icons.description_rounded,
                ),
              if (item.dependencies.isNotEmpty)
                _PluginInfoChip(
                  label: '${item.dependencies.length} 依赖',
                  icon: Icons.inventory_2_rounded,
                ),
              if (item.permissions.isNotEmpty)
                _PluginInfoChip(
                  label: '${item.permissions.length} 权限',
                  icon: Icons.shield_rounded,
                ),
              if (item.license != null) _PluginInfoChip(label: item.license!),
              if (item.configSchema != null)
                const _PluginInfoChip(
                  label: '可配置',
                  icon: Icons.settings_rounded,
                ),
              if (item.scraper?.autoScrape == true)
                const _PluginInfoChip(label: '自动刮削'),
              if ((item.scraper?.searchFields.length ?? 0) > 0)
                _PluginInfoChip(
                  label: '${item.scraper!.searchFields.length} 搜索项',
                  icon: Icons.search_rounded,
                  tooltip: item.scraper!.searchFields.join(', '),
                ),
              if ((item.scraper?.resultFields.length ?? 0) > 0)
                _PluginInfoChip(
                  label: '${item.scraper!.resultFields.length} 返回字段',
                  icon: Icons.fact_check_outlined,
                  tooltip: item.scraper!.resultFields.join(', '),
                ),
            ],
          ),
          const Spacer(),
          Divider(color: context.faintBorder),
          Row(
            children: [
              if (item.repo != null && item.repo!.trim().isNotEmpty)
                _PluginFooterButton(
                  icon: const _GitHubIcon(size: 17),
                  label: '仓库',
                  onPressed: () => openRepositoryUrl(item.repo!),
                ),
              const Spacer(),
              if (onConfigure != null)
                _PluginIconAction(
                  icon: Icons.settings_rounded,
                  tooltip: '配置',
                  onPressed: onConfigure!,
                ),
              if (onReload != null)
                _PluginIconAction(
                  icon: Icons.refresh_rounded,
                  tooltip: '重新加载',
                  onPressed: onReload!,
                ),
              if (onDelete != null)
                _PluginIconAction(
                  icon: Icons.delete_outline_rounded,
                  tooltip: '卸载',
                  danger: true,
                  onPressed: onDelete!,
                ),
              if (onInstall != null)
                ElevatedButton.icon(
                  onPressed: installing || (installed && !hasUpdate)
                      ? null
                      : onInstall,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: hasUpdate
                        ? const Color(0xff059669)
                        : AppColors.primary600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: context.isDark
                        ? AppColors.slate800
                        : AppColors.slate100,
                    disabledForegroundColor: AppColors.slate400,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  icon: installing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 17),
                  label: Text(
                    installing
                        ? '处理中'
                        : hasUpdate
                            ? '更新'
                            : installed
                                ? '已安装'
                                : '安装',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PluginFooterButton extends StatelessWidget {
  const _PluginFooterButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: context.mutedText,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: icon,
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _PluginIconAction extends StatelessWidget {
  const _PluginIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        splashRadius: 21,
        color: danger ? const Color(0xffdc2626) : context.mutedText,
        icon: Icon(icon, size: 19),
      ),
    );
  }
}

class _PluginInfoChip extends StatelessWidget {
  const _PluginInfoChip({
    required this.label,
    this.icon,
    this.color,
    this.background,
    this.border,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;
  final Color? border;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final fg =
        color ?? (context.isDark ? AppColors.slate300 : AppColors.slate600);
    final chip = Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background ??
            (context.isDark ? AppColors.slate800 : AppColors.slate50),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: border ?? context.faintBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
    final message = tooltip?.trim();
    if (message == null || message.isEmpty) return chip;
    return Tooltip(message: message, child: chip);
  }
}

class _PluginStateBadge extends StatelessWidget {
  const _PluginStateBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final active = state == 'active' || state == 'loaded';
    final failed = state == 'failed';
    final color = failed
        ? const Color(0xffdc2626)
        : active
            ? const Color(0xff16a34a)
            : AppColors.slate600;
    final bg = failed
        ? const Color(0xfffff1f2)
        : active
            ? const Color(0xfff0fdf4)
            : AppColors.slate50;
    final label = active ? '活跃' : (failed ? '失败' : state);
    final icon = active
        ? Icons.check_circle_rounded
        : failed
            ? Icons.cancel_rounded
            : Icons.error_outline_rounded;

    return _Badge(label: label, icon: icon, color: color, background: bg);
  }
}

class _StorePluginBadge extends StatelessWidget {
  const _StorePluginBadge({
    required this.installed,
    required this.hasUpdate,
  });

  final bool installed;
  final bool hasUpdate;

  @override
  Widget build(BuildContext context) {
    if (hasUpdate) {
      return const _Badge(
        label: '可更新',
        color: Color(0xff047857),
        background: Color(0xffecfdf5),
      );
    }
    if (installed) {
      return const _Badge(
        label: '已安装',
        color: AppColors.slate600,
        background: AppColors.slate50,
      );
    }
    return const SizedBox.shrink();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginEmptyState extends StatelessWidget {
  const _PluginEmptyState({required this.tab});

  final _PluginTab tab;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: tab == _PluginTab.installed
          ? Icons.extension_off_rounded
          : Icons.shopping_bag_outlined,
      title: tab == _PluginTab.updates
          ? '暂无可用更新'
          : tab == _PluginTab.installed
              ? '暂无已安装的插件'
              : '未找到符合条件的插件',
      message:
          tab == _PluginTab.installed ? '点击“全部”查看可安装插件。' : '调整筛选条件或刷新插件列表。',
    );
  }
}

class _PluginConfigDialog extends StatefulWidget {
  const _PluginConfigDialog({required this.plugin});

  final PluginItem plugin;

  @override
  State<_PluginConfigDialog> createState() => _PluginConfigDialogState();
}

class _PluginConfigDialogState extends State<_PluginConfigDialog> {
  final _controller = TextEditingController(text: '{}');
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await AppScope.appOf(context)
          .api
          .get('/api/v1/plugins/${widget.plugin.id}/config');
      if (!mounted) return;
      final config = asMap(res.data)['config'] ?? <String, dynamic>{};
      _controller.text = _prettyLibraryJson(config);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    Object? config;
    try {
      config = jsonDecode(_controller.text);
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('JSON 格式错误')));
      return;
    }

    setState(() => _saving = true);
    try {
      await AppScope.appOf(context).api.put(
        '/api/v1/plugins/${widget.plugin.id}/config',
        data: {'config': config},
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.plugin.name} 配置',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const SizedBox(height: 180, child: LoadingView())
              else
                TextField(
                  controller: _controller,
                  minLines: 8,
                  maxLines: 12,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(hintText: '{}'),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: '保存',
                      loading: _saving,
                      onPressed: _saving ? null : () => _save(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PluginTypeStyle {
  const _PluginTypeStyle({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

_PluginTypeStyle _pluginTypeStyle(String type, BuildContext context) {
  switch (type) {
    case 'format':
      return const _PluginTypeStyle(
        foreground: Color(0xff0e7490),
        background: Color(0xffecfeff),
        border: Color(0xffcffafe),
      );
    case 'utility':
      return const _PluginTypeStyle(
        foreground: Color(0xff047857),
        background: Color(0xffecfdf5),
        border: Color(0xffd1fae5),
      );
    case 'scraper':
      return const _PluginTypeStyle(
        foreground: Color(0xff1d4ed8),
        background: Color(0xffeff6ff),
        border: Color(0xffdbeafe),
      );
    default:
      return _PluginTypeStyle(
        foreground: context.isDark ? AppColors.slate200 : AppColors.slate700,
        background: context.isDark ? AppColors.slate800 : AppColors.slate50,
        border: context.faintBorder,
      );
  }
}

IconData _pluginTypeIcon(String type) {
  if (type == 'format') return Icons.description_rounded;
  if (type == 'utility') return Icons.inventory_2_rounded;
  return Icons.extension_rounded;
}

String _pluginTypeLabel(String type) {
  switch (type) {
    case 'scraper':
      return '元数据';
    case 'format':
      return '格式';
    case 'utility':
      return '工具';
    default:
      return type.isEmpty ? '未知' : type;
  }
}

String _pluginRuntimeLabel(String? runtime) {
  switch (runtime) {
    case 'wasm':
      return 'WASM';
    case 'javascript':
      return 'JavaScript';
    case 'native':
      return 'Native';
    default:
      return runtime?.isNotEmpty == true ? runtime! : 'unknown';
  }
}

String _formatPluginVersion(String? version) {
  if (version == null || version.isEmpty) return '未知版本';
  return version.startsWith('v') ? version : 'v$version';
}

String _basePluginId(String id) => id.split('@').first;

int _comparePluginVersions(String a, String b) {
  final left = _versionParts(a);
  final right = _versionParts(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final diff =
        (i < left.length ? left[i] : 0) - (i < right.length ? right[i] : 0);
    if (diff != 0) return diff;
  }
  return 0;
}

List<int> _versionParts(String value) {
  return value
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
}

class _GitHubIcon extends StatelessWidget {
  const _GitHubIcon({this.size = 17});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GitHubIconPainter(
        color: IconTheme.of(context).color ?? context.mutedText,
      ),
    );
  }
}

class _GitHubIconPainter extends CustomPainter {
  const _GitHubIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final path = Path()
      ..moveTo(15, 22)
      ..lineTo(15, 18)
      ..cubicTo(15, 16.6, 14.65, 15.4, 14, 14.5)
      ..cubicTo(17, 14.5, 20, 12.5, 20, 9)
      ..cubicTo(20.08, 7.75, 19.73, 6.52, 19, 5.5)
      ..cubicTo(19.28, 4.35, 19.28, 3.15, 19, 2)
      ..cubicTo(19, 2, 18, 2, 16, 3.5)
      ..cubicTo(13.36, 3, 10.64, 3, 8, 3.5)
      ..cubicTo(6, 2, 5, 2, 5, 2)
      ..cubicTo(4.7, 3.15, 4.7, 4.35, 5, 5.5)
      ..cubicTo(4.35, 6.5, 4, 7.7, 4, 9)
      ..cubicTo(4, 12.5, 7, 14.5, 10, 14.5)
      ..cubicTo(9.61, 14.99, 9.32, 15.55, 9.15, 16.15)
      ..cubicTo(8.98, 16.75, 8.93, 17.38, 9, 18)
      ..lineTo(9, 22)
      ..moveTo(9, 18)
      ..cubicTo(4.49, 20, 4, 16, 2, 16);
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GitHubIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
