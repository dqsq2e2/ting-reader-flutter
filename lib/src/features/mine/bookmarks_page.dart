import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/models/_helpers.dart' show readDouble, readInt, readString;
import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';
import 'activity_book_card.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  static const _pageSize = 40;
  final Set<String> _expanded = {};
  List<Map<String, dynamic>> _books = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(1));
  }

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await AppScope.appOf(context).api.get(
        '/api/bookmarks/books',
        params: {'page': page, 'page_size': _pageSize},
      );
      if (!mounted) return;
      final data = asMap(response.data);
      setState(() {
        _books = asMapList(data['items']);
        _total = readInt(data, 'total') ?? 0;
        _page = page;
        _expanded.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final app = AppScope.appOf(context);
    final coverShape = coverShapeFromAppSettings(app.settings);
    return PageListView(
      onRefresh: () => _load(_page),
      children: [
        AppBackButton(onPressed: widget.onBack),
        const SizedBox(height: 24),
        PageHeaderRow(
          icon: Icons.bookmarks_outlined,
          title: context.localeText('我的书签', 'My Bookmarks'),
          subtitle: context.localeText(
              '按书籍查看保存的位置和备注', 'Saved positions and notes, grouped by book'),
        ),
        const SizedBox(height: 18),
        if (_error != null)
          TextButton.icon(
              onPressed: () => _load(_page),
              icon: const Icon(Icons.refresh),
              label: Text(
                  context.localeText('加载失败，点击重试', 'Loading failed. Retry'))),
        if (_books.isEmpty && _error == null)
          Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                  child:
                      Text(context.localeText('还没有书签', 'No bookmarks yet')))),
        for (final item in _books) ...[
          Builder(builder: (context) {
            final id = readString(item, 'book_id') ?? '';
            final title = readString(item, 'book_title') ??
                context.localeText('未知书籍', 'Unknown book');
            final book = Book(
              id: id,
              libraryId: readString(item, 'library_id') ?? '',
              title: title,
              coverUrl: readString(item, 'cover_url'),
            );
            return ActivityBookCard(
              book: book,
              coverShape: coverShape,
              countLabel: context.localeText(
                  '${readInt(item, 'chapter_count') ?? 0} 个书签',
                  '${readInt(item, 'chapter_count') ?? 0} bookmarks'),
              expanded: _expanded.contains(id),
              onExpand: () => setState(() {
                if (!_expanded.add(id)) _expanded.remove(id);
              }),
              child: SizedBox(
                  height: ((readInt(item, 'chapter_count') ?? 0) * 155.0 + 24)
                      .clamp(180, 460),
                  child: BookBookmarkPanel(
                    book: book,
                    onCountChanged: (count) => setState(() {
                      item['chapter_count'] = count;
                      if (count == 0) {
                        _books.remove(item);
                        _total--;
                        if (_books.isEmpty && _page > 1) {
                          _load(_page - 1);
                        }
                      }
                    }),
                  )),
            );
          }),
          const SizedBox(height: 10),
        ],
        if (_total > _pageSize)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                onPressed: _page > 1 ? () => _load(_page - 1) : null,
                icon: const Icon(Icons.chevron_left)),
            Text('$_page / ${(_total / _pageSize).ceil()}'),
            IconButton(
                onPressed:
                    _page * _pageSize < _total ? () => _load(_page + 1) : null,
                icon: const Icon(Icons.chevron_right)),
          ]),
        const SafeBottomSpacer(),
      ],
    );
  }
}

/// Shared book bookmark panel used by My Bookmarks and the expanded player.
class BookBookmarkDialog extends StatelessWidget {
  const BookBookmarkDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final book = AppScope.playerOf(context).currentBook;
    if (book == null) return const SizedBox.shrink();
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: (MediaQuery.sizeOf(context).height * 0.8).clamp(0, 720),
        ),
        child: SizedBox(
          width: 500,
          child: BookBookmarkPanel(
            key: ValueKey(book.id),
            book: book,
            allowAdd: true,
          ),
        ),
      ),
    );
  }
}

class BookBookmarkPanel extends StatefulWidget {
  const BookBookmarkPanel(
      {super.key,
      required this.book,
      this.allowAdd = false,
      this.onCountChanged});
  final Book book;
  final bool allowAdd;
  final ValueChanged<int>? onCountChanged;

  @override
  State<BookBookmarkPanel> createState() => _BookBookmarkPanelState();
}

