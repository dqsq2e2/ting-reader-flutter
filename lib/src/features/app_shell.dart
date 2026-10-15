import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin/admin_pages.dart';
import 'admin/users/admin_users_page.dart';
import 'bookshelf/book_detail/book_detail_page.dart';
import 'bookshelf/bookshelf_page.dart';
import 'bookshelf/search_page.dart';
import 'bookshelf/series_detail/series_detail_page.dart';
import 'home/home_page.dart';
import 'mine/about_update_dialog.dart';
import 'mine/downloads_page.dart';
import 'mine/favorites_page.dart';
import 'mine/fn_connect_page.dart';
import 'mine/mine_page.dart';
import 'mine/history_page.dart';
import 'mine/bookmarks_page.dart';
import 'mine/personalization/personalization_page.dart';
import 'playlists/playlists_page.dart';
import '../core/models/models.dart';
import '../core/state/navigation_state.dart';
import '../core/plugin_extensions/types.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/locale.dart';
import '../shared/app_scope.dart';
import '../shared/common/common_widgets.dart';
import '../shared/plugin_extensions/plugin_extension_host.dart';
import 'player/mini_player.dart';

part 'shell_mobile_navigation.dart';

part 'shell_desktop_navigation.dart';

const _expandedSidebarWidth = 288.0;
const _collapsedSidebarWidth = 80.0;
const _desktopSidebarContentGap = 20.0;

typedef _NavigationEntry = ({
  AppDestination destination,
  IconData icon,
  String label,
});

List<_NavigationEntry> _navigationEntries(BuildContext context,
    {bool admin = false}) {
  final l10n = context.l10n;
  return admin
      ? [
          (
            destination: AppDestination.libraries,
            icon: Icons.storage_rounded,
            label: l10n.navLibraries
          ),
          (
            destination: AppDestination.plugins,
            icon: Icons.extension_rounded,
            label: l10n.navPlugins
          ),
          (
            destination: AppDestination.logs,
            icon: Icons.terminal_rounded,
            label: l10n.navLogs
          ),
          (
            destination: AppDestination.users,
            icon: Icons.group_rounded,
            label: l10n.navUsers
          ),
        ]
      : [
          (
            destination: AppDestination.home,
            icon: Icons.home_rounded,
            label: l10n.navHome
          ),
          (
            destination: AppDestination.bookshelf,
            icon: Icons.library_books_rounded,
            label: l10n.navBookshelf
          ),
          (
            destination: AppDestination.playlists,
            icon: Icons.playlist_play_rounded,
            label: l10n.navPlaylists
          ),
          (
            destination: AppDestination.mine,
            icon: Icons.person_rounded,
            label: l10n.navMine
          ),
        ];
}

