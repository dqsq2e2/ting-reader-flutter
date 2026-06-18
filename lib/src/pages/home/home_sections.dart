part of 'home_page.dart';

class _HomeStatsGrid extends StatelessWidget {
  const _HomeStatsGrid({
    required this.listenMinutes,
    required this.favoritesCount,
    required this.playlistsCount,
    required this.recentCount,
  });

  final int listenMinutes;
  final int favoritesCount;
  final int playlistsCount;
  final int recentCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final cols = compact ? 2 : 2;
        final gap = compact ? 12.0 : 14.0;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _MetricCard(
              width: width,
              compact: compact,
              icon: Icons.headphones_rounded,
              iconColor: AppColors.primary600,
              label: '最近已听',
              value: listenMinutes.toString(),
              unit: '分钟',
            ),
            _MetricCard(
              width: width,
              compact: compact,
              icon: Icons.favorite_border_rounded,
              iconColor: Colors.red,
              label: '收藏作品',
              value: favoritesCount.toString(),
              unit: '本',
            ),
            _MetricCard(
              width: width,
              compact: compact,
              icon: Icons.queue_music_rounded,
              iconColor: Colors.orange,
              label: '我的书单',
              value: playlistsCount.toString(),
              unit: '个',
            ),
            _MetricCard(
              width: width,
              compact: compact,
              icon: Icons.history_rounded,
              iconColor: Colors.green,
              label: '收听记录',
              value: recentCount.toString(),
              unit: '条',
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.compact,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  final double width;
  final bool compact;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TingCard(
        radius: compact ? 22 : 24,
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 50 : 44,
              height: compact ? 50 : 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: compact ? 24 : 21),
            ),
            SizedBox(height: compact ? 20 : 18),
            Text(
              label,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 12,
              ),
            ),
            SizedBox(height: compact ? 4 : 3),
            RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: context.isDark
                          ? AppColors.slate50
                          : AppColors.slate950,
                      fontSize: compact ? 30 : 28,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      color: context.tertiaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 25),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendedShelf extends StatelessWidget {
  const _RecommendedShelf({
    required this.books,
    required this.coverShape,
    required this.onBook,
  });

  final List<Book> books;
  final CoverShape coverShape;
  final ValueChanged<String> onBook;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const _EmptyBand(
        icon: Icons.library_books_rounded,
        title: '还没有可推荐的内容',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1500
            ? 8
            : constraints.maxWidth >= 1100
                ? 6
                : constraints.maxWidth >= 720
                    ? 4
                    : 3;
        const gap = 20.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 28,
          children: [
            for (final book in books)
              SizedBox(
                width: width,
                child: BookCard(
                  book: book,
                  coverShape: coverShape,
                  onTap: () => onBook(book.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentGrid extends StatelessWidget {
  const _RecentGrid({
    required this.items,
    required this.coverShape,
    required this.onBook,
  });

  final List<ProgressItem> items;
  final CoverShape coverShape;
  final ValueChanged<String> onBook;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820 ? 2 : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _RecentListenTile(
                  item: item,
                  coverShape: coverShape,
                  onTap: () => onBook(item.bookId),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentListenTile extends StatelessWidget {
  const _RecentListenTile({
    required this.item,
    required this.coverShape,
    required this.onTap,
  });

  final ProgressItem item;
  final CoverShape coverShape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final total = item.chapterDuration ?? item.duration;
    final percent =
        total <= 0 ? 0 : ((item.position / total) * 100).clamp(0, 100).round();
    return TingCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: AspectRatio(
              aspectRatio: coverAspectRatio(coverShape),
              child: CoverImage(
                url: coverUrl(
                  appState,
                  url: item.coverUrl,
                  libraryId: item.libraryId,
                  bookId: item.bookId,
                ),
                radius: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.bookTitle ?? '未知书籍',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '正在播放: ${item.chapterTitle ?? '未知章节'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: percent / 100,
                          minHeight: 5,
                          color: AppColors.primary500,
                          backgroundColor: AppColors.slate100,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: context.tertiaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentlyAddedGrid extends StatelessWidget {
  const _RecentlyAddedGrid({
    required this.books,
    required this.coverShape,
    required this.onBook,
  });

  final List<Book> books;
  final CoverShape coverShape;
  final ValueChanged<String> onBook;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const _EmptyBand(
        icon: Icons.trending_up_rounded,
        title: '暂无上新内容',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 3
            : constraints.maxWidth >= 760
                ? 2
                : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final book in books)
              SizedBox(
                width: width,
                child: _RecentlyAddedTile(
                  book: book,
                  coverShape: coverShape,
                  onTap: () => onBook(book.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentlyAddedTile extends StatelessWidget {
  const _RecentlyAddedTile({
    required this.book,
    required this.coverShape,
    required this.onTap,
  });

  final Book book;
  final CoverShape coverShape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    return TingCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: AspectRatio(
              aspectRatio: coverAspectRatio(coverShape),
              child: CoverImage(url: bookCoverUrl(appState, book), radius: 16),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '最近入库',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  book.author?.isNotEmpty == true ? book.author! : '未知作者',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.tertiaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.slate300),
        ],
      ),
    );
  }
}

class _CollectionsGrid extends StatelessWidget {
  const _CollectionsGrid({
    required this.playlists,
    required this.series,
    required this.playlistCoverSeed,
    required this.onPlaylists,
  });

  final List<Playlist> playlists;
  final List<Series> series;
  final int playlistCoverSeed;
  final VoidCallback onPlaylists;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      for (final playlist in playlists)
        _CollectionCard(
          title: playlist.title,
          subtitle: '${_playlistBookCount(playlist)} 本书',
          color: AppColors.primary600,
          coverUrlValue: _playlistRandomCoverUrl(
            context,
            playlist,
            playlistCoverSeed,
          ),
          onTap: onPlaylists,
        ),
      for (final item in series)
        _CollectionCard(
          title: item.title,
          subtitle: '${item.books.length} 本系列作品',
          coverUrlValue: seriesCoverUrl(AppScope.appOf(context), item),
          onTap: onPlaylists,
        ),
    ];
    if (items.isEmpty) {
      return const _EmptyBand(
        icon: Icons.queue_music_rounded,
        title: '还没有书单或系列',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 720
                ? 2
                : 1;
        const gap = 16.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in items.take(4))
              SizedBox(width: width, height: 178, child: child),
          ],
        );
      },
    );
  }
}

int _playlistBookCount(Playlist playlist) {
  if (playlist.items.isEmpty) return playlist.bookIds.length;
  return playlist.items.fold<int>(0, (total, item) {
    if (item.itemType == 'series') {
      return total + (item.series?.books.length ?? 0);
    }
    return total + 1;
  });
}

String? _playlistRandomCoverUrl(
  BuildContext context,
  Playlist playlist,
  int seed,
) {
  final appState = AppScope.appOf(context);
  final covers = <String>[];

  void pushBook(Book book) {
    covers.add(bookCoverUrl(appState, book));
  }

  void pushSeries(Series series) {
    if (series.books.isNotEmpty) {
      for (final book in series.books) {
        pushBook(book);
      }
    } else {
      covers.add(seriesCoverUrl(appState, series));
    }
  }

  if (playlist.items.isNotEmpty) {
    for (final item in playlist.items) {
      if (item.itemType == 'series' && item.series != null) {
        pushSeries(item.series!);
      } else if (item.book != null) {
        pushBook(item.book!);
      }
    }
  } else {
    for (final book in playlist.books) {
      pushBook(book);
    }
  }

  if (covers.isEmpty) return null;
  var hash = seed & 0x7fffffff;
  for (final unit in playlist.id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return covers[hash % covers.length];
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
    this.coverUrlValue,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
  final String? coverUrlValue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: color ?? AppColors.primary600,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.slate900.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverUrlValue != null)
                  CoverImage(url: coverUrlValue!, radius: 24),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.slate950.withOpacity(0.08),
                        AppColors.slate950.withOpacity(0.86),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.queue_music_rounded,
                          color: Colors.white, size: 25),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _EmptyBand extends StatelessWidget {
  const _EmptyBand({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.slate400, size: 34),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: context.mutedText)),
        ],
      ),
    );
  }
}
