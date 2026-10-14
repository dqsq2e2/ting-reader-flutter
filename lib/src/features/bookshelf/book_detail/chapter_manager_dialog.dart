import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/state/books_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/locale.dart';
import '../../../core/utils/urls.dart';
import '../../../shared/app_scope.dart';
import '../../../shared/common/common_widgets.dart';
import '../../../shared/common/media_widgets.dart';

class ChapterManagerDialog extends StatefulWidget {
  const ChapterManagerDialog({
    super.key,
    required this.book,
    required this.chapters,
  });

  final Book book;
  final List<Chapter> chapters;

  @override
  State<ChapterManagerDialog> createState() => ChapterManagerDialogState();
}

class ChapterManagerDialogState extends State<ChapterManagerDialog> {
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
  BookOperations? _operations;

  @override
  void initState() {
    super.initState();
    _chapters = [...widget.chapters]
      ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_operations != null) return;
    _operations = BookOperations(AppScope.appOf(context).api);
    _loadPathContext();
  }

  @override
  void dispose() {
    _operations?.dispose();
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
      final res = await _operations!.run((token) =>
          _operations!.api.get('/api/libraries', cancelToken: token));
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
    if (confirmed != true || !mounted) return;
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
      await _operations!.run((token) => _operations!.api.put(
            '/api/books/${Uri.encodeComponent(widget.book.id)}/chapters/batch',
            data: {'updates': updates},
            cancelToken: token,
          ));
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
    setState(() => _moving = true);
    try {
      final target = await _pickTargetBook();
      if (target == null || !mounted) return;
      await _operations!.run((token) => _operations!.api.post(
            '/api/books/chapters/move',
            data: {
              'target_book_id': target.id,
              'chapter_ids': _selectedIds.toList(),
            },
            cancelToken: token,
          ));
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
    final res = await _operations!
        .run((token) => _operations!.api.get('/api/books', cancelToken: token));
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

extension _ChapterManagerLayout on ChapterManagerDialogState {
  Future<void> _jumpToChapter() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.localeText('跳转到章节', 'Jump to Chapter')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.tag_rounded),
            hintText: context.localeText('输入章节序号', 'Enter chapter number'),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          PrimaryButton(
            label: context.localeText('跳转', 'Jump'),
            icon: Icons.subdirectory_arrow_right_rounded,
            onPressed: () => Navigator.pop(context, controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    final target = int.tryParse((value ?? '').trim());
    if (target == null) return;
    final chapters = _tabChapters;
    if (chapters.isEmpty) return;
    var targetIndex =
        chapters.indexWhere((chapter) => chapter.chapterIndex >= target);
    if (targetIndex < 0) targetIndex = chapters.length - 1;
    _updateState(() {
      _searchController.clear();
      _groupIndex = targetIndex ~/ ChapterManagerDialogState._groupSize;
    });
  }

  Future<void> _editChapter(Chapter chapter) async {
    final current = _chapters.firstWhere(
      (item) => item.id == chapter.id,
      orElse: () => chapter,
    );
    final result = await showModalBottomSheet<_ChapterEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChapterEditSheet(
        chapter: current,
        libraryName: _pathLibrary?.name ??
            context.localeText('未知存储库', 'Unknown Library'),
        displayPath: _chapterDisplayPath(current.path),
      ),
    );
    if (result == null || !mounted) return;
    _replaceChapter(
      current.id,
      (item) => item.copyWith(
        title: result.title,
        chapterIndex: result.chapterIndex,
        isExtra: result.isExtra,
      ),
    );
  }

  Widget _buildResponsiveDialog(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final compact = size.width < 640;
    final filtered = _filteredChapters;
    final allFilteredSelected = filtered.isNotEmpty &&
        filtered.every((item) => _selectedIds.contains(item.id));
    final groupCount = math.max(
      1,
      (filtered.length / ChapterManagerDialogState._groupSize).ceil(),
    );
    final groupIndex = _groupIndex.clamp(0, groupCount - 1).toInt();
    final start = groupIndex * ChapterManagerDialogState._groupSize;
    final visible = filtered
        .skip(start)
        .take(ChapterManagerDialogState._groupSize)
        .toList();
    final showChapterTypeSwitch =
        _mainChapterCount > 0 && _extraChapterCount > 0;
    final showChapterGroups = groupCount > 1;
    final maxHeight = compact ? size.height - safe.top - 24 : size.height * 0.9;
    final maxWidth = compact ? 560.0 : 920.0;
    final insetPadding = compact
        ? EdgeInsets.fromLTRB(8, safe.top + 12, 8, 8)
        : const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    final canSave = _changedIds.isNotEmpty && !_saving;
    final saveButton = ElevatedButton.icon(
      onPressed: canSave ? _save : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            context.isDark ? AppColors.slate800 : AppColors.slate100,
        disabledForegroundColor: context.mutedText,
        elevation: 0,
        minimumSize: Size(0, compact ? 40 : 38),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 18,
          vertical: compact ? 11 : 10,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: _saving
          ? SizedBox.square(
              dimension: compact ? 15 : 16,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.save_rounded, size: compact ? 16 : 17),
      label: Text(
        _saving
            ? context.localeText('保存中...', 'Saving...')
            : context.localeText(
                '保存更改 (${_changedIds.length})', 'Save (${_changedIds.length})'),
        style: TextStyle(
          fontSize: compact ? 13 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Dialog(
        insetPadding: insetPadding,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: context.isDark ? 0.34 : 0.18),
                  blurRadius: 26,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 24,
                    compact ? 18 : 22,
                    compact ? 10 : 18,
                    compact ? 12 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            context.localeText('章节管理', 'Chapter Manager'),
                            style: TextStyle(
                              fontSize: compact ? 22 : 24,
                              fontWeight: FontWeight.w700,
                              height: 1.12,
                              color: context.primaryText,
                            ),
                          ),
                          if (showChapterTypeSwitch) ...[
                            SizedBox(width: compact ? 10 : 12),
                            _ChapterTypeSwitch(
                              activeTab: _activeChapterTab,
                              mainCount: _mainChapterCount,
                              extraCount: _extraChapterCount,
                              compact: compact,
                              onChanged: _setChapterTab,
                            ),
                          ],
                          const Spacer(),
                          IconButton(
                            tooltip: context.localeText('关闭', 'Close'),
                            onPressed: _requestClose,
                            color: AppColors.slate500,
                            iconSize: compact ? 26 : 28,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 10 : 12),
                      _ChapterManagerSearchField(
                        controller: _searchController,
                        hintText: context.localeText(
                            '搜索章节、序号', 'Search chapters or index'),
                        onChanged: (_) => _updateState(() => _groupIndex = 0),
                      ),
                      if (showChapterGroups) ...[
                        const SizedBox(height: 12),
                        _ChapterGroups(
                          total: filtered.length,
                          groupSize: ChapterManagerDialogState._groupSize,
                          groupIndex: groupIndex,
                          onGroupChanged: (index) =>
                              _updateState(() => _groupIndex = index),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 16 : 24,
                    vertical: compact ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? AppColors.slate900
                        : AppColors.slate50.withValues(alpha: 0.9),
                    border: Border.symmetric(
                      horizontal: BorderSide(color: context.faintBorder),
                    ),
                  ),
                  child: _selectionMode
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            BatchActionButton(
                              label: context.localeText('完成', 'Done'),
                              icon: Icons.check_rounded,
                              filled: true,
                              compact: compact,
                              onPressed: () {
                                _updateState(() {
                                  _selectionMode = false;
                                  _selectedIds.clear();
                                });
                              },
                            ),
                            BatchSelectButton(
                              checked: allFilteredSelected,
                              label: context.localeText('全选 ${filtered.length}',
                                  'All ${filtered.length}'),
                              compact: compact,
                              onPressed: filtered.isEmpty ? null : _toggleAll,
                            ),
                            BatchCountBadge(
                              label: context.localeText(
                                  '已选 ${_selectedIds.length}',
                                  'Selected ${_selectedIds.length}'),
                              compact: compact,
                            ),
                            BatchActionButton(
                              label: context.localeText('移动', 'Move'),
                              icon: Icons.arrow_forward_rounded,
                              compact: compact,
                              onPressed: _selectedIds.isEmpty || _moving
                                  ? null
                                  : _moveSelected,
                            ),
                          ],
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            BatchActionButton(
                              label: context.localeText('选择', 'Select'),
                              icon: Icons.checklist_rounded,
                              compact: compact,
                              onPressed: filtered.isEmpty
                                  ? null
                                  : () => _updateState(
                                        () => _selectionMode = true,
                                      ),
                            ),
                            BatchActionButton(
                              label: context.localeText('重排', 'Renumber'),
                              icon: Icons.format_list_numbered_rounded,
                              compact: compact,
                              onPressed: _renumber,
                            ),
                            BatchActionButton(
                              label: context.localeText('跳转', 'Jump'),
                              icon: Icons.subdirectory_arrow_right_rounded,
                              compact: compact,
                              onPressed: _jumpToChapter,
                            ),
                          ],
                        ),
                ),
                Expanded(
                  child: Container(
                    color: context.isDark
                        ? AppColors.slate900.withValues(alpha: 0.18)
                        : AppColors.slate50.withValues(alpha: 0.38),
                    child: visible.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off_rounded,
                            title: context.localeText(
                                '没有匹配章节', 'No Matching Chapters'),
                            message: context.localeText('换一个关键词或切换正文/番外试试。',
                                'Try another keyword or switch chapter type.'),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 12 : 20,
                              compact ? 10 : 12,
                              compact ? 12 : 20,
                              compact ? 12 : 16,
                            ),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: compact ? 6 : 7),
                            itemBuilder: (context, index) {
                              final chapter = visible[index];
                              return _ManagerChapterRow(
                                chapter: chapter,
                                selected: _selectedIds.contains(chapter.id),
                                changed: _changedIds.contains(chapter.id),
                                selectionMode: _selectionMode,
                                onSelected: () => _toggleSelection(chapter.id),
                                onEdit: () => _editChapter(chapter),
                              );
                            },
                          ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 18 : 24,
                      12,
                      compact ? 18 : 24,
                      compact ? 14 : 18,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      border:
                          Border(top: BorderSide(color: context.faintBorder)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (compact) ...[
                          TextButton(
                            onPressed: _requestClose,
                            child: Text(context.l10n.commonCancel),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: saveButton)
                        ] else ...[
                          const Spacer(),
                          TextButton(
                            onPressed: _requestClose,
                            child: Text(context.l10n.commonCancel),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(width: 210, child: saveButton),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterGroups extends StatelessWidget {
  const _ChapterGroups({
    required this.total,
    required this.groupSize,
    required this.groupIndex,
    required this.onGroupChanged,
  });

  final int total;
  final int groupSize;
  final int groupIndex;
  final ValueChanged<int> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    final groupCount = (total / groupSize).ceil();
    if (groupCount <= 1) return const SizedBox.shrink();

    return HorizontalScrollControls(
      child: Row(
        children: [
          for (var i = 0; i < groupCount; i++) ...[
            _ChapterRangeChip(
              label: _labelFor(context, i),
              selected: i == groupIndex,
              onTap: () => onGroupChanged(i),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _labelFor(BuildContext context, int index) {
    final start = index * groupSize + 1;
    final end = math.min((index + 1) * groupSize, total);
    if (total == 0) return '0';
    return context.localeText('第 $start-$end 章', 'Ch. $start-$end');
  }
}

class _ChapterRangeChip extends StatelessWidget {
  const _ChapterRangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final foreground = selected ? Colors.white : context.secondaryText;
    return Material(
      color: selected
          ? AppColors.primary600
          : (context.isDark ? AppColors.slate800 : context.cardColor),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 13,
            vertical: compact ? 8 : 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? AppColors.primary600 : context.faintBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 12 : 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerChapterRow extends StatelessWidget {
  const _ManagerChapterRow({
    required this.chapter,
    required this.selected,
    required this.changed,
    required this.selectionMode,
    required this.onSelected,
    required this.onEdit,
  });

  final Chapter chapter;
  final bool selected;
  final bool changed;
  final bool selectionMode;
  final VoidCallback onSelected;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final background = selected
        ? AppColors.primary50
        : changed
            ? const Color(0xfffffbeb)
            : (context.isDark
                ? AppColors.slate900.withValues(alpha: 0.6)
                : Colors.white);
    final borderColor = selected
        ? AppColors.primary300
        : changed
            ? const Color(0xfffde68a)
            : context.faintBorder.withValues(alpha: 0.62);
    return Material(
      color: context.isDark ? context.cardColor : background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: selectionMode ? onSelected : onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 12,
            compact ? 9 : 10,
            compact ? 8 : 10,
            compact ? 9 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.isDark ? context.faintBorder : borderColor,
            ),
          ),
          child: Row(
            children: [
              if (selectionMode) ...[
                BatchCheckbox(
                  checked: selected,
                  compact: compact,
                  onChanged: onSelected,
                ),
                const SizedBox(width: 6),
              ],
              Container(
                constraints: BoxConstraints(minWidth: compact ? 34 : 40),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 9,
                  vertical: compact ? 7 : 8,
                ),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? AppColors.slate800
                      : AppColors.primary50.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${chapter.chapterIndex}',
                  style: TextStyle(
                    color: AppColors.primary600,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w400,
                          height: 1.22,
                        ),
                      ),
                    ),
                    if (changed) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffecfeff),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.localeText('已修改', 'Changed'),
                          style: const TextStyle(
                            color: AppColors.primary600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!selectionMode) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: context.localeText('编辑章节', 'Edit Chapter'),
                  child: Material(
                    color: context.isDark
                        ? AppColors.slate800
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox.square(
                        dimension: compact ? 32 : 34,
                        child: Icon(
                          Icons.edit_rounded,
                          size: compact ? 16 : 17,
                          color: context.secondaryText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterManagerSearchField extends StatelessWidget {
  const _ChapterManagerSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).width < 640 ? 42 : 44,
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, size: 19),
          hintText: hintText,
          hintStyle: TextStyle(
            color: context.mutedText,
            fontSize: MediaQuery.sizeOf(context).width < 640 ? 14 : 15,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _ChapterTypeSwitch extends StatelessWidget {
  const _ChapterTypeSwitch({
    required this.activeTab,
    required this.mainCount,
    required this.extraCount,
    required this.compact,
    required this.onChanged,
  });

  final String activeTab;
  final int mainCount;
  final int extraCount;
  final bool compact;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate900 : AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.faintBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChapterTypeSwitchItem(
            label: compact
                ? context.localeText('正文', 'Main')
                : context.localeText('正文 $mainCount', 'Main $mainCount'),
            selected: activeTab == 'main',
            compact: compact,
            onTap: () => onChanged('main'),
          ),
          _ChapterTypeSwitchItem(
            label: compact
                ? context.localeText('番外', 'Extra')
                : context.localeText('番外 $extraCount', 'Extra $extraCount'),
            selected: activeTab == 'extra',
            compact: compact,
            onTap: () => onChanged('extra'),
          ),
        ],
      ),
    );
  }
}

class _ChapterTypeSwitchItem extends StatelessWidget {
  const _ChapterTypeSwitchItem({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : context.secondaryText;
    return Material(
      color: selected ? AppColors.primary600 : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 14,
            vertical: compact ? 6 : 7,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 12 : 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterEditResult {
  const _ChapterEditResult({
    required this.title,
    required this.chapterIndex,
    required this.isExtra,
  });

  final String title;
  final int chapterIndex;
  final bool isExtra;
}

class _ChapterEditSheet extends StatefulWidget {
  const _ChapterEditSheet({
    required this.chapter,
    required this.libraryName,
    required this.displayPath,
  });

  final Chapter chapter;
  final String libraryName;
  final String displayPath;

  @override
  State<_ChapterEditSheet> createState() => _ChapterEditSheetState();
}

class _ChapterEditSheetState extends State<_ChapterEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _indexController;
  late bool _isExtra;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.chapter.title);
    _indexController =
        TextEditingController(text: widget.chapter.chapterIndex.toString());
    _isExtra = widget.chapter.isExtra;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _indexController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final index = int.tryParse(_indexController.text.trim());
    if (title.isEmpty || index == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.localeText(
                '请填写标题和有效序号', 'Enter a title and valid index'))),
      );
      return;
    }
    Navigator.pop(
      context,
      _ChapterEditResult(
        title: title,
        chapterIndex: index,
        isExtra: _isExtra,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.localeText('编辑章节', 'Edit Chapter'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.localeText('关闭', 'Close'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: context.localeText('标题', 'Title'),
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _indexController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.localeText('序号', 'Index'),
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                _ChapterEditTypeSwitch(
                  isExtra: _isExtra,
                  onChanged: (value) => setState(() => _isExtra = value),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        context.isDark ? AppColors.slate900 : AppColors.slate50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.faintBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.localeText('文件来源', 'File Source'),
                        style: TextStyle(
                          color: context.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ChapterEditMetaRow(
                        icon: Icons.storage_rounded,
                        label: context.localeText('存储库', 'Library'),
                        value: widget.libraryName,
                      ),
                      const SizedBox(height: 8),
                      _ChapterEditMetaRow(
                        icon: Icons.folder_rounded,
                        label: context.localeText('存储位置', 'Location'),
                        value: widget.displayPath.isEmpty
                            ? context.localeText('未识别', 'Unknown')
                            : widget.displayPath,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.l10n.commonCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: context.localeText('保存此章节', 'Save Chapter'),
                        icon: Icons.save_rounded,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterEditTypeSwitch extends StatelessWidget {
  const _ChapterEditTypeSwitch({
    required this.isExtra,
    required this.onChanged,
  });

  final bool isExtra;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate900 : AppColors.slate100,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: context.faintBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ChapterEditTypeItem(
              label: context.localeText('正文', 'Main'),
              selected: !isExtra,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ChapterEditTypeItem(
              label: context.localeText('番外', 'Extra'),
              selected: isExtra,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterEditTypeItem extends StatelessWidget {
  const _ChapterEditTypeItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary600 : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : context.secondaryText,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterEditMetaRow extends StatelessWidget {
  const _ChapterEditMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.tertiaryText),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(color: context.mutedText, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
