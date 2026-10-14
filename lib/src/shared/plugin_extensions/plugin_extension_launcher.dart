part of 'plugin_extension_host.dart';

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
