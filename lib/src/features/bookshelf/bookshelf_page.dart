import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/locale.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';
import '../../shared/filter/display_filter_menu.dart';
import 'book_delete_dialog.dart';

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

  bool _loading = true;
  List<Book> _books = [];
  List<Series> _series = [];
  List<Library> _libraries = [];
  String _selectedLibraryId = '';
  final String _searchQuery = '';
  String _sortBy = 'created_at';
  IconSizeSetting _iconSize = IconSizeSetting.medium;
  CoverShape _coverShape = CoverShape.rect;
  bool _showFilterMenu = false;
  bool _selectionMode = false;
  bool _deletingBooks = false;
  bool _deletingSeries = false;
  final Set<String> _selectedBookIds = {};
  final Set<String> _selectedSeriesIds = {};
  final LayerLink _filterMenuLink = LayerLink();
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _filterOverlay;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNeeded);
    _load();
  }

  @override
  void dispose() {
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

  Future<void> _load() async {
    setState(() => _loading = true);
    final appState = AppScope.appOf(context);
    try {
      final settingsRes = await appState.api.get('/api/settings');
      final settingsPayload = asMap(settingsRes.data);
      final settingsJson = asMap(settingsPayload['settings_json']);
      dynamic settingValue(String key) =>
          settingsPayload[key] ?? settingsJson[key];
      _selectedLibraryId =
          (settingValue('bookshelf_library_id') ?? '').toString();
      _sortBy = (settingValue('bookshelf_sort_by') ?? 'created_at').toString();
      _iconSize = iconSizeFromAppSettings(settingsPayload);
      _coverShape = coverShapeFromAppSettings(settingsPayload);

      final libsRes = await appState.api.get('/api/libraries');
      final libraries = asMapList(libsRes.data).map(Library.fromJson).toList();
      final selectedExists = _selectedLibraryId.isEmpty ||
          libraries.any((lib) => lib.id == _selectedLibraryId);
      if (!selectedExists) _selectedLibraryId = '';

      final results = await Future.wait([
        appState.api.get(
          '/api/books',
          params: {
            if (_selectedLibraryId.isNotEmpty) 'library_id': _selectedLibraryId,
          },
        ),
        appState.api.get(
          '/api/v1/series',
          params: {
            if (_selectedLibraryId.isNotEmpty) 'library_id': _selectedLibraryId,
          },
        ),
      ]);

      setState(() {
        _libraries = libraries;
        _books = asMapList(results[0].data).map(Book.fromJson).toList();
        _series = asMapList(results[1].data).map(Series.fromJson).toList();
        _resetVisibleItems();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist(String key, Object value) async {
    await AppScope.appOf(context).updateSettings({key: value});
  }

  List<Book> get _sortedBooks {
    final result = [..._books];
    result.sort((a, b) {
      if (_sortBy == 'title') return compareChineseText(a.title, b.title);
      if (_sortBy == 'author') {
        return compareChineseText(a.author ?? '', b.author ?? '');
      }
      if (_sortBy == 'year') return (b.year ?? 0).compareTo(a.year ?? 0);
      final ad = DateTime.tryParse(a.createdAt ?? '') ?? DateTime(1970);
      final bd = DateTime.tryParse(b.createdAt ?? '') ?? DateTime(1970);
      return bd.compareTo(ad);
    });
    return result;
  }

  List<Book> get _filteredBooks {
    final booksInSeries =
        _series.expand((item) => item.books.map((book) => book.id)).toSet();
    final query = _searchQuery.trim().toLowerCase();
    return _sortedBooks.where((book) {
      if (booksInSeries.contains(book.id)) return false;
      if (query.isEmpty) return true;
      return book.title.toLowerCase().contains(query) ||
          (book.author ?? '').toLowerCase().contains(query) ||
          (book.narrator ?? '').toLowerCase().contains(query);
    }).toList();
  }

  List<Series> get _filteredSeries {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _series;
    return _series.where((series) {
      return series.title.toLowerCase().contains(query) ||
          (series.author ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final appState = AppScope.appOf(context);
    final hasContent = _books.isNotEmpty || _series.isNotEmpty;

    return PageListView(
      controller: _scrollController,
      onRefresh: _load,
      children: [
        _Header(
          selectionMode: _selectionMode,
          selectedBookCount: _selectedBookIds.length,
          selectedSeriesCount: _selectedSeriesIds.length,
          isAdmin: appState.isAdmin,
          libraries: _libraries,
          selectedLibraryId: _selectedLibraryId,
          showFilterMenu: _showFilterMenu,
          filterMenuLink: _filterMenuLink,
          deletingItems: _deletingBooks || _deletingSeries,
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
          onCreateSeries: _selectedBookIds.isEmpty ||
                  _selectedSeriesIds.isNotEmpty ||
                  _deletingBooks ||
                  _deletingSeries
              ? null
              : _showCreateSeriesDialog,
          onDeleteSelected:
              (_selectedBookIds.isEmpty && _selectedSeriesIds.isEmpty) ||
                      _deletingBooks ||
                      _deletingSeries
                  ? null
                  : _showDeleteSelectedDialog,
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
          _ContentGrid(
            books: _filteredBooks,
            series: _filteredSeries,
            visibleCount: _visibleCount,
            sortBy: _sortBy,
            iconSize: _iconSize,
            coverShape: _coverShape,
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
    _filterOverlay = OverlayEntry(
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
                  onSortChanged: _changeSort,
                  onIconSizeChanged: _changeIconSize,
                  onCoverShapeChanged: _changeCoverShape,
                ),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context).insert(_filterOverlay!);
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
    final api = AppScope.appOf(context).api;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _deletingSeries = true);
    try {
      await Future.wait(
        selectedSeries.map(
          (series) => api.delete('/api/v1/series/${series.id}'),
        ),
      );
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

    final api = AppScope.appOf(context).api;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _deletingBooks = true);
    try {
      await Future.wait(
        selectedBooks.map(
          (book) => api.delete(
            '/api/books/${book.id}',
            params: {'delete_files': confirmation.deleteSourceFiles},
          ),
        ),
      );
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
                      await AppScope.appOf(context).api.post(
                        '/api/v1/series',
                        data: {
                          'library_id': selectedBooks.first.libraryId,
                          'title': titleController.text.trim(),
                          'author': authorController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'book_ids':
                              selectedBooks.map((book) => book.id).toList(),
                        },
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    } finally {
                      setDialogState(() => saving = false);
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

class _Header extends StatelessWidget {
  const _Header({
    required this.selectionMode,
    required this.selectedBookCount,
    required this.selectedSeriesCount,
    required this.isAdmin,
    required this.libraries,
    required this.selectedLibraryId,
    required this.showFilterMenu,
    required this.filterMenuLink,
    required this.deletingItems,
    required this.onSearchOpen,
    required this.onLibraryChanged,
    required this.onToggleFilterMenu,
    required this.onSelectionMode,
    required this.onCancelSelection,
    required this.onSelectAll,
    required this.onCreateSeries,
    required this.onDeleteSelected,
  });

  final bool selectionMode;
  final int selectedBookCount;
  final int selectedSeriesCount;
  final bool isAdmin;
  final List<Library> libraries;
  final String selectedLibraryId;
  final bool showFilterMenu;
  final LayerLink filterMenuLink;
  final bool deletingItems;
  final VoidCallback onSearchOpen;
  final ValueChanged<String?> onLibraryChanged;
  final VoidCallback onToggleFilterMenu;
  final VoidCallback onSelectionMode;
  final VoidCallback onCancelSelection;
  final VoidCallback onSelectAll;
  final VoidCallback? onCreateSeries;
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 880;
        final mobile = constraints.maxWidth < 560;
        final searchWidth = compact ? constraints.maxWidth : 256.0;
        final selectedCount = selectedBookCount + selectedSeriesCount;
        final hasSelection = selectedCount > 0;
        final operationsButton = _BatchOperationsMenuButton(
          compact: mobile,
          hasSelection: hasSelection,
          canCreateSeries: onCreateSeries != null,
          canDelete: onDeleteSelected != null,
          loading: deletingItems,
          onCreateSeries: onCreateSeries,
          onDelete: onDeleteSelected,
        );
        final desktopToolbar = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: searchWidth,
              child: _SearchEntry(onTap: onSearchOpen),
            ),
            if (selectionMode) ...[
              BatchCountBadge(
                  label: context.localeText(
                      '已选 $selectedCount', '$selectedCount selected'),
                  compact: mobile),
              BatchActionButton(
                icon: Icons.select_all_rounded,
                label: context.localeText('全选', 'Select All'),
                compact: mobile,
                onPressed: onSelectAll,
              ),
              operationsButton,
              _SquareToolbarButton(
                icon: Icons.close_rounded,
                onPressed: onCancelSelection,
              ),
            ] else if (isAdmin)
              BatchActionButton(
                icon: Icons.layers_rounded,
                label: context.localeText('选择模式', 'Select Mode'),
                compact: mobile,
                onPressed: onSelectionMode,
              ),
            if (libraries.isNotEmpty)
              SizedBox(
                width: compact ? constraints.maxWidth : 168,
                child: _LibraryDropdown(
                  libraries: libraries,
                  selectedLibraryId: selectedLibraryId,
                  onChanged: onLibraryChanged,
                ),
              ),
            CompositedTransformTarget(
              link: filterMenuLink,
              child: _SquareToolbarButton(
                icon: Icons.filter_list_rounded,
                selected: showFilterMenu,
                onPressed: onToggleFilterMenu,
              ),
            ),
          ],
        );

        final compactFilterButton = CompositedTransformTarget(
          link: filterMenuLink,
          child: _SquareToolbarButton(
            icon: Icons.filter_list_rounded,
            selected: showFilterMenu,
            onPressed: onToggleFilterMenu,
          ),
        );

        Widget compactToolbar() {
          if (selectionMode) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BatchCountBadge(
                    label: context.localeText(
                        '已选 $selectedCount', '$selectedCount selected'),
                    compact: mobile),
                BatchActionButton(
                  icon: Icons.select_all_rounded,
                  label: context.localeText('全选', 'Select All'),
                  compact: mobile,
                  onPressed: onSelectAll,
                ),
                operationsButton,
                _SquareToolbarButton(
                  icon: Icons.close_rounded,
                  onPressed: onCancelSelection,
                ),
              ],
            );
          }

          final modeButton = isAdmin
              ? BatchActionButton(
                  icon: Icons.layers_rounded,
                  label: mobile
                      ? context.localeText('选择', 'Select')
                      : context.localeText('选择模式', 'Select Mode'),
                  onPressed: onSelectionMode,
                  compact: mobile,
                )
              : const SizedBox.shrink();
          final libraryDropdown = libraries.isEmpty
              ? const SizedBox.shrink()
              : _LibraryDropdown(
                  libraries: libraries,
                  selectedLibraryId: selectedLibraryId,
                  onChanged: onLibraryChanged,
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: double.infinity,
                  child: _SearchEntry(onTap: onSearchOpen)),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (isAdmin) ...[
                    if (mobile)
                      Flexible(flex: 10, child: modeButton)
                    else
                      SizedBox(width: 136, child: modeButton),
                    const SizedBox(width: 8),
                  ],
                  if (libraries.isNotEmpty)
                    if (mobile)
                      Expanded(flex: 12, child: libraryDropdown)
                    else
                      SizedBox(width: 176, child: libraryDropdown),
                  if (libraries.isNotEmpty) const SizedBox(width: 8),
                  compactFilterButton,
                ],
              ),
            ],
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HeaderText(
                        icon: Icons.library_books_rounded,
                        title: context.localeText('我的书架', 'My Bookshelf'),
                        subtitle: context.localeText('发现您收藏的所有有声读物。',
                            'Browse every audiobook in your collection.'),
                      ),
                      const SizedBox(height: 16),
                      compactToolbar(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: HeaderText(
                          icon: Icons.library_books_rounded,
                          title: context.localeText('我的书架', 'My Bookshelf'),
                          subtitle: context.localeText('发现您收藏的所有有声读物。',
                              'Browse every audiobook in your collection.'),
                        ),
                      ),
                      desktopToolbar,
                    ],
                  ),
          ],
        );
      },
    );
  }
}

