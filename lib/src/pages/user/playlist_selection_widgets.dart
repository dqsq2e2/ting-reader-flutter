part of 'user_pages.dart';

class _PlaylistContentGrid extends StatelessWidget {
  const _PlaylistContentGrid({required this.items, required this.onOpen});

  final List<PlaylistItem> items;
  final ValueChanged<PlaylistItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = iconSizeFromAppSettings(
          AppScope.appOf(context).settings,
        );
        final columns = gridColumnsForWidth(
          constraints.maxWidth,
          iconSize,
        );
        final spacing = gridSpacing(iconSize);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing + 8,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _PlaylistContentCard(
                  item: item,
                  onTap: () => onOpen(item),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlaylistBookSelectGrid extends StatelessWidget {
  const _PlaylistBookSelectGrid({
    required this.books,
    required this.isSelected,
    required this.onToggle,
  });

  final List<Book> books;
  final bool Function(Book book) isSelected;
  final ValueChanged<Book> onToggle;

  @override
  Widget build(BuildContext context) {
    final coverShape = _playlistCoverShape(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = iconSizeFromAppSettings(
          AppScope.appOf(context).settings,
        );
        final columns = gridColumnsForWidth(
          constraints.maxWidth,
          iconSize,
        );
        final spacing = gridSpacing(iconSize);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing + 8,
          children: [
            for (final book in books)
              SizedBox(
                width: width,
                child: BookCard(
                  book: book,
                  coverShape: coverShape,
                  selectionMode: true,
                  selected: isSelected(book),
                  onTap: () => onToggle(book),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlaylistSeriesSelectGrid extends StatelessWidget {
  const _PlaylistSeriesSelectGrid({
    required this.series,
    required this.isSelected,
    required this.onToggle,
  });

  final List<Series> series;
  final bool Function(Series series) isSelected;
  final ValueChanged<Series> onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final columns = compact ? 1 : (constraints.maxWidth >= 1024 ? 3 : 2);
        const spacing = 14.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in series)
              SizedBox(
                width: width,
                child: _PlaylistSeriesSelectCard(
                  series: item,
                  selected: isSelected(item),
                  onTap: () => onToggle(item),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlaylistSeriesSelectCard extends StatelessWidget {
  const _PlaylistSeriesSelectCard({
    required this.series,
    required this.selected,
    required this.onTap,
  });

  final Series series;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coverShape = _playlistCoverShape(context);
    final cover = _seriesFirstCover(context, series);
    return TingCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: coverShape == CoverShape.square ? 72 : 58,
            child: AspectRatio(
              aspectRatio: coverAspectRatio(coverShape),
              child: CoverImage(
                url: cover,
                radius: 12,
                placeholderIcon: Icons.layers_rounded,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  '${series.author ?? '未知作者'} · ${series.books.length} 本',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.primary600 : Colors.transparent,
              border: Border.all(
                color: selected ? AppColors.primary600 : AppColors.slate300,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
        ],
      ),
    );
  }
}

class _PlaylistSelectedOrderPanel extends StatelessWidget {
  const _PlaylistSelectedOrderPanel({
    required this.items,
    required this.onMove,
    required this.onRemove,
  });

  final List<PlaylistItem> items;
  final void Function(int index, int offset) onMove;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return TingCard(
      radius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '已选顺序',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '这里的顺序就是保存后的书单播放顺序。',
                        style: TextStyle(
                          color: context.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${items.length} 项',
                  style: TextStyle(color: context.secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.faintBorder),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                '还没有选择内容。',
                style: TextStyle(color: context.secondaryText),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              _PlaylistItemTile(
                item: items[i],
                index: i,
                total: items.length,
                onOpen: () {},
                onMoveUp: i == 0 ? null : () => onMove(i, -1),
                onMoveDown: i == items.length - 1 ? null : () => onMove(i, 1),
                onRemove: () => onRemove(i),
              ),
              if (i != items.length - 1)
                Divider(height: 1, color: context.faintBorder),
            ],
        ],
      ),
    );
  }
}

class _PlaylistContentCard extends StatelessWidget {
  const _PlaylistContentCard({required this.item, required this.onTap});

  final PlaylistItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coverShape = _playlistCoverShape(context);
    final isSeries = item.itemType == 'series';
    final title = isSeries
        ? (item.series?.title ?? '未知系列')
        : (item.book?.title ?? '未知书籍');
    final subtitle = isSeries
        ? '${item.series?.author ?? '未知作者'} · ${item.series?.books.length ?? 0} 本'
        : (item.book?.author ?? item.book?.narrator ?? '未知作者');
    final cover = isSeries
        ? (item.series == null ? '' : _seriesFirstCover(context, item.series!))
        : (item.book == null
            ? ''
            : bookCoverUrl(AppScope.appOf(context), item.book!));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: coverAspectRatio(coverShape),
                child: CoverImage(
                  url: cover,
                  radius: 6,
                  placeholderIcon:
                      isSeries ? Icons.layers_rounded : Icons.menu_book_rounded,
                ),
              ),
              if (isSeries)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary600,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '系列',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PlaylistItemTile extends StatelessWidget {
  const _PlaylistItemTile({
    required this.item,
    required this.index,
    required this.total,
    required this.onOpen,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  });

  final PlaylistItem item;
  final int index;
  final int total;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final book = item.book;
    final series = item.series;
    final title = item.itemType == 'series'
        ? (series?.title ?? '未知系列')
        : (book?.title ?? '未知书籍');
    final subtitle = item.itemType == 'series'
        ? '系列 · ${series?.books.length ?? 0} 本'
        : (book?.author ?? book?.narrator ?? '书籍');
    final coverUrlValue = item.itemType == 'series'
        ? (series == null
            ? ''
            : seriesCoverUrl(AppScope.appOf(context), series))
        : (book == null ? '' : bookCoverUrl(AppScope.appOf(context), book));
    return TingCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      onTap: onOpen,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: CoverImage(
                  url: coverUrlValue,
                  radius: 12,
                  placeholderIcon: item.itemType == 'series'
                      ? Icons.layers_rounded
                      : Icons.menu_book_rounded,
                ),
              ),
              Positioned(
                left: -6,
                top: -6,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.faintBorder),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: context.secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '上移',
            onPressed: onMoveUp,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            tooltip: '下移',
            onPressed: onMoveDown,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          IconButton(
            tooltip: '移除',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
