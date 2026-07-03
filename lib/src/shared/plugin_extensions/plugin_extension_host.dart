import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/document_reader/document_reader.dart';
import '../../core/models/_helpers.dart' show asMap;
import '../../core/plugin_extensions/registry.dart';
import '../../core/plugin_extensions/types.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';
import '../app_scope.dart';

const _missingPluginUiEntryError = '__missing_plugin_ui_entry__';

class PluginExtensionHost extends StatefulWidget {
  const PluginExtensionHost({
    super.key,
    required this.bottomOffset,
  });

  final double bottomOffset;

  @override
  State<PluginExtensionHost> createState() => _PluginExtensionHostState();
}

class _PluginExtensionHostState extends State<PluginExtensionHost> {
  ClientExtensionRegistrySnapshot _registry =
      ClientExtensionRegistrySnapshot.empty;
  ClientExtensionDescriptor? _activeExtension;
  String? _loadedToken;
  int? _loadedRevision;
  bool _loading = false;
  bool _reloadQueued = false;
  bool _running = false;
  bool _menuOpen = false;
  String? _actionMessage;
  bool _actionFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.appOf(context);
    final revision = app.pluginExtensionRevision;
    if (app.offlineMode || app.token == null) {
      _loadedToken = null;
      _loadedRevision = null;
      if (_registry.extensions.isNotEmpty) {
        setState(() => _registry = ClientExtensionRegistrySnapshot.empty);
      }
      return;
    }
    if (app.token == _loadedToken && revision == _loadedRevision) return;
    _loadedToken = app.token;
    _loadedRevision = revision;
    _loadExtensions();
  }

  Future<void> _loadExtensions() async {
    if (_loading) {
      _reloadQueued = true;
      return;
    }
    setState(() => _loading = true);
    try {
      final api = AppScope.appOf(context).pluginCapabilities;
      final registrations = [
        ...await api.listPluginCapabilities(kind: 'ui_extension'),
        ...await api.listPluginCapabilities(kind: 'client_extension'),
      ];
      if (!mounted) return;
      setState(() {
        _registry = buildClientExtensionRegistry(registrations);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _registry = ClientExtensionRegistrySnapshot.empty);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_reloadQueued) {
          _reloadQueued = false;
          _loadExtensions();
        }
      }
    }
  }

  void _openExtension(ClientExtensionDescriptor extension) {
    setState(() {
      _activeExtension = extension;
      _menuOpen = false;
      _actionMessage = null;
      _actionFailed = false;
    });
  }

  Future<void> _invokeActiveAction() async {
    final extension = _activeExtension;
    if (extension == null || _running) return;

    setState(() {
      _running = true;
      _actionMessage = null;
      _actionFailed = false;
    });
    try {
      final result = await AppScope.appOf(context)
          .pluginCapabilities
          .invokePluginCapability(
        pluginId: extension.pluginId,
        capabilityId: extension.capability.id,
        params: {
          'slot': extension.slot.value,
          'contexts': extension.contexts,
          'context': const <String, Object?>{},
        },
      );
      if (!mounted) return;
      setState(() => _actionMessage = _formatActionResult(result));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionFailed = true;
        _actionMessage = error.toString();
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final floating =
        _registry.bySlot[ClientExtensionSlot.globalFloatingAction] ?? const [];
    final panels =
        _registry.bySlot[ClientExtensionSlot.globalPanel] ?? const [];
    final primary = floating.isNotEmpty ? floating : panels;

    if (primary.isEmpty && _activeExtension == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (primary.isNotEmpty)
          Positioned(
            right: 18,
            bottom: widget.bottomOffset,
            child: _PluginFloatingLauncher(
              extensions: primary,
              menuOpen: _menuOpen,
              onToggle: () => setState(() => _menuOpen = !_menuOpen),
              onOpen: _openExtension,
            ),
          ),
        if (_activeExtension != null)
          Positioned.fill(
            child: _PluginExtensionPanel(
              extension: _activeExtension!,
              running: _running,
              message: _actionMessage,
              failed: _actionFailed,
              onClose: () => setState(() => _activeExtension = null),
              onInvoke: _invokeActiveAction,
              extensionContext: const <String, Object?>{},
            ),
          ),
      ],
    );
  }
}

class PluginExtensionSlot extends StatefulWidget {
  const PluginExtensionSlot({
    super.key,
    required this.slot,
    this.extensionContext = const <String, Object?>{},
    this.limit,
    this.spacing = 6,
    this.buttonSize = 38,
    this.iconSize = 18,
    this.padding,
  });

