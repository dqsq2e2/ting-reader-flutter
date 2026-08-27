import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/test_icons.dart' as lucide_catalog;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_plugin.dart';

import '../../core/document_reader/document_reader.dart';
import '../../core/auth/fnos_gateway_auth.dart';
import '../../core/models/_helpers.dart' show asMap;
import '../../core/plugin_extensions/registry.dart';
import '../../core/plugin_extensions/types.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/external_links.dart';
import '../../core/utils/locale.dart';
import '../app_scope.dart';

const _missingPluginUiEntryError = '__missing_plugin_ui_entry__';

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
  void didUpdateWidget(covariant PluginExtensionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _activeExtension = null;
      _menuOpen = false;
      _actionMessage = null;
      _actionFailed = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.appOf(context);
    final revision = app.pluginExtensionRevision;
    final cached = app.pluginCapabilities.cachedClientExtensions;
    if (cached != null) {
      _registry = buildClientExtensionRegistry(cached);
    }
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
      final registrations = await api.listClientExtensions();
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
        _actionMessage = error.toString();
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
          if (_activeExtension != null)
            Positioned.fill(
              child: _PluginExtensionPanel(
                extension: _activeExtension!,
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
    final cached = app.pluginCapabilities.cachedClientExtensions;
    if (cached != null) {
      _registry = buildClientExtensionRegistry(cached);
    }
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
      final registrations = await api.listClientExtensions();
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
    final app = AppScope.appOf(context);
    final extensions = (_registry.bySlot[widget.slot] ?? const [])
        .where((extension) => !extension.adminOnly || app.isAdmin)
        .toList(growable: false);
    final visible = widget.limit == null
        ? extensions
        : extensions
            .take(widget.limit!.clamp(0, extensions.length).toInt())
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

class _PluginExtensionMenuButton extends StatefulWidget {
  const _PluginExtensionMenuButton({
    required this.label,
    required this.extensions,
    required this.onOpen,
    required this.height,
    required this.iconSize,
    required this.showLabel,
    required this.fontSize,
    required this.horizontalPadding,
    required this.iconTextGap,
    this.width,
    this.enabled = true,
  });

  final String label;
  final List<ClientExtensionDescriptor> extensions;
  final ValueChanged<ClientExtensionDescriptor> onOpen;
  final double? width;
  final double height;
  final double iconSize;
  final bool showLabel;
  final double fontSize;
  final double horizontalPadding;
  final double iconTextGap;
  final bool enabled;

  @override
  State<_PluginExtensionMenuButton> createState() =>
      _PluginExtensionMenuButtonState();
}

class _PluginExtensionMenuButtonState
    extends State<_PluginExtensionMenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? AppColors.primary600 : context.mutedText;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: IgnorePointer(
          ignoring: !widget.enabled,
          child: PopupMenuButton<ClientExtensionDescriptor>(
            tooltip: widget.label,
            onSelected: widget.onOpen,
            offset: const Offset(0, 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              for (final extension in widget.extensions)
                PopupMenuItem<ClientExtensionDescriptor>(
                  value: extension,
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? AppColors.slate800
                              : AppColors.slate100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _PluginExtensionIcon(
                          extension: extension,
                          size: widget.iconSize,
                          color: context.mutedText,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          extension.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.faintBorder),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.horizontalPadding,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.more_horiz_rounded,
                      size: widget.iconSize,
                      color: color,
                    ),
                    if (widget.showLabel) ...[
                      SizedBox(width: widget.iconTextGap),
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconForSlot(ClientExtensionSlot slot) {
  return switch (slot) {
    ClientExtensionSlot.globalFloatingAction => Icons.chat_bubble_rounded,
    ClientExtensionSlot.appSidebarPage => Icons.dashboard_customize_rounded,
    ClientExtensionSlot.bookDetailAction => Icons.menu_book_rounded,
    ClientExtensionSlot.globalPanel => Icons.extension_rounded,
    _ => Icons.extension_rounded,
  };
}

final Map<String, IconData> _lucideIconIndex = _buildLucideIconIndex();

Map<String, IconData> _buildLucideIconIndex() {
  const icons = lucide_catalog.icons;
  const names = lucide_catalog.iconNames;
  final count = names.length < icons.length ? names.length : icons.length;
  final result = <String, IconData>{};

  for (var index = 0; index < count; index++) {
    final raw = names[index].trim();
    if (raw.isEmpty || RegExp(r'\d{3}$').hasMatch(raw)) continue;
    final icon = icons[index];
    for (final key in _iconNameKeys(raw)) {
      result.putIfAbsent(key, () => icon);
    }
  }

  return Map.unmodifiable(result);
}

Iterable<String> _iconNameKeys(String value) {
  final trimmed = value.trim();
  final withoutPrefix =
      trimmed.replaceFirst(RegExp(r'^lucide:', caseSensitive: false), '');
  final camel = _toCamelIconName(withoutPrefix);
  final kebab = _toKebabIconName(camel);
  return {
    withoutPrefix,
    withoutPrefix.toLowerCase(),
    camel,
    camel.toLowerCase(),
    kebab,
    kebab.toLowerCase(),
  }.where((key) => key.isNotEmpty);
}

String _toCamelIconName(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '');
  final parts = cleaned
      .split(RegExp(r'[-_\s]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  final first = parts.first[0].toLowerCase() + parts.first.substring(1);
  return [
    first,
    for (final part in parts.skip(1)) part[0].toUpperCase() + part.substring(1),
  ].join();
}

String _toKebabIconName(String value) {
  return value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}-${match.group(2)}',
      )
      .replaceAll('_', '-')
      .replaceAll(' ', '-')
      .toLowerCase();
}

IconData? _iconForName(String value) {
  final normalized = _toKebabIconName(
    value.trim().replaceFirst(RegExp(r'^lucide:', caseSensitive: false), ''),
  );
  final lucideIcon = _lucideIconIndex[normalized] ??
      _lucideIconIndex[_toCamelIconName(normalized)] ??
      _lucideIconIndex[value.trim()];
  if (lucideIcon != null) return lucideIcon;

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

bool _isPluginImageIcon(String value) {
  if (!value.startsWith('assets/')) return false;
  final segments = value.split('/');
  return segments.every(
    (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
  );
}

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

    if (value != null && _isPluginImageIcon(value)) {
      final app = AppScope.appOf(context);
      final clientGrant = extension.clientGrant;
      if (clientGrant == null || clientGrant.isEmpty) {
        return Icon(_iconForSlot(extension.slot), size: size, color: color);
      }
      final imageUrl = app.pluginCapabilities.pluginAssetUrl(
        pluginId: extension.pluginId,
        clientGrant: clientGrant,
        entry: value,
      );
      final image = Image.network(
        imageUrl,
        headers: app.api.authHeaders,
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

class PluginExtensionIcon extends StatelessWidget {
  const PluginExtensionIcon({
    super.key,
    required this.extension,
    required this.size,
    this.color,
  });

  final ClientExtensionDescriptor extension;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _PluginExtensionIcon(
      extension: extension,
      size: size,
      color: color,
    );
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
            color: context.isDark
                ? AppColors.slate900.withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.96),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.faintBorder),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onToggle,
              child: const SizedBox(
                width: 48,
                height: 48,
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
      Color(0xff38c7df),
      Color(0xff2fb8d7),
      Color(0xff1fa9cf),
      Color(0xff158fc2),
    ];

    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _PluginLauncherTile(color: colors[0]),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _PluginLauncherTile(color: colors[1]),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: _PluginLauncherTile(color: colors[2]),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _PluginLauncherTile(color: colors[3]),
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
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.2),
      ),
    );
  }
}

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
  bool _pageLoaded = false;
  bool _pluginDocumentReady = false;
  String? _appliedThemeSignature;
  int _loadGeneration = 0;
  Timer? _documentReadyTimer;
  bool _initialized = false;
  String _bridgeNonce = _newPluginBridgeNonce();
  String _bridgeToken = _newPluginBridgeNonce();
  final List<DateTime> _bridgeRequestTimes = [];

  @override
  void didUpdateWidget(covariant _PluginWebContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extension.id != widget.extension.id ||
        oldWidget.extension.clientGrant != widget.extension.clientGrant ||
        jsonEncode(oldWidget.extension.render) !=
            jsonEncode(widget.extension.render) ||
        jsonEncode(oldWidget.extensionContext) !=
            jsonEncode(widget.extensionContext)) {
      _initialize();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initialize();
      return;
    }
    _syncPluginTheme();
  }

  @override
  void dispose() {
    _documentReadyTimer?.cancel();
    super.dispose();
  }

  void _initialize() {
    final generation = ++_loadGeneration;
    _documentReadyTimer?.cancel();
    final bridgeNonce = _newPluginBridgeNonce();
    final bridgeToken = _newPluginBridgeNonce();
    _bridgeNonce = bridgeNonce;
    _bridgeToken = bridgeToken;
    _bridgeRequestTimes.clear();
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
    final clientGrant = widget.extension.clientGrant;
    if (clientGrant == null || clientGrant.isEmpty) {
      setState(() {
        _controller = null;
        _error = 'Plugin UI authorization is unavailable.';
        _unsupported = false;
      });
      return;
    }
    final assetUrl = app.pluginCapabilities.pluginAssetUrl(
      pluginId: widget.extension.pluginId,
      clientGrant: clientGrant,
      entry: entry,
    );
    final loadAssetAsTopLevel = _pluginWebViewLoadsAssetAsTopLevel();
    final pluginTheme = _pluginThemePayload(context);
    final themeVariables = pluginTheme['cssVariables'];
    debugPrint(
      '[plugin-webview] theme scheme=${pluginTheme['colorScheme']} '
      'bg=${themeVariables is Map ? themeVariables['--bg'] : ''}',
    );
    final initPayload = _pluginInitPayloadJson(
      extension: widget.extension,
      extensionContext: widget.extensionContext,
      theme: pluginTheme,
      bridgeToken: bridgeToken,
    );
    _appliedThemeSignature = null;
    _pageLoaded = false;
    _pluginDocumentReady = false;

    final WebViewController controller;
    late final Future<void> controllerSetup;
    try {
      late final WebViewController nextController;
      nextController = defaultTargetPlatform == TargetPlatform.windows
          ? WebViewController.fromPlatformCreationParams(
              const WindowsWebViewControllerCreationParams(
                // The native WebView is an HWND overlay. A dialog rebuild can
                // temporarily deactivate its Flutter subtree; suspending the
                // browser in that interval leaves a blank native surface.
                suspendDuringDeactive: false,
              ),
            )
          : WebViewController();
      controllerSetup = nextController
          .setJavaScriptMode(JavaScriptMode.unrestricted)
          .then<void>((_) => nextController.setBackgroundColor(
                Color(themeVariables is Map
                    ? _parsePluginCssColor(themeVariables['--bg'])
                    : 0xfff8fafc),
              ))
          .then<void>(
            (_) => nextController.setNavigationDelegate(
              NavigationDelegate(
                onNavigationRequest: (request) {
                  // Allow the plugin document and its authenticated assets,
                  // including css/js, before applying the external-navigation
                  // policy.
                  if (_isPluginAssetUrl(
                    request.url,
                    assetUrl: assetUrl,
                    pluginId: widget.extension.pluginId,
                    clientGrant: clientGrant,
                  )) {
                    return NavigationDecision.navigate;
                  }
                  if (loadAssetAsTopLevel) {
                    // Subresources such as the plugin CSS/JS are not top-level
                    // navigations. Let the WebView fetch them under the same
                    // authenticated origin instead of applying the main-frame
                    // external-link policy to every request.
                    if (!request.isMainFrame) {
                      return NavigationDecision.navigate;
                    }
                    if (_isPluginAssetUrl(
                      request.url,
                      assetUrl: assetUrl,
                      pluginId: widget.extension.pluginId,
                      clientGrant: clientGrant,
                    )) {
                      return NavigationDecision.navigate;
                    }
                    _openPluginExternalUrl(request.url);
                    return NavigationDecision.prevent;
                  }
                  if (request.isMainFrame) {
                    if (_openPluginExternalUrl(request.url)) {
                      return NavigationDecision.prevent;
                    }
                    return NavigationDecision.navigate;
                  }
                  if (request.url == assetUrl ||
                      request.url.startsWith('$assetUrl#') ||
                      request.url.startsWith('$assetUrl?')) {
                    return NavigationDecision.navigate;
                  }
                  debugPrint(
                    '[plugin-webview] blocked untrusted subframe navigation',
                  );
                  return NavigationDecision.prevent;
                },
                onPageFinished: (url) {
                  if (loadAssetAsTopLevel &&
                      url.isNotEmpty &&
                      !_isPluginAssetUrl(
                        url,
                        assetUrl: assetUrl,
                        pluginId: widget.extension.pluginId,
                        clientGrant: clientGrant,
                      )) {
                    final parsedUrl = Uri.tryParse(url);
                    final safeUrl = parsedUrl == null
                        ? url
                        : parsedUrl.replace(query: '', fragment: '').toString();
                    debugPrint(
                      '[plugin-webview] rejected final document outside plugin asset: $safeUrl',
                    );
                    if (mounted) {
                      setState(() {
                        _error =
                            'Plugin UI redirected outside the authenticated asset';
                      });
                    }
                    return;
                  }
                  if (loadAssetAsTopLevel) {
                    unawaited(() async {
                      await _installTopLevelPluginBridge(
                        nextController,
                        initPayload: initPayload,
                        theme: pluginTheme,
                        assetUrl: assetUrl,
                        bridgeNonce: bridgeNonce,
                        bridgeToken: bridgeToken,
                      );
                      _appliedThemeSignature =
                          _pluginThemeSignature(pluginTheme);
                      await _probePluginDocument(
                        nextController,
                        url,
                      );
                    }());
                  } else {
                    unawaited(_probePluginDocument(nextController, url));
                  }
                  if (mounted && generation == _loadGeneration) {
                    setState(() => _pageLoaded = true);
                  }
                },
                onHttpError: (error) {
                  if (!mounted) return;
                  final statusCode = error.response?.statusCode;
                  setState(() {
                    _error = statusCode == null
                        ? 'Plugin UI request failed'
                        : 'Plugin UI request failed: HTTP $statusCode';
                  });
                },
                onWebResourceError: (error) {
                  if (!mounted || error.isForMainFrame != true) return;
                  setState(() => _error = error.description);
                },
              ),
            ),
          )
          .then<void>(
            (_) => nextController.addJavaScriptChannel(
              'TingPluginBridge',
              onMessageReceived: _handleBridgeMessage,
            ),
          )
          .then<void>(
            (_) => nextController.addJavaScriptChannel(
              'TingPluginLifecycle',
              onMessageReceived: (message) {
                if (message.message != bridgeToken ||
                    generation != _loadGeneration ||
                    !mounted) {
                  return;
                }
                _documentReadyTimer?.cancel();
                setState(() {
                  _pageLoaded = true;
                  _pluginDocumentReady = true;
                  _error = null;
                });
              },
            ),
          );
      controller = nextController;
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
      _pageLoaded = false;
      _pluginDocumentReady = false;
    });

    unawaited(
      _loadPluginWebView(
        controller: controller,
        assetUrl: assetUrl,
        app: app,
        loadAssetAsTopLevel: loadAssetAsTopLevel,
        initPayload: initPayload,
        theme: pluginTheme,
        bridgeNonce: bridgeNonce,
        bridgeToken: bridgeToken,
        generation: generation,
        setupFuture: controllerSetup,
      ),
    );
  }

  Future<void> _loadPluginWebView({
    required WebViewController controller,
    required String assetUrl,
    required AppState app,
    required bool loadAssetAsTopLevel,
    required String initPayload,
    required Map<String, Object?> theme,
    required String bridgeNonce,
    required String bridgeToken,
    required int generation,
    required Future<void> setupFuture,
  }) async {
    try {
      // WebView2 registers navigation callbacks and document-created scripts
      // asynchronously. Do not navigate until all three setup operations have
      // completed, otherwise the plugin can run before TingPluginBridge exists.
      await setupFuture;

      final assetUri = Uri.parse(assetUrl);
      await _writePluginCookiesToWebView(
        controller: controller,
        assetUri: assetUri,
        cookieHeader: app.api.cookie,
      );
      await _configurePluginSubresourceHeaders(
        controller: controller,
        assetUri: assetUri,
        headers: app.api.authHeaders,
      );

      if (loadAssetAsTopLevel) {
        await controller.loadRequest(
          assetUri,
          headers: app.api.authHeaders,
        );
      } else {
        final response = await app.api.getTextUri(assetUri);
        final responseData = response.data;
        final html = responseData is List<int>
            ? utf8.decode(responseData, allowMalformed: false)
            : responseData?.toString() ?? '';
        final safeUrl = assetUri.replace(query: '', fragment: '').toString();
        debugPrint(
          '[plugin-webview] fetched plugin html url=$safeUrl '
          'status=${response.statusCode} length=${html.length}',
        );
        if (_looksLikeTingReaderShell(html)) {
          throw StateError(
            'Plugin asset request returned the Ting Reader app shell',
          );
        }
        await controller.loadHtmlString(
          _pluginHtmlForSandbox(
            html: html,
            assetUrl: assetUrl,
            initPayload: initPayload,
            theme: theme,
            bridgeNonce: bridgeNonce,
            bridgeToken: bridgeToken,
          ),
          baseUrl: app.api.baseUrl,
        );
        _documentReadyTimer = Timer(const Duration(seconds: 8), () {
          if (!mounted ||
              generation != _loadGeneration ||
              _pluginDocumentReady) {
            return;
          }
          setState(() {
            _error = context.localeText(
              '插件页面未能完成渲染，请重试。',
              'The plugin page did not finish rendering. Please try again.',
            );
          });
        });
      }
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _configurePluginSubresourceHeaders({
    required WebViewController controller,
    required Uri assetUri,
    required Map<String, String> headers,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    final platform = controller.platform;
    if (platform is! WindowsPlatformWebViewController) return;
    final configured = await platform.setRequestHeaders(
      assetUri,
      headers: headers,
    );
    if (!configured) {
      throw StateError(
        'Windows WebView2 failed to configure plugin resource headers',
      );
    }
  }

  Future<void> _writePluginCookiesToWebView({
    required WebViewController controller,
    required Uri assetUri,
    required String? cookieHeader,
  }) async {
    final rawCookie = cookieHeader?.trim() ?? '';
    if (rawCookie.isEmpty || assetUri.host.isEmpty) return;

    final windowsController = defaultTargetPlatform == TargetPlatform.windows &&
            controller.platform is WindowsPlatformWebViewController
        ? controller.platform as WindowsPlatformWebViewController
        : null;
    final cookieManager =
        windowsController == null ? WebViewCookieManager() : null;
    for (final pair in rawCookie.split(';')) {
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;

      final name = pair.substring(0, separator).trim();
      final value = pair.substring(separator + 1).trim();
      if (name.isEmpty) continue;

      final cookie = WebViewCookie(
        name: name,
        value: value,
        // fnOS may redirect through fnos.net while validating the relay
        // session. Use the parent domain so both the FNID host and fnos.net
        // receive the same gateway cookies, as they do in a browser.
        domain: FnosGateway.cookieDomainForHost(assetUri.host),
        path: '/',
      );
      if (windowsController != null) {
        final written = await windowsController.setCookie(cookie);
        if (!written) {
          throw StateError('Windows WebView2 failed to write plugin cookie');
        }
      } else {
        await cookieManager!.setCookie(cookie);
      }
    }
  }

  void _syncPluginTheme() {
    final controller = _controller;
    if (controller == null || !_pageLoaded || _unsupported || _error != null) {
      return;
    }
    final pluginTheme = _pluginThemePayload(context);
    final signature = _pluginThemeSignature(pluginTheme);
    if (signature == _appliedThemeSignature) return;
    _appliedThemeSignature = signature;
    controller.runJavaScript(_pluginThemeApplicationScript(pluginTheme));
  }

  bool _acceptBridgeMessage(String raw) {
    if (raw.length > 256 * 1024) return false;
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 10));
    _bridgeRequestTimes.removeWhere((timestamp) => timestamp.isBefore(cutoff));
    if (_bridgeRequestTimes.length >= 100) return false;
    _bridgeRequestTimes.add(now);
    return true;
  }

  Future<void> _handleBridgeMessage(JavaScriptMessage message) async {
    if (!_acceptBridgeMessage(message.message)) {
      debugPrint(
          '[plugin-webview] rejected oversized or rate-limited bridge message');
      return;
    }

    final externalUrl = _decodeExternalUrlRequest(
      message.message,
      expectedNonce: _bridgeNonce,
      expectedBridgeToken: _bridgeToken,
    );
    if (externalUrl != null) {
      _openPluginExternalUrl(externalUrl);
      return;
    }

    final request = _decodeBridgeRequest(
      message.message,
      expectedNonce: _bridgeNonce,
      expectedBridgeToken: _bridgeToken,
    );
    if (request == null) return;

    debugPrint(
      '[plugin-webview] bridge request method=${request.method}',
    );

    try {
      final result = await _invokeBridgeRequest(request);
      await _postBridgeResponse(request, ok: true, result: result);
      debugPrint(
        '[plugin-webview] bridge response method=${request.method} ok=1',
      );
    } catch (error) {
      await _postBridgeResponse(
        request,
        ok: false,
        error: error.toString(),
      );
      debugPrint(
        '[plugin-webview] bridge response method=${request.method} ok=0',
      );
    }
  }

  Future<void> _probePluginDocument(
    WebViewController controller,
    String url,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    final parsed = Uri.tryParse(url);
    final safeUrl = parsed == null
        ? url
        : parsed.replace(query: '', fragment: '').toString();
    try {
      final result = await controller.runJavaScriptReturningResult('''
JSON.stringify({
  readyState: document.readyState,
  title: document.title,
  href: location.href,
  bodyLength: document.body ? document.body.innerHTML.length : -1,
  scriptCount: document.scripts.length,
  styleCount: document.styleSheets.length,
  appText: document.body ? document.body.innerText.slice(0, 80) : ""
})
''');
      debugPrint('[plugin-webview] DOM probe url=$safeUrl result=$result');
    } catch (error) {
      debugPrint('[plugin-webview] DOM probe failed url=$safeUrl');
    }
  }

  Future<Object?> _invokeBridgeRequest(_PluginBridgeRequest request) {
    final pluginCapabilities = AppScope.appOf(context).pluginCapabilities;
    switch (request.method) {
      case 'capability.invoke':
        if (!widget.extension.allowsCapabilityInvoke) {
          throw StateError('Capability invocation is disabled for this view');
        }
        final params = request.params is Map
            ? Map<String, dynamic>.from(request.params as Map)
            : const <String, dynamic>{};
        final declaredCapabilityId = params['capabilityId']?.toString().trim();
        final capabilityId =
            declaredCapabilityId == null || declaredCapabilityId.isEmpty
                ? widget.extension.capability.id
                : declaredCapabilityId;
        if (!widget.extension.allowedCapabilityIds.contains(capabilityId)) {
          throw StateError('Capability is not allowed for this view');
        }
        return pluginCapabilities.invokePluginCapability<Object?>(
          pluginId: widget.extension.pluginId,
          capabilityId: capabilityId,
          uiCapabilityId: widget.extension.capability.id,
          uiGrant: widget.extension.clientGrant,
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
        if (!widget.extension.allowedHostMethods.contains(method)) {
          throw StateError('Host method is not allowed for this view');
        }
        return pluginCapabilities.invokePluginHost<Object?>(
          pluginId: widget.extension.pluginId,
          uiCapabilityId: widget.extension.capability.id,
          uiGrant: widget.extension.clientGrant ?? '',
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
      'bridge_token': request.bridgeToken,
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

    if (!_pageLoaded || !_pluginDocumentReady) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: WebViewWidget(controller: controller),
    );
  }
}

bool _pluginWebViewLoadsAssetAsTopLevel() {
  // Fetch through the authenticated API, then load the hardened HTML string as
  // the WebView document. Navigating to the asset URL can return the fnOS SPA
  // shell instead of the plugin asset.
  return false;
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

bool _openPluginExternalUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  final scheme = uri?.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  openExternalUrl(rawUrl);
  return true;
}

class _PluginBridgeRequest {
  const _PluginBridgeRequest({
    required this.id,
    required this.method,
    required this.bridgeToken,
    this.params,
  });

  final String id;
  final String method;
  final String bridgeToken;
  final Object? params;
}

String _newPluginBridgeNonce() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64UrlEncode(bytes);
}

_PluginBridgeRequest? _decodeBridgeRequest(
  String raw, {
  required String expectedNonce,
  required String expectedBridgeToken,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  if (decoded['type'] != 'ting-plugin:request') return null;
  if (decoded['bridge_nonce'] != expectedNonce) return null;
  if (decoded['bridge_token'] != expectedBridgeToken) return null;
  final id = decoded['id']?.toString();
  final method = decoded['method']?.toString();
  if (id == null ||
      id.isEmpty ||
      id.length > 128 ||
      method == null ||
      method.isEmpty ||
      method.length > 64) {
    return null;
  }
  return _PluginBridgeRequest(
    id: id,
    method: method,
    bridgeToken: expectedBridgeToken,
    params: decoded['params'],
  );
}

String? _decodeExternalUrlRequest(
  String raw, {
  required String expectedNonce,
  required String expectedBridgeToken,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  if (decoded['type'] != 'ting-plugin:external-url') return null;
  if (decoded['bridge_nonce'] != expectedNonce) return null;
  if (decoded['bridge_token'] != expectedBridgeToken) return null;
  final url = decoded['url']?.toString().trim();
  return url == null || url.isEmpty ? null : url;
}

Future<void> _installTopLevelPluginBridge(
  WebViewController controller, {
  required String initPayload,
  required Map<String, Object?> theme,
  required String assetUrl,
  required String bridgeNonce,
  required String bridgeToken,
}) async {
  final themeScript = _pluginThemeApplicationScript(theme);
  final assetUrlPayload = jsonEncode(assetUrl);
  final noncePayload = jsonEncode(bridgeNonce);
  final tokenPayload = jsonEncode(bridgeToken);
  final secureBridgeScript = buildPluginTopLevelSecureBridgeScript(
    noncePayload: noncePayload,
    tokenPayload: tokenPayload,
  );
  final safeInitPayload = initPayload.replaceAll('<', r'\u003C');
  await controller.runJavaScript('''
(function() {
  $themeScript
  if (window.__tingPluginBridgeInstalled) {
    window.postMessage($safeInitPayload, "*");
    return;
  }
  window.__tingPluginBridgeInstalled = true;
  $secureBridgeScript
  window.__tingPluginRespond = function(response) {
    if (!response || response.bridge_token !== bridgeToken) return;
    window.postMessage(response, "*");
  };
  const pluginAssetUrl = $assetUrlPayload;
  function absolutePluginUrl(url) {
    try {
      return new URL(url, document.baseURI || window.location.href).href;
    } catch (_) {
      return "";
    }
  }
  function shouldOpenExternally(url) {
    const absoluteUrl = absolutePluginUrl(url);
    if (!absoluteUrl) return false;
    try {
      const parsed = new URL(absoluteUrl);
      if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return false;
      return absoluteUrl !== pluginAssetUrl &&
        !absoluteUrl.startsWith(pluginAssetUrl + "#") &&
        !absoluteUrl.startsWith(pluginAssetUrl + "?");
    } catch (_) {
      return false;
    }
  }
  function openExternal(url) {
    const absoluteUrl = absolutePluginUrl(url);
    if (!absoluteUrl) return false;
    TingPluginBridge.postMessage(JSON.stringify({
      type: "ting-plugin:external-url",
      url: absoluteUrl,
      bridge_nonce: bridgeNonce,
      bridge_token: bridgeToken
    }));
    return true;
  }
  const originalWindowOpen = window.open;
  window.open = function(url, target, features) {
    if (url && shouldOpenExternally(url)) {
      const activation = navigator.userActivation;
      if (!activation || activation.isActive) openExternal(url);
      return null;
    }
    return originalWindowOpen
      ? originalWindowOpen.call(window, url, target, features)
      : null;
  };
  document.addEventListener("click", function(event) {
    if (!event.isTrusted) return;
    const target = event.target;
    const anchor = target && target.closest ? target.closest("a[href]") : null;
    if (!anchor || !shouldOpenExternally(anchor.href)) return;
    event.preventDefault();
    event.stopPropagation();
    openExternal(anchor.href);
  }, true);
  window.addEventListener("message", function(event) {
    if (event.source !== window) return;
    const data = event.data;
    if (!data || data.type !== "ting-plugin:request" || !data.id) return;
    postBridgeMessage(data);
  });
  window.postMessage($safeInitPayload, "*");
})();
''');
}

@visibleForTesting
String buildPluginTopLevelSecureBridgeScript({
  required String noncePayload,
  required String tokenPayload,
}) {
  return '''
  const bridgeToken = $tokenPayload;
  const bridgeNonce = $noncePayload;
  function postBridgeMessage(message) {
    TingPluginBridge.postMessage(JSON.stringify(Object.assign({}, message, {
      bridge_nonce: bridgeNonce,
      bridge_token: bridgeToken
    })));
  }
  const secureBridge = Object.freeze({
    postMessage: function(message) {
      if (!message || typeof message !== "object" ||
          message.type !== "ting-plugin:request") return;
      postBridgeMessage(message);
    }
  });
  Object.defineProperty(window, "__TING_PLUGIN_BRIDGE__", {
    value: secureBridge,
    configurable: false,
    enumerable: false,
    writable: false
  });
''';
}

bool _isPluginAssetUrl(
  String url, {
  required String assetUrl,
  required String pluginId,
  required String clientGrant,
}) {
  final uri = Uri.tryParse(url);
  final assetUri = Uri.tryParse(assetUrl);
  if (uri == null || assetUri == null) return false;
  if (uri.scheme != assetUri.scheme ||
      uri.host != assetUri.host ||
      uri.port != assetUri.port) {
    return false;
  }

  // The gateway adds a path prefix such as /app/ting-reader before the API
  // path. Anchor the check to the actual asset URL instead of assuming that
  // /api/v1 is at the origin root.
  final assetSegments = assetUri.pathSegments;
  final requestSegments = uri.pathSegments;
  final pluginAssetsIndex = assetSegments.indexOf('plugin-assets');
  if (pluginAssetsIndex < 0 ||
      pluginAssetsIndex + 2 >= assetSegments.length ||
      requestSegments.length <= pluginAssetsIndex + 2) {
    return false;
  }
  for (var index = 0; index <= pluginAssetsIndex; index++) {
    if (requestSegments[index] != assetSegments[index]) return false;
  }

  final grantSegment = requestSegments[pluginAssetsIndex + 1];
  final pluginSegment = requestSegments[pluginAssetsIndex + 2];
  return grantSegment == clientGrant &&
      (pluginSegment == pluginId ||
          pluginSegment == Uri.encodeComponent(pluginId));
}

@visibleForTesting
bool isPluginAssetUrlForTesting(
  String url, {
  required String assetUrl,
  required String pluginId,
  required String clientGrant,
}) {
  return _isPluginAssetUrl(
    url,
    assetUrl: assetUrl,
    pluginId: pluginId,
    clientGrant: clientGrant,
  );
}

int _parsePluginCssColor(Object? value) {
  final raw = value?.toString().trim() ?? '';
  final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(raw);
  if (match == null) return 0xfff8fafc;
  return 0xff000000 | int.parse(match.group(1)!, radix: 16);
}

String _pluginInitPayloadJson({
  required ClientExtensionDescriptor extension,
  required Map<String, Object?> extensionContext,
  required Map<String, Object?> theme,
  required String bridgeToken,
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
    'bridgeToken': bridgeToken,
  });
}

Map<String, Object?> _pluginThemePayload(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.brightness == Brightness.dark ? 'dark' : 'light';
  final cssVariables = colorScheme == 'dark'
      ? const {
          '--bg': '#020617',
          '--panel': '#0f172a',
          '--text': '#f8fafc',
          '--muted': '#cbd5e1',
          '--line': '#1e293b',
          '--accent': '#7dd3fc',
          '--soft': '#082f49',
          '--danger': '#fca5a5',
        }
      : const {
          '--bg': '#f8fafc',
          '--panel': '#ffffff',
          '--text': '#0f172a',
          '--muted': '#475569',
          '--line': '#e2e8f0',
          '--accent': '#0284c7',
          '--soft': '#f0f9ff',
          '--danger': '#dc2626',
        };
  return {
    'colorScheme': colorScheme,
    'brightness': colorScheme,
    'cssVariables': cssVariables,
  };
}

String _pluginThemeSignature(Map<String, Object?> theme) => jsonEncode(theme);

String _pluginHtmlForSandbox({
  required String html,
  required String assetUrl,
  required String initPayload,
  required Map<String, Object?> theme,
  required String bridgeNonce,
  required String bridgeToken,
}) {
  final origin = Uri.parse(assetUrl).origin;
  final policy = [
    "default-src 'none'",
    "script-src 'unsafe-inline' $origin",
    "style-src 'unsafe-inline' $origin",
    "font-src data: $origin",
    'img-src data: blob: $origin',
    'media-src data: blob: $origin',
    "connect-src 'none'",
    "object-src 'none'",
    "frame-src 'none'",
    "worker-src 'none'",
    "form-action 'none'",
    'base-uri $origin',
  ].join('; ');
  final bootstrap = _pluginTopLevelBootstrapScript(
    initPayload: initPayload,
    theme: theme,
    assetUrl: assetUrl,
    bridgeNonce: bridgeNonce,
    bridgeToken: bridgeToken,
  );
  const attributeEscape = HtmlEscape(HtmlEscapeMode.attribute);
  final injectedHead = '''
<meta http-equiv="Content-Security-Policy" content="${attributeEscape.convert(policy)}">
<base href="${attributeEscape.convert(assetUrl)}">
<script>$bootstrap</script>
''';
  final document = html
      .replaceAll(RegExp(r'<base\b[^>]*>', caseSensitive: false), '')
      .replaceAll(
        RegExp(
          r'''<meta\b(?=[^>]*\bhttp-equiv\s*=\s*["']?\s*content-security-policy\b)[^>]*>''',
          caseSensitive: false,
        ),
        '',
      );
  final head =
      RegExp(r'<head\b[^>]*>', caseSensitive: false).firstMatch(document);
  if (head != null) {
    return document.replaceRange(head.end, head.end, injectedHead);
  }
  final htmlTag =
      RegExp(r'<html\b[^>]*>', caseSensitive: false).firstMatch(document);
  if (htmlTag != null) {
    return document.replaceRange(
      htmlTag.end,
      htmlTag.end,
      '<head>$injectedHead</head>',
    );
  }
  return '<!doctype html><html><head>$injectedHead</head><body>'
      '$document</body></html>';
}

String _pluginTopLevelBootstrapScript({
  required String initPayload,
  required Map<String, Object?> theme,
  required String assetUrl,
  required String bridgeNonce,
  required String bridgeToken,
}) {
  final assetPayload = jsonEncode(assetUrl).replaceAll('<', r'\u003C');
  final themePayload = jsonEncode(theme).replaceAll('<', r'\u003C');
  final noncePayload = jsonEncode(bridgeNonce);
  final tokenPayload = jsonEncode(bridgeToken);
  final safeInitPayload = initPayload.replaceAll('<', r'\u003C');
  final secureBridgeScript = buildPluginTopLevelSecureBridgeScript(
    noncePayload: noncePayload,
    tokenPayload: tokenPayload,
  );
  return '''
(function() {
  if (window.__tingPluginBridgeInstalled) return;
  Object.defineProperty(window, "__tingPluginBridgeInstalled", {
    value: true, configurable: false, enumerable: false, writable: false
  });
  const assetUrl = $assetPayload;
  const initialTheme = $themePayload;
  $secureBridgeScript
  const scheduleTask = window.setTimeout.bind(window);
  const bootstrapScript = document.currentScript;
  if (bootstrapScript) bootstrapScript.remove();
  let externalNavigationPermit = false;
  let permitGeneration = 0;

  function applyTheme(theme) {
    const rawScheme = String(theme && (theme.colorScheme || theme.brightness) || "light").toLowerCase();
    const colorScheme = rawScheme.indexOf("dark") >= 0 ? "dark" : "light";
    const root = document.documentElement;
    const vars = theme && theme.cssVariables || {};
    root.style.setProperty("color-scheme", colorScheme, "important");
    root.dataset.tingTheme = colorScheme;
    root.dataset.theme = colorScheme;
    root.classList.toggle("dark", colorScheme === "dark");
    root.classList.toggle("light", colorScheme === "light");
    Object.keys(vars).forEach(function(key) {
      root.style.setProperty(key, String(vars[key]), "important");
    });
    if (document.body) {
      if (vars["--bg"]) document.body.style.setProperty("background-color", String(vars["--bg"]), "important");
      if (vars["--text"]) document.body.style.setProperty("color", String(vars["--text"]), "important");
    }
    let style = document.getElementById("ting-plugin-host-style");
    if (!style) {
      style = document.createElement("style");
      style.id = "ting-plugin-host-style";
      (document.head || root).appendChild(style);
    }
    const thumb = colorScheme === "dark"
      ? "rgba(148, 163, 184, 0.48)"
      : "rgba(100, 116, 139, 0.34)";
    style.textContent =
      "html, body, .generate-panel, .saved-panel { scrollbar-width: thin; scrollbar-color: " + thumb + " transparent; }" +
      "html::-webkit-scrollbar, body::-webkit-scrollbar, .generate-panel::-webkit-scrollbar, .saved-panel::-webkit-scrollbar { width: 8px; height: 8px; }" +
      "html::-webkit-scrollbar-track, body::-webkit-scrollbar-track, .generate-panel::-webkit-scrollbar-track, .saved-panel::-webkit-scrollbar-track { background: transparent; }" +
      "html::-webkit-scrollbar-thumb, body::-webkit-scrollbar-thumb, .generate-panel::-webkit-scrollbar-thumb, .saved-panel::-webkit-scrollbar-thumb { background: " + thumb + "; border: 2px solid transparent; border-radius: 999px; background-clip: padding-box; }";
    window.__tingPluginTheme = theme;
  }
  Object.defineProperty(window, "__tingPluginApplyTheme", {
    value: applyTheme, configurable: false, enumerable: false, writable: false
  });
  Object.defineProperty(window, "__tingPluginRespond", {
    value: function(response) {
      if (!response || response.bridge_token !== bridgeToken) return;
      window.postMessage(response, "*");
    },
    configurable: false, enumerable: false, writable: false
  });

  function absolutePluginUrl(url) {
    try { return new URL(url, assetUrl).href; } catch (_) { return ""; }
  }

  function shouldOpenExternally(url) {
    const absoluteUrl = absolutePluginUrl(url);
    if (!absoluteUrl) return false;
    try {
      const parsed = new URL(absoluteUrl);
      if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return false;
      return absoluteUrl !== assetUrl &&
        !absoluteUrl.startsWith(assetUrl + "#") &&
        !absoluteUrl.startsWith(assetUrl + "?");
    } catch (_) {
      return false;
    }
  }

  function openExternal(url) {
    if (!externalNavigationPermit) return;
    externalNavigationPermit = false;
    const absoluteUrl = absolutePluginUrl(url);
    if (!absoluteUrl || !shouldOpenExternally(absoluteUrl)) return;
    postBridgeMessage({
      type: "ting-plugin:external-url",
      url: absoluteUrl
    });
  }

  const originalWindowOpen = window.open;
  window.open = function(url, target, features) {
    if (url && shouldOpenExternally(url)) {
      openExternal(url);
      return null;
    }
    return originalWindowOpen
      ? originalWindowOpen.call(window, url, target, features)
      : null;
  };
  window.addEventListener("click", function(event) {
    if (event.isTrusted) {
      const generation = ++permitGeneration;
      externalNavigationPermit = true;
      queueMicrotask(function() {
        if (permitGeneration === generation) externalNavigationPermit = false;
      });
    }
    const target = event.target;
    const anchor = target && target.closest ? target.closest("a[href]") : null;
    if (!anchor || !shouldOpenExternally(anchor.href)) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    openExternal(anchor.href);
  }, { capture: true });
  window.addEventListener("message", function(event) {
    if (event.source !== window) return;
    const data = event.data;
    if (!data || data.type !== "ting-plugin:request" || !data.id) return;
    postBridgeMessage(data);
  });
  function finishBootstrap() {
    applyTheme(initialTheme);
    window.postMessage($safeInitPayload, "*");
    TingPluginLifecycle.postMessage(bridgeToken);
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function() {
      scheduleTask(finishBootstrap, 0);
    }, { capture: true, once: true });
  } else {
    scheduleTask(finishBootstrap, 0);
  }
})();
''';
}

bool _looksLikeTingReaderShell(String html) {
  final hasAppTitle = RegExp(
    r'<title[^>]*>\s*Ting Reader\b',
    caseSensitive: false,
  ).hasMatch(html);
  final normalized = html.toLowerCase();
  final hasRoot =
      normalized.contains('id="root"') || normalized.contains("id='root'");
  return hasAppTitle && hasRoot;
}

String _pluginThemeApplicationScript(Map<String, Object?> theme) {
  final themePayload = jsonEncode(theme);
  return '''
(function() {
  const theme = $themePayload;
  const rawScheme = String(theme.colorScheme || theme.brightness || "light").toLowerCase();
  const colorScheme = rawScheme.indexOf("dark") >= 0 ? "dark" : "light";
  const root = document.documentElement;
  const vars = theme.cssVariables || {};
  root.style.setProperty("color-scheme", colorScheme, "important");
  root.dataset.tingTheme = colorScheme;
  root.dataset.theme = colorScheme;
  root.classList.toggle("dark", colorScheme === "dark");
  root.classList.toggle("light", colorScheme === "light");
  Object.keys(vars).forEach(function(key) {
    root.style.setProperty(key, String(vars[key]), "important");
  });
  let meta = document.querySelector('meta[name="color-scheme"]');
  if (!meta) {
    meta = document.createElement("meta");
    meta.setAttribute("name", "color-scheme");
    document.head && document.head.appendChild(meta);
  }
  meta.setAttribute("content", colorScheme);
  if (document.body) {
    if (vars["--bg"]) document.body.style.setProperty("background-color", String(vars["--bg"]), "important");
    if (vars["--text"]) document.body.style.setProperty("color", String(vars["--text"]), "important");
  }
  if (typeof window.__tingPluginApplyTheme === "function") {
    window.__tingPluginApplyTheme(theme);
  }
  window.__tingPluginTheme = theme;
  window.postMessage({ type: "ting-plugin:theme", theme: theme }, "*");
})();
''';
}

@visibleForTesting
String buildPluginTopLevelDocumentForTesting({
  required String html,
  required String assetUrl,
  required String initPayload,
  required Map<String, Object?> theme,
  required String bridgeNonce,
  required String bridgeToken,
}) {
  return _pluginHtmlForSandbox(
    html: html,
    assetUrl: assetUrl,
    initPayload: initPayload,
    theme: theme,
    bridgeNonce: bridgeNonce,
    bridgeToken: bridgeToken,
  );
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
