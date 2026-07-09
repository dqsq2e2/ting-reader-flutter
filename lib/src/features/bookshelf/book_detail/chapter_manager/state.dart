part of '../book_detail_page.dart';

class _ChapterManagerDialog extends StatefulWidget {
  const _ChapterManagerDialog({
    required this.book,
    required this.chapters,
  });

  final Book book;
  final List<Chapter> chapters;

  @override
  State<_ChapterManagerDialog> createState() => _ChapterManagerDialogState();
}

class _ChapterManagerDialogState extends State<_ChapterManagerDialog> {
  static const int _groupSize = 100;

  late List<Chapter> _chapters;
  final Set<String> _changedIds = {};
  final Set<String> _selectedIds = {};
  final _searchController = TextEditingController();
  String _activeChapterTab = 'main';
  int _groupIndex = 0;
  bool _selectionMode = false;
  bool _saving = false;
  bool _moving = false;
  Library? _pathLibrary;

  @override
  void initState() {
    super.initState();
    _chapters = [...widget.chapters]
      ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    _loadPathContext();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Chapter> get _tabChapters {
    return _chapters
        .where((chapter) =>
            _activeChapterTab == 'extra' ? chapter.isExtra : !chapter.isExtra)
        .toList();
  }

  List<Chapter> get _filteredChapters {
    final search = _searchController.text.trim().toLowerCase();
    final source = _tabChapters;
    if (search.isEmpty) return source;
    return source
        .where((chapter) =>
            chapter.title.toLowerCase().contains(search) ||
            chapter.chapterIndex.toString().contains(search) ||
            _chapterDisplayPath(chapter.path).toLowerCase().contains(search))
        .toList();
  }

  int get _mainChapterCount =>
      _chapters.where((chapter) => !chapter.isExtra).length;

  int get _extraChapterCount =>
      _chapters.where((chapter) => chapter.isExtra).length;

  void _setChapterTab(String tab) {
    if (_activeChapterTab == tab) return;
    setState(() {
      _activeChapterTab = tab;
      _groupIndex = 0;
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  void _replaceChapter(String id, Chapter Function(Chapter chapter) update) {
    setState(() {
      _chapters = [
        for (final chapter in _chapters)
          if (chapter.id == id) update(chapter) else chapter,
      ];
      _changedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    if (!_selectionMode) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleAll() {
    final filtered = _filteredChapters;
    final ids = filtered.map((chapter) => chapter.id).toList();
    final allSelected = ids.isNotEmpty && ids.every(_selectedIds.contains);
    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  void _updateState(VoidCallback update) => setState(update);

  Future<void> _requestClose() async {
    if (_saving || _moving) return;
    if (_changedIds.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.localeText('有未保存更改', 'Unsaved Changes')),
        content: Text(context.localeText('关闭前保存 ${_changedIds.length} 项修改？',
            'Save ${_changedIds.length} changes before closing?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(context.localeText('放弃修改', 'Discard')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: Text(context.localeText('继续编辑', 'Keep Editing')),
          ),
          PrimaryButton(
            label: context.localeText('保存并退出', 'Save and Exit'),
            icon: Icons.save_rounded,
            onPressed: () => Navigator.pop(context, 'save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'discard') {
      Navigator.pop(context);
    } else if (action == 'save') {
      await _save();
    }
  }

  Future<void> _loadPathContext() async {
    try {
      final res = await AppScope.appOf(context).api.get('/api/libraries');
      if (!mounted) return;
      final raw = res.data is List
          ? asMapList(res.data)
          : asMapList(asMap(res.data)['libraries']);
      final libraries = raw.map(Library.fromJson);
      setState(() {
        _pathLibrary = libraries
            .where((library) => library.id == widget.book.libraryId)
            .firstOrNull;
      });
    } catch (_) {
      // Path context is only used for display; keep the dialog usable if it fails.
    }
  }

  Future<void> _renumber() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.localeText('重排序号', 'Renumber Chapters')),
        content: Text(context.localeText('确定按当前列表顺序重新生成章节序号（从 1 开始）吗？',
            'Regenerate chapter numbers from the current order, starting at 1?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          PrimaryButton(
            label: context.localeText('重排', 'Renumber'),
            icon: Icons.format_list_numbered_rounded,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _chapters = [
        for (var i = 0; i < _chapters.length; i++)
          _chapters[i].copyWith(chapterIndex: i + 1),
      ];
      _changedIds.addAll(_chapters.map((chapter) => chapter.id));
    });
  }

  Future<void> _save() async {
    if (_changedIds.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final updates = _chapters
          .where((chapter) => _changedIds.contains(chapter.id))
          .map((chapter) => {
                'id': chapter.id,
                'title': chapter.title,
                'chapter_index': chapter.chapterIndex,
                'is_extra': chapter.isExtra ? 1 : 0,
              })
          .toList();
      await AppScope.appOf(context).api.put(
        '/api/books/${widget.book.id}/chapters/batch',
        data: {'updates': updates},
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.localeText(
                '保存章节失败：$err', 'Failed to save chapters: $err'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _moveSelected() async {
    if (_selectedIds.isEmpty || _moving) return;
    final target = await _pickTargetBook();
    if (target == null || !mounted) return;
    setState(() => _moving = true);
    try {
      await AppScope.appOf(context).api.post(
        '/api/books/chapters/move',
        data: {
          'target_book_id': target.id,
          'chapter_ids': _selectedIds.toList(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.localeText(
                '移动章节失败：$err', 'Failed to move chapters: $err'))),
      );
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  Future<Book?> _pickTargetBook() async {
    final appState = AppScope.appOf(context);
    final res = await appState.api.get('/api/books');
    final books = asMapList(res.data)
        .map(Book.fromJson)
        .where((book) => book.id != widget.book.id)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    if (!mounted) return null;
    return showDialog<Book>(
      context: context,
      builder: (context) {
        var search = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = search.trim().isEmpty
                ? books
                : books
                    .where((book) => book.title
                        .toLowerCase()
                        .contains(search.trim().toLowerCase()))
                    .toList();
            return AlertDialog(
              title: Text(context.localeText('移动到作品', 'Move to Book')),
              content: SizedBox(
                width: 520,
                height: 520,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: context.localeText('搜索作品', 'Search books'),
                      ),
                      onChanged: (value) =>
                          setDialogState(() => search = value),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? EmptyState(
                              icon: Icons.menu_book_rounded,
                              title: context.localeText(
                                  '没有可移动的目标作品', 'No Target Books'),
                              message: context.localeText('请先创建或扫描其他作品。',
                                  'Create or scan another book first.'),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final book = filtered[index];
                                return ListTile(
                                  leading: SizedBox(
                                    width: 42,
                                    height: 56,
                                    child: CoverImage(
                                      url: bookCoverUrl(appState, book),
                                      radius: 8,
                                    ),
                                  ),
                                  title: Text(
                                    book.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(book.author ??
                                      context.localeText(
                                          '未知作者', 'Unknown Author')),
                                  onTap: () => Navigator.pop(context, book),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.commonCancel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _decodeSegment(String segment) {
    try {
      return Uri.decodeComponent(segment);
    } catch (_) {
      return segment;
    }
  }

  String _decodePathBySegment(String path) {
    return path.split('/').map(_decodeSegment).join('/');
  }

  String _stripWindowsVerbatimPrefix(String path) {
    if (path.startsWith(r'\\?\UNC\')) return '//${path.substring(8)}';
    if (path.startsWith('//?/UNC/')) return '//${path.substring(8)}';
    if (path.startsWith(r'\\?\')) return path.substring(4);
    if (path.startsWith('//?/')) return path.substring(4);
    return path;
  }

  String _normalizeDisplayPath(String path) {
    return _stripWindowsVerbatimPrefix(path)
        .replaceAll('\\', '/')
        .replaceAllMapped(RegExp(r'([^:])/{2,}'), (match) => '${match[1]}/')
        .replaceAll(RegExp(r'/+$'), '');
  }

  String _remoteDisplayPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final decodedPath = _decodePathBySegment(uri.path);
      return _normalizeDisplayPath(
        '${uri.origin}$decodedPath${uri.hasQuery ? '?${uri.query}' : ''}${uri.hasFragment ? '#${uri.fragment}' : ''}',
      );
    }
    return _normalizeDisplayPath(_decodePathBySegment(trimmed));
  }

  String _chapterDisplayPath(String chapterPath) {
    final library = _pathLibrary;
    if (library?.libraryType == 'local') {
      return _normalizeDisplayPath(chapterPath);
    }
    return _remoteDisplayPath(chapterPath);
  }

  @override
  Widget build(BuildContext context) => _buildResponsiveDialog(context);
}
