import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/home_layout.dart';
import '../../core/utils/locale.dart';
import '../../core/utils/urls.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';

part 'home_hero.dart';
part 'home_sections.dart';
part 'home_models.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.openBook,
    required this.openBookshelf,
    required this.openHistory,
    required this.openSearch,
    required this.openPlaylists,
  });

  final ValueChanged<String> openBook;
  final VoidCallback openBookshelf;
  final VoidCallback openHistory;
  final VoidCallback openSearch;
  final VoidCallback openPlaylists;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  List<ProgressItem> _recent = [];
  List<Book> _books = [];
  List<Book> _favorites = [];
  List<Series> _series = [];
  List<Playlist> _playlists = [];
  int _playlistCoverSeed = DateTime.now().microsecondsSinceEpoch;
  String? _activeHeroId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final appState = AppScope.appOf(context);
    try {
      final results = await Future.wait([
        appState.api.get('/api/progress/recent'),
        appState.api.get('/api/books'),
        appState.api.get('/api/favorites'),
        appState.api.get('/api/v1/series'),
        appState.api.get('/api/playlists'),
      ]).timeout(const Duration(seconds: 45));
      if (!mounted) return;
      setState(() {
        _error = null;
        _recent =
            asMapList(results[0].data).map(ProgressItem.fromJson).toList();
        _books = asMapList(results[1].data).map(Book.fromJson).toList();
        _favorites = asMapList(results[2].data).map(Book.fromJson).toList();
        _series = asMapList(results[3].data).map(Series.fromJson).toList();
        _playlists = asMapList(results[4].data).map(Playlist.fromJson).toList();
        _playlistCoverSeed = DateTime.now().microsecondsSinceEpoch;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.localeText(
          '首页数据加载失败：${_shortError(error)}',
          'Failed to load home data: ${_shortError(error)}',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _shortError(Object error) {
    final text = error.toString();
    const dioPrefix = 'DioException [';
    if (text.startsWith(dioPrefix)) {
      return text.split('\n').first;
    }
    return text.replaceFirst('Exception: ', '');
  }

  List<Book> get _recentlyAdded {
    final list = [..._books];
    list.sort((a, b) {
      final ad = DateTime.tryParse(a.createdAt ?? '') ?? DateTime(1970);
      final bd = DateTime.tryParse(b.createdAt ?? '') ?? DateTime(1970);
      return bd.compareTo(ad);
    });
    return list.take(10).toList();
  }

  Map<String, Book> get _bookMap => {
        for (final book in _books)
          if (book.id.isNotEmpty) book.id: book,
      };

  List<ProgressItem> get _recentBookPlays {
    final map = <String, ProgressItem>{};
    for (final progress in _recent) {
      if (progress.bookId.isEmpty) continue;
      final existing = map[progress.bookId];
      if (existing == null ||
          _progressTime(progress).isAfter(_progressTime(existing))) {
        map[progress.bookId] = progress;
      }
    }
    final items = map.values.toList();
    items.sort((a, b) => _progressTime(b).compareTo(_progressTime(a)));
    return items;
  }

  DateTime _progressTime(ProgressItem item) {
    return DateTime.tryParse(item.updatedAt ?? '') ?? DateTime(1970);
  }

  List<_HeroItem> get _heroItems {
    final seen = <String>{};
    final items = <_HeroItem>[];
    final map = _bookMap;

    for (final progress in _recentBookPlays) {
      final book = map[progress.bookId];
      final id = book?.id ?? progress.bookId;
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      items.add(
        _HeroItem(
          id: id,
          title: book?.title ??
              progress.bookTitle ??
              context.localeText('未知书籍', 'Unknown Book'),
          subtitle: progress.chapterTitle?.isNotEmpty == true
              ? context.localeText(
                  '上次听到 ${progress.chapterTitle}',
                  'Last listened: ${progress.chapterTitle}',
                )
              : book?.author ?? context.localeText('继续收听', 'Continue'),
          description: _inlineDescription(
            book?.description,
            context.localeText(
              '继续从上次的位置开始，接上你的听书进度。',
              'Resume from where you left off.',
            ),
          ),
          coverUrl: book?.coverUrl ?? progress.coverUrl,
          libraryId: book?.libraryId ?? progress.libraryId,
          book: book,
          progress: progress,
        ),
      );
    }

    for (final book in [..._favorites, ..._recentlyAdded]) {
      if (book.id.isEmpty || seen.contains(book.id)) continue;
      seen.add(book.id);
      items.add(
        _HeroItem(
          id: book.id,
          title: localizedBookTitle(context, book),
          subtitle: book.author?.isNotEmpty == true
              ? book.author!
              : context.localeText('今日推荐', 'Today Pick'),
          description: _inlineDescription(
            book.description,
            context.localeText(
              '从书架里挑一本作品，开启今天的听书时间。',
              'Pick a book from your shelf and start listening today.',
            ),
          ),
          coverUrl: book.coverUrl,
          libraryId: book.libraryId,
          book: book,
        ),
      );
    }
    return items.take(10).toList();
  }

  List<Book> get _recommendedBooks {
    final seen = <String>{};
    final source = <Book?>[
      _activeHero?.book,
      ..._favorites,
      ..._recentBookPlays.map((item) => _bookMap[item.bookId]),
      ..._recentlyAdded,
    ];
    return source
        .whereType<Book>()
        .where((book) {
          if (seen.contains(book.id)) return false;
          seen.add(book.id);
          return true;
        })
        .take(6)
        .toList();
  }

  _HeroItem? get _activeHero {
    final items = _heroItems;
    if (items.isEmpty) return null;
    return items.firstWhere(
      (item) => item.id == _activeHeroId,
      orElse: () => items.first,
    );
  }

  _HeroItem? get _nextHero {
    final items = _heroItems;
    final active = _activeHero;
    if (items.length <= 1 || active == null) return null;
    final index = items.indexWhere((item) => item.id == active.id);
    return items[(index + 1) % items.length];
  }

  int get _listenMinutes {
    final seconds = _recent.fold<double>(0, (sum, item) => sum + item.position);
    return (seconds / 60).round();
  }

  void _cycleHero() {
    final next = _nextHero;
    if (next == null) return;
    setState(() => _activeHeroId = next.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return Center(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: context.localeText('加载失败', 'Load Failed'),
          message: _error!,
          action: PrimaryButton(
            icon: Icons.refresh_rounded,
            label: context.localeText('重试', 'Retry'),
            onPressed: _load,
          ),
        ),
      );
    }

    final appState = AppScope.appOf(context);
    final coverShape = coverShapeFromAppSettings(appState.settings);
    final homeLayout = HomeLayoutSettings.fromSettings(appState.settings);

    return PageListView(
      onRefresh: _load,
      children: [
        _HomeHeader(onSearch: widget.openSearch),
        if (homeLayout.hasHeroArea) ...[
          const SizedBox(height: 28),
          _HeroSection(
            item: _activeHero,
            next: _nextHero,
            listenMinutes: _listenMinutes,
            favoritesCount: _favorites.length,
            playlistsCount: _playlists.length,
            recentCount: _recent.length,
            coverShape: coverShape,
            showHero: homeLayout.showHero,
            showStats: homeLayout.showStats,
            onCycle: _cycleHero,
            onPrimary: () {
              final item = _activeHero;
              if (item?.id.isNotEmpty == true) {
                widget.openBook(item!.id);
              } else {
                widget.openBookshelf();
              }
            },
            onPlaylists: widget.openPlaylists,
          ),
        ],
        if (homeLayout.showRecommended) ...[
          const SizedBox(height: 34),
          _SectionTitle(
            icon: Icons.auto_awesome_rounded,
            iconColor: Colors.amber,
            title: context.localeText('为你推荐', 'Recommended'),
            action: context.localeText('查看书架', 'Bookshelf'),
            onAction: widget.openBookshelf,
          ),
          const SizedBox(height: 16),
          _RecommendedShelf(
            books: _recommendedBooks,
            coverShape: coverShape,
            onBook: widget.openBook,
          ),
        ],
        if (homeLayout.showRecent) ...[
          const SizedBox(height: 34),
          _SectionTitle(
            icon: Icons.history_rounded,
            iconColor: AppColors.primary600,
            title: context.localeText('最近收听', 'Recently Listened'),
            action: context.localeText('查看历史', 'History'),
            onAction: widget.openHistory,
          ),
          const SizedBox(height: 16),
          if (_recentBookPlays.isEmpty)
            EmptyState(
              icon: Icons.play_arrow_rounded,
              title: context.localeText('暂无播放记录', 'No Playback Yet'),
              message: context.localeText(
                '去书架挑一本书，首页会记录你的听书节奏。',
                'Pick a book from the shelf and your rhythm will appear here.',
              ),
              action: PrimaryButton(
                label: context.localeText('去书架', 'Go to Bookshelf'),
                icon: Icons.library_books_rounded,
                onPressed: widget.openBookshelf,
              ),
            )
          else
            _RecentGrid(
              items: _recentBookPlays.take(4).toList(),
              coverShape: coverShape,
              onBook: widget.openBook,
            ),
        ],
        if (homeLayout.showRecentlyAdded) ...[
          const SizedBox(height: 34),
          _SectionTitle(
            icon: Icons.trending_up_rounded,
            iconColor: Colors.green,
            title: context.localeText('最近上新', 'Recently Added'),
            action: context.localeText('更多', 'More'),
            onAction: widget.openBookshelf,
          ),
          const SizedBox(height: 16),
          _RecentlyAddedGrid(
            books: _recentlyAdded.take(6).toList(),
            coverShape: coverShape,
            onBook: widget.openBook,
          ),
        ],
        if (homeLayout.showCollections) ...[
          const SizedBox(height: 34),
          _SectionTitle(
            icon: Icons.queue_music_rounded,
            iconColor: Colors.orange,
            title: context.localeText('书单与系列', 'Playlists & Series'),
            action: context.localeText('管理书单', 'Manage'),
            onAction: widget.openPlaylists,
          ),
          const SizedBox(height: 16),
          _CollectionsGrid(
            playlists: _playlists.take(4).toList(),
            series: _series.take(math.max(0, 4 - _playlists.length)).toList(),
            playlistCoverSeed: _playlistCoverSeed,
            onPlaylists: widget.openPlaylists,
          ),
        ],
        const SafeBottomSpacer(),
      ],
    );
  }
}
