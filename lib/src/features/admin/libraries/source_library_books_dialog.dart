part of '../admin_pages.dart';

class _SourceLibraryBooksDialog extends StatefulWidget {
  const _SourceLibraryBooksDialog({required this.library});

  final Library library;

  @override
  State<_SourceLibraryBooksDialog> createState() =>
      _SourceLibraryBooksDialogState();
}

class _SourceLibraryBooksDialogState extends State<_SourceLibraryBooksDialog> {
  BookOperations? _operations;
  List<Book> _books = [];
  bool _loading = true;
  bool _changed = false;
  String? _deletingId;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_operations == null) {
      _operations = BookOperations(AppScope.appOf(context).api);
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _operations?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final operations = _operations;
    if (operations == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await operations.run((token) => operations.api.get(
            '/api/books',
            params: {'library_id': widget.library.id},
            cancelToken: token,
          ));
      if (!mounted) return;
      setState(
          () => _books = asMapList(response.data).map(Book.fromJson).toList());
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Book book) async {
    final operations = _operations;
    if (operations == null || _deletingId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.localeText('删除书籍', 'Delete book')),
        content: Text(context.localeText('从书架移除“${book.title}”？',
            'Remove "${book.title}" from the bookshelf?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.localeText('取消', 'Cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.localeText('删除', 'Delete'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingId = book.id);
    try {
      await operations.deleteBooks([book.id]);
      if (!mounted) return;
      setState(() {
        _books.removeWhere((item) => item.id == book.id);
        _changed = true;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiError.messageFor(error))));
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: _deletingId == null,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                child: Row(children: [
                  Expanded(
                      child: Text(widget.library.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    tooltip: context.localeText('关闭', 'Close'),
                    onPressed: _deletingId != null
                        ? null
                        : () => Navigator.pop(context, _changed),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ]),
              ),
              const Divider(height: 1),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: LoadingView())
              else if (_error != null)
                Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(ApiError.messageFor(
                            _error ?? StateError('Library load failed'))),
                        TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(context.localeText('重试', 'Retry'))),
                      ],
                    ))
              else if (_books.isEmpty)
                Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(context.localeText(
                        '此书源尚未加入书籍', 'No books added from this source')))
              else
                Flexible(
                    child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _books.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    final credit =
                        bookPrimaryCredit(book.author, book.narrator);
                    return ListTile(
                      title: Text(book.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: credit.isEmpty
                          ? null
                          : Text(credit,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: _deletingId == book.id
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(
                              tooltip:
                                  context.localeText('删除书籍', 'Delete book'),
                              onPressed: _deletingId != null
                                  ? null
                                  : () => _delete(book),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                    );
                  },
                )),
            ],
          ),
        ),
      ),
    );
  }
}