enum _BatchOperation { createSeries, delete }

class _BatchOperationsMenuButton extends StatelessWidget {
  const _BatchOperationsMenuButton({
    required this.compact,
    required this.hasSelection,
    required this.canCreateSeries,
    required this.canDelete,
    required this.loading,
    required this.onCreateSeries,
    required this.onDelete,
  });

  final bool compact;
  final bool hasSelection;
  final bool canCreateSeries;
  final bool canDelete;
  final bool loading;
  final VoidCallback? onCreateSeries;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_BatchOperation>(
      enabled: !loading,
      tooltip: context.localeText('批量操作', 'Batch Actions'),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: (operation) {
        switch (operation) {
          case _BatchOperation.createSeries:
            onCreateSeries?.call();
          case _BatchOperation.delete:
            onDelete?.call();
        }
      },
      itemBuilder: (context) {
        if (!hasSelection) {
          return [
            PopupMenuItem<_BatchOperation>(
              enabled: false,
              child: SizedBox(
                width: 210,
                child: Text(
                  context.localeText(
                    '请先在下方勾选书籍或系列',
                    'Select books or series first',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
              ),
            ),
          ];
        }

        return [
          PopupMenuItem<_BatchOperation>(
            value: _BatchOperation.createSeries,
            enabled: canCreateSeries,
            child: _BatchOperationMenuItem(
              icon: Icons.layers_rounded,
              label: context.localeText('创建系列', 'Create Series'),
              enabled: canCreateSeries,
            ),
          ),
          PopupMenuItem<_BatchOperation>(
            value: _BatchOperation.delete,
            enabled: canDelete,
            child: _BatchOperationMenuItem(
              icon: Icons.delete_outline_rounded,
              label: context.localeText('删除', 'Delete'),
              danger: true,
              enabled: canDelete,
            ),
          ),
        ];
      },
      child: _BatchOperationsButtonSurface(
        compact: compact,
        loading: loading,
      ),
    );
  }
}

class _BatchOperationMenuItem extends StatelessWidget {
  const _BatchOperationMenuItem({
    required this.icon,
    required this.label,
    required this.enabled,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xffef4444) : context.secondaryText;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchOperationsButtonSurface extends StatelessWidget {
  const _BatchOperationsButtonSurface({
    required this.compact,
    required this.loading,
  });

  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 40.0 : 44.0;
    final background = loading
        ? AppColors.primary600.withValues(alpha: 0.55)
        : AppColors.primary600;

    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 15,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary600.withValues(alpha: loading ? 0 : 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: compact ? 15 : 16,
              height: compact ? 15 : 16,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Icon(
              Icons.more_horiz_rounded,
              size: compact ? 17 : 18,
              color: Colors.white,
            ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            compact
                ? context.localeText('操作', 'Actions')
                : context.localeText('批量操作', 'Batch Actions'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w400,
              height: 1.15,
            ),
          ),
          if (!loading) ...[
            SizedBox(width: compact ? 4 : 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: compact ? 17 : 18,
              color: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.faintBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  size: 20, color: AppColors.slate500),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.localeText(
                      '搜索书名、作者、演播者', 'Search title, author, narrator'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryDropdown extends StatelessWidget {
  const _LibraryDropdown({
    required this.libraries,
    required this.selectedLibraryId,
    required this.onChanged,
  });

  final List<Library> libraries;
  final String selectedLibraryId;
  final ValueChanged<String?> onChanged;

  String _libraryLabel(BuildContext context, String id) {
    if (id.isEmpty) return context.localeText('所有媒体库', 'All Libraries');
    for (final library in libraries) {
      if (library.id == id) return library.name;
    }
    return context.localeText('媒体库', 'Library');
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      DropdownMenuItem(
          value: '', child: Text(context.localeText('所有媒体库', 'All Libraries'))),
      ...libraries.map(
        (lib) => DropdownMenuItem(
          value: lib.id,
          child: Text(
            lib.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    return DropdownButtonFormField<String>(
      initialValue: selectedLibraryId,
      isExpanded: true,
      icon: const Padding(
        padding: EdgeInsets.only(left: 8),
        child: Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      ),
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.library_books_rounded, size: 18),
        prefixIconConstraints: BoxConstraints(minWidth: 34, minHeight: 42),
        contentPadding: EdgeInsets.fromLTRB(2, 8, 8, 8),
      ),
      selectedItemBuilder: (context) => items
          .map(
            (item) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _libraryLabel(context, item.value ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          )
          .toList(),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _SquareToolbarButton extends StatelessWidget {
  const _SquareToolbarButton({
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary600 : context.faintBorder;
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? AppColors.primary600 : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}

class _ContentGrid extends StatelessWidget {
  const _ContentGrid({
    required this.books,
    required this.series,
    required this.visibleCount,
    required this.sortBy,
    required this.iconSize,
    required this.coverShape,
    required this.selectionMode,
    required this.selectedBookIds,
    required this.selectedSeriesIds,
    required this.onBook,
    required this.onSeries,
  });

  final List<Book> books;
  final List<Series> series;
  final int visibleCount;
  final String sortBy;
  final IconSizeSetting iconSize;
  final CoverShape coverShape;
  final bool selectionMode;
  final Set<String> selectedBookIds;
  final Set<String> selectedSeriesIds;
  final ValueChanged<Book> onBook;
  final ValueChanged<Series> onSeries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = gridColumnsForWidth(constraints.maxWidth, iconSize);
        final spacing = gridSpacing(iconSize);
        final ratio = coverShape == CoverShape.square ? 0.78 : 0.62;

        if (sortBy != 'created_at') {
          final groups = <String, List<Object>>{};
          for (final book in books) {
            final source = sortBy == 'author' ? book.author ?? '' : book.title;
            final key = sortBy == 'year'
                ? (book.year?.toString().substring(2) ?? '#')
                : pinyinInitial(source);
            groups.putIfAbsent(key, () => []).add(book);
          }
          for (final item in series) {
            final source = sortBy == 'author' ? item.author ?? '' : item.title;
            final key = sortBy == 'year' ? '#' : pinyinInitial(source);
            groups.putIfAbsent(key, () => []).add(item);
          }
          final keys = groups.keys.toList()
            ..sort((a, b) {
              if (a == '#') return 1;
              if (b == '#') return -1;
              if (sortBy == 'year') return b.compareTo(a);
              return a.compareTo(b);
            });
          var remaining = visibleCount;
          final visibleGroups = <String, List<Object>>{};
          for (final key in keys) {
            if (remaining <= 0) break;
            final group = groups[key]!;
            final take = group.length < remaining ? group.length : remaining;
            if (take > 0) {
              visibleGroups[key] = group.sublist(0, take);
              remaining -= take;
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in visibleGroups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 10, top: 6),
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: context.mutedText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entry.value.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing + 12,
                    childAspectRatio: ratio,
                  ),
                  itemBuilder: (context, index) {
                    final item = entry.value[index];
                    if (item is Series) {
                      return SeriesCard(
                        series: item,
                        coverShape: coverShape,
                        selectionMode: selectionMode,
                        selected: selectedSeriesIds.contains(item.id),
                        onTap: () => onSeries(item),
                      );
                    }
                    final book = item as Book;
                    return BookCard(
                      book: book,
                      coverShape: coverShape,
                      selectionMode: selectionMode,
                      selected: selectedBookIds.contains(book.id),
                      onTap: () => onBook(book),
                    );
                  },
                ),
                const SizedBox(height: 18),
              ],
            ],
          );
        }

        final items = <Object>[...series, ...books].take(visibleCount).toList();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing + 14,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is Series) {
              return SeriesCard(
                series: item,
                coverShape: coverShape,
                selectionMode: selectionMode,
                selected: selectedSeriesIds.contains(item.id),
                onTap: () => onSeries(item),
              );
            }
            final book = item as Book;
            return BookCard(
              book: book,
              coverShape: coverShape,
              selectionMode: selectionMode,
              selected: selectedBookIds.contains(book.id),
              onTap: () => onBook(book),
            );
          },
        );
      },
    );
  }
}
