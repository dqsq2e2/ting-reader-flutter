import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/locale.dart';
import '../../../core/utils/urls.dart';
import '../../../shared/app_scope.dart';
import '../../../shared/cards/book_card.dart';
import '../../../shared/common/common_widgets.dart';
import '../../../shared/filter/display_filter_menu.dart';

part 'series_detail_widgets.dart';
part 'series_settings_dialog.dart';
part 'series_book_picker_dialog.dart';

class SeriesDetailPage extends StatefulWidget {
  const SeriesDetailPage({
    super.key,
    required this.seriesId,
    required this.onBack,
    required this.openBook,
  });

  final String seriesId;
  final VoidCallback onBack;
  final ValueChanged<String> openBook;

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  bool _loading = true;
  bool _showFilterMenu = false;
  Series? _series;
  String _sortBy = 'default';
  IconSizeSetting _iconSize = IconSizeSetting.medium;
  CoverShape _coverShape = CoverShape.rect;
  final LayerLink _filterMenuLink = LayerLink();
  OverlayEntry? _filterOverlay;

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
      final results = await Future.wait([
        appState.api.get('/api/v1/series/${widget.seriesId}'),
        appState.api.get('/api/settings'),
      ]);
      final settingsPayload = asMap(results[1].data);
      final settingsJson = asMap(settingsPayload['settings_json']);
      dynamic settingValue(String key) {
        return settingsPayload[key] ?? settingsJson[key];
      }

      setState(() {
        _series = Series.fromJson(asMap(results[0].data));
        _sortBy = _normalizeSeriesSortBy(
          (settingValue('series_sort_by') ?? _sortBy).toString(),
        );
        _iconSize = iconSizeFromString(
          settingValue('series_icon_size')?.toString(),
        );
        _coverShape = coverShapeFromString(
          settingValue('bookshelf_cover_shape')?.toString(),
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Book> _sortedBooks(Series series) {
    final books = [...series.books];
    switch (_sortBy) {
      case 'title':
        books.sort((a, b) => compareChineseText(a.title, b.title));
        break;
      case 'author':
        books.sort(
          (a, b) => compareChineseText(a.author ?? '', b.author ?? ''),
        );
        break;
    }
    return books;
  }

  String _normalizeSeriesSortBy(String value) {
    return switch (value) {
      'title' || 'author' || 'default' => value,
      _ => 'default',
    };
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
                      value: 'default',
                      label: context.localeText('默认排序', 'Default'),
                    ),
                    DisplayFilterSortOption(
                      value: 'title',
                      label: context.localeText('书名排序', 'Title'),
                    ),
                    DisplayFilterSortOption(
                      value: 'author',
                      label: context.localeText('作者排序', 'Author'),
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
    _closeFilterMenu();
    setState(() => _sortBy = value);
    await AppScope.appOf(context).updateSettings({'series_sort_by': value});
  }

  Future<void> _setIconSize(IconSizeSetting value) async {
    final raw = switch (value) {
      IconSizeSetting.small => 'small',
      IconSizeSetting.medium => 'medium',
      IconSizeSetting.large => 'large',
    };
    _closeFilterMenu();
    setState(() => _iconSize = value);
    await AppScope.appOf(context).updateSettings({'series_icon_size': raw});
  }

  Future<void> _showSeriesSettingsDialog() async {
    final series = _series;
    if (series == null) return;

    final appState = AppScope.appOf(context);
    final messenger = ScaffoldMessenger.of(context);
    List<Book> allBooks;
    try {
      final response = await appState.api.get('/api/books');
      allBooks = asMapList(response.data).map(Book.fromJson).toList();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text(context.localeText(
                '加载书籍失败：$error', 'Failed to load books: $error'))),
      );
      return;
    }

    if (!mounted) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SeriesSettingsDialog(
        series: series,
        allBooks: allBooks,
        coverShape: _coverShape,
        onDeleted: widget.onBack,
      ),
    );

    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final series = _series;
    if (series == null) {
      return PageListView(
        children: [
          AppBackButton(onPressed: widget.onBack),
          const SizedBox(height: 24),
          EmptyState(
            icon: Icons.layers_clear_rounded,
            title: context.localeText('未找到系列', 'Series Not Found'),
            message: context.localeText('该系列可能已被删除或您没有访问权限。',
                'This series may have been deleted or you may not have access.'),
          ),
        ],
      );
    }

    final books = _sortedBooks(series);

    return PageListView(
      onRefresh: _load,
      children: [
        _SeriesHeader(
          title: localizedSeriesTitle(context, series),
          filterMenuLink: _filterMenuLink,
          showFilterMenu: _showFilterMenu,
          onBack: widget.onBack,
          onToggleFilter: _toggleFilterMenu,
          onSettings: _showSeriesSettingsDialog,
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Text(
              context.localeText('包含书籍 (${series.books.length})',
                  'Books (${series.books.length})'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (books.isEmpty)
          EmptyState(
            icon: Icons.menu_book_rounded,
            title: context.localeText('系列中暂无书籍', 'No Books in Series'),
            message: context.localeText(
                '添加书籍后会在这里显示。', 'Books you add will appear here.'),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = gridColumnsForWidth(
                constraints.maxWidth,
                _iconSize,
              );
              final spacing = gridSpacing(_iconSize);
              final ratio = _coverShape == CoverShape.square ? 0.78 : 0.62;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: books.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing + 14,
                  childAspectRatio: ratio,
                ),
                itemBuilder: (context, index) {
                  final book = books[index];
                  return BookCard(
                    book: book,
                    coverShape: _coverShape,
                    onTap: () => widget.openBook(book.id),
                  );
                },
              );
            },
          ),
        const SafeBottomSpacer(),
      ],
    );
  }
}
