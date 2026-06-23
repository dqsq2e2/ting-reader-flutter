import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../book_detail/book_detail_page.dart';
import '../bookshelf/bookshelf_page.dart';
import '../downloads/downloads_page.dart';
import '../favorites/favorites_page.dart';
import '../home/home_page.dart';
import '../admin/users/admin_users_page.dart';
import '../admin/management/management_pages.dart';
import '../search/search_page.dart';
import '../series_detail/series_detail_page.dart';
import '../settings/settings_page.dart';
import '../mine/user_pages.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/app_scope.dart';
import '../../shared/common/common_widgets.dart';
import '../player/mini_player.dart';

enum AppDestination {
  home,
  bookshelf,
  search,
  favorites,
  mine,
  history,
  playlists,
  personalization,
  notifications,
  statistics,
  downloads,
  settings,
  libraries,
  plugins,
  logs,
  users,
}

bool _isMineDestination(AppDestination destination) {
  return switch (destination) {
    AppDestination.mine ||
    AppDestination.history ||
    AppDestination.favorites ||
    AppDestination.personalization ||
    AppDestination.notifications ||
    AppDestination.statistics =>
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
  String? _seriesId;
  String? _playlistId;
  bool _mobileAdminDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    final params = Uri.base.queryParameters;
    _destination = _destinationFromQuery(params['page']);
    _bookId = params['book'];
    _seriesId = params['series'];
    _playlistId = params['playlist'];
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
      case 'notifications':
        return AppDestination.notifications;
      case 'statistics':
        return AppDestination.statistics;
      case 'downloads':
        return AppDestination.downloads;
      case 'libraries':
        return AppDestination.libraries;
      case 'plugins':
        return AppDestination.plugins;
      case 'logs':
        return AppDestination.logs;
      case 'users':
        return AppDestination.users;
      default:
        return AppDestination.home;
    }
  }

  void _go(AppDestination destination) {
    setState(() {
      _mobileAdminDrawerOpen = false;
      _destination = destination;
      _bookId = null;
      _seriesId = null;
      _playlistId = null;
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
      _seriesId = null;
      _playlistId = null;
    });
  }

  void _openSeries(String id) {
    setState(() {
      _seriesId = id;
      _bookId = null;
      _playlistId = null;
    });
  }

  void _openPlaylist(String id) {
    setState(() {
      _playlistId = id;
      _bookId = null;
      _seriesId = null;
    });
  }

  void _backFromDetail() {
    setState(() {
      _bookId = null;
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
      AppDestination.downloads => AppDestination.mine,
      AppDestination.search => AppDestination.bookshelf,
      AppDestination.favorites ||
      AppDestination.history ||
      AppDestination.personalization ||
      AppDestination.notifications ||
      AppDestination.statistics ||
      AppDestination.settings =>
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
              final navDestination = _bookId != null || _seriesId != null
                  ? AppDestination.bookshelf
                  : _playlistId != null
                      ? AppDestination.playlists
                      : _destination;
              return AnimatedBuilder(
                animation: AppScope.playerOf(context),
                builder: (context, _) {
                  final player = AppScope.playerOf(context);
                  final bottomInset = MediaQuery.of(context).padding.bottom;
                  final collapsedMini = player.isMiniCollapsed;
                  return Stack(
                    children: [
                      Scaffold(
                        body: Row(
                          children: [
                            if (desktop)
                              _DesktopSidebar(go: _go, current: navDestination),
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
                      if (player.hasChapter && !player.isExpanded)
                        Positioned(
                          left: desktop ? 308 : (collapsedMini ? 24 : 12),
                          right: collapsedMini ? null : (desktop ? 20 : 12),
                          bottom: desktop
                              ? 20
                              : 64 + bottomInset + (collapsedMini ? 20 : 0),
                          child: const MiniPlayer(),
                        ),
                      if (!desktop && _mobileAdminDrawerOpen)
                        Positioned.fill(
                          child: _MobileAdminOverlay(
                            go: _go,
                            current: navDestination,
                            onClose: _closeMobileAdminDrawer,
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
      return BookDetailPage(bookId: _bookId!, onBack: _backFromDetail);
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
          openSearch: () => _go(AppDestination.search),
          openPlaylists: () => _go(AppDestination.playlists),
        );
      case AppDestination.bookshelf:
        return BookshelfPage(
          openBook: _openBook,
          openSeries: _openSeries,
          openLibraries: () => _go(AppDestination.libraries),
          openSearch: () => _go(AppDestination.search),
        );
      case AppDestination.search:
        return SearchPage(
          openBook: _openBook,
          onBack: () => _go(AppDestination.bookshelf),
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
          openNotifications: () => _go(AppDestination.notifications),
          openStatistics: () => _go(AppDestination.statistics),
          openBook: _openBook,
        );
      case AppDestination.history:
        return HistoryPage(
          openBook: _openBook,
          onBack: () => _go(AppDestination.mine),
          openBookshelf: () => _go(AppDestination.bookshelf),
        );
      case AppDestination.playlists:
        return MyPlaylistsPage(
          openPlaylist: _openPlaylist,
          onBack: () => _go(AppDestination.home),
        );
      case AppDestination.personalization:
        return SettingsPage(
          openDownloads: () => _go(AppDestination.downloads),
          onBack: () => _go(AppDestination.mine),
        );
      case AppDestination.notifications:
        return NotificationSettingsPage(onBack: () => _go(AppDestination.mine));
      case AppDestination.statistics:
        return AdminStatisticsPage(onBack: () => _go(AppDestination.mine));
      case AppDestination.downloads:
        return DownloadsPage(onBack: () => _go(AppDestination.mine));
      case AppDestination.settings:
        return SettingsPage(openDownloads: () => _go(AppDestination.downloads));
      case AppDestination.libraries:
        return const AdminLibrariesPage();
      case AppDestination.plugins:
        return const PluginsPage();
      case AppDestination.logs:
        return const LogsPage();
      case AppDestination.users:
        return const AdminUsersV2Page();
    }
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.go,
    required this.current,
  });

  final ValueChanged<AppDestination> go;
  final AppDestination current;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final user = appState.user;
    if (appState.offlineMode) {
      return Container(
        width: 288,
        decoration: BoxDecoration(
          color: context.cardColor,
          border: Border(right: BorderSide(color: context.faintBorder)),
        ),
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                  child: Row(
                    children: [
                      Image.asset('assets/images/logo.png',
                          width: 40, height: 40),
                      const SizedBox(width: 12),
                      const Text(
                        'Ting Reader',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const _GroupLabel('离线模式'),
                _NavTile(
                  icon: Icons.download_done_rounded,
                  label: '下载',
                  selected: true,
                  onTap: () => go(AppDestination.downloads),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: appState.logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('返回登录'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(right: BorderSide(color: context.faintBorder)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                child: Row(
                  children: [
                    Image.asset('assets/images/logo.png',
                        width: 40, height: 40),
                    const SizedBox(width: 12),
                    const Text(
                      'Ting Reader',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const _GroupLabel('主菜单'),
              _NavTile(
                icon: Icons.home_rounded,
                label: '首页',
                selected: current == AppDestination.home,
                onTap: () => go(AppDestination.home),
              ),
              _NavTile(
                icon: Icons.library_books_rounded,
                label: '书架',
                selected: current == AppDestination.bookshelf ||
                    current == AppDestination.search,
                onTap: () => go(AppDestination.bookshelf),
              ),
              _NavTile(
                icon: Icons.playlist_play_rounded,
                label: '书单',
                selected: current == AppDestination.playlists,
                onTap: () => go(AppDestination.playlists),
              ),
              _NavTile(
                icon: Icons.person_rounded,
                label: '我的',
                selected: _isMineDestination(current),
                onTap: () => go(AppDestination.mine),
              ),
              const SizedBox(height: 28),
              const _GroupLabel('管理后台'),
              if (appState.isAdmin) ...[
                _NavTile(
                  icon: Icons.storage_rounded,
                  label: '库管理',
                  selected: current == AppDestination.libraries,
                  onTap: () => go(AppDestination.libraries),
                ),
                _NavTile(
                  icon: Icons.extension_rounded,
                  label: '插件管理',
                  selected: current == AppDestination.plugins,
                  onTap: () => go(AppDestination.plugins),
                ),
                _NavTile(
                  icon: Icons.terminal_rounded,
                  label: '系统日志',
                  selected: current == AppDestination.logs,
                  onTap: () => go(AppDestination.logs),
                ),
                _NavTile(
                  icon: Icons.group_rounded,
                  label: '用户管理',
                  selected: current == AppDestination.users,
                  onTap: () => go(AppDestination.users),
                ),
              ],
              const Spacer(),
              Container(
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
                        (user?.username.isNotEmpty ?? false)
                            ? user!.username.substring(0, 1).toUpperCase()
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
                            user?.username ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            user?.isAdmin == true ? 'ADMINISTRATOR' : 'USER',
                            style: TextStyle(
                              color: context.mutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '退出登录',
                      onPressed: appState.logout,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
  });

  final ValueChanged<AppDestination> go;
  final AppDestination current;
  final VoidCallback onClose;

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
            ),
          ),
          Positioned(
            right: 22,
            top: topInset + 12,
            child: Material(
              color: context.cardColor.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: '关闭',
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
  });

  final ValueChanged<AppDestination> go;
  final AppDestination current;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final user = appState.user;
    final width = _drawerWidthFor(context);
    if (appState.offlineMode) {
      return Drawer(
        width: width,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _GroupLabel('离线模式'),
                _MobileAdminTile(
                  icon: Icons.download_done_rounded,
                  label: '下载',
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
                      const _GroupLabel('管理后台'),
                      _MobileAdminTile(
                        icon: Icons.storage_rounded,
                        label: '库管理',
                        selected: current == AppDestination.libraries,
                        onTap: () {
                          onClose();
                          go(AppDestination.libraries);
                        },
                      ),
                      _MobileAdminTile(
                        icon: Icons.extension_rounded,
                        label: '插件管理',
                        selected: current == AppDestination.plugins,
                        onTap: () {
                          onClose();
                          go(AppDestination.plugins);
                        },
                      ),
                      _MobileAdminTile(
                        icon: Icons.terminal_rounded,
                        label: '系统日志',
                        selected: current == AppDestination.logs,
                        onTap: () {
                          onClose();
                          go(AppDestination.logs);
                        },
                      ),
                      _MobileAdminTile(
                        icon: Icons.group_rounded,
                        label: '用户管理',
                        selected: current == AppDestination.users,
                        onTap: () {
                          onClose();
                          go(AppDestination.users);
                        },
                      ),
                    ] else
                      const EmptyState(
                        icon: Icons.admin_panel_settings_outlined,
                        title: '没有后台入口',
                        message: '主菜单已在底部导航中。',
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
              tooltip: '退出登录',
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
              label: '首页',
              selected: current == AppDestination.home,
              onTap: offline ? null : () => go(AppDestination.home),
            ),
            _BottomItem(
              icon: Icons.library_books_rounded,
              label: '书架',
              selected: current == AppDestination.bookshelf ||
                  current == AppDestination.search,
              onTap: offline ? null : () => go(AppDestination.bookshelf),
            ),
            if (offline)
              _BottomItem(
                icon: Icons.download_done_rounded,
                label: '下载',
                selected: true,
                onTap: () => go(AppDestination.downloads),
              ),
            if (!offline)
              _BottomItem(
                icon: Icons.playlist_play_rounded,
                label: '书单',
                selected: current == AppDestination.playlists,
                onTap: () => go(AppDestination.playlists),
              ),
            if (!offline)
              _BottomItem(
                icon: Icons.person_rounded,
                label: '我的',
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
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.primary600 : Colors.transparent,
        elevation: selected ? 8 : 0,
        shadowColor: AppColors.primary500.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : context.mutedText,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : context.mutedText,
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

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      '连接失败',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
                      label: '重试连接',
                      icon: Icons.refresh_rounded,
                      onPressed: onRetry,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onLogout,
                      child: const Text('退出登录'),
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
