part of 'bookshelf_page.dart';

class _ShelfContent extends StatelessWidget {
  const _ShelfContent({
    required this.books,
    required this.series,
    required this.visibleCount,
    required this.groupKeys,
    required this.groups,
    required this.groupSectionKeys,
    required this.iconSize,
    required this.coverShape,
    required this.viewMode,
    required this.selectionMode,
    required this.selectedBookIds,
    required this.selectedSeriesIds,
    required this.onBook,
    required this.onSeries,
  });

  final List<Book> books;
  final List<Series> series;
  final int visibleCount;
  final List<String>? groupKeys;
  final Map<String, List<Object>>? groups;
  final Map<String, GlobalKey> groupSectionKeys;
  final IconSizeSetting iconSize;
  final CoverShape coverShape;
  final BookshelfViewMode viewMode;
  final bool selectionMode;
  final Set<String> selectedBookIds;
  final Set<String> selectedSeriesIds;
  final ValueChanged<Book> onBook;
  final ValueChanged<Series> onSeries;

  Widget _buildItem(Object item) {
    if (item is Series) {
      return SeriesCard(
        series: item,
        coverShape: coverShape,
        viewMode: viewMode,
        iconSize: iconSize,
        selectionMode: selectionMode,
        selected: selectedSeriesIds.contains(item.id),
        onTap: () => onSeries(item),
      );
    }
    final book = item as Book;
    return BookCard(
      book: book,
      coverShape: coverShape,
      viewMode: viewMode,
      iconSize: iconSize,
      selectionMode: selectionMode,
      selected: selectedBookIds.contains(book.id),
      onTap: () => onBook(book),
    );
  }

  Widget _buildItems(BuildContext context, List<Object> items,
      {required int columns,
      required double spacing,
      required double cardHeight}) {
    if (viewMode == BookshelfViewMode.list) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildItem(items[index]),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing + 12,
        mainAxisExtent: cardHeight,
      ),
      itemBuilder: (context, index) => _buildItem(items[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = gridColumnsForWidth(constraints.maxWidth, iconSize);
        final spacing = gridSpacing(iconSize);
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final textScaler = MediaQuery.textScalerOf(context);
        final cardHeight = cellWidth / coverAspectRatio(coverShape) +
            textScaler.scale(14) * 1.5 +
            textScaler.scale(12) * 1.5 +
            16;

        final groupKeys = this.groupKeys;
        final groups = this.groups;
        if (groupKeys != null && groups != null) {
          var remaining = visibleCount;
          final visibleGroups = <String, List<Object>>{};
          for (final key in groupKeys) {
            if (remaining <= 0) break;
            final group = groups[key];
            if (group == null) continue;
            final take = group.length < remaining ? group.length : remaining;
            if (take > 0) {
              visibleGroups[key] = group.sublist(0, take);
              remaining -= take;
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in visibleGroups.entries)
                Column(
                  key: groupSectionKeys[entry.key],
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 2, bottom: 10, top: 6),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: context.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _buildItems(context, entry.value,
                        columns: columns,
                        spacing: spacing,
                        cardHeight: cardHeight),
                    const SizedBox(height: 18),
                  ],
                ),
            ],
          );
        }

        final items = <Object>[...series, ...books].take(visibleCount).toList();
        return _buildItems(context, items,
            columns: columns, spacing: spacing, cardHeight: cardHeight);
      },
    );
  }
}

class _AlphabetIndexBar extends StatelessWidget {
  const _AlphabetIndexBar({
    required this.keys,
    required this.activeKey,
    required this.onTouchStart,
    required this.onKeyTouch,
    required this.onTapEnd,
    required this.onTouchEnd,
  });

  static const double _itemExtent = 18;

  final List<String> keys;
  final String? activeKey;
  final VoidCallback onTouchStart;
  final ValueChanged<String> onKeyTouch;
  final VoidCallback onTapEnd;
  final VoidCallback onTouchEnd;

  void _handleTouch(Offset localPosition) {
    if (keys.isEmpty) return;
    final index =
        (localPosition.dy / _itemExtent).floor().clamp(0, keys.length - 1);
    onKeyTouch(keys[index]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idleColor = isDark ? AppColors.slate500 : AppColors.slate400;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) {
        onTouchStart();
        _handleTouch(details.localPosition);
      },
      onVerticalDragUpdate: (details) => _handleTouch(details.localPosition),
      onVerticalDragEnd: (_) => onTouchEnd(),
      onVerticalDragCancel: onTouchEnd,
      onTapDown: (details) {
        onTouchStart();
        _handleTouch(details.localPosition);
      },
      onTapUp: (_) => onTapEnd(),
      onTapCancel: onTouchEnd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final key in keys)
              SizedBox(
                width: 16,
                height: _itemExtent,
                child: Center(
                  child: AnimatedScale(
                    scale: activeKey == key ? 1.25 : 1,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: activeKey == key
                            ? AppColors.primary600
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        key,
                        maxLines: 1,
                        style: TextStyle(
                          color: activeKey == key ? Colors.white : idleColor,
                          fontSize: 10,
                          fontWeight: activeKey == key
                              ? FontWeight.w700
                              : FontWeight.w500,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Removes the always-visible scrollbar that the default scroll behavior
/// adds on desktop platforms.
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
