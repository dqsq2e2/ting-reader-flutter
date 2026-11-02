part of 'book_detail_page.dart';

class _ChapterSection extends StatefulWidget {
  const _ChapterSection({
    required this.book,
    required this.header,
    required this.chapters,
    required this.groupIndex,
    required this.activeTab,
    required this.highlightedChapterId,
    required this.currentChapterId,
    required this.isPlaying,
    required this.loading,
    required this.themeColor,
    required this.rowKeys,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelected,
    required this.onPlayChapter,
  });

  final Book book;
  final Widget header;
  final List<Chapter> chapters;
  final int groupIndex;
  final String activeTab;
  final String? highlightedChapterId;
  final String? currentChapterId;
  final bool isPlaying;
  final bool loading;
  final Color? themeColor;
  final Map<String, GlobalKey> rowKeys;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<Chapter> onToggleSelected;
  final Future<void> Function(Chapter chapter) onPlayChapter;

  @override
  State<_ChapterSection> createState() => _ChapterSectionState();
}

class _ChapterSectionState extends State<_ChapterSection> {
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
            '加入下载失败：${ApiError.messageFor(error)}',
            'Failed to add download: ${ApiError.messageFor(error)}'));
      }
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
    final compactLayout = MediaQuery.sizeOf(context).width < 640;
    final sidePadding = compactLayout ? 16.0 : 24.0;
    final downloadState = AppScope.downloadOf(context);
    final displayChapters = widget.chapters;
    return Container(
      // Full-width rows: the section spans the viewport, only its header and
      // auxiliary controls keep the page's readable side padding.
      padding: EdgeInsets.symmetric(vertical: compactLayout ? 16 : 24),
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
          widget.header,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sidePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.loading) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: context.isDark
                          ? AppColors.slate800
                          : AppColors.slate100,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary500),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (widget.chapters.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              child: EmptyState(
                icon: Icons.queue_music_rounded,
                title: context.localeText('暂无章节', 'No Chapters'),
                message: context.localeText(
                    '这个分组下还没有章节。', 'This group has no chapters yet.'),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compactLayout ? 8 : 12,
              ),
              child: Column(
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
                          playing: widget.currentChapterId ==
                                  displayChapters[i].id &&
                              widget.isPlaying,
                          themeColor: widget.themeColor,
                          selectionMode: widget.selectionMode,
                          selected: widget.selectedIds
                              .contains(displayChapters[i].id),
                          downloaded:
                              downloadState.hasChapter(displayChapters[i].id),
                          task: downloadState
                              .taskForChapter(displayChapters[i].id),
                          onSelected: () =>
                              widget.onToggleSelected(displayChapters[i]),
                          onPlay: () =>
                              widget.onPlayChapter(displayChapters[i]),
                          onDownload: () =>
                              _downloadChapter(displayChapters[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChapterSectionHeader extends StatefulWidget {
  const _ChapterSectionHeader({
    super.key,
    required this.chapters,
    required this.groupCount,
    required this.activeTotal,
    required this.groupIndex,
    required this.groupDescending,
    required this.activeTab,
    required this.mainCount,
    required this.extraCount,
    required this.showExtraTab,
    required this.admin,
    required this.ascending,
    required this.themeColor,
    required this.selectionMode,
    required this.selectedDownloadable,
    required this.allPageSelected,
    required this.hasSelectable,
    required this.sidePadding,
    required this.sticky,
    required this.onToggleCurrentPage,
    required this.onDownloadSelected,
    required this.onToggleSort,
    required this.onGroupChanged,
    required this.onTabChanged,
    required this.onManage,
    required this.onToggleSelectionMode,
  });

  final List<Chapter> chapters;
  final int groupCount;
  final int activeTotal;
  final int groupIndex;
  final bool groupDescending;
  final String activeTab;
  final int mainCount;
  final int extraCount;
  final bool showExtraTab;
  final bool admin;
  final bool ascending;
  final Color? themeColor;
  final bool selectionMode;
  final int selectedDownloadable;
  final bool allPageSelected;
  final bool hasSelectable;
  final double sidePadding;
  final bool sticky;
  final VoidCallback onToggleCurrentPage;
  final VoidCallback onDownloadSelected;
  final VoidCallback onToggleSort;
  final ValueChanged<int> onGroupChanged;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onManage;
  final VoidCallback onToggleSelectionMode;

  @override
  State<_ChapterSectionHeader> createState() => _ChapterSectionHeaderState();
}

class _ChapterSectionHeaderState extends State<_ChapterSectionHeader> {
  final Map<int, GlobalKey> _groupKeys = {};

  @override
  void initState() {
    super.initState();
    _centerSelectedGroup();
  }

  @override
  void didUpdateWidget(covariant _ChapterSectionHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        widget.sidePadding,
        widget.sticky ? 10 : 0,
        widget.sidePadding,
        widget.sticky ? 10 : 0,
      ),
      decoration: widget.sticky
          ? BoxDecoration(
              color: context.cardColor,
              border: Border(
                bottom: BorderSide(color: context.faintBorder),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDark ? 0.35 : 0.08,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            )
          : null,
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
                onPressed: widget.chapters.isEmpty
                    ? null
                    : widget.onToggleSelectionMode,
                icon: Icon(
                  widget.selectionMode
                      ? Icons.close_rounded
                      : Icons.download_for_offline_outlined,
                  size: actionIconSize,
                ),
                label: Text(
                  widget.selectionMode
                      ? context.l10n.commonCancel
                      : context.localeText('批量下载', 'Batch Download'),
                  style: actionTextStyle,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: widget.selectionMode
                      ? context.secondaryText
                      : AppColors.primary600,
                  backgroundColor: context.isDark
                      ? AppColors.slate800
                      : (widget.selectionMode
                          ? AppColors.slate100
                          : AppColors.primary50),
                  padding: actionPadding,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: widget.selectionMode
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
          if (widget.selectionMode) ...[
            const SizedBox(height: 16),
            _buildSelectionBar(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    return Container(
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
            checked: widget.allPageSelected,
            label: widget.allPageSelected
                ? context.localeText('取消本页', 'Unselect Page')
                : context.localeText('全选本页', 'Select Page'),
            compact: compact,
            onPressed: widget.hasSelectable ? widget.onToggleCurrentPage : null,
          );
          final downloadButton = BatchActionButton(
            icon: Icons.download_rounded,
            label: compact
                ? context.localeText('下载 (${widget.selectedDownloadable})',
                    'Download (${widget.selectedDownloadable})')
                : context.localeText('下载选中 (${widget.selectedDownloadable})',
                    'Download Selected (${widget.selectedDownloadable})'),
            filled: true,
            compact: compact,
            onPressed: widget.selectedDownloadable == 0
                ? null
                : widget.onDownloadSelected,
          );
          if (compact) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [selectButton, downloadButton],
            );
          }
          return Row(
            children: [
              selectButton,
              const Spacer(),
              downloadButton,
            ],
          );
        },
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