bool _navigationSelected(AppDestination target, AppDestination current) =>
    target == AppDestination.mine
        ? isMineDestination(current)
        : target == AppDestination.bookshelf
            ? current == target || current == AppDestination.search
            : current == target;

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ShellNavigation _navigation;
  AppDestination get _destination => _navigation.destination;
  AppDestination get _searchOrigin => _navigation.searchOrigin;
  String? get _bookId => _navigation.bookId;
  String? get _bookInitialChapterId => _navigation.chapterId;
  String? get _seriesId => _navigation.seriesId;
  String? get _playlistId => _navigation.playlistId;
  String? get _aboutBackendVersion => _navigation.aboutBackendVersion;
  ClientExtensionDescriptor? get _activePluginPage =>
      _navigation.activePluginPage;
  PluginItem? get _activePluginLogs => _navigation.activePluginLogs;
  bool _mobileAdminDrawerOpen = false;
  ClientExtensionRegistrySnapshot get _pluginRegistry =>
      AppScope.appOf(context).clientExtensions.snapshot;
  String? _defaultCredentialsReminderIdentity;

  @override
  void initState() {
    super.initState();
    _navigation = ShellNavigation.fromQuery(Uri.base.queryParameters);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = AppScope.appOf(context);
    _remindDefaultAdminCredentials();
    appState.ensureClientExtensions();
    if (appState.offlineMode || appState.token == null) {
      _navigation.activePluginPage = null;
      _navigation.activePluginLogs = null;
      return;
    }
    final active = _activePluginPage;
    if (active != null && !appState.clientExtensions.loading) {
      _navigation.activePluginPage =
          _sidebarPluginPages.where((item) => item.id == active.id).firstOrNull;
    }
    _restoreInitialPluginPage();
  }

  void _remindDefaultAdminCredentials() {
    final appState = AppScope.appOf(context);
    final user = appState.user;
    if (appState.offlineMode ||
        !appState.isAuthenticated ||
        user == null ||
        !user.isAdmin ||
        !user.usesDefaultAdminCredentials) {
      return;
    }
    final identity = '${appState.serverUrl}:${user.id}';
    if (_defaultCredentialsReminderIdentity == identity) return;
    _defaultCredentialsReminderIdentity = identity;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final current = AppScope.appOf(context);
      if (current.offlineMode ||
          '${current.serverUrl}:${current.user?.id}' != identity ||
          current.user?.usesDefaultAdminCredentials != true) {
        return;
      }
      final changeCredentials = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.security_rounded),
          title: Text(dialogContext.l10n.authDefaultCredentialsTitle),
          content: Text(dialogContext.l10n.authDefaultCredentialsMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.authDefaultCredentialsLater),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.l10n.authDefaultCredentialsChange),
            ),
          ],
        ),
      );
      if (!mounted || changeCredentials != true) return;
      final active = AppScope.appOf(context);
      if ('${active.serverUrl}:${active.user?.id}' != identity) return;
      AppScope.playerOf(context).setExpanded(false);
      _go(AppDestination.mine);
    });
  }

  List<ClientExtensionDescriptor> get _sidebarPluginPages {
    final appState = AppScope.appOf(context);
    final extensions =
        _pluginRegistry.bySlot[ClientExtensionSlot.appSidebarPage] ?? const [];
    return extensions
        .where((extension) => !extension.adminOnly || appState.isAdmin)
        .toList(growable: false);
  }

  void _restoreInitialPluginPage() {
    if (_destination != AppDestination.pluginPage ||
        _activePluginPage != null) {
      return;
    }
    final pluginId = _navigation.initialPluginId;
    final capabilityId = _navigation.initialCapabilityId;
    if (pluginId == null || capabilityId == null) return;
    for (final extension in _sidebarPluginPages) {
      if (extension.pluginId == pluginId &&
          extension.capability.id == capabilityId) {
        _navigation.activePluginPage = extension;
        return;
      }
    }
  }

  void _navigate(VoidCallback change) {
    setState(() {
      _mobileAdminDrawerOpen = false;
      change();
    });
    if (hidesMiniPlayer(_navigation.navDestination)) {
      AppScope.playerOf(context).setExpanded(false);
    }
  }

  void _go(AppDestination destination) =>
      _navigate(() => _navigation.go(destination));
  void _openPluginLogs(PluginItem plugin) =>
      _navigate(() => _navigation.openPluginLogs(plugin));
  void _openPluginPage(ClientExtensionDescriptor extension) =>
      _navigate(() => _navigation.openPluginPage(extension));
  void _openAbout(String? version) =>
      _navigate(() => _navigation.openAbout(version));

  void _openMobileAdminDrawer() {
    setState(() => _mobileAdminDrawerOpen = true);
  }

  void _closeMobileAdminDrawer() {
    if (_mobileAdminDrawerOpen) {
      setState(() => _mobileAdminDrawerOpen = false);
    }
  }

  void _openBook(String id) => _openBookAtChapter(id, null);
  void _openBookAtChapter(String id, String? chapterId) => _navigate(() =>
      _navigation.openDetail(DetailDestination.book, id, chapter: chapterId));
  void _openSeries(String id) =>
      _navigate(() => _navigation.openDetail(DetailDestination.series, id));
  void _openPlaylist(String id) =>
      _navigate(() => _navigation.openDetail(DetailDestination.playlist, id));
  void _openSearch(AppDestination origin) =>
      _navigate(() => _navigation.openSearch(origin));
  void _backFromDetail() => setState(_navigation.closeDetail);

  bool _handleSystemBack() {
    final player = AppScope.playerOf(context);
    if (player.isExpanded) {
      player.setExpanded(false);
      return true;
    }
    if (_mobileAdminDrawerOpen) {
      _closeMobileAdminDrawer();
      return true;
    }
    if (_navigation.hasDetail) {
      _backFromDetail();
      return true;
    }
    final destination = _navigation.backDestination;
    if (destination != null) {
      _go(destination);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final connectionErrorValue = appState.connectionError;
        if (connectionErrorValue != null) {
          return _ConnectionScreen(
            message: connectionErrorValue,
            onRetry: appState.validateConnection,
            onLogout: appState.logout,
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final handled = _handleSystemBack();
            if (!handled) SystemNavigator.pop();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 1280;
              final sidebarCollapsed = appState.sidebarCollapsed;
              final navDestination = _navigation.navDestination;
              return AnimatedBuilder(
                animation: AppScope.playerOf(context),
                builder: (context, _) {
                  final player = AppScope.playerOf(context);
                  final bottomInset = MediaQuery.of(context).padding.bottom;
                  final collapsedMini = player.isMiniCollapsed;
                  final showMiniPlayer = player.hasChapter &&
                      !player.isExpanded &&
                      !hidesMiniPlayer(navDestination);
                  final pluginExtensionBottom = showMiniPlayer
                      ? (desktop ? 128.0 : 150.0 + bottomInset)
                      : (desktop ? 24.0 : 84.0 + bottomInset);
                  return Stack(
                    children: [
                      Scaffold(
                        body: Row(
                          children: [
                            if (desktop)
                              _DesktopSidebar(
                                go: _go,
                                current: navDestination,
                                collapsed: sidebarCollapsed,
                                onToggleCollapsed: () =>
                                    appState.updateLocalSettings({
                                  'sidebar_collapsed': !sidebarCollapsed,
                                }),
                                pluginPages: _sidebarPluginPages,
                                activePluginPageId: _activePluginPage?.id,
                                onOpenPluginPage: _openPluginPage,
                              ),
                            Expanded(
                              child: Column(
                                children: [
                                  if (!desktop)
                                    _MobileHeader(
                                      openMenu: _openMobileAdminDrawer,
                                    ),
                                  Expanded(child: _page()),
                                  if (!desktop)
                                    _BottomNav(
                                      current: navDestination,
                                      go: _go,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showMiniPlayer)
                        Positioned(
                          left: desktop
                              ? (sidebarCollapsed
                                      ? _collapsedSidebarWidth
                                      : _expandedSidebarWidth) +
                                  _desktopSidebarContentGap
                              : (collapsedMini ? 24 : 12),
                          right: collapsedMini ? null : (desktop ? 20 : 12),
                          bottom: desktop
                              ? 20
                              : 64 + bottomInset + (collapsedMini ? 20 : 0),
                          child: const MiniPlayer(),
                        ),
                      if (!player.isExpanded && !_mobileAdminDrawerOpen)
                        Positioned.fill(
                          child: PluginExtensionHost(
                            bottomOffset: pluginExtensionBottom,
                            enabled: appState.pluginToolMenuEnabled &&
                                _destination != AppDestination.pluginPage,
                          ),
                        ),
                      if (!desktop && _mobileAdminDrawerOpen)
                        Positioned.fill(
                          child: _MobileAdminOverlay(
                            go: _go,
                            current: navDestination,
                            onClose: _closeMobileAdminDrawer,
                            pluginPages: _sidebarPluginPages,
                            activePluginPageId: _activePluginPage?.id,
                            onOpenPluginPage: _openPluginPage,
                          ),
                        ),
                      if (desktop && sidebarCollapsed && !player.isExpanded)
                        Positioned(
                          left: _collapsedSidebarWidth - 22,
                          top: MediaQuery.paddingOf(context).top + 22,
                          child: _SidebarToggleButton(
                            collapsed: true,
                            onPressed: () => appState.updateLocalSettings({
                              'sidebar_collapsed': false,
                            }),
                          ),
                        ),
                      if (player.isExpanded)
                        const Positioned.fill(child: ExpandedPlayerOverlay()),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _page() {
    final bookId = _bookId;
    final playlistId = _playlistId;
    final seriesId = _seriesId;
    if (AppScope.appOf(context).offlineMode) {
      return const DownloadsPage();
    }
    if (bookId != null) {
      return BookDetailPage(
        bookId: bookId,
        initialChapterId: _bookInitialChapterId,
        onBack: _backFromDetail,
      );
    }
    if (playlistId != null) {
      return PlaylistDetailPage(
        playlistId: playlistId,
        onBack: () => _go(AppDestination.playlists),
        openBook: _openBook,
        openSeries: _openSeries,
      );
    }
    if (seriesId != null) {
      return SeriesDetailPage(
        seriesId: seriesId,
        onBack: _backFromDetail,
        openBook: _openBook,
      );
    }

    switch (_destination) {
      case AppDestination.home:
        return HomePage(
          openBook: _openBook,
          openBookshelf: () => _go(AppDestination.bookshelf),
          openHistory: () => _go(AppDestination.history),
          openSearch: () => _openSearch(AppDestination.home),
          openPlaylists: () => _go(AppDestination.playlists),
        );
      case AppDestination.bookshelf:
        return BookshelfPage(
          openBook: _openBook,
          openSeries: _openSeries,
          openLibraries: () => _go(AppDestination.libraries),
          openSearch: () => _openSearch(AppDestination.bookshelf),
        );
      case AppDestination.search:
        return SearchPage(
          openBook: _openBook,
          onBack: () => _go(_searchOrigin),
        );
      case AppDestination.favorites:
        return FavoritesPage(
          openBook: _openBook,
          openBookshelf: () => _go(AppDestination.bookshelf),
          onBack: () => _go(AppDestination.mine),
        );
      case AppDestination.mine:
        return MyPage(
          openHistory: () => _go(AppDestination.history),
          openBookmarks: () => _go(AppDestination.bookmarks),
          openFavorites: () => _go(AppDestination.favorites),
          openDownloads: () => _go(AppDestination.downloads),
          openPersonalization: () => _go(AppDestination.personalization),
          openFnConnect: () => _go(AppDestination.fnConnect),
          openNotifications: () => _go(AppDestination.notifications),
          openStatistics: () => _go(AppDestination.statistics),
          openAbout: _openAbout,
          openBook: _openBook,
        );
      case AppDestination.history:
        return HistoryPage(
          openBook: _openBookAtChapter,
          onBack: () => _go(AppDestination.mine),
          openBookshelf: () => _go(AppDestination.bookshelf),
        );
      case AppDestination.bookmarks:
        return BookmarksPage(onBack: () => _go(AppDestination.mine));
      case AppDestination.playlists:
        return PlaylistsPage(
          openPlaylist: _openPlaylist,
          onBack: () => _go(AppDestination.home),
        );
      case AppDestination.personalization:
        return PersonalizationPage(
          openDownloads: () => _go(AppDestination.downloads),
          onBack: () => _go(AppDestination.mine),
        );
      case AppDestination.fnConnect:
        return FnConnectPage(onBack: () => _go(AppDestination.mine));
      case AppDestination.notifications:
        return NotificationSettingsPage(onBack: () => _go(AppDestination.mine));
      case AppDestination.statistics:
        return AdminStatisticsPage(onBack: () => _go(AppDestination.mine));
      case AppDestination.downloads:
        return DownloadsPage(onBack: () => _go(AppDestination.mine));
      case AppDestination.about:
        return AboutPage(
          backendVersion: _aboutBackendVersion,
          onBack: () => _go(AppDestination.mine),
        );
      case AppDestination.libraries:
        return const AdminLibrariesPage();
      case AppDestination.plugins:
        return PluginsPage(onViewLogs: _openPluginLogs);
      case AppDestination.logs:
        return const LogsPage();
      case AppDestination.users:
        return const AdminUsersV2Page();
      case AppDestination.pluginLogs:
        final plugin = _activePluginLogs;
        if (plugin == null) {
          return PluginsPage(onViewLogs: _openPluginLogs);
        }
        return PluginLogsPage(
          key: ValueKey(plugin.id),
          plugin: plugin,
          onBack: () => _go(AppDestination.plugins),
        );
      case AppDestination.pluginPage:
        final extension = _activePluginPage;
        if (extension == null) {
          return EmptyState(
            icon: Icons.extension_off_rounded,
            title: context.l10n.pluginPageUnavailable,
            message: context.l10n.pluginPageUnavailableDescription,
          );
        }
        final user = AppScope.appOf(context).user;
        return PluginExtensionPage(
          key: ValueKey(extension.id),
          extension: extension,
          onBack: () => _go(AppDestination.home),
          extensionContext: <String, Object?>{
            'surface': ClientExtensionSlot.appSidebarPage.value,
            'user_id': user?.id,
            'username': user?.username,
            'role': user?.role,
          },
        );
    }
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.collapsed = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
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
                Icon(
                  icon,
                  color: selected ? Colors.white : context.mutedText,
                  size: 20,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : context.mutedText,
                      ),
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
      child: collapsed ? Tooltip(message: label, child: tile) : tile,
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {this.collapsed = false});

  final String text;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    if (collapsed) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.slate400,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ConnectionScreen extends StatelessWidget {
  const _ConnectionScreen({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ConnectionStatusCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 72,
                      height: 72,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.connectionFailed,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: context.l10n.commonRetryConnection,
                      icon: Icons.refresh_rounded,
                      onPressed: onRetry,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onLogout,
                      child: Text(context.l10n.navLogout),
                    ),
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
