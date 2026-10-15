part of 'admin_pages.dart';

class _PluginCard extends StatelessWidget {
  const _PluginCard({
    required this.item,
    required this.installed,
    required this.hasUpdate,
    required this.installing,
    required this.expanded,
    required this.onToggleDescription,
    this.installedVersion,
    this.onInstall,
    this.onReload,
    this.onDelete,
    this.onConfigure,
    this.onViewLogs,
  });

  final PluginItem item;
  final bool installed;
  final String? installedVersion;
  final bool hasUpdate;
  final bool installing;
  final bool expanded;
  final VoidCallback onToggleDescription;
  final VoidCallback? onInstall;
  final VoidCallback? onReload;
  final VoidCallback? onDelete;
  final VoidCallback? onConfigure;
  final VoidCallback? onViewLogs;

  @override
  Widget build(BuildContext context) {
    final onDeleteValue = onDelete;
    final onReloadValue = onReload;
    final onConfigureValue = onConfigure;
    final onViewLogsValue = onViewLogs;
    final repoValue = item.repo;
    final licenseValue = item.license;
    final authorValue = item.author;
    final description = _localizedText(item.descriptionI18n, context) ??
        item.longDescription ??
        item.description ??
        context.l10n.pluginsNoDescription;
    final typeStyle = _pluginTypeStyle(item.pluginType, context);
    final supportLabels =
        item.supportedExtensions.map((value) => value.toUpperCase()).toList();
    final searchFieldCount =
        _metadataCapabilityListCount(item.capabilities, 'search_fields');
    final resultFieldCount =
        _metadataCapabilityListCount(item.capabilities, 'result_fields');
    final capabilityKinds = _pluginCapabilityKinds(item.capabilities);
    final runtimeLabel = _pluginRuntimeLabel(item.runtime);
    final permissionLabels = item.permissions.map((permission) {
      final label = context.l10n.pluginsPermissionLabel(permission.type);
      return permission.scope == null ? label : '$label (${permission.scope})';
    }).toList();

    return TingCard(
      radius: 8,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeStyle.background,
                  border: Border.all(color: typeStyle.border),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _pluginTypeIcon(item.pluginType),
                  color: typeStyle.foreground,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          _formatPluginVersion(item.version),
                          style:
                              TextStyle(color: context.mutedText, fontSize: 12),
                        ),
                        if (hasUpdate && installedVersion != null)
                          Text(
                            _formatPluginVersion(installedVersion),
                            style: const TextStyle(
                              color: AppColors.slate400,
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        if (authorValue != null)
                          Text(
                            authorValue,
                            style: TextStyle(
                                color: context.mutedText, fontSize: 12),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              installed && onInstall == null
                  ? _PluginStateBadge(state: item.state)
                  : _StorePluginBadge(
                      installed: installed,
                      hasUpdate: hasUpdate,
                    ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onToggleDescription,
            borderRadius: BorderRadius.circular(8),
            child: Text(
              description,
              maxLines: expanded ? null : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.isDark ? AppColors.slate300 : AppColors.slate600,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (capabilityKinds.isEmpty)
                _PluginInfoChip(
                  label: _pluginTypeLabel(context, item.pluginType),
                  icon: Icons.sell_rounded,
                  color: typeStyle.foreground,
                  background: typeStyle.background,
                  border: typeStyle.border,
                ),
              for (final kind in capabilityKinds)
                _PluginInfoChip(
                  label: context.l10n.pluginsCapabilityLabel(kind),
                  icon: kind == 'http_route'
                      ? Icons.language_rounded
                      : Icons.sell_rounded,
                  color: typeStyle.foreground,
                  background: typeStyle.background,
                  border: typeStyle.border,
                ),
              if (runtimeLabel != null)
                _PluginInfoChip(
                  label: runtimeLabel,
                  icon: Icons.memory_rounded,
                ),
              if (supportLabels.isNotEmpty)
                _PluginInfoChip(
                  label: supportLabels.length > 4
                      ? '${supportLabels.take(4).join(', ')} +${supportLabels.length - 4}'
                      : supportLabels.join(', '),
                  icon: Icons.description_rounded,
                  tooltip: supportLabels.join(', '),
                ),
              if (item.adminOnly)
                _PluginInfoChip(
                  label: context.l10n.pluginsAdminOnly,
                  icon: Icons.shield_outlined,
                ),
              if (item.permissions.isNotEmpty)
                _PluginInfoChip(
                  label: context.l10n
                      .pluginsPermissionCount(item.permissions.length),
                  icon: Icons.shield_outlined,
                  tooltip: permissionLabels.join('\n'),
                ),
              if (searchFieldCount > 0)
                _PluginInfoChip(
                  label: context.l10n.pluginsSearchFieldCount(searchFieldCount),
                  icon: Icons.search_rounded,
                ),
              if (resultFieldCount > 0)
                _PluginInfoChip(
                  label: context.l10n.pluginsResultFieldCount(resultFieldCount),
                  icon: Icons.fact_check_rounded,
                ),
              if (item.dependencies.isNotEmpty)
                _PluginInfoChip(
                  label: context.l10n
                      .pluginsDependencyCount(item.dependencies.length),
                  icon: Icons.inventory_2_rounded,
                  tooltip: item.dependencies.join('\n'),
                ),
              if (licenseValue != null) _PluginInfoChip(label: licenseValue),
              if (item.configSchema != null)
                _PluginInfoChip(
                  label: context.l10n.pluginsConfigurable,
                  icon: Icons.settings_rounded,
                ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 16),
          Divider(color: context.faintBorder),
          Row(
            children: [
              if (repoValue != null && repoValue.trim().isNotEmpty)
                _PluginFooterButton(
                  icon: const _GitHubIcon(size: 17),
                  label: context.l10n.pluginsRepository,
                  onPressed: () => openRepositoryUrl(repoValue),
                ),
              const Spacer(),
              if (onViewLogsValue != null)
                _PluginIconAction(
                  icon: Icons.description_outlined,
                  tooltip: context.localeText('插件日志', 'Plugin logs'),
                  onPressed: onViewLogsValue,
                ),
              if (onConfigureValue != null)
                _PluginIconAction(
                  icon: Icons.settings_rounded,
                  tooltip: context.l10n.pluginsConfigure,
                  onPressed: onConfigureValue,
                ),
              if (onReloadValue != null)
                _PluginIconAction(
                  icon: Icons.refresh_rounded,
                  tooltip: context.l10n.pluginsReload,
                  onPressed: onReloadValue,
                ),
              if (onDeleteValue != null)
                _PluginIconAction(
                  icon: Icons.delete_outline_rounded,
                  tooltip: context.l10n.pluginsUninstallAction,
                  danger: true,
                  onPressed: onDeleteValue,
                ),
              if (onInstall != null)
                ElevatedButton.icon(
                  onPressed: installing || (installed && !hasUpdate)
                      ? null
                      : onInstall,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: hasUpdate
                        ? const Color(0xff059669)
                        : AppColors.primary600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: context.isDark
                        ? AppColors.slate800
                        : AppColors.slate100,
                    disabledForegroundColor: AppColors.slate400,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  icon: installing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 17),
                  label: Text(
                    installing
                        ? context.l10n.pluginsProcessing
                        : hasUpdate
                            ? context.l10n.pluginsUpdate
                            : installed
                                ? context.l10n.pluginsInstalledTab
                                : context.l10n.pluginsInstall,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PluginFooterButton extends StatelessWidget {
  const _PluginFooterButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: context.mutedText,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: icon,
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _PluginIconAction extends StatelessWidget {
  const _PluginIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        splashRadius: 21,
        color: danger ? const Color(0xffdc2626) : context.mutedText,
        icon: Icon(icon, size: 19),
      ),
    );
  }
}

class _PluginInfoChip extends StatelessWidget {
  const _PluginInfoChip({
    required this.label,
    this.icon,
    this.color,
    this.background,
    this.border,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;
  final Color? border;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final fg =
        color ?? (context.isDark ? AppColors.slate300 : AppColors.slate600);
    final chip = Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background ??
            (context.isDark ? AppColors.slate800 : AppColors.slate50),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: border ?? context.faintBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
    final message = tooltip?.trim();
    if (message == null || message.isEmpty) return chip;
    return Tooltip(message: message, child: chip);
  }
}

class _PluginStateBadge extends StatelessWidget {
  const _PluginStateBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final active = state == 'active' || state == 'loaded';
    final failed = state == 'failed';
    final color = failed
        ? const Color(0xffdc2626)
        : active
            ? const Color(0xff16a34a)
            : AppColors.slate600;
    final bg = failed
        ? const Color(0xfffff1f2)
        : active
            ? const Color(0xfff0fdf4)
            : AppColors.slate50;
    final label = switch (state) {
      'active' || 'loaded' => context.l10n.pluginsStateActive,
      'failed' => context.l10n.pluginsStateFailed,
      'loading' => context.l10n.pluginsStateLoading,
      'inactive' => context.l10n.pluginsStateInactive,
      _ => context.localeText('未知', 'Unknown'),
    };
    final icon = active
        ? Icons.check_circle_rounded
        : failed
            ? Icons.cancel_rounded
            : Icons.error_outline_rounded;

    return _Badge(label: label, icon: icon, color: color, background: bg);
  }
}

class _StorePluginBadge extends StatelessWidget {
  const _StorePluginBadge({
    required this.installed,
    required this.hasUpdate,
  });

  final bool installed;
  final bool hasUpdate;

  @override
  Widget build(BuildContext context) {
    if (hasUpdate) {
      return _Badge(
        label: context.l10n.pluginsUpdateAvailable,
        color: const Color(0xff047857),
        background: const Color(0xffecfdf5),
      );
    }
    if (installed) {
      return _Badge(
        label: context.l10n.pluginsInstalledTab,
        color: AppColors.slate600,
        background: AppColors.slate50,
      );
    }
    return const SizedBox.shrink();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginEmptyState extends StatelessWidget {
  const _PluginEmptyState({required this.tab});

  final _PluginTab tab;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: tab == _PluginTab.installed
          ? Icons.extension_off_rounded
          : Icons.shopping_bag_outlined,
      title: tab == _PluginTab.updates
          ? context.l10n.pluginsNoUpdates
          : tab == _PluginTab.installed
              ? context.l10n.pluginsNoInstalled
              : context.l10n.pluginsNoMatches,
      message: tab == _PluginTab.installed
          ? context.l10n.pluginsInstalledEmptyHint
          : context.l10n.pluginsFilterEmptyHint,
    );
  }
}

class _PluginTypeStyle {
  const _PluginTypeStyle({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

_PluginTypeStyle _pluginTypeStyle(String type, BuildContext context) {
  if (context.isDark) {
    switch (type) {
      case 'format':
        return _PluginTypeStyle(
          foreground: const Color(0xff67e8f9),
          background: const Color(0xff083344).withValues(alpha: 0.4),
          border: const Color(0xff164e63).withValues(alpha: 0.5),
        );
      case 'utility':
        return _PluginTypeStyle(
          foreground: const Color(0xff6ee7b7),
          background: const Color(0xff022c22).withValues(alpha: 0.4),
          border: const Color(0xff064e3b).withValues(alpha: 0.5),
        );
      case 'scraper':
        return _PluginTypeStyle(
          foreground: const Color(0xff93c5fd),
          background: const Color(0xff172554).withValues(alpha: 0.4),
          border: const Color(0xff1e3a8a).withValues(alpha: 0.5),
        );
    }
  }
  switch (type) {
    case 'format':
      return const _PluginTypeStyle(
        foreground: Color(0xff0e7490),
        background: Color(0xffecfeff),
        border: Color(0xffcffafe),
      );
    case 'utility':
      return const _PluginTypeStyle(
        foreground: Color(0xff047857),
        background: Color(0xffecfdf5),
        border: Color(0xffd1fae5),
      );
    case 'scraper':
      return const _PluginTypeStyle(
        foreground: Color(0xff1d4ed8),
        background: Color(0xffeff6ff),
        border: Color(0xffdbeafe),
      );
    default:
      return _PluginTypeStyle(
        foreground: context.isDark ? AppColors.slate200 : AppColors.slate700,
        background: context.isDark ? AppColors.slate800 : AppColors.slate50,
        border: context.faintBorder,
      );
  }
}

IconData _pluginTypeIcon(String type) {
  if (type == 'format') return Icons.description_rounded;
  if (type == 'utility') return Icons.inventory_2_rounded;
  return Icons.extension_rounded;
}

String _pluginTypeLabel(BuildContext context, String type) {
  switch (type) {
    case 'scraper':
      return context.l10n.pluginsCategoryMetadata;
    case 'format':
      return context.l10n.pluginsCategoryFormat;
    case 'utility':
      return context.l10n.pluginsCategoryUtility;
    default:
      return type.isNotEmpty ? type : context.localeText('未知', 'Unknown');
  }
}

int _metadataCapabilityListCount(
    List<PluginCapability> capabilities, String key) {
  var count = 0;
  for (final capability in capabilities) {
    if (capability.kind != 'metadata_provider') continue;
    final direct = capability.extra[key];
    final value = direct;
    if (value is List) count += value.length;
  }
  return count;
}

String? _pluginRuntimeLabel(String? runtime) {
  final value = runtime?.trim();
  switch (value?.toLowerCase()) {
    case 'wasm':
      return 'WASM';
    case 'javascript':
      return 'JavaScript';
    case 'native':
      return 'Native';
    default:
      return value?.isNotEmpty == true ? value : null;
  }
}

bool _usesClientExtension(PluginItem item) {
  return item.capabilities.any(
    (capability) => capability.kind == 'ui_extension',
  );
}

List<String> _pluginCapabilityKinds(List<PluginCapability> capabilities) {
  const order = [
    'metadata_provider',
    'format_handler',
    'content_processor',
    'tool_provider',
    'ui_extension',
    'http_route',
    'plugin_store',
    'task_handler',
    'event_handler',
  ];
  final kinds = capabilities.map((capability) => capability.kind).toSet();
  return order.where(kinds.contains).toList();
}

String? _localizedText(Map<String, String> values, BuildContext context) {
  if (values.isEmpty) return null;
  final locale = Localizations.localeOf(context);
  final language = locale.languageCode.toLowerCase();
  final country = locale.countryCode?.toLowerCase();
  final candidates = <String>[
    if (country != null && country.isNotEmpty) '$language-$country',
    language,
    language.startsWith('en') ? 'en' : 'zh',
    language.startsWith('en') ? 'zh' : 'en',
  ];

  for (final key in candidates) {
    final direct = values[key]?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    for (final entry in values.entries) {
      if (entry.key.replaceAll('_', '-').toLowerCase() == key) {
        final value = entry.value.trim();
        if (value.isNotEmpty) return value;
      }
    }
  }

  for (final value in values.values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String _formatPluginVersion(String? version) {
  if (version == null || version.isEmpty) return 'v?';
  return version.startsWith('v') ? version : 'v$version';
}

class _GitHubIcon extends StatelessWidget {
  const _GitHubIcon({this.size = 17});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GitHubIconPainter(
        color: IconTheme.of(context).color ?? context.mutedText,
      ),
    );
  }
}

class _GitHubIconPainter extends CustomPainter {
  const _GitHubIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final path = Path()
      ..moveTo(15, 22)
      ..lineTo(15, 18)
      ..cubicTo(15, 16.6, 14.65, 15.4, 14, 14.5)
      ..cubicTo(17, 14.5, 20, 12.5, 20, 9)
      ..cubicTo(20.08, 7.75, 19.73, 6.52, 19, 5.5)
      ..cubicTo(19.28, 4.35, 19.28, 3.15, 19, 2)
      ..cubicTo(19, 2, 18, 2, 16, 3.5)
      ..cubicTo(13.36, 3, 10.64, 3, 8, 3.5)
      ..cubicTo(6, 2, 5, 2, 5, 2)
      ..cubicTo(4.7, 3.15, 4.7, 4.35, 5, 5.5)
      ..cubicTo(4.35, 6.5, 4, 7.7, 4, 9)
      ..cubicTo(4, 12.5, 7, 14.5, 10, 14.5)
      ..cubicTo(9.61, 14.99, 9.32, 15.55, 9.15, 16.15)
      ..cubicTo(8.98, 16.75, 8.93, 17.38, 9, 18)
      ..lineTo(9, 22)
      ..moveTo(9, 18)
      ..cubicTo(4.49, 20, 4, 16, 2, 16);
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GitHubIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
