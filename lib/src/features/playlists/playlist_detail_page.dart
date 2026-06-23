part of 'playlists_page.dart';

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    required this.onBack,
    required this.openBook,
    required this.openSeries,
  });

  final String playlistId;
  final VoidCallback onBack;
  final ValueChanged<String> openBook;
  final ValueChanged<String> openSeries;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  bool _loading = true;
  bool _managing = false;
  Playlist? _playlist;
  List<Book> _books = [];
  List<Series> _series = [];
  List<PlaylistItem> _draftItems = [];
  String _detailQuery = '';
  String _manageQuery = '';
  String _manageType = 'book';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlaylistDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlistId != widget.playlistId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = AppScope.appOf(context).api;
    try {
      final results = await Future.wait([
        api.get('/api/playlists/${widget.playlistId}'),
        api.get('/api/books'),
        api.get('/api/v1/series'),
      ]);
      setState(() {
        _playlist = Playlist.fromJson(asMap(results[0].data));
        _books = asMapList(results[1].data).map(Book.fromJson).toList();
        _series = asMapList(results[2].data).map(Series.fromJson).toList();
        _managing = false;
        _draftItems = [];
        _detailQuery = '';
        _manageQuery = '';
        _manageType = 'book';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveItems(List<PlaylistItem> items) async {
    final playlist = _playlist;
    if (playlist == null) return;
    final res = await AppScope.appOf(context).api.put(
      '/api/playlists/${playlist.id}',
      data: {
        'items': items.map((item) => item.toRequestJson()).toList(),
      },
    );
    setState(() {
      _playlist = Playlist.fromJson(asMap(res.data));
      _draftItems = _playlist!.effectiveItems;
    });
  }

  Future<void> _editInfo() async {
    final playlist = _playlist;
    if (playlist == null) return;
    final api = AppScope.appOf(context).api;
    final data = await _showPlaylistInfoDialog(context, playlist: playlist);
    if (data == null) return;
    final res = await api.put(
      '/api/playlists/${playlist.id}',
      data: data,
    );
    setState(() => _playlist = Playlist.fromJson(asMap(res.data)));
  }

  Future<void> _delete() async {
    final playlist = _playlist;
    if (playlist == null) return;
    final api = AppScope.appOf(context).api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书单'),
        content: Text('确定删除「${playlist.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await api.delete('/api/playlists/${playlist.id}');
    widget.onBack();
  }

  void _startManaging() {
    final playlist = _playlist;
    if (playlist == null) return;
    setState(() {
      _managing = true;
      _draftItems = [...playlist.effectiveItems];
      _manageQuery = '';
      _manageType = 'book';
    });
  }

  void _cancelManaging() {
    final playlist = _playlist;
    setState(() {
      _managing = false;
      _draftItems = playlist?.effectiveItems ?? [];
      _manageQuery = '';
      _manageType = 'book';
    });
  }

  Future<void> _saveDraftItems() async {
    await _saveItems(_draftItems);
    if (mounted) {
      setState(() {
        _managing = false;
        _manageQuery = '';
        _manageType = 'book';
      });
    }
  }

  bool _draftContains(String itemType, String itemId) {
    return _draftItems.any(
      (item) => item.itemType == itemType && item.itemId == itemId,
    );
  }

  void _toggleDraftBook(Book book) {
    setState(() {
      final selected = _draftContains('book', book.id);
      if (selected) {
        _draftItems = _draftItems
            .where(
                (item) => !(item.itemType == 'book' && item.itemId == book.id))
            .toList();
      } else {
        _draftItems = [
          ..._draftItems,
          PlaylistItem(
            itemType: 'book',
            itemId: book.id,
            order: _draftItems.length + 1,
            book: book,
          ),
        ];
      }
    });
  }

  void _toggleDraftSeries(Series series) {
    setState(() {
      final selected = _draftContains('series', series.id);
      if (selected) {
        _draftItems = _draftItems
            .where(
              (item) =>
                  !(item.itemType == 'series' && item.itemId == series.id),
            )
            .toList();
      } else {
        _draftItems = [
          ..._draftItems,
          PlaylistItem(
            itemType: 'series',
            itemId: series.id,
            order: _draftItems.length + 1,
            series: series,
          ),
        ];
      }
    });
  }

  void _removeDraftAt(int index) {
    setState(() => _draftItems = [..._draftItems]..removeAt(index));
  }

  void _moveDraft(int index, int offset) {
    final nextIndex = index + offset;
    if (nextIndex < 0 || nextIndex >= _draftItems.length) return;
    setState(() {
      final next = [..._draftItems];
      final item = next.removeAt(index);
      next.insert(nextIndex, item);
      _draftItems = next;
    });
  }

  bool _bookMatches(Book book, String keyword) {
    if (keyword.isEmpty) return true;
    return '${book.title} ${book.author ?? ''} ${book.narrator ?? ''}'
        .toLowerCase()
        .contains(keyword);
  }

  bool _seriesMatches(Series series, String keyword) {
    if (keyword.isEmpty) return true;
    final bookText = series.books
        .map((book) =>
            '${book.title} ${book.author ?? ''} ${book.narrator ?? ''}')
        .join(' ');
    return '${series.title} ${series.author ?? ''} ${series.narrator ?? ''} $bookText'
        .toLowerCase()
        .contains(keyword);
  }

  bool _playlistItemMatches(PlaylistItem item, String keyword) {
    if (keyword.isEmpty) return true;
    if (item.itemType == 'series') {
      final series = item.series;
      if (series == null) return false;
      return _seriesMatches(series, keyword);
    }
    final book = item.book;
    if (book == null) return false;
    return _bookMatches(book, keyword);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final playlist = _playlist;
    if (playlist == null) {
      return PageListView(
        children: [
          AppBackButton(onPressed: widget.onBack),
          const SizedBox(height: 24),
          const EmptyState(
            icon: Icons.playlist_remove_rounded,
            title: '未找到书单',
            message: '这个书单可能已经被删除。',
          ),
        ],
      );
    }
    final items = playlist.effectiveItems;
    final detailKeyword = _detailQuery.trim().toLowerCase();
    final visibleItems = items
        .where((item) => _playlistItemMatches(item, detailKeyword))
        .toList();

    return PageListView(
      onRefresh: _load,
      children: [
        AppBackButton(onPressed: widget.onBack),
        const SizedBox(height: 20),
        _PlaylistHero(
          playlist: playlist,
          itemCount: items.length,
          onEdit: _editInfo,
          onManage: _startManaging,
          managing: _managing,
          onCancelManage: _cancelManaging,
          onSaveManage: _saveDraftItems,
          onDelete: _delete,
        ),
        const SizedBox(height: 18),
        if (_managing)
          ..._buildManageChildren(context)
        else ...[
          _PlaylistSearchPanel(
            query: _detailQuery,
            hint: '搜索书单内作品',
            countText: '${visibleItems.length} / ${items.length} 项',
            onChanged: (value) => setState(() => _detailQuery = value),
          ),
          const SizedBox(height: 22),
          if (items.isEmpty)
            EmptyState(
              icon: Icons.playlist_add_rounded,
              title: '书单是空的',
              message: '点击“管理内容”加入作品或系列。',
              action: PrimaryButton(
                label: '管理内容',
                icon: Icons.add_rounded,
                onPressed: _startManaging,
              ),
            )
          else if (visibleItems.isEmpty)
            const EmptyState(
              icon: Icons.search_off_rounded,
              title: '没有匹配的作品',
              message: '换个关键词试试。',
            )
          else
            _PlaylistContentGrid(
              items: visibleItems,
              onOpen: (item) {
                if (item.itemType == 'series') {
                  widget.openSeries(item.itemId);
                } else {
                  widget.openBook(item.itemId);
                }
              },
            ),
        ],
        const SafeBottomSpacer(),
      ],
    );
  }

  List<Widget> _buildManageChildren(BuildContext context) {
    final keyword = _manageQuery.trim().toLowerCase();
    final visibleBooks =
        _books.where((book) => _bookMatches(book, keyword)).toList();
    final visibleSeries =
        _series.where((item) => _seriesMatches(item, keyword)).toList();
    return [
      _PlaylistManageSearchPanel(
        type: _manageType,
        query: _manageQuery,
        selectedCount: _draftItems.length,
        onTypeChanged: (value) => setState(() => _manageType = value),
        onQueryChanged: (value) => setState(() => _manageQuery = value),
      ),
      const SizedBox(height: 18),
      _PlaylistSelectedOrderPanel(
        items: _draftItems,
        onMove: _moveDraft,
        onRemove: _removeDraftAt,
      ),
      const SizedBox(height: 20),
      if (_manageType == 'series')
        visibleSeries.isEmpty
            ? const EmptyState(
                icon: Icons.layers_rounded,
                title: '没有匹配的系列',
                message: '换个关键词试试。',
              )
            : _PlaylistSeriesSelectGrid(
                series: visibleSeries,
                isSelected: (item) => _draftContains('series', item.id),
                onToggle: _toggleDraftSeries,
              )
      else
        visibleBooks.isEmpty
            ? const EmptyState(
                icon: Icons.menu_book_rounded,
                title: '没有匹配的书籍',
                message: '换个关键词试试。',
              )
            : _PlaylistBookSelectGrid(
                books: visibleBooks,
                isSelected: (book) => _draftContains('book', book.id),
                onToggle: _toggleDraftBook,
              ),
    ];
  }
}
