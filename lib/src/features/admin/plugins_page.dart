part of 'admin_pages.dart';

class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key, this.onViewLogs});

  final ValueChanged<PluginItem>? onViewLogs;

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

enum _PluginTab { store, installed, updates }

class _PluginsPageState extends State<PluginsPage> {
  PluginState? _catalog;
  bool get _installedLoading => _catalog?.installedLoading ?? true;
  bool get _storeLoading => _catalog?.storeLoading ?? false;
  List<PluginItem> get _installed => _catalog?.installed ?? const [];
  List<PluginItem> get _store => _catalog?.store ?? const [];
  _PluginTab _tab = _PluginTab.installed;
  String _category = 'all';
  String _query = '';
  String? _installingId;
  bool _uploadingPlugin = false;
  final Set<String> _expandedDescriptions = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_catalog != null) return;
    _catalog = PluginState(AppScope.appOf(context).api)
      ..addListener(_catalogChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInstalled();
    });
  }

  void _catalogChanged() {
    if (!mounted) return;
    setState(() {
      if (!_hasPluginStoreProvider) _tab = _PluginTab.installed;
    });
  }

  @override
  void dispose() {
    _catalog?.removeListener(_catalogChanged);
    _catalog?.dispose();
    super.dispose();
  }

  bool get _hasPluginStoreProvider => _catalog?.hasStore ?? false;

  Future<void> _loadInstalled() async {
    await _catalog?.loadInstalled();
  }

  Future<void> _loadStore({bool clearCache = false}) async {
    await _catalog?.loadStore(refresh: clearCache);
  }

  Future<void> _refresh() {
    if (_tab == _PluginTab.installed || !_hasPluginStoreProvider) {
      return _loadInstalled();
    }
    return _loadStore(clearCache: true);
  }

  Future<void> _reloadPluginLists({bool refreshStore = false}) async {
    await _catalog?.refresh(refreshStore: refreshStore);
    if (mounted) AppScope.appOf(context).notifyPluginExtensionsChanged();
  }

  Future<void> _reload(String id) async {
    try {
      if (await _catalog?.reload(id) != true || !mounted) return;
      _showSnack(context.l10n.pluginsReloaded);
      AppScope.appOf(context).notifyPluginExtensionsChanged();
    } catch (error) {
      if (mounted) {
        _showSnack(context.localeText('重载失败：${ApiError.messageFor(error)}',
            'Reload failed: ${ApiError.messageFor(error)}'));
      }
    }
  }

  Future<void> _install(PluginItem item) async {
    final catalog = _catalog;
    if (catalog == null) return;
    var attemptedInstall = false;
    try {
      final installed = await catalog.install(
        item,
        checkClientVersion: _ensureFlutterVersionSupported,
        confirmDependencies: (dependencies) async {
          if (!mounted) return false;
          return await _confirmDependencyInstall(item,
                  dependencies.map((dependency) => dependency.name).toList()) ==
              true;
        },
        confirmPackage: (confirmation) async {
          if (!mounted) return false;
          return await _confirmUnverifiedPlugin(confirmation) == true;
        },
        onInstalling: (id) {
          if (id != null) attemptedInstall = true;
          if (mounted) setState(() => _installingId = id);
        },
      );
      if (!mounted || !installed) return;
      _showSnack(context.l10n.pluginsInstalled);
    } catch (error) {
      if (mounted) {
        _showSnack(ApiError.messageFor(
          error,
          fallback: context.l10n.pluginsInstallFailed,
        ));
      }
    } finally {
      if (mounted && attemptedInstall) {
        AppScope.appOf(context).notifyPluginExtensionsChanged();
      }
    }
  }

  Future<bool?> _confirmDependencyInstall(
    PluginItem item,
    List<String> dependencyNames,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.pluginsDependencyInstallTitle),
        content: Text(context.l10n.pluginsDependencyInstallMessage(
          item.name,
          dependencyNames,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.pluginsDependencyInstallAction),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureFlutterVersionSupported(PluginItem item) async {
    final required = item.minFlutterVersion?.trim();
    if (required == null || required.isEmpty || !_usesClientExtension(item)) {
      return true;
    }

    final useEnglish = context.isEnglishLocale;
    final current = (await PackageInfo.fromPlatform()).version;
    if (comparePluginVersions(current, required) >= 0) return true;

    if (mounted) {
      _showSnack(useEnglish
          ? '${item.name} requires Flutter client >= $required, current version is $current'
          : '${item.name} 需要 Flutter 客户端 >= $required，当前版本 $current');
    }
    return false;
  }

  Future<void> _uploadPlugin() async {
    if (_uploadingPlugin) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['tr'],
      withData: true,
    );
    if (!mounted) return;
    final file = picked?.files.single;
    final path = file?.path;
    final bytes = file?.bytes;
    if (file == null || (path == null && bytes == null)) return;

    setState(() => _uploadingPlugin = true);

    try {
      final installed = await _catalog?.installPackage(
        name: file.name,
        path: path,
        bytes: bytes,
        confirm: (confirmation) async =>
            mounted && await _confirmUnverifiedPlugin(confirmation) == true,
      );
      if (installed != true) return;
      if (!mounted) return;
      _showSnack(context.l10n.pluginsInstalled);
      AppScope.appOf(context).notifyPluginExtensionsChanged();
    } catch (error) {
      if (mounted) {
        _showSnack(ApiError.messageFor(
          error,
          fallback: context.l10n.pluginsInstallFailed,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingPlugin = false);
    }
  }

  Future<bool?> _confirmUnverifiedPlugin(
      UnverifiedPluginConfirmation confirmation) {
    return showDialog<bool>(
      context: context,
      builder: (context) => UnverifiedPluginDialog(confirmation: confirmation),
    );
  }

  Future<void> _delete(PluginItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.pluginsUninstallTitle),
        content: Text(context.l10n.pluginsUninstallMessage(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.pluginsUninstallAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      if (await _catalog?.uninstall(item.id) != true || !mounted) return;
      _showSnack(context.l10n.pluginsUninstalled);
      AppScope.appOf(context).notifyPluginExtensionsChanged();
    } catch (error) {
      if (mounted) {
        _showSnack(context.localeText('卸载失败：${ApiError.messageFor(error)}',
            'Uninstall failed: ${ApiError.messageFor(error)}'));
      }
    }
  }

  Future<void> _configure(PluginItem item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _PluginConfigDialog(plugin: item),
    );
    if (saved == true) {
      final refreshStore = item.capabilities.any(
        (capability) => capability.kind == 'plugin_store',
      );
      await _reloadPluginLists(refreshStore: refreshStore);
    }
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

  String? _installedVersion(String id) => _catalog?.installedVersion(id);
  bool _hasUpdate(PluginItem item) => _catalog?.hasUpdate(item) ?? false;

  bool _matches(PluginItem item) {
    if (_category != 'all' && item.pluginType != _category) return false;
    if (_query.trim().isEmpty) return true;
    final query = _query.trim().toLowerCase();
    final haystack = '${item.name} ${item.description ?? ''} '
            '${item.longDescription ?? ''} '
            '${item.descriptionI18n.values.join(' ')} ${item.author ?? ''}'
        .toLowerCase();
    return haystack.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final hasStoreProvider = _hasPluginStoreProvider;
    final updateCount = hasStoreProvider ? _store.where(_hasUpdate).length : 0;
    final installedItems = _installed.where(_matches).toList();
    final storeItems = hasStoreProvider
        ? _store
            .where((item) {
              if (_tab == _PluginTab.store &&
                  _installedVersion(item.id) != null) {
                return false;
              }
              if (_tab == _PluginTab.updates && !_hasUpdate(item)) {
                return false;
              }
              return true;
            })
            .where(_matches)
            .toList()
        : <PluginItem>[];
    final activeItems =
        _tab == _PluginTab.installed ? installedItems : storeItems;
    final activeLoading =
        _tab == _PluginTab.installed ? _installedLoading : _storeLoading;

    return PageListView(
      onRefresh: _refresh,
      children: [
        if (_catalog?.error case final String error)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        _PluginTopBar(
          tab: _tab,
          hasStoreProvider: hasStoreProvider,
          installedCount: _installed.length,
          updateCount: updateCount,
          refreshing: activeLoading,
          uploading: _uploadingPlugin,
          onTabChanged: (tab) {
            if (tab != _PluginTab.installed && !hasStoreProvider) return;
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
          SizedBox(
              height: 220,
              child: LoadingView(label: context.l10n.pluginsLoading))
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
            onViewLogs: widget.onViewLogs,
          ),
      ],
    );
  }
}

class _PluginTopBar extends StatelessWidget {
  const _PluginTopBar({
    required this.tab,
    required this.hasStoreProvider,
    required this.installedCount,
    required this.updateCount,
    required this.refreshing,
    required this.uploading,
    required this.onTabChanged,
    required this.onRefresh,
    required this.onUpload,
  });

  final _PluginTab tab;
  final bool hasStoreProvider;
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
                label: context.l10n.pluginsInstalledTab,
                count: installedCount == 0 ? null : installedCount,
                selected: tab == _PluginTab.installed,
                onTap: () => onTabChanged(_PluginTab.installed),
              ),
              if (hasStoreProvider) ...[
                _PluginTabButton(
                  label: context.localeText('插件商店', 'Plugin Store'),
                  selected: tab == _PluginTab.store,
                  onTap: () => onTabChanged(_PluginTab.store),
                ),
                _PluginTabButton(
                  label: context.l10n.pluginsUpdatesTab,
                  count: updateCount == 0 ? null : updateCount,
                  alert: updateCount > 0,
                  selected: tab == _PluginTab.updates,
                  onTap: () => onTabChanged(_PluginTab.updates),
                ),
              ],
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
          label: Text(tab == _PluginTab.installed
              ? context.l10n.pluginsRefreshList
              : context.l10n.pluginsUpdateList),
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
          label: Text(context.l10n.pluginsManualInstall),
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
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: tabs,
              ),
              const SizedBox(height: 12),
              actions,
            ],
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
                    color: Colors.black.withValues(alpha: 0.04),
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
    final categories = [
      ('all', context.l10n.pluginsAll),
      ('scraper', context.l10n.pluginsCategoryMetadata),
      ('format', context.l10n.pluginsCategoryFormat),
      ('utility', context.l10n.pluginsCategoryUtility),
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
              decoration: InputDecoration(
                hintText: context.l10n.pluginsSearchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  ? AppColors.primary700.withValues(alpha: 0.24)
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
    this.onViewLogs,
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
  final ValueChanged<PluginItem>? onViewLogs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1120 ? 3 : (width >= 740 ? 2 : 1);
        Widget buildCard(int index) {
          final item = items[index];
          final installedVersion = installedVersionFor(item.id);
          return _PluginCard(
            item: item,
            installed: tab == _PluginTab.installed || installedVersion != null,
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
                tab == _PluginTab.installed ? () => onDelete.call(item) : null,
            onConfigure:
                tab == _PluginTab.installed && item.configSchema != null
                    ? () => onConfigure(item)
                    : null,
            onViewLogs: tab == _PluginTab.installed && onViewLogs != null
                ? () => onViewLogs?.call(item)
                : null,
          );
        }

        return Column(
          children: [
            for (var start = 0; start < items.length; start += columns)
              Padding(
                padding: EdgeInsets.only(
                    bottom: start + columns < items.length ? 16 : 0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: 16),
                        Expanded(
                          child: start + column < items.length
                              ? ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minHeight: 288),
                                  child: buildCard(start + column),
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
