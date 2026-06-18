part of 'management_pages.dart';

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
  List<_LogEntry> _logs = [];
  final Set<String> _expandedLogKeys = {};
  Timer? _timer;

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
    if (!silent) setState(() => _loading = true);
    try {
      final res = await AppScope.appOf(context).api.get(
        '/api/system/logs',
        params: {
          'page': 1,
          'page_size': 100,
          if (_moduleFilter.isNotEmpty) 'module': _moduleFilter,
          if (_levelFilter.isNotEmpty) 'level': _levelFilter,
        },
      );
      if (!mounted) return;
      final next =
          asMapList(asMap(res.data)['logs']).map(_LogEntry.fromJson).toList();
      setState(() {
        _logs = next;
        _expandedLogKeys.removeWhere(
          (key) => !_logs.asMap().entries.any(
                (entry) => _logKey(entry.value, entry.key) == key,
              ),
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clear() async {
    final ok = await _confirm(
      title: '清空日志',
      message: '确定要清空所有日志和任务记录吗？这将删除所有系统日志和已完成/失败的任务。',
      action: '清空',
    );
    if (!ok || !mounted) return;

    final api = AppScope.appOf(context).api;
    await Future.wait([
      api.delete('/api/tasks'),
      api.delete('/api/system/logs'),
    ]);
    _expandedLogKeys.clear();
    await _load();
  }

  Future<void> _cancelTask(String taskId) async {
    await AppScope.appOf(context).api.post('/api/tasks/$taskId/cancel');
    await _load();
  }

  Future<void> _deleteTask(String taskId) async {
    final ok = await _confirm(
      title: '删除任务记录',
      message: '确定要删除这条任务记录吗？',
      action: '删除',
    );
    if (!ok || !mounted) return;

    await AppScope.appOf(context).api.delete('/api/tasks/$taskId');
    await _load();
  }

  Future<void> _export({String? level}) async {
    final res = await AppScope.appOf(context).api.get(
      '/api/system/logs/export',
      params: {if (level != null) 'level': level},
    );
    await Clipboard.setData(ClipboardData(text: res.data?.toString() ?? ''));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(level == 'ERROR' ? '错误日志已复制' : '日志已复制')),
    );
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
            child: const Text('取消'),
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

  String _logKey(_LogEntry log, int index) {
    return [
      log.taskId ?? '',
      log.timestamp,
      log.module,
      log.message,
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
        const SizedBox(height: 24),
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
                      _LogRow(
                        log: _logs[i],
                        expanded:
                            _expandedLogKeys.contains(_logKey(_logs[i], i)),
                        onToggleDetails: _logs[i].fields.isEmpty
                            ? null
                            : () => _toggleLogDetails(_logKey(_logs[i], i)),
                        onCancelTask: _logs[i].taskId == null
                            ? null
                            : () => _cancelTask(_logs[i].taskId!),
                        onDeleteTask: _logs[i].taskId == null
                            ? null
                            : () => _deleteTask(_logs[i].taskId!),
                      ),
                      if (i != _logs.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
            ],
          ),
        ),
        const SafeBottomSpacer(),
      ],
    );
  }
}

class _LogEntry {
  const _LogEntry({
    required this.timestamp,
    required this.level,
    required this.module,
    required this.message,
    this.fields = const {},
    this.taskId,
    this.taskStatus,
    this.taskType,
  });

  final String timestamp;
  final String level;
  final String module;
  final String message;
  final Map<String, dynamic> fields;
  final String? taskId;
  final String? taskStatus;
  final String? taskType;

  bool get isTask => taskId != null && taskId!.isNotEmpty;