  final ClientExtensionSlot slot;
  final Map<String, Object?> extensionContext;
  final int? limit;
  final double spacing;
  final double buttonSize;
  final double iconSize;
  final EdgeInsetsGeometry? padding;

  @override
  State<PluginExtensionSlot> createState() => _PluginExtensionSlotState();
}

class _PluginExtensionSlotState extends State<PluginExtensionSlot> {
  ClientExtensionRegistrySnapshot _registry =
      ClientExtensionRegistrySnapshot.empty;
  ClientExtensionDescriptor? _activeExtension;
  OverlayEntry? _overlayEntry;
  String? _loadedToken;
  int? _loadedRevision;
  bool _loading = false;
  bool _reloadQueued = false;
  bool _running = false;
  String? _actionMessage;
  bool _actionFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.appOf(context);
    final revision = app.pluginExtensionRevision;
    if (app.offlineMode || app.token == null) {
      _loadedToken = null;
      _loadedRevision = null;
      if (_registry.extensions.isNotEmpty) {
        setState(() => _registry = ClientExtensionRegistrySnapshot.empty);
      }
      return;
    }
    if (app.token == _loadedToken && revision == _loadedRevision) return;
    _loadedToken = app.token;
    _loadedRevision = revision;
    _loadExtensions();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadExtensions() async {
    if (_loading) {
      _reloadQueued = true;
      return;
    }
    setState(() => _loading = true);
    try {
      final api = AppScope.appOf(context).pluginCapabilities;
      final registrations = [
        ...await api.listPluginCapabilities(kind: 'ui_extension'),
        ...await api.listPluginCapabilities(kind: 'client_extension'),
      ];
      if (!mounted) return;
      setState(() {
        _registry = buildClientExtensionRegistry(registrations);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _registry = ClientExtensionRegistrySnapshot.empty);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_reloadQueued) {
          _reloadQueued = false;
          _loadExtensions();
        }
      }
    }
  }

  void _openExtension(ClientExtensionDescriptor extension) {
    _activeExtension = extension;
    _running = false;
    _actionMessage = null;
    _actionFailed = false;
    _showOverlay();
    if (extension.renderMode == ClientExtensionRenderMode.action) {
      _invokeActiveAction();
    }
  }

  Future<void> _invokeActiveAction() async {
    final extension = _activeExtension;
    if (extension == null || _running) return;

    _running = true;
    _actionMessage = null;
    _actionFailed = false;
    _refreshOverlay();
    try {
      final result = await AppScope.appOf(context)
          .pluginCapabilities
          .invokePluginCapability(
        pluginId: extension.pluginId,
        capabilityId: extension.capability.id,
        params: {
          'slot': extension.slot.value,
          'contexts': extension.contexts,
          'context': widget.extensionContext,
        },
      );
      if (!mounted) return;
      _actionMessage = _formatActionResult(result);
    } catch (error) {
      if (!mounted) return;
      _actionFailed = true;
      _actionMessage = error.toString();
    } finally {
      if (mounted) {
        _running = false;
        _refreshOverlay();
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (overlayContext) {
          final extension = _activeExtension;
          if (extension == null) return const SizedBox.shrink();
          return _PluginExtensionPanel(
            extension: extension,
            running: _running,
            message: _actionMessage,
            failed: _actionFailed,
            onClose: _closeOverlay,
            onInvoke: _invokeActiveAction,
            extensionContext: widget.extensionContext,
          );
        },
      );
      Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    } else {
      _refreshOverlay();
    }
  }

  void _refreshOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _closeOverlay() {
    _removeOverlay();
    if (!mounted) return;
    setState(() {
      _activeExtension = null;
      _running = false;
      _actionMessage = null;
      _actionFailed = false;
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final extensions = _registry.bySlot[widget.slot] ?? const [];
    final visible = widget.limit == null
        ? extensions
        : extensions
            .take(widget.limit!.clamp(0, extensions.length).toInt())
            .toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          if (index > 0) SizedBox(width: widget.spacing),
          Tooltip(
            message: visible[index].label,
            child: SizedBox(
              width: widget.buttonSize,
              height: widget.buttonSize,
              child: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: () => _openExtension(visible[index]),
                icon: _PluginExtensionIcon(
                  extension: visible[index],
                  size: widget.iconSize,
                ),
              ),
            ),
          ),
        ],
      ],
    );
    final padding = widget.padding;
    return padding == null ? row : Padding(padding: padding, child: row);
  }
}

