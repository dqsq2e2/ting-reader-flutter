import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/app_scope.dart';
import '../widgets/book_card.dart';
import '../widgets/common_widgets.dart';

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
      final settings = asMap(asMap(results[1].data)['settings_json'] ??
          asMap(results[1].data)['settingsJson']);
      setState(() {
        _books = asMapList(results[0].data).map(Book.fromJson).toList();
        _iconSize = iconSizeFromString(
          (settings['bookshelf_icon_size'] ?? settings['bookshelfIconSize'])
              ?.toString(),
        );
        _coverShape = coverShapeFromString(
          (settings['bookshelf_cover_shape'] ?? settings['bookshelfCoverShape'])
              ?.toString(),
        );
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
          title: '我的收藏',
          subtitle: '您最喜爱的 ${_books.length} 部作品',
        ),
        const SizedBox(height: 24),
        if (_books.isEmpty)
          EmptyState(
            icon: Icons.favorite_outline_rounded,
            title: '您的收藏夹还是空的',
            message: '点击书籍详情页的爱心图标，即可收藏您喜欢的作品',
            action: PrimaryButton(
              label: '去书架看看',
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
