import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_error.dart';
import '../../core/state/search_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';

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
  SearchState? _searchState;
  SearchState get _state =>
      _searchState ?? (throw StateError('Search not bound'));
  bool _showFilters = false;
  final _sourceMenu = MenuController();

  IconSizeSetting get _iconSize => iconSizeFromAppSettings(_state.settings);
  CoverShape get _coverShape => coverShapeFromAppSettings(_state.settings);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _searchState ??= SearchState(AppScope.appOf(context).api)
      ..addListener(_changed)
      ..load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchState?.removeListener(_changed);
    _searchState?.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _state.invalidateSearch();
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _search({int page = 1}) async {
    _debounce?.cancel();
    _state.query = _queryController.text;
    await _state.search(requestedPage: page);
  }

  void _setFilter(VoidCallback mutate) {
    setState(mutate);
    unawaited(_search());
  }

  @override
  Widget build(BuildContext context) {
    if (_state.loading) return const LoadingView();

    return PageListView(
      children: [
        AppBackButton(onPressed: widget.onBack),
        const SizedBox(height: 24),
        Center(
          child: Text(
            context.localeText('发现精彩内容', 'Discover'),
            style: TextStyle(
              fontSize: MediaQuery.sizeOf(context).width < 768 ? 30 : 36,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            context.localeText('搜索书名、作者、演播者或简介',
                'Search titles, authors, narrators, or descriptions'),
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
                hintText: context.localeText('输入关键词搜索...', 'Enter keywords...'),
                suffixIcon: _state.searching
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
        _scopeTabs(),
        if (_state.metadataError != null) _error(_state.metadataError),
        if (_state.showFilters)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: const Icon(Icons.tune_rounded),
              label: Text(context.localeText(_showFilters ? '收起筛选' : '展开筛选',
                  _showFilters ? 'Hide Filters' : 'Show Filters')),
            ),
          ),
        if (_state.showFilters && _showFilters) ...[
          const SizedBox(height: 14),
          TingCard(
            child: Column(
              children: [
                _FilterRow(
                  label: context.localeText('媒体库', 'Library'),
                  items: _state.libraries
                      .map((item) => _FilterOption(item.id, item.name))
                      .toList(),
                  selected: _state.libraryId,
                  onSelected: (value) =>
                      _setFilter(() => _state.libraryId = value),
                ),
                _FilterRow(
                  label: context.localeText('系列', 'Series'),
                  items: _state.series
                      .map((item) => _FilterOption(item.id, item.title))
                      .toList(),
                  selected: _state.seriesId,
                  onSelected: (value) =>
                      _setFilter(() => _state.seriesId = value),
                ),
                _FilterRow(
                  label: context.localeText('标签', 'Tags'),
                  items: _state.tags
                      .map((item) => _FilterOption(item, item))
                      .toList(),
                  selected: _state.tag,
                  onSelected: (value) => _setFilter(() => _state.tag = value),
                ),
                _FilterRow(
                  label: context.localeText('流派', 'Genre'),
                  items: _state.genres
                      .map((item) => _FilterOption(item, item))
                      .toList(),
                  selected: _state.genre,
                  onSelected: (value) => _setFilter(() => _state.genre = value),
                ),
                _FilterRow(
                  label: context.localeText('年份', 'Year'),
                  items: _state.years
                      .map((item) => _FilterOption(item, item))
                      .toList(),
                  selected: _state.year,
                  onSelected: (value) => _setFilter(() => _state.year = value),
                ),
                _FilterRow(
                  label: context.localeText('作者', 'Author'),
                  items: _state.authors
                      .map((item) => _FilterOption(item, item))
                      .toList(),
                  selected: _state.author,
                  onSelected: (value) =>
                      _setFilter(() => _state.author = value),
                ),
                _FilterRow(
                  label: context.localeText('演播者', 'Narrator'),
                  items: _state.narrators
                      .map((item) => _FilterOption(item, item))
                      .toList(),
                  selected: _state.narrator,
                  onSelected: (value) =>
                      _setFilter(() => _state.narrator = value),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_state.hasSearch && _state.showBookshelf) ...[
          if (_state.scope == SearchScope.all)
            _sectionTitle(context.localeText('书架', 'Bookshelf')),
          if (_state.bookshelfError != null)
            _error(_state.bookshelfError)
          else if (_state.books.isNotEmpty)
            _bookGrid(_state.books.length, (index) {
              final book = _state.books[index];
              return BookCard(
                book: book,
                coverShape: _coverShape,
                onTap: () => widget.openBook(book.id),
              );
            })
          else
            _emptyResults(),
        ],
        if (_state.showOnline &&
            (_state.hasSearch || _state.scope == SearchScope.online)) ...[
          if (_state.scope == SearchScope.all) ...[
            const SizedBox(height: 28),
            _sectionTitle(context.localeText('在线', 'Online')),
          ],
          if (_state.sourceLoadError != null) _error(_state.sourceLoadError),
          for (final error in _state.sourceErrors) _error(error),
          if (_state.sources.isEmpty)
            _hint(context.localeText('暂无可用书源', 'No online sources available'))
          else if (_state.selectedSourceIds.isEmpty)
            _hint(context.localeText('请选择在线书源', 'Select online sources'))
          else if (_state.sourceBooks.isNotEmpty)
            _bookGrid(_state.sourceBooks.length, (index) {
              final item = _state.sourceBooks[index];
              return BookCard(
                book: item.book,
                coverShape: _coverShape,
                showProgress: false,
                onTap: () {
                  final id = item.addedBookId;
                  if (id != null && id.isNotEmpty) widget.openBook(id);
                },
                action: _addButton(item),
              );
            }, online: true)
          else if (_state.sourceErrors.isEmpty)
            _state.query.trim().isEmpty
                ? _hint(context.localeText(
                    '输入关键词搜索在线书源', 'Enter keywords to search online sources'))
                : _emptyResults(),
          if (_state.page > 1 || _state.hasMore)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: context.localeText('上一页', 'Previous page'),
                  onPressed: _state.searching || _state.page <= 1
                      ? null
                      : () => _search(page: _state.page - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('${_state.page}'),
                IconButton(
                  tooltip: context.localeText('下一页', 'Next page'),
                  onPressed: _state.searching || !_state.hasMore
                      ? null
                      : () => _search(page: _state.page + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
        ],
        if (!_state.hasSearch && _state.scope != SearchScope.online)
          _hint(context.localeText(
              '输入关键词或使用上方筛选器开始探索', 'Enter keywords or use filters to start')),
        const SafeBottomSpacer(),
      ],
    );
  }

  void _changeScope(SearchScope scope) {
    _debounce?.cancel();
    _state.query = _queryController.text;
    unawaited(_state.setScope(scope));
  }

  Widget _scopeTabs() {
    final allSelected = _state.sources.isNotEmpty &&
        _state.selectedSourceIds.length == _state.sources.length;
    void selectSources(Iterable<String> ids) {
      _debounce?.cancel();
      _state.query = _queryController.text;
      unawaited(_state.selectSources(ids));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: MenuAnchor(
          controller: _sourceMenu,
          consumeOutsideTap: true,
          style: const MenuStyle(
            maximumSize: WidgetStatePropertyAll(Size(320, 360)),
          ),
          menuChildren: [
            CheckboxMenuButton(
              value: allSelected,
              closeOnActivate: false,
              onChanged: _state.sources.isEmpty
                  ? null
                  : (value) => selectSources(value == true
                      ? _state.sources.map((source) => source.id)
                      : []),
              child: Text(context.localeText('全部在线书源', 'All online sources')),
            ),
            for (final source in _state.sources)
              CheckboxMenuButton(
                value: _state.selectedSourceIds.contains(source.id),
                closeOnActivate: false,
                onChanged: (value) => selectSources({
                  ..._state.selectedSourceIds.where((id) => id != source.id),
                  if (value == true) source.id,
                }),
                child: Text(source.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            if (_state.sources.isEmpty)
              MenuItemButton(
                child: Text(context.localeText(
                    '暂无可用书源', 'No online sources available')),
              ),
          ],
          builder: (context, controller, child) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final scope in [SearchScope.all, SearchScope.bookshelf])
                Flexible(
                    child: _scopeTab(
                        scope,
                        scope == SearchScope.all
                            ? context.localeText('全部', 'All')
                            : context.localeText('书架', 'Bookshelf'))),
              Flexible(
                  child: _scopeTab(
                      SearchScope.online, context.localeText('在线', 'Online'),
                      menuOpen: controller.isOpen, onTap: () {
                if (_state.scope != SearchScope.online) {
                  _changeScope(SearchScope.online);
                  // Scope changes can shorten the scroll extent and close a menu
                  // opened before layout has settled.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _sourceMenu.open();
                  });
                } else {
                  controller.isOpen ? controller.close() : controller.open();
                }
              })),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scopeTab(SearchScope scope, String label,
      {bool menuOpen = false, VoidCallback? onTap}) {
    final selected = _state.scope == scope;
    return Semantics(
      selected: selected,
      button: true,
      child: TextButton(
        onPressed: onTap ??
            () {
              _sourceMenu.close();
              _changeScope(scope);
            },
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 14),
          foregroundColor: selected ? AppColors.primary600 : context.mutedText,
          shape: const RoundedRectangleBorder(),
          side: BorderSide.none,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: selected ? AppColors.primary600 : Colors.transparent,
                    width: 2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
                child:
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (scope == SearchScope.online) ...[
              if (_state.selectedSourceIds.isNotEmpty)
                Text(' (${_state.selectedSourceIds.length})'),
              Icon(
                  menuOpen
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
              header: true,
              child:
                  Text(title, style: Theme.of(context).textTheme.titleMedium)),
          const Divider(height: 24),
        ],
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
            child: Text(text, style: TextStyle(color: context.mutedText))),
      );

  Widget _emptyResults() => _hint(_state.searching
      ? context.localeText('搜索中…', 'Searching…')
      : context.localeText('未找到相关结果', 'No Results'));

  Widget _error(Object? error) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(ApiError.messageFor(error ?? StateError('Search failed')),
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );

  Widget _bookGrid(int count, Widget Function(int) itemBuilder,
          {bool online = false}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = gridColumnsForWidth(constraints.maxWidth, _iconSize);
          final spacing = gridSpacing(_iconSize);
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: count,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing + 14,
              mainAxisExtent: width / coverAspectRatio(_coverShape) +
                  (online ? 110 : 62) *
                      MediaQuery.textScalerOf(context).scale(1),
            ),
            itemBuilder: (context, index) => itemBuilder(index),
          );
        },
      );

  Widget _addButton(SourceSearchBook item) {
    final pending = _state.adding.contains(item.key);
    return SizedBox(
      height: 36,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4)),
        onPressed: pending || item.added || item.book.id.isEmpty
            ? null
            : () async {
                try {
                  await _state.addBook(item);
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ApiError.messageFor(error))),
                  );
                }
              },
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (pending)
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(item.added ? Icons.check_rounded : Icons.add_rounded,
                size: 14),
          const SizedBox(width: 3),
          Flexible(
              child: Text(
                  pending
                      ? context.localeText('加入中', 'Adding')
                      : item.added
                          ? context.localeText('已加入', 'Added')
                          : context.localeText('加入书架', 'Add to shelf'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12))),
        ]),
      ),
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
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: compact ? 76 : 84,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: HorizontalScrollControls(
              child: Row(
                children: [
                  _FilterChip(
                    label: context.localeText('全部', 'All'),
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
