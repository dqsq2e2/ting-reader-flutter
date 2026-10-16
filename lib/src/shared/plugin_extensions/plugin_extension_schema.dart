part of 'plugin_extension_host.dart';

class _PluginSchemaForm extends StatefulWidget {
  const _PluginSchemaForm({
    required this.extension,
    required this.extensionContext,
  });

  final ClientExtensionDescriptor extension;
  final Map<String, Object?> extensionContext;

  @override
  State<_PluginSchemaForm> createState() => _PluginSchemaFormState();
}

class _PluginSchemaFormState extends State<_PluginSchemaForm> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _booleans = <String, bool>{};
  final _selectValues = <String, String>{};
  late List<_PluginSchemaField> _fields;
  bool _running = false;
  bool _failed = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _resetFields();
  }

  @override
  void didUpdateWidget(covariant _PluginSchemaForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extension.id != widget.extension.id) {
      _disposeControllers();
      _resetFields();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  void _resetFields() {
    _fields = _schemaFieldsFor(widget.extension);
    _booleans.clear();
    _selectValues.clear();
    for (final field in _fields) {
      if (field.type == 'boolean') {
        _booleans[field.name] = field.defaultValue == true;
      } else if (field.type == 'select') {
        final defaultValue = field.defaultValue?.toString();
        _selectValues[field.name] = defaultValue != null &&
                field.options.any((option) => option.value == defaultValue)
            ? defaultValue
            : (field.options.isNotEmpty ? field.options.first.value : '');
      } else {
        _controllers[field.name] =
            TextEditingController(text: field.defaultValue?.toString() ?? '');
      }
    }
  }

  Map<String, Object?> _values() {
    final values = <String, Object?>{};
    for (final field in _fields) {
      if (field.type == 'boolean') {
        values[field.name] = _booleans[field.name] == true;
      } else if (field.type == 'select') {
        values[field.name] = _selectValues[field.name] ?? '';
      } else if (field.type == 'number') {
        final text = _controllers[field.name]?.text.trim() ?? '';
        values[field.name] = num.tryParse(text) ?? text;
      } else {
        values[field.name] = _controllers[field.name]?.text ?? '';
      }
    }
    return values;
  }

  Future<void> _submit() async {
    if (_running || !(_formKey.currentState?.validate() ?? true)) return;
    setState(() {
      _running = true;
      _failed = false;
      _message = null;
    });
    try {
      final result = await AppScope.appOf(context)
          .pluginCapabilities
          .invokePluginCapability(
        pluginId: widget.extension.pluginId,
        capabilityId: widget.extension.capability.id,
        uiCapabilityId: widget.extension.capability.id,
        uiGrant: widget.extension.clientGrant,
        params: {
          'slot': widget.extension.slot.value,
          'contexts': widget.extension.contexts,
          'context': widget.extensionContext,
          'values': _values(),
        },
      );
      if (!mounted) return;
      setState(() => _message = _formatActionResult(result));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _message = ApiError.messageFor(error);
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageValue = _message;
    if (_fields.isEmpty) {
      return _PluginUnsupportedBody(
        title: context.localeText('表单不可用', 'Form unavailable'),
        message: context.localeText(
          '缺少 render.schema.fields',
          'Missing render.schema.fields',
        ),
      );
    }
    final submitLabel = widget.extension.render['submit_label']?.toString() ??
        context.localeText('运行', 'Run');

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final field in _fields) ...[
                    _PluginSchemaFieldWidget(
                      field: field,
                      controller: _controllers[field.name],
                      booleanValue: _booleans[field.name] == true,
                      selectValue: _selectValues[field.name],
                      onBooleanChanged: (value) =>
                          setState(() => _booleans[field.name] = value),
                      onSelectChanged: (value) =>
                          setState(() => _selectValues[field.name] = value),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (messageValue != null) ...[
                    const SizedBox(height: 2),
                    _PluginActionMessage(
                        message: messageValue, failed: _failed),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _running ? null : _submit,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(submitLabel),
          ),
        ],
      ),
    );
  }
}

class _PluginSchemaFieldWidget extends StatelessWidget {
  const _PluginSchemaFieldWidget({
    required this.field,
    required this.booleanValue,
    required this.onBooleanChanged,
    required this.onSelectChanged,
    this.controller,
    this.selectValue,
  });

  final _PluginSchemaField field;
  final TextEditingController? controller;
  final bool booleanValue;
  final String? selectValue;
  final ValueChanged<bool> onBooleanChanged;
  final ValueChanged<String> onSelectChanged;

  @override
  Widget build(BuildContext context) {
    final label = field.label ?? field.name;
    final validator = field.required
        ? (String? value) {
            if (value == null || value.trim().isEmpty) {
              return context.localeText('必填', 'Required');
            }
            return null;
          }
        : null;
    if (field.type == 'boolean') {
      return CheckboxListTile(
        value: booleanValue,
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        onChanged: (value) => onBooleanChanged(value == true),
      );
    }
    if (field.type == 'select' && field.options.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: field.options.any((option) => option.value == selectValue)
            ? selectValue
            : field.options.first.value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final option in field.options)
            DropdownMenuItem(value: option.value, child: Text(option.label)),
        ],
        validator: validator,
        onChanged: (value) {
          if (value != null) onSelectChanged(value);
        },
      );
    }
    return TextFormField(
      controller: controller,
      minLines: field.type == 'textarea' ? 3 : 1,
      maxLines: field.type == 'textarea' ? 6 : 1,
      keyboardType:
          field.type == 'number' ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: field.placeholder,
      ),
      validator: validator,
    );
  }
}

class _PluginSchemaField {
  const _PluginSchemaField({
    required this.name,
    required this.type,
    this.label,
    this.placeholder,
    this.required = false,
    this.defaultValue,
    this.options = const [],
  });

  final String name;
  final String type;
  final String? label;
  final String? placeholder;
  final bool required;
  final Object? defaultValue;
  final List<_PluginSchemaOption> options;
}

class _PluginSchemaOption {
  const _PluginSchemaOption({required this.label, required this.value});

  final String label;
  final String value;
}

List<_PluginSchemaField> _schemaFieldsFor(
  ClientExtensionDescriptor extension,
) {
  final schema = asMap(extension.render['schema']);
  final rawFields = schema['fields'];
  if (rawFields is! List) return const [];
  return rawFields.expand<_PluginSchemaField>((rawField) {
    final field = asMap(rawField);
    final name = field['name']?.toString().trim();
    if (name == null || name.isEmpty) return const [];
    final type = switch (field['type']?.toString()) {
      'textarea' => 'textarea',
      'number' => 'number',
      'boolean' => 'boolean',
      'select' => 'select',
      _ => 'text',
    };
    return [
      _PluginSchemaField(
        name: name,
        type: type,
        label: field['label']?.toString(),
        placeholder: field['placeholder']?.toString(),
        required: field['required'] == true,
        defaultValue: field['default'],
        options: _schemaOptions(field['options']),
      ),
    ];
  }).toList(growable: false);
}

List<_PluginSchemaOption> _schemaOptions(Object? rawOptions) {
  if (rawOptions is! List) return const [];
  return rawOptions.expand<_PluginSchemaOption>((rawOption) {
    if (rawOption is String) {
      return [_PluginSchemaOption(label: rawOption, value: rawOption)];
    }
    final option = asMap(rawOption);
    final value = option['value']?.toString();
    if (value == null) return const [];
    return [
      _PluginSchemaOption(
        label: option['label']?.toString() ?? value,
        value: value,
      ),
    ];
  }).toList(growable: false);
}