  factory _LogEntry.fromJson(Map<String, dynamic> json) {
    return _LogEntry(
      timestamp:
          (json['timestamp'] ?? json['created_at'] ?? json['createdAt'] ?? '')
              .toString(),
      level: (json['level'] ?? 'INFO').toString(),
      module: (json['module'] ?? 'audit').toString(),
      message: (json['message'] ?? '').toString(),
      fields: asMap(json['fields']),
      taskId: (json['task_id'] ?? json['taskId'])?.toString(),
      taskStatus: (json['task_status'] ?? json['taskStatus'])?.toString(),
      taskType: (json['task_type'] ?? json['taskType'])?.toString(),
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
              label: '模块',
              width: compact ? 172 : 164,
              value: moduleFilter,
              items: const [
                ('audit', '全部核心日志'),
                ('audit::login', '登录记录'),
                ('audit::playback', '播放记录'),
                ('audit::scan', '扫描记录'),
                ('audit::metadata', '元数据记录'),
                ('audit::library', '存储库记录'),
                ('audit::notification', '通知记录'),
                ('all', '系统所有日志'),
              ],
              onChanged: onModuleChanged,
            ),
            _LogSelect(
              label: '等级',
              width: 130,
              value: levelFilter,
              items: const [
                ('', '全部'),
                ('INFO', 'INFO'),
                ('WARN', 'WARN'),
                ('ERROR', 'ERROR'),
              ],
              onChanged: onLevelChanged,
            ),
            _LogActionButton(
              icon: Icons.cleaning_services_rounded,
              label: '清空',
              onPressed: onClear,
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (value) {
                if (value == 'all') onExportAll();
                if (value == 'error') onExportError();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'all', child: Text('导出所有日志')),
                PopupMenuItem(value: 'error', child: Text('导出错误日志')),
              ],
              child: const _LogActionButtonVisual(
                icon: Icons.more_horiz_rounded,
                label: '更多',
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
              '系统日志',
              style: TextStyle(
                fontSize: compact ? 24 : 30,
                height: 1.15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '实时监控系统后台运行状态与任务进度',
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
              '自动刷新',
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
                        color: Colors.black.withOpacity(0.12),
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

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.log,
    required this.expanded,
    required this.onToggleDetails,
    required this.onCancelTask,
    required this.onDeleteTask,
  });

  final _LogEntry log;
  final bool expanded;
  final VoidCallback? onToggleDetails;
  final VoidCallback? onCancelTask;
  final VoidCallback? onDeleteTask;

  @override
  Widget build(BuildContext context) {
    final canStop = log.taskStatus == 'running' || log.taskStatus == 'queued';
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final leading = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LogIcon(log: log),
              const SizedBox(width: 16),
              Expanded(
                child: _LogBody(
                  log: log,
                  expanded: expanded,
                  onToggleDetails: onToggleDetails,
                ),
              ),
            ],
          );

          final trailing = _LogTrailing(
            log: log,
            compact: compact,
            onCancelTask: canStop ? onCancelTask : null,
            onDeleteTask: !canStop ? onDeleteTask : null,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leading,
                const SizedBox(height: 14),
                Divider(color: context.faintBorder),
                trailing,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leading),
              const SizedBox(width: 18),
              trailing,
            ],
          );
        },
      ),
    );
  }
}

class _LogIcon extends StatelessWidget {
  const _LogIcon({required this.log});

  final _LogEntry log;

  @override
  Widget build(BuildContext context) {
    final color = _logAccent(log);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(context.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Icon(_logIcon(log.module), color: color, size: 24),
    );
  }
}

class _LogBody extends StatelessWidget {
  const _LogBody({
    required this.log,
    required this.expanded,
    required this.onToggleDetails,
  });

  final _LogEntry log;
  final bool expanded;
  final VoidCallback? onToggleDetails;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _moduleName(log.module),
              style: const TextStyle(fontSize: 16),
            ),
            _LevelChip(level: log.level),
            if (log.isTask && log.taskStatus != null)
              _TaskStatusChip(status: log.taskStatus!),
            if (onToggleDetails != null)
              TextButton.icon(
                onPressed: onToggleDetails,
                style: TextButton.styleFrom(
                  foregroundColor: context.mutedText,
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 16,
                ),
                label: const Text(
                  '详情',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SelectableText(
          log.message,
          style: TextStyle(
            color: log.isTask
                ? context.mutedText
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontFamily: 'monospace',
            fontSize: 14,
            height: 1.45,
          ),
        ),
        if (expanded && log.fields.isNotEmpty)
          _LogFieldsGrid(fields: log.fields),
      ],
    );
  }
}

class _LogFieldsGrid extends StatelessWidget {
  const _LogFieldsGrid({required this.fields});

  final Map<String, dynamic> fields;

