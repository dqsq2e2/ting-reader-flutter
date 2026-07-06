part of 'admin_pages.dart';

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
  _PluginTab _tab = _PluginTab.installed;
  String _category = 'all';
  String _query = '';
  String? _installingId;
  bool _uploadingPlugin = false;
  final Set<String> _expandedDescriptions = {};

  @override
  void initState() {
    super.initState();
    _loadInstalled();
  }

  bool get _hasPluginStoreProvider => _installed.any(
        (item) => item.capabilities.any(
          (capability) => capability.kind == 'plugin_store',
        ),
      );

  Future<void> _loadInstalled() async {
    setState(() => _installedLoading = true);
    try {
      final res = await AppScope.appOf(context).api.get('/api/v1/plugins');
      if (!mounted) return;
      setState(() {
        _installed = asMapList(res.data).map(PluginItem.fromJson).toList();
        if (!_hasPluginStoreProvider) {
          _store = [];
          if (_tab != _PluginTab.installed) _tab = _PluginTab.installed;
        }
      });
    } finally {
      if (mounted) setState(() => _installedLoading = false);
    }
  }

  Future<void> _loadStore({bool clearCache = false}) async {
    if (!_hasPluginStoreProvider) {
      if (!mounted) return;
      setState(() {
        _store = [];
        if (_tab != _PluginTab.installed) _tab = _PluginTab.installed;
      });
      return;
    }

    setState(() => _storeLoading = true);
    try {
      final api = AppScope.appOf(context).api;
      if (clearCache) await api.post('/api/v1/store/cache/clear');
      final res = await api.get(
        '/api/v1/store/plugins',
        params: clearCache ? {'refresh': 'true'} : null,
      );
      if (!mounted) return;
      setState(() {
        _store = asMapList(res.data).map(PluginItem.fromJson).toList();
      });
    } finally {
      if (mounted) setState(() => _storeLoading = false);
    }
  }

  Future<void> _refresh() {
    if (_tab == _PluginTab.installed || !_hasPluginStoreProvider) {
      return _loadInstalled();
    }
    return _loadStore(clearCache: true);
  }

  Future<void> _reloadPluginLists({bool refreshStore = false}) async {
    await _loadInstalled();
    if (_hasPluginStoreProvider) {
      await _loadStore(clearCache: refreshStore);
    }
    if (mounted) AppScope.appOf(context).notifyPluginExtensionsChanged();
  }

  Future<void> _reload(String id) async {
    await AppScope.appOf(context).api.post('/api/v1/plugins/$id/reload');
    if (!mounted) return;
    _showSnack(context.l10n.pluginsReloaded);
    await _loadInstalled();
    if (mounted) AppScope.appOf(context).notifyPluginExtensionsChanged();
  }

  Future<void> _install(PluginItem item) async {
    if (!await _ensureFlutterVersionSupported(item)) return;
    if (!mounted) return;

    final api = AppScope.appOf(context).api;
    final installedMessage = context.l10n.pluginsInstalled;
    final installFailedMessage = context.l10n.pluginsInstallFailed;

    Future<void> install({required bool acceptUnverified}) async {
      await api.post(
        '/api/v1/store/install',
        data: {
          'plugin_id': item.id,
          if (acceptUnverified) 'accept_unverified': true,
        },
      );
    }

    setState(() => _installingId = item.id);
    try {
      await install(acceptUnverified: false);
      if (!mounted) return;
      _showSnack(installedMessage);
      await _reloadPluginLists();
    } on DioException catch (error) {
      final response = error.response;
      final data = response?.data;
      if (response?.statusCode == 428 &&
          data is Map &&
          data['requires_confirmation'] == true) {
        final warning = data['warning']?.toString() ??
            '${item.name}由未知发布者提供，未经Ting Reader验证。单击同意，即表示你同意全权负责因使用该插件而可能导致的任何设备损坏或数据丢失。';
        if (!mounted) return;
        final agreed = await _confirmUnverifiedPlugin(warning);
        if (agreed == true && mounted) {
          try {
            await install(acceptUnverified: true);
            if (!mounted) return;
            _showSnack(installedMessage);
            await _reloadPluginLists();
          } catch (_) {
            if (mounted) _showSnack(installFailedMessage);
          }
        }
      } else if (mounted) {
        _showSnack(installFailedMessage);
      }
    } catch (_) {
      if (mounted) _showSnack(installFailedMessage);
    } finally {
      if (mounted) setState(() => _installingId = null);
    }
  }

  Future<bool> _ensureFlutterVersionSupported(PluginItem item) async {
    final required = item.minFlutterVersion?.trim();
    if (required == null || required.isEmpty || !_usesClientExtension(item)) {
      return true;
    }

    final useEnglish = context.isEnglishLocale;
    final current = (await PackageInfo.fromPlatform()).version;
    if (_comparePluginVersions(current, required) >= 0) return true;

    if (mounted) {
      _showSnack(useEnglish
          ? '${item.name} requires Flutter client >= $required, current version is $current'
          : '${item.name} 需要 Flutter 客户端 >= $required，当前版本 $current');
    }
    return false;
  }

  Future<void> _uploadPlugin() async {
    if (_uploadingPlugin) return;
    final api = AppScope.appOf(context).api;
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

    Future<void> upload({required bool acceptUnverified}) async {
      final uploadFile = path != null
          ? await MultipartFile.fromFile(path, filename: file.name)
          : MultipartFile.fromBytes(bytes!, filename: file.name);
      final formData = FormData.fromMap({
        'file': uploadFile,
        if (acceptUnverified) 'accept_unverified': 'true',
      });
      await api.post('/api/v1/plugins/install', data: formData);
    }

    try {
      await upload(acceptUnverified: false);
      if (!mounted) return;
      _showSnack(context.l10n.pluginsInstalled);
      await _reloadPluginLists();
    } on DioException catch (error) {
      final response = error.response;
      final data = response?.data;
      if (response?.statusCode == 428 &&
          data is Map &&
          data['requires_confirmation'] == true) {
        final warning = data['warning']?.toString() ??
            '${file.name}由未知发布者提供，未经Ting Reader验证。单击同意，即表示你同意全权负责因使用该插件而可能导致的任何设备损坏或数据丢失。';
        if (!mounted) return;
        final agreed = await _confirmUnverifiedPlugin(warning);
        if (agreed == true && mounted) {
          try {
            await upload(acceptUnverified: true);
            if (!mounted) return;
            _showSnack(context.l10n.pluginsInstalled);
            await _reloadPluginLists();
          } catch (_) {
            if (mounted) _showSnack(context.l10n.pluginsInstallFailed);
          }
        }
      } else if (mounted) {
        _showSnack(context.l10n.pluginsInstallFailed);
      }
    } catch (_) {
      if (mounted) _showSnack(context.l10n.pluginsInstallFailed);
    } finally {
      if (mounted) setState(() => _uploadingPlugin = false);
    }
  }

  Future<bool?> _confirmUnverifiedPlugin(String warning) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.localeText('未经验证插件', 'Unverified plugin')),
        content: Text(warning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.localeText('同意', 'Agree')),
          ),
        ],
      ),
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

    await AppScope.appOf(context).api.delete('/api/v1/plugins/${item.id}');
    if (!mounted) return;
    _showSnack(context.l10n.pluginsUninstalled);
    await _reloadPluginLists();
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
          ),
        const SafeBottomSpacer(),
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
    final description = _localizedText(item.descriptionI18n, context) ??
        item.longDescription ??
        item.description ??
        context.l10n.pluginsNoDescription;
    final typeStyle = _pluginTypeStyle(item.pluginType, context);
    final supports = item.supportedExtensions;
    final supportLabels =
        supports.map(_pluginSupportLabel).toList(growable: false);
    final searchFieldCount =
        _metadataCapabilityListCount(item.capabilities, 'search_fields');
    final resultFieldCount =
        _metadataCapabilityListCount(item.capabilities, 'result_fields');
    final riskSignals = _pluginRiskSignals(context, item);

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
                label: _pluginTypeLabel(context, item.pluginType),
                icon: Icons.sell_rounded,
              ),
              _PluginInfoChip(
                label: _pluginRuntimeLabel(item.runtime),
                icon: Icons.memory_rounded,
              ),
              if (supportLabels.isNotEmpty)
                _PluginInfoChip(
                  label: supportLabels.length > 4
                      ? '${supportLabels.take(4).join(', ')} +${supportLabels.length - 4}'
                      : supportLabels.join(', '),
                  icon: Icons.description_rounded,
                ),
              if (item.permissions.isNotEmpty)
                _PluginInfoChip(
                  label: context.l10n.pluginsPermissionCount(
                    item.permissions.length,
                  ),
                  icon: Icons.shield_outlined,
                ),
              if (searchFieldCount > 0)
                _PluginInfoChip(
                  label: context.l10n.pluginsSearchFieldCount(
                    searchFieldCount,
                  ),
                  icon: Icons.search_rounded,
                ),
              if (resultFieldCount > 0)
                _PluginInfoChip(
                  label: context.l10n.pluginsResultFieldCount(
                    resultFieldCount,
                  ),
                  icon: Icons.fact_check_rounded,
                ),
              if (riskSignals.isNotEmpty)
                _PluginInfoChip(
                  label: _previewChipLabels(riskSignals, limit: 3),
                  icon: Icons.policy_rounded,
                  color: const Color(0xffb45309),
                  background: const Color(0xfffffbeb),
                  border: const Color(0xfffde68a),
                  tooltip: riskSignals.join(', '),
                ),
              if (item.dependencies.isNotEmpty)
                _PluginInfoChip(
                  label: context.l10n
                      .pluginsDependencyCount(item.dependencies.length),
                  icon: Icons.inventory_2_rounded,
                ),
              if (item.license != null) _PluginInfoChip(label: item.license!),
              if (item.configSchema != null)
                _PluginInfoChip(
                  label: context.l10n.pluginsConfigurable,
                  icon: Icons.settings_rounded,
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
                  label: context.l10n.pluginsRepository,
                  onPressed: () => openRepositoryUrl(item.repo!),
                ),
              const Spacer(),
              if (onConfigure != null)
                _PluginIconAction(
                  icon: Icons.settings_rounded,
                  tooltip: context.l10n.pluginsConfigure,
                  onPressed: onConfigure!,
                ),
              if (onReload != null)
                _PluginIconAction(
                  icon: Icons.refresh_rounded,
                  tooltip: context.l10n.pluginsReload,
                  onPressed: onReload!,
                ),
              if (onDelete != null)
                _PluginIconAction(
                  icon: Icons.delete_outline_rounded,
                  tooltip: context.l10n.pluginsUninstallAction,
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
                        ? context.l10n.pluginsProcessing
                        : hasUpdate
                            ? context.l10n.pluginsUpdate
                            : installed
                                ? context.l10n.pluginsInstalledTab
                                : context.l10n.pluginsInstall,
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
    final label = active
        ? context.l10n.pluginsStateActive
        : (failed ? context.l10n.pluginsStateFailed : state);
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
      return _Badge(
        label: context.l10n.pluginsUpdateAvailable,
        color: const Color(0xff047857),
        background: const Color(0xffecfdf5),
      );
    }
    if (installed) {
      return _Badge(
        label: context.l10n.pluginsInstalledTab,
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
        border: Border.all(color: color.withValues(alpha: 0.18)),
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
          ? context.l10n.pluginsNoUpdates
          : tab == _PluginTab.installed
              ? context.l10n.pluginsNoInstalled
              : context.l10n.pluginsNoMatches,
      message: tab == _PluginTab.installed
          ? context.l10n.pluginsInstalledEmptyHint
          : context.l10n.pluginsFilterEmptyHint,
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
  final Map<String, TextEditingController> _controllers = {};
  Map<String, dynamic> _config = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _secretPlaceholder = '__TING_READER_SECRET_UNCHANGED__';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, Map<String, dynamic>> get _properties {
    final schema = widget.plugin.configSchema;
    final raw = schema == null ? null : schema['properties'];
    if (raw is! Map) return const {};
    return raw.map((key, value) {
      return MapEntry(
        key.toString(),
        value is Map
            ? value.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{},
      );
    });
  }

  Future<void> _load() async {
    try {
      final res = await AppScope.appOf(context)
          .api
          .get('/api/v1/plugins/${widget.plugin.id}/config');
      if (!mounted) return;
      final config = asMap(asMap(res.data)['config']);
      setState(() {
        _config = Map<String, dynamic>.from(config);
        _syncControllers();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    Map<String, dynamic> config;
    try {
      config = _readFormConfig();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.localeText(
            '配置格式不正确: $error',
            'Invalid config: $error',
          )),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await AppScope.appOf(context).api.put(
        '/api/v1/plugins/${widget.plugin.id}/config',
        data: {'config': config},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _syncControllers() {
    for (final entry in _properties.entries) {
      final prop = entry.value;
      if (_usesTextController(prop)) {
        _controllerFor(entry.key, prop).text =
            _editorTextForValue(_valueFor(entry.key, prop), prop);
      }
    }
  }

  TextEditingController _controllerFor(String key, Map<String, dynamic> prop) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(
        text: _editorTextForValue(_valueFor(key, prop), prop),
      ),
    );
  }

  Object? _valueFor(String key, Map<String, dynamic> prop) {
    if (_config.containsKey(key)) return _config[key];
    return prop['default'];
  }

  bool _usesTextController(Map<String, dynamic> prop) {
    final type = _schemaType(prop);
    return _isEncryptedField(prop) ||
        type == 'string' ||
        type == 'integer' ||
        type == 'number' ||
        type == 'array' ||
        type == 'object';
  }

  Map<String, dynamic> _readFormConfig() {
    final result = Map<String, dynamic>.from(_config);
    for (final entry in _properties.entries) {
      final key = entry.key;
      final prop = entry.value;
      final type = _schemaType(prop);
      final enumValues = _schemaEnum(prop);

      if (enumValues.isNotEmpty || type == 'boolean') {
        result[key] = _config.containsKey(key) ? _config[key] : prop['default'];
        continue;
      }

      final controller = _controllerFor(key, prop);
      final text = controller.text.trim();
      if (_isEncryptedField(prop) && text.isEmpty) {
        result[key] = _secretPlaceholder;
      } else if (type == 'integer') {
        result[key] = text.isEmpty ? null : int.parse(text);
      } else if (type == 'number') {
        result[key] = text.isEmpty ? null : num.parse(text);
      } else if (type == 'array' || type == 'object') {
        result[key] = text.isEmpty
            ? (type == 'array' ? <dynamic>[] : {})
            : jsonDecode(text);
      } else {
        result[key] = text;
      }
    }
    return result;
  }

  void _setConfigValue(String key, Object? value) {
    setState(() {
      _config = {..._config, key: value};
    });
  }

  Widget _field(String key, Map<String, dynamic> prop) {
    final label = _schemaLabel(context, key, prop);
    final description = _schemaDescription(context, prop);
    final type = _schemaType(prop);
    final enumValues = _schemaEnum(prop);
    final encrypted = _isEncryptedField(prop);

    if (enumValues.isNotEmpty) {
      final current = (_valueFor(key, prop) ?? enumValues.first).toString();
      return _PluginConfigFieldFrame(
        label: label,
        description: description,
        child: DropdownButtonFormField<String>(
          initialValue:
              enumValues.contains(current) ? current : enumValues.first,
          decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          items: [
            for (final value in enumValues)
              DropdownMenuItem(value: value, child: Text(value)),
          ],
          onChanged: _saving ? null : (value) => _setConfigValue(key, value),
        ),
      );
    }

    if (type == 'boolean') {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: description == null ? null : Text(description),
        value: _valueFor(key, prop) == true,
        onChanged: _saving ? null : (value) => _setConfigValue(key, value),
      );
    }

    final controller = _controllerFor(key, prop);
    final multiline = type == 'array' ||
        type == 'object' ||
        prop['format'] == 'textarea' ||
        prop['x-display'] == 'textarea';
    return _PluginConfigFieldFrame(
      label: label,
      description: description,
      encrypted: encrypted,
      child: TextField(
        controller: controller,
        enabled: !_saving,
        obscureText: encrypted,
        maxLines: encrypted ? 1 : (multiline ? 5 : 1),
        keyboardType: type == 'integer' || type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : (multiline ? TextInputType.multiline : TextInputType.text),
        style: TextStyle(
          fontFamily: type == 'array' || type == 'object' ? 'monospace' : null,
        ),
        decoration: InputDecoration(
          hintText: encrypted
              ? context.localeText(
                  '留空则保持原值', 'Leave blank to keep current value')
              : _schemaPlaceholder(context, prop),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final properties = _properties;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.pluginsConfigTitle(widget.plugin.name),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const SizedBox(height: 180, child: LoadingView())
              else
                Flexible(
                  child: properties.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              context.localeText(
                                  '该插件没有配置项', 'No configurable options'),
                              style: TextStyle(color: context.mutedText),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final entry in properties.entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _field(entry.key, entry.value),
                                ),
                            ],
                          ),
                        ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xffdc2626), fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      child: Text(context.l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: context.l10n.commonSave,
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

class _PluginConfigFieldFrame extends StatelessWidget {
  const _PluginConfigFieldFrame({
    required this.label,
    required this.child,
    this.description,
    this.encrypted = false,
  });

  final String label;
  final String? description;
  final bool encrypted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (encrypted)
              Tooltip(
                message: context.localeText('本字段会加密保存', 'Stored encrypted'),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: context.mutedText,
                ),
              ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description!,
              style: TextStyle(color: context.mutedText, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

String _schemaType(Map<String, dynamic> prop) {
  final type = prop['type'];
  if (type is String && type.trim().isNotEmpty) return type.trim();
  return 'string';
}

List<String> _schemaEnum(Map<String, dynamic> prop) {
  final values = prop['enum'];
  if (values is! List) return const [];
  return values.map((value) => value.toString()).toList();
}

bool _isEncryptedField(Map<String, dynamic> prop) {
  return prop['x-encrypted'] == true ||
      prop['encrypted'] == true ||
      prop['format'] == 'password' ||
      prop['format'] == 'secret';
}

String _editorTextForValue(Object? value, Map<String, dynamic> prop) {
  if (_isEncryptedField(prop) &&
      value == _PluginConfigDialogState._secretPlaceholder) {
    return '';
  }
  if (value == null) return '';
  final type = _schemaType(prop);
  if (type == 'array' || type == 'object') {
    return _prettyLibraryJson(value);
  }
  return value.toString();
}

String _schemaLabel(
    BuildContext context, String key, Map<String, dynamic> prop) {
  return _schemaText(context, prop['title_i18n']) ??
      _schemaText(context, prop['label_i18n']) ??
      _schemaText(context, prop['title']) ??
      _schemaText(context, prop['label']) ??
      _humanizePluginField(key);
}

String? _schemaDescription(BuildContext context, Map<String, dynamic> prop) {
  return _schemaText(context, prop['description_i18n']) ??
      _schemaText(context, prop['description']);
}

String? _schemaPlaceholder(BuildContext context, Map<String, dynamic> prop) {
  return _schemaText(context, prop['placeholder_i18n']) ??
      _schemaText(context, prop['placeholder']);
}

String? _schemaText(BuildContext context, Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is! Map) return null;
  final language = Localizations.localeOf(context).languageCode.toLowerCase();
  final preferred = language.startsWith('en')
      ? const ['en', 'en-US', 'en_US']
      : const ['zh', 'zh-CN', 'zh_CN', 'zh-Hans', 'zh_Hans'];
  final fallback = language.startsWith('en')
      ? const ['zh', 'zh-CN', 'zh_CN', 'zh-Hans', 'zh_Hans']
      : const ['en', 'en-US', 'en_US'];
  for (final key in [...preferred, ...fallback]) {
    final text = value[key]?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  for (final item in value.values) {
    final text = item?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

String _humanizePluginField(String key) {
  return key
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
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

String _pluginTypeLabel(BuildContext context, String type) {
  switch (type) {
    case 'scraper':
      return context.l10n.pluginsCategoryMetadata;
    case 'format':
      return context.l10n.pluginsCategoryFormat;
    case 'utility':
      return context.l10n.pluginsCategoryUtility;
    default:
      return type.isNotEmpty ? type : context.localeText('未知', 'Unknown');
  }
}

String _pluginSupportLabel(String support) {
  return support;
}

int _metadataCapabilityListCount(
    List<PluginCapability> capabilities, String key) {
  var count = 0;
  for (final capability in capabilities) {
    if (capability.kind != 'metadata_provider') continue;
    final direct = capability.extra[key];
    final metadata = capability.extra['metadata'];
    final nested = metadata is Map ? metadata[key] : null;
    final value = direct is List ? direct : nested;
    if (value is List) count += value.length;
  }
  return count;
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

bool _usesClientExtension(PluginItem item) {
  return item.capabilities.any(
    (capability) =>
        capability.kind == 'ui_extension' ||
        capability.kind == 'client_extension',
  );
}

List<String> _pluginRiskSignals(BuildContext context, PluginItem item) {
  final signals = <String>{};

  if (item.adminOnly) {
    signals.add(context.localeText('仅管理员', 'Admin only'));
  }

  for (final permission in item.permissions.map(_normalizePluginPermission)) {
    if (permission.contains('network')) {
      signals.add(context.localeText('网络访问', 'Network'));
    }
    if (permission == 'database_read' ||
        permission == 'books_read' ||
        permission == 'chapters_read' ||
        permission == 'media_read' ||
        permission == 'media_read_url') {
      signals.add(context.localeText('书库读取', 'Library read'));
    }
    if (permission.endsWith('_write') ||
        permission == 'metadata_write' ||
        permission == 'cache_write') {
      signals.add(context.localeText('写入能力', 'Write access'));
    }
    if (permission == 'cache_read' || permission == 'cache_write') {
      signals.add(context.localeText('缓存访问', 'Cache access'));
    }
    if (permission == 'task_create') {
      signals.add(context.localeText('创建任务', 'Task create'));
    }
    if (permission == 'progress_read') {
      signals.add(context.localeText('播放进度', 'Playback progress'));
    }
  }

  for (final capability in item.capabilities) {
    switch (capability.kind) {
      case 'http_route':
        final auth = _capabilityRouteAuth(capability);
        if (auth == 'public') {
          signals.add(context.localeText('公开 HTTP', 'Public HTTP'));
        } else if (auth == 'signed' || auth == 'public_or_signed') {
          signals.add(context.localeText('签名 HTTP', 'Signed HTTP'));
        } else {
          signals.add(context.localeText('HTTP 路由', 'HTTP route'));
        }
        break;
      case 'ui_extension':
      case 'client_extension':
        final mode = _capabilityRenderMode(capability);
        if (mode.contains('floating')) {
          signals.add(context.localeText('悬浮 UI', 'Floating UI'));
        } else if (mode == 'web_container') {
          signals.add(context.localeText('Web UI', 'Web UI'));
        } else {
          signals.add(context.localeText('前端 UI', 'Client UI'));
        }
        break;
      case 'tool_provider':
        signals.add(context.localeText('工具能力', 'Tool provider'));
        break;
      case 'content_processor':
        signals.add(context.localeText('文档处理', 'Document reader'));
        break;
      case 'task_handler':
        signals.add(context.localeText('后台任务', 'Background task'));
        break;
      case 'event_handler':
        signals.add(context.localeText('事件订阅', 'Event hook'));
        break;
    }
  }

  return signals.toList();
}

String _previewChipLabels(List<String> values, {required int limit}) {
  if (values.length <= limit) return values.join(', ');
  return '${values.take(limit).join(', ')} +${values.length - limit}';
}

String _normalizePluginPermission(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String _capabilityRenderMode(PluginCapability capability) {
  final render = capability.extra['render'];
  final value = render is Map
      ? render['mode']
      : capability.extra['render_mode'] ?? capability.extra['mode'];
  return value?.toString().trim().toLowerCase() ?? '';
}

String _capabilityRouteAuth(PluginCapability capability) {
  final route = capability.extra['route'];
  final value = route is Map ? route['auth'] : capability.extra['auth'];
  return value?.toString().trim().toLowerCase() ?? '';
}

String? _localizedText(Map<String, String> values, BuildContext context) {
  if (values.isEmpty) return null;
  final locale = Localizations.localeOf(context);
  final language = locale.languageCode.toLowerCase();
  final country = locale.countryCode?.toLowerCase();
  final candidates = <String>[
    if (country != null && country.isNotEmpty) '$language-$country',
    language,
    language.startsWith('en') ? 'en' : 'zh',
    language.startsWith('en') ? 'zh' : 'en',
  ];

  for (final key in candidates) {
    final direct = values[key]?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    for (final entry in values.entries) {
      if (entry.key.replaceAll('_', '-').toLowerCase() == key) {
        final value = entry.value.trim();
        if (value.isNotEmpty) return value;
      }
    }
  }

  for (final value in values.values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String _formatPluginVersion(String? version) {
  if (version == null || version.isEmpty) return 'v?';
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
