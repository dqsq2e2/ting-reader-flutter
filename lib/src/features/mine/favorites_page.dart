import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/utils/locale.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.openBook,
    required this.openBookshelf,
    required this.onBack,
  });

  final ValueChanged<String> openBook;
  final VoidCallback openBookshelf;
  final VoidCallback onBack;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _loading = true;
  List<Book> _books = [];
  IconSizeSetting _iconSize = IconSizeSetting.medium;
  CoverShape _coverShape = CoverShape.rect;

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
        appState.api.get('/api/favorites'),
        appState.api.get('/api/settings'),
      ]);
      final settings = asMap(results[1].data);
      setState(() {
        _books = asMapList(results[0].data).map(Book.fromJson).toList();
        _iconSize = iconSizeFromAppSettings(settings);
        _coverShape = coverShapeFromAppSettings(settings);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();

    return PageListView(
      onRefresh: _load,
      children: [
        AppBackButton(onPressed: widget.onBack),
        const SizedBox(height: 24),
        HeaderText(
          icon: Icons.favorite_rounded,
          iconColor: Colors.red.shade500,
          title: context.localeText('我的收藏', 'Favorites'),
          subtitle: context.localeText(
            '您最喜爱的 ${_books.length} 部作品',
            '${_books.length} favorite books',
          ),
        ),
        const SizedBox(height: 24),
        if (_books.isEmpty)
          EmptyState(
            icon: Icons.favorite_outline_rounded,
            title: context.localeText('您的收藏夹还是空的', 'No Favorites Yet'),
            message: context.localeText(
              '点击书籍详情页的爱心图标，即可收藏您喜欢的作品',
              'Tap the heart on a book detail page to add it here.',
            ),
            action: PrimaryButton(
              label: context.localeText('去书架看看', 'Go to Bookshelf'),
              icon: Icons.library_books_rounded,
              onPressed: widget.openBookshelf,
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  gridColumnsForWidth(constraints.maxWidth, _iconSize);
              final spacing = gridSpacing(_iconSize);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _books.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing + 14,
                  childAspectRatio:
                      _coverShape == CoverShape.square ? 0.62 : 0.54,
                ),
                itemBuilder: (context, index) {
                  final book = _books[index];
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
