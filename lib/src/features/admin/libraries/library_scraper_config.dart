part of '../admin_pages.dart';

class _ScraperConfigTab {
  const _ScraperConfigTab({
    required this.id,
    required this.label,
    required this.key,
  });

  final String id;
  final String label;
  final String key;
}

class _ScraperSourceChoice {
  const _ScraperSourceChoice({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class _ScraperSource {
  const _ScraperSource({
    required this.id,
    required this.name,
    required this.autoScrape,
  });

  final String id;
  final String name;
  final bool autoScrape;

  factory _ScraperSource.fromJson(Map<String, dynamic> json) {
    return _ScraperSource(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed plugin',
      autoScrape: json['auto_scrape'] == true,
    );
  }
}

class _ScraperConfigPanel extends StatefulWidget {
  const _ScraperConfigPanel({
    required this.controller,
    required this.libraryType,
    required this.sources,
    required this.sourcesLoading,
  });

  final TextEditingController controller;
  final String libraryType;
  final List<_ScraperSource> sources;
  final bool sourcesLoading;

  @override
  State<_ScraperConfigPanel> createState() => _ScraperConfigPanelState();
}

class _ScraperConfigPanelState extends State<_ScraperConfigPanel> {
  bool _showJson = false;
  String _activeTab = 'default';

  static const _tabs = [
    _ScraperConfigTab(
      id: 'priority',
      label: 'priority',
      key: 'metadata_priority',
    ),
    _ScraperConfigTab(
      id: 'default',
      label: 'default',
      key: 'default_sources',
    ),
    _ScraperConfigTab(
      id: 'cover',
      label: 'cover',
      key: 'cover_sources',
    ),
    _ScraperConfigTab(
      id: 'intro',
      label: 'intro',
      key: 'intro_sources',
    ),
    _ScraperConfigTab(
      id: 'author',
      label: 'author',
      key: 'author_sources',
    ),
    _ScraperConfigTab(
      id: 'narrator',
      label: 'narrator',
      key: 'narrator_sources',
    ),
    _ScraperConfigTab(
      id: 'tags',
      label: 'tags',
      key: 'tags_sources',
    ),
  ];

  static const _prioritySources = [
    _ScraperSourceChoice(id: 'local_metadata', name: 'local_metadata'),
    _ScraperSourceChoice(id: 'audio_metadata', name: 'audio_metadata'),
    _ScraperSourceChoice(id: 'scraper', name: 'scraper'),
  ];

  Map<String, dynamic> _config() {
    try {
      final decoded = jsonDecode(widget.controller.text);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return Map<String, dynamic>.from(_defaultLibraryScraperConfig);
  }

  bool _boolValue(String key, bool fallback) {
    final config = _config();
    final value = config[key];
    return value is bool ? value : fallback;
  }

  void _setBool(String key, bool value) {
    final config = _config();
    config[key] = value;
    widget.controller.text = _prettyLibraryJson(config);
    setState(() {});
  }

  _ScraperConfigTab get _currentTab =>
      _tabs.firstWhere((tab) => tab.id == _activeTab, orElse: () => _tabs[1]);

  List<String> _stringListFor(_ScraperConfigTab tab) {
    final config = _config();
    final raw = config[tab.key];
    if (raw is List) return raw.map((value) => value.toString()).toList();
    if (tab.id == 'priority') {
      return _prioritySources.map((source) => source.id).toList();
    }
    return const [];
  }

  void _setListFor(_ScraperConfigTab tab, List<String> ids) {
    final config = _config();
    config[tab.key] = ids;
    widget.controller.text = _prettyLibraryJson(config);
    setState(() {});
  }

  List<_ScraperSourceChoice> _choicesFor(_ScraperConfigTab tab) {
    if (tab.id == 'priority') return _prioritySources;
    return widget.sources
        .map((source) => _ScraperSourceChoice(id: source.id, name: source.name))
        .toList();
  }

  _ScraperSourceChoice _choiceById(
    List<_ScraperSourceChoice> choices,
    String id,
  ) {
    return choices.firstWhere(
      (choice) => choice.id == id,
      orElse: () => _ScraperSourceChoice(id: id, name: id),
    );
  }

  void _addSource(_ScraperConfigTab tab, String id) {
    final ids = [..._stringListFor(tab), id];
    _setListFor(tab, ids);
  }

  void _removeSource(_ScraperConfigTab tab, String id) {
    final ids = _stringListFor(tab).where((item) => item != id).toList();
    _setListFor(tab, ids);
  }

  void _moveSource(_ScraperConfigTab tab, int index, int delta) {
    final ids = _stringListFor(tab);
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= ids.length) return;
    final item = ids.removeAt(index);
    ids.insert(nextIndex, item);
    _setListFor(tab, ids);
  }

  @override
  Widget build(BuildContext context) {
    final nfo = _boolValue('nfo_writing_enabled', false);
    final metadata = _boolValue('metadata_writing_enabled', false);
    final preferTitle = _boolValue('use_filename_as_title', true);
    final extractCover = _boolValue('extract_audio_cover', true);
    final watcherEnabled = !_boolValue('disable_watcher', false);
    final cloudMode = _boolValue('cloud_mode', false);
    final tab = _currentTab;
    final choices = _choicesFor(tab);
    final activeIds = _stringListFor(tab)
        .where((id) => tab.id == 'priority' || choices.any((s) => s.id == id))
        .toList();
    final activeSources =
        activeIds.map((id) => _choiceById(choices, id)).toList();
    final availableSources = tab.id == 'priority'
        ? const <_ScraperSourceChoice>[]
        : choices.where((source) => !activeIds.contains(source.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: DialogLabel(
                    context.localeText('刮削源配置', 'Scraper Sources'),
                    fontSize: 14)),
            TextButton(
              onPressed: () => setState(() => _showJson = !_showJson),
              child: Text(_showJson
                  ? context.localeText('切换至简易模式', 'Simple Mode')
                  : context.localeText('切换至高级模式 (JSON)', 'Advanced (JSON)')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_showJson)
          TextFormField(
            controller: widget.controller,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              hintText: '{"default_sources": ["ximalaya-scraper-wasm"]}',
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.isDark ? AppColors.slate800 : AppColors.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.faintBorder),
            ),
            child: Column(
              children: [
                _ConfigSwitchRow(
                  title:
                      context.localeText('启用 NFO 元数据写入', 'Write NFO metadata'),
                  subtitle: context.localeText('刮削或修改元数据时同步写入 book.nfo 文件',
                      'Write book.nfo when scraping or editing metadata'),
                  value: nfo,
                  onChanged: (value) => _setBool('nfo_writing_enabled', value),
                ),
                _ConfigSwitchRow(
                  title: context.localeText(
                      '写入 metadata.json', 'Write metadata.json'),
                  subtitle: context.localeText(
                      '生成 Audiobookshelf 兼容的 metadata.json 文件',
                      'Generate an Audiobookshelf-compatible metadata.json file'),
                  value: metadata,
                  onChanged: (value) =>
                      _setBool('metadata_writing_enabled', value),
                ),
                _ConfigSwitchRow(
                  title: context.localeText(
                      '优先使用文件/文件夹名作为标题', 'Prefer file/folder title'),
                  subtitle: context.localeText('忽略优先级配置，强制使用路径名称',
                      'Ignore source priority and use the path name'),
                  value: preferTitle,
                  onChanged: (value) =>
                      _setBool('use_filename_as_title', value),
                ),
                _ConfigSwitchRow(
                  title: context.localeText('提取音频封面', 'Extract audio cover'),
                  subtitle: context.localeText('系统或插件将尝试从音频文件中提取封面',
                      'System or plugins will try to extract cover art from audio files'),
                  value: extractCover,
                  onChanged: (value) => _setBool('extract_audio_cover', value),
                ),
                if (widget.libraryType == 'local')
                  _ConfigSwitchRow(
                    title: context.localeText(
                        '自动检测媒体库变化', 'Watch library changes'),
                    subtitle: context.localeText('监控目录变化并自动触发扫描',
                        'Monitor folders and trigger scans automatically'),
                    value: watcherEnabled,
                    onChanged: (value) => _setBool(
                      'disable_watcher',
                      !value,
                    ),
                  ),
                _ConfigSwitchRow(
                  title: context.localeText('网盘模式（减少远程音频探测）', 'Cloud mode'),
                  subtitle: context.localeText('优先使用元数据文件，减少远程音频读取',
                      'Prefer metadata files and reduce remote audio reads'),
                  value: cloudMode,
                  last: true,
                  onChanged: (value) => _setBool('cloud_mode', value),
                ),
                const SizedBox(height: 16),
                _ScraperTabBar(
                  tabs: _tabs,
                  activeTab: _activeTab,
                  onChanged: (value) => setState(() => _activeTab = value),
                ),
                const SizedBox(height: 14),
                if (widget.sourcesLoading && tab.id != 'priority')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary600,
                        ),
                      ),
                    ),
                  )
                else
                  _ScraperSourceGrid(
                    tab: tab,
                    activeSources: activeSources,
                    availableSources: availableSources,
                    onMove: (index, delta) => _moveSource(tab, index, delta),
                    onRemove: (id) => _removeSource(tab, id),
                    onAdd: (id) => _addSource(tab, id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

String _scraperTabLabel(BuildContext context, _ScraperConfigTab tab) {
  switch (tab.id) {
    case 'priority':
      return context.localeText('优先级', 'Priority');
    case 'default':
      return context.localeText('默认', 'Default');
    case 'cover':
      return context.localeText('封面', 'Cover');
    case 'intro':
      return context.localeText('简介', 'Description');
    case 'author':
      return context.localeText('作者', 'Author');
    case 'narrator':
      return context.localeText('演播', 'Narrator');
    case 'tags':
      return context.localeText('标签', 'Tags');
    default:
      return tab.label;
  }
}

String _scraperSourceChoiceName(
    BuildContext context, _ScraperSourceChoice source) {
  switch (source.id) {
    case 'local_metadata':
      return context.localeText(
          '本地元数据 (JSON/NFO)', 'Local metadata (JSON/NFO)');
    case 'audio_metadata':
      return context.localeText('音频文件元数据 (ID3)', 'Audio metadata (ID3)');
    case 'scraper':
      return context.localeText('刮削器 (Plugins)', 'Scraper (Plugins)');
    default:
      return source.name;
  }
}

class _ScraperTabBar extends StatelessWidget {
  const _ScraperTabBar({
    required this.tabs,
    required this.activeTab,
    required this.onChanged,
  });

  final List<_ScraperConfigTab> tabs;
  final String activeTab;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.faintBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            for (final tab in tabs) ...[
              _ScraperTabButton(
                label: _scraperTabLabel(context, tab),
                selected: activeTab == tab.id,
                onPressed: () => onChanged(tab.id),
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScraperTabButton extends StatelessWidget {
  const _ScraperTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected ? context.cardColor : Colors.transparent,
        foregroundColor: selected ? AppColors.primary600 : context.mutedText,
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ScraperSourceGrid extends StatelessWidget {
  const _ScraperSourceGrid({
    required this.tab,
    required this.activeSources,
    required this.availableSources,
    required this.onMove,
    required this.onRemove,
    required this.onAdd,
  });

  final _ScraperConfigTab tab;
  final List<_ScraperSourceChoice> activeSources;
  final List<_ScraperSourceChoice> availableSources;
  final void Function(int index, int delta) onMove;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 520 && tab.id != 'priority';
        final active = _ScraperSourceColumn(
          title: tab.id == 'priority'
              ? context.localeText('元数据来源优先级排序', 'Metadata source priority')
              : context.localeText('已启用（按优先级排序）', 'Enabled by priority'),
          count: activeSources.length,
          emptyTitle: context.localeText('暂无启用的源', 'No enabled sources'),
          emptySubtitle: tab.id == 'priority'
              ? ''
              : context.localeText('请从右侧添加', 'Add from the right'),
          child: Column(
            children: [
              for (var i = 0; i < activeSources.length; i++)
                _ActiveScraperSourceRow(
                  source: activeSources[i],
                  first: i == 0,
                  last: i == activeSources.length - 1,
                  removable: tab.id != 'priority',
                  onMoveUp: () => onMove(i, -1),
                  onMoveDown: () => onMove(i, 1),
                  onRemove: () => onRemove(activeSources[i].id),
                ),
            ],
          ),
        );

        final available = _ScraperSourceColumn(
          title: context.localeText('可用插件', 'Available plugins'),
          count: availableSources.length,
          mutedCount: true,
          emptyTitle: context.localeText('没有更多可用插件', 'No more plugins'),
          emptySubtitle: '',
          child: Column(
            children: [
              for (final source in availableSources)
                _AvailableScraperSourceRow(
                  source: source,
                  onAdd: () => onAdd(source.id),
                ),
            ],
          ),
        );

        if (!split) {
          return Column(
            children: [
              active,
              if (tab.id != 'priority') ...[
                const SizedBox(height: 14),
                available,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: active),
            const SizedBox(width: 16),
            Expanded(child: available),
          ],
        );
      },
    );
  }
}

class _ScraperSourceColumn extends StatelessWidget {
  const _ScraperSourceColumn({
    required this.title,
    required this.count,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.child,
    this.mutedCount = false,
  });

  final String title;
  final int count;
  final String emptyTitle;
  final String emptySubtitle;
  final Widget child;
  final bool mutedCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: context.tertiaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: mutedCount ? AppColors.slate400 : AppColors.primary600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.faintBorder),
          ),
          child: count == 0
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        emptyTitle,
                        style: const TextStyle(
                          color: AppColors.slate400,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (emptySubtitle.isNotEmpty)
                        Text(
                          emptySubtitle,
                          style: const TextStyle(
                            color: AppColors.slate400,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                )
              : child,
        ),
      ],
    );
  }
}

class _ActiveScraperSourceRow extends StatelessWidget {
  const _ActiveScraperSourceRow({
    required this.source,
    required this.first,
    required this.last,
    required this.removable,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final _ScraperSourceChoice source;
  final bool first;
  final bool last;
  final bool removable;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _scraperSourceChoiceName(context, source),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          _MiniIconButton(
            icon: Icons.arrow_upward_rounded,
            enabled: !first,
            onPressed: onMoveUp,
          ),
          _MiniIconButton(
            icon: Icons.arrow_downward_rounded,
            enabled: !last,
            onPressed: onMoveDown,
          ),
          _MiniIconButton(
            icon: Icons.close_rounded,
            danger: true,
            enabled: removable,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AvailableScraperSourceRow extends StatelessWidget {
  const _AvailableScraperSourceRow({
    required this.source,
    required this.onAdd,
  });

  final _ScraperSourceChoice source;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: TextButton(
        onPressed: onAdd,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor:
              context.isDark ? AppColors.slate800 : AppColors.slate50,
          foregroundColor: AppColors.primary600,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_rounded, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _scraperSourceChoiceName(context, source),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 26, height: 26),
      splashRadius: 15,
      color: danger ? const Color(0xffef4444) : context.mutedText,
      disabledColor: AppColors.slate300,
      icon: Icon(icon, size: 15),
    );
  }
}

class _ConfigSwitchRow extends StatelessWidget {
  const _ConfigSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: last ? 0 : 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.faintBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              activeColor: AppColors.primary600,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (next) => onChanged(next ?? false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.isDark
                          ? AppColors.slate300
                          : AppColors.slate700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: subtitle,
                  child: const Icon(
                    Icons.help_outline_rounded,
                    size: 16,
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
