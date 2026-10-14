import '../models/models.dart';
import '../plugin_extensions/types.dart';

enum AppDestination {
  home,
  bookshelf,
  search,
  favorites,
  mine,
  history,
  bookmarks,
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

enum DetailDestination { book, series, playlist }

/// Shell routing rules. A detail route has exactly one kind and identifier,
/// so opening a book cannot leave a series or playlist route active.
class ShellNavigation {
  ShellNavigation();

  factory ShellNavigation.fromQuery(Map<String, String> query) {
    final state = ShellNavigation();
    state.destination = switch (query['page']) {
      'settings' => AppDestination.personalization,
      'fn-connect' => AppDestination.fnConnect,
      'plugin-page' => AppDestination.pluginPage,
      final name =>
        AppDestination.values.where((item) => item.name == name).firstOrNull ??
            AppDestination.home,
    };
    state.initialPluginId = query['plugin'];
    state.initialCapabilityId = query['capability'];
    final book = query['book'];
    final series = query['series'];
    final playlist = query['playlist'];
    if (book != null && book.isNotEmpty) {
      state.openDetail(DetailDestination.book, book, chapter: query['chapter']);
    } else if (series != null && series.isNotEmpty) {
      state.openDetail(DetailDestination.series, series);
    } else if (playlist != null && playlist.isNotEmpty) {
      state.openDetail(DetailDestination.playlist, playlist);
    }
    return state;
  }

  AppDestination destination = AppDestination.home;
  AppDestination searchOrigin = AppDestination.bookshelf;
  ({DetailDestination kind, String id, String? chapter})? _detail;
  String? aboutBackendVersion;
  ClientExtensionDescriptor? activePluginPage;
  PluginItem? activePluginLogs;
  String? initialPluginId;
  String? initialCapabilityId;

  String? get bookId =>
      _detail?.kind == DetailDestination.book ? _detail?.id : null;
  String? get chapterId =>
      _detail?.kind == DetailDestination.book ? _detail?.chapter : null;
  String? get seriesId =>
      _detail?.kind == DetailDestination.series ? _detail?.id : null;
  String? get playlistId =>
      _detail?.kind == DetailDestination.playlist ? _detail?.id : null;
  bool get hasDetail => _detail != null;

  void go(AppDestination next) {
    destination = next;
    _detail = null;
    aboutBackendVersion = null;
    activePluginPage = null;
    activePluginLogs = null;
  }

  void openDetail(DetailDestination kind, String id, {String? chapter}) {
    _detail = (
      kind: kind,
      id: id,
      chapter: kind == DetailDestination.book ? chapter : null
    );
    activePluginPage = null;
    activePluginLogs = null;
  }

  void closeDetail() => _detail = null;

  void openPluginPage(ClientExtensionDescriptor extension) {
    go(AppDestination.pluginPage);
    activePluginPage = extension;
  }

  void openPluginLogs(PluginItem plugin) {
    go(AppDestination.pluginLogs);
    activePluginLogs = plugin;
  }

  void openAbout(String? version) {
    go(AppDestination.about);
    aboutBackendVersion = version;
  }

  void openSearch(AppDestination origin) {
    searchOrigin = origin;
    go(AppDestination.search);
  }

  AppDestination? get backDestination => switch (destination) {
        AppDestination.home => null,
        AppDestination.pluginLogs => AppDestination.plugins,
        AppDestination.search => searchOrigin,
        AppDestination.downloads ||
        AppDestination.favorites ||
        AppDestination.history ||
        AppDestination.bookmarks ||
        AppDestination.personalization ||
        AppDestination.fnConnect ||
        AppDestination.notifications ||
        AppDestination.statistics ||
        AppDestination.about =>
          AppDestination.mine,
        _ => AppDestination.home,
      };

  AppDestination get navDestination => switch (_detail?.kind) {
        DetailDestination.book ||
        DetailDestination.series =>
          AppDestination.bookshelf,
        DetailDestination.playlist => AppDestination.playlists,
        null => destination == AppDestination.pluginLogs
            ? AppDestination.plugins
            : destination,
      };
}

bool isMineDestination(AppDestination destination) => switch (destination) {
      AppDestination.mine ||
      AppDestination.history ||
      AppDestination.bookmarks ||
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

bool hidesMiniPlayer(AppDestination destination) => switch (destination) {
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