class _BookBookmarkPanelState extends State<BookBookmarkPanel> {
  static const _pageSize = 40;
  final _noteController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(1));
  }

  @override
  void didUpdateWidget(covariant BookBookmarkPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id == widget.book.id) return;
    _items = [];
    _total = 0;
    _page = 1;
    _saving = false;
    _noteController.clear();
    _load(1);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load(int page) async {
    if (!mounted) return;
    final revision = ++_loadRevision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await AppScope.appOf(context).api.get(
        '/api/bookmarks/books/${widget.book.id}',
        params: {'page': page, 'page_size': _pageSize},
      );
      if (!mounted || revision != _loadRevision) return;
      final data = asMap(response.data);
      setState(() {
        _items = asMapList(data['items'])
            .where((item) => item['book_id'] == widget.book.id)
            .toList();
        _page = page;
        _total = readInt(data, 'total') ?? 0;
      });
    } catch (error) {
      if (mounted && revision == _loadRevision) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && revision == _loadRevision) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _add() async {
    final player = AppScope.playerOf(context);
    final chapter = player.currentChapter;
    if (_saving ||
        chapter == null ||
        player.currentBook?.id != widget.book.id) {
      return;
    }
    final position = player.currentTime;
    setState(() => _saving = true);
    try {
      await AppScope.appOf(context).api.post('/api/bookmarks', data: {
        'book_id': widget.book.id,
        'chapter_id': chapter.id,
        'position': position,
        'note': _noteController.text,
      });
      if (!mounted) return;
      _noteController.clear();
      await _load(1);
      if (mounted) widget.onCountChanged?.call(_total);
    } catch (error) {
      if (mounted) {
        _message(context.localeText(
            '添加书签失败：$error', 'Could not add bookmark: $error'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final controller =
        TextEditingController(text: item['note']?.toString() ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.localeText('编辑书签备注', 'Edit bookmark note')),
        content:
            TextField(controller: controller, maxLength: 2000, maxLines: 3),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(context.localeText('保存', 'Save'))),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return;
    try {
      await AppScope.appOf(context)
          .api
          .put('/api/bookmarks/${item['id']}', data: {'note': note});
      if (mounted) await _load(1);
    } catch (error) {
      if (mounted) {
        _message(context.localeText('保存失败：$error', 'Save failed: $error'));
      }
    }
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    try {
      await AppScope.appOf(context).api.delete('/api/bookmarks/${item['id']}');
      if (!mounted) return;
      await _load(_items.length == 1 && _page > 1 ? _page - 1 : _page);
      if (mounted) widget.onCountChanged?.call(_total);
    } catch (error) {
      if (mounted) {
        _message(context.localeText('删除失败：$error', 'Delete failed: $error'));
      }
    }
  }

  Future<void> _jump(Map<String, dynamic> item) async {
    if (_saving || item['book_id'] != widget.book.id) return;
    final app = AppScope.appOf(context);
    final player = AppScope.playerOf(context);
    final bookId = widget.book.id;
    final position = readDouble(item, 'position') ?? 0;
    setState(() => _saving = true);
    try {
      if (player.currentBook?.id == bookId &&
          player.currentChapter?.id == item['chapter_id'] &&
          player.error == null) {
        await player.seek(position);
        if (!player.isPlaying) {
          unawaited(player.togglePlay().catchError(_jumpError));
        }
      } else {
        final responses = await Future.wait([
          app.api.get('/api/books/$bookId'),
          app.api.get('/api/books/$bookId/chapters'),
        ]);
        if (!mounted ||
            widget.book.id != bookId ||
            (widget.allowAdd && player.currentBook?.id != bookId)) {
          return;
        }
        final book = Book.fromJson(asMap(responses[0].data));
        final chapters =
            asMapList(responses[1].data).map(Chapter.fromJson).toList();
        final index =
            chapters.indexWhere((chapter) => chapter.id == item['chapter_id']);
        if (index < 0) throw StateError('Chapter unavailable');
        // Native play futures can last until playback stops. The dialog
        // should close when playback is requested, not at the chapter's end.
        unawaited(player
            .playChapter(book, chapters, chapters[index], startAt: position)
            .catchError(_jumpError));
      }
      if (mounted && widget.allowAdd) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        _message(context.localeText(
            '跳转失败：$error', 'Could not play bookmark: $error'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _jumpError(Object error) {
    if (!mounted) return;
    _message(
        context.localeText('跳转失败：$error', 'Could not play bookmark: $error'));
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final player = widget.allowAdd ? AppScope.playerOf(context) : null;
    final canAdd = player?.currentBook?.id == widget.book.id &&
        player?.currentChapter != null;
    return Column(
      mainAxisSize: widget.allowAdd ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (widget.allowAdd) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.bookmark_border_rounded, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                          child: Text(
                              context.localeText('本书书签', 'Book bookmarks'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 4),
                    Text(widget.book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: context.mutedText, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                  tooltip: context.localeText('关闭', 'Close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20)),
            ]),
          ),
          Divider(height: 1, color: context.faintBorder),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.localeText('备注', 'Note'),
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                    controller: _noteController,
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                        hintText: context.localeText(
                            '为当前位置添加备注', 'Add a note for this position'),
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6)))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: Text(
                          canAdd ? _bookmarkTime(player!.currentTime) : '',
                          style: TextStyle(
                              color: context.mutedText, fontSize: 12))),
                  FilledButton.icon(
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6))),
                      onPressed: canAdd && !_saving ? _add : null,
                      icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                      label: Text(context.localeText('添加书签', 'Add bookmark'))),
                ]),
              ],
            ),
          ),
          Divider(height: 1, color: context.faintBorder),
        ],
        Flexible(
            fit: widget.allowAdd ? FlexFit.loose : FlexFit.tight,
            child: _loading
                ? const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()))
                : _error != null
                    ? SizedBox(
                        height: 80,
                        child: Center(
                            child: TextButton(
                                onPressed: () => _load(_page),
                                child: Text(context.localeText(
                                    '加载失败，重试', 'Loading failed. Retry')))))
                    : _items.isEmpty
                        ? SizedBox(
                            height: 80,
                            child: Center(
                                child: Text(context.localeText(
                                    '还没有书签', 'No bookmarks yet'))))
                        : ListView.separated(
                            shrinkWrap: widget.allowAdd,
                            padding: EdgeInsets.zero,
                            itemCount: _items.length,
                            separatorBuilder: (context, index) =>
                                Divider(height: 1, color: context.faintBorder),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final note = item['note']?.toString() ?? '';
                              return InkWell(
                                onTap: _saving ? null : () => _jump(item),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Row(children: [
                                                Flexible(
                                                    child: Text(
                                                        readString(item,
                                                                'chapter_title') ??
                                                            context.localeText(
                                                                '未知章节',
                                                                'Unknown chapter'),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500))),
                                                const SizedBox(width: 6),
                                                Text('·',
                                                    style: TextStyle(
                                                        color:
                                                            context.mutedText,
                                                        fontSize: 12)),
                                                const SizedBox(width: 6),
                                                Text(
                                                    _bookmarkTime(readDouble(
                                                            item, 'position') ??
                                                        0),
                                                    style: TextStyle(
                                                        color:
                                                            context.mutedText,
                                                        fontSize: 12)),
                                              ]),
                                              const SizedBox(height: 4),
                                              Text(
                                                  note.isNotEmpty
                                                      ? note
                                                      : context.localeText(
                                                          '无备注', 'No note'),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: context.mutedText,
                                                      fontSize: 12)),
                                              ActivityProgress(
                                                  topSpacing: 8,
                                                  percent:
                                                      _bookmarkPercent(item)),
                                            ])),
                                        const SizedBox(width: 4),
                                        IconButton(
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                    width: 36, height: 40),
                                            padding: EdgeInsets.zero,
                                            tooltip: context.localeText(
                                                '编辑备注', 'Edit note'),
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18),
                                            onPressed: () => _edit(item)),
                                        IconButton(
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                    width: 36, height: 40),
                                            padding: EdgeInsets.zero,
                                            tooltip: context.localeText(
                                                '删除', 'Delete'),
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 18),
                                            onPressed: () => _remove(item)),
                                      ]),
                                ),
                              );
                            },
                          )),
        if (_total > _pageSize)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                onPressed:
                    !_loading && _page > 1 ? () => _load(_page - 1) : null,
                icon: const Icon(Icons.chevron_left)),
            Text('$_page / ${(_total / _pageSize).ceil()}'),
            IconButton(
                onPressed: !_loading && _page * _pageSize < _total
                    ? () => _load(_page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right)),
          ]),
      ],
    );
  }
}

int _bookmarkPercent(Map<String, dynamic> item) {
  final duration = readDouble(item, 'chapter_duration') ?? 0;
  final position = readDouble(item, 'position') ?? 0;
  if (duration <= 0 || !duration.isFinite || !position.isFinite) return 0;
  return (position / duration * 100).round().clamp(0, 100);
}

String _bookmarkTime(double seconds) {
  final duration = Duration(seconds: seconds.floor().clamp(0, 1 << 31));
  return '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}
