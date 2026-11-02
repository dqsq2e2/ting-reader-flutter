import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/api/api_error.dart';
import '../../../core/models/models.dart';
import '../../../core/plugin_extensions/registry.dart';
import '../../../core/plugin_extensions/types.dart';
import '../../../core/state/books_state.dart';
import '../../../core/state/download_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/locale.dart';
import '../../../core/utils/urls.dart';
import '../../../shared/app_scope.dart';
import '../../../shared/common/common_widgets.dart';
import '../../../shared/common/chapter_type_selector.dart';
import '../../../shared/common/media_widgets.dart';
import '../../../shared/plugin_extensions/plugin_extension_host.dart';
import 'book_detail_editing.dart';
import 'book_detail_scrape.dart';
import 'chapter_manager_dialog.dart';

part 'book_detail_components.dart';
part 'book_detail_chapter_section.dart';
part 'book_detail_chapter_row.dart';

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({
    super.key,
    required this.bookId,
    this.initialChapterId,
    required this.onBack,
  });

  final String bookId;
  final String? initialChapterId;
  final VoidCallback onBack;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  static const _chaptersPerGroup = 100;

  BookDetailState? _detail;
  bool get _loading => _detail?.loading ?? true;
  bool get _chapterPageLoading => _detail?.pageLoading ?? false;
  Book? get _book => _detail?.book;
  List<Chapter> get _chapters => _detail?.chapters ?? const [];
  ProgressItem? get _bookProgress => _detail?.progress;
  int get _chapterTotal => _detail?.total ?? 0;
  int get _mainChapterTotal => _detail?.mainTotal ?? 0;
  int get _extraChapterTotal => _detail?.extraTotal ?? 0;
  bool get _favorite => _book?.isFavorite ?? false;
  String get _activeTab => _detail?.tab ?? 'main';
  set _activeTab(String value) {
    _detail?.tab = value;
  }

  int get _groupIndex => _detail?.group ?? 0;
  bool get _chapterAscending => _detail?.ascending ?? true;
  set _chapterAscending(bool value) {
    _detail?.ascending = value;
  }

  bool get _chapterGroupsDescending => _detail?.groupsDescending ?? false;
  bool _tagsExpanded = false;
  CoverShapePreference _coverShape = CoverShapePreference.square;
  final _chapterSectionKey = GlobalKey();
  final _chapterInlineHeaderKey = GlobalKey();
  final _pageStackKey = GlobalKey();
  final ValueNotifier<bool> _chapterHeaderStuck = ValueNotifier<bool>(false);
  bool _chapterSelectionMode = false;
  final Set<String> _selectedChapterIds = {};
  bool _headerCheckScheduled = false;
  final Map<String, GlobalKey> _chapterRowKeys = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_detail == null) _bindDetail();
  }

  void _bindDetail() {
    final app = AppScope.appOf(context);
    _detail = BookDetailState(app.api, widget.bookId, cache: app.libraryCache)
      ..addListener(_detailChanged);
    _load();
  }

  void _detailChanged() {
    if (!mounted) return;
    setState(() {
      _coverShape = _detail?.settings['bookshelf_cover_shape'] == 'rect'
          ? CoverShapePreference.rect
          : CoverShapePreference.square;
      final visible = _chapters.map((chapter) => chapter.id).toSet();
      _chapterRowKeys.removeWhere((id, _) => !visible.contains(id));
      _selectedChapterIds.removeWhere((id) => !visible.contains(id));
    });
  }

  @override
  void didUpdateWidget(covariant BookDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) {
      _detail?.removeListener(_detailChanged);
      _detail?.dispose();
      _chapterRowKeys.clear();
      _bindDetail();
    } else if (oldWidget.initialChapterId != widget.initialChapterId) {
      _load();
    }
  }

  @override
  void dispose() {
    _detail?.removeListener(_detailChanged);
    _detail?.dispose();
    _chapterHeaderStuck.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final initialChapterIdValue = widget.initialChapterId;
    _tagsExpanded = false;
    final detail = _detail;
    await detail?.load(initialChapter: initialChapterIdValue);
    if (mounted &&
        identical(detail, _detail) &&
        initialChapterIdValue != null) {
      _ensureChapterVisible(initialChapterIdValue);
    }
  }

  int get _activeTotal =>
      _activeTab == 'extra' ? _extraChapterTotal : _mainChapterTotal;
  int get _groupCount =>
      _activeTotal <= 0 ? 0 : ((_activeTotal - 1) ~/ _chaptersPerGroup) + 1;

  Future<ChaptersPage?> _loadChapterPage(
      {String? tab,
      int? groupIndex,
      String? targetChapterId,
      bool scrollToTarget = false,
      bool preferLastGroup = false}) async {
    final detail = _detail;
    final page = await detail?.loadPage(
        requestedTab: tab,
        requestedGroup: groupIndex,
        target: targetChapterId,
        preferLast: preferLastGroup);
    if (mounted &&
        identical(detail, _detail) &&
        page != null &&
        scrollToTarget &&
        targetChapterId != null) {
      _ensureChapterVisible(targetChapterId);
    }
    return page;
  }

  Future<List<Chapter>> _fetchAllChapters({bool force = false}) async {
    final detail = _detail;
    if (force) detail?.catalogue.invalidate();
    final chapters = await detail?.catalogue.all();
    return identical(detail, _detail) ? chapters ?? const [] : const [];
  }

  Future<Chapter?> _resolveResumeChapter() =>
      _detail?.resolveResume(
          widget.initialChapterId, AppScope.playerOf(context).currentChapter) ??
      Future.value(null);

  Chapter? get _resumeChapter {
    final book = _book;
    if (book == null || _chapters.isEmpty) return null;
    final player = AppScope.playerOf(context);
    if (player.currentChapter?.bookId == book.id) return player.currentChapter;
    final initialChapterId = widget.initialChapterId;
    if (initialChapterId != null) {
      final initial =
          _chapters.where((chapter) => chapter.id == initialChapterId);
      if (initial.isNotEmpty) return initial.first;
    }
    final progress = _bookProgress;
    final progressChapterId = progress?.chapterId;
    if (progress != null &&
        progressChapterId != null &&
        progressChapterId.isNotEmpty) {
      final local =
          _chapters.where((chapter) => chapter.id == progressChapterId);
      if (local.isNotEmpty) return local.first;
      return Chapter(
        id: progressChapterId,
        bookId: book.id,
        title:
            progress.chapterTitle ?? context.l10n.bookDetailLastListenedChapter,
        path: '',
        chapterIndex: 0,
        duration: progress.chapterDuration ?? progress.duration.round(),
        progressPosition: progress.position,
        progressUpdatedAt: progress.updatedAt,
      );
    }
    final played = _chapters
        .where((chapter) => chapter.progressUpdatedAt != null)
        .toList()
      ..sort((a, b) => (DateTime.tryParse(b.progressUpdatedAt ?? '') ??
              DateTime(1970))
          .compareTo(
              DateTime.tryParse(a.progressUpdatedAt ?? '') ?? DateTime(1970)));
    if (played.isNotEmpty) return played.first;
    return null;
  }

  Future<void> _toggleFavorite() async {
    await _detail?.toggleFavorite();
  }

  Future<void> _playResume() async {
    final detail = _detail;
    final book = _book;
    if (book == null) return;
    final player = AppScope.playerOf(context);
    final current = player.currentChapter;
    if (current != null && current.bookId == book.id) {
      await _locateChapter(current, loadPage: true);
      if (!mounted || !identical(detail, _detail)) return;
      if (!player.isPlaying) {
        await player.togglePlay();
      }
      return;
    }
    final chapter = await _resolveResumeChapter();
    if (!mounted || !identical(detail, _detail)) return;
    if (chapter == null) {
      if (_chapters.isEmpty) {
        await _loadChapterPage(tab: 'main', groupIndex: 0);
      }
      if (!mounted || !identical(detail, _detail)) return;
      if (_chapters.isEmpty) return;
      await _playChapter(_chapters.first);
      return;
    }
    await _locateChapter(chapter, loadPage: true);
    if (!mounted || !identical(detail, _detail)) return;
    await _playChapter(chapter);
  }

  Future<void> _playChapter(Chapter chapter) async {
    final detail = _detail;
    final book = _book;
    if (book == null || chapter.bookId != book.id) return;
    final allChapters =
        book.libraryType == 'source' ? _chapters : await _fetchAllChapters();
    if (!mounted || !identical(detail, _detail)) return;
    await AppScope.playerOf(context).playChapter(
      book,
      allChapters,
      chapter,
    );
  }

  Future<void> _locateChapter(
    Chapter chapter, {
    bool scroll = true,
    bool loadPage = false,
  }) async {
    if (!mounted) return;
    final targetTab = chapter.isExtra ? 'extra' : 'main';
    if (loadPage || !_chapters.any((item) => item.id == chapter.id)) {
      await _loadChapterPage(
        tab: targetTab,
        targetChapterId: chapter.id,
        scrollToTarget: scroll,
      );
      return;
    }
    if (_activeTab != targetTab) setState(() => _activeTab = targetTab);
    if (scroll) _ensureChapterVisible(chapter.id);
  }

  void _ensureChapterVisible(String chapterId, {int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _chapterRowKeys[chapterId]?.currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (attempt < 3) {
        _ensureChapterVisible(chapterId, attempt: attempt + 1);
        return;
      }
      final sectionContext = _chapterSectionKey.currentContext;
      if (sectionContext != null) {
        Scrollable.ensureVisible(
          sectionContext,
          alignment: 0.08,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  bool _handlePageScroll(ScrollNotification notification) {
    if (notification.depth == 0) _scheduleHeaderCheck();
    return false;
  }

  void _scheduleHeaderCheck() {
    if (_headerCheckScheduled) return;
    _headerCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerCheckScheduled = false;
      _checkHeaderPosition();
    });
  }

  void _checkHeaderPosition() {
    if (!mounted) return;
    final headerContext = _chapterInlineHeaderKey.currentContext;
    final stackContext = _pageStackKey.currentContext;
    if (headerContext == null || stackContext == null) {
      if (_chapterHeaderStuck.value) _chapterHeaderStuck.value = false;
      return;
    }
    final headerBox = headerContext.findRenderObject();
    final stackBox = stackContext.findRenderObject();
    if (headerBox is! RenderBox ||
        stackBox is! RenderBox ||
        !headerBox.attached ||
        !stackBox.attached) {
      return;
    }
    final top = stackBox.globalToLocal(headerBox.localToGlobal(Offset.zero)).dy;
    final sectionBox =
        _chapterSectionKey.currentContext?.findRenderObject() as RenderBox?;
    final sectionBottom = sectionBox == null || !sectionBox.attached
        ? double.infinity
        : stackBox
            .globalToLocal(
                sectionBox.localToGlobal(Offset(0, sectionBox.size.height)))
            .dy;
    final stuck = top <= 0.5 && sectionBottom > 0;
    if (stuck != _chapterHeaderStuck.value) {
      _chapterHeaderStuck.value = stuck;
    }
  }

  void _toggleChapterSelectionMode() {
    setState(() {
      _chapterSelectionMode = !_chapterSelectionMode;
      if (!_chapterSelectionMode) _selectedChapterIds.clear();
    });
  }

  List<Chapter> _downloadableVisibleChapters(DownloadState downloadState) {
    return _chapters
        .where((chapter) => downloadState.canQueueChapter(chapter.id))
        .toList();
  }

  bool _isChapterSelectable(DownloadState downloadState, String chapterId) {
    return !downloadState.hasChapter(chapterId) &&
        downloadState.taskForChapter(chapterId) == null;
  }

  void _toggleChapterSelected(Chapter chapter) {
    final downloadState = AppScope.downloadOf(context);
    if (!_isChapterSelectable(downloadState, chapter.id)) return;
    setState(() {
      if (!_selectedChapterIds.remove(chapter.id)) {
        _selectedChapterIds.add(chapter.id);
      }
    });
  }

  void _toggleVisiblePageSelection() {
    final downloadState = AppScope.downloadOf(context);
    final ids = _downloadableVisibleChapters(downloadState)
        .map((chapter) => chapter.id)
        .toList();
    if (ids.isEmpty) return;
    setState(() {
      final allSelected = ids.every(_selectedChapterIds.contains);
      if (allSelected) {
        _selectedChapterIds.removeAll(ids);
      } else {
        _selectedChapterIds.addAll(ids);
      }
    });
  }

  Future<void> _downloadSelectedChapters() async {
    final book = _book;
    if (book == null) return;
    final downloadState = AppScope.downloadOf(context);
    final targets = _chapters
        .where((chapter) =>
            _selectedChapterIds.contains(chapter.id) &&
            downloadState.canQueueChapter(chapter.id))
        .toList()
      ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    if (targets.isEmpty) {
      _showChapterDownloadMessage(
          context.localeText('没有可加入队列的章节', 'No chapters can be queued'));
      return;
    }
    var queued = 0;
    for (final chapter in targets) {
      try {
        final result = await downloadState.requestChapter(book, chapter,
            resumeExisting: false);
        if (result.outcome == DownloadRequestOutcome.queued) queued++;
      } catch (error) {
        if (!mounted) return;
        _showChapterDownloadMessage(context.localeText(
            '加入下载失败：${ApiError.messageFor(error)}',
            'Failed to add download: ${ApiError.messageFor(error)}'));
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _selectedChapterIds.clear();
      _chapterSelectionMode = false;
    });
    if (queued > 0) {
      _showChapterDownloadMessage(context.localeText(
          '已加入 $queued 个章节到下载队列', 'Queued $queued chapters'));
    }
  }

  void _showChapterDownloadMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showScrapeDialog() async {
    final book = _book;
    if (book == null) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScrapeDiffDialog(bookId: book.id),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _showChapterManager() async {
    final detail = _detail;
    final book = _book;
    if (book == null) return;
    final chapters = await _fetchAllChapters();
    if (!mounted || !identical(detail, _detail)) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChapterManagerDialog(
        book: book,
        chapters: chapters,
      ),
    );
    if (mounted && identical(detail, _detail) && changed == true) {
      _detail?.catalogue.invalidate();
      await _loadChapterPage(tab: _activeTab, groupIndex: _groupIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_detail?.error != null && _book == null) {
      return PageListView(children: [
        AppBackButton(onPressed: widget.onBack),
        LoadErrorView(onRetry: _load),
      ]);
    }
    final book = _book;
    if (book == null) {
      return PageListView(
        children: [
          AppBackButton(onPressed: widget.onBack),
          const SizedBox(height: 24),
          EmptyState(
            icon: Icons.search_off_rounded,
            title: context.l10n.bookDetailNotFoundTitle,
            message: context.l10n.bookDetailNotFoundMessage,
          ),
        ],
      );
    }

    final appState = AppScope.appOf(context);
    final downloadState = AppScope.downloadOf(context);
    final description = book.description;
    final tags = book.tags;
    final resume = _resumeChapter;
    final player = AppScope.playerOf(context);
    final currentChapter = player.currentChapter;
    final sameBookCurrentChapter =
        currentChapter?.bookId == book.id ? currentChapter : null;
    final initialChapterId = widget.initialChapterId;
    final highlightedChapterId = initialChapterId != null &&
            _chapters.any((chapter) => chapter.id == initialChapterId)
        ? initialChapterId
        : sameBookCurrentChapter?.id ?? resume?.id;
    final playLabel = sameBookCurrentChapter != null
        ? context.l10n.bookDetailNowPlaying(sameBookCurrentChapter.title)
        : resume == null
            ? context.l10n.bookDetailPlayNow
            : resume.progressPosition != null
                ? context.l10n.bookDetailContinuePlaying(resume.title)
                : context.l10n.bookDetailPlayNow;
    final themeColor = effectiveBookThemeColor(book.themeColor);
    final visibleChapters = _chapterAscending
        ? _chapters
        : _chapters.reversed.toList(growable: false);
    final sidePadding = MediaQuery.sizeOf(context).width < 640 ? 16.0 : 24.0;
    final downloadableIds = _chapters
        .where((chapter) => downloadState.canQueueChapter(chapter.id))
        .map((chapter) => chapter.id)
        .toSet();
    final allPageSelected = downloadableIds.isNotEmpty &&
        downloadableIds.every(_selectedChapterIds.contains);
    final selectedDownloadable =
        downloadableIds.where(_selectedChapterIds.contains).length;

    Widget buildChapterHeader({required bool sticky, Key? key}) {
      return _ChapterSectionHeader(
        key: key,
        chapters: visibleChapters,
        groupCount: _groupCount,
        activeTotal: _activeTotal,
        groupIndex: _groupIndex,
        groupDescending: _chapterGroupsDescending,
        activeTab: _activeTab,
        mainCount: _mainChapterTotal,
        extraCount: _extraChapterTotal,
        showExtraTab: _extraChapterTotal > 0,
        admin: appState.isAdmin,
        ascending: _chapterAscending,
        themeColor: themeColor,
        selectionMode: _chapterSelectionMode,
        selectedDownloadable: selectedDownloadable,
        allPageSelected: allPageSelected,
        hasSelectable: downloadableIds.isNotEmpty,
        sidePadding: sidePadding,
        sticky: sticky,
        onToggleCurrentPage: _toggleVisiblePageSelection,
        onDownloadSelected: _downloadSelectedChapters,
        onToggleSort: () {
          setState(() => _chapterAscending = !_chapterAscending);
        },
        onGroupChanged: (index) =>
            _loadChapterPage(tab: _activeTab, groupIndex: index),
        onTabChanged: (tab) => _loadChapterPage(
          tab: tab,
          groupIndex:
              _chapterGroupsDescending ? _detail?.lastGroup(tab) ?? 0 : 0,
        ),
        onManage: _showChapterManager,
        onToggleSelectionMode: _toggleChapterSelectionMode,
      );
    }

    final pageView = PageListView(
      onRefresh: _load,
      children: [
        _DetailBackButton(onPressed: widget.onBack),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final cover = SizedBox(
              width: compact ? 192 : 288,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: context.isDark
                        ? AppColors.slate800
                        : AppColors.slate200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: context.isDark ? 0.32 : 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio:
                      _coverShape == CoverShapePreference.square ? 1 : 3 / 4,
                  child: CoverImage(
                    url: bookCoverUrl(appState, book),
                    radius: 24,
                  ),
                ),
              ),
            );

            final infoContent = Column(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 24 : 30,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _BookMetadataRow(
                  centered: compact,
                  author: book.author ?? context.l10n.bookDetailUnknownAuthor,
                  narrator:
                      book.narrator ?? context.l10n.bookDetailUnknownNarrator,
                  chapters: context.l10n.bookDetailChapterCount(_chapterTotal),
                ),
                if (book.year != null) ...[
                  const SizedBox(height: 8),
                  _Meta(icon: Icons.event_rounded, text: '${book.year}'),
                ],
                if (tags != null && tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _CollapsibleBookTags(
                    tags: tags
                        .split(RegExp(r'[,，]'))
                        .map((tag) => tag.trim())
                        .where((tag) => tag.isNotEmpty)
                        .toList(),
                    expanded: _tagsExpanded,
                    alignment:
                        compact ? WrapAlignment.center : WrapAlignment.start,
                    onExpandedChanged: (value) {
                      setState(() => _tagsExpanded = value);
                    },
                  ),
                ],
                const SizedBox(height: 24),
                _BookActionPanel(
                  favorite: _favorite,
                  admin: appState.isAdmin,
                  resumeLabel: playLabel,
                  themeColor: themeColor,
                  extensionContext: {
                    'book_id': book.id,
                    'book_title': book.title,
                    'book_path': book.path,
                    'library_id': book.libraryId,
                    'author': book.author,
                    'narrator': book.narrator,
                    'chapter_count': _chapterTotal,
                  },
                  onPlay: _playResume,
                  onFavorite: _toggleFavorite,
                  onScrape: _showScrapeDialog,
                  onEdit: _showEditDialog,
                ),
                const SizedBox(height: 20),
                _DescriptionPanel(
                  description: description != null && description.isNotEmpty
                      ? _inlineDescription(description)
                      : context.l10n.bookDetailNoDescription,
                  themeColor: themeColor,
                ),
              ],
            );
            final Widget info =
                compact ? infoContent : Expanded(child: infoContent);

            return compact
                ? Column(
                    children: [
                      cover,
                      const SizedBox(height: 28),
                      info,
                    ],
                  )
                : Row(
                    crossAxisAlignment:
                        _coverShape == CoverShapePreference.square
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                    children: [
                      cover,
                      const SizedBox(width: 32),
                      info,
                    ],
                  );
          },
        ),
        const SizedBox(height: 32),
        FullBleed(
          child: KeyedSubtree(
            key: _chapterSectionKey,
            child: _ChapterSection(
              book: book,
              header: buildChapterHeader(
                sticky: false,
                key: _chapterInlineHeaderKey,
              ),
              chapters: visibleChapters,
              groupIndex: _groupIndex,
              activeTab: _activeTab,
              highlightedChapterId: highlightedChapterId,
              currentChapterId: sameBookCurrentChapter?.id,
              isPlaying: player.isPlaying,
              loading: _chapterPageLoading,
              themeColor: themeColor,
              rowKeys: _chapterRowKeys,
              selectionMode: _chapterSelectionMode,
              selectedIds: _selectedChapterIds,
              onToggleSelected: _toggleChapterSelected,
              onPlayChapter: (chapter) async {
                await _playChapter(chapter);
              },
            ),
          ),
        ),
        const SafeBottomSpacer(),
      ],
    );
    final page = Stack(
      key: _pageStackKey,
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handlePageScroll,
            child: pageView,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: _chapterHeaderStuck,
            builder: (context, stuck, _) {
              if (!stuck) return const SizedBox.shrink();
              return buildChapterHeader(sticky: true);
            },
          ),
        ),
      ],
    );
    _scheduleHeaderCheck();
    if (themeColor == null || context.isDark) return page;
    return ColoredBox(color: themeColor.withValues(alpha: 0.05), child: page);
  }

  String _inlineDescription(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _showEditDialog() async {
    final detail = _detail;
    if (detail == null) return;
    final result = await showBookEditorDialog(context, detail);
    if (!mounted || !identical(detail, _detail)) return;
    if (result?.deleted == true) {
      widget.onBack();
      return;
    }
    final saved = result?.book;
    if (saved != null) {
      AppScope.playerOf(context).updateBookMetadata(saved);
      await _loadChapterPage(tab: _activeTab, groupIndex: _groupIndex);
    }
  }
}
