import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/models/_helpers.dart' show readDouble, readInt, readString;
import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';
import '../../core/utils/application_time_zone.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';
import 'activity_book_card.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.openBook,
    required this.onBack,
    required this.openBookshelf,
  });

  final void Function(String bookId, String? chapterId) openBook;
  final VoidCallback onBack;
  final VoidCallback openBookshelf;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _bookPageSize = 40;
  static const _chapterPageSize = 50;
  bool _loading = true;
  bool _deleting = false;
  bool _selectionMode = false;
  int _page = 1;
  int _total = 0;
  CoverShape _coverShape = CoverShape.square;
  List<_HistoryBook> _books = [];
  final Set<String> _expanded = {};
  final Set<String> _loadingChapters = {};
  final Set<String> _selectedBooks = {};
  final Set<String> _selectedProgress = {};
  final Map<String, List<ProgressItem>> _chapters = {};
  final Map<String, int> _chapterPages = {};
  final Map<String, int> _chapterTotals = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({int page = 1}) async {
    if (mounted) setState(() => _loading = true);
    try {
      final api = AppScope.appOf(context).api;
      final responses = await Future.wait([
        api.get('/api/history/books',
            params: {'page': page, 'page_size': _bookPageSize}),
        api.get('/api/settings'),
      ]);
      final data = asMap(responses[0].data);
      final nested = asMap(asMap(responses[1].data)['settings_json']);
      if (!mounted) return;
      setState(() {
        _expanded.clear();
        _chapters.clear();
        _chapterPages.clear();
        _chapterTotals.clear();
        _page = page;
        _total = readInt(data, 'total') ?? 0;
        _coverShape =
            coverShapeFromString(nested['bookshelf_cover_shape']?.toString());
        _books = asMapList(data['items']).map((item) {
          final id = readString(item, 'book_id') ?? '';
          final cached = _chapters[id] ?? const <ProgressItem>[];
          return _HistoryBook(
            id: id,
            title: readString(item, 'book_title') ??
                context.localeText('未知书籍', 'Unknown Book'),
            cover: readString(item, 'cover_url'),
            libraryId: readString(item, 'library_id'),
            updatedAt: readString(item, 'updated_at'),
            chapterCount: readInt(item, 'chapter_count') ?? 0,
            latest: ProgressItem(
              id: '',
              bookId: id,
              chapterId: readString(item, 'latest_chapter_id'),
              chapterTitle: readString(item, 'latest_chapter_title'),
              position: readDouble(item, 'latest_position') ?? 0,
              duration: readDouble(item, 'latest_duration') ?? 0,
              updatedAt: readString(item, 'updated_at'),
            ),
            chapters: cached,
          );
        }).toList();
      });
    } catch (error) {
      if (mounted) {
        _message(context.localeText(
            '加载历史失败：$error', 'Failed to load history: $error'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadChapters(String bookId, int page) async {
    if (_loadingChapters.contains(bookId)) return;
    setState(() => _loadingChapters.add(bookId));
    try {
      final response = await AppScope.appOf(context).api.get(
        '/api/history/books/$bookId/chapters',
        params: {'page': page, 'page_size': _chapterPageSize},
      );
      final data = asMap(response.data);
      final next = asMapList(data['items']).map(ProgressItem.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _chapters[bookId] = next;
        _chapterPages[bookId] = page;
        _chapterTotals[bookId] = readInt(data, 'total') ?? 0;
        final index = _books.indexWhere((book) => book.id == bookId);
        if (index >= 0) _books[index].chapters = _chapters[bookId]!;
      });
    } catch (error) {
      if (mounted) {
        _message(context.localeText(
            '加载章节失败：$error', 'Failed to load chapters: $error'));
      }
    } finally {
      if (mounted) setState(() => _loadingChapters.remove(bookId));
    }
  }

  void _toggleExpanded(_HistoryBook book) {
    final opening = !_expanded.contains(book.id);
    setState(
        () => opening ? _expanded.add(book.id) : _expanded.remove(book.id));
    if (opening && !_chapters.containsKey(book.id)) _loadChapters(book.id, 1);
  }

  String _progressKey(ProgressItem item) =>
      item.id.isNotEmpty ? item.id : '${item.bookId}:${item.chapterId}';

  void _toggleBook(String id) {
    setState(() => _selectedBooks.contains(id)
        ? _selectedBooks.remove(id)
        : _selectedBooks.add(id));
  }

  void _toggleProgress(ProgressItem item) {
    final key = _progressKey(item);
    setState(() => _selectedProgress.contains(key)
        ? _selectedProgress.remove(key)
        : _selectedProgress.add(key));
  }

  void _selectPage() {
    final allSelected = _books.isNotEmpty &&
        _books.every((book) => _selectedBooks.contains(book.id));
    setState(() {
      if (allSelected) {
        _selectedBooks.removeAll(_books.map((book) => book.id));
      } else {
        _selectedBooks.addAll(_books.map((book) => book.id));
      }
    });
  }

  Future<void> _confirmDelete({bool all = false}) async {
    if (_deleting ||
        (!all && _selectedBooks.isEmpty && _selectedProgress.isEmpty)) {
      return;
    }
    var clearProgress = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.localeText('确认清除历史', 'Clear listening history?')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(all
                ? context.localeText(
                    '将清除全部播放历史。', 'All listening history will be cleared.')
                : context.localeText('将清除选中的播放历史。',
                    'The selected listening history will be cleared.')),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: clearProgress,
              onChanged: (value) =>
                  setDialogState(() => clearProgress = value ?? false),
              title: Text(
                  context.localeText('同步清除进度', 'Also clear playback progress')),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.commonCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.localeText('确认', 'Confirm'))),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final books = _selectedBooks.toList();
      final progress = _selectedProgress.toList();
      final count = all
          ? 1
          : (books.length > progress.length ? books.length : progress.length);
      for (var offset = 0; offset < count; offset += 250) {
        await AppScope.appOf(context)
            .api
            .post('/api/progress/recent/delete', data: {
          'all': all,
          'book_ids':
              all ? const <String>[] : books.skip(offset).take(250).toList(),
          'progress_ids':
              all ? const <String>[] : progress.skip(offset).take(250).toList(),
          'clear_progress': clearProgress,
        });
      }
      if (!mounted) return;
      setState(() {
        _selectedBooks.clear();
        _selectedProgress.clear();
        _expanded.clear();
        _chapters.clear();
        _selectionMode = false;
      });
      await _load(page: 1);
    } catch (error) {
      if (mounted) {
        _message(context.localeText(
            '清除历史失败：$error', 'Failed to clear history: $error'));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final compact = MediaQuery.sizeOf(context).width < 460;
    return PageListView(
      onRefresh: _load,
      children: [
        AppBackButton(onPressed: widget.onBack),
        const SizedBox(height: 24),
        PageHeaderRow(
          icon: Icons.history_rounded,
          title: context.l10n.mineHistoryTitle,
          subtitle: context.localeText('共 $_total 本，按最近收听排序。',
              '$_total books, ordered by last listened.'),
          action: _total == 0 || _selectionMode
              ? null
              : TextButton.icon(
                  onPressed: () => setState(() => _selectionMode = true),
                  icon: const Icon(Icons.checklist_rounded),
                  label: Text(context.localeText('选择', 'Select'))),
        ),
        if (_selectionMode) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, children: [
            BatchSelectButton(
                checked: _books.isNotEmpty &&
                    _books.every((book) => _selectedBooks.contains(book.id)),
                label: context.localeText('全选', 'Select page'),
                compact: compact,
                onPressed: _selectPage),
            _HistoryActionButton(
                icon: Icons.delete_outline_rounded,
                label: context.localeText('删除所选', 'Delete selected'),
                danger: true,
                loading: _deleting,
                onPressed: _deleting ||
                        (_selectedBooks.isEmpty && _selectedProgress.isEmpty)
                    ? null
                    : _confirmDelete),
            _HistoryActionButton(
                icon: Icons.delete_sweep_outlined,
                label: context.localeText('清空全部', 'Clear all'),
                danger: true,
                onPressed: _deleting ? null : () => _confirmDelete(all: true)),
            _HistoryActionButton(
                icon: Icons.close_rounded,
                label: context.localeText('取消', 'Cancel'),
                onPressed: () => setState(() {
                      _selectionMode = false;
                      _selectedBooks.clear();
                      _selectedProgress.clear();
                    })),
          ]),
        ],
        const SizedBox(height: 18),
        if (_books.isEmpty)
          EmptyState(
            icon: Icons.history_toggle_off_rounded,
            title: context.localeText('暂无我的历史', 'No History Yet'),
            message: context.localeText(
                '去书架开始第一本吧。', 'Start a book from your bookshelf.'),
            action: PrimaryButton(
                label: context.localeText('去书架', 'Go to Bookshelf'),
                icon: Icons.library_books_rounded,
                onPressed: widget.openBookshelf),
          )
        else ...[
          for (final book in _books) ...[
            _HistoryBookSection(
              book: book,
              coverShape: _coverShape,
              expanded: _expanded.contains(book.id),
              selectionMode: _selectionMode,
              selectedBook: _selectedBooks.contains(book.id),
              selectedProgress: _selectedProgress,
              progressKey: _progressKey,
              loading: _loadingChapters.contains(book.id),
              totalChapters: _chapterTotals[book.id] ?? book.chapterCount,
              chapterPage: _chapterPages[book.id] ?? 1,
              onExpand: () => _toggleExpanded(book),
              onToggleBook: () => _toggleBook(book.id),
              onToggleProgress: _toggleProgress,
              onPage: (page) => _loadChapters(book.id, page),
              onOpenBook: widget.openBook,
            ),
            const SizedBox(height: 10),
          ],
          if (_total > _bookPageSize)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded)),
              Text('$_page / ${(_total / _bookPageSize).ceil()}'),
              IconButton(
                  onPressed: _page * _bookPageSize < _total
                      ? () => _load(page: _page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded)),
            ]),
        ],
        const SafeBottomSpacer(),
      ],
    );
  }
}

