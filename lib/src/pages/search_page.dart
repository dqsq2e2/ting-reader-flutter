import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/book_card.dart';
import '../widgets/common_widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.openBook,
    required this.onBack,
  });

  final ValueChanged<String> openBook;
  final VoidCallback onBack;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _queryController = TextEditingController();
  Timer? _debounce;

  bool _loadingMetadata = true;
  bool _searching = false;
  bool _showFilters = false;

  String _query = '';
  String _selectedLibraryId = '';
  String _selectedSeries = '';
  String _selectedTag = '';
  String _selectedGenre = '';
  String _selectedYear = '';
  String _selectedAuthor = '';
  String _selectedNarrator = '';

  List<Library> _libraries = [];
  List<Series> _series = [];
  List<String> _tags = [];
  List<String> _genres = [];
  List<String> _years = [];
  List<String> _authors = [];
  List<String> _narrators = [];
  List<Book> _results = [];
  IconSizeSetting _iconSize = IconSizeSetting.medium;
  CoverShape _coverShape = CoverShape.rect;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final appState = AppScope.appOf(context);
    try {
      final results = await Future.wait([
        appState.api.get('/api/tags'),
        appState.api.get('/api/books'),
        appState.api.get('/api/libraries'),
        appState.api.get('/api/v1/series'),
        appState.api.get('/api/settings'),
      ]);
      final allBooks = asMapList(results[1].data).map(Book.fromJson).toList();
      final authors = <String>{};
      final narrators = <String>{};
      final genres = <String>{};
      final years = <String>{};
      for (final book in allBooks) {
        if ((book.author ?? '').isNotEmpty) authors.add(book.author!);
        if ((book.narrator ?? '').isNotEmpty) narrators.add(book.narrator!);
        if ((book.genre ?? '').isNotEmpty) {
          genres.addAll(book.genre!
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty));
        }
        if (book.year != null) years.add(book.year.toString());
      }
      final settings = asMap(asMap(results[4].data)['settings_json'] ??
          asMap(results[4].data)['settingsJson']);
      setState(() {
        _tags = (results[0].data as List? ?? const [])
            .map((e) => e.toString())
            .toList();
        _libraries = asMapList(results[2].data).map(Library.fromJson).toList();
        _series = asMapList(results[3].data).map(Series.fromJson).toList();
        _authors = authors.toList()..sort();
        _narrators = narrators.toList()..sort();
        _genres = genres.toList()..sort();
        _years = years.toList()
          ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));
        _iconSize = iconSizeFromString(
          (settings['bookshelf_icon_size'] ?? settings['bookshelfIconSize'])
              ?.toString(),
        );
        _coverShape = coverShapeFromString(
          (settings['bookshelf_cover_shape'] ?? settings['bookshelfCoverShape'])
              ?.toString(),
        );
      });
    } finally {
      if (mounted) setState(() => _loadingMetadata = false);
    }
  }

  void _onQuery(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  bool get _hasActiveFilters =>
      _selectedLibraryId.isNotEmpty ||
      _selectedSeries.isNotEmpty ||
      _selectedTag.isNotEmpty ||
      _selectedGenre.isNotEmpty ||
      _selectedYear.isNotEmpty ||
      _selectedAuthor.isNotEmpty ||
      _selectedNarrator.isNotEmpty;

  Future<void> _search() async {
    if (_query.trim().isEmpty && !_hasActiveFilters) {
      setState(() => _results = []);
      return;
    }

    setState(() => _searching = true);
    final appState = AppScope.appOf(context);
    try {
      final res = await appState.api.get(
        '/api/books',
        params: {
          if (_query.trim().isNotEmpty) 'search': _query.trim(),
          if (_selectedTag.isNotEmpty) 'tag': _selectedTag,
          if (_selectedLibraryId.isNotEmpty) 'library_id': _selectedLibraryId,
        },
      );
      var books = asMapList(res.data).map(Book.fromJson).toList();
      if (_selectedAuthor.isNotEmpty) {
        books = books.where((book) => book.author == _selectedAuthor).toList();
      }
      if (_selectedNarrator.isNotEmpty) {
        books =
            books.where((book) => book.narrator == _selectedNarrator).toList();
      }
      if (_selectedGenre.isNotEmpty) {
        books = books.where((book) {
          return (book.genre ?? '')
              .split(',')
              .map((item) => item.trim())
              .contains(_selectedGenre);
        }).toList();
      }
      if (_selectedYear.isNotEmpty) {
        books = books
            .where((book) => book.year?.toString() == _selectedYear)
            .toList();
      }
      if (_selectedSeries.isNotEmpty) {
        final target = _series.where((item) => item.id == _selectedSeries);
        final ids = target.isEmpty
            ? <String>{}
            : target.first.books.map((book) => book.id).toSet();
        books = books.where((book) => ids.contains(book.id)).toList();
      }
      setState(() => _results = books);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _setFilter(VoidCallback mutate) {
    setState(mutate);
    _search();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMetadata) return const LoadingView();

    return PageListView(
      children: [
        AppBackButton(onPressed: widget.onBack),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '发现精彩内容',
            style: TextStyle(
              fontSize: MediaQuery.sizeOf(context).width < 768 ? 30 : 36,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            '搜索书名、作者、演播者或简介',
            style: TextStyle(color: context.mutedText),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              onChanged: _onQuery,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: '输入关键词搜索...',
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _queryController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _queryController.clear();
                              _onQuery('');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
              ),
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: const Icon(Icons.tune_rounded),
            label: Text(_showFilters ? '收起筛选' : '展开筛选'),
          ),
        ),
        if (_showFilters) ...[
          const SizedBox(height: 14),
          TingCard(
            child: Column(
              children: [
                _FilterRow(
                  label: '媒体库',
                  items: _libraries
                      .map((item) => _FilterOption(item.id, item.name))
                      .toList(),
                  selected: _selectedLibraryId,
                  onSelected: (value) =>
                      _setFilter(() => _selectedLibraryId = value),
                ),
                _FilterRow(
                  label: '系列',
                  items: _series
                      .map((item) => _FilterOption(item.id, item.title))
                      .toList(),
                  selected: _selectedSeries,
                  onSelected: (value) =>
                      _setFilter(() => _selectedSeries = value),
                ),
                _FilterRow(
                  label: '标签',
                  items:
                      _tags.map((item) => _FilterOption(item, item)).toList(),
                  selected: _selectedTag,
                  onSelected: (value) => _setFilter(() => _selectedTag = value),
                ),
                _FilterRow(
                  label: '流派',
                  items:
                      _genres.map((item) => _FilterOption(item, item)).toList(),
                  selected: _selectedGenre,
                  onSelected: (value) =>
                      _setFilter(() => _selectedGenre = value),
                ),
                _FilterRow(
                  label: '年份',
                  items:
                      _years.map((item) => _FilterOption(item, item)).toList(),
                  selected: _selectedYear,
                  onSelected: (value) =>
                      _setFilter(() => _selectedYear = value),
                ),
                _FilterRow(
                  label: '作者',
                  items: _authors
                      .map((item) => _FilterOption(item, item))
                      .toList(),
                  selected: _selectedAuthor,
                  onSelected: (value) =>
                      _setFilter(() => _selectedAuthor = value),
                ),
                _FilterRow(
                  label: '演播者',
                  items: _narrators
                      .map((item) => _FilterOption(item, item))
                      .toList(),
                  selected: _selectedNarrator,
                  onSelected: (value) =>
                      _setFilter(() => _selectedNarrator = value),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_results.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  gridColumnsForWidth(constraints.maxWidth, _iconSize);
              final spacing = gridSpacing(_iconSize);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _results.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing + 14,
                  childAspectRatio:
                      _coverShape == CoverShape.square ? 0.62 : 0.54,
                ),
                itemBuilder: (context, index) {
                  final book = _results[index];
                  return BookCard(
                    book: book,
                    coverShape: _coverShape,
                    onTap: () => widget.openBook(book.id),
                  );
                },
              );
            },
          )
        else if ((_query.trim().isNotEmpty || _hasActiveFilters) && !_searching)
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: '未找到相关结果',
            message: '尝试调整筛选条件或搜索关键词',
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 52),
            child: Center(
              child: Text(
                '输入关键词或使用上方筛选器开始探索',
                style: TextStyle(color: context.mutedText),
              ),
            ),
          ),
        const SafeBottomSpacer(),
      ],
    );
  }
}

class _FilterOption {
  const _FilterOption(this.value, this.label);

  final String value;
  final String label;
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<_FilterOption> items;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: '全部',
                    selected: selected.isEmpty,
                    onTap: () => onSelected(''),
                  ),
                  for (final item in items)
                    _FilterChip(
                      label: item.label,
                      selected: selected == item.value,
                      onTap: () =>
                          onSelected(selected == item.value ? '' : item.value),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primary500,
        labelStyle: TextStyle(
          color: selected ? Colors.white : null,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
