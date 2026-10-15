part of 'book_detail_page.dart';

class _ChapterSection extends StatefulWidget {
  const _ChapterSection({
    required this.book,
    required this.chapters,
    required this.groupCount,
    required this.activeTotal,
    required this.groupIndex,
    required this.groupDescending,
    required this.activeTab,
    required this.mainCount,
    required this.extraCount,
    required this.showExtraTab,
    required this.highlightedChapterId,
    required this.currentChapterId,
    required this.isPlaying,
    required this.loading,
    required this.themeColor,
    required this.admin,
    required this.rowKeys,
    required this.ascending,
    required this.onPlayChapter,
    required this.onToggleSort,
    required this.onGroupChanged,
    required this.onTabChanged,
    required this.onManage,
  });

  final Book book;
  final List<Chapter> chapters;
  final int groupCount;
  final int activeTotal;
  final int groupIndex;
  final bool groupDescending;
  final String activeTab;
  final int mainCount;
  final int extraCount;
  final bool showExtraTab;
  final String? highlightedChapterId;
  final String? currentChapterId;
  final bool isPlaying;
  final bool loading;
  final Color? themeColor;
  final bool admin;
  final Map<String, GlobalKey> rowKeys;
  final bool ascending;
  final Future<void> Function(Chapter chapter) onPlayChapter;
  final VoidCallback onToggleSort;
  final ValueChanged<int> onGroupChanged;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onManage;

  @override
  State<_ChapterSection> createState() => _ChapterSectionState();
}

class _ChapterSectionState extends State<_ChapterSection> {
  final Set<String> _selectedIds = {};
  final Map<int, GlobalKey> _groupKeys = {};
  bool _selectionMode = false;

  @override
  void didUpdateWidget(covariant _ChapterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final visibleIds = widget.chapters.map((chapter) => chapter.id).toSet();
    _selectedIds.removeWhere((id) => !visibleIds.contains(id));
    if (oldWidget.activeTab != widget.activeTab ||
        oldWidget.groupIndex != widget.groupIndex) {
      _selectedIds.clear();
    }
    if (oldWidget.groupIndex != widget.groupIndex ||
        oldWidget.activeTab != widget.activeTab) {
      _centerSelectedGroup();
    }
  }

