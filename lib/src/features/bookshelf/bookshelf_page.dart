import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/books_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';
import '../../shared/filter/display_filter_menu.dart';
import 'book_delete_dialog.dart';

part 'bookshelf_toolbar.dart';
part 'bookshelf_content.dart';

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({
    super.key,
    required this.openBook,
    required this.openSeries,
    required this.openLibraries,
    required this.openSearch,
  });

  final ValueChanged<String> openBook;
  final ValueChanged<String> openSeries;
  final VoidCallback openLibraries;
  final VoidCallback openSearch;

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  static const int _pageSize = 50;

  BookshelfState? _shelf;
  bool get _loading => _shelf?.loading ?? true;
  List<Book> get _books => _shelf?.books ?? const [];
  List<Series> get _series => _shelf?.series ?? const [];
  List<Library> get _libraries => _shelf?.libraries ?? const [];
  String get _selectedLibraryId => _shelf?.selectedLibrary ?? '';
  set _selectedLibraryId(String value) {
    _shelf?.selectedLibrary = value;
  }

  String get _sortBy => _shelf?.sortBy ?? 'created_at';
  set _sortBy(String value) {
    _shelf?.sortBy = value;
  }

  IconSizeSetting _iconSize = IconSizeSetting.medium;
  CoverShape _coverShape = CoverShape.square;
  BookshelfViewMode _viewMode = BookshelfViewMode.grid;
  bool _showFilterMenu = false;
  bool _selectionMode = false;
  bool _deletingBooks = false;
  bool _deletingSeries = false;
  bool _updatingReadStatus = false;
  final Set<String> _selectedBookIds = {};
  final Set<String> _selectedSeriesIds = {};
  final LayerLink _filterMenuLink = LayerLink();
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _filterOverlay;
  int _visibleCount = _pageSize;
  final Map<String, GlobalKey> _groupSectionKeys = {};
  String? _activeLetter;
  bool _indexBarTouchActive = false;
  Timer? _indexOverlayTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _shelf?.removeListener(_shelfChanged);
    _shelf?.dispose();
    _indexOverlayTimer?.cancel();
    _filterOverlay?.remove();
    _scrollController
      ..removeListener(_loadMoreWhenNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreWhenNeeded() {
    if (!_scrollController.hasClients || _loading) return;
    if (_scrollController.position.extentAfter > 800) return;
    final totalCount = _filteredBooks.length + _filteredSeries.length;
    if (_visibleCount >= totalCount) return;
    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(0, totalCount);
    });
  }

  void _resetVisibleItems() {
    _visibleCount = _pageSize;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shelf ??= BookshelfState(AppScope.appOf(context).api)
      ..addListener(_shelfChanged);
  }

  void _shelfChanged() {
    if (!mounted) return;
    setState(() {
      final settings = _shelf?.settings ?? const <String, dynamic>{};
      _iconSize = iconSizeFromAppSettings(settings);
      _coverShape = coverShapeFromAppSettings(settings);
      _viewMode = settings['bookshelf_view_mode'] == 'list'
          ? BookshelfViewMode.list
          : BookshelfViewMode.grid;
      _selectedBookIds.retainAll(_books.map((book) => book.id));
      _selectedSeriesIds.retainAll(_series.map((series) => series.id));
    });
  }

  Future<void> _load() async {
    await _shelf?.load();
    if (mounted) setState(_resetVisibleItems);
  }

  Future<void> _persist(String key, Object value) async {
    await AppScope.appOf(context).updateSettings({key: value});
  }

  Future<void> _markSelectedRead(bool read) async {
    if (_selectedBookIds.isEmpty || _updatingReadStatus) return;
    if (!read) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(context.localeText('确认标记未读', 'Mark as unread?')),
          content: Text(context.localeText(
              '将所选 ${_selectedBookIds.length} 本书标记为未读，同时清除这些书籍的全部播放进度。确定继续吗？',
              'Mark the ${_selectedBookIds.length} selected books as unread and clear all their playback progress. Continue?')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.commonCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.localeText('标记未读', 'Mark as unread'))),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    setState(() => _updatingReadStatus = true);
    try {
      await _shelf?.operations.markRead(_selectedBookIds.toList(), read);
      if (!mounted) return;
      setState(() => _selectedBookIds.clear());
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.localeText(
                  '更新阅读状态失败：$error', 'Failed to update read status: $error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingReadStatus = false);
    }
  }

  List<Book> get _filteredBooks => _shelf?.filteredBooks ?? const [];
  List<Series> get _filteredSeries => _shelf?.filteredSeries ?? const [];
  ({List<String> keys, Map<String, List<Object>> groups})? get _groupedContent {
    final content = _shelf?.groupedContent;
    final keys = content?.keys.toSet() ?? <String>{};
    _groupSectionKeys.removeWhere((key, _) => !keys.contains(key));
    for (final key in keys) {
      _groupSectionKeys.putIfAbsent(key, GlobalKey.new);
    }
    return content;
  }

  void _scrollToGroup(String key) {
    final grouped = _groupedContent;
    if (grouped == null) return;

    // The list is paged, so render up to the target group before scrolling.
    var needed = 0;
    for (final groupKey in grouped.keys) {
      needed += (grouped.groups[groupKey] ?? const <Book>[]).length;
      if (groupKey == key) break;
    }
    setState(() {
      _activeLetter = key;
      if (_visibleCount < needed) _visibleCount = needed;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _groupSectionKeys[key]?.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: 0.02,
      );
    });
  }

  void _beginIndexBarTouch() {
    _indexOverlayTimer?.cancel();
    if (!_indexBarTouchActive) {
      setState(() => _indexBarTouchActive = true);
    }
  }

  void _endIndexBarTap() {
    _indexOverlayTimer?.cancel();
    _indexOverlayTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _indexBarTouchActive = false;
        _activeLetter = null;
      });
    });
  }

  void _endIndexBarTouch() {
    _indexOverlayTimer?.cancel();
    if (!_indexBarTouchActive) return;
    setState(() => _indexBarTouchActive = false);
    _indexOverlayTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted && !_indexBarTouchActive && _activeLetter != null) {
        setState(() => _activeLetter = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeLetterValue = _activeLetter;
    if (_loading) return const LoadingView();
    if (_shelf?.error != null) return LoadErrorView(onRetry: _load);
    final appState = AppScope.appOf(context);
    final hasContent = _books.isNotEmpty || _series.isNotEmpty;
    final grouped = _groupedContent;
    final hasFilteredContent =
        _filteredBooks.isNotEmpty || _filteredSeries.isNotEmpty;

    final list = PageListView(
      controller: _scrollController,
      onRefresh: _load,
      children: [
        _Header(
          selectionMode: _selectionMode,
          selectedBookCount: _selectedBookIds.length,
          selectedSeriesCount: _selectedSeriesIds.length,
          libraries: _libraries,
          selectedLibraryId: _selectedLibraryId,
          showFilterMenu: _showFilterMenu,
          filterMenuLink: _filterMenuLink,
          deletingItems: _deletingBooks || _deletingSeries,
          updatingReadStatus: _updatingReadStatus,
          onSearchOpen: widget.openSearch,
          onLibraryChanged: (value) async {
            setState(() {
              _selectedLibraryId = value ?? '';
              _showFilterMenu = false;
            });
            _closeFilterMenu();
            await _persist('bookshelf_library_id', _selectedLibraryId);
            await _load();
          },
          onToggleFilterMenu: _toggleFilterMenu,
          onSelectionMode: () {
            _closeFilterMenu();
            setState(() {
              _selectionMode = true;
              _selectedBookIds.clear();
              _selectedSeriesIds.clear();
            });
          },
          onCancelSelection: () {
            setState(() {
              _selectionMode = false;
              _selectedBookIds.clear();
              _selectedSeriesIds.clear();
            });
          },
          onSelectAll: _selectAllVisible,
          onCreateSeries: !appState.isAdmin ||
                  _selectedBookIds.isEmpty ||
                  _selectedSeriesIds.isNotEmpty ||
                  _deletingBooks ||
                  _deletingSeries
              ? null
              : _showCreateSeriesDialog,
          onDeleteSelected: !appState.isAdmin ||
                  (_selectedBookIds.isEmpty && _selectedSeriesIds.isEmpty) ||
                  _deletingBooks ||
                  _deletingSeries
              ? null
              : _showDeleteSelectedDialog,
          onMarkRead: _selectedBookIds.isNotEmpty && !_updatingReadStatus
              ? () => _markSelectedRead(true)
              : null,
          onMarkUnread: _selectedBookIds.isNotEmpty && !_updatingReadStatus
              ? () => _markSelectedRead(false)
              : null,
        ),
        const SizedBox(height: 10),
        if (!hasContent)
          EmptyState(
            icon: Icons.storage_rounded,
            title: context.localeText('书架空空如也', 'Your bookshelf is empty'),
            message: context.localeText('您还没有添加任何存储库，或者存储库中还没有扫描到音频文件。',
                'Add a library or scan audio files to start building your shelf.'),
            action: PrimaryButton(
              label: context.localeText('配置存储库', 'Configure Library'),
              icon: Icons.add_rounded,
              onPressed: widget.openLibraries,
            ),
          )
        else if (_filteredBooks.isEmpty && _filteredSeries.isEmpty)
          EmptyState(
            icon: Icons.search_off_rounded,
            title: context.localeText('未找到相关内容', 'No Matches'),
            message: context.localeText('换个关键词试试吧', 'Try another keyword.'),
          )
        else
          _ShelfContent(
            books: _filteredBooks,
            series: _filteredSeries,
            visibleCount: _visibleCount,
            groupKeys: grouped?.keys,
            groups: grouped?.groups,
            groupSectionKeys: _groupSectionKeys,
            iconSize: _iconSize,
            coverShape: _coverShape,
            viewMode: _viewMode,
            selectionMode: _selectionMode,
            selectedBookIds: _selectedBookIds,
            selectedSeriesIds: _selectedSeriesIds,
            onBook: (book) {
              if (_selectionMode) {
                setState(() {
                  _selectedBookIds.contains(book.id)
                      ? _selectedBookIds.remove(book.id)
                      : _selectedBookIds.add(book.id);
                });
              } else {
                widget.openBook(book.id);
              }
            },
            onSeries: (series) {
              if (_selectionMode) {
                setState(() {
                  _selectedSeriesIds.contains(series.id)
                      ? _selectedSeriesIds.remove(series.id)
                      : _selectedSeriesIds.add(series.id);
                });
              } else {
                widget.openSeries(series.id);
              }
            },
          ),
        const SafeBottomSpacer(),
      ],
    );

    // The default desktop scroll behavior adds an always-visible scrollbar;
    // the bookshelf uses the alphabet index bar for navigation instead.
    final content = ScrollConfiguration(
      behavior: const _NoScrollbarBehavior(),
      child: list,
    );

    if (grouped == null || !hasContent || !hasFilteredContent) {
      return content;
    }

    return Stack(
      children: [
        content,
        Positioned(
          right: 2,
          top: 0,
          bottom: 0,
          child: Center(
            child: _AlphabetIndexBar(
              keys: grouped.keys,
              activeKey: _indexBarTouchActive ? activeLetterValue : null,
              onTouchStart: _beginIndexBarTouch,
              onKeyTouch: (key) {
                if (key != activeLetterValue) _scrollToGroup(key);
              },
              onTapEnd: _endIndexBarTap,
              onTouchEnd: _endIndexBarTouch,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                reverseDuration: const Duration(milliseconds: 120),
                transitionBuilder: (child, animation) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.82, end: 1).animate(curved),
                      child: child,
                    ),
                  );
                },
                child: _indexBarTouchActive && activeLetterValue != null
                    ? Container(
                        key: ValueKey(activeLetterValue),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xff0f172a).withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          activeLetterValue,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey('index-overlay-empty')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _selectAllVisible() {
    final visibleBookIds = _filteredBooks.map((book) => book.id).toSet();
    final visibleSeriesIds = _filteredSeries.map((series) => series.id).toSet();
    if (visibleBookIds.isEmpty && visibleSeriesIds.isEmpty) return;
    setState(() {
      final allBooksSelected = visibleBookIds.every(_selectedBookIds.contains);
      final allSeriesSelected =
          visibleSeriesIds.every(_selectedSeriesIds.contains);
      if (allBooksSelected && allSeriesSelected) {
        _selectedBookIds.removeAll(visibleBookIds);
        _selectedSeriesIds.removeAll(visibleSeriesIds);
      } else {
        _selectedBookIds.addAll(visibleBookIds);
        _selectedSeriesIds.addAll(visibleSeriesIds);
      }
    });
  }

  void _toggleFilterMenu() {
    if (_filterOverlay != null) {
      _closeFilterMenu();
      return;
    }
    setState(() => _showFilterMenu = true);
    final overlay = OverlayEntry(
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
                      value: 'created_at',
                      label: context.localeText('最近添加', 'Recently Added'),
                    ),
                    DisplayFilterSortOption(
                      value: 'title',
                      label: context.localeText('书名排序', 'Title'),
                    ),
                    DisplayFilterSortOption(
                      value: 'author',
                      label: context.localeText('作者排序', 'Author'),
                    ),
                    DisplayFilterSortOption(
                      value: 'year',
                      label: context.localeText('年份排序', 'Year'),
                    ),
                  ],
                  iconSize: _iconSize,
                  coverShape: _coverShape,
                  viewMode: _viewMode,
                  onSortChanged: _changeSort,
                  onIconSizeChanged: _changeIconSize,
                  onCoverShapeChanged: _changeCoverShape,
                  onViewModeChanged: _changeViewMode,
                ),
              ),
            ],
          ),
        );
      },
    );
    _filterOverlay = overlay;
    Overlay.of(context).insert(overlay);
  }

  void _closeFilterMenu() {
    _filterOverlay?.remove();
    _filterOverlay = null;
    if (mounted && _showFilterMenu) {
      setState(() => _showFilterMenu = false);
    }
  }

  Future<void> _changeSort(String value) async {
    _closeFilterMenu();
    setState(() {
      _sortBy = value;
      _resetVisibleItems();
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _persist('bookshelf_sort_by', value);
  }

  Future<void> _changeIconSize(IconSizeSetting value) async {
    _closeFilterMenu();
    setState(() => _iconSize = value);
    await _persist('bookshelf_icon_size', value.name);
  }

  Future<void> _changeCoverShape(CoverShape value) async {
    _closeFilterMenu();
    setState(() => _coverShape = value);
    await _persist(
      'bookshelf_cover_shape',
      value == CoverShape.square ? 'square' : 'rect',
    );
  }

  Future<void> _changeViewMode(BookshelfViewMode value) async {
    _closeFilterMenu();
    setState(() => _viewMode = value);
    await _persist('bookshelf_view_mode', value.name);
  }

  Future<void> _showDeleteSelectedDialog() async {
    final selectedSeries = _series
        .where((series) => _selectedSeriesIds.contains(series.id))
        .toList();
    final selectedBooks =
        _books.where((book) => _selectedBookIds.contains(book.id)).toList();
    if ((selectedBooks.isEmpty && selectedSeries.isEmpty) ||
        _deletingBooks ||
        _deletingSeries) {
      return;
    }

    var deletedSeries = false;
    if (selectedSeries.isNotEmpty) {
      final confirmed = await _confirmDeleteSeries(selectedSeries);
      if (confirmed != true) return;
      if (!mounted) return;

      deletedSeries = await _deleteSeries(selectedSeries);
      if (!deletedSeries || !mounted) return;
      setState(() => _selectedSeriesIds.clear());
    }

    if (selectedBooks.isNotEmpty) {
      final deletedBooks = await _confirmAndDeleteBooks(selectedBooks);
      if (!deletedBooks && deletedSeries) await _load();
      return;
    }

    if (deletedSeries) {
      setState(() {
        _selectionMode = false;
        _selectedBookIds.clear();
        _selectedSeriesIds.clear();
      });
      await _load();
    }
  }

  Future<bool?> _confirmDeleteSeries(List<Series> selectedSeries) {
    if (selectedSeries.isEmpty) return Future.value(false);
    final bulk = selectedSeries.length > 1;
    final title = selectedSeries.first.title;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xffef4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xffef4444),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.localeText('删除系列', 'Delete Series'))),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            bulk
                ? context.localeText(
                    '此操作会删除选中的 ${selectedSeries.length} 个系列，系列中的书籍不会被删除。',
                    'Delete ${selectedSeries.length} selected series. Books in those series will not be deleted.',
                  )
                : context.localeText(
                    '确定要删除“$title”这个系列吗？系列中的书籍不会被删除。',
                    'Delete "$title"? Books in this series will not be deleted.',
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffef4444),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  Future<bool> _deleteSeries(List<Series> selectedSeries) async {
    if (selectedSeries.isEmpty || _deletingSeries) return false;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _deletingSeries = true);
    try {
      await _shelf?.operations
          .deleteSeries(selectedSeries.map((series) => series.id));
      return true;
    } catch (error) {
      if (!mounted) return false;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.localeText(
              '删除系列失败：$error',
              'Failed to delete series: $error',
            ),
          ),
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _deletingSeries = false);
    }
  }

  Future<bool> _confirmAndDeleteBooks(List<Book> selectedBooks) async {
    if (selectedBooks.isEmpty || _deletingBooks) return false;

    final confirmation = await showDeleteBookConfirmationDialog(
      context,
      books: selectedBooks,
    );
    if (confirmation == null) return false;
    if (!mounted) return false;

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _deletingBooks = true);
    try {
      await _shelf?.operations.deleteBooks(selectedBooks.map((book) => book.id),
          deleteFiles: confirmation.deleteSourceFiles);
      if (!mounted) return false;
      setState(() {
        _selectionMode = false;
        _selectedBookIds.clear();
        _selectedSeriesIds.clear();
      });
      await _load();
      return true;
    } catch (error) {
      if (!mounted) return false;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.localeText(
                '删除书籍失败：$error', 'Failed to delete books: $error'),
          ),
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _deletingBooks = false);
    }
  }

  Future<void> _showCreateSeriesDialog() async {
    final selectedBooks =
        _books.where((book) => _selectedBookIds.contains(book.id)).toList();
    if (selectedBooks.isEmpty) return;
    final titleController =
        TextEditingController(text: selectedBooks.first.title);
    final authorController =
        TextEditingController(text: selectedBooks.first.author ?? '');
    final descriptionController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.localeText('创建系列', 'Create Series')),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                          labelText: context.localeText('系列名称', 'Series Name')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: authorController,
                      decoration: InputDecoration(
                          labelText: context.localeText('作者', 'Author')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                          labelText: context.localeText('简介', 'Description')),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.localeText('已选 ${selectedBooks.length} 本书',
                            '${selectedBooks.length} selected'),
                        style: TextStyle(color: context.mutedText),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.pop(context, false),
                  child: Text(context.l10n.commonCancel),
                ),
                PrimaryButton(
                  label: context.localeText('创建', 'Create'),
                  loading: saving,
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    setDialogState(() => saving = true);
                    try {
                      await _shelf?.operations.createSeries({
                        'library_id': selectedBooks.first.libraryId,
                        'title': titleController.text.trim(),
                        'author': authorController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'book_ids':
                            selectedBooks.map((book) => book.id).toList(),
                      });
                      if (context.mounted) Navigator.pop(context, true);
                    } finally {
                      if (context.mounted) setDialogState(() => saving = false);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    authorController.dispose();
    descriptionController.dispose();

    if (created == true) {
      setState(() {
        _selectionMode = false;
        _selectedBookIds.clear();
        _selectedSeriesIds.clear();
      });
      await _load();
    }
  }
}
