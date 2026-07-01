part of 'mine_page.dart';

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
    await api.delete('/api/system/notifications/${webhook.id}');
    await _load();
  }

  Future<void> _toggle(NotificationWebhook webhook) async {
    await AppScope.appOf(context).api.put(
          '/api/system/notifications/${webhook.id}',
          data: webhook.toRequestJson(enabledOverride: !webhook.enabled),
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

const _defaultWebhookBodyTemplate = '{{json:payload}}';

class _WebhookHeaderDraft {
  _WebhookHeaderDraft({String? id, this.key = '', this.value = ''})
      : id = id ?? '${DateTime.now().microsecondsSinceEpoch}';

  final String id;
  String key;
  String value;
}

class _WebhookPreset {
  const _WebhookPreset({
    required this.id,
    required this.name,
    required this.urlPlaceholder,
    required this.headers,
    required this.bodyTemplate,
  });

  final String id;
  final String name;
  final String urlPlaceholder;
  final Map<String, String> headers;
  final String bodyTemplate;
}

class _WebhookTestResult {
  const _WebhookTestResult({
    required this.success,
    required this.status,
    this.responseBody = '',
    this.renderedBody = '',
    this.error,
  });

  final bool success;
  final int status;
  final String responseBody;
  final String renderedBody;
  final String? error;

  factory _WebhookTestResult.fromJson(Map<String, dynamic> json) {
    return _WebhookTestResult(
      success: json['success'] == true,
      status: (json['status'] as num?)?.toInt() ?? 0,
      responseBody: (json['response_body'] ?? '').toString(),
      renderedBody: (json['rendered_body'] ?? '').toString(),
      error: (json['error'] as String?)?.trim(),
    );
  }
}

const _webhookPresets = [
  _WebhookPreset(
    id: 'ting-json',
    name: 'raw-json',
    urlPlaceholder: 'https://example.com/webhook',
    headers: {'Content-Type': 'application/json'},
    bodyTemplate: _defaultWebhookBodyTemplate,
  ),
  _WebhookPreset(
    id: 'wecom-markdown',
    name: 'wecom-markdown',
    urlPlaceholder: 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=...',
    headers: {'Content-Type': 'application/json'},
    bodyTemplate: '''{
  "msgtype": "markdown",
  "markdown": {
    "content": {{json:notification}}
  }
}''',
  ),
  _WebhookPreset(
    id: 'wecom-text',
    name: 'wecom-text',
    urlPlaceholder: 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=...',
    headers: {'Content-Type': 'application/json'},
    bodyTemplate: '''{
  "msgtype": "text",
  "text": {
    "content": {{json:notification}}
  }
}''',
  ),
  _WebhookPreset(
    id: 'ntfy-json',
    name: 'ntfy JSON',
    urlPlaceholder: 'https://ntfy.example.com',
    headers: {'Content-Type': 'application/json'},
    bodyTemplate: '''{
  "topic": "ting-reader",
  "title": {{json:title}},
  "message": {{json:message}},
  "priority": 3,
  "tags": ["headphones"]
}''',
  ),
  _WebhookPreset(
    id: 'gotify-json',
    name: 'Gotify JSON',
    urlPlaceholder: 'https://gotify.example.com/message?token=...',
    headers: {'Content-Type': 'application/json'},
    bodyTemplate: '''{
  "title": {{json:title}},
  "message": {{json:message}},
  "priority": 5
}''',
  ),
  _WebhookPreset(
    id: 'plain-text',
    name: 'plain-text',
    urlPlaceholder: 'https://example.com/webhook',
    headers: {'Content-Type': 'text/plain; charset=utf-8'},
    bodyTemplate: '{{notification}}',
  ),
];

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
  late final TextEditingController _filter;
  late final TextEditingController _bodyTemplate;
  late bool _enabled;
  late Set<String> _events;
  late List<_WebhookHeaderDraft> _headers;
  String? _selectedPresetId;
  bool _testing = false;
  _WebhookTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    final webhook = widget.webhook;
    _name = TextEditingController(text: webhook?.name ?? '');
    _url = TextEditingController(text: webhook?.url ?? '');
    _filter = TextEditingController();
    _bodyTemplate = TextEditingController(
      text: webhook?.bodyTemplate ?? _defaultWebhookBodyTemplate,
    );
    _enabled = webhook?.enabled ?? true;
    _events = webhook?.events.toSet() ?? _commonEvents();
    _headers = _headersFromMap(
      webhook?.headers ?? const {'Content-Type': 'application/json'},
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _filter.dispose();
    _bodyTemplate.dispose();
    super.dispose();
  }

  Set<String> _commonEvents() {
    const preferred = {
      'user.login',
      'playback.play',
      'library.scan_completed',
    };
    final common = widget.events
        .where((event) => preferred.contains(event.id))
        .map((event) => event.id)
        .toSet();
    if (common.isNotEmpty) return common;
    return widget.events.take(1).map((event) => event.id).toSet();
  }

  List<_WebhookHeaderDraft> _headersFromMap(Map<String, String> headers) {
    return headers.entries
        .map((entry) => _WebhookHeaderDraft(
              key: entry.key,
              value: entry.value,
            ))
        .toList();
  }

  Map<String, String> _headersToMap() {
    final values = <String, String>{};
    for (final header in _headers) {
      final key = header.key.trim();
      if (key.isEmpty) continue;
      values[key] = header.value.trim();
    }
    return values;
  }

  _WebhookPreset? get _selectedPreset {
    final id = _selectedPresetId;
    if (id == null || id.isEmpty) return null;
    for (final preset in _webhookPresets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  String _presetDisplayName(_WebhookPreset preset) {
    return switch (preset.id) {
      'ting-json' => context.l10n.notificationsPresetRawJson,
      'wecom-markdown' => context.l10n.notificationsPresetWecomMarkdown,
      'wecom-text' => context.l10n.notificationsPresetWecomText,
      'plain-text' => context.l10n.notificationsPresetPlainText,
      _ => preset.name,
    };
  }

  void _applyPreset(String? presetId) {
    if (presetId == null || presetId.isEmpty) return;
    final preset = _webhookPresets.firstWhere((item) => item.id == presetId);
    setState(() {
      _selectedPresetId = presetId;
      _headers = _headersFromMap(preset.headers);
      _bodyTemplate.text = preset.bodyTemplate;
      _testResult = null;
    });
  }

  Map<String, dynamic> _requestData({bool? enabledOverride}) {
    return {
      'name': _name.text.trim(),
      'url': _url.text.trim(),
      'enabled': enabledOverride ?? _enabled,
      'events': _events.toList(),
      'headers': _headersToMap(),
      'body_template': _bodyTemplate.text.trim().isEmpty
          ? _defaultWebhookBodyTemplate
          : _bodyTemplate.text,
    };
  }

  bool _validate() {
    if (_name.text.trim().isEmpty || _url.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.notificationsValidateRequired)),
      );
      return false;
    }
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.notificationsValidateEvents)),
      );
      return false;
    }
    return true;
  }

  Future<void> _testWebhook() async {
    if (_testing || !_validate()) return;
    final api = AppScope.appOf(context).api;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final response = await api.post(
        '/api/system/notifications/test',
        data: _requestData(enabledOverride: true),
      );
      if (!mounted) return;
      setState(() {
        _testResult = _WebhookTestResult.fromJson(asMap(response.data));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testResult = _WebhookTestResult(
          success: false,
          status: 0,
          error: context.l10n.notificationsTestFailed('$error'),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.width < 560;
    final keyword = _filter.text.trim().toLowerCase();
    final filteredEvents = widget.events.where((event) {
      if (keyword.isEmpty) return true;
      final label = _notificationEventLabel(context, event.id, event.label);
      final description =
          _notificationEventDescription(context, event.id, event.description);
      return '$label ${event.id} $description ${event.label} ${event.description}'
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
          maxWidth: 840,
          maxHeight: math.min(screen.height * 0.94, 820),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 20 : 28,
                compact ? 18 : 24,
                compact ? 12 : 20,
                compact ? 16 : 20,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.webhook == null
                              ? context.l10n.notificationsAddWebhookTitle
                              : context.l10n.notificationsEditWebhookTitle,
                          style: TextStyle(
                            color: context.primaryText,
                            fontSize: compact ? 22 : 26,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.notificationsEventCount(_events.length),
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.notificationsClose,
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
                  compact ? 20 : 28,
                  compact ? 18 : 24,
                  compact ? 20 : 28,
                  compact ? 20 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _labeledField(
                      context,
                      context.l10n.notificationsNameLabel,
                      TextField(
                        controller: _name,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.badge_outlined),
                          hintText: context.l10n.notificationsNameHint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _labeledField(
                      context,
                      'Webhook URL',
                      TextField(
                        controller: _url,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.link_rounded),
                          hintText: _selectedPreset?.urlPlaceholder ??
                              'https://example.com/webhook',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildPresetRow(compact),
                    const SizedBox(height: 18),
                    _buildHeadersCard(compact),
                    const SizedBox(height: 18),
                    _buildBodyTemplate(),
                    if (_testResult != null) ...[
                      const SizedBox(height: 16),
                      _buildTestResult(_testResult!),
                    ],
                    const SizedBox(height: 18),
                    _buildEnabledCard(),
                    const SizedBox(height: 18),
                    _buildEventsCard(filteredEvents, compact),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: context.faintBorder),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 20 : 28,
                14,
                compact ? 20 : 28,
                compact ? 20 : 24,
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.commonCancel),
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: context.l10n.mineSave,
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

  Widget _labeledField(BuildContext context, String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.secondaryText, fontSize: 13),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildPresetRow(bool compact) {
    final dropdown = DropdownButtonFormField<String>(
      initialValue: _selectedPresetId,
      hint: Text(context.l10n.notificationsSelectTemplate),
      items: [
        for (final preset in _webhookPresets)
          DropdownMenuItem(
            value: preset.id,
            child: Text(_presetDisplayName(preset)),
          ),
      ],
      onChanged: _applyPreset,
    );
    final testButton = OutlinedButton.icon(
      onPressed: _testing ? null : _testWebhook,
      icon: _testing
          ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.science_outlined, size: 18),
      label: Text(context.l10n.notificationsTestSend),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(132, 52),
        foregroundColor: AppColors.primary600,
        side: const BorderSide(color: AppColors.primary200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.notificationsCommonTemplates,
            style: TextStyle(color: context.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 8),
          dropdown,
          const SizedBox(height: 10),
          testButton,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.notificationsCommonTemplates,
          style: TextStyle(color: context.secondaryText, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: dropdown),
            const SizedBox(width: 14),
            testButton,
          ],
        ),
      ],
    );
  }

  Widget _buildHeadersCard(bool compact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.notificationsRequestHeaders,
                  style: TextStyle(color: context.primaryText, fontSize: 15),
                ),
              ),
              IconButton(
                tooltip: context.l10n.notificationsAddHeader,
                onPressed: () {
                  setState(() {
                    _headers.add(_WebhookHeaderDraft());
                    _testResult = null;
                  });
                },
                icon:
                    const Icon(Icons.add_rounded, color: AppColors.primary600),
              ),
            ],
          ),
          if (_headers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                context.l10n.notificationsNoHeaders,
                style: TextStyle(color: context.mutedText),
              ),
            )
          else
            for (var i = 0; i < _headers.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _buildHeaderRow(_headers[i], compact),
            ],
        ],
      ),
    );
  }

  Widget _buildHeaderRow(_WebhookHeaderDraft header, bool compact) {
    final keyField = TextFormField(
      key: ValueKey('webhook-header-key-${header.id}'),
      initialValue: header.key,
      decoration: const InputDecoration(hintText: 'Content-Type'),
      onChanged: (value) {
        header.key = value;
        _testResult = null;
      },
    );
    final valueField = TextFormField(
      key: ValueKey('webhook-header-value-${header.id}'),
      initialValue: header.value,
      decoration: const InputDecoration(hintText: 'application/json'),
      onChanged: (value) {
        header.value = value;
        _testResult = null;
      },
    );
    final deleteButton = IconButton(
      tooltip: context.l10n.notificationsDeleteHeader,
      onPressed: () {
        setState(() {
          _headers.removeWhere((item) => item.id == header.id);
          _testResult = null;
        });
      },
      icon: const Icon(Icons.delete_outline_rounded),
      color: AppColors.slate400,
    );

    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                keyField,
                const SizedBox(height: 8),
                valueField,
              ],
            ),
          ),
          const SizedBox(width: 8),
          deleteButton,
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 4, child: keyField),
        const SizedBox(width: 10),
        Expanded(flex: 6, child: valueField),
        const SizedBox(width: 4),
        deleteButton,
      ],
    );
  }

  Widget _buildBodyTemplate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '{}',
              style: TextStyle(color: context.secondaryText, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.notificationsBodyTemplate,
              style: TextStyle(color: context.secondaryText, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bodyTemplate,
          minLines: 8,
          maxLines: 12,
          spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
          style: TextStyle(
            color: context.isDark ? Colors.white : AppColors.slate900,
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.45,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.isDark ? AppColors.slate950 : AppColors.slate50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: context.isDark ? AppColors.slate800 : AppColors.slate200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: context.isDark ? AppColors.slate800 : AppColors.slate200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary500),
            ),
          ),
          onChanged: (_) => _testResult = null,
        ),
      ],
    );
  }

  Widget _buildTestResult(_WebhookTestResult result) {
    final success = result.success;
    final color = success ? const Color(0xff16a34a) : const Color(0xffdc2626);
    final background =
        success ? const Color(0xffecfdf5) : const Color(0xfffff1f2);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.isDark ? color.withValues(alpha: 0.14) : background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            success
                ? context.l10n.notificationsSendSuccess(result.status)
                : (result.error?.isNotEmpty == true
                    ? result.error!
                    : context.l10n.notificationsSendFailed(result.status)),
            style: TextStyle(color: color, fontSize: 13),
          ),
          if (result.responseBody.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              result.responseBody,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.secondaryText, fontSize: 12),
            ),
          ],
          if (result.renderedBody.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                context.l10n.notificationsRenderedBody,
                style: TextStyle(color: context.secondaryText, fontSize: 12),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    result.renderedBody,
                    style: TextStyle(
                      color: context.secondaryText,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEnabledCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate900 : AppColors.slate50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.faintBorder),
      ),
      child: SwitchListTile(
        value: _enabled,
        onChanged: (value) => setState(() => _enabled = value),
        title: Text(context.l10n.notificationsEnabledSwitch),
        subtitle: Text(
          _enabled
              ? context.l10n.notificationsEnable
              : context.l10n.notificationsDisable,
        ),
        activeThumbColor: AppColors.primary600,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildEventsCard(
    List<NotificationEventOption> filteredEvents,
    bool compact,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate900 : AppColors.slate50,
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
                      _events = _commonEvents();
                    }),
                    child: Text(context.l10n.notificationsCommon),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _events = widget.events.map((event) => event.id).toSet();
                    }),
                    child: Text(context.l10n.notificationsSelectAll),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _events = <String>{}),
                    child: Text(context.l10n.notificationsClear),
                  ),
                ],
              );
              final title = Text(
                context.l10n.notificationsListeningEvents,
                style: TextStyle(color: context.primaryText, fontSize: 15),
              );
              if (constraints.maxWidth < 440) {
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
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: context.l10n.notificationsSearchEvents,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          if (filteredEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  context.l10n.notificationsNoMatchedEvents,
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
    );
  }

  void _save() {
    if (!_validate()) return;
    Navigator.pop(context, _requestData());
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
    final label = _notificationEventLabel(context, event.id, event.label);
    final description =
        _notificationEventDescription(context, event.id, event.description);
    final selectedBackground =
        context.isDark ? const Color(0xff172033) : AppColors.primary50;
    final selectedBorder =
        context.isDark ? AppColors.primary500 : AppColors.primary300;
    final selectedTitle = context.isDark ? Colors.white : AppColors.primary700;
    final selectedSubtitle =
        context.isDark ? AppColors.slate300 : AppColors.slate600;
    final unselectedBackground = context.cardColor;
    final unselectedTitle = context.isDark ? Colors.white : AppColors.slate900;
    final unselectedSubtitle = context.mutedText;
    return Material(
      color: selected ? selectedBackground : unselectedBackground,
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
              color: selected ? selectedBorder : context.faintBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary300 : AppColors.slate400,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? selectedTitle : unselectedTitle,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? selectedSubtitle : unselectedSubtitle,
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