class _HistoryBook {
  _HistoryBook(
      {required this.id,
      required this.title,
      required this.updatedAt,
      required this.chapterCount,
      required this.latest,
      required this.chapters,
      this.cover,
      this.libraryId});
  final String id;
  final String title;
  final String? cover;
  final String? libraryId;
  final String? updatedAt;
  final int chapterCount;
  final ProgressItem latest;
  List<ProgressItem> chapters;
}

class _HistoryBookSection extends StatelessWidget {
  const _HistoryBookSection(
      {required this.book,
      required this.coverShape,
      required this.expanded,
      required this.selectionMode,
      required this.selectedBook,
      required this.selectedProgress,
      required this.progressKey,
      required this.loading,
      required this.totalChapters,
      required this.chapterPage,
      required this.onExpand,
      required this.onToggleBook,
      required this.onToggleProgress,
      required this.onPage,
      required this.onOpenBook});
  final _HistoryBook book;
  final CoverShape coverShape;
  final bool expanded;
  final bool selectionMode;
  final bool selectedBook;
  final Set<String> selectedProgress;
  final String Function(ProgressItem) progressKey;
  final bool loading;
  final int totalChapters;
  final int chapterPage;
  final VoidCallback onExpand;
  final VoidCallback onToggleBook;
  final ValueChanged<ProgressItem> onToggleProgress;
  final ValueChanged<int> onPage;
  final void Function(String, String?) onOpenBook;

