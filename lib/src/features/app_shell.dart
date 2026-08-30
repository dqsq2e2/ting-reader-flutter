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
import 'mine/personalization/personalization_page.dart';
import 'playlists/playlists_page.dart';
import '../core/models/models.dart';
import '../core/plugin_extensions/registry.dart';
import '../core/plugin_extensions/types.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/locale.dart';
import '../shared/app_scope.dart';
import '../shared/common/common_widgets.dart';
import '../shared/plugin_extensions/plugin_extension_host.dart';
import 'player/mini_player.dart';

enum AppDestination {
  home,
  bookshelf,
  search,
  favorites,
  mine,
  history,
  playlists,
  personalization,
  fnConnect,
  notifications,
  statistics,
  downloads,
  about,
  libraries,
  plugins,
  logs,
  users,
  pluginLogs,
  pluginPage,
}

const _expandedSidebarWidth = 288.0;
const _collapsedSidebarWidth = 80.0;
const _desktopSidebarContentGap = 20.0;

bool _isMineDestination(AppDestination destination) {
  return switch (destination) {
    AppDestination.mine ||
    AppDestination.history ||
    AppDestination.favorites ||
    AppDestination.personalization ||
    AppDestination.fnConnect ||
    AppDestination.notifications ||
    AppDestination.statistics ||
    AppDestination.downloads ||
    AppDestination.about =>
      true,
    _ => false,
  };
}

