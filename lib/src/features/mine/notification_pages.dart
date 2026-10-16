import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/api/api_error.dart';
import '../../core/models/models.dart';
import '../../core/state/notification_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';
import '../../shared/app_scope.dart';
import '../../shared/common/common_widgets.dart';

part 'webhook_editor.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  NotificationState? _notifications;
  bool get _loading => _notifications?.loading ?? true;
  bool _saved = false;
  List<NotificationWebhook> get _webhooks =>
      _notifications?.webhooks ?? const [];
  List<NotificationEventOption> get _events =>
      _notifications?.events ?? const [];
  Timer? _savedTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_notifications != null) return;
    _notifications = NotificationState(AppScope.appOf(context).api)
      ..addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notifications?.removeListener(_changed);
    _notifications?.dispose();
    _savedTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await _notifications?.load();
  }

  void _markSaved() {
    _savedTimer?.cancel();
    setState(() => _saved = true);
    _savedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _upsert([NotificationWebhook? webhook]) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _WebhookDialog(webhook: webhook, events: _events),
    );
    if (data == null || !mounted) return;
    await _notifications?.save(data, id: webhook?.id);
    if (!mounted) return;
    _markSaved();
    await _load();
  }

  Future<void> _delete(NotificationWebhook webhook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(context.l10n.notificationsDeleteWebhookTitle),
        content: Text(
          context.l10n.notificationsDeleteWebhookMessage(webhook.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(context.l10n.notificationsDeleteAction),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffef4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await _notifications?.delete(webhook.id);
    await _load();
  }

  Future<void> _toggle(NotificationWebhook webhook) async {
    await _notifications?.save(
        webhook.toRequestJson(enabledOverride: !webhook.enabled),
        id: webhook.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_notifications?.error != null) {
      return PageListView(children: [
        AppBackButton(onPressed: widget.onBack),
        LoadErrorView(onRetry: _load),
      ]);
    }
    final enabledCount = _webhooks.where((item) => item.enabled).length;
    final disabledCount = math.max(_webhooks.length - enabledCount, 0);
    final listenedEvents = _webhooks
        .where((item) => item.enabled)
        .expand((item) => item.events)
        .toSet()
        .length;

    return PageListView(
      onRefresh: _load,
      children: [
        AppBackButton(onPressed: widget.onBack),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: HeaderText(
                icon: Icons.notifications_active_rounded,
                title: context.l10n.notificationsTitle,
                subtitle: context.l10n.notificationsSubtitle,
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _saved
                  ? Row(
                      key: const ValueKey('saved'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xff16a34a),
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          context.l10n.commonSaved,
                          style: const TextStyle(
                            color: Color(0xff16a34a),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(key: ValueKey('empty'), width: 1),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _NotificationStatCard(
                  width: width,
                  label: 'Webhook',
                  value: _webhooks.length.toString(),
                  icon: Icons.webhook_rounded,
                  color: AppColors.primary600,
                ),
                _NotificationStatCard(
                  width: width,
                  label: context.l10n.notificationsEnabled,
                  value: enabledCount.toString(),
                  icon: Icons.power_settings_new_rounded,
                  color: const Color(0xff16a34a),
                ),
                _NotificationStatCard(
                  width: width,
                  label: context.l10n.notificationsDisabled,
                  value: disabledCount.toString(),
                  icon: Icons.power_off_rounded,
                  color: AppColors.slate500,
                ),
                _NotificationStatCard(
                  width: width,
                  label: context.l10n.notificationsListeningEvents,
                  value: listenedEvents.toString(),
                  icon: Icons.notifications_active_rounded,
                  color: const Color(0xff7c3aed),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.faintBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDark ? 0.12 : 0.035,
                ),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.notificationsWebhookList,
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n
                                .notificationsWebhookCount(_webhooks.length),
                            style: TextStyle(
                              color: context.mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PrimaryButton(
                      label: context.l10n.notificationsAddWebhook,
                      icon: Icons.add_rounded,
                      onPressed: () => _upsert(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.faintBorder),
              if (_webhooks.isEmpty)
                const _NotificationEmptyState()
              else
                for (var i = 0; i < _webhooks.length; i++) ...[
                  _WebhookTile(
                    webhook: _webhooks[i],
                    events: _events,
                    onToggle: () => _toggle(_webhooks[i]),
                    onEdit: () => _upsert(_webhooks[i]),
                    onDelete: () => _delete(_webhooks[i]),
                  ),
                  if (i != _webhooks.length - 1)
                    Divider(height: 1, color: context.faintBorder),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WebhookTile extends StatelessWidget {
  const _WebhookTile({
    required this.webhook,
    required this.events,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final NotificationWebhook webhook;
  final List<NotificationEventOption> events;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final eventLabels =
        webhook.events.map((id) => _eventLabel(context, id)).toList();
    final visibleEvents = eventLabels.take(6).toList();
    final hiddenCount = math.max(eventLabels.length - visibleEvents.length, 0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: webhook.enabled
                  ? AppColors.primary50
                  : (context.isDark ? AppColors.slate800 : AppColors.slate100),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              webhook.enabled
                  ? Icons.webhook_rounded
                  : Icons.notifications_off_rounded,
              color: webhook.enabled ? AppColors.primary600 : context.mutedText,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        webhook.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _WebhookStatusBadge(enabled: webhook.enabled),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  webhook.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
                if (visibleEvents.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final label in visibleEvents)
                        _WebhookEventChip(label: label),
                      if (hiddenCount > 0)
                        _WebhookEventChip(label: '+$hiddenCount'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: webhook.enabled
                ? context.l10n.notificationsDisable
                : context.l10n.notificationsEnable,
            onPressed: onToggle,
            icon: Icon(
              webhook.enabled
                  ? Icons.power_settings_new_rounded
                  : Icons.play_circle_outline_rounded,
              color: webhook.enabled ? AppColors.primary600 : context.mutedText,
            ),
          ),
          IconButton(
            tooltip: context.l10n.notificationsEdit,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: context.l10n.notificationsDeleteAction,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          ),
        ],
      ),
    );
  }

  String _eventLabel(BuildContext context, String id) {
    for (final event in events) {
      if (event.id == id) {
        return _notificationEventLabel(context, event.id, event.label);
      }
    }
    return id;
  }
}

class _NotificationStatCard extends StatelessWidget {
  const _NotificationStatCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TingCard(
        radius: 18,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 348,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sensors_rounded,
              size: 48,
              color: context.isDark ? AppColors.slate600 : AppColors.slate300,
            ),
            const SizedBox(height: 22),
            Text(
              context.l10n.notificationsNoWebhook,
              style: TextStyle(
                color: context.isDark ? AppColors.slate50 : AppColors.slate900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.notificationsNoWebhookHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebhookStatusBadge extends StatelessWidget {
  const _WebhookStatusBadge({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xffdcfce7)
            : (context.isDark ? AppColors.slate800 : AppColors.slate100),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        enabled
            ? context.l10n.notificationsEnabled
            : context.l10n.notificationsDisabled,
        style: TextStyle(
          color: enabled ? const Color(0xff15803d) : context.mutedText,
          fontSize: 11,
        ),
      ),
    );
  }
}

String _notificationEventLabel(
  BuildContext context,
  String id,
  String fallback,
) {
  return switch (id) {
    'user.login' => context.localeText('用户登录', 'User Login'),
    'playback.play' => context.localeText('播放', 'Playback'),
    'library.created' => context.localeText('新增媒体库', 'Library Created'),
    'library.deleted' => context.localeText('删除媒体库', 'Library Deleted'),
    'book.created' => context.localeText('作品入库', 'Book Imported'),
    'book.deleted' => context.localeText('删除作品', 'Book Deleted'),
    'library.scan_completed' => context.localeText('扫描完成', 'Scan Completed'),
    _ => fallback.isEmpty ? id : fallback,
  };
}

String _notificationEventDescription(
  BuildContext context,
  String id,
  String fallback,
) {
  return switch (id) {
    'user.login' =>
      context.localeText('用户成功登录系统', 'A user successfully logged in'),
    'playback.play' => context.localeText(
        '用户开始播放作品或章节', 'A user started playing a work or chapter'),
    'library.created' =>
      context.localeText('管理员创建媒体库', 'An admin created a library'),
    'library.deleted' =>
      context.localeText('管理员删除媒体库', 'An admin deleted a library'),
    'book.created' =>
      context.localeText('作品被创建或入库', 'A work was created or imported'),
    'book.deleted' => context.localeText('作品被删除', 'A work was deleted'),
    'library.scan_completed' =>
      context.localeText('媒体库扫描任务完成', 'A library scan completed'),
    _ => fallback.isEmpty ? id : fallback,
  };
}

class _WebhookEventChip extends StatelessWidget {
  const _WebhookEventChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.faintBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.isDark ? AppColors.slate300 : AppColors.slate600,
          fontSize: 11,
        ),
      ),
    );
  }
}
