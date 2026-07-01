part of 'series_detail_page.dart';

class _SeriesBookPickerDialog extends StatefulWidget {
  const _SeriesBookPickerDialog({
    required this.books,
    required this.existingIds,
    required this.coverShape,
  });

  final List<Book> books;
  final Set<String> existingIds;
  final CoverShape coverShape;

  @override
  State<_SeriesBookPickerDialog> createState() =>
      _SeriesBookPickerDialogState();
}

class _SeriesBookPickerDialogState extends State<_SeriesBookPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final query = _query.trim().toLowerCase();
    final filtered = widget.books.where((book) {
      if (query.isEmpty) return true;
      return book.title.toLowerCase().contains(query) ||
          (book.author ?? '').toLowerCase().contains(query) ||
          (book.narrator ?? '').toLowerCase().contains(query);
    }).toList();

    return Dialog(
      insetPadding: EdgeInsets.all(media.width < 560 ? 10 : 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: media.height * 0.82,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.faintBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.localeText('添加系列条目', 'Add Series Item'),
                        style: TextStyle(
                          fontSize: context.adaptiveFont(21, 18),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: context.localeText(
                        '搜索书名、作者、演播者', 'Search title, author, narrator'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: context.subtleFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.faintBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: context.faintBorder),
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: context.faintBorder),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: context.localeText('没有找到书籍', 'No Books Found'),
                        message: context.localeText(
                            '换个关键词再试试。', 'Try another keyword.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final book = filtered[index];
                          final added = widget.existingIds.contains(book.id);
                          return _SeriesPickerBookRow(
                            book: book,
                            coverShape: widget.coverShape,
                            added: added,
                            onTap: added
                                ? null
                                : () => Navigator.pop(context, book),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesPickerBookRow extends StatelessWidget {
  const _SeriesPickerBookRow({
    required this.book,
    required this.coverShape,
    required this.added,
    required this.onTap,
  });

  final Book book;
  final CoverShape coverShape;
  final bool added;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    return Material(
      color: added ? context.subtleFill : context.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: context.faintBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: AspectRatio(
                  aspectRatio: coverAspectRatio(coverShape),
                  child:
                      CoverImage(url: bookCoverUrl(appState, book), radius: 8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedBookTitle(context, book),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.adaptiveFont(15, 14),
                        fontWeight: FontWeight.w700,
                        color: context.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author?.isNotEmpty == true
                          ? book.author!
                          : context.localeText('未知作者', 'Unknown Author'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: context.adaptiveFont(13, 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (added)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.subtleFill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.localeText('已添加', 'Added'),
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: context.adaptiveFont(12, 11),
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
