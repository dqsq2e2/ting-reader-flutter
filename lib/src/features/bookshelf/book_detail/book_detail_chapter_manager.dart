part of 'book_detail_page.dart';

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
  late List<Chapter> _chapters;
  final Set<String> _changedIds = {};
  final Set<String> _selectedIds = {};
  final _searchController = TextEditingController();
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

  List<Chapter> get _filteredChapters {
    final search = _searchController.text.trim().toLowerCase();
    if (search.isEmpty) return _chapters;
    return _chapters
        .where((chapter) =>
            chapter.title.toLowerCase().contains(search) ||
            chapter.chapterIndex.toString().contains(search))
        .toList();
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
    setState(() {
      if (_selectedIds.length == filtered.length && filtered.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(filtered.map((chapter) => chapter.id));
      }
    });
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
        title: const Text('重排序号'),
        content: const Text('确定按当前列表顺序重新生成章节序号（从 1 开始）吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          PrimaryButton(
            label: '重排',
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
        SnackBar(content: Text('保存章节失败：$err')),
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
        SnackBar(content: Text('移动章节失败：$err')),
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
              title: const Text('移动到作品'),
              content: SizedBox(
                width: 520,
                height: 520,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: '搜索作品',
                      ),
                      onChanged: (value) =>
                          setDialogState(() => search = value),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const EmptyState(
                              icon: Icons.menu_book_rounded,
                              title: '没有可移动的目标作品',
                              message: '请先创建或扫描其他作品。',
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
                                  subtitle: Text(book.author ?? '未知作者'),
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
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _chapterLocation(Chapter chapter) {
    final libraryName = _pathLibrary?.name ?? '未知存储库';
    final relativePath = _relativeChapterPath(chapter.path);
    return relativePath.isEmpty ? libraryName : '$libraryName / $relativePath';
  }

  String _safeDecodePath(String path) {
    try {
      return Uri.decodeComponent(path);
    } catch (_) {
      return path;
    }
  }

  String _normalizePath(String path) {
    return _safeDecodePath(path)
        .replaceAll('\\', '/')
        .replaceAllMapped(RegExp(r'([^:])/{2,}'), (match) => '${match[1]}/')
        .replaceAll(RegExp(r'/+$'), '');
  }

  String _stripOuterSlashes(String path) {
    return path.replaceAll(RegExp(r'^/+|/+$'), '');
  }

  String _joinDisplayPath(List<String?> parts) {
    return parts
        .map((part) => _stripOuterSlashes(part ?? ''))
        .where((part) => part.isNotEmpty)
        .join('/');
  }

  String _pathName(String path) {
    final parts = _stripOuterSlashes(_normalizePath(path))
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? path : parts.last;
  }

  String? _relativeFromRoot(String path, String? root) {
    final normalizedPath = _normalizePath(path);
    final normalizedRoot = _normalizePath(root ?? '');
    if (normalizedRoot.isEmpty || normalizedRoot == '/') return null;

    final lowerPath = normalizedPath.toLowerCase();
    final lowerRoot = normalizedRoot.toLowerCase();
    if (lowerPath == lowerRoot) return '';
    if (lowerPath.startsWith('$lowerRoot/')) {
      return _stripOuterSlashes(
        normalizedPath.substring(normalizedRoot.length + 1),
      );
    }
    return null;
  }

  String? _relativeFromPathSegment(String path, String? segment) {
    final pathParts = _stripOuterSlashes(_normalizePath(path))
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    final segmentParts = _stripOuterSlashes(_normalizePath(segment ?? ''))
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (segmentParts.isEmpty || segmentParts.length > pathParts.length) {
      return null;
    }

    final lowerPathParts = pathParts.map((part) => part.toLowerCase()).toList();
    final lowerSegmentParts =
        segmentParts.map((part) => part.toLowerCase()).toList();
    for (var i = 0; i <= pathParts.length - segmentParts.length; i++) {
      var matched = true;
      for (var j = 0; j < segmentParts.length; j++) {
        if (lowerPathParts[i + j] != lowerSegmentParts[j]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return pathParts.skip(i + segmentParts.length).join('/');
      }
    }
    return null;
  }

  String _relativeChapterPath(String chapterPath) {
    final library = _pathLibrary;
    final roots = <String>[];
    if (library != null) {
      if (library.libraryType == 'webdav') {
        roots.add(_joinDisplayPath([library.url, library.rootPath]));
      }
      if ((library.url ?? '').isNotEmpty) roots.add(library.url!);
      if (library.rootPath.isNotEmpty) roots.add(library.rootPath);
    }

    roots.sort((a, b) => b.length.compareTo(a.length));
    for (final root in roots) {
      final relativePath = _relativeFromRoot(chapterPath, root);
      if (relativePath != null) return relativePath;
    }

    if (library?.libraryType == 'local') {
      for (final segment in [library?.url, library?.rootPath]) {
        final relativePath = _relativeFromPathSegment(chapterPath, segment);
        if (relativePath != null) return relativePath;
      }
    }

    final bookPath = widget.book.path;
    if (bookPath != null && bookPath.isNotEmpty) {
      final relativeToBook = _relativeFromRoot(chapterPath, bookPath);
      if (relativeToBook != null) {
        return _joinDisplayPath([_pathName(bookPath), relativeToBook]);
      }
    }

    final normalizedPath = _normalizePath(chapterPath);
    if (!normalizedPath.contains(':') && !normalizedPath.startsWith('/')) {
      return _stripOuterSlashes(normalizedPath);
    }
    return _pathName(chapterPath);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredChapters;
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 32,
        vertical: compact ? 12 : 24,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1024,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: context.isDark ? 0.36 : 0.18),
                blurRadius: 32,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 18,
                    compact ? 12 : 18, compact ? 12 : 16),
                child: Row(
                  children: [
                    const Text(
                      '章节管理',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      fit: FlexFit.loose,
                      child: SizedBox(
                        width: compact ? double.infinity : 260,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.isDark
                                ? AppColors.slate800
                                : AppColors.slate100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search_rounded, size: 18),
                              hintText: '搜索章节...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 11),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _saving || _moving
                          ? null
                          : () => Navigator.pop(context),
                      color: AppColors.slate500,
                      iconSize: 24,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 24,
                  vertical: compact ? 12 : 16,
                ),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? AppColors.slate900
                      : AppColors.slate50.withValues(alpha: 0.8),
                  border: Border.symmetric(
                    horizontal: BorderSide(color: context.faintBorder),
                  ),
                ),
                child: Row(
                  children: [
                    _ChapterManagerToolbarButton(
                      selected: _selectionMode,
                      icon: _selectionMode
                          ? Icons.check_box_rounded
                          : Icons.playlist_add_check_rounded,
                      label: _selectionMode ? '完成' : '选择',
                      onPressed: () {
                        setState(() {
                          _selectionMode = !_selectionMode;
                          if (!_selectionMode) _selectedIds.clear();
                        });
                      },
                    ),
                    if (_selectionMode) ...[
                      const SizedBox(width: 12),
                      BatchSelectButton(
                        checked: _selectedIds.length == filtered.length &&
                            filtered.isNotEmpty,
                        label: '全选 (${filtered.length})',
                        compact: compact,
                        onPressed: filtered.isEmpty ? null : _toggleAll,
                      ),
                      const SizedBox(width: 8),
                      BatchCountBadge(
                        label: '已选 ${_selectedIds.length}',
                        compact: compact,
                      ),
                    ],
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _renumber,
                      icon: const Icon(Icons.format_list_numbered_rounded),
                      label: Text(compact ? '重排' : '重排序号'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _selectionMode && _selectedIds.isNotEmpty
                          ? _moveSelected
                          : null,
                      icon: _moving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: Text(compact ? '移动' : '移动到...'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: '没有匹配章节',
                        message: '换一个关键词试试。',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final chapter = filtered[index];
                          final selected = _selectedIds.contains(chapter.id);
                          final changed = _changedIds.contains(chapter.id);
                          return _ChapterManagerRow(
                            key: ValueKey(chapter.id),
                            chapter: chapter,
                            selected: selected,
                            changed: changed,
                            selectionMode: _selectionMode,
                            location: _chapterLocation(chapter),
                            onSelected: () => _toggleSelection(chapter.id),
                            onTitleChanged: (value) => _replaceChapter(
                              chapter.id,
                              (item) => item.copyWith(title: value),
                            ),
                            onIndexChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed == null) return;
                              _replaceChapter(
                                chapter.id,
                                (item) => item.copyWith(chapterIndex: parsed),
                              );
                            },
                            onExtraChanged: (value) => _replaceChapter(
                              chapter.id,
                              (item) => item.copyWith(isExtra: value),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 24,
                  16,
                  compact ? 16 : 24,
                  22,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.faintBorder)),
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      onPressed: _saving || _moving
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 10),
                    PrimaryButton(
                      label: '保存更改 (${_changedIds.length})',
                      icon: Icons.save_rounded,
                      loading: _saving,
                      onPressed: _changedIds.isEmpty ? null : _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterManagerRow extends StatelessWidget {
  const _ChapterManagerRow({
    super.key,
    required this.chapter,
    required this.selected,
    required this.changed,
    required this.selectionMode,
    required this.location,
    required this.onSelected,
    required this.onTitleChanged,
    required this.onIndexChanged,
    required this.onExtraChanged,
  });

  final Chapter chapter;
  final bool selected;
  final bool changed;
  final bool selectionMode;
  final String location;
  final VoidCallback onSelected;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onIndexChanged;
  final ValueChanged<bool> onExtraChanged;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? AppColors.primary50
        : changed
            ? const Color(0xfffffbeb)
            : context.cardColor;
    final borderColor = selected
        ? AppColors.primary200
        : changed
            ? const Color(0xfffde68a)
            : context.faintBorder;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.isDark ? context.cardColor : background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: context.isDark ? context.faintBorder : borderColor),
      ),
      child: Row(
        children: [
          if (selectionMode) ...[
            BatchCheckbox(
              checked: selected,
              compact: MediaQuery.sizeOf(context).width < 640,
              tooltip: selected ? '取消选择' : '选择章节',
              onChanged: onSelected,
            ),
            const SizedBox(width: 4),
          ],
          SizedBox(
            width: 64,
            child: TextFormField(
              initialValue: chapter.chapterIndex.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.mutedText,
                fontSize: context.adaptiveFont(13, 13),
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary500),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              onChanged: onIndexChanged,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: chapter.title,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: '章节标题',
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onTitleChanged,
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => onExtraChanged(!chapter.isExtra),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: chapter.isExtra
                    ? const Color(0xfffaf5ff)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: chapter.isExtra
                      ? const Color(0xffe9d5ff)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                '番外',
                style: TextStyle(
                  color: chapter.isExtra
                      ? const Color(0xff9333ea)
                      : context.mutedText,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 980) ...[
            const SizedBox(width: 14),
            SizedBox(
              width: 260,
              child: Tooltip(
                message: location,
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_rounded,
                      size: 14,
                      color: context.tertiaryText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.tertiaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChapterManagerToolbarButton extends StatelessWidget {
  const _ChapterManagerToolbarButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.primary600 : context.cardColor,
        foregroundColor: selected ? Colors.white : context.mutedText,
        side: BorderSide(
          color: selected ? AppColors.primary600 : context.faintBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
