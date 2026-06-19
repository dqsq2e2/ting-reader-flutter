import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/download_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/urls.dart';
import '../../widgets/book_card.dart';
import '../../widgets/app_scope.dart';
import '../../widgets/common_widgets.dart';

part 'book_detail_components.dart';
part 'book_detail_chapter_section.dart';
part 'book_detail_editing.dart';
part 'book_detail_scrape.dart';
part 'book_detail_scrape_compare.dart';
part 'book_detail_scrape_widgets.dart';
part 'book_detail_chapter_manager.dart';

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({
    super.key,
    required this.bookId,
    required this.onBack,
  });

  final String bookId;
  final VoidCallback onBack;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  static const _chaptersPerGroup = 100;

  bool _loading = true;
  bool _chapterPageLoading = false;
  Book? _book;
  List<Chapter> _chapters = [];
  List<Chapter>? _allChaptersCache;
  ProgressItem? _bookProgress;
  int _chapterTotal = 0;
  int _mainChapterTotal = 0;
  int _extraChapterTotal = 0;
  bool _favorite = false;
  String _activeTab = 'main';
  int _groupIndex = 0;
  bool _chapterAscending = true;
  CoverShapePreference _coverShape = CoverShapePreference.rect;
  final _chapterSectionKey = GlobalKey();
  final Map<String, GlobalKey> _chapterRowKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BookDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final appState = AppScope.appOf(context);
    try {
      final results = await Future.wait<dynamic>([
        appState.api.get('/api/books/${widget.bookId}'),
        appState.api
            .get('/api/progress/${widget.bookId}')
            .then<ProgressItem?>(
                (res) => ProgressItem.fromJson(asMap(res.data)))
            .catchError((_) => null),
        appState.api.get('/api/settings'),
      ]);
      final bookResponse = results[0] as Response<dynamic>;
      final progress = results[1] as ProgressItem?;
      final settingsResponse = results[2] as Response<dynamic>;
      final book = Book.fromJson(asMap(bookResponse.data));
      final settings = asMap(asMap(settingsResponse.data)['settings_json'] ??
          asMap(settingsResponse.data)['settingsJson']);
      setState(() {
        _book = book;
        _chapters = [];
        _allChaptersCache = null;
        _bookProgress = progress;
        _chapterTotal = 0;
        _mainChapterTotal = 0;
        _extraChapterTotal = 0;
        _chapterRowKeys.clear();
        _favorite = book.isFavorite;
        _coverShape = (settings['bookshelf_cover_shape'] ??
                    settings['bookshelfCoverShape']) ==
                'square'
            ? CoverShapePreference.square
            : CoverShapePreference.rect;
        _groupIndex = 0;
      });
      await _loadChapterPage(targetChapterId: progress?.chapterId);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _activeTotal =>
      _activeTab == 'extra' ? _extraChapterTotal : _mainChapterTotal;

  int get _groupCount =>
      _activeTotal <= 0 ? 0 : ((_activeTotal - 1) ~/ _chaptersPerGroup) + 1;

  Future<ChaptersPage?> _loadChapterPage({
    String? tab,
    int? groupIndex,
    String? targetChapterId,
    bool scrollToTarget = false,
  }) async {
    final book = _book;
    if (book == null) return null;
    final requestedTab = tab ?? _activeTab;
    final requestedGroup = math.max(groupIndex ?? _groupIndex, 0);
    if (mounted) setState(() => _chapterPageLoading = true);
    try {
      final params = <String, dynamic>{
        'limit': _chaptersPerGroup,
        'offset': requestedGroup * _chaptersPerGroup,
        // Keep server pagination in canonical order; the UI toggles only the
        // visible group so group boundaries never jump between 1-100, 101-200...
        'order': 'asc',
      };
      if (!(targetChapterId != null && tab == null)) {
        params['chapter_type'] = requestedTab;
      }
      if (targetChapterId != null) {
        params['target_chapter_id'] = targetChapterId;
      }

      final res = await AppScope.appOf(context).api.get(
            '/api/books/${book.id}/chapters',
            params: params,
          );
      final page = ChaptersPage.fromJson(asMap(res.data));
      final resolvedTab = page.chapterType == 'extra' ? 'extra' : 'main';
      final resolvedGroup = page.offset ~/ _chaptersPerGroup;
      final visibleIds = page.chapters.map((chapter) => chapter.id).toSet();
      if (!mounted) return page;
      setState(() {
        _activeTab = resolvedTab;
        _groupIndex = resolvedGroup;
        _chapters = page.chapters;
        _chapterTotal = page.total;
        _mainChapterTotal = page.mainTotal;
        _extraChapterTotal = page.extraTotal;
        _chapterRowKeys.removeWhere((id, _) => !visibleIds.contains(id));
      });
      if (targetChapterId != null && scrollToTarget) {
        _ensureChapterVisible(targetChapterId);
      }
      return page;
    } finally {
      if (mounted) setState(() => _chapterPageLoading = false);
    }
  }

  Future<List<Chapter>> _fetchAllChapters({bool force = false}) async {
    if (!force && _allChaptersCache != null) return _allChaptersCache!;
    final book = _book;
    if (book == null) return const [];
    final player = AppScope.playerOf(context);
    if (!force &&
        player.currentBook?.id == book.id &&
        player.chapters.isNotEmpty) {
      _allChaptersCache = [...player.chapters]
        ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
      return _allChaptersCache!;
    }
    final res = await AppScope.appOf(context).api.get(
          '/api/books/${book.id}/chapters',
        );
    final chapters = asMapList(res.data).map(Chapter.fromJson).toList()
      ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    _allChaptersCache = chapters;
    return chapters;
  }

  Future<Chapter?> _resolveResumeChapter() async {
    final current = AppScope.playerOf(context).currentChapter;
    if (current?.bookId == _book?.id) return current;
    final progressChapterId = _bookProgress?.chapterId;
    if (progressChapterId != null) {
      final local =
          _chapters.where((chapter) => chapter.id == progressChapterId);
      if (local.isNotEmpty) return local.first;
      final page = await _loadChapterPage(
        targetChapterId: progressChapterId,
        scrollToTarget: false,
      );
      if (page != null) {
        final match =
            page.chapters.where((chapter) => chapter.id == progressChapterId);
        if (match.isNotEmpty) return match.first;
      }
    }
    if (_chapters.isNotEmpty) return _chapters.first;
    final page = await _loadChapterPage(tab: 'main', groupIndex: 0);
    if (page != null && page.chapters.isNotEmpty) return page.chapters.first;
    return null;
  }

  Chapter? get _resumeChapter {
    final book = _book;
    if (book == null || _chapters.isEmpty) return null;
    final player = AppScope.playerOf(context);
    if (player.currentChapter?.bookId == book.id) return player.currentChapter;
    final played = _chapters
        .where((chapter) => chapter.progressUpdatedAt != null)
        .toList()
      ..sort((a, b) => (DateTime.tryParse(b.progressUpdatedAt ?? '') ??
              DateTime(1970))
          .compareTo(
              DateTime.tryParse(a.progressUpdatedAt ?? '') ?? DateTime(1970)));
    if (played.isNotEmpty) return played.first;
    return _chapters.first;
  }

  Future<void> _toggleFavorite() async {
    final book = _book;
    if (book == null) return;
    final appState = AppScope.appOf(context);
    if (_favorite) {
      await appState.api.delete('/api/favorites/${book.id}');
    } else {
      await appState.api.post('/api/favorites/${book.id}');
    }
    setState(() => _favorite = !_favorite);
  }

  Future<void> _playResume() async {
    final book = _book;
    if (book == null) return;
    final player = AppScope.playerOf(context);
    final current = player.currentChapter;
    if (current?.bookId == book.id) {
      await _locateChapter(current!, loadPage: true);
      if (!player.isPlaying) {
        await player.togglePlay();
      }
      return;
    }
    final chapter = await _resolveResumeChapter();
    if (chapter == null) return;
    await _locateChapter(chapter, loadPage: true);
    await _playChapter(chapter);
  }

  Future<void> _playChapter(Chapter chapter) async {
    final book = _book;
    if (book == null) return;
    final allChapters = await _fetchAllChapters();
    if (!mounted) return;
    final list = allChapters
        .where((item) => item.isExtra == chapter.isExtra)
        .toList(growable: false);
    await AppScope.playerOf(context).playChapter(
      book,
      list.isEmpty ? allChapters : list,
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

  Future<void> _writeMetadata() async {
    final book = _book;
    if (book == null) return;
    await AppScope.appOf(context)
        .api
        .post('/api/books/${book.id}/write-metadata');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已开始后台写入元数据，请稍候查看任务进度。')),
    );
  }

  Future<void> _showScrapeDialog() async {
    final book = _book;
    if (book == null) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ScrapeDiffDialog(bookId: book.id),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _showChapterManager() async {
    final book = _book;
    if (book == null) return;
    final chapters = await _fetchAllChapters();
    if (!mounted) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ChapterManagerDialog(
        book: book,
        chapters: chapters,
      ),
    );
    if (changed == true) {
      _allChaptersCache = null;
      await _loadChapterPage(tab: _activeTab, groupIndex: _groupIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final book = _book;
    if (book == null) {
      return PageListView(
        children: [
          AppBackButton(onPressed: widget.onBack),
          const SizedBox(height: 24),
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: '未找到书籍',
            message: '这本书可能已被删除或您没有访问权限。',
          ),
        ],
      );
    }

    final appState = AppScope.appOf(context);
    final resume = _resumeChapter;
    final player = AppScope.playerOf(context);
    final currentChapter = player.currentChapter;
    final sameBookCurrentChapter =
        currentChapter?.bookId == book.id ? currentChapter : null;
    final highlightedChapterId = sameBookCurrentChapter?.id ?? resume?.id;
    final playLabel = sameBookCurrentChapter != null
        ? '正在播放：${sameBookCurrentChapter.title}'
        : resume == null
            ? '立即播放'
            : resume.progressPosition != null
                ? '继续播放：${resume.title}'
                : '立即播放';
    final themeColor = _effectiveThemeColor(book.themeColor);

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
                          .withOpacity(context.isDark ? 0.32 : 0.16),
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
                        text: book.author ?? '未知作者'),
                    _Meta(
                        icon: Icons.mic_rounded, text: book.narrator ?? '未知演播'),
                    _Meta(
                        icon: Icons.queue_music_rounded,
                        text: '$_chapterTotal 章节'),
                    if (book.year != null)
                      _Meta(icon: Icons.event_rounded, text: '${book.year}'),
                  ],
                ),
                if ((book.tags ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    alignment:
                        compact ? WrapAlignment.center : WrapAlignment.start,
                    spacing: 8,
                    runSpacing: 8,
                    children: book.tags!
                        .split(RegExp(r'[,，]'))
                        .map((tag) => tag.trim())
                        .where((tag) => tag.isNotEmpty)
                        .map((tag) => _BookTag(label: tag))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                _BookActionPanel(
                  favorite: _favorite,
                  admin: appState.isAdmin,
                  resumeLabel: playLabel,
                  themeColor: themeColor,
                  onPlay: _playResume,
                  onFavorite: _toggleFavorite,
                  onScrape: _showScrapeDialog,
                  onEdit: _showEditDialog,
                ),
                const SizedBox(height: 20),
                _DescriptionPanel(
                  description: book.description?.isNotEmpty == true
                      ? _inlineDescription(book.description!)
                      : '暂无简介',
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
                onTabChanged: (tab) =>
                    _loadChapterPage(tab: tab, groupIndex: 0),
                onManage: _showChapterManager,
              ),
            );
          },
        ),
        const SafeBottomSpacer(),
      ],
    );
    if (themeColor == null || context.isDark) return page;
    return ColoredBox(color: themeColor.withOpacity(0.05), child: page);
  }

  String _inlineDescription(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _showEditDialog() async {
    final book = _book;
    if (book == null) return;
    final title = TextEditingController(text: book.title);
    final author = TextEditingController(text: book.author ?? '');
    final narrator = TextEditingController(text: book.narrator ?? '');
    final tags = TextEditingController(text: book.tags ?? '');
    final genre = TextEditingController(text: book.genre ?? '');
    final year = TextEditingController(text: book.year?.toString() ?? '');
    final cover = TextEditingController(text: book.coverUrl ?? '');
    final skipIntro = TextEditingController(text: book.skipIntro.toString());
    final skipOutro = TextEditingController(text: book.skipOutro.toString());
    final chapterRegex = TextEditingController(text: book.chapterRegex ?? '');
    final description = TextEditingController(text: book.description ?? '');
    final genFilename = TextEditingController();
    final genNum = TextEditingController();
    final genTitle = TextEditingController();

    final result = await showDialog<_EditBookDialogResult>(
      context: context,
      builder: (context) {
        var saving = false;
        var deleting = false;
        var generating = false;
        var showRegexGenerator = false;
        Map<String, dynamic>? regexResult;
        String? dialogError;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> save() async {
              if (saving) return;
              setDialogState(() {
                saving = true;
                dialogError = null;
              });
              try {
                final payload = {
                  'title': title.text.trim(),
                  'author': author.text.trim(),
                  'narrator': narrator.text.trim(),
                  'tags': tags.text.trim(),
                  'genre': genre.text.trim(),
                  'year': int.tryParse(year.text.trim()),
                  'cover_url': cover.text.trim(),
                  'skip_intro': int.tryParse(skipIntro.text.trim()) ?? 0,
                  'skip_outro': int.tryParse(skipOutro.text.trim()) ?? 0,
                  'chapter_regex': chapterRegex.text.trim(),
                  'description': description.text.trim(),
                };
                final res = await AppScope.appOf(dialogContext).api.patch(
                      '/api/books/${book.id}',
                      data: payload,
                    );
                if (dialogContext.mounted) {
                  Navigator.pop(
                    dialogContext,
                    _EditBookDialogResult.saved(
                      Book.fromJson(asMap(res.data)),
                    ),
                  );
                }
              } catch (error) {
                setDialogState(() => dialogError = '保存失败：$error');
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => saving = false);
                }
              }
            }

            Future<void> deleteBook() async {
              final api = AppScope.appOf(dialogContext).api;
              final confirmed = await showDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) => AlertDialog(
                  title: const Text('确认删除书籍？'),
                  content: Text(
                    '此操作会从书架中移除《${book.title}》，并清除相关播放进度。',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child: const Text('取消'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(confirmContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffef4444),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('确认删除'),
                    ),
                  ],
                ),
              );
              if (!dialogContext.mounted || confirmed != true || deleting) {
                return;
              }
              setDialogState(() {
                deleting = true;
                dialogError = null;
              });
              try {
                await api.delete('/api/books/${book.id}');
                if (dialogContext.mounted) {
                  Navigator.pop(
                    dialogContext,
                    const _EditBookDialogResult.deleted(),
                  );
                }
              } catch (error) {
                setDialogState(() => dialogError = '删除失败：$error');
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => deleting = false);
                }
              }
            }

            Future<void> generateRegex() async {
              if (genFilename.text.trim().isEmpty ||
                  genNum.text.trim().isEmpty ||
                  genTitle.text.trim().isEmpty ||
                  generating) {
                return;
              }
              setDialogState(() {
                generating = true;
                dialogError = null;
              });
              try {
                final res = await AppScope.appOf(dialogContext).api.post(
                  '/api/tools/regex/generate',
                  data: {
                    'filename': genFilename.text.trim(),
                    'chapter_number': genNum.text.trim(),
                    'chapter_title': genTitle.text.trim(),
                  },
                );
                setDialogState(() => regexResult = asMap(res.data));
              } catch (error) {
                setDialogState(() => dialogError = '生成失败：$error');
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => generating = false);
                }
              }
            }

            final compact = MediaQuery.sizeOf(dialogContext).width < 700;
            final disabled = saving || deleting;

            Widget dialogBody() {
              if (showRegexGenerator) {
                final capturedIndex = (regexResult?['capturedIndex'] ??
                        regexResult?['captured_index'])
                    ?.toString();
                final capturedTitle = (regexResult?['capturedTitle'] ??
                        regexResult?['captured_title'])
                    ?.toString();
                final generatedRegex = regexResult?['regex']?.toString();
                return Padding(
                  padding: EdgeInsets.all(compact ? 20 : 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_fix_high_rounded,
                              color: AppColors.primary600),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '正则生成器',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setDialogState(() {
                              showRegexGenerator = false;
                              regexResult = null;
                            }),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _EditMetadataField(
                        controller: genFilename,
                        label: '示例文件名（不含后缀）',
                        hint: '例如：书名 第1集 章节名',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _EditMetadataField(
                              controller: genNum,
                              label: '提取章节号',
                              hint: '例如：1',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _EditMetadataField(
                              controller: genTitle,
                              label: '提取章节名',
                              hint: '例如：章节名',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: generating ? null : generateRegex,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          generating ? '生成中...' : '生成规则',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (generatedRegex != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: dialogContext.isDark
                                ? AppColors.slate800.withOpacity(0.5)
                                : AppColors.slate50,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: dialogContext.faintBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _EditFieldLabel('生成正则'),
                              const SizedBox(height: 7),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: dialogContext.cardColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: dialogContext.faintBorder),
                                ),
                                child: Text(
                                  generatedRegex,
                                  style: const TextStyle(
                                    color: AppColors.primary600,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _RegexMatchPreview(
                                      label: '提取序号',
                                      value: capturedIndex ?? '未匹配',
                                      matched: capturedIndex == genNum.text,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _RegexMatchPreview(
                                      label: '提取标题',
                                      value: capturedTitle ?? '未匹配',
                                      matched: capturedTitle == genTitle.text,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton(
                                onPressed: () {
                                  chapterRegex.text = generatedRegex;
                                  setDialogState(() {
                                    showRegexGenerator = false;
                                    regexResult = null;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary600,
                                  side: const BorderSide(
                                      color: AppColors.primary600, width: 2),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                child: const Text('使用此规则'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.all(compact ? 20 : 30),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 620;
                    final leftColumn = Column(
                      children: [
                        _EditMetadataField(controller: title, label: '书名'),
                        const SizedBox(height: 14),
                        _EditMetadataField(controller: author, label: '作者'),
                        const SizedBox(height: 14),
                        _EditMetadataField(controller: narrator, label: '演播者'),
                        const SizedBox(height: 14),
                        _EditMetadataField(controller: tags, label: '标签（逗号分隔）'),
                        const SizedBox(height: 14),
                        _EditMetadataField(controller: genre, label: '流派'),
                        const SizedBox(height: 14),
                        _EditMetadataField(
                          controller: year,
                          label: '年份',
                          hint: '例如: 2024',
                          number: true,
                        ),
                        const SizedBox(height: 14),
                        _EditMetadataField(
                          controller: chapterRegex,
                          label: '章节正则清洗规则',
                          mono: true,
                          hint: r'^...(\d+)...(.+)$',
                          helper: '用于从文件名提取章节号和标题。修改后需重新扫描生效。',
                          trailing: TextButton.icon(
                            onPressed: disabled
                                ? null
                                : () => setDialogState(
                                      () => showRegexGenerator = true,
                                    ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary600,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 24),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.auto_fix_high_rounded,
                                size: 14),
                            label: const Text(
                              '自动生成',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    );
                    final rightColumn = Column(
                      children: [
                        _EditMetadataField(controller: cover, label: '封面 URL'),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _EditMetadataField(
                                controller: skipIntro,
                                label: '跳过片头（秒）',
                                number: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _EditMetadataField(
                                controller: skipOutro,
                                label: '跳过片尾（秒）',
                                number: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '编辑书籍元数据',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (twoColumns)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: leftColumn),
                              const SizedBox(width: 18),
                              Expanded(child: rightColumn),
                            ],
                          )
                        else ...[
                          leftColumn,
                          const SizedBox(height: 14),
                          rightColumn,
                        ],
                        const SizedBox(height: 18),
                        _EditMetadataField(
                          controller: description,
                          label: '简介',
                          minLines: 4,
                          maxLines: 6,
                        ),
                      ],
                    );
                  },
                ),
              );
            }

            Widget footer() {
              final textStyle = TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w600,
              );
              final deleteButton = TextButton.icon(
                onPressed: disabled ? null : deleteBook,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xffef4444),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 14,
                    vertical: compact ? 9 : 12,
                  ),
                ),
                icon: deleting
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.delete_outline_rounded,
                        size: compact ? 17 : 19),
                label: Text(compact ? '删除' : '删除书籍', style: textStyle),
              );
              final writeButton = TextButton.icon(
                onPressed: disabled ? null : _writeMetadata,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary600,
                  backgroundColor: AppColors.primary50,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 11 : 18,
                    vertical: compact ? 9 : 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: Icon(Icons.edit_document, size: compact ? 17 : 19),
                label: Text(compact ? '写入' : '写入文件', style: textStyle),
              );
              final cancelButton = TextButton(
                onPressed: disabled ? null : () => Navigator.pop(dialogContext),
                style: TextButton.styleFrom(
                  foregroundColor: dialogContext.mutedText,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 11 : 18,
                    vertical: compact ? 9 : 13,
                  ),
                ),
                child: Text('取消', style: textStyle),
              );
              final saveButton = ElevatedButton.icon(
                onPressed: disabled ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary600,
                  foregroundColor: Colors.white,
                  elevation: 10,
                  shadowColor: AppColors.primary500.withOpacity(0.28),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 14 : 22,
                    vertical: compact ? 10 : 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.save_outlined, size: compact ? 17 : 19),
                label: Text(
                  saving
                      ? (compact ? '保存中' : '保存中...')
                      : (compact ? '保存' : '保存更改'),
                  style: textStyle,
                ),
              );
              final actions = Wrap(
                spacing: compact ? 8 : 10,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: compact
                    ? [deleteButton, writeButton, cancelButton, saveButton]
                    : [writeButton, cancelButton, saveButton],
              );
              if (compact) {
                return Align(alignment: Alignment.centerRight, child: actions);
              }
              return Row(
                children: [
                  deleteButton,
                  const Spacer(),
                  actions,
                ],
              );
            }

            return Dialog(
              insetPadding: EdgeInsets.all(compact ? 8 : 22),
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 900,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: dialogContext.cardColor,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(dialogContext.isDark ? 0.5 : 0.2),
                        blurRadius: 34,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(child: dialogBody()),
                      ),
                      if (dialogError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: Text(
                            dialogError!,
                            style: const TextStyle(
                              color: Color(0xffef4444),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 18 : 30,
                          14,
                          compact ? 18 : 30,
                          compact ? 18 : 24,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: dialogContext.faintBorder),
                          ),
                        ),
                        child: footer(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    for (final controller in [
      title,
      author,
      narrator,
      tags,
      genre,
      year,
      cover,
      skipIntro,
      skipOutro,
      chapterRegex,
      description,
      genFilename,
      genNum,
      genTitle,
    ]) {
      controller.dispose();
    }

    if (result?.deleted == true) {
      widget.onBack();
      return;
    }

    final saved = result?.book;
    if (saved != null) {
      setState(() {
        _book = _book!.copyWith(
          title: saved.title,
          author: saved.author,
          narrator: saved.narrator,
          description: saved.description,
          coverUrl: saved.coverUrl,
          tags: saved.tags,
          genre: saved.genre,
          year: saved.year,
          skipIntro: saved.skipIntro,
          skipOutro: saved.skipOutro,
          chapterRegex: saved.chapterRegex,
        );
      });
    }
  }
}

Color? _effectiveThemeColor(String? raw) {
  final color = _parseThemeColor(raw);
  if (color == null) return null;
  return _themeLuminance(color) > 0.9 ? null : color;
}

Color? _parseThemeColor(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  if (value.startsWith('#')) {
    var hex = value.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((char) => '$char$char').join();
    }
    if (hex.length == 6) {
      final rgb = int.tryParse(hex, radix: 16);
      if (rgb != null) return Color(0xff000000 | rgb);
    }
  }
  final match = RegExp(r'rgba?\(([^)]+)\)').firstMatch(value);
  if (match != null) {
    final parts = match
        .group(1)!
        .split(',')
        .map((part) => part.trim())
        .toList(growable: false);
    if (parts.length >= 3) {
      int? channel(String text) {
        final parsed = double.tryParse(text);
        if (parsed == null) return null;
        return parsed.round().clamp(0, 255);
      }

      final r = channel(parts[0]);
      final g = channel(parts[1]);
      final b = channel(parts[2]);
      if (r != null && g != null && b != null) {
        return Color.fromARGB(255, r, g, b);
      }
    }
  }
  return null;
}

double _themeLuminance(Color color) {
  return (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
}

bool _isThemeLight(Color color) => _themeLuminance(color) > 0.65;
