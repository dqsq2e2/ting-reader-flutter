part of 'user_pages.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _loading = true;
  bool _saved = false;
  List<NotificationWebhook> _webhooks = [];
  List<NotificationEventOption> _events = [];
  Timer? _savedTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = AppScope.appOf(context).api;
    try {
      final results = await Future.wait([
        api.get('/api/system/notifications'),
        api.get('/api/system/notifications/events'),
      ]);
      setState(() {
        _webhooks = asMapList(results[0].data)
            .map(NotificationWebhook.fromJson)
            .toList();
        _events = asMapList(results[1].data)
            .map(NotificationEventOption.fromJson)
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _markSaved() {
    _savedTimer?.cancel();
    setState(() => _saved = true);
    _savedTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _upsert([NotificationWebhook? webhook]) async {
    final api = AppScope.appOf(context).api;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _WebhookDialog(webhook: webhook, events: _events),
    );
    if (data == null) return;
    if (webhook == null) {
      await api.post('/api/system/notifications', data: data);
    } else {
      await api.put('/api/system/notifications/${webhook.id}', data: data);
    }
    _markSaved();
    await _load();
  }

  Future<void> _delete(NotificationWebhook webhook) async {
    final api = AppScope.appOf(context).api;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('删除 Webhook'),
        content: Text('确定删除「${webhook.name}」吗？这不会影响历史事件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('删除'),
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
    await api.delete('/api/system/notifications/${webhook.id}');
    await _load();
  }

  Future<void> _toggle(NotificationWebhook webhook) async {
    await AppScope.appOf(context).api.put(
      '/api/system/notifications/${webhook.id}',
      data: {
        'name': webhook.name,
        'url': webhook.url,
        'enabled': !webhook.enabled,
        'events': webhook.events,
        'secret': webhook.secret,
      },
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
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
            const Expanded(
              child: HeaderText(
                icon: Icons.notifications_active_rounded,
                title: '通知与事件',
                subtitle: 'Webhook 监听与事件推送',
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _saved
                  ? const Row(
                      key: ValueKey('saved'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xff16a34a),
                          size: 16,
                        ),
                        SizedBox(width: 5),
                        Text(
                          '已保存',
                          style: TextStyle(
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
                  label: '已开启',
                  value: enabledCount.toString(),
                  icon: Icons.power_settings_new_rounded,
                  color: const Color(0xff16a34a),
                ),
                _NotificationStatCard(
                  width: width,
                  label: '已关闭',
                  value: disabledCount.toString(),
                  icon: Icons.radio_button_unchecked_rounded,
                  color: AppColors.slate500,
                ),
                _NotificationStatCard(
                  width: width,
                  label: '监听事件',
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
                color: Colors.black.withOpacity(context.isDark ? 0.12 : 0.035),
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
                          const Text(
                            'Webhook 列表',
                            style: TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_webhooks.length} 个配置',
                            style: TextStyle(
                              color: context.mutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PrimaryButton(
                      label: '添加 Webhook',
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
        const SafeBottomSpacer(),
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
    final eventLabels = webhook.events.map(_eventLabel).toList();
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
            tooltip: webhook.enabled ? '关闭' : '开启',
            onPressed: onToggle,
            icon: Icon(
              webhook.enabled
                  ? Icons.power_settings_new_rounded
                  : Icons.play_circle_outline_rounded,
              color: webhook.enabled ? AppColors.primary600 : context.mutedText,
            ),
          ),
          IconButton(
            tooltip: '编辑',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          ),
        ],
      ),
    );
  }

  String _eventLabel(String id) {
    for (final event in events) {
      if (event.id == id) return event.label.isEmpty ? id : event.label;
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
                color: color.withOpacity(0.08),
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
              '暂无 Webhook',
              style: TextStyle(
                color: context.isDark ? AppColors.slate50 : AppColors.slate900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击列表右上角添加一个监听配置',
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
        enabled ? '已开启' : '已关闭',
        style: TextStyle(
          color: enabled ? const Color(0xff15803d) : context.mutedText,
          fontSize: 11,
        ),
      ),
    );
  }
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

class _WebhookDialog extends StatefulWidget {
  const _WebhookDialog({required this.events, this.webhook});

  final List<NotificationEventOption> events;
  final NotificationWebhook? webhook;

  @override
  State<_WebhookDialog> createState() => _WebhookDialogState();
}

class _WebhookDialogState extends State<_WebhookDialog> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _secret;
  late final TextEditingController _filter;
  late bool _enabled;
  late Set<String> _events;

  @override
  void initState() {
    super.initState();
    final webhook = widget.webhook;
    _name = TextEditingController(text: webhook?.name ?? '');
    _url = TextEditingController(text: webhook?.url ?? '');
    _secret = TextEditingController(text: webhook?.secret ?? '');
    _filter = TextEditingController();
    _enabled = webhook?.enabled ?? true;
    _events = (webhook?.events.toSet() ??
        widget.events.take(1).map((event) => event.id).toSet());
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _secret.dispose();
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.width < 560;
    final keyword = _filter.text.trim().toLowerCase();
    final filteredEvents = widget.events.where((event) {
      if (keyword.isEmpty) return true;
      return '${event.label} ${event.id} ${event.description}'
          .toLowerCase()
          .contains(keyword);
    }).toList();

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: compact ? 14 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 24 : 28),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: math.min(screen.height * 0.9, 760),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 26,
                compact ? 18 : 24,
                compact ? 14 : 22,
                compact ? 14 : 18,
              ),
              child: Row(
                children: [
                  Container(
                    width: compact ? 40 : 44,
                    height: compact ? 40 : 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.webhook_rounded,
                      color: AppColors.primary600,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.webhook == null ? '添加 Webhook' : '编辑 Webhook',
                          style: const TextStyle(
                            fontSize: 20,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_events.length} 个监听事件',
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.faintBorder),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 18 : 26,
                  compact ? 18 : 22,
                  compact ? 18 : 26,
                  compact ? 18 : 22,
                ),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final nameField = TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.badge_outlined),
                            labelText: '配置名称',
                          ),
                        );
                        final enabledTile = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: context.isDark
                                ? AppColors.slate900
                                : AppColors.slate50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.faintBorder),
                          ),
                          child: SwitchListTile(
                            value: _enabled,
                            onChanged: (value) =>
                                setState(() => _enabled = value),
                            title: const Text('启用'),
                            activeColor: AppColors.primary600,
                            contentPadding: EdgeInsets.zero,
                          ),
                        );
                        if (constraints.maxWidth < 520) {
                          return Column(
                            children: [
                              nameField,
                              const SizedBox(height: 12),
                              enabledTile,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: nameField),
                            const SizedBox(width: 14),
                            SizedBox(width: 170, child: enabledTile),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _url,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.link_rounded),
                        labelText: 'Webhook URL',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _secret,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.key_rounded),
                        labelText: 'Secret（可选）',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(compact ? 14 : 18),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? AppColors.slate900
                            : AppColors.slate50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.faintBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final actions = Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: () => setState(() {
                                      final common = widget.events
                                          .where((event) =>
                                              event.id == 'user.login' ||
                                              event.id == 'playback.play' ||
                                              event.id ==
                                                  'library.scan_completed')
                                          .map((event) => event.id);
                                      _events = common.toSet();
                                    }),
                                    child: const Text('常用'),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _events = widget.events
                                          .map((event) => event.id)
                                          .toSet();
                                    }),
                                    child: const Text('全选'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _events = <String>{}),
                                    child: const Text('清空'),
                                  ),
                                ],
                              );
                              final title = Text(
                                '监听事件',
                                style: TextStyle(
                                  color: context.isDark
                                      ? Colors.white
                                      : AppColors.slate900,
                                ),
                              );
                              if (constraints.maxWidth < 430) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    title,
                                    const SizedBox(height: 8),
                                    actions,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: title),
                                  actions,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _filter,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search_rounded),
                              hintText: '搜索事件',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 14),
                          if (filteredEvents.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  '没有匹配事件',
                                  style: TextStyle(color: context.mutedText),
                                ),
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final itemWidth = constraints.maxWidth < 420
                                    ? constraints.maxWidth
                                    : constraints.maxWidth < 660
                                        ? (constraints.maxWidth - 10) / 2
                                        : 214.0;
                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final event in filteredEvents)
                                      _WebhookEventToggle(
                                        width: itemWidth,
                                        event: event,
                                        selected: _events.contains(event.id),
                                        onTap: () {
                                          setState(() {
                                            _events.contains(event.id)
                                                ? _events.remove(event.id)
                                                : _events.add(event.id);
                                          });
                                        },
                                      ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: context.faintBorder),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 26,
                14,
                compact ? 18 : 26,
                compact ? 18 : 22,
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: '保存',
                    icon: Icons.save_rounded,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_name.text.trim().isEmpty || _url.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写名称和 Webhook URL')),
      );
      return;
    }
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个监听事件')),
      );
      return;
    }
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'url': _url.text.trim(),
      'enabled': _enabled,
      'events': _events.toList(),
      'secret': _secret.text.trim().isEmpty ? null : _secret.text.trim(),
    });
  }
}

class _WebhookEventToggle extends StatelessWidget {
  const _WebhookEventToggle({
    required this.width,
    required this.event,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final NotificationEventOption event;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary50 : context.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary300 : context.faintBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary600 : AppColors.slate400,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.label.isEmpty ? event.id : event.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary700
                            : (context.isDark
                                ? Colors.white
                                : AppColors.slate900),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.description.isEmpty ? event.id : event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