IconData _iconForSlot(ClientExtensionSlot slot) {
  return switch (slot) {
    ClientExtensionSlot.globalFloatingAction => Icons.chat_bubble_rounded,
    ClientExtensionSlot.readerToolbarAction => Icons.auto_stories_rounded,
    ClientExtensionSlot.readerDocumentViewer => Icons.description_rounded,
    ClientExtensionSlot.readerSidePanel => Icons.view_sidebar_rounded,
    ClientExtensionSlot.settingsSection => Icons.tune_rounded,
    ClientExtensionSlot.bookDetailAction => Icons.menu_book_rounded,
    ClientExtensionSlot.globalPanel => Icons.extension_rounded,
  };
}

IconData? _iconForName(String value) {
  final normalized = value
      .trim()
      .replaceFirst(RegExp(r'^lucide:', caseSensitive: false), '')
      .replaceAll('_', '-')
      .replaceAll(' ', '-')
      .toLowerCase();

  return switch (normalized) {
    'message-circle' ||
    'message-square' ||
    'messages-square' ||
    'chat' =>
      Icons.chat_bubble_rounded,
    'book' || 'book-open' || 'menu-book' => Icons.menu_book_rounded,
    'library' || 'books' => Icons.local_library_rounded,
    'search' => Icons.search_rounded,
    'settings' || 'sliders-horizontal' || 'tune' => Icons.tune_rounded,
    'sparkles' || 'wand-sparkles' || 'bot' || 'brain' => Icons.auto_awesome,
    'file' || 'file-text' || 'description' => Icons.description_rounded,
    'panel-right' || 'sidebar' || 'view-sidebar' => Icons.view_sidebar_rounded,
    'play' || 'circle-play' => Icons.play_arrow_rounded,
    'list' || 'list-music' || 'playlist' => Icons.playlist_play_rounded,
    'heart' => Icons.favorite_rounded,
    'star' => Icons.star_rounded,
    'download' => Icons.download_rounded,
    'upload' => Icons.upload_rounded,
    'tool' || 'tools' || 'wrench' => Icons.build_rounded,
    'plug' || 'plug-zap' || 'extension' => Icons.extension_rounded,
    'grid' || 'grid-2x2' || 'layout-grid' => Icons.grid_view_rounded,
    _ => null,
  };
}

String? _iconText(Object? icon) {
  if (icon is String) {
    final text = icon.trim();
    return text.isEmpty ? null : text;
  }
  if (icon is Map) {
    for (final key in const ['src', 'name', 'value']) {
      final value = icon[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
  }
  return null;
}

String? _iconType(Object? icon) {
  if (icon is Map) {
    final value = icon['type'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim().toLowerCase();
    }
  }
  return null;
}

bool _isImageIcon(String value) =>
    value.startsWith('http://') ||
    value.startsWith('https://') ||
    value.startsWith('assets/');

bool _isEmojiLikeIcon(String value) =>
    value.runes.length <= 4 &&
    !RegExp(r'^[a-z0-9:_ -]+$', caseSensitive: false).hasMatch(value);

class _PluginExtensionIcon extends StatelessWidget {
  const _PluginExtensionIcon({
    required this.extension,
    required this.size,
    this.color,
  });

  final ClientExtensionDescriptor extension;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final value = _iconText(extension.icon);
    final type = _iconType(extension.icon);

    if (value != null &&
        (type == 'image' || type == 'url' || _isImageIcon(value))) {
      final image = value.startsWith('assets/')
          ? Image.asset(value, width: size, height: size, fit: BoxFit.contain)
          : Image.network(
              value,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                _iconForSlot(extension.slot),
                size: size,
                color: color,
              ),
            );
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: image,
      );
    }

    if (value != null && type != 'emoji') {
      final icon = _iconForName(value);
      if (icon != null) {
        return Icon(icon, size: size, color: color);
      }
    }

    if (value != null && (type == 'emoji' || _isEmojiLikeIcon(value))) {
      return Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size, height: 1),
      );
    }

    return Icon(_iconForSlot(extension.slot), size: size, color: color);
  }
}

class _PluginFloatingLauncher extends StatelessWidget {
  const _PluginFloatingLauncher({
    required this.extensions,
    required this.menuOpen,
    required this.onToggle,
    required this.onOpen,
  });

