part of 'series_detail_page.dart';

class _SeriesSettingsDialog extends StatefulWidget {
  const _SeriesSettingsDialog({
    required this.series,
    required this.allBooks,
    required this.coverShape,
    required this.onDeleted,
  });

  final Series series;
  final List<Book> allBooks;
  final CoverShape coverShape;
  final VoidCallback onDeleted;

  @override
  State<_SeriesSettingsDialog> createState() => _SeriesSettingsDialogState();
}

class _SeriesSettingsDialogState extends State<_SeriesSettingsDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _narratorController;
  late final TextEditingController _coverController;
  late final TextEditingController _descriptionController;
  late List<Book> _books;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final series = widget.series;
    _titleController = TextEditingController(text: series.title);
    _authorController = TextEditingController(text: series.author ?? '');
    _narratorController = TextEditingController(text: series.narrator ?? '');
    _coverController = TextEditingController(text: series.coverUrl ?? '');
    _descriptionController =
        TextEditingController(text: series.description ?? '');
    _books = [...series.books];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _narratorController.dispose();
    _coverController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addBook() async {
    final selected = await showDialog<Book>(
      context: context,
      builder: (context) => _SeriesBookPickerDialog(
        books: widget.allBooks,
        existingIds: _books.map((book) => book.id).toSet(),
        coverShape: widget.coverShape,
      ),
    );
    if (selected == null || _books.any((book) => book.id == selected.id)) {
      return;
    }
    setState(() => _books = [..._books, selected]);
  }

  void _moveBook(int index, int delta) {
    final next = index + delta;
    if (next < 0 || next >= _books.length) return;
    final updated = [..._books];
    final book = updated.removeAt(index);
    updated.insert(next, book);
    setState(() => _books = updated);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('系列名称不能为空')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await AppScope.appOf(context).api.put(
        '/api/v1/series/${widget.series.id}',
        data: {
          'title': title,
          'author': _authorController.text.trim(),
          'narrator': _narratorController.text.trim(),
          'cover_url': _coverController.text.trim(),
          'description': _descriptionController.text.trim(),
          'book_ids': _books.map((book) => book.id).toList(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存系列失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final api = AppScope.appOf(context).api;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除系列'),
        content: const Text('确定要删除这个系列吗？系列中的书籍不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffef4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await api.delete(
        '/api/v1/series/${widget.series.id}',
      );
      if (!mounted) return;
      navigator.pop(false);
      widget.onDeleted();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('删除系列失败：$error')),
      );
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _saving || _deleting;
    final media = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.all(media.width < 640 ? 10 : 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: media.height * 0.9,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: context.faintBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 18 : 26,
                      compact ? 16 : 22,
                      compact ? 10 : 18,
                      compact ? 12 : 18,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '系列设置',
                            style: TextStyle(
                              fontSize: context.adaptiveFont(25, 21),
                              fontWeight: FontWeight.w700,
                              color: context.primaryText,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed:
                              disabled ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: '关闭',
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: context.faintBorder),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(compact ? 16 : 24),
                      child: compact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SeriesCoverPreview(
                                  series: widget.series,
                                  coverController: _coverController,
                                  coverShape: widget.coverShape,
                                ),
                                const SizedBox(height: 16),
                                _SeriesFormFields(
                                  titleController: _titleController,
                                  authorController: _authorController,
                                  narratorController: _narratorController,
                                  coverController: _coverController,
                                  descriptionController: _descriptionController,
                                ),
                                const SizedBox(height: 18),
                                _SeriesBooksEditor(
                                  books: _books,
                                  coverShape: widget.coverShape,
                                  compact: true,
                                  onAdd: disabled ? null : _addBook,
                                  onMove: disabled ? null : _moveBook,
                                  onRemove: disabled
                                      ? null
                                      : (book) => setState(
                                            () => _books = _books
                                                .where((item) =>
                                                    item.id != book.id)
                                                .toList(),
                                          ),
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 250,
                                  child: _SeriesCoverPreview(
                                    series: widget.series,
                                    coverController: _coverController,
                                    coverShape: widget.coverShape,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _SeriesFormFields(
                                        titleController: _titleController,
                                        authorController: _authorController,
                                        narratorController: _narratorController,
                                        coverController: _coverController,
                                        descriptionController:
                                            _descriptionController,
                                      ),
                                      const SizedBox(height: 20),
                                      _SeriesBooksEditor(
                                        books: _books,
                                        coverShape: widget.coverShape,
                                        compact: false,
                                        onAdd: disabled ? null : _addBook,
                                        onMove: disabled ? null : _moveBook,
                                        onRemove: disabled
                                            ? null
                                            : (book) => setState(
                                                  () => _books = _books
                                                      .where((item) =>
                                                          item.id != book.id)
                                                      .toList(),
                                                ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  Divider(height: 1, color: context.faintBorder),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 14 : 24,
                      12,
                      compact ? 14 : 24,
                      compact ? 14 : 18,
                    ),
                    child: _SeriesSettingsActions(
                      compact: compact,
                      disabled: disabled,
                      deleting: _deleting,
                      saving: _saving,
                      onDelete: _delete,
                      onCancel: () => Navigator.pop(context),
                      onSave: _save,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SeriesCoverPreview extends StatelessWidget {
  const _SeriesCoverPreview({
    required this.series,
    required this.coverController,
    required this.coverShape,
  });

  final Series series;
  final TextEditingController coverController;
  final CoverShape coverShape;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: coverController,
      builder: (context, value, _) {
        final firstBook = series.books.isNotEmpty ? series.books.first : null;
        final url = coverUrl(
          appState,
          url: value.text.trim().isNotEmpty
              ? value.text.trim()
              : series.coverUrl ?? firstBook?.coverUrl,
          libraryId: series.libraryId,
          bookId: firstBook?.id,
        );
        return AspectRatio(
          aspectRatio: coverAspectRatio(coverShape),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.subtleFill,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: CoverImage(url: url, radius: 18),
          ),
        );
      },
    );
  }
}

class _SeriesFormFields extends StatelessWidget {
  const _SeriesFormFields({
    required this.titleController,
    required this.authorController,
    required this.narratorController,
    required this.coverController,
    required this.descriptionController,
  });

  final TextEditingController titleController;
  final TextEditingController authorController;
  final TextEditingController narratorController;
  final TextEditingController coverController;
  final TextEditingController descriptionController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 560;
        final fields = [
          _SeriesTextField(controller: titleController, label: '系列名称'),
          _SeriesTextField(controller: authorController, label: '作者'),
          _SeriesTextField(controller: narratorController, label: '演播者'),
          _SeriesTextField(controller: coverController, label: '封面 URL'),
        ];

        return Column(
          children: [
            if (twoColumns)
              ...List.generate(2, (row) {
                return Padding(
                  padding: EdgeInsets.only(bottom: row == 1 ? 0 : 12),
                  child: Row(
                    children: [
                      Expanded(child: fields[row * 2]),
                      const SizedBox(width: 12),
                      Expanded(child: fields[row * 2 + 1]),
                    ],
                  ),
                );
              })
            else
              ...fields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: field,
                ),
              ),
            const SizedBox(height: 12),
            _SeriesTextField(
              controller: descriptionController,
              label: '简介',
              minLines: 4,
              maxLines: 6,
            ),
          ],
        );
      },
    );
  }
}