bool _hidesMiniPlayer(AppDestination destination) {
  return switch (destination) {
    AppDestination.personalization ||
    AppDestination.fnConnect ||
    AppDestination.notifications ||
    AppDestination.statistics ||
    AppDestination.about ||
    AppDestination.libraries ||
    AppDestination.plugins ||
    AppDestination.logs ||
    AppDestination.users ||
    AppDestination.pluginLogs ||
    AppDestination.pluginPage =>
      true,
    _ => false,
  };
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppDestination _destination = AppDestination.home;
  String? _bookId;
  String? _bookInitialChapterId;
  String? _seriesId;
  String? _playlistId;
  AppDestination _searchOrigin = AppDestination.bookshelf;
  bool _mobileAdminDrawerOpen = false;
  String? _aboutBackendVersion;
  ClientExtensionRegistrySnapshot _pluginRegistry =
      ClientExtensionRegistrySnapshot.empty;
  ClientExtensionDescriptor? _activePluginPage;
  PluginItem? _activePluginLogs;
  String? _loadedPluginToken;
  int? _loadedPluginRevision;
  bool _loadingPluginExtensions = false;
  bool _reloadPluginExtensions = false;
  String? _initialPluginId;
  String? _initialPluginCapabilityId;

  @override
  void initState() {
    super.initState();
    final params = Uri.base.queryParameters;
    _destination = _destinationFromQuery(params['page']);
    _bookId = params['book'];
    _bookInitialChapterId = params['chapter'];
    _seriesId = params['series'];
    _playlistId = params['playlist'];
    _initialPluginId = params['plugin'];
    _initialPluginCapabilityId = params['capability'];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = AppScope.appOf(context);
    final revision = appState.pluginExtensionRevision;
    final cached = appState.pluginCapabilities.cachedClientExtensions;
    if (cached != null) {
      _pluginRegistry = buildClientExtensionRegistry(cached);
      _restoreInitialPluginPage();
    }
    if (appState.offlineMode || appState.token == null) {
      _loadedPluginToken = null;
      _loadedPluginRevision = null;
      _pluginRegistry = ClientExtensionRegistrySnapshot.empty;
      _activePluginPage = null;
      _activePluginLogs = null;
      return;
    }
    if (_loadedPluginToken == appState.token &&
        _loadedPluginRevision == revision) {
      return;
    }
    _loadedPluginToken = appState.token;
    _loadedPluginRevision = revision;
    _loadPluginExtensions();
  }

  AppDestination _destinationFromQuery(String? page) {
    switch (page) {
      case 'bookshelf':
        return AppDestination.bookshelf;
      case 'search':
        return AppDestination.search;
      case 'favorites':
        return AppDestination.favorites;
      case 'mine':
        return AppDestination.mine;
      case 'history':
        return AppDestination.history;
      case 'playlists':
        return AppDestination.playlists;
      case 'personalization':
      case 'settings':
        return AppDestination.personalization;
      case 'fn-connect':
        return AppDestination.fnConnect;
      case 'notifications':
        return AppDestination.notifications;
      case 'statistics':
        return AppDestination.statistics;
      case 'downloads':
        return AppDestination.downloads;
      case 'about':
        return AppDestination.about;
      case 'libraries':
        return AppDestination.libraries;
      case 'plugins':
        return AppDestination.plugins;
      case 'logs':
        return AppDestination.logs;
      case 'users':
        return AppDestination.users;
      case 'plugin-page':
        return AppDestination.pluginPage;
      default:
        return AppDestination.home;
    }
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
    final pluginId = _initialPluginId;
    final capabilityId = _initialPluginCapabilityId;
    if (pluginId == null || capabilityId == null) return;
    for (final extension in _sidebarPluginPages) {
      if (extension.pluginId == pluginId &&
          extension.capability.id == capabilityId) {
        _activePluginPage = extension;
        return;
      }
    }
  }

  Future<void> _loadPluginExtensions() async {
    if (_loadingPluginExtensions) {
      _reloadPluginExtensions = true;
      return;
    }
    _loadingPluginExtensions = true;
    try {
      final registrations = await AppScope.appOf(context)
          .pluginCapabilities
          .listClientExtensions();
      if (!mounted) return;
      final registry = buildClientExtensionRegistry(registrations);
      final activeId = _activePluginPage?.id;
      setState(() {
        _pluginRegistry = registry;
        if (activeId != null) {
          _activePluginPage = _sidebarPluginPages
              .where((extension) => extension.id == activeId)
              .firstOrNull;
        }
        _restoreInitialPluginPage();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pluginRegistry = ClientExtensionRegistrySnapshot.empty;
        _activePluginPage = null;
      });
    } finally {
      _loadingPluginExtensions = false;
      if (_reloadPluginExtensions && mounted) {
        _reloadPluginExtensions = false;
        _loadPluginExtensions();
      }
    }
  }

  void _go(AppDestination destination) {
    if (_hidesMiniPlayer(destination)) {
      AppScope.playerOf(context).setExpanded(false);
    }
    setState(() {
      _mobileAdminDrawerOpen = false;
      _destination = destination;
      _bookId = null;
      _bookInitialChapterId = null;
      _seriesId = null;
      _playlistId = null;
      _aboutBackendVersion = null;
      _activePluginPage = null;
      _activePluginLogs = null;
    });
  }

  void _openPluginLogs(PluginItem plugin) {
    AppScope.playerOf(context).setExpanded(false);
    setState(() {
      _mobileAdminDrawerOpen = false;
      _destination = AppDestination.pluginLogs;
      _bookId = null;
      _bookInitialChapterId = null;
      _seriesId = null;
      _playlistId = null;
      _aboutBackendVersion = null;
      _activePluginPage = null;
      _activePluginLogs = plugin;
    });
  }

  void _openPluginPage(ClientExtensionDescriptor extension) {
    AppScope.playerOf(context).setExpanded(false);
    setState(() {
      _mobileAdminDrawerOpen = false;
      _destination = AppDestination.pluginPage;
      _bookId = null;
      _bookInitialChapterId = null;
      _seriesId = null;
      _playlistId = null;
      _aboutBackendVersion = null;
      _activePluginPage = extension;
      _activePluginLogs = null;
    });
  }

  void _openAbout(String? backendVersion) {
    setState(() {
      _mobileAdminDrawerOpen = false;
      _destination = AppDestination.about;
      _bookId = null;
      _bookInitialChapterId = null;
      _seriesId = null;
      _playlistId = null;
      _aboutBackendVersion = backendVersion;
      _activePluginPage = null;
    });
  }

  void _openMobileAdminDrawer() {
    setState(() => _mobileAdminDrawerOpen = true);
  }

  void _closeMobileAdminDrawer() {
    if (_mobileAdminDrawerOpen) {
      setState(() => _mobileAdminDrawerOpen = false);
    }
  }

  void _openBook(String id) {
    setState(() {
      _bookId = id;
      _bookInitialChapterId = null;
      _seriesId = null;
      _playlistId = null;
      _activePluginPage = null;
    });
  }

  void _openBookAtChapter(String id, String? chapterId) {
    setState(() {
      _bookId = id;
      _bookInitialChapterId = chapterId;
      _seriesId = null;
      _playlistId = null;
      _activePluginPage = null;
    });
  }

  void _openSeries(String id) {
    setState(() {
      _seriesId = id;
      _bookId = null;
      _bookInitialChapterId = null;
      _playlistId = null;
      _activePluginPage = null;
    });
  }

  void _openPlaylist(String id) {
    setState(() {
      _playlistId = id;
      _bookId = null;
      _bookInitialChapterId = null;
      _seriesId = null;
      _activePluginPage = null;
    });
  }

  void _openSearch(AppDestination origin) {
    _searchOrigin = origin;
    _go(AppDestination.search);
  }

  void _backFromDetail() {
    setState(() {
      _bookId = null;
      _bookInitialChapterId = null;
      _seriesId = null;
      _playlistId = null;
    });
  }

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
    if (_bookId != null || _seriesId != null || _playlistId != null) {
      _backFromDetail();
      return true;
    }
    final destination = _backDestinationFor(_destination);
    if (destination != null) {
      _go(destination);
      return true;
    }
    return false;
  }

  AppDestination? _backDestinationFor(AppDestination destination) {
    return switch (destination) {
      AppDestination.home => null,
      AppDestination.bookshelf ||
      AppDestination.playlists ||
      AppDestination.mine ||
      AppDestination.libraries ||
      AppDestination.plugins ||
      AppDestination.logs ||
      AppDestination.users =>
        AppDestination.home,
      AppDestination.pluginLogs => AppDestination.plugins,
      AppDestination.pluginPage => AppDestination.home,
      AppDestination.downloads => AppDestination.mine,
      AppDestination.search => _searchOrigin,
      AppDestination.favorites ||
      AppDestination.history ||
      AppDestination.personalization ||
      AppDestination.fnConnect ||
      AppDestination.notifications ||
      AppDestination.statistics ||
      AppDestination.about =>
        AppDestination.mine,
    };
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        if (appState.connectionError != null) {
          return _ConnectionScreen(
            message: appState.connectionError!,
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
              final navDestination = _bookId != null || _seriesId != null
                  ? AppDestination.bookshelf
                  : _playlistId != null
                      ? AppDestination.playlists
                      : _destination == AppDestination.pluginLogs
                          ? AppDestination.plugins
                          : _destination;
              return AnimatedBuilder(
                animation: AppScope.playerOf(context),
                builder: (context, _) {
                  final player = AppScope.playerOf(context);
                  final bottomInset = MediaQuery.of(context).padding.bottom;
                  final collapsedMini = player.isMiniCollapsed;
                  final showMiniPlayer = player.hasChapter &&
                      !player.isExpanded &&
                      !_hidesMiniPlayer(navDestination);
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
    if (AppScope.appOf(context).offlineMode) {
      return const DownloadsPage();
    }
    if (_bookId != null) {
      return BookDetailPage(
        bookId: _bookId!,
        initialChapterId: _bookInitialChapterId,
        onBack: _backFromDetail,
      );
    }
    if (_playlistId != null) {
      return PlaylistDetailPage(
        playlistId: _playlistId!,
        onBack: () => _go(AppDestination.playlists),
        openBook: _openBook,
        openSeries: _openSeries,
      );
    }
    if (_seriesId != null) {
      return SeriesDetailPage(
        seriesId: _seriesId!,
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
                          _NavTile(
                            icon: Icons.home_rounded,
                            label: l10n.navHome,
                            selected: current == AppDestination.home,
                            collapsed: collapsed,
                            onTap: () => go(AppDestination.home),
                          ),
                          _NavTile(
                            icon: Icons.library_books_rounded,
                            label: l10n.navBookshelf,
                            selected: current == AppDestination.bookshelf ||
                                current == AppDestination.search,
                            collapsed: collapsed,
                            onTap: () => go(AppDestination.bookshelf),
                          ),
                          _NavTile(
                            icon: Icons.playlist_play_rounded,
                            label: l10n.navPlaylists,
                            selected: current == AppDestination.playlists,
                            collapsed: collapsed,
                            onTap: () => go(AppDestination.playlists),
                          ),
                          _NavTile(
                            icon: Icons.person_rounded,
                            label: l10n.navMine,
                            selected: _isMineDestination(current),
                            collapsed: collapsed,
                            onTap: () => go(AppDestination.mine),
                          ),
                          if (appState.isAdmin) ...[
                            const SizedBox(height: 32),
                            _GroupLabel(
                              l10n.navAdmin,
                              collapsed: collapsed,
                            ),
                            _NavTile(
                              icon: Icons.storage_rounded,
                              label: l10n.navLibraries,
                              selected: current == AppDestination.libraries,
                              collapsed: collapsed,
                              onTap: () => go(AppDestination.libraries),
                            ),
                            _NavTile(
                              icon: Icons.extension_rounded,
                              label: l10n.navPlugins,
                              selected: current == AppDestination.plugins,
                              collapsed: collapsed,
                              onTap: () => go(AppDestination.plugins),
                            ),
                            _NavTile(
                              icon: Icons.terminal_rounded,
                              label: l10n.navLogs,
                              selected: current == AppDestination.logs,
                              collapsed: collapsed,
                              onTap: () => go(AppDestination.logs),
                            ),
                            _NavTile(
                              icon: Icons.group_rounded,
                              label: l10n.navUsers,
                              selected: current == AppDestination.users,
                              collapsed: collapsed,
                              onTap: () => go(AppDestination.users),
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

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.openMenu});

  final VoidCallback openMenu;

  @override
  Widget build(BuildContext context) {
    final headerColor = Color.alphaBlend(
      context.cardColor.withValues(alpha: 0.92),
      Theme.of(context).scaffoldBackgroundColor,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: headerColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: ColoredBox(
        color: headerColor,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: headerColor,
              border: Border(bottom: BorderSide(color: context.faintBorder)),
            ),
            child: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 36, height: 36),
                const SizedBox(width: 10),
                const Text(
                  'Ting Reader',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: openMenu,
                  icon: const Icon(Icons.menu_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileAdminOverlay extends StatelessWidget {
  const _MobileAdminOverlay({
    required this.go,
    required this.current,
    required this.onClose,
    required this.pluginPages,
    required this.activePluginPageId,
    required this.onOpenPluginPage,
  });

  final ValueChanged<AppDestination> go;
  final AppDestination current;
  final VoidCallback onClose;
  final List<ClientExtensionDescriptor> pluginPages;
  final String? activePluginPageId;
  final ValueChanged<ClientExtensionDescriptor> onOpenPluginPage;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: Container(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.46),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _MobileDrawer(
              go: go,
              current: current,
              onClose: onClose,
              pluginPages: pluginPages,
              activePluginPageId: activePluginPageId,
              onOpenPluginPage: onOpenPluginPage,
            ),
          ),
          Positioned(
            right: 22,
            top: topInset + 12,
            child: Material(
              color: context.cardColor.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: context.localeText('关闭', 'Close'),
                icon: Icon(
                  Icons.close_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: onClose,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({
    required this.go,
    required this.current,
    required this.onClose,
    required this.pluginPages,
    required this.activePluginPageId,
    required this.onOpenPluginPage,
  });

  final ValueChanged<AppDestination> go;
  final AppDestination current;
  final VoidCallback onClose;
  final List<ClientExtensionDescriptor> pluginPages;
  final String? activePluginPageId;
  final ValueChanged<ClientExtensionDescriptor> onOpenPluginPage;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final user = appState.user;
    final width = _drawerWidthFor(context);
    final l10n = context.l10n;
    if (appState.offlineMode) {
      return Drawer(
        width: width,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GroupLabel(l10n.navOfflineMode),
                _MobileAdminTile(
                  icon: Icons.download_done_rounded,
                  label: l10n.navDownloads,
                  selected: true,
                  onTap: () {
                    onClose();
                    go(AppDestination.downloads);
                  },
                ),
                const Spacer(),
                _DrawerAccountCard(
                  user: user,
                  roleLabel: 'OFFLINE',
                  onLogout: () async {
                    onClose();
                    await appState.logout();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Drawer(
      width: width,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (appState.isAdmin) ...[
                      _GroupLabel(l10n.navAdmin),
                      _MobileAdminTile(
                        icon: Icons.storage_rounded,
                        label: l10n.navLibraries,
                        selected: current == AppDestination.libraries,
                        onTap: () {
                          onClose();
                          go(AppDestination.libraries);
                        },
                      ),
                      _MobileAdminTile(
                        icon: Icons.extension_rounded,
                        label: l10n.navPlugins,
                        selected: current == AppDestination.plugins,
                        onTap: () {
                          onClose();
                          go(AppDestination.plugins);
                        },
                      ),
                      _MobileAdminTile(
                        icon: Icons.terminal_rounded,
                        label: l10n.navLogs,
                        selected: current == AppDestination.logs,
                        onTap: () {
                          onClose();
                          go(AppDestination.logs);
                        },
                      ),
                      _MobileAdminTile(
                        icon: Icons.group_rounded,
                        label: l10n.navUsers,
                        selected: current == AppDestination.users,
                        onTap: () {
                          onClose();
                          go(AppDestination.users);
                        },
                      ),
                    ],
                    if (pluginPages.isNotEmpty) ...[
                      if (appState.isAdmin) const SizedBox(height: 22),
                      _GroupLabel(l10n.navPluginPages),
                      for (final extension in pluginPages)
                        _MobilePluginTile(
                          extension: extension,
                          selected: current == AppDestination.pluginPage &&
                              activePluginPageId == extension.id,
                          onTap: () {
                            onClose();
                            onOpenPluginPage(extension);
                          },
                        ),
                    ],
                    if (!appState.isAdmin && pluginPages.isEmpty)
                      EmptyState(
                        icon: Icons.admin_panel_settings_outlined,
                        title: l10n.navNoAdminEntry,
                        message: l10n.navMainMenuInBottom,
                      ),
                  ],
                ),
              ),
              _DrawerAccountCard(
                user: user,
                roleLabel: user?.isAdmin == true ? 'ADMINISTRATOR' : 'USER',
                onLogout: () async {
                  onClose();
                  await appState.logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _drawerWidthFor(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth < 392) {
      return screenWidth * 0.92;
    }
    return 360;
  }
}

class _MobileAdminTile extends StatelessWidget {
  const _MobileAdminTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.primary600 : Colors.transparent,
        elevation: selected ? 8 : 0,
        shadowColor: AppColors.primary500.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: selected ? Colors.white : context.mutedText,
                ),
                const SizedBox(width: 18),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : context.mutedText,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobilePluginTile extends StatelessWidget {
  const _MobilePluginTile({
    required this.extension,
    required this.selected,
    required this.onTap,
  });

  final ClientExtensionDescriptor extension;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : context.mutedText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.primary600 : Colors.transparent,
        elevation: selected ? 8 : 0,
        shadowColor: AppColors.primary500.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                PluginExtensionIcon(
                  extension: extension,
                  size: 24,
                  color: foreground,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    extension.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerAccountCard extends StatelessWidget {
  const _DrawerAccountCard({
    required this.user,
    required this.roleLabel,
    required this.onLogout,
  });

  final dynamic user;
  final String roleLabel;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final username = (user?.username as String?) ?? '';
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.faintBorder)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.isDark
              ? AppColors.slate800.withValues(alpha: 0.55)
              : AppColors.slate50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary100,
              foregroundColor: AppColors.primary700,
              child: Text(
                username.isNotEmpty
                    ? username.substring(0, 1).toUpperCase()
                    : 'U',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
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
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.current,
    required this.go,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> go;

  @override
  Widget build(BuildContext context) {
    final offline = AppScope.appOf(context).offlineMode;
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: context.cardColor.withValues(alpha: 0.94),
          border: Border(top: BorderSide(color: context.faintBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            _BottomItem(
              icon: Icons.home_rounded,
              label: l10n.navHome,
              selected: current == AppDestination.home,
              onTap: offline ? null : () => go(AppDestination.home),
            ),
            _BottomItem(
              icon: Icons.library_books_rounded,
              label: l10n.navBookshelf,
              selected: current == AppDestination.bookshelf ||
                  current == AppDestination.search,
              onTap: offline ? null : () => go(AppDestination.bookshelf),
            ),
            if (offline)
              _BottomItem(
                icon: Icons.download_done_rounded,
                label: l10n.navDownloads,
                selected: true,
                onTap: () => go(AppDestination.downloads),
              ),
            if (!offline)
              _BottomItem(
                icon: Icons.playlist_play_rounded,
                label: l10n.navPlaylists,
                selected: current == AppDestination.playlists,
                onTap: () => go(AppDestination.playlists),
              ),
            if (!offline)
              _BottomItem(
                icon: Icons.person_rounded,
                label: l10n.navMine,
                selected: _isMineDestination(current),
                onTap: () => go(AppDestination.mine),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: disabled ? 0.38 : 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary50 : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: selected ? AppColors.primary600 : context.mutedText,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary600 : context.mutedText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
