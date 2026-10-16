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
  final Map<String, GlobalKey> _chapterRowKeys = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_detail == null) _bindDetail();
  }

  void _bindDetail() {
    _detail = BookDetailState(AppScope.appOf(context).api, widget.bookId)
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
    final allChapters = await _fetchAllChapters();
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
    if (_detail?.error != null) {
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

    final page = PageListView(
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
                Wrap(
                  alignment:
                      compact ? WrapAlignment.center : WrapAlignment.start,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _Meta(
                        icon: Icons.person_rounded,
                        text: book.author ??
                            context.l10n.bookDetailUnknownAuthor),
                    _Meta(
                        icon: Icons.mic_rounded,
                        text: book.narrator ??
                            context.l10n.bookDetailUnknownNarrator),
                    _Meta(
                        icon: Icons.queue_music_rounded,
                        text:
                            context.l10n.bookDetailChapterCount(_chapterTotal)),
                    if (book.year != null)
                      _Meta(icon: Icons.event_rounded, text: '${book.year}'),
                  ],
                ),
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
        Builder(
          builder: (context) {
            final visibleChapters = _chapterAscending
                ? _chapters
                : _chapters.reversed.toList(growable: false);
            return KeyedSubtree(
              key: _chapterSectionKey,
              child: _ChapterSection(
                book: book,
                chapters: visibleChapters,
                groupCount: _groupCount,
                activeTotal: _activeTotal,
                groupIndex: _groupIndex,
                groupDescending: _chapterGroupsDescending,
                activeTab: _activeTab,
                mainCount: _mainChapterTotal,
                extraCount: _extraChapterTotal,
                showExtraTab: _extraChapterTotal > 0,
                highlightedChapterId: highlightedChapterId,
                currentChapterId: sameBookCurrentChapter?.id,
                isPlaying: player.isPlaying,
                loading: _chapterPageLoading,
                themeColor: themeColor,
                admin: appState.isAdmin,
                rowKeys: _chapterRowKeys,
                ascending: _chapterAscending,
                onPlayChapter: (chapter) async {
                  await _playChapter(chapter);
                },
                onToggleSort: () {
                  setState(() => _chapterAscending = !_chapterAscending);
                },
                onGroupChanged: (index) =>
                    _loadChapterPage(tab: _activeTab, groupIndex: index),
                onTabChanged: (tab) => _loadChapterPage(
                  tab: tab,
                  groupIndex: _chapterGroupsDescending
                      ? _detail?.lastGroup(tab) ?? 0
                      : 0,
                ),
                onManage: _showChapterManager,
              ),
            );
          },
        ),
        const SafeBottomSpacer(),
      ],
    );
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
