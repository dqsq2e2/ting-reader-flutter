import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:lucide_icons_flutter/test_icons.dart' as lucide_catalog;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_plugin.dart';

import '../../core/document_reader/document_reader.dart';
import '../../core/api/api_error.dart';
import '../../core/auth/fnos_gateway_auth.dart';
import '../../core/models/_helpers.dart' show asMap;
import '../../core/plugin_extensions/types.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/external_links.dart';
import '../../core/utils/locale.dart';
import '../app_scope.dart';

part 'plugin_extension_launcher.dart';
part 'plugin_extension_panel.dart';
part 'plugin_extension_reader.dart';
part 'plugin_extension_schema.dart';
part 'plugin_extension_web.dart';
part 'plugin_extension_document.dart';

const _missingPluginUiEntryError = '__missing_plugin_ui_entry__';
const _maxPluginDocumentBytes = 2 * 1024 * 1024;
const _maxPluginTextAssetBytes = 2 * 1024 * 1024;
const _maxBundledPluginBytes = 8 * 1024 * 1024;

mixin _PluginExtensionRegistryLoader<T extends StatefulWidget> on State<T> {
  ClientExtensionRegistrySnapshot get _registry =>
      AppScope.appOf(context).clientExtensions.snapshot;
  bool get _loading => AppScope.appOf(context).clientExtensions.loading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppScope.appOf(context).ensureClientExtensions();
  }
}

class PluginExtensionHost extends StatefulWidget {
  const PluginExtensionHost({
    super.key,
    required this.bottomOffset,
    this.enabled = true,
  });

  final double bottomOffset;
  final bool enabled;

  @override
  State<PluginExtensionHost> createState() => _PluginExtensionHostState();
}

class _PluginExtensionHostState extends State<PluginExtensionHost>
    with _PluginExtensionRegistryLoader<PluginExtensionHost> {
  ClientExtensionDescriptor? _activeExtension;
  bool _running = false;
  bool _menuOpen = false;
  String? _actionMessage;
  bool _actionFailed = false;

  @override
  void didUpdateWidget(covariant PluginExtensionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _activeExtension = null;
      _menuOpen = false;
      _actionMessage = null;
      _actionFailed = false;
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
        uiCapabilityId: extension.capability.id,
        uiGrant: extension.clientGrant,
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
        _actionMessage = ApiError.messageFor(error);
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    final app = AppScope.appOf(context);
    final floating =
        (_registry.bySlot[ClientExtensionSlot.globalFloatingAction] ?? const [])
            .where((extension) => !extension.adminOnly || app.isAdmin)
            .toList(growable: false);
    final panels =
        (_registry.bySlot[ClientExtensionSlot.globalPanel] ?? const [])
            .where((extension) => !extension.adminOnly || app.isAdmin)
            .toList(growable: false);
    final primaryByCapability = <String, ClientExtensionDescriptor>{};
    for (final extension in [...floating, ...panels]) {
      primaryByCapability.putIfAbsent(
        '${extension.pluginId}:${extension.capability.id}',
        () => extension,
      );
    }
    final primary = primaryByCapability.values.toList(growable: false)
      ..sort((left, right) {
        final priority = left.priority.compareTo(right.priority);
        return priority != 0 ? priority : left.id.compareTo(right.id);
      });

    if (primary.isEmpty && _activeExtension == null) {
      return const SizedBox.shrink();
    }

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
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
          if (_activeExtension case final extension?)
            Positioned.fill(
              child: _PluginExtensionPanel(
                extension: extension,
                compact: false,
                running: _running,
                message: _actionMessage,
                failed: _actionFailed,
                onClose: () => setState(() => _activeExtension = null),
                onInvoke: _invokeActiveAction,
                extensionContext: const <String, Object?>{},
              ),
            ),
        ],
      ),
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
    this.menuLabel,
    this.showMenuLabel = true,
    this.menuFontSize = 14,
    this.menuHorizontalPadding = 12,
    this.menuIconTextGap = 8,
    this.buttonWidth,
    this.buttonHeight = 48,
    this.showLoadingPlaceholder = false,
  });

  final ClientExtensionSlot slot;
  final Map<String, Object?> extensionContext;
  final int? limit;
  final double spacing;
  final double buttonSize;
  final double iconSize;
  final EdgeInsetsGeometry? padding;
  final String? menuLabel;
  final bool showMenuLabel;
  final double menuFontSize;
  final double menuHorizontalPadding;
  final double menuIconTextGap;
  final double? buttonWidth;
  final double buttonHeight;
  final bool showLoadingPlaceholder;

  @override
  State<PluginExtensionSlot> createState() => _PluginExtensionSlotState();
}

class _PluginExtensionSlotState extends State<PluginExtensionSlot>
    with _PluginExtensionRegistryLoader<PluginExtensionSlot> {
  ClientExtensionDescriptor? _activeExtension;
  OverlayEntry? _overlayEntry;
  bool _running = false;
  String? _actionMessage;
  bool _actionFailed = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
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
        uiCapabilityId: extension.capability.id,
        uiGrant: extension.clientGrant,
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
      _actionMessage = ApiError.messageFor(error);
    } finally {
      if (mounted) {
        _running = false;
        _refreshOverlay();
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry == null) {
      final overlay = OverlayEntry(
        builder: (overlayContext) {
          final extension = _activeExtension;
          if (extension == null) return const SizedBox.shrink();
          return _PluginExtensionPanel(
            extension: extension,
            compact: true,
            running: _running,
            message: _actionMessage,
            failed: _actionFailed,
            onClose: _closeOverlay,
            onInvoke: _invokeActiveAction,
            extensionContext: widget.extensionContext,
          );
        },
      );
      _overlayEntry = overlay;
      Overlay.of(context, rootOverlay: true).insert(overlay);
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
    final limitValue = widget.limit;
    final app = AppScope.appOf(context);
    final extensions = (_registry.bySlot[widget.slot] ?? const [])
        .where((extension) => !extension.adminOnly || app.isAdmin)
        .toList(growable: false);
    final visible = limitValue == null
        ? extensions
        : extensions
            .take(limitValue.clamp(0, extensions.length).toInt())
            .toList();

    if (visible.isEmpty) {
      final menuLabel = widget.menuLabel;
      if (_loading && widget.showLoadingPlaceholder && menuLabel != null) {
        return _PluginExtensionMenuButton(
          label: menuLabel,
          extensions: const [],
          width: widget.buttonWidth,
          height: widget.buttonHeight,
          iconSize: widget.iconSize,
          showLabel: widget.showMenuLabel,
          fontSize: widget.menuFontSize,
          horizontalPadding: widget.menuHorizontalPadding,
          iconTextGap: widget.menuIconTextGap,
          onOpen: (_) {},
          enabled: false,
        );
      }
      return const SizedBox.shrink();
    }

    final menuLabel = widget.menuLabel;
    if (menuLabel != null && menuLabel.trim().isNotEmpty) {
      final menuButton = _PluginExtensionMenuButton(
        label: menuLabel,
        extensions: visible,
        width: widget.buttonWidth,
        height: widget.buttonHeight,
        iconSize: widget.iconSize,
        showLabel: widget.showMenuLabel,
        fontSize: widget.menuFontSize,
        horizontalPadding: widget.menuHorizontalPadding,
        iconTextGap: widget.menuIconTextGap,
        onOpen: _openExtension,
      );
      final padding = widget.padding;
      return padding == null
          ? menuButton
          : Padding(padding: padding, child: menuButton);
    }

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
