part of 'app_shell.dart';

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.go,
    required this.current,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.pluginPages,
    required this.activePluginPageId,
    required this.onOpenPluginPage,
  });

  final ValueChanged<AppDestination> go;
  final AppDestination current;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final List<ClientExtensionDescriptor> pluginPages;
  final String? activePluginPageId;
  final ValueChanged<ClientExtensionDescriptor> onOpenPluginPage;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final user = appState.user;
    final l10n = context.l10n;
    final offline = appState.offlineMode;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: collapsed ? _collapsedSidebarWidth : _expandedSidebarWidth,
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(right: BorderSide(color: context.faintBorder)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 12 : 16,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SidebarHeader(
                collapsed: collapsed,
                onToggleCollapsed: onToggleCollapsed,
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverList(
                      delegate: SliverChildListDelegate([
                        if (offline) ...[
                          _GroupLabel(
                            l10n.navOfflineMode,
                            collapsed: collapsed,
                          ),
                          _NavTile(
                            icon: Icons.download_done_rounded,
                            label: l10n.navDownloads,
                            selected: true,
                            collapsed: collapsed,
                            onTap: () => go(AppDestination.downloads),
                          ),
                        ] else ...[
                          _GroupLabel(
                            l10n.navMainMenu,
                            collapsed: collapsed,
                          ),
                          for (final entry in _navigationEntries(context))
                            _NavTile(
                              icon: entry.icon,
                              label: entry.label,
                              selected: _navigationSelected(
                                  entry.destination, current),
                              collapsed: collapsed,
                              onTap: () => go(entry.destination),
                            ),
                          if (appState.isAdmin) ...[
                            const SizedBox(height: 32),
                            _GroupLabel(
                              l10n.navAdmin,
                              collapsed: collapsed,
                            ),
                            for (final entry
                                in _navigationEntries(context, admin: true))
                              _NavTile(
                                icon: entry.icon,
                                label: entry.label,
                                selected: _navigationSelected(
                                    entry.destination, current),
                                collapsed: collapsed,
                                onTap: () => go(entry.destination),
                              ),
                          ],
                          if (collapsed && pluginPages.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _GroupLabel(
                              l10n.navPluginPages,
                              collapsed: true,
                            ),
                            for (final extension in pluginPages)
                              _PluginNavTile(
                                extension: extension,
                                selected:
                                    current == AppDestination.pluginPage &&
                                        activePluginPageId == extension.id,
                                collapsed: true,
                                onTap: () => onOpenPluginPage(extension),
                              ),
                          ],
                        ],
                      ]),
                    ),
                    if (!offline && !collapsed && pluginPages.isNotEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 32),
                            _GroupLabel(
                              l10n.navPluginPages,
                              collapsed: false,
                            ),
                            for (final extension in pluginPages)
                              _PluginNavTile(
                                extension: extension,
                                selected:
                                    current == AppDestination.pluginPage &&
                                        activePluginPageId == extension.id,
                                collapsed: false,
                                onTap: () => onOpenPluginPage(extension),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Divider(color: context.faintBorder, height: 18),
              if (offline)
                _DesktopLogoutButton(
                  collapsed: collapsed,
                  label: l10n.navReturnLogin,
                  onPressed: appState.logout,
                )
              else
                _DesktopAccountCard(
                  collapsed: collapsed,
                  username: user?.username ?? '',
                  roleLabel: user?.isAdmin == true ? 'ADMINISTRATOR' : 'USER',
                  onLogout: appState.logout,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return SizedBox(
        height: 56,
        child: Center(
          child: Image.asset('assets/images/logo.png', width: 36, height: 36),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 36, height: 36),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Ting Reader',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            _SidebarToggleButton(
              collapsed: false,
              onPressed: onToggleCollapsed,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarToggleButton extends StatelessWidget {
  const _SidebarToggleButton({
    required this.collapsed,
    required this.onPressed,
  });

  final bool collapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tooltip = collapsed
        ? context.l10n.navExpandSidebar
        : context.l10n.navCollapseSidebar;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox.square(
          dimension: 44,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.faintBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SizedBox.square(
                    dimension: 32,
                    child: Icon(
                      collapsed
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      size: 17,
                      color: context.mutedText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopAccountCard extends StatelessWidget {
  const _DesktopAccountCard({
    required this.collapsed,
    required this.username,
    required this.roleLabel,
    required this.onLogout,
  });

  final bool collapsed;
  final String username;
  final String roleLabel;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      backgroundColor: AppColors.primary100,
      foregroundColor: AppColors.primary700,
      child: Text(
        username.isNotEmpty ? username.substring(0, 1).toUpperCase() : 'U',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
    if (collapsed) {
      return Column(
        children: [
          Tooltip(message: username, child: avatar),
          const SizedBox(height: 4),
          IconButton(
            tooltip: context.l10n.navLogout,
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.slate800.withValues(alpha: 0.55)
            : AppColors.slate50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  roleLabel,
                  style: TextStyle(color: context.mutedText, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.navLogout,
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _DesktopLogoutButton extends StatelessWidget {
  const _DesktopLogoutButton({
    required this.collapsed,
    required this.label,
    required this.onPressed,
  });

  final bool collapsed;
  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.logout_rounded),
      label: Text(label),
    );
  }
}

class _PluginNavTile extends StatelessWidget {
  const _PluginNavTile({
    required this.extension,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final ClientExtensionDescriptor extension;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : context.mutedText;
    final tile = Material(
      color: selected ? AppColors.primary600 : Colors.transparent,
      elevation: selected ? 8 : 0,
      shadowColor: AppColors.primary500.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                PluginExtensionIcon(
                  extension: extension,
                  size: 20,
                  color: foreground,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      extension.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: foreground),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: collapsed ? Tooltip(message: extension.label, child: tile) : tile,
    );
  }
}