  final List<ClientExtensionDescriptor> extensions;
  final bool menuOpen;
  final VoidCallback onToggle;
  final ValueChanged<ClientExtensionDescriptor> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (menuOpen) ...[
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.58,
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final extension in extensions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PluginFloatingMenuItem(
                        extension: extension,
                        onPressed: () => onOpen(extension),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
        ],
        Tooltip(
          message: context.localeText('插件入口', 'Plugin entries'),
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(child: _PluginLauncherIcon()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PluginFloatingMenuItem extends StatelessWidget {
  const _PluginFloatingMenuItem({
    required this.extension,
    required this.onPressed,
  });

  final ClientExtensionDescriptor extension;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: extension.label,
      child: Material(
        color: context.cardColor.withValues(alpha: 0.96),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: context.faintBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: _PluginExtensionIcon(
                extension: extension,
                size: 19,
                color: context.isDark
                    ? const Color(0xff7dd3fc)
                    : AppColors.primary600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PluginLauncherIcon extends StatelessWidget {
  const _PluginLauncherIcon();

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xff54cde3),
      Color(0xff48bfdd),
      Color(0xff32b4d4),
      Color(0xff249ec8),
    ];

    return SizedBox(
      width: 24,
      height: 24,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _PluginLauncherTile(color: colors[0])),
                const SizedBox(width: 2),
                Expanded(child: _PluginLauncherTile(color: colors[1])),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _PluginLauncherTile(color: colors[2])),
                const SizedBox(width: 2),
                Expanded(child: _PluginLauncherTile(color: colors[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginLauncherTile extends StatelessWidget {
  const _PluginLauncherTile({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.2),
      ),
    );
  }
}

class _PluginExtensionPanel extends StatelessWidget {
  const _PluginExtensionPanel({
    required this.extension,
    required this.running,
    required this.failed,
    required this.onClose,
    required this.onInvoke,
    required this.extensionContext,
    this.message,
  });

  final ClientExtensionDescriptor extension;
  final bool running;
  final bool failed;
  final String? message;
  final VoidCallback onClose;
  final VoidCallback onInvoke;
  final Map<String, Object?> extensionContext;

  @override
  Widget build(BuildContext context) {
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
                width: MediaQuery.of(context).size.width < 560
                    ? double.infinity
                    : 420,
                height: MediaQuery.of(context).size.height * 0.72,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(10),
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
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: _PluginExtensionPanelBody(
                          extension: extension,
                          running: running,
                          failed: failed,
                          message: message,
                          onInvoke: onInvoke,
                          extensionContext: extensionContext,
                        ),
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
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.faintBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
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
          const SizedBox(width: 10),
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
          if (message != null) ...[
            const SizedBox(height: 14),
            Expanded(
              child: _PluginActionMessage(
                message: message!,
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
              method: config.method,
              params: config.params,
            )
          : await api.invokePluginCapability<Object?>(
              pluginId: widget.extension.pluginId,
              capabilityId: widget.extension.capability.id,
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

class _PluginDocumentReaderPanel extends StatefulWidget {
  const _PluginDocumentReaderPanel({required this.extensionContext});

  final Map<String, Object?> extensionContext;

  @override
  State<_PluginDocumentReaderPanel> createState() =>
      _PluginDocumentReaderPanelState();
}

class _PluginDocumentReaderPanelState
    extends State<_PluginDocumentReaderPanel> {
  late final TextEditingController _uriController =
      TextEditingController(text: _resourceFromContext().uri);
  late final TextEditingController _extensionController =
      TextEditingController(text: _resourceFromContext().extension ?? '');
  final TextEditingController _pageController =
      TextEditingController(text: '1');

  DocumentReaderSession? _session;
  DocumentMetadata? _metadata;
  List<DocumentSection> _sections = const [];
  String? _sectionId;
  DocumentChunk? _chunk;
  DocumentPageRender? _page;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _uriController.dispose();
    _extensionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  DocumentResourceRef _resourceFromContext() {
    final context = widget.extensionContext;
    final uri = _contextString(context, 'document_uri') ??
        _contextString(context, 'uri') ??
        _contextString(context, 'chapter_path') ??
        _contextString(context, 'book_path') ??
        '';
    return DocumentResourceRef(
      uri: uri,
      extension: _contextString(context, 'extension') ??
          _contextString(context, 'document_extension') ??
          _extensionFromUri(uri),
      mimeType: _contextString(context, 'mime_type'),
      bookId: _contextString(context, 'book_id'),
      chapterId: _contextString(context, 'chapter_id'),
    );
  }

  DocumentResourceRef _resource() {
    final contextResource = _resourceFromContext();
    final uri = _uriController.text.trim();
    final extension = _extensionController.text.trim();
    return DocumentResourceRef(
      uri: uri,
      extension: extension.isNotEmpty ? extension : _extensionFromUri(uri),
      mimeType: contextResource.mimeType,
      bookId: contextResource.bookId,
      chapterId: contextResource.chapterId,
    );
  }

  Future<void> _open() async {
    if (_loading || _uriController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _session = null;
      _metadata = null;
      _sections = const [];
      _sectionId = null;
      _chunk = null;
      _page = null;
    });
    try {
      final client = AppScope.appOf(context).documentReader;
      final session = await client.openDocumentSession(_resource());
      if (session == null) {
        if (!mounted) return;
        setState(() => _error = context.localeText(
              '没有内容处理器支持此文档。',
              'No content processor supports this document.',
            ));
        return;
      }
      final results = await Future.wait<Object?>([
        client
            .extractDocumentMetadata(session.resource, session: session)
            .catchError((_) => null),
        client
            .listDocumentSections(session.resource, session: session)
            .catchError((_) => const <DocumentSection>[]),
      ]);
      if (!mounted) return;
      final sections = results[1] as List<DocumentSection>;
      setState(() {
        _session = session;
        _metadata = results[0] as DocumentMetadata?;
        _sections = sections;
        _sectionId = sections.isNotEmpty ? sections.first.id : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _readChunk() async {
    final session = _session;
    if (_loading || session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chunk =
          await AppScope.appOf(context).documentReader.readDocumentChunk(
                session.resource,
                sectionId: _sectionId,
                limit: 4000,
                session: session,
              );
      if (!mounted) return;
      setState(() => _chunk = chunk);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _renderPage() async {
    final session = _session;
    if (_loading || session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page =
          await AppScope.appOf(context).documentReader.renderDocumentPage(
                session.resource,
                page: int.tryParse(_pageController.text.trim()) ?? 1,
                session: session,
              );
      if (!mounted) return;
      setState(() => _page = page);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _uriController,
          decoration: InputDecoration(
            labelText: context.localeText('资源 URI', 'URI'),
            hintText: context.localeText(
              '书籍/章节路径或插件资源 URI',
              'Book/chapter path or plugin resource URI',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 92,
              child: TextField(
                controller: _extensionController,
                decoration: InputDecoration(
                  labelText: context.localeText('扩展名', 'Ext'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _open,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_stories_rounded),
                label: Text(context.localeText('打开', 'Open')),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _PluginActionMessage(message: _error!, failed: true),
        ],
        if (_session != null) ...[
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PluginActionMessage(
                    message: _formatDocumentSummary(),
                    failed: false,
                  ),
                  const SizedBox(height: 12),
                  if (_sections.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue:
                          _sections.any((section) => section.id == _sectionId)
                              ? _sectionId
                              : _sections.first.id,
                      decoration: InputDecoration(
                        labelText: context.localeText('分区', 'Section'),
                      ),
                      items: [
                        for (final section in _sections)
                          DropdownMenuItem(
                            value: section.id,
                            child: Text(section.title ?? section.id),
                          ),
                      ],
                      onChanged: (value) => setState(() => _sectionId = value),
                    ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loading ? null : _readChunk,
                    child: Text(context.localeText('读取片段', 'Chunk')),
                  ),
                  if (_chunk != null) ...[
                    const SizedBox(height: 10),
                    _PluginActionMessage(
                      message: _chunk!.text ??
                          _chunk!.html ??
                          _jsonEncode(_chunkSummary(_chunk!)),
                      failed: false,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 92,
                        child: TextField(
                          controller: _pageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.localeText('页码', 'Page'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _renderPage,
                          child:
                              Text(context.localeText('渲染页面', 'Render page')),
                        ),
                      ),
                    ],
                  ),
                  if (_page != null) ...[
                    const SizedBox(height: 10),
                    if (_page!.imageBase64 != null)
                      Image.memory(
                        base64Decode(_page!.imageBase64!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _PluginActionMessage(
                          message: _jsonEncode(_pageSummary(_page!)),
                          failed: false,
                        ),
                      )
                    else
                      _PluginActionMessage(
                        message: _page!.text ??
                            _page!.svg ??
                            _jsonEncode(_pageSummary(_page!)),
                        failed: false,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ] else
          const Spacer(),
      ],
    );
  }

  String _formatDocumentSummary() {
    final session = _session;
    return _jsonEncode({
      'processor': session?.processor.capability.id,
      'probe': {
        'supported': session?.probe?.supported,
        'confidence': session?.probe?.confidence,
        'reason': session?.probe?.reason,
      },
      'metadata': {
        'title': _metadata?.title,
        'author': _metadata?.author,
        'language': _metadata?.language,
        'page_count': _metadata?.pageCount,
        'word_count': _metadata?.wordCount,
        ...?_metadata?.extra,
      },
    });
  }
}

String? _contextString(Map<String, Object?> context, String key) {
  final value = context[key];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _extensionFromUri(String uri) {
  final match = RegExp(r'\.([a-z0-9]+)$', caseSensitive: false)
      .firstMatch(uri.split('?').first);
  return match?.group(1) ?? '';
}

String _jsonEncode(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

Map<String, Object?> _chunkSummary(DocumentChunk chunk) => {
      'section_id': chunk.sectionId,
      'text': chunk.text,
      'html': chunk.html,
      'next_cursor': chunk.nextCursor,
      'progress': chunk.progress,
      ...chunk.extra,
    };

Map<String, Object?> _pageSummary(DocumentPageRender page) => {
      'page': page.page,
      'text': page.text,
      'svg': page.svg,
      'width': page.width,
      'height': page.height,
      ...page.extra,
    };

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
        _message = error.toString();
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  if (_message != null) ...[
                    const SizedBox(height: 2),
                    _PluginActionMessage(message: _message!, failed: _failed),
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

class _PluginWebContainer extends StatefulWidget {
  const _PluginWebContainer({
    required this.extension,
    required this.extensionContext,
  });

  final ClientExtensionDescriptor extension;
  final Map<String, Object?> extensionContext;

  @override
  State<_PluginWebContainer> createState() => _PluginWebContainerState();
}

class _PluginWebContainerState extends State<_PluginWebContainer> {
  WebViewController? _controller;
  String? _error;
  bool _unsupported = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _PluginWebContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extension.id != widget.extension.id) {
      _initialize();
    }
  }

  void _initialize() {
    final entry = widget.extension.entry;
    if (entry == null) {
      setState(() {
        _controller = null;
        _error = _missingPluginUiEntryError;
        _unsupported = false;
      });
      return;
    }

    if (!_pluginWebViewSupported()) {
      setState(() {
        _controller = null;
        _error = null;
        _unsupported = true;
      });
      return;
    }

    final app = AppScope.appOf(context);
    final assetUrl = app.pluginCapabilities.pluginAssetUrl(
      pluginId: widget.extension.pluginId,
      entry: entry,
    );
    final loadAssetAsTopLevel = _pluginWebViewLoadsAssetAsTopLevel();
    final pluginTheme = _pluginThemePayload(context);
    final initPayload = _pluginInitPayloadJson(
      extension: widget.extension,
      extensionContext: widget.extensionContext,
      theme: pluginTheme,
    );

    final WebViewController controller;
    try {
      late final WebViewController nextController;
      nextController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              if (loadAssetAsTopLevel) {
                if (!request.isMainFrame) {
                  return NavigationDecision.navigate;
                }
                return _isPluginAssetUrl(
                  request.url,
                  assetUrl: assetUrl,
                  pluginId: widget.extension.pluginId,
                )
                    ? NavigationDecision.navigate
                    : NavigationDecision.prevent;
              }
              if (request.isMainFrame) {
                return NavigationDecision.navigate;
              }
              if (request.url == assetUrl ||
                  request.url.startsWith('$assetUrl#') ||
                  request.url.startsWith('$assetUrl?')) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
            onPageFinished: (_) {
              if (loadAssetAsTopLevel) {
                _installTopLevelPluginBridge(
                  nextController,
                  initPayload: initPayload,
                  theme: pluginTheme,
                );
              }
            },
            onWebResourceError: (error) {
              if (!mounted || error.isForMainFrame != true) return;
              setState(() => _error = error.description);
            },
          ),
        )
        ..addJavaScriptChannel(
          'TingPluginBridge',
          onMessageReceived: _handleBridgeMessage,
        );
      controller = nextController;
      if (loadAssetAsTopLevel) {
        controller.loadRequest(Uri.parse(assetUrl));
      } else {
        controller.loadHtmlString(
          _pluginWebContainerHtml(
            initPayload: initPayload,
            assetUrl: assetUrl,
          ),
          baseUrl: app.api.baseUrl,
        );
      }
    } catch (error) {
      setState(() {
        _controller = null;
        _error = error.toString();
        _unsupported = false;
      });
      return;
    }

    setState(() {
      _controller = controller;
      _error = null;
      _unsupported = false;
    });
  }

  Future<void> _handleBridgeMessage(JavaScriptMessage message) async {
    final request = _decodeBridgeRequest(message.message);
    if (request == null) return;

    try {
      final result = await _invokeBridgeRequest(request);
      await _postBridgeResponse(request, ok: true, result: result);
    } catch (error) {
      await _postBridgeResponse(
        request,
        ok: false,
        error: error.toString(),
      );
    }
  }

  Future<Object?> _invokeBridgeRequest(_PluginBridgeRequest request) {
    final pluginCapabilities = AppScope.appOf(context).pluginCapabilities;
    switch (request.method) {
      case 'capability.invoke':
        final params = request.params is Map
            ? Map<String, dynamic>.from(request.params as Map)
            : const <String, dynamic>{};
        final capabilityId = params['capabilityId']?.toString() ??
            widget.extension.capability.id;
        return pluginCapabilities.invokePluginCapability<Object?>(
          pluginId: widget.extension.pluginId,
          capabilityId: capabilityId,
          params: params['params'] ?? const {},
        );
      case 'host.invoke':
        final params = request.params is Map
            ? Map<String, dynamic>.from(request.params as Map)
            : const <String, dynamic>{};
        final method = params['method']?.toString();
        if (method == null || method.trim().isEmpty) {
          throw StateError('Missing host method');
        }
        return pluginCapabilities.invokePluginHost<Object?>(
          pluginId: widget.extension.pluginId,
          method: method,
          params: params['params'] ?? const {},
        );
      default:
        throw StateError('Unknown bridge method: ${request.method}');
    }
  }

  Future<void> _postBridgeResponse(
    _PluginBridgeRequest request, {
    required bool ok,
    Object? result,
    String? error,
  }) async {
    final controller = _controller;
    if (controller == null) return;

    final payload = jsonEncode({
      'type': 'ting-plugin:response',
      'id': request.id,
      'ok': ok,
      if (ok) 'result': result,
      if (!ok) 'error': error,
    });
    await controller.runJavaScript('window.__tingPluginRespond($payload);');
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_unsupported) {
      return _PluginUnsupportedBody(
        title: context.localeText('WebView 不可用', 'WebView unavailable'),
        message: context.localeText(
          '当前平台暂不支持插件 Web UI。',
          'Plugin Web UI is not supported on this platform yet.',
        ),
      );
    }
    if (_error != null) {
      return _PluginUnsupportedBody(
        title: context.localeText('Web UI 加载失败', 'Web UI failed'),
        message: _error == _missingPluginUiEntryError
            ? context.localeText('缺少插件 UI 入口。', 'Missing plugin UI entry.')
            : _error!,
      );
    }
    if (controller == null) {
      return _PluginUnsupportedBody(
        title: context.localeText('Web UI 待接入', 'Web UI pending'),
        message: widget.extension.capability.id,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: WebViewWidget(controller: controller),
    );
  }
}

bool _pluginWebViewLoadsAssetAsTopLevel() {
  // The Windows WebView2 implementation ignores loadHtmlString(baseUrl).
  // Loading the asset as the top-level document keeps the plugin UI same-origin
  // with the backend, so the plugin asset CSP `frame-ancestors 'self'` remains valid.
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
}

bool _pluginWebViewSupported() {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
}

class _PluginBridgeRequest {
  const _PluginBridgeRequest({
    required this.id,
    required this.method,
    this.params,
  });

  final String id;
  final String method;
  final Object? params;
}

_PluginBridgeRequest? _decodeBridgeRequest(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  if (decoded['type'] != 'ting-plugin:request') return null;
  final id = decoded['id']?.toString();
  final method = decoded['method']?.toString();
  if (id == null || id.isEmpty || method == null || method.isEmpty) {
    return null;
  }
  return _PluginBridgeRequest(
    id: id,
    method: method,
    params: decoded['params'],
  );
}

Future<void> _installTopLevelPluginBridge(
  WebViewController controller, {
  required String initPayload,
  required Map<String, Object?> theme,
}) async {
  final colorScheme = jsonEncode(theme['colorScheme']?.toString() ?? 'light');
  await controller.runJavaScript('''
(function() {
  const colorScheme = $colorScheme;
  document.documentElement.style.colorScheme = colorScheme;
  document.documentElement.dataset.tingTheme = colorScheme;
  if (window.__tingPluginBridgeInstalled) {
    window.postMessage($initPayload, "*");
    return;
  }
  window.__tingPluginBridgeInstalled = true;
  window.__tingPluginRespond = function(response) {
    window.postMessage(response, "*");
  };
  window.addEventListener("message", function(event) {
    const data = event.data;
    if (!data || data.type !== "ting-plugin:request" || !data.id) return;
    TingPluginBridge.postMessage(JSON.stringify(data));
  });
  window.postMessage($initPayload, "*");
})();
''');
}

bool _isPluginAssetUrl(
  String url, {
  required String assetUrl,
  required String pluginId,
}) {
  final uri = Uri.tryParse(url);
  final assetUri = Uri.tryParse(assetUrl);
  if (uri == null || assetUri == null) return false;
  if (uri.scheme != assetUri.scheme ||
      uri.host != assetUri.host ||
      uri.port != assetUri.port) {
    return false;
  }
  final segments = uri.pathSegments;
  if (segments.length < 5) return false;
  final pluginSegment = segments[3];
  return segments[0] == 'api' &&
      segments[1] == 'v1' &&
      segments[2] == 'plugin-assets' &&
      (pluginSegment == pluginId ||
          pluginSegment == Uri.encodeComponent(pluginId));
}

String _pluginInitPayloadJson({
  required ClientExtensionDescriptor extension,
  required Map<String, Object?> extensionContext,
  required Map<String, Object?> theme,
}) {
  return jsonEncode({
    'type': 'ting-plugin:init',
    'pluginId': extension.pluginId,
    'pluginName': extension.pluginName,
    'capabilityId': extension.capability.id,
    'slot': extension.slot.value,
    'contexts': extension.contexts,
    'context': extensionContext,
    'theme': theme,
  });
}

Map<String, Object?> _pluginThemePayload(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.brightness == Brightness.dark ? 'dark' : 'light';
  return {
    'colorScheme': colorScheme,
    'brightness': colorScheme,
  };
}

String _pluginWebContainerHtml({
  required String initPayload,
  required String assetUrl,
}) {
  final assetPayload = jsonEncode(assetUrl);

  return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body, iframe { margin: 0; width: 100%; height: 100%; border: 0; background: transparent; }
  </style>
</head>
<body>
  <iframe id="plugin-frame" sandbox="allow-scripts allow-forms"></iframe>
  <script>
    const frame = document.getElementById('plugin-frame');
    const initPayload = $initPayload;
    const assetUrl = $assetPayload;

    window.__tingPluginRespond = function(response) {
      const frameWindow = frame.contentWindow;
      if (frameWindow) frameWindow.postMessage(response, '*');
    };

    window.addEventListener('message', function(event) {
      const data = event.data;
      if (!data || data.type !== 'ting-plugin:request' || !data.id) return;
      TingPluginBridge.postMessage(JSON.stringify(data));
    });

    frame.addEventListener('load', function() {
      if (frame.contentWindow) {
        frame.contentWindow.postMessage(initPayload, '*');
      }
    });
    frame.src = assetUrl;
  </script>
</body>
</html>
''';
}

class _PluginActionMessage extends StatelessWidget {
  const _PluginActionMessage({
    required this.message,
    required this.failed,
  });

  final String message;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final color = failed ? const Color(0xffdc2626) : context.mutedText;
    final background = failed
        ? const Color(0xfffff1f2)
        : (context.isDark ? AppColors.slate900 : AppColors.slate50);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.faintBorder),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          message,
          style: TextStyle(
            color: color,
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _PluginUnsupportedBody extends StatelessWidget {
  const _PluginUnsupportedBody({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.extension_rounded, color: context.mutedText, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SelectableText(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

String _formatActionResult(Object? value) {
  if (value is String) return value;
  try {
    return const JsonEncoder.withIndent('  ').convert(value ?? {'ok': true});
  } catch (_) {
    return value?.toString() ?? 'ok';
  }
}
