part of 'admin_pages.dart';

class PluginLogsPage extends StatefulWidget {
  const PluginLogsPage({
    super.key,
    required this.plugin,
    required this.onBack,
  });

  final PluginItem plugin;
  final VoidCallback onBack;

  @override
  State<PluginLogsPage> createState() => _PluginLogsPageState();
}

class _PluginLogsPageState extends State<PluginLogsPage> {
  static const _pageSize = 100;
  static const _levels = ['', 'DEBUG', 'INFO', 'WARN', 'ERROR'];
  static const _sources = [
    '',
    'code',
    'lifecycle',
    'runtime',
    'gateway',
    'security',
  ];

  bool _loading = true;
  bool _autoRefresh = true;
  String _level = '';
  String _source = '';
  String? _error;
  int _page = 1;
  int _total = 0;
  List<_LogEntry> _logs = [];
  final Set<String> _expandedKeys = {};
  Timer? _timer;

  int get _pageCount => (_total / _pageSize).ceil().clamp(1, 1 << 20);

  String get _encodedPluginId => Uri.encodeComponent(widget.plugin.id);

  @override
  void initState() {
    super.initState();
    _load();
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final response = await AppScope.appOf(context).api.get(
        '/api/v1/plugins/$_encodedPluginId/logs',
        params: {
          'page': _page,
          'page_size': _pageSize,
          if (_level.isNotEmpty) 'level': _level,
          if (_source.isNotEmpty) 'source': _source,
        },
      );
      if (!mounted) return;
      final data = asMap(response.data);
      final logs = asMapList(data['logs']).map(_LogEntry.fromJson).toList();
      setState(() {
        _logs = logs;
        _total = (data['total'] as num?)?.toInt() ?? logs.length;
        _error = null;
        _expandedKeys.removeWhere(
          (key) => !_logs.asMap().entries.any(
                (entry) => _logKey(entry.value, entry.key) == key,
              ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.localeText('插件日志加载失败', 'Failed to load plugin logs');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    if (!_autoRefresh) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _load(silent: true);
    });
  }

  void _setAutoRefresh(bool value) {
    setState(() => _autoRefresh = value);
    _syncTimer();
  }

  void _setLevel(String value) {
    setState(() {
      _level = value;
      _page = 1;
      _expandedKeys.clear();
    });
    _load();
  }

  void _setSource(String value) {
    setState(() {
      _source = value;
      _page = 1;
      _expandedKeys.clear();
    });
    _load();
  }

  Future<void> _setPage(int value) async {
    final next = value.clamp(1, _pageCount);
    if (next == _page) return;
    setState(() {
      _page = next;
      _expandedKeys.clear();
    });
    await _load();
  }

  Future<void> _export() async {
    final response = await AppScope.appOf(context).api.get(
      '/api/v1/plugins/$_encodedPluginId/logs/export',
      params: {
        if (_level.isNotEmpty) 'level': _level,
        if (_source.isNotEmpty) 'source': _source,
      },
    );
    await Clipboard.setData(
      ClipboardData(text: response.data?.toString() ?? ''),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(context.localeText('插件日志已复制', 'Plugin logs copied'))),
    );
  }

  String _logKey(_LogEntry log, int index) =>
      '${log.timestamp}|${log.fields['event_id'] ?? ''}|$index';

  void _toggleExpanded(String key) {
    setState(() {
      if (!_expandedKeys.add(key)) _expandedKeys.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageListView(
      onRefresh: () => _load(),
      children: [
        _PluginLogsHeader(
          plugin: widget.plugin,
          loading: _loading,
          autoRefresh: _autoRefresh,
          onBack: widget.onBack,
          onRefresh: () => _load(),
          onExport: _export,
          onAutoRefreshChanged: _setAutoRefresh,
        ),
        const SizedBox(height: 18),
        _PluginLogsFilters(
          level: _level,
          source: _source,
          total: _total,
          levels: _levels,
          sources: _sources,
          onLevelChanged: _setLevel,
          onSourceChanged: _setSource,
        ),
        const SizedBox(height: 18),
        TingCard(
          radius: 8,
          padding: EdgeInsets.zero,
          child: _buildLogsBody(),
        ),
        if (_pageCount > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton.outlined(
                tooltip: context.localeText('上一页', 'Previous page'),
                onPressed: _page > 1 ? () => _setPage(_page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  '$_page / $_pageCount',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedText),
                ),
              ),
              IconButton.outlined(
                tooltip: context.localeText('下一页', 'Next page'),
                onPressed:
                    _page < _pageCount ? () => _setPage(_page + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
        const SafeBottomSpacer(),
      ],
    );
  }

  Widget _buildLogsBody() {
    if (_loading && _logs.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary600),
        ),
      );
    }
    if (_error != null && _logs.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child:
              Text(_error!, style: const TextStyle(color: Color(0xffdc2626))),
        ),
      );
    }
    if (_logs.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Text(
            context.localeText('暂无插件日志', 'No plugin logs'),
            style: TextStyle(color: context.mutedText),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < _logs.length; index++) ...[
          _PluginLogRow(
            log: _logs[index],
            expanded: _expandedKeys.contains(_logKey(_logs[index], index)),
            onToggleDetails: _logs[index].fields.isEmpty
                ? null
                : () => _toggleExpanded(_logKey(_logs[index], index)),
          ),
          if (index != _logs.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _PluginLogsHeader extends StatelessWidget {
  const _PluginLogsHeader({
    required this.plugin,
    required this.loading,
    required this.autoRefresh,
    required this.onBack,
    required this.onRefresh,
    required this.onExport,
    required this.onAutoRefreshChanged,
  });

  final PluginItem plugin;
  final bool loading;
  final bool autoRefresh;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final ValueChanged<bool> onAutoRefreshChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final title = Row(
          children: [
            IconButton(
              tooltip: context.localeText('返回插件管理', 'Back to plugins'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xffecfeff),
                border: Border.all(color: const Color(0xffcffafe)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.extension_rounded,
                color: Color(0xff0e7490),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.localeText(
                      '${plugin.name} 日志',
                      '${plugin.name} Logs',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 20 : 24),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${plugin.id} · ${_formatPluginVersion(plugin.version)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.mutedText, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton.outlined(
              tooltip: context.localeText('刷新', 'Refresh'),
              onPressed: loading ? null : onRefresh,
              icon: Icon(
                loading ? Icons.hourglass_empty_rounded : Icons.refresh_rounded,
                size: 19,
              ),
            ),
            IconButton.outlined(
              tooltip: context.localeText('导出日志', 'Export logs'),
              onPressed: onExport,
              icon: const Icon(Icons.download_rounded, size: 19),
            ),
            _AutoRefreshSwitch(
              value: autoRefresh,
              onChanged: onAutoRefreshChanged,
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: actions),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 20),
            actions,
          ],
        );
      },
    );
  }
}

class _PluginLogsFilters extends StatelessWidget {
  const _PluginLogsFilters({
    required this.level,
    required this.source,
    required this.total,
    required this.levels,
    required this.sources,
    required this.onLevelChanged,
    required this.onSourceChanged,
  });

  final String level;
  final String source;
  final int total;
  final List<String> levels;
  final List<String> sources;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onSourceChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: context.faintBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _LogSelect(
                  label: context.localeText('等级', 'Level'),
                  width: 172,
                  value: level,
                  items: [
                    for (final item in levels)
                      (
                        item,
                        item.isEmpty
                            ? context.localeText('全部等级', 'All levels')
                            : item,
                      ),
                  ],
                  onChanged: onLevelChanged,
                ),
                _LogSelect(
                  label: context.localeText('来源', 'Source'),
                  width: 220,
                  value: source,
                  items: [
                    for (final item in sources)
                      (
                        item,
                        item.isEmpty
                            ? context.localeText('全部来源', 'All sources')
                            : _pluginLogSourceLabel(context, item),
                      ),
                  ],
                  onChanged: onSourceChanged,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            context.localeText('共 $total 条', '$total total'),
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PluginLogRow extends StatelessWidget {
  const _PluginLogRow({
    required this.log,
    required this.expanded,
    required this.onToggleDetails,
  });

  final _LogEntry log;
  final bool expanded;
  final VoidCallback? onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final fields = log.fields;
    final instanceId = fields['plugin_instance_id']?.toString();
    final runtime = fields['runtime']?.toString();
    final source = fields['source']?.toString();
    final operation = fields['op']?.toString();
    final eventId = fields['event_id']?.toString();
    final message = (log.rawMessage?.trim().isNotEmpty ?? false)
        ? log.rawMessage!
        : log.message;
    final accent = _levelColor(log.level);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: context.isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.extension_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _LevelChip(level: log.level),
                    if (instanceId != null && instanceId.isNotEmpty)
                      _PluginLogChip(
                          label: instanceId, color: const Color(0xff0e7490)),
                    if (runtime != null && runtime.isNotEmpty)
                      _PluginLogChip(label: runtime.toUpperCase()),
                    if (source != null && source.isNotEmpty)
                      _PluginLogChip(
                        label: _pluginLogSourceLabel(context, source),
                      ),
                    if (operation != null && operation.isNotEmpty)
                      _PluginLogChip(
                        label: operation,
                        color: const Color(0xff047857),
                      ),
                    Text(
                      _formatLogTime(context, log.timestamp),
                      style:
                          TextStyle(color: context.tertiaryText, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  message,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                if (eventId != null && eventId.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  SelectableText(
                    'event_id: $eventId',
                    style: TextStyle(
                      color: context.tertiaryText,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ],
                if (onToggleDetails != null) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onToggleDetails,
                    style: TextButton.styleFrom(
                      foregroundColor: context.mutedText,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 16,
                    ),
                    label: Text(context.localeText('详情', 'Details')),
                  ),
                ],
                if (expanded && fields.isNotEmpty)
                  _LogFieldsGrid(fields: fields),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginLogChip extends StatelessWidget {
  const _PluginLogChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? context.mutedText;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: context.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: foreground, fontSize: 11),
      ),
    );
  }
}

String _pluginLogSourceLabel(BuildContext context, String source) {
  return switch (source) {
    'code' => context.localeText('插件代码', 'Code'),
    'lifecycle' => context.localeText('生命周期', 'Lifecycle'),
    'runtime' => context.localeText('运行时', 'Runtime'),
    'gateway' => context.localeText('主机网关', 'Gateway'),
    'security' => context.localeText('安全', 'Security'),
    _ => source,
  };
}
