part of 'admin_pages.dart';

class _PluginConfigDialog extends StatefulWidget {
  const _PluginConfigDialog({required this.plugin});

  final PluginItem plugin;

  @override
  State<_PluginConfigDialog> createState() => _PluginConfigDialogState();
}

class _PluginConfigDialogState extends State<_PluginConfigDialog> {
  final Map<String, TextEditingController> _controllers = {};
  PluginConfigurationState? _configuration;
  bool get _loading => _configuration?.loading ?? true;
  bool get _saving => _configuration?.saving ?? false;
  String? get _error => _configuration?.error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configuration != null) return;
    _configuration =
        PluginConfigurationState(AppScope.appOf(context).api, widget.plugin)
          ..addListener(_configurationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _configurationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _configuration?.removeListener(_configurationChanged);
    _configuration?.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, Map<String, dynamic>> get _properties =>
      _configuration?.properties ?? const {};

  Future<void> _load() async {
    await _configuration?.load();
    if (mounted) setState(_syncControllers);
  }

  Future<void> _save() async {
    Map<String, dynamic> values;
    try {
      values = _readFormConfig();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.localeText(
              '配置格式不正确: ${ApiError.messageFor(error)}',
              'Invalid config: ${ApiError.messageFor(error)}'))));
      return;
    }
    final saved = await _configuration?.save(values) ?? false;
    if (mounted && saved) Navigator.pop(context, true);
  }

  void _syncControllers() {
    for (final entry in _properties.entries) {
      final prop = entry.value;
      if (_usesTextController(prop)) {
        _controllerFor(entry.key, prop).text =
            pluginEditorText(_valueFor(entry.key, prop), prop);
      }
    }
  }

  TextEditingController _controllerFor(String key, Map<String, dynamic> prop) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(
        text: pluginEditorText(_valueFor(key, prop), prop),
      ),
    );
  }

  Object? _valueFor(String key, Map<String, dynamic> prop) {
    final configuration = _configuration;
    return configuration == null
        ? prop['default']
        : configuration.valueFor(key, prop);
  }

  bool _usesTextController(Map<String, dynamic> prop) {
    final type = pluginSchemaType(prop);
    return isEncryptedPluginField(prop) ||
        type == 'string' ||
        type == 'integer' ||
        type == 'number' ||
        type == 'array' ||
        type == 'object';
  }

  Map<String, dynamic> _readFormConfig() =>
      _configuration?.readForm({
        for (final entry in _properties.entries)
          if (_usesTextController(entry.value))
            entry.key: _controllerFor(entry.key, entry.value).text,
      }) ??
      {};

  void _setConfigValue(String key, Object? value) =>
      _configuration?.setValue(key, value);

  Widget _field(String key, Map<String, dynamic> prop) {
    final label = _schemaLabel(context, key, prop);
    final description = _schemaDescription(context, prop);
    final type = pluginSchemaType(prop);
    final enumValues = pluginSchemaEnum(prop);
    final encrypted = isEncryptedPluginField(prop);

    if (enumValues.isNotEmpty) {
      final current = (_valueFor(key, prop) ?? enumValues.first).toString();
      return _PluginConfigFieldFrame(
        label: label,
        description: description,
        child: DropdownButtonFormField<String>(
          initialValue:
              enumValues.contains(current) ? current : enumValues.first,
          decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          items: [
            for (final value in enumValues)
              DropdownMenuItem(value: value, child: Text(value)),
          ],
          onChanged: _saving ? null : (value) => _setConfigValue(key, value),
        ),
      );
    }

    if (type == 'boolean') {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: description == null ? null : Text(description),
        value: _valueFor(key, prop) == true,
        onChanged: _saving ? null : (value) => _setConfigValue(key, value),
      );
    }

    final controller = _controllerFor(key, prop);
    final multiline = type == 'array' ||
        type == 'object' ||
        prop['format'] == 'textarea' ||
        prop['x-display'] == 'textarea';
    return _PluginConfigFieldFrame(
      label: label,
      description: description,
      encrypted: encrypted,
      child: TextField(
        controller: controller,
        enabled: !_saving,
        obscureText: encrypted,
        maxLines: encrypted ? 1 : (multiline ? 5 : 1),
        keyboardType: type == 'integer' || type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : (multiline ? TextInputType.multiline : TextInputType.text),
        style: TextStyle(
          fontFamily: type == 'array' || type == 'object' ? 'monospace' : null,
        ),
        decoration: InputDecoration(
          hintText: encrypted
              ? context.localeText(
                  '留空则保持原值', 'Leave blank to keep current value')
              : _schemaPlaceholder(context, prop),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final properties = _properties;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.pluginsConfigTitle(widget.plugin.name),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const SizedBox(height: 180, child: LoadingView())
              else
                Flexible(
                  child: properties.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              context.localeText(
                                  '该插件没有配置项', 'No configurable options'),
                              style: TextStyle(color: context.mutedText),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final entry in properties.entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _field(entry.key, entry.value),
                                ),
                            ],
                          ),
                        ),
                ),
              if (_error case final errorText?) ...[
                const SizedBox(height: 12),
                Text(
                  errorText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xffdc2626), fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      child: Text(context.l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: context.l10n.commonSave,
                      loading: _saving,
                      onPressed: _saving ? null : () => _save(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PluginConfigFieldFrame extends StatelessWidget {
  const _PluginConfigFieldFrame({
    required this.label,
    required this.child,
    this.description,
    this.encrypted = false,
  });

  final String label;
  final String? description;
  final bool encrypted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final descriptionValue = description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (encrypted)
              Tooltip(
                message: context.localeText('本字段会加密保存', 'Stored encrypted'),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: context.mutedText,
                ),
              ),
          ],
        ),
        if (descriptionValue != null) ...[
          const SizedBox(height: 4),
          Text(descriptionValue,
              style: TextStyle(color: context.mutedText, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

String _schemaLabel(
    BuildContext context, String key, Map<String, dynamic> prop) {
  return _schemaText(context, prop['title_i18n']) ??
      _schemaText(context, prop['label_i18n']) ??
      _schemaText(context, prop['title']) ??
      _schemaText(context, prop['label']) ??
      _humanizePluginField(key);
}

String? _schemaDescription(BuildContext context, Map<String, dynamic> prop) {
  return _schemaText(context, prop['description_i18n']) ??
      _schemaText(context, prop['description']);
}

String? _schemaPlaceholder(BuildContext context, Map<String, dynamic> prop) {
  return _schemaText(context, prop['placeholder_i18n']) ??
      _schemaText(context, prop['placeholder']);
}

String? _schemaText(BuildContext context, Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is! Map) return null;
  final language = Localizations.localeOf(context).languageCode.toLowerCase();
  final preferred = language.startsWith('en')
      ? const ['en', 'en-US', 'en_US']
      : const ['zh', 'zh-CN', 'zh_CN', 'zh-Hans', 'zh_Hans'];
  final fallback = language.startsWith('en')
      ? const ['zh', 'zh-CN', 'zh_CN', 'zh-Hans', 'zh_Hans']
      : const ['en', 'en-US', 'en_US'];
  for (final key in [...preferred, ...fallback]) {
    final text = value[key]?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  for (final item in value.values) {
    final text = item?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

String _humanizePluginField(String key) {
  return key
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
