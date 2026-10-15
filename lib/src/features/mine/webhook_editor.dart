part of 'notification_pages.dart';

class _WebhookHeaderDraft {
  _WebhookHeaderDraft({String? id, this.key = '', this.value = ''})
      : id = id ?? '${DateTime.now().microsecondsSinceEpoch}';

  final String id;
  String key;
  String value;
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
  late final TextEditingController _filter;
  late final TextEditingController _bodyTemplate;
  late bool _enabled;
  late Set<String> _events;
  late List<_WebhookHeaderDraft> _headers;
  String? _selectedPresetId;
  NotificationState? _tester;
  bool _testing = false;
  WebhookTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    final webhook = widget.webhook;
    _name = TextEditingController(text: webhook?.name ?? '');
    _url = TextEditingController(text: webhook?.url ?? '');
    _filter = TextEditingController();
    _bodyTemplate = TextEditingController(
      text: webhook?.bodyTemplate ?? defaultWebhookBodyTemplate,
    );
    _enabled = webhook?.enabled ?? true;
    _events = webhook?.events.toSet() ?? _commonEvents();
    _headers = _headersFromMap(
      webhook?.headers ?? const {'Content-Type': 'application/json'},
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tester ??= NotificationState(AppScope.appOf(context).api);
  }

  @override
  void dispose() {
    _tester?.dispose();
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

  WebhookPreset? get _selectedPreset {
    final id = _selectedPresetId;
    if (id == null || id.isEmpty) return null;
    for (final preset in webhookPresets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  String _presetDisplayName(WebhookPreset preset) {
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
    final preset = webhookPresets.firstWhere((item) => item.id == presetId);
    setState(() {
      _selectedPresetId = presetId;
      _headers = _headersFromMap(preset.headers);
      _bodyTemplate.text = preset.bodyTemplate;
      _testResult = null;
    });
  }

  Map<String, dynamic> _requestData({bool? enabledOverride}) {
    return NotificationWebhook(
      id: widget.webhook?.id ?? '',
      name: _name.text.trim(),
      url: _url.text.trim(),
      enabled: enabledOverride ?? _enabled,
      events: _events.toList(),
      headers: _headersToMap(),
      bodyTemplate: _bodyTemplate.text,
    ).toRequestJson();
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
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final result = await _tester?.test(_requestData(enabledOverride: true));
      if (mounted) setState(() => _testResult = result);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testResultValue = _testResult;
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
                    if (testResultValue != null) ...[
                      const SizedBox(height: 16),
                      _buildTestResult(testResultValue),
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
        for (final preset in webhookPresets)
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

  Widget _buildTestResult(WebhookTestResult result) {
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
                    ? (result.error ?? '')
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