  @override
  Widget build(BuildContext context) {
    final entries = fields.entries.toList();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.slate950.withOpacity(0.35)
            : AppColors.slate50.withOpacity(0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.faintBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720
              ? 3
              : constraints.maxWidth >= 420
                  ? 2
                  : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 74,
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final value = _formatLogFieldValue(entry.value);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.faintBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        context.isDark ? 0.08 : 0.03,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.tertiaryText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: SelectableText(
                        value,
                        maxLines: 2,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LogTrailing extends StatelessWidget {
  const _LogTrailing({
    required this.log,
    required this.compact,
    required this.onCancelTask,
    required this.onDeleteTask,
  });

  final _LogEntry log;
  final bool compact;
  final VoidCallback? onCancelTask;
  final VoidCallback? onDeleteTask;

  @override
  Widget build(BuildContext context) {
    final statusIcon = _taskStatusIcon(log.taskStatus);
    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatLogTime(log.timestamp),
            style: TextStyle(
              color: context.tertiaryText,
              fontSize: 12,
            ),
          ),
          if (log.isTask)
            Row(
              children: [
                Icon(statusIcon.$1, color: statusIcon.$2, size: 22),
                IconButton(
                  tooltip: onCancelTask != null ? '停止任务' : '删除记录',
                  onPressed: onCancelTask ?? onDeleteTask,
                  icon: Icon(
                    onCancelTask != null
                        ? Icons.stop_circle_outlined
                        : Icons.delete_outline_rounded,
                    color: onCancelTask != null
                        ? const Color(0xffdc2626)
                        : AppColors.slate400,
                  ),
                ),
              ],
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (log.isTask) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon.$1, color: statusIcon.$2, size: 22),
              IconButton(
                tooltip: onCancelTask != null ? '停止任务' : '删除记录',
                onPressed: onCancelTask ?? onDeleteTask,
                icon: Icon(
                  onCancelTask != null
                      ? Icons.stop_circle_outlined
                      : Icons.delete_outline_rounded,
                  color: onCancelTask != null
                      ? const Color(0xffdc2626)
                      : AppColors.slate400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        Text(
          _formatLogTime(log.timestamp),
          textAlign: TextAlign.right,
          style: TextStyle(
            color: context.tertiaryText,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(context.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  const _TaskStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final icon = _taskStatusIcon(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: icon.$2.withOpacity(context.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _taskStatusText(status),
        style: TextStyle(
          color: icon.$2,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LogsEmptyState extends StatelessWidget {
  const _LogsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(Icons.terminal_rounded, size: 48, color: AppColors.slate300),
          SizedBox(height: 14),
          Text('暂无记录', style: TextStyle(color: AppColors.slate500)),
        ],
      ),
    );
  }
}

String _moduleName(String module) {
  if (module.startsWith('audit::login')) return '登录记录';
  if (module.startsWith('audit::playback')) return '播放记录';
  if (module.startsWith('audit::scan')) return '扫描记录';
  if (module.startsWith('audit::metadata')) return '元数据记录';
  if (module.startsWith('audit::library')) return '存储库记录';
  if (module.startsWith('audit::notification')) return '通知记录';
  if (module.startsWith('audit::task')) return '任务记录';
  if (module == 'audit') return '核心业务';
  if (module.startsWith('auth')) return '鉴权系统';
  if (module.startsWith('ting_reader::core::error')) return '核心错误';
  if (module.startsWith('ting_reader::api')) return 'API服务';
  return module;
}

IconData _logIcon(String module) {
  if (module.contains('login') || module.contains('auth')) {
    return Icons.logout_rounded;
  }
  if (module.contains('playback')) return Icons.play_circle_outline_rounded;
  if (module.contains('notification')) {
    return Icons.notifications_active_rounded;
  }
  if (module.contains('scan')) return Icons.storage_rounded;
  if (module.contains('metadata')) {
    return Icons.drive_file_rename_outline_rounded;
  }
  return Icons.monitor_heart_rounded;
}

String _formatLogFieldValue(Object? value) {
  if (value == null) return '';
  if (value is String || value is num || value is bool) return value.toString();
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}

Color _logAccent(_LogEntry log) {
  if (!log.isTask) return AppColors.slate500;
  if (log.taskType == 'scan' || log.taskType == 'library_scan') {
    return AppColors.primary600;
  }
  if (log.taskType == 'write_metadata') return const Color(0xffd97706);
  return const Color(0xff7c3aed);
}

Color _levelColor(String level) {
  switch (level.toUpperCase()) {
    case 'ERROR':
      return const Color(0xffef4444);
    case 'WARN':
      return const Color(0xffd97706);
    case 'INFO':
      return AppColors.primary600;
    case 'DEBUG':
      return const Color(0xff7c3aed);
    default:
      return AppColors.slate500;
  }
}

(IconData, Color) _taskStatusIcon(String? status) {
  switch (status) {
    case 'completed':
      return (Icons.check_circle_rounded, const Color(0xff16a34a));
    case 'failed':
      return (Icons.cancel_rounded, const Color(0xffef4444));
    case 'running':
      return (Icons.sync_rounded, AppColors.primary600);
    case 'cancelled':
      return (Icons.cancel_rounded, AppColors.slate400);
    default:
      return (Icons.schedule_rounded, AppColors.slate400);
  }
}

String _taskStatusText(String status) {
  switch (status) {
    case 'queued':
      return '排队中';
    case 'running':
      return '运行中';
    case 'completed':
      return '已完成';
    case 'failed':
      return '失败';
    case 'cancelled':
      return '已取消';
    default:
      return status;
  }
}

String _formatLogTime(String raw) {
  final parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) return raw;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
      '${two(parsed.hour)}:${two(parsed.minute)}:${two(parsed.second)}';
}