  @override
  Widget build(BuildContext context) {
    return ActivityBookCard(
      book: Book(
          id: book.id,
          libraryId: book.libraryId ?? '',
          title: book.title,
          coverUrl: book.cover),
      coverShape: coverShape,
      countLabel: '${book.chapterCount} ${context.localeText('章', 'chapters')}',
      preview: book.latest.chapterTitle,
      meta: context.localeText('最后收听：${_displayDate(context, book.updatedAt)}',
          'Last listened: ${_displayDate(context, book.updatedAt)}'),
      percent: _percent(book.latest),
      expanded: expanded,
      onExpand: onExpand,
      selection: selectionMode
          ? BatchCheckbox(
              checked: selectedBook, onChanged: onToggleBook, compact: true)
          : null,
      child: Column(children: [
        for (final item in book.chapters)
          InkWell(
            onTap: selectionMode
                ? () => onToggleProgress(item)
                : () => onOpenBook(book.id, item.chapterId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: context.faintBorder.withValues(alpha: 0.5)))),
              child: Row(children: [
                if (selectionMode) ...[
                  BatchCheckbox(
                      checked: selectedProgress.contains(progressKey(item)),
                      onChanged: () => onToggleProgress(item),
                      compact: true),
                  const SizedBox(width: 12),
                ],
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          item.chapterTitle ??
                              context.localeText('未知章节', 'Unknown chapter'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.access_time_rounded,
                            size: 13, color: context.mutedText),
                        const SizedBox(width: 5),
                        Text(_displayDate(context, item.updatedAt),
                            style: TextStyle(
                                color: context.mutedText, fontSize: 12)),
                      ]),
                      ActivityProgress(percent: _percent(item)),
                    ])),
              ]),
            ),
          ),
        if (loading)
          const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        if (totalChapters > 50)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                onPressed: !loading && chapterPage > 1
                    ? () => onPage(chapterPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: context.localeText('上一页章节', 'Previous chapters')),
            Text('$chapterPage / ${(totalChapters / 50).ceil()}'),
            IconButton(
                onPressed: !loading && chapterPage * 50 < totalChapters
                    ? () => onPage(chapterPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: context.localeText('下一页章节', 'Next chapters')),
          ]),
        if (!loading && book.chapters.isEmpty)
          Padding(
              padding: const EdgeInsets.all(14),
              child: Text(context.localeText('暂无历史章节', 'No chapter history'),
                  style: TextStyle(color: context.mutedText))),
      ]),
    );
  }
}

String _displayDate(BuildContext context, String? value) {
  final date = backendDateTimeInApplicationTimeZone(
      value, AppScope.appOf(context).applicationTimeZone);
  if (date == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  final now =
      nowInApplicationTimeZone(AppScope.appOf(context).applicationTimeZone);
  final days = DateTime.utc(now.year, now.month, now.day)
      .difference(DateTime.utc(date.year, date.month, date.day))
      .inDays;
  final time = '${two(date.hour)}:${two(date.minute)}';
  if (days == 0) return context.localeText('今天 $time', 'Today $time');
  if (days == 1) return context.localeText('昨天 $time', 'Yesterday $time');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

class _HistoryActionButton extends StatelessWidget {
  const _HistoryActionButton(
      {required this.label,
      this.icon,
      this.onPressed,
      this.danger = false,
      this.loading = false});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) => BatchActionButton(
        label: label,
        icon: icon,
        onPressed: onPressed,
        danger: danger,
        loading: loading,
        compact: MediaQuery.sizeOf(context).width < 460,
      );
}

int _percent(ProgressItem item) {
  final duration = item.chapterDuration?.toDouble() ?? item.duration;
  if (duration <= 0) return 0;
  return (item.position / duration * 100).round().clamp(0, 100);
}
