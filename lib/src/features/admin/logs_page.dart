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
      title: context.localeText('清空日志', 'Clear Logs'),
      message: context.localeText('确定要清空所有日志和任务记录吗？这将删除所有系统日志和已完成/失败的任务。',
          'Clear all logs and task records? This deletes system logs and completed or failed tasks.'),
      action: context.localeText('清空', 'Clear'),
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
      title: context.localeText('删除任务记录', 'Delete Task Record'),
      message: context.localeText('确定要删除这条任务记录吗？', 'Delete this task record?'),
      action: context.localeText('删除', 'Delete'),
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
      SnackBar(
          content: Text(level == 'ERROR'
              ? context.localeText('错误日志已复制', 'Error logs copied')
              : context.localeText('日志已复制', 'Logs copied'))),
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
    this.rawMessage,
    this.messageKey,
    this.messageParams = const {},
    this.fields = const {},
    this.taskId,
    this.taskStatus,
    this.taskType,
  });

  final String timestamp;
  final String level;
  final String module;
  final String message;
  final String? rawMessage;
  final String? messageKey;
  final Map<String, dynamic> messageParams;
  final Map<String, dynamic> fields;
  final String? taskId;
  final String? taskStatus;
  final String? taskType;

  bool get isTask => taskId != null && taskId!.isNotEmpty;

  factory _LogEntry.fromJson(Map<String, dynamic> json) {
    return _LogEntry(
      timestamp: (json['timestamp'] ?? json['created_at'] ?? '').toString(),
      level: (json['level'] ?? 'INFO').toString(),
      module: (json['module'] ?? 'audit').toString(),
      message: (json['message'] ?? '').toString(),
      rawMessage: json['raw_message']?.toString(),
      messageKey: json['message_key']?.toString(),
      messageParams: asMap(json['message_params']),
      fields: asMap(json['fields']),
      taskId: json['task_id']?.toString(),
      taskStatus: json['task_status']?.toString(),
      taskType: json['task_type']?.toString(),
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
        color: color.withValues(alpha: context.isDark ? 0.18 : 0.1),
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
    final message = _logMessage(context, log);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _moduleName(context, log.module),
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
                label: Text(
                  context.localeText('详情', 'Details'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SelectableText(
          message,
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
            ? AppColors.slate950.withValues(alpha: 0.35)
            : AppColors.slate50.withValues(alpha: 0.8),
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
                      color: Colors.black.withValues(
                        alpha: context.isDark ? 0.08 : 0.03,
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
                  tooltip: onCancelTask != null
                      ? context.localeText('停止任务', 'Stop Task')
                      : context.localeText('删除记录', 'Delete Record'),
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
                tooltip: onCancelTask != null
                    ? context.localeText('停止任务', 'Stop Task')
                    : context.localeText('删除记录', 'Delete Record'),
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
        color: color.withValues(alpha: context.isDark ? 0.18 : 0.1),
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
        color: icon.$2.withValues(alpha: context.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _taskStatusText(context, status),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          const Icon(Icons.terminal_rounded,
              size: 48, color: AppColors.slate300),
          const SizedBox(height: 14),
          Text(context.localeText('暂无记录', 'No records'),
              style: const TextStyle(color: AppColors.slate500)),
        ],
      ),
    );
  }
}

String _moduleName(BuildContext context, String module) {
  if (module.startsWith('audit::login')) {
    return context.localeText('登录记录', 'Login');
  }
  if (module.startsWith('audit::playback')) {
    return context.localeText('播放记录', 'Playback');
  }
  if (module.startsWith('audit::scan')) {
    return context.localeText('扫描记录', 'Scan');
  }
  if (module.startsWith('audit::metadata')) {
    return context.localeText('元数据记录', 'Metadata');
  }
  if (module.startsWith('audit::library')) {
    return context.localeText('存储库记录', 'Library');
  }
  if (module.startsWith('audit::notification')) {
    return context.localeText('通知记录', 'Notification');
  }
  if (module.startsWith('audit::task')) {
    return context.localeText('任务记录', 'Task');
  }
  if (module == 'audit') return context.localeText('核心业务', 'Core');
  if (module.startsWith('auth')) return context.localeText('鉴权系统', 'Auth');
  if (module.startsWith('ting_reader::core::error')) {
    return context.localeText('核心错误', 'Core Errors');
  }
  if (module.startsWith('ting_reader::api')) {
    return context.localeText('API服务', 'API Service');
  }
  return module;
}

String _logMessage(BuildContext context, _LogEntry log) {
  final key = log.messageKey;
  if (key == null || key.isEmpty) {
    return log.message.isNotEmpty ? log.message : (log.rawMessage ?? '');
  }
  final template = _logMessageTemplate(context, key);
  if (template == null) {
    if (log.message.isNotEmpty) return log.message;
    if (log.rawMessage != null && log.rawMessage!.isNotEmpty) {
      return log.rawMessage!;
    }
    return key;
  }
  return _renderLogTemplate(template, log.messageParams);
}

String? _logMessageTemplate(BuildContext context, String key) {
  final isZh = context.localeText('zh', 'en') == 'zh';
  const zh = <String, String>{
    'logging.initialized': '日志系统初始化完成',
    'system.config.loaded': '配置加载成功',
    'system.backend.starting': '正在启动 Ting Reader 后端 v{version}',
    'system.server.config': '服务器配置',
    'system.database.config': '数据库配置',
    'system.plugin.config': '插件配置',
    'system.directories.ensuring': '正在确保必需的目录存在...',
    'system.directory.creating': '正在创建目录：{path}',
    'system.directories.ready': '所有必需的目录已就绪',
    'system.database.initializing': '正在初始化数据库...',
    'system.database.migrating': '正在运行数据库迁移...',
    'system.database.initialized': '数据库初始化成功',
    'system.http.initializing': '正在初始化 HTTP 服务器...',
    'system.http.starting': '正在启动 HTTP 服务器：{host}:{port}',
    'system.http.listening': 'HTTP 服务器正在监听：{addr}',
    'system.backend.initialized': '听书后端初始化成功',
    'system.server.ready': '服务器已就绪：{url}',
    'system.master_key.derived': '主密钥已基于机器特征和数据库路径自动派生',
    'system.jwt_key.initialized': 'JWT 密钥管理器初始化成功',
    'system.jwt_key.init_failed': 'JWT 密钥管理器初始化失败，使用配置文件密钥：{error}',
    'security.machine_id.env': '使用环境变量中的机器 ID',
    'security.master_key.derived': '主密钥已基于机器特征自动派生',
    'security.machine_id.existing': '使用现有机器 ID：{path}',
    'security.machine_id.created_data': '已在数据目录创建新的机器 ID：{path}',
    'security.machine_id.created_user': '已在用户目录创建新的机器 ID：{path}',
    'security.machine_id.temporary': '无法持久化机器 ID，使用临时标识符',
    'security.machine_id.system_fallback': '使用系统信息组合生成机器标识',
    'system.default_admin.creating': '未发现用户，正在创建默认管理员',
    'system.default_admin.created': '默认管理员已创建：{username}',
    'cache.file.delete_failed': '删除缓存文件失败：{path}',
    'cache.orphan.delete_failed': '删除孤立缓存文件失败：{path}',
    'cache.cleanup.completed': '缓存清理完成，移除了 {removed_count} 个文件',
    'database.connection.failed': '获取数据库连接失败',
    'audio.format.probe_failed': '音频格式探测失败：{path}',
    'strm.file.read_failed': '读取 strm 文件失败：{path}',
    'strm.url.invalid': 'strm 文件包含无效 URL：{path}',
    'ffprobe.output_parse_failed': '解析 FFprobe 输出失败',
    'ffprobe.duration_failed': 'FFprobe 获取时长失败',
    'ffprobe.run_failed': '无法运行 FFprobe',
    'ffprobe.missing': '未找到 FFprobe，时长将设为 0',
    'ffmpeg.missing': '未找到 FFmpeg，时长将设为 0',
    'webdav.duration.mismatch': 'WebDAV 文件时长与大小估算差距过大，将使用 FFprobe：{file_url}',
    'scraper.plugin.failed': '刮削器插件失败：{source_id}',
    'scraper.search.failed': '刮削器搜索失败：{source_id}',
    'media.plugin_stream.read_failed': '插件解码流读取失败',
    'media.ffmpeg.pipe_failed': '无法将输入通过管道传输到 FFmpeg',
    'media.cache.rename_failed': '重命名临时缓存文件失败：{chapter_id}',
    'media.cache.write_failed': '写入临时缓存文件失败：{chapter_id}',
    'media.preload.read_failed': '读取下一章预加载失败：{chapter_id}',
    'media.cache.stream_copy_failed': '自动缓存的流复制失败：{chapter_id}',
    'media.cache.temp_create_failed': '创建临时缓存文件失败：{chapter_id}',
    'media.metadata_read_size.failed': '获取元数据读取大小失败',
    'media.decryption_plan.failed': '获取解密计划失败',
    'media.hls.first_segment_timeout': '等待首分片超时，但继续返回',
    'media.hls.concurrent_limit':
        'HLS 转码并发已达上限：{active_count}/{max_concurrent}',
    'media.preload.reader_failed': '获取下一章读取器失败：{chapter_id}',
    'image.palette.extract_failed': '提取图像调色板失败',
    'image.decode_failed': '解码图像失败',
    'image.cover.download_failed': '下载封面图像失败',
    'image.cover.fetch_failed': '获取封面图像失败',
    'image.cover.read_failed': '读取本地封面图像失败：{path}',
    'websocket.progress_save_failed': 'WebSocket 进度保存失败',
    'plugin.gc_failed': '插件垃圾回收失败：{plugin}',
    'plugin.unload_during_uninstall_failed': '卸载期间卸载插件失败：{plugin_id}',
    'plugin.reload.started': '正在重新加载插件：{plugin_id}',
    'plugin.reload.same_version': '正在重新加载相同版本插件：{plugin_id}',
    'plugin.unload_old_failed': '卸载旧版本插件失败：{plugin_id}',
    'plugin.reload.completed': '插件重新加载完成：{plugin_id}',
    'plugin.reload_new_instance_failed': '加载新插件实例失败：{plugin_id}',
    'plugin.reload.version_changed': '随着版本更改重新加载插件：{old_id} -> {new_id}',
    'plugin.unload_after_upgrade_failed': '升级后卸载旧版本插件失败：{plugin_id}',
    'plugin.upgrade.completed': '插件升级完成：{old_id} -> {new_id}',
    'plugin.load_new_version_failed': '加载新版本插件失败：{plugin_id}',
    'plugin.uninstall_old_failed': '卸载旧版本插件失败：{plugin_id}',
    'plugin.unload_before_install_failed': '安装前卸载插件失败：{plugin_id}',
    'plugin.auto_load_after_install_failed': '安装后自动加载插件失败：{plugin_id}',
    'plugin.temp_file.delete_failed': '删除临时插件文件失败：{path}',
    'system.memory.release_failed': '释放内存失败',
    'plugin.version.invalid': '插件版本格式无效：{version}',
    'plugin.version_requirement.invalid': '插件版本要求无效：{requirement}',
    'library.initial_scan.enqueue_failed': '队列初始扫描任务失败：{library_id}',
    'library.watcher.watch_failed': '开始监视新库失败：{library_id}',
    'library.watcher.update_failed': '更新库监视器失败：{library_id}',
    'library.tasks.cancel_failed': '取消库任务失败：{library_id}',
    'library.orphan_books.cleanup_failed': '清理孤立书籍失败：{library_id}',
    'library.cover_cache.delete_failed': '删除封面缓存失败：{path}',
    'library.created': '管理员 {actor} 创建了媒体库 {library_name}（{url}）',
    'library.deleted': '管理员 {actor} 删除了媒体库 {library_name}',
    'book.created': '作品已入库：{book_title}',
    'book.deleted': '作品已删除：{book_title}',
    'metadata.nfo.write_failed': '写入 NFO 失败：{book_title}',
    'metadata.json.write_failed': '写入 metadata.json 失败',
    'metadata.json.write_succeeded': 'metadata.json 写入成功：{path}',
    'metadata.json.update_failed': '更新 metadata.json 失败：{book_id}',
    'book.theme_color.calculate_failed': '计算主题颜色失败',
    'book.theme_color.extract_failed': '无法从封面提取主题颜色',
    'config.validation_failed': '配置验证失败',
    'user.settings.restricted_update_ignored': '已忽略受限设置更新：{user_id}',
    'plugin.fetch.body_read_failed': '插件 fetch 读取响应主体失败',
    'plugin.fetch.request_failed': '插件 fetch 请求失败',
    'auth.jwt.rotation.started': '正在轮换 JWT 密钥',
    'auth.jwt.rotation.completed': 'JWT 密钥轮换完成',
    'auth.jwt.loaded': '已从数据库加载加密 JWT 密钥',
    'auth.jwt.generated': '已生成新的加密 JWT 密钥对',
    'auth.jwt.rotated': 'JWT 密钥已自动轮换并保存',
    'auth.jwt.rotation_check_failed': 'JWT 密钥轮换检查失败：{error}',
    'http.error.authentication': '认证失败：{error_type}（{status_code}）',
    'http.error.request': '请求失败：{error_type}（{status_code}）',
    'http.error.permission': '权限不足：{error_type}（{status_code}）',
    'http.error.database_busy': '数据库繁忙：{error_type}（{status_code}）',
    'http.response.failed': 'HTTP 响应失败：{classification}（{latency_ms} ms）',
    'http.response.status_failed':
        'HTTP 响应失败，状态码 {status_code}（{latency_ms} ms）',
    'http.response.service_failed': 'HTTP 服务失败（{latency_ms} ms）',
    'auth.login.success': '用户 {username} 登录成功',
    'auth.login.failed.invalid_token': 'JWT Token 登录失败：令牌验证失败',
    'auth.login.failed.user_missing': 'JWT Token 登录失败：用户不存在',
    'auth.login.failed.user_not_found': '用户 {username} 登录失败：用户不存在',
    'auth.login.failed.bad_password': '用户 {username} 登录失败：密码错误',
    'auth.login.failed.empty_token': 'JWT Token 登录失败：令牌为空',
    'auth.login.session_restore.duplicate_skipped': '跳过重复的浏览器会话恢复登录日志',
    'auth.register.success': '用户 {username} 注册成功，角色：{role}',
    'auth.register.failed': '用户 {username} 注册失败：{error}',
    'playback.started':
        '用户 {username} 开始播放《{book_title}》章节「{chapter_title}」，位置 {position}/{duration}',
    'notification.webhook.dispatch_failed': '发送 Webhook 通知失败：{event}',
    'notification.webhook.sent': 'Webhook 通知已发送：{webhook_name}（{event}）',
    'notification.webhook.status_failed':
        'Webhook 通知返回失败：{webhook_name}（HTTP {status}）',
    'notification.webhook.request_failed': 'Webhook 通知请求失败：{webhook_name}',
    'notification.webhook.created': 'Webhook 通知配置已创建：{webhook_name}',
    'notification.webhook.updated': 'Webhook 通知配置已更新：{webhook_name}',
    'notification.webhook.deleted': 'Webhook 通知配置已删除：{webhook_name}',
    'task.execute': '执行任务',
    'task.execute_with_payload': '执行任务：{payload}',
    'task.recovery.started': '正在从数据库恢复未完成的任务',
    'task.recovery.completed': '任务恢复完成：{count} 个',
    'task.recovery.failed': '任务恢复失败：{error}',
    'task.executor.started': '任务队列执行器已启动',
    'task.submitted': '任务已提交：{task_name}',
    'task.executing': '正在执行任务：{task_name}',
    'task.completed': '任务完成：{task_id}',
    'task.failed': '任务失败：{error}',
    'task.retrying': '任务重试中：第 {retry}/{max_retries} 次，{delay_secs} 秒后重试',
    'task.max_retries_failed': '任务达到最大重试次数后失败：{task_id}',
    'task.timed_out': '任务超时：{timeout_secs} 秒',
    'scan.started': '开始扫描存储库：{path}',
    'scan.local.scanning': '正在扫描本地目录...',
    'scan.webdav.scanning': '正在扫描 WebDAV 目录...',
    'scan.rss.fetching': '正在获取 RSS：{url}',
    'scan.rss.fetched': 'RSS 获取完成，发现 {count} 个音频条目',
    'scan.rss.completed': 'RSS 库扫描完成，发现 {episodes} 个音频条目',
    'scan.audio_dirs.found': '找到 {count} 个包含音频文件的目录',
    'scan.item.processing': '处理中 ({current}/{total})：{name}',
    'scan.chapter.processing': '处理章节 {current}/{total}',
    'scan.auto_merge.processing': '正在处理自动合并...',
    'scan.completed':
        '扫描完成：共 {total} 本，新增 {created} 本，更新 {updated} 本，删除 {deleted} 本，错误 {errors} 个',
    'scan.library.completed':
        '存储库「{library_name}」扫描完成，新增 {created} 本，更新 {updated} 本，删除 {deleted} 本',
    'library.watcher.start_failed': '启动库监听器失败：{error}',
    'metadata.chapter.writing': '正在写入第 {current}/{total} 章：{chapter_title}',
    'metadata.write.completed': '元数据写入完成，成功 {success} 章，失败 {failed} 章',
    'metadata.write.completed_for_book':
        '书籍「{book_title}」音频文件元数据写入完成，成功 {success} 章，失败 {failed} 章',
  };
  const en = <String, String>{
    'logging.initialized': 'Logging initialized',
    'system.config.loaded': 'Configuration loaded',
    'system.backend.starting': 'Starting Ting Reader backend v{version}',
    'system.server.config': 'Server configuration',
    'system.database.config': 'Database configuration',
    'system.plugin.config': 'Plugin configuration',
    'system.directories.ensuring': 'Ensuring required directories exist...',
    'system.directory.creating': 'Creating directory: {path}',
    'system.directories.ready': 'All required directories are ready',
    'system.database.initializing': 'Initializing database...',
    'system.database.migrating': 'Running database migrations...',
    'system.database.initialized': 'Database initialized',
    'system.http.initializing': 'Initializing HTTP server...',
    'system.http.starting': 'Starting HTTP server on {host}:{port}',
    'system.http.listening': 'HTTP server listening at {addr}',
    'system.backend.initialized': 'Ting Reader backend initialized',
    'system.server.ready': 'Server ready: {url}',
    'system.master_key.derived':
        'Master key derived from machine features and database path',
    'system.jwt_key.initialized': 'JWT key manager initialized',
    'system.jwt_key.init_failed':
        'JWT key manager initialization failed; using configured secret: {error}',
    'security.machine_id.env': 'Using machine ID from environment',
    'security.master_key.derived': 'Master key derived from machine features',
    'security.machine_id.existing': 'Using existing machine ID: {path}',
    'security.machine_id.created_data':
        'Created new machine ID in data directory: {path}',
    'security.machine_id.created_user':
        'Created new machine ID in user directory: {path}',
    'security.machine_id.temporary':
        'Could not persist machine ID; using temporary identifier',
    'security.machine_id.system_fallback':
        'Using system information fallback for machine ID',
    'system.default_admin.creating': 'No users found, creating default admin',
    'system.default_admin.created': 'Default admin created: {username}',
    'cache.file.delete_failed': 'Failed to delete cache file: {path}',
    'cache.orphan.delete_failed':
        'Failed to delete orphaned cache file: {path}',
    'cache.cleanup.completed':
        'Cache cleanup completed: {removed_count} files removed',
    'database.connection.failed': 'Failed to get database connection',
    'audio.format.probe_failed': 'Audio format probe failed: {path}',
    'strm.file.read_failed': 'Failed to read strm file: {path}',
    'strm.url.invalid': 'strm file contains an invalid URL: {path}',
    'ffprobe.output_parse_failed': 'Failed to parse FFprobe output',
    'ffprobe.duration_failed': 'FFprobe duration detection failed',
    'ffprobe.run_failed': 'Failed to run FFprobe',
    'ffprobe.missing': 'FFprobe not found; duration will be set to zero',
    'ffmpeg.missing': 'FFmpeg not found; duration will be set to zero',
    'webdav.duration.mismatch':
        'WebDAV duration differs from size estimate; using FFprobe: {file_url}',
    'scraper.plugin.failed': 'Scraper plugin failed: {source_id}',
    'scraper.search.failed': 'Scraper search failed: {source_id}',
    'media.plugin_stream.read_failed': 'Plugin decode stream read failed',
    'media.ffmpeg.pipe_failed': 'Failed to pipe input to FFmpeg',
    'media.cache.rename_failed':
        'Failed to rename temporary cache file: {chapter_id}',
    'media.cache.write_failed':
        'Failed to write temporary cache file: {chapter_id}',
    'media.preload.read_failed':
        'Failed to read next chapter preload: {chapter_id}',
    'media.cache.stream_copy_failed':
        'Auto-cache stream copy failed: {chapter_id}',
    'media.cache.temp_create_failed':
        'Failed to create temporary cache file: {chapter_id}',
    'media.metadata_read_size.failed': 'Failed to get metadata read size',
    'media.decryption_plan.failed': 'Failed to get decryption plan',
    'media.hls.first_segment_timeout':
        'Timed out waiting for first HLS segment; returning anyway',
    'media.hls.concurrent_limit':
        'HLS transcoding concurrency limit reached: {active_count}/{max_concurrent}',
    'media.preload.reader_failed':
        'Failed to get next chapter reader: {chapter_id}',
    'image.palette.extract_failed': 'Image palette extraction failed',
    'image.decode_failed': 'Image decode failed',
    'image.cover.download_failed': 'Failed to download cover image',
    'image.cover.fetch_failed': 'Failed to fetch cover image',
    'image.cover.read_failed': 'Failed to read local cover image: {path}',
    'websocket.progress_save_failed': 'WebSocket progress save failed',
    'plugin.gc_failed': 'Plugin garbage collection failed: {plugin}',
    'plugin.unload_during_uninstall_failed':
        'Failed to unload plugin during uninstall: {plugin_id}',
    'plugin.reload.started': 'Reloading plugin: {plugin_id}',
    'plugin.reload.same_version': 'Reloading same plugin version: {plugin_id}',
    'plugin.unload_old_failed':
        'Failed to unload old plugin version: {plugin_id}',
    'plugin.reload.completed': 'Plugin reloaded: {plugin_id}',
    'plugin.reload_new_instance_failed':
        'Failed to load new plugin instance: {plugin_id}',
    'plugin.reload.version_changed':
        'Reloading plugin with version change: {old_id} -> {new_id}',
    'plugin.unload_after_upgrade_failed':
        'Failed to unload old plugin version after upgrade: {plugin_id}',
    'plugin.upgrade.completed': 'Plugin upgraded: {old_id} -> {new_id}',
    'plugin.load_new_version_failed':
        'Failed to load new plugin version: {plugin_id}',
    'plugin.uninstall_old_failed':
        'Failed to uninstall old plugin version: {plugin_id}',
    'plugin.unload_before_install_failed':
        'Failed to unload plugin before install: {plugin_id}',
    'plugin.auto_load_after_install_failed':
        'Failed to auto-load plugin after install: {plugin_id}',
    'plugin.temp_file.delete_failed':
        'Failed to delete temporary plugin file: {path}',
    'system.memory.release_failed': 'Memory release failed',
    'plugin.version.invalid': 'Invalid plugin version format: {version}',
    'plugin.version_requirement.invalid':
        'Invalid plugin version requirement: {requirement}',
    'library.initial_scan.enqueue_failed':
        'Failed to enqueue initial library scan task: {library_id}',
    'library.watcher.watch_failed': 'Failed to watch new library: {library_id}',
    'library.watcher.update_failed':
        'Failed to update library watcher: {library_id}',
    'library.tasks.cancel_failed':
        'Failed to cancel library tasks: {library_id}',
    'library.orphan_books.cleanup_failed':
        'Failed to clean up orphan books: {library_id}',
    'library.cover_cache.delete_failed': 'Failed to delete cover cache: {path}',
    'library.created': 'Admin {actor} created library {library_name} ({url})',
    'library.deleted': 'Admin {actor} deleted library {library_name}',
    'book.created': 'Book imported: {book_title}',
    'book.deleted': 'Book deleted: {book_title}',
    'metadata.nfo.write_failed': 'Failed to write NFO: {book_title}',
    'metadata.json.write_failed': 'Failed to write metadata.json',
    'metadata.json.write_succeeded': 'metadata.json written: {path}',
    'metadata.json.update_failed': 'Failed to update metadata.json: {book_id}',
    'book.theme_color.calculate_failed': 'Book theme color calculation failed',
    'book.theme_color.extract_failed':
        'Could not extract theme color from cover',
    'config.validation_failed': 'Configuration validation failed',
    'user.settings.restricted_update_ignored':
        'Restricted settings update ignored: {user_id}',
    'plugin.fetch.body_read_failed': 'Plugin fetch body read failed',
    'plugin.fetch.request_failed': 'Plugin fetch request failed',
    'auth.jwt.rotation.started': 'Rotating JWT keys',
    'auth.jwt.rotation.completed': 'JWT key rotation completed',
    'auth.jwt.loaded': 'Loaded encrypted JWT keys from database',
    'auth.jwt.generated': 'Generated new encrypted JWT key pair',
    'auth.jwt.rotated': 'JWT keys rotated and saved',
    'auth.jwt.rotation_check_failed': 'JWT key rotation check failed: {error}',
    'http.error.authentication':
        'Authentication failed: {error_type} ({status_code})',
    'http.error.request': 'Request failed: {error_type} ({status_code})',
    'http.error.permission': 'Permission denied: {error_type} ({status_code})',
    'http.error.database_busy': 'Database busy: {error_type} ({status_code})',
    'http.response.failed':
        'HTTP response failed: {classification} ({latency_ms} ms)',
    'http.response.status_failed':
        'HTTP response failed with status {status_code} ({latency_ms} ms)',
    'http.response.service_failed': 'HTTP service failed ({latency_ms} ms)',
    'auth.login.success': 'User {username} logged in',
    'auth.login.failed.invalid_token':
        'JWT token login failed: token validation failed',
    'auth.login.failed.user_missing':
        'JWT token login failed: user does not exist',
    'auth.login.failed.user_not_found':
        'User {username} login failed: user not found',
    'auth.login.failed.bad_password':
        'User {username} login failed: bad password',
    'auth.login.failed.empty_token': 'JWT token login failed: token is empty',
    'auth.login.session_restore.duplicate_skipped':
        'Skipped duplicate browser session restore login log',
    'auth.register.success': 'User {username} registered with role {role}',
    'auth.register.failed': 'User {username} registration failed: {error}',
    'playback.started':
        'User {username} started playing "{book_title}" chapter "{chapter_title}" at {position}/{duration}',
    'notification.webhook.dispatch_failed':
        'Webhook notification dispatch failed: {event}',
    'notification.webhook.sent':
        'Webhook notification sent: {webhook_name} ({event})',
    'notification.webhook.status_failed':
        'Webhook notification returned failure: {webhook_name} (HTTP {status})',
    'notification.webhook.request_failed':
        'Webhook notification request failed: {webhook_name}',
    'notification.webhook.created':
        'Webhook configuration created: {webhook_name}',
    'notification.webhook.updated':
        'Webhook configuration updated: {webhook_name}',
    'notification.webhook.deleted':
        'Webhook configuration deleted: {webhook_name}',
    'task.execute': 'Run task',
    'task.execute_with_payload': 'Run task: {payload}',
    'task.recovery.started': 'Restoring unfinished tasks from database',
    'task.recovery.completed': 'Task recovery completed: {count}',
    'task.recovery.failed': 'Task recovery failed: {error}',
    'task.executor.started': 'Task queue executor started',
    'task.submitted': 'Task submitted: {task_name}',
    'task.executing': 'Executing task: {task_name}',
    'task.completed': 'Task completed: {task_id}',
    'task.failed': 'Task failed: {error}',
    'task.retrying':
        'Retrying task: {retry}/{max_retries}, retrying in {delay_secs}s',
    'task.max_retries_failed': 'Task failed after max retries: {task_id}',
    'task.timed_out': 'Task timed out after {timeout_secs}s',
    'scan.started': 'Started scanning library: {path}',
    'scan.local.scanning': 'Scanning local directory...',
    'scan.webdav.scanning': 'Scanning WebDAV directory...',
    'scan.rss.fetching': 'Fetching RSS: {url}',
    'scan.rss.fetched': 'RSS fetched, found {count} audio items',
    'scan.rss.completed':
        'RSS library scan completed with {episodes} audio items',
    'scan.audio_dirs.found': 'Found {count} directories with audio files',
    'scan.item.processing': 'Processing ({current}/{total}): {name}',
    'scan.chapter.processing': 'Processing chapter {current}/{total}',
    'scan.auto_merge.processing': 'Processing automatic merges...',
    'scan.completed':
        'Scan completed: {total} total, {created} created, {updated} updated, {deleted} deleted, {errors} errors',
    'scan.library.completed':
        'Library "{library_name}" scan completed: {created} created, {updated} updated, {deleted} deleted',
    'library.watcher.start_failed': 'Library watcher failed to start: {error}',
    'metadata.chapter.writing':
        'Writing chapter {current}/{total}: {chapter_title}',
    'metadata.write.completed':
        'Metadata write completed: {success} succeeded, {failed} failed',
    'metadata.write.completed_for_book':
        'Metadata write completed for "{book_title}": {success} succeeded, {failed} failed',
  };
  return (isZh ? zh : en)[key];
}

String _renderLogTemplate(String template, Map<String, dynamic> params) {
  var rendered = template;
  for (final entry in params.entries) {
    rendered =
        rendered.replaceAll('{${entry.key}}', _formatLogParam(entry.value));
  }
  return rendered;
}

String _formatLogParam(Object? value) {
  if (value == null) return '';
  if (value is String || value is num || value is bool) return value.toString();
  try {
    return jsonEncode(value);
  } catch (_) {
    return value.toString();
  }
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

String _taskStatusText(BuildContext context, String status) {
  switch (status) {
    case 'queued':
      return context.localeText('排队中', 'Queued');
    case 'running':
      return context.localeText('运行中', 'Running');
    case 'completed':
      return context.localeText('已完成', 'Completed');
    case 'failed':
      return context.localeText('失败', 'Failed');
    case 'cancelled':
      return context.localeText('已取消', 'Cancelled');
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
