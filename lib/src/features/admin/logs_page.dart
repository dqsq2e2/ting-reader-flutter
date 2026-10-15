part of 'admin_pages.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  bool _loading = true;
  bool _autoRefresh = true;
  String _moduleFilter = 'audit';
  String _levelFilter = '';
  String _pluginFilter = '';
  String _pluginSourceFilter = '';
  String _pluginSearch = '';
  List<PluginItem> _plugins = [];
  int _total = 0;
  List<LogEntry> _logs = [];
  final Set<String> _expandedLogKeys = {};
  final TextEditingController _pluginSearchController = TextEditingController();
  LogState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state != null) return;
    _state = LogState(AppScope.appOf(context).api)..addListener(_logsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _state?.start();
    });
  }

  void _logsChanged() {
    final state = _state;
    if (!mounted || state == null) return;
    setState(() {
      _loading = state.loading;
      _logs = state.logs;
      _total = state.total;
      _plugins = state.plugins;
      _expandedLogKeys.removeWhere((key) => !_logs
          .asMap()
          .entries
          .any((entry) => _logKey(entry.value, entry.key) == key));
    });
  }

  @override
  void dispose() {
    _state?.removeListener(_logsChanged);
    _state?.dispose();
    _pluginSearchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final state = _state;
    if (state == null) return;
    state
      ..module = _moduleFilter
      ..level = _levelFilter
      ..plugin = _pluginFilter
      ..source = _pluginSourceFilter
      ..search = _pluginSearch;
    await state.load(silent: silent);
  }

  Future<void> _clear() async {
    final ok = await _confirm(
      title: context.localeText('清空日志', 'Clear Logs'),
      message: context.localeText('确定要清空所有日志和任务记录吗？这将删除核心日志、插件日志和已完成/失败的任务。',
          'Clear all core logs, plugin logs, and completed or failed tasks?'),
      action: context.localeText('清空', 'Clear'),
    );
    if (!ok || !mounted) return;

    await _state?.clear();
    _expandedLogKeys.clear();
    await _load();
  }

  Future<void> _cancelTask(String taskId) async {
    await _state?.cancelTask(taskId);
  }

  Future<void> _deleteTask(String taskId) async {
    final ok = await _confirm(
      title: context.localeText('删除任务记录', 'Delete Task Record'),
      message: context.localeText('确定要删除这条任务记录吗？', 'Delete this task record?'),
      action: context.localeText('删除', 'Delete'),
    );
    if (!ok || !mounted) return;

    await _state?.deleteTask(taskId);
  }

  Future<void> _export({String? level}) async {
    final text = await _state?.export(level: level);
    if (!mounted || text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(level == 'ERROR'
            ? context.localeText('错误日志已复制', 'Error logs copied')
            : context.localeText('日志已复制', 'Logs copied'))));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _setAutoRefresh(bool value) {
    setState(() => _autoRefresh = value);
    _state?.setAutoRefresh(value);
  }

  void _setModule(String value) {
    setState(() {
      _moduleFilter = value;
      _expandedLogKeys.clear();
    });
    _load();
  }

  void _setLevel(String value) {
    setState(() => _levelFilter = value);
    _load();
  }

  void _setPlugin(String value) {
    setState(() {
      _pluginFilter = value;
      _expandedLogKeys.clear();
    });
    _load();
  }

  void _setPluginSource(String value) {
    setState(() {
      _pluginSourceFilter = value;
      _expandedLogKeys.clear();
    });
    _load();
  }

  void _setPluginSearch(String value) {
    setState(() {
      _pluginSearch = value;
      _expandedLogKeys.clear();
    });
    _load();
  }

  void _resetPluginFilters() {
    _pluginSearchController.clear();
    setState(() {
      _pluginFilter = '';
      _pluginSourceFilter = '';
      _pluginSearch = '';
      _expandedLogKeys.clear();
    });
    _load();
  }

  VoidCallback? _taskAction(String? id, Future<void> Function(String) action) =>
      id == null ? null : () => action(id);

  String _logKey(LogEntry log, int index) {
    return [
      log.taskId ?? '',
      log.timestamp,
      log.module,
      log.messageKey ?? log.message,
      index,
    ].join('|');
  }

  void _toggleLogDetails(String key) {
    setState(() {
      if (_expandedLogKeys.contains(key)) {
        _expandedLogKeys.remove(key);
      } else {
        _expandedLogKeys.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageListView(
      onRefresh: () => _load(),
      children: [
        _LogsHeader(
          moduleFilter: _moduleFilter,
          levelFilter: _levelFilter,
          autoRefresh: _autoRefresh,
          loading: _loading,
          onModuleChanged: _setModule,
          onLevelChanged: _setLevel,
          onClear: _clear,
          onExportAll: () => _export(),
          onExportError: () => _export(level: 'ERROR'),
          onAutoRefreshChanged: _setAutoRefresh,
          onRefresh: () => _load(),
        ),
        if (_moduleFilter == 'plugins') ...[
          const SizedBox(height: 18),
          _SystemPluginLogFilters(
            plugins: _plugins,
            plugin: _pluginFilter,
            source: _pluginSourceFilter,
            total: _total,
            searchController: _pluginSearchController,
            onPluginChanged: _setPlugin,
            onSourceChanged: _setPluginSource,
            onSearchSubmitted: _setPluginSearch,
            onReset: _resetPluginFilters,
          ),
        ],
        const SizedBox(height: 24),
        if (_state?.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
                context.localeText(
                    '日志加载失败，请重试', 'Failed to load logs. Please retry.'),
                style: const TextStyle(color: Colors.red)),
          ),
        TingCard(
          padding: EdgeInsets.zero,
          radius: 24,
          child: Column(
            children: [
              if (_loading && _logs.isEmpty)
                const SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary600,
                    ),
                  ),
                )
              else if (_logs.isEmpty)
                const _LogsEmptyState()
              else
                Column(
                  children: [
                    for (var i = 0; i < _logs.length; i++) ...[
                      if (_moduleFilter == 'plugins')
                        _PluginLogRow(
                          log: _logs[i],
                          expanded:
                              _expandedLogKeys.contains(_logKey(_logs[i], i)),
                          onToggleDetails: _logs[i].fields.isEmpty
                              ? null
                              : () => _toggleLogDetails(_logKey(_logs[i], i)),
                        )
                      else
                        _LogRow(
                          log: _logs[i],
                          expanded:
                              _expandedLogKeys.contains(_logKey(_logs[i], i)),
                          onToggleDetails: _logs[i].fields.isEmpty
                              ? null
                              : () => _toggleLogDetails(_logKey(_logs[i], i)),
                          onCancelTask:
                              _taskAction(_logs[i].taskId, _cancelTask),
                          onDeleteTask:
                              _taskAction(_logs[i].taskId, _deleteTask),
                        ),
                      if (i != _logs.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogsHeader extends StatelessWidget {
  const _LogsHeader({
    required this.moduleFilter,
    required this.levelFilter,
    required this.autoRefresh,
    required this.loading,
    required this.onModuleChanged,
    required this.onLevelChanged,
    required this.onClear,
    required this.onExportAll,
    required this.onExportError,
    required this.onAutoRefreshChanged,
    required this.onRefresh,
  });

  final String moduleFilter;
  final String levelFilter;
  final bool autoRefresh;
  final bool loading;
  final ValueChanged<String> onModuleChanged;
  final ValueChanged<String> onLevelChanged;
  final VoidCallback onClear;
  final VoidCallback onExportAll;
  final VoidCallback onExportError;
  final ValueChanged<bool> onAutoRefreshChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final controls = Wrap(
          spacing: compact ? 8 : 12,
          runSpacing: 10,
          alignment: compact ? WrapAlignment.center : WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _LogSelect(
              label: context.localeText('模块', 'Module'),
              width: compact ? 172 : 164,
              value: moduleFilter,
              items: [
                ('audit', context.localeText('全部核心日志', 'Core')),
                ('audit::login', context.localeText('登录记录', 'Login')),
                ('audit::playback', context.localeText('播放记录', 'Playback')),
                ('audit::scan', context.localeText('扫描记录', 'Scan')),
                ('audit::metadata', context.localeText('元数据记录', 'Metadata')),
                ('audit::library', context.localeText('存储库记录', 'Library')),
                (
                  'audit::notification',
                  context.localeText('通知记录', 'Notification')
                ),
                ('plugins', context.localeText('插件日志', 'Plugin Logs')),
                ('all', context.localeText('系统所有日志', 'All')),
              ],
              onChanged: onModuleChanged,
            ),
            _LogSelect(
              label: context.localeText('等级', 'Level'),
              width: 130,
              value: levelFilter,
              items: [
                ('', context.localeText('全部', 'All')),
                ('INFO', 'INFO'),
                ('WARN', 'WARN'),
                ('ERROR', 'ERROR'),
              ],
              onChanged: onLevelChanged,
            ),
            _LogActionButton(
              icon: Icons.cleaning_services_rounded,
              label: context.localeText('清空', 'Clear'),
              onPressed: onClear,
            ),
            PopupMenuButton<String>(
              tooltip: context.localeText('更多', 'More'),
              onSelected: (value) {
                if (value == 'all') onExportAll();
                if (value == 'error') onExportError();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'all',
                    child:
                        Text(context.localeText('导出所有日志', 'Export All Logs'))),
                PopupMenuItem(
                    value: 'error',
                    child: Text(
                        context.localeText('导出错误日志', 'Export Error Logs'))),
              ],
              child: _LogActionButtonVisual(
                icon: Icons.more_horiz_rounded,
                label: context.localeText('更多', 'More'),
              ),
            ),
            _AutoRefreshSwitch(
              value: autoRefresh,
              onChanged: onAutoRefreshChanged,
            ),
            _LogRefreshButton(loading: loading, onPressed: onRefresh),
          ],
        );
        final header = _LogsTitle(compact: compact);
        if (constraints.maxWidth < 1144) {
          return Column(
            crossAxisAlignment: constraints.maxWidth < 620
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 18),
              Align(
                alignment: constraints.maxWidth < 620
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: controls,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: header,
            ),
            const Spacer(),
            controls,
          ],
        );
      },
    );
  }
}

class _LogsTitle extends StatelessWidget {
  const _LogsTitle({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              compact ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            const Icon(
              Icons.terminal_rounded,
              color: AppColors.primary600,
              size: 30,
            ),
            const SizedBox(width: 12),
            Text(
              context.localeText('系统日志', 'System Logs'),
              style: TextStyle(
                fontSize: compact ? 24 : 30,
                height: 1.15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          context.localeText('实时监控系统后台运行状态与任务进度',
              'Monitor backend status and task progress in real time'),
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            color: context.mutedText,
          ),
        ),
      ],
    );
  }
}

class _SystemPluginLogFilters extends StatelessWidget {
  const _SystemPluginLogFilters({
    required this.plugins,
    required this.plugin,
    required this.source,
    required this.total,
    required this.searchController,
    required this.onPluginChanged,
    required this.onSourceChanged,
    required this.onSearchSubmitted,
    required this.onReset,
  });

  final List<PluginItem> plugins;
  final String plugin;
  final String source;
  final int total;
  final TextEditingController searchController;
  final ValueChanged<String> onPluginChanged;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    const sources = ['', 'code', 'lifecycle', 'runtime', 'gateway', 'security'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.faintBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final searchField = SizedBox(
            height: 40,
            child: TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: onSearchSubmitted,
              decoration: InputDecoration(
                hintText: context.localeText(
                  '搜索消息、事件 ID、运行时或操作...',
                  'Search message, event ID, runtime, or operation...',
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                suffixIcon: IconButton(
                  tooltip: context.localeText('搜索', 'Search'),
                  onPressed: () => onSearchSubmitted(searchController.text),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          );
          final resetButton = Tooltip(
            message: context.localeText('重置筛选', 'Reset filters'),
            child: Material(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onReset,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.faintBorder),
                  ),
                  child: Icon(
                    LucideIcons.rotateCcw,
                    size: 18,
                    color: context.mutedText,
                  ),
                ),
              ),
            ),
          );
          final filters = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LogSelect(
                label: context.localeText('插件', 'Plugin'),
                width: compact ? constraints.maxWidth : 270,
                value: plugin,
                items: [
                  ('', context.localeText('全部插件', 'All plugins')),
                  for (final item in plugins) (item.id, item.name),
                ],
                onChanged: onPluginChanged,
              ),
              _LogSelect(
                label: context.localeText('来源', 'Source'),
                width: compact ? constraints.maxWidth : 220,
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
              if (compact)
                SizedBox(
                  width: constraints.maxWidth,
                  child: Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 10),
                      resetButton,
                    ],
                  ),
                )
              else ...[
                SizedBox(width: 360, child: searchField),
                resetButton,
              ],
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                filters,
                const SizedBox(height: 10),
                Text(
                  context.localeText('共 $total 条', '$total total'),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: filters),
              const SizedBox(width: 12),
              Text(
                context.localeText('共 $total 条', '$total total'),
                style: TextStyle(color: context.mutedText, fontSize: 13),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LogSelect extends StatelessWidget {
  const _LogSelect({
    required this.label,
    required this.width,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final double width;
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 40,
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.faintBorder),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  style: TextStyle(
                    color: context.isDark
                        ? AppColors.slate100
                        : AppColors.slate900,
                    fontSize: 14,
                  ),
                  iconSize: 18,
                  items: [
                    for (final item in items)
                      DropdownMenuItem(
                        value: item.$1,
                        child: Text(
                          item.$2,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onChanged(value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogActionButton extends StatelessWidget {
  const _LogActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: context.cardColor,
        foregroundColor: context.mutedText,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: context.faintBorder),
      ),
      icon: Icon(icon, size: 17),
      label: Text(
        label,
      ),
    );
  }
}

class _LogActionButtonVisual extends StatelessWidget {
  const _LogActionButtonVisual({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.faintBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: context.mutedText),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: context.tertiaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoRefreshSwitch extends StatelessWidget {
  const _AutoRefreshSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.faintBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.localeText('自动刷新', 'Auto Refresh'),
              style: TextStyle(
                color: context.mutedText,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 38,
              height: 20,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? AppColors.primary600 : context.faintBorder,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogRefreshButton extends StatelessWidget {
  const _LogRefreshButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.faintBorder),
          ),
          child: Icon(
            loading ? Icons.hourglass_empty_rounded : Icons.refresh_rounded,
            size: 18,
            color: loading ? context.mutedText : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}