class _SeriesTextField extends StatelessWidget {
  const _SeriesTextField({
    required this.controller,
    required this.label,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: context.adaptiveFont(15, 14),
        color: context.primaryText,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: context.subtleFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.faintBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.faintBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary500, width: 2),
        ),
      ),
    );
  }
}

class _SeriesBooksEditor extends StatelessWidget {
  const _SeriesBooksEditor({
    required this.books,
    required this.coverShape,
    required this.compact,
    required this.onAdd,
    required this.onMove,
    required this.onRemove,
  });

  final List<Book> books;
  final CoverShape coverShape;
  final bool compact;
  final VoidCallback? onAdd;
  final void Function(int index, int delta)? onMove;
  final ValueChanged<Book>? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.subtleFill.withOpacity(context.isDark ? 0.2 : 0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.faintBorder),
      ),
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '系列条目 (${books.length})',
                  style: TextStyle(
                    fontSize: context.adaptiveFont(18, 16),
                    fontWeight: FontWeight.w700,
                    color: context.primaryText,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16,
                    vertical: compact ? 9 : 11,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(compact ? '添加' : '添加书籍'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (books.isEmpty)
            const EmptyState(
              icon: Icons.menu_book_rounded,
              title: '暂无条目',
              message: '点击添加书籍把作品加入这个系列。',
            )
          else
            ...books.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SeriesBookEditorRow(
                      book: entry.value,
                      index: entry.key,
                      total: books.length,
                      coverShape: coverShape,
                      compact: compact,
                      onMove: onMove,
                      onRemove: onRemove,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _SeriesBookEditorRow extends StatelessWidget {
  const _SeriesBookEditorRow({
    required this.book,
    required this.index,
    required this.total,
    required this.coverShape,
    required this.compact,
    required this.onMove,
    required this.onRemove,
  });

  final Book book;
  final int index;
  final int total;
  final CoverShape coverShape;
  final bool compact;
  final void Function(int index, int delta)? onMove;
  final ValueChanged<Book>? onRemove;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final coverWidth = compact ? 44.0 : 52.0;
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.faintBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.tertiaryText,
                fontSize: context.adaptiveFont(14, 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: coverWidth,
            child: AspectRatio(
              aspectRatio: coverAspectRatio(coverShape),
              child: CoverImage(url: bookCoverUrl(appState, book), radius: 8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.adaptiveFont(15, 14),
                    fontWeight: FontWeight.w600,
                    color: context.primaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  book.author?.isNotEmpty == true ? book.author! : '未知作者',
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
          const SizedBox(width: 8),
          if (!compact)
            Column(
              children: [
                _TinyIconButton(
                  icon: Icons.keyboard_arrow_up_rounded,
                  onPressed: index == 0 || onMove == null
                      ? null
                      : () => onMove!(index, -1),
                ),
                _TinyIconButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  onPressed: index == total - 1 || onMove == null
                      ? null
                      : () => onMove!(index, 1),
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TinyIconButton(
                  icon: Icons.arrow_upward_rounded,
                  onPressed: index == 0 || onMove == null
                      ? null
                      : () => onMove!(index, -1),
                ),
                _TinyIconButton(
                  icon: Icons.arrow_downward_rounded,
                  onPressed: index == total - 1 || onMove == null
                      ? null
                      : () => onMove!(index, 1),
                ),
              ],
            ),
          _TinyIconButton(
            icon: Icons.close_rounded,
            color: const Color(0xffef4444),
            onPressed: onRemove == null ? null : () => onRemove!(book),
          ),
        ],
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      icon: Icon(icon, size: 18, color: color),
    );
  }
}

class _SeriesSettingsActions extends StatelessWidget {
  const _SeriesSettingsActions({
    required this.compact,
    required this.disabled,
    required this.deleting,
    required this.saving,
    required this.onDelete,
    required this.onCancel,
    required this.onSave,
  });

  final bool compact;
  final bool disabled;
  final bool deleting;
  final bool saving;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final deleteButton = TextButton.icon(
      onPressed: disabled ? null : onDelete,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xffef4444),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 9 : 12,
        ),
      ),
      icon: deleting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_outline_rounded, size: 18),
      label: Text(compact ? '删除' : '删除系列'),
    );
    final cancelButton = TextButton(
      onPressed: disabled ? null : onCancel,
      style: TextButton.styleFrom(
        foregroundColor: context.mutedText,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 18,
          vertical: compact ? 9 : 12,
        ),
      ),
      child: const Text('取消'),
    );
    final saveButton = ElevatedButton.icon(
      onPressed: disabled ? null : onSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 22,
          vertical: compact ? 10 : 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      icon: saving
          ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_outlined, size: 18),
      label: Text(saving ? '保存中' : (compact ? '保存' : '保存更改')),
    );

    if (compact) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [deleteButton, cancelButton, saveButton],
      );
    }

    return Row(
      children: [
        deleteButton,
        const Spacer(),
        cancelButton,
        const SizedBox(width: 10),
        saveButton,
      ],
    );
  }
}
