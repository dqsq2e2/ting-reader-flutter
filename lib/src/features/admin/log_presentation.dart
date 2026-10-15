part of 'admin_pages.dart';

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

String _logMessage(BuildContext context, LogEntry log) {
  final rawMessageValue = log.rawMessage;
  final key = log.messageKey;
  if (key == null || key.isEmpty) {
    return log.message.isNotEmpty ? log.message : (rawMessageValue ?? '');
  }
  final template = logMessageTemplate(context, key);
  if (template == null) {
    if (log.message.isNotEmpty) return log.message;
    if (rawMessageValue != null && rawMessageValue.isNotEmpty) {
      return rawMessageValue;
    }
    return key;
  }
  return _renderLogTemplate(template, log.messageParams);
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

Color _logAccent(LogEntry log) {
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

String _formatLogTime(BuildContext context, String raw) {
  final parsed = backendDateTimeInApplicationTimeZone(
    raw,
    AppScope.appOf(context).applicationTimeZone,
  );
  if (parsed == null) return raw;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
      '${two(parsed.hour)}:${two(parsed.minute)}:${two(parsed.second)}';
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.log,
    required this.expanded,
    required this.onToggleDetails,
    required this.onCancelTask,
    required this.onDeleteTask,
  });

  final LogEntry log;
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

  final LogEntry log;

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

  final LogEntry log;
  final bool expanded;
  final VoidCallback? onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final taskStatusValue = log.taskStatus;
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
            if (log.isTask && taskStatusValue != null)
              _TaskStatusChip(status: taskStatusValue),
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

  final LogEntry log;
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
            _formatLogTime(context, log.timestamp),
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
          _formatLogTime(context, log.timestamp),
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