  void _centerSelectedGroup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final groupContext = _groupKeys[widget.groupIndex]?.currentContext;
      if (groupContext == null) return;
      final horizontalScrollable = Scrollable.maybeOf(
        groupContext,
        axis: Axis.horizontal,
      );
      final target = groupContext.findRenderObject();
      if (horizontalScrollable == null || target == null || !target.attached) {
        return;
      }
      // Scrollable.ensureVisible traverses every ancestor scrollable, which
      // would overwrite the chapter-row jump in the outer vertical list.
      horizontalScrollable.position.ensureVisible(
        target,
        alignment: 0.5,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<Chapter> _downloadableChapters(DownloadState downloadState) {
    return widget.chapters
        .where((chapter) => downloadState.canQueueChapter(chapter.id))
        .toList();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleChapterSelection(Chapter chapter, DownloadState downloadState) {
    if (downloadState.hasChapter(chapter.id) ||
        downloadState.taskForChapter(chapter.id) != null) {
      return;
    }
    setState(() {
      if (_selectedIds.contains(chapter.id)) {
        _selectedIds.remove(chapter.id);
      } else {
        _selectedIds.add(chapter.id);
      }
    });
  }

  void _toggleCurrentPage(DownloadState downloadState) {
    final ids = _downloadableChapters(downloadState)
        .map((chapter) => chapter.id)
        .toList();
    setState(() {
      final allSelected = ids.every(_selectedIds.contains);
      if (allSelected) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  Future<void> _downloadChapter(Chapter chapter) async {
    try {
      final result = await AppScope.downloadOf(context)
          .requestChapter(widget.book, chapter);
      if (!mounted) return;
      _showDownloadMessage(
          result.messageForLocale(context.isEnglishLocale, chapter.title));
    } catch (error) {
      if (mounted) {
        _showDownloadMessage(context.localeText(
            '加入下载失败：$error', 'Failed to add download: $error'));
      }
    }
  }

  Future<void> _downloadSelected() async {
    final downloadState = AppScope.downloadOf(context);
    final targets = widget.chapters
        .where((chapter) =>
            _selectedIds.contains(chapter.id) &&
            downloadState.canQueueChapter(chapter.id))
        .toList()
      ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    if (targets.isEmpty) {
      _showDownloadMessage(
          context.localeText('没有可加入队列的章节', 'No chapters can be queued'));
      return;
    }
    var queued = 0;
    for (final chapter in targets) {
      try {
        final result = await downloadState.requestChapter(widget.book, chapter,
            resumeExisting: false);
        if (result.outcome == DownloadRequestOutcome.queued) queued++;
      } catch (err) {
        if (!mounted) return;
        _showDownloadMessage(
            context.localeText('加入下载失败：$err', 'Failed to add download: $err'));
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    if (queued > 0) {
      _showDownloadMessage(context.localeText(
          '已加入 $queued 个章节到下载队列', 'Queued $queued chapters'));
    }
  }

  void _showDownloadMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = AppScope.downloadOf(context);
    final downloadable = _downloadableChapters(downloadState);
    final allPageSelected = downloadable.isNotEmpty &&
        downloadable.map((chapter) => chapter.id).every(_selectedIds.contains);
    final selectedDownloadable = widget.chapters
        .where((chapter) =>
            _selectedIds.contains(chapter.id) &&
            downloadState.canQueueChapter(chapter.id))
        .length;
    final displayChapters = widget.chapters;
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 640 ? 16 : 24),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.isDark ? AppColors.slate800 : AppColors.slate100,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: context.isDark ? 0.12 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final headerFontSize = compact ? 20.0 : 24.0;
              final actionPadding = compact
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
              final actionIconSize = compact ? 15.0 : 17.0;
              final actionTextStyle = TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w700,
              );
              final title = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    color: AppColors.primary600,
                    size: compact ? 22 : 24,
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  Text(
                    context.localeText('章节列表', 'Chapters'),
                    style: TextStyle(
                      fontSize: headerFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
              final tabs = ChapterTypeSelector(
                activeTab: widget.activeTab,
                mainCount: widget.mainCount,
                extraCount: widget.extraCount,
                compact: compact,
                onChanged: widget.onTabChanged,
              );
              final manageButton = IconButton(
                tooltip: context.localeText('管理章节', 'Manage chapters'),
                onPressed: widget.onManage,
                style: IconButton.styleFrom(
                  foregroundColor: context.tertiaryText,
                  hoverColor:
                      context.isDark ? AppColors.slate800 : AppColors.slate100,
                  minimumSize: Size(compact ? 28 : 34, compact ? 28 : 34),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(compact ? 8 : 9),
                  ),
                ),
                icon: Icon(Icons.settings_rounded, size: compact ? 18 : 20),
              );
              final batchButton = TextButton.icon(
                onPressed:
                    widget.chapters.isEmpty ? null : _toggleSelectionMode,
                icon: Icon(
                  _selectionMode
                      ? Icons.close_rounded
                      : Icons.download_for_offline_outlined,
                  size: actionIconSize,
                ),
                label: Text(
                  _selectionMode
                      ? context.l10n.commonCancel
                      : context.localeText('批量下载', 'Batch Download'),
                  style: actionTextStyle,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _selectionMode
                      ? context.secondaryText
                      : AppColors.primary600,
                  backgroundColor: context.isDark
                      ? AppColors.slate800
                      : (_selectionMode
                          ? AppColors.slate100
                          : AppColors.primary50),
                  padding: actionPadding,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _selectionMode
                          ? context.faintBorder
                          : AppColors.primary100,
                    ),
                  ),
                ),
              );
              final sortButton = TextButton.icon(
                onPressed:
                    widget.chapters.length < 2 ? null : widget.onToggleSort,
                icon: Icon(
                  widget.ascending
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: actionIconSize,
                ),
                label: Text(
                  widget.ascending
                      ? context.localeText('正序', 'Ascending')
                      : context.localeText('倒序', 'Descending'),
                  style: actionTextStyle,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: context.secondaryText,
                  backgroundColor:
                      context.isDark ? AppColors.slate800 : AppColors.slate50,
                  padding: actionPadding,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: context.faintBorder),
                  ),
                ),
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  sortButton,
                  SizedBox(width: compact ? 6 : 10),
                  batchButton,
                ],
              );
              final header = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  if (widget.showExtraTab) ...[
                    if (widget.admin) ...[
                      SizedBox(width: compact ? 6 : 10),
                      manageButton,
                    ],
                    SizedBox(width: compact ? 8 : 12),
                    tabs,
                  ] else ...[
                    if (widget.admin) ...[
                      SizedBox(width: compact ? 6 : 10),
                      manageButton,
                    ],
                    SizedBox(width: compact ? 6 : 12),
                    actions,
                  ],
                ],
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: constraints.maxWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: header,
                      ),
                    ),
                  ),
                  if (widget.showExtraTab) ...[
                    SizedBox(height: compact ? 10 : 12),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: actions,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          if (widget.groupCount > 1) ...[
            const SizedBox(height: 24),
            HorizontalScrollControls(
              child: Row(
                children: [
                  for (final i in _visibleGroupIndexes(
                    widget.groupCount,
                    widget.groupDescending,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: KeyedSubtree(
                        key: _groupKeys.putIfAbsent(i, () => GlobalKey()),
                        child: _ChapterGroupButton(
                          label: _chapterGroupLabel(
                              context, i, widget.activeTotal),
                          selected: widget.groupIndex == i,
                          themeColor: widget.themeColor,
                          onPressed: () => widget.onGroupChanged(i),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (widget.loading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor:
                    context.isDark ? AppColors.slate800 : AppColors.slate100,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary500),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_selectionMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.isDark ? AppColors.slate800 : AppColors.slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.faintBorder),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final selectButton = BatchSelectButton(
                    checked: allPageSelected,
                    label: allPageSelected
                        ? context.localeText('取消本页', 'Unselect Page')
                        : context.localeText('全选本页', 'Select Page'),
                    compact: compact,
                    onPressed: downloadable.isEmpty
                        ? null
                        : () => _toggleCurrentPage(downloadState),
                  );
                  final countBadge = BatchCountBadge(
                    label: context.localeText('已选 $selectedDownloadable',
                        '$selectedDownloadable selected'),
                    compact: compact,
                  );
                  final downloadButton = BatchActionButton(
                    icon: Icons.download_rounded,
                    label: compact
                        ? context.localeText('下载', 'Download')
                        : context.localeText('下载选中', 'Download Selected'),
                    filled: true,
                    compact: compact,
                    onPressed:
                        selectedDownloadable == 0 ? null : _downloadSelected,
                  );
                  if (compact) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        selectButton,
                        countBadge,
                        downloadButton,
                      ],
                    );
                  }
                  final trailing = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.end,
                    children: [countBadge, downloadButton],
                  );
                  return Row(
                    children: [selectButton, const Spacer(), trailing],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.chapters.isEmpty)
            EmptyState(
              icon: Icons.queue_music_rounded,
              title: context.localeText('暂无章节', 'No Chapters'),
              message: context.localeText(
                  '这个分组下还没有章节。', 'This group has no chapters yet.'),
            )
          else
            Column(
              children: [
                for (var i = 0; i < displayChapters.length; i++)
                  KeyedSubtree(
                    key: widget.rowKeys.putIfAbsent(
                      displayChapters[i].id,
                      () => GlobalKey(),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i == displayChapters.length - 1 ? 0 : 12,
                      ),
                      child: _ChapterListRow(
                        chapter: displayChapters[i],
                        active: widget.highlightedChapterId ==
                            displayChapters[i].id,
                        playing:
                            widget.currentChapterId == displayChapters[i].id &&
                                widget.isPlaying,
                        themeColor: widget.themeColor,
                        selectionMode: _selectionMode,
                        selected: _selectedIds.contains(displayChapters[i].id),
                        downloaded:
                            downloadState.hasChapter(displayChapters[i].id),
                        task:
                            downloadState.taskForChapter(displayChapters[i].id),
                        onSelected: () => _toggleChapterSelection(
                          displayChapters[i],
                          downloadState,
                        ),
                        onPlay: () => widget.onPlayChapter(displayChapters[i]),
                        onDownload: () => _downloadChapter(displayChapters[i]),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

List<int> _visibleGroupIndexes(int groupCount, bool descending) {
  final indexes = List<int>.generate(groupCount, (index) => index);
  return descending ? indexes.reversed.toList(growable: false) : indexes;
}

String _chapterGroupLabel(BuildContext context, int groupIndex, int total) {
  if (total <= 0) return context.localeText('章节', 'Chapters');
  final start = groupIndex * _BookDetailPageState._chaptersPerGroup + 1;
  final end = math.min(
    start + _BookDetailPageState._chaptersPerGroup - 1,
    total,
  );
  return context.localeText('第 $start-$end 章', 'Chapters $start-$end');
}

class _ChapterGroupButton extends StatelessWidget {
  const _ChapterGroupButton({
    required this.label,
    required this.selected,
    required this.themeColor,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color? themeColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final themeColorValue = themeColor;
    final selectedBackground = themeColorValue ?? AppColors.primary600;
    final selectedForeground =
        themeColorValue != null && isBookThemeLight(themeColorValue)
            ? AppColors.slate600
            : Colors.white;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? selectedBackground
            : (context.isDark ? AppColors.slate800 : context.cardColor),
        foregroundColor: selected ? selectedForeground : context.mutedText,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? selectedBackground : context.faintBorder,
          ),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}
