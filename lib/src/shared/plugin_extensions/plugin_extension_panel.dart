part of 'plugin_extension_host.dart';

class PluginExtensionPage extends StatefulWidget {
  const PluginExtensionPage({
    super.key,
    required this.extension,
    this.extensionContext = const <String, Object?>{},
    this.onBack,
  });

  final ClientExtensionDescriptor extension;
  final Map<String, Object?> extensionContext;
  final VoidCallback? onBack;

  @override
  State<PluginExtensionPage> createState() => _PluginExtensionPageState();
}

class _PluginExtensionPageState extends State<PluginExtensionPage> {
  bool _running = false;
  bool _failed = false;
  String? _message;

  @override
  void didUpdateWidget(covariant PluginExtensionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extension.id != widget.extension.id) {
      _running = false;
      _failed = false;
      _message = null;
    }
  }

  Future<void> _invoke() async {
    if (_running) return;
    setState(() {
      _running = true;
      _failed = false;
      _message = null;
    });
    try {
      final result = await AppScope.appOf(context)
          .pluginCapabilities
          .invokePluginCapability<Object?>(
        pluginId: widget.extension.pluginId,
        capabilityId: widget.extension.capability.id,
        uiCapabilityId: widget.extension.capability.id,
        uiGrant: widget.extension.clientGrant,
        params: {
          'slot': widget.extension.slot.value,
          'contexts': widget.extension.contexts,
          'context': widget.extensionContext,
        },
      );
      if (!mounted) return;
      setState(() => _message = _formatActionResult(result));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _message = error.toString();
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extension = widget.extension;
    final isWebContainer =
        extension.renderMode == ClientExtensionRenderMode.webContainer;
    final body = _PluginExtensionPanelBody(
      extension: extension,
      running: _running,
      failed: _failed,
      message: _message,
      onInvoke: _invoke,
      extensionContext: widget.extensionContext,
    );

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: MediaQuery.sizeOf(context).width >= 1280,
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: context.cardColor,
                border: Border(bottom: BorderSide(color: context.faintBorder)),
              ),
              child: Row(
                children: [
                  if (widget.onBack != null) ...[
                    IconButton(
                      tooltip: context.localeText('返回', 'Back'),
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: PluginExtensionIcon(
                        extension: extension,
                        size: 20,
                        color: AppColors.primary600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          extension.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          extension.pluginName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isWebContainer
                  ? body
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: body,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PluginExtensionPanel extends StatelessWidget {
  const _PluginExtensionPanel({
    required this.extension,
    required this.compact,
    required this.running,
    required this.failed,
    required this.onClose,
    required this.onInvoke,
    required this.extensionContext,
    this.message,
  });

  final ClientExtensionDescriptor extension;
  final bool compact;
  final bool running;
  final bool failed;
  final String? message;
  final VoidCallback onClose;
  final VoidCallback onInvoke;
  final Map<String, Object?> extensionContext;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.of(context).size;
    final panelHeight = (viewport.height * (compact ? 0.86 : 0.88))
        .clamp(0.0, compact ? 608.0 : 672.0)
        .toDouble();
    final panelMargin = viewport.width >= 640 ? 24.0 : 12.0;
    final isWebContainer =
        extension.renderMode == ClientExtensionRenderMode.webContainer;
    final body = _PluginExtensionPanelBody(
      extension: extension,
      running: running,
      failed: failed,
      message: message,
      onInvoke: onInvoke,
      extensionContext: extensionContext,
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Container(
                color: const Color(0xff0f172a).withValues(alpha: 0.32),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: SafeArea(
              child: Container(
                width: viewport.width < 560 ? double.infinity : 448,
                height: panelHeight,
                margin: EdgeInsets.all(panelMargin),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.faintBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _PluginExtensionPanelHeader(
                      extension: extension,
                      onClose: onClose,
                    ),
                    Expanded(
                      child: isWebContainer
                          ? body
                          : Padding(
                              padding: const EdgeInsets.all(18),
                              child: body,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginExtensionPanelHeader extends StatelessWidget {
  const _PluginExtensionPanelHeader({
    required this.extension,
    required this.onClose,
  });

  final ClientExtensionDescriptor extension;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.faintBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: _PluginExtensionIcon(
                extension: extension,
                size: 18,
                color: AppColors.primary600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  extension.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  extension.pluginName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.localeText('关闭', 'Close'),
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _PluginExtensionPanelBody extends StatelessWidget {
  const _PluginExtensionPanelBody({
    required this.extension,
    required this.running,
    required this.failed,
    required this.onInvoke,
    required this.extensionContext,
    this.message,
  });

  final ClientExtensionDescriptor extension;
  final bool running;
  final bool failed;
  final String? message;
  final VoidCallback onInvoke;
  final Map<String, Object?> extensionContext;

  @override
  Widget build(BuildContext context) {
    final messageValue = message;
    if (extension.renderMode == ClientExtensionRenderMode.action) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: running ? null : onInvoke,
            icon: running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(
              running
                  ? context.localeText('运行中...', 'Running...')
                  : context.localeText('运行', 'Run'),
            ),
          ),
          if (messageValue != null) ...[
            const SizedBox(height: 14),
            Expanded(
              child: _PluginActionMessage(
                message: messageValue,
                failed: failed,
              ),
            ),
          ] else
            const Spacer(),
        ],
      );
    }

    if (extension.renderMode == ClientExtensionRenderMode.webContainer) {
      return _PluginWebContainer(
        extension: extension,
        extensionContext: extensionContext,
      );
    }

    if (extension.renderMode == ClientExtensionRenderMode.schema) {
      return _PluginSchemaForm(
        extension: extension,
        extensionContext: extensionContext,
      );
    }

    if (extension.renderMode == ClientExtensionRenderMode.builtin) {
      return _PluginBuiltinView(
        extension: extension,
        extensionContext: extensionContext,
      );
    }

    return _PluginUnsupportedBody(
      title: context.localeText('通用面板', 'Plugin panel'),
      message: extension.capability.id,
    );
  }
}

class _PluginBuiltinView extends StatefulWidget {
  const _PluginBuiltinView({
    required this.extension,
    required this.extensionContext,
  });

  final ClientExtensionDescriptor extension;
  final Map<String, Object?> extensionContext;

  @override
  State<_PluginBuiltinView> createState() => _PluginBuiltinViewState();
}

class _PluginBuiltinViewState extends State<_PluginBuiltinView> {
  bool _running = false;
  bool _failed = false;
  String? _message;

  _PluginBuiltinConfig get _config => _builtinConfigFor(widget.extension);

  @override
  void initState() {
    super.initState();
    if (_config.autoRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _PluginBuiltinView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extension.id != widget.extension.id && _config.autoRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run();
      });
    }
  }

  Future<void> _run() async {
    if (_running) return;
    final config = _config;
    if (config.component == 'host_method' && config.method.isEmpty) {
      setState(() {
        _failed = true;
        _message = 'Missing builtin host method.';
      });
      return;
    }

    setState(() {
      _running = true;
      _failed = false;
      _message = null;
    });
    try {
      final api = AppScope.appOf(context).pluginCapabilities;
      final result = config.component == 'host_method'
          ? await api.invokePluginHost<Object?>(
              pluginId: widget.extension.pluginId,
              uiCapabilityId: widget.extension.capability.id,
              uiGrant: widget.extension.clientGrant ?? '',
              method: config.method,
              params: config.params,
            )
          : await api.invokePluginCapability<Object?>(
              pluginId: widget.extension.pluginId,
              capabilityId: widget.extension.capability.id,
              uiCapabilityId: widget.extension.capability.id,
              uiGrant: widget.extension.clientGrant,
              params: {
                'slot': widget.extension.slot.value,
                'contexts': widget.extension.contexts,
                'context': widget.extensionContext,
                'params': config.params,
              },
            );
      if (!mounted) return;
      setState(() => _message = _formatActionResult(result));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _message = error.toString();
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config.component == 'document_reader') {
      return _PluginDocumentReaderPanel(
        extensionContext: widget.extensionContext,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _running ? null : _run,
          icon: _running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(config.submitLabel),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _PluginActionMessage(
            message: _message ?? 'Ready.',
            failed: _failed,
          ),
        ),
      ],
    );
  }
}

class _PluginBuiltinConfig {
  const _PluginBuiltinConfig({
    required this.component,
    required this.method,
    required this.params,
    required this.autoRun,
    required this.submitLabel,
  });

  final String component;
  final String method;
  final Map<String, dynamic> params;
  final bool autoRun;
  final String submitLabel;
}

_PluginBuiltinConfig _builtinConfigFor(ClientExtensionDescriptor extension) {
  final builtin = asMap(extension.render['builtin']);
  final component =
      (builtin['component'] ?? extension.render['component'])?.toString() ??
          'capability_result';
  return _PluginBuiltinConfig(
    component: component,
    method: (builtin['method'] ?? extension.render['method'])?.toString() ?? '',
    params: asMap(builtin['params'] ?? extension.render['params']),
    autoRun:
        builtin['auto_run'] == true || extension.render['auto_run'] == true,
    submitLabel: (builtin['submit_label'] ?? extension.render['submit_label'])
            ?.toString() ??
        'Run',
  );
}
