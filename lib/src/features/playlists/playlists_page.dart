import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/locale.dart';
import '../../core/utils/urls.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';
import '../../shared/filter/display_filter_menu.dart';

part 'playlist_cover_grid.dart';
part 'playlist_detail_page.dart';
part 'playlist_selection_widgets.dart';
part 'playlist_widgets.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({
    super.key,
    required this.openPlaylist,
    required this.onBack,
  });

  final ValueChanged<String> openPlaylist;
  final VoidCallback onBack;

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  bool _loading = true;
  List<Playlist> _playlists = [];
  String _query = '';
  String _sortBy = 'updated_at';
  IconSizeSetting _iconSize = IconSizeSetting.medium;
  int _playlistCoverSeed = DateTime.now().microsecondsSinceEpoch;
  final LayerLink _filterMenuLink = LayerLink();
  OverlayEntry? _filterOverlay;
  bool _showFilterMenu = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filterOverlay?.remove();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final appState = AppScope.appOf(context);
      final settings = asMap(appState.settings['settings_json']);
      final res = await appState.api.get('/api/playlists');
      setState(() {
        _playlists = asMapList(res.data).map(Playlist.fromJson).toList();
        _playlistCoverSeed = DateTime.now().microsecondsSinceEpoch;
        _sortBy = _normalizePlaylistSortBy(
          (settings['playlist_sort_by'] ??
                  appState.settings['playlist_sort_by'] ??
                  _sortBy)
              .toString(),
        );
        _iconSize = iconSizeFromString(
          (settings['playlist_icon_size'] ??
                  appState.settings['playlist_icon_size'])
              ?.toString(),
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final api = AppScope.appOf(context).api;
    final created = await _showPlaylistInfoDialog(context);
    if (created == null) return;
    final res = await api.post(
      '/api/playlists',
      data: created,
    );
    final playlist = Playlist.fromJson(asMap(res.data));
    await _load();
    widget.openPlaylist(playlist.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final keyword = _query.trim().toLowerCase();
    final visiblePlaylists = keyword.isEmpty
        ? _playlists
        : _playlists.where((playlist) {
            final text = [
              playlist.title,
              playlist.description ?? '',
              for (final item in playlist.effectiveItems)
                if (item.itemType == 'series')
                  '${item.series?.title ?? ''} ${item.series?.author ?? ''}'
                else
                  '${item.book?.title ?? ''} ${item.book?.author ?? ''} ${item.book?.narrator ?? ''}',
            ].join(' ').toLowerCase();
            return text.contains(keyword);
          }).toList();
    _sortPlaylists(visiblePlaylists);
    return PageListView(
      onRefresh: _load,
      children: [
        PageHeaderRow(
          icon: Icons.playlist_play_rounded,
          title: context.localeText('我的书单', 'Playlists'),
          subtitle: context.localeText(
            '按通勤、睡前、专题整理你的听书队列。',
            'Organize your listening queue for commutes, bedtime, and topics.',
          ),
          action: PrimaryButton(
            label: context.localeText('新建书单', 'New Playlist'),
            icon: Icons.add_rounded,
            onPressed: _create,
          ),
        ),
        const SizedBox(height: 24),
        if (_playlists.isEmpty)
          EmptyState(
            icon: Icons.playlist_add_rounded,
            title: context.localeText('还没有书单', 'No Playlists Yet'),
            message: context.localeText(
              '创建一个书单，把想听的书籍和系列放在一起。',
              'Create a playlist to collect books and series you want to hear.',
            ),
            action: PrimaryButton(
              label: context.localeText('新建书单', 'New Playlist'),
              icon: Icons.add_rounded,
              onPressed: _create,
            ),
          )
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;
              final searchBox = _PlaylistSearchBox(
                hint: context.localeText(
                  '搜索书单名称或描述',
                  'Search playlist name or description',
                ),
                onChanged: (value) => setState(() => _query = value),
              );
              final filterButton = CompositedTransformTarget(
                link: _filterMenuLink,
                child: _PlaylistFilterButton(
                  active: _showFilterMenu,
                  onPressed: _toggleFilterMenu,
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchBox,
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: filterButton,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: searchBox),
                  const SizedBox(width: 12),
                  filterButton,
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          if (visiblePlaylists.isEmpty)
            EmptyState(
              icon: Icons.search_off_rounded,
              title: context.localeText('没有匹配的书单', 'No Matching Playlists'),
              message: context.localeText('换个关键词试试。', 'Try another keyword.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final mobile = constraints.maxWidth < 640;
                final spacing = _playlistGridGap(_iconSize);
                final minCardWidth = mobile
                    ? _playlistMobileCardMinWidth(_iconSize)
                    : _playlistDesktopCardWidth(_iconSize);
                final possibleColumns = math.max(
                  1,
                  ((constraints.maxWidth + spacing) / (minCardWidth + spacing))
                      .floor(),
                );
                final columns = mobile
                    ? math.max(
                        1,
                        math.min(possibleColumns, visiblePlaylists.length),
                      )
                    : possibleColumns;
                final width = mobile
                    ? (constraints.maxWidth - spacing * (columns - 1)) / columns
                    : math.min(minCardWidth, constraints.maxWidth);
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final playlist in visiblePlaylists)
                      SizedBox(
                        width: width,
                        child: _PlaylistCard(
                          playlist: playlist,
                          iconSize: _iconSize,
                          coverSeed: _playlistCoverSeed,
                          compactOnMobile: mobile,
                          onTap: () => widget.openPlaylist(playlist.id),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
        const SafeBottomSpacer(),
      ],
    );
  }

  void _sortPlaylists(List<Playlist> playlists) {
    switch (_sortBy) {
      case 'title':
        playlists.sort((a, b) => compareChineseText(a.title, b.title));
        break;
      case 'count':
        playlists.sort(
          (a, b) => _playlistBookCount(b).compareTo(_playlistBookCount(a)),
        );
        break;
      case 'updated_at':
      case 'created_at':
        playlists.sort((a, b) {
          final at = DateTime.tryParse(a.updatedAt ?? a.createdAt ?? '') ??
              DateTime(1970);
          final bt = DateTime.tryParse(b.updatedAt ?? b.createdAt ?? '') ??
              DateTime(1970);
          return bt.compareTo(at);
        });
        break;
    }
  }

  void _toggleFilterMenu() {
    if (_filterOverlay != null) {
      _closeFilterMenu();
      return;
    }
    setState(() => _showFilterMenu = true);
    _filterOverlay = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closeFilterMenu,
                ),
              ),
              CompositedTransformFollower(
                link: _filterMenuLink,
                showWhenUnlinked: false,
                offset: const Offset(-176, 54),
                child: DisplayFilterMenu(
                  sortBy: _sortBy,
                  sortOptions: [
                    DisplayFilterSortOption(
                      value: 'updated_at',
                      label: context.localeText('最近更新', 'Recently Updated'),
                    ),
                    DisplayFilterSortOption(
                      value: 'title',
                      label: context.localeText('书单名称', 'Playlist Name'),
                    ),
                    DisplayFilterSortOption(
                      value: 'count',
                      label: context.localeText('作品数量', 'Item Count'),
                    ),
                  ],
                  iconSize: _iconSize,
                  onSortChanged: _setSortBy,
                  onIconSizeChanged: _setIconSize,
                ),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context).insert(_filterOverlay!);
  }

  void _closeFilterMenu() {
    _filterOverlay?.remove();
    _filterOverlay = null;
    if (mounted && _showFilterMenu) {
      setState(() => _showFilterMenu = false);
    }
  }

  Future<void> _setSortBy(String value) async {
    final normalized = _normalizePlaylistSortBy(value);
    _closeFilterMenu();
    setState(() => _sortBy = normalized);
    await AppScope.appOf(context)
        .updateSettings({'playlist_sort_by': normalized});
  }

  Future<void> _setIconSize(IconSizeSetting value) async {
    final raw = switch (value) {
      IconSizeSetting.small => 'small',
      IconSizeSetting.medium => 'medium',
      IconSizeSetting.large => 'large',
    };
    _closeFilterMenu();
    setState(() => _iconSize = value);
    await AppScope.appOf(context).updateSettings({'playlist_icon_size': raw});
  }

  String _normalizePlaylistSortBy(String value) {
    return switch (value) {
      'title' || 'count' || 'updated_at' => value,
      'created_at' => 'updated_at',
      _ => 'updated_at',
    };
  }

  double _playlistGridGap(IconSizeSetting size) {
    return switch (size) {
      IconSizeSetting.small => 12,
      IconSizeSetting.medium => 16,
      IconSizeSetting.large => 24,
    };
  }

  double _playlistDesktopCardWidth(IconSizeSetting size) {
    return switch (size) {
      IconSizeSetting.small => 170,
      IconSizeSetting.medium => 300,
      IconSizeSetting.large => 440,
    };
  }

  double _playlistMobileCardMinWidth(IconSizeSetting size) {
    return switch (size) {
      IconSizeSetting.small => 132,
      IconSizeSetting.medium => 156,
      IconSizeSetting.large => 180,
    };
  }
}

int _playlistBookCount(Playlist playlist) {
  return playlist.effectiveItems.fold<int>(
    0,
    (total, item) =>
        total +
        (item.itemType == 'series' ? item.series?.books.length ?? 0 : 1),
  );
}
