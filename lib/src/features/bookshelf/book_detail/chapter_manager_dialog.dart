import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/state/books_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/locale.dart';
import '../../../shared/app_scope.dart';
import '../../../shared/common/common_widgets.dart';
import '../../../shared/cards/book_card.dart';
import '../../../shared/dialogs/text_input_dialog.dart';
import '../book_picker_dialog.dart';
import '../../../shared/common/chapter_type_selector.dart';

part 'chapter_editor_sheet.dart';

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

  late final ChapterEditDraft _draft;
  List<Chapter> get _chapters => _draft.chapters;
  Set<String> get _changedIds => _draft.changedIds;
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
    _draft = ChapterEditDraft(widget.chapters);
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

  List<Chapter> get _tabChapters => _draft.forTab(_activeChapterTab);
  List<Chapter> get _filteredChapters => _draft.filter(
      _activeChapterTab, _searchController.text, _chapterDisplayPath);
  int get _mainChapterCount => _draft.count('main');
  int get _extraChapterCount => _draft.count('extra');

  void _setChapterTab(String tab) {
    if (_activeChapterTab == tab) return;
    setState(() {
      _activeChapterTab = tab;
      _groupIndex = 0;
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  void _replaceChapter(String id, Chapter Function(Chapter) update) =>
      setState(() => _draft.update(id, update));

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
    final operationsValue = _operations;
    if (operationsValue == null) {
      throw StateError('Chapter manager has not initialized');
    }
    try {
      final res = await operationsValue.run((token) =>
          operationsValue.api.get('/api/libraries', cancelToken: token));
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
    setState(_draft.renumber);
  }

  Future<void> _save() async {
    final operationsValue = _operations;
    if (operationsValue == null) {
      throw StateError('Chapter manager has not initialized');
    }
    if (_changedIds.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await operationsValue.run((token) => operationsValue.api.put(
            '/api/books/${Uri.encodeComponent(widget.book.id)}/chapters/batch',
            data: {'updates': _draft.updates},
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
    final operationsValue = _operations;
    if (operationsValue == null) {
      throw StateError('Chapter manager has not initialized');
    }
    if (_selectedIds.isEmpty || _moving) return;
    setState(() => _moving = true);
    try {
      final target = await _pickTargetBook();
      if (target == null || !mounted) return;
      await operationsValue.run((token) => operationsValue.api.post(
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
    final operationsValue = _operations;
    if (operationsValue == null) {
      throw StateError('Chapter manager has not initialized');
    }
    final appState = AppScope.appOf(context);
    final res = await operationsValue.run(
        (token) => operationsValue.api.get('/api/books', cancelToken: token));
    final books = asMapList(res.data)
        .map(Book.fromJson)
        .where((book) => book.id != widget.book.id)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    if (!mounted) return null;
    return showDialog<Book>(
      context: context,
      builder: (context) => BookPickerDialog(
        title: context.localeText('移动到作品', 'Move to Book'),
        books: books,
        existingIds: const {},
        coverShape: coverShapeFromAppSettings(appState.settings),
      ),
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
  Future<void> _jumpToChapter() async {
    final value = await showTextInputDialog(
      context,
      title: context.localeText('跳转到章节', 'Jump to Chapter'),
      action: context.localeText('跳转', 'Jump'),
      hint: context.localeText('输入章节序号', 'Enter chapter number'),
      keyboardType: TextInputType.number,
    );
    if (!mounted) return;
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
                            ChapterTypeSelector(
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
