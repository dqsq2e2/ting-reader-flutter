part of 'book_detail_page.dart';

class _ChapterSection extends StatefulWidget {
  const _ChapterSection({
    required this.book,
    required this.chapters,
    required this.groupCount,
    required this.activeTotal,
    required this.groupIndex,
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
      final context = _groupKeys[widget.groupIndex]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<Chapter> _downloadableChapters(DownloadState downloadState) {
    return widget.chapters
        .where((chapter) =>
            !downloadState.hasChapter(chapter.id) &&
            downloadState.taskForChapter(chapter.id) == null)
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
    final downloadState = AppScope.downloadOf(context);
    if (downloadState.hasChapter(chapter.id)) {
      _showDownloadMessage('章节已下载');
      return;
    }
    final task = downloadState.taskForChapter(chapter.id);
    if (task != null) {
      if (task.status == DownloadStatus.paused ||
          task.status == DownloadStatus.failed) {
        await downloadState.resumeTask(chapter.id);
        _showDownloadMessage('已恢复下载：${chapter.title}');
      } else {
        _showDownloadMessage('下载任务已存在：${task.status.label}');
      }
      return;
    }
    try {
      downloadState.queueChapter(widget.book, chapter);
      _showDownloadMessage('已加入下载队列：${chapter.title}');
    } catch (err) {
      _showDownloadMessage('加入下载失败：$err');
    }
  }

  Future<void> _downloadSelected() async {
    final downloadState = AppScope.downloadOf(context);
    final targets = widget.chapters
        .where((chapter) =>
            _selectedIds.contains(chapter.id) &&
            !downloadState.hasChapter(chapter.id) &&
            downloadState.taskForChapter(chapter.id) == null)
        .toList()
      ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    if (targets.isEmpty) {
      _showDownloadMessage('没有可加入队列的章节');
      return;
    }
    var queued = 0;
    for (final chapter in targets) {
      try {
        downloadState.queueChapter(widget.book, chapter);
        queued++;
      } catch (err) {
        _showDownloadMessage('加入下载失败：$err');
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    if (queued > 0) _showDownloadMessage('已加入 $queued 个章节到下载队列');
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
            !downloadState.hasChapter(chapter.id) &&
            downloadState.taskForChapter(chapter.id) == null)
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
            color: Colors.black.withOpacity(context.isDark ? 0.12 : 0.035),
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
                fontWeight: FontWeight.w600,
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
                    '章节列表',
                    style: TextStyle(
                      fontSize: headerFontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
              final tabs = _ChapterTabs(
                activeTab: widget.activeTab,
                mainCount: widget.mainCount,
                extraCount: widget.extraCount,
                compact: compact,
                onChanged: widget.onTabChanged,
              );
              final manageButton = IconButton(
                tooltip: '管理章节',
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
                  _selectionMode ? '取消' : '批量下载',
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
                  widget.ascending ? '正序' : '逆序',
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < widget.groupCount; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: KeyedSubtree(
                        key: _groupKeys.putIfAbsent(i, () => GlobalKey()),
                        child: _ChapterGroupButton(
                          label: _chapterGroupLabel(i, widget.activeTotal),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.isDark ? AppColors.slate800 : AppColors.slate50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.faintBorder),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 420;
                  final buttonPadding = EdgeInsets.symmetric(
                    horizontal: compact ? 7 : 10,
                    vertical: compact ? 5 : 7,
                  );
                  final selectButton = TextButton.icon(
                    onPressed: downloadable.isEmpty
                        ? null
                        : () => _toggleCurrentPage(downloadState),
                    icon: Icon(
                      allPageSelected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: compact ? 16 : 18,
                    ),
                    label: Text(
                      allPageSelected ? '取消本页' : '全选本页',
                      style: TextStyle(fontSize: compact ? 13 : 14),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: buttonPadding,
                      foregroundColor: AppColors.primary600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  final downloadButton = TextButton.icon(
                    onPressed:
                        selectedDownloadable == 0 ? null : _downloadSelected,
                    icon: Icon(Icons.download_rounded, size: compact ? 16 : 18),
                    label: Text(
                      compact ? '下载' : '下载选中',
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: buttonPadding,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: context.mutedText,
                      backgroundColor: AppColors.primary600,
                      disabledBackgroundColor: context.isDark
                          ? AppColors.slate700
                          : AppColors.slate100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  );
                  return Row(
                    children: [
                      selectButton,
                      const Spacer(),
                      Text(
                        '已选 $selectedDownloadable',
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: compact ? 13 : 14,
                        ),
                      ),
                      SizedBox(width: compact ? 6 : 12),
                      downloadButton,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.chapters.isEmpty)
            const EmptyState(
              icon: Icons.queue_music_rounded,
              title: '暂无章节',
              message: '这个分组下还没有章节。',
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

String _chapterGroupLabel(int groupIndex, int total) {
  if (total <= 0) return '章节';
  final start = groupIndex * _BookDetailPageState._chaptersPerGroup + 1;
  final end = math.min(
    start + _BookDetailPageState._chaptersPerGroup - 1,
    total,
  );
  return '第 $start-$end 章';
}

class _ChapterTabs extends StatelessWidget {
  const _ChapterTabs({
    required this.activeTab,
    required this.mainCount,
    required this.extraCount,
    required this.compact,
    required this.onChanged,
  });

  final String activeTab;
  final int mainCount;
  final int extraCount;
  final bool compact;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChapterTabButton(
            label: '正文 ($mainCount)',
            selected: activeTab == 'main',
            compact: compact,
            onPressed: () => onChanged('main'),
          ),
          _ChapterTabButton(
            label: '番外 ($extraCount)',
            selected: activeTab == 'extra',
            compact: compact,
            onPressed: () => onChanged('extra'),
          ),
        ],
      ),
    );
  }
}

class _ChapterTabButton extends StatelessWidget {
  const _ChapterTabButton({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected ? context.cardColor : Colors.transparent,
        foregroundColor: selected ? AppColors.primary600 : context.mutedText,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 16,
          vertical: compact ? 6 : 8,
        ),
        minimumSize: Size(0, compact ? 30 : 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: compact ? 13 : 14),
      ),
    );
  }
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
    final selectedBackground = themeColor ?? AppColors.primary600;
    final selectedForeground = themeColor != null && _isThemeLight(themeColor!)
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

class _ChapterListRow extends StatefulWidget {
  const _ChapterListRow({
    required this.chapter,
    required this.active,
    required this.playing,
    required this.themeColor,
    required this.selectionMode,
    required this.selected,
    required this.downloaded,
    required this.onSelected,
    required this.onPlay,
    required this.onDownload,
    this.task,
  });

  final Chapter chapter;
  final bool active;
  final bool playing;
  final Color? themeColor;
  final bool selectionMode;
  final bool selected;
  final bool downloaded;
  final DownloadTask? task;
  final VoidCallback onSelected;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  @override
  State<_ChapterListRow> createState() => _ChapterListRowState();
}

class _ChapterListRowState extends State<_ChapterListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final metaColor = context.tertiaryText;
    final progress =
        widget.chapter.progressPosition != null && widget.chapter.duration > 0
            ? (widget.chapter.progressPosition! / widget.chapter.duration)
                .clamp(0.0, 1.0)
            : 0.0;
    final progressText = progress >= 0.95
        ? '已播完'
        : progress > 0
            ? '已播${(progress * 100).floor()}%'
            : null;
    final themeColor = widget.themeColor;
    final themedActive = widget.active && themeColor != null && !context.isDark;
    final themeTextColor = themeColor != null && _isThemeLight(themeColor)
        ? AppColors.slate600
        : Colors.white;
    final bg = themedActive ? themeColor.withOpacity(0.1) : context.cardColor;
    final borderColor = widget.active
        ? (themeColor != null && !context.isDark
            ? themeColor.withOpacity(0.3)
            : (context.isDark ? AppColors.slate600 : AppColors.slate900))
        : (_hovered ? AppColors.primary100 : context.faintBorder);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.selectionMode ? widget.onSelected : widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.all(compact ? 8 : 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(compact ? 10 : 16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              if (widget.selectionMode) ...[
                SizedBox(
                  width: compact ? 30 : 34,
                  child: Checkbox(
                    value: widget.selected,
                    onChanged: widget.downloaded || widget.task != null
                        ? null
                        : (_) => widget.onSelected(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                SizedBox(width: compact ? 6 : 10),
              ],
              if (!compact) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.active
                        ? (themeColor ?? AppColors.primary600)
                        : (context.isDark
                            ? AppColors.slate800
                            : AppColors.slate100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.chapter.chapterIndex}',
                    style: TextStyle(
                      color: widget.active ? themeTextColor : context.mutedText,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chapter.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.active
                            ? (themeColor != null && !context.isDark
                                ? themeColor
                                : (context.isDark
                                    ? AppColors.slate50
                                    : AppColors.slate900))
                            : (context.isDark
                                ? Colors.white
                                : AppColors.slate900),
                        fontSize: compact ? 15 : 16,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: metaColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatDurationShort(widget.chapter.duration),
                              style: TextStyle(
                                color: metaColor,
                                fontSize: compact ? 12.5 : 12,
                              ),
                            ),
                          ],
                        ),
                        if (progressText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: progress >= 0.95
                                  ? const Color(0xffdcfce7)
                                  : AppColors.primary50,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              progressText,
                              style: TextStyle(
                                color: progress >= 0.95
                                    ? const Color(0xff22c55e)
                                    : AppColors.primary600,
                                fontSize: compact ? 11 : 10,
                              ),
                            ),
                          ),
                        if (!widget.selectionMode)
                          _ChapterDownloadAction(
                            compact: compact,
                            downloaded: widget.downloaded,
                            task: widget.task,
                            themeColor: themeColor,
                            onDownload: widget.onDownload,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.playing || !compact) SizedBox(width: compact ? 8 : 16),
              if (widget.playing) ...[
                _PlayingBars(
                  color: themeColor ?? AppColors.primary600,
                  compact: compact,
                ),
                SizedBox(width: compact ? 6 : 10),
              ] else if (!widget.selectionMode && !compact) ...[
                AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: IgnorePointer(
                    ignoring: !_hovered,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? AppColors.slate800
                            : AppColors.slate50,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: themeColor ?? AppColors.primary600,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayingBars extends StatefulWidget {
  const _PlayingBars({
    required this.color,
    required this.compact,
  });

  final Color color;
  final bool compact;

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = widget.compact ? 16.0 : 20.0;
    final minHeight = widget.compact ? 5.0 : 6.0;
    return SizedBox(
      width: widget.compact ? 18 : 22,
      height: maxHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++) ...[
                _PlayingBar(
                  color: widget.color,
                  width: widget.compact ? 3 : 4,
                  height: minHeight +
                      (maxHeight - minHeight) *
                          (0.25 +
                              0.75 *
                                  math
                                      .sin(
                                        _controller.value * math.pi * 2 +
                                            i * math.pi / 2,
                                      )
                                      .abs()),
                ),
                if (i != 2) SizedBox(width: widget.compact ? 2 : 3),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlayingBar extends StatelessWidget {
  const _PlayingBar({
    required this.color,
    required this.width,
    required this.height,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _ChapterDownloadAction extends StatelessWidget {
  const _ChapterDownloadAction({
    required this.compact,
    required this.downloaded,
    required this.themeColor,
    required this.onDownload,
    this.task,
  });

  final bool compact;
  final bool downloaded;
  final DownloadTask? task;
  final Color? themeColor;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    if (downloaded) {
      return _iconChip(
        context,
        icon: Icons.check_rounded,
        color: AppColors.primary600,
        tooltip: '已下载',
      );
    }

    final task = this.task;
    if (task != null) {
      final color = switch (task.status) {
        DownloadStatus.downloading => AppColors.primary600,
        DownloadStatus.paused => Colors.orange,
        DownloadStatus.failed => Colors.red,
        DownloadStatus.completed => AppColors.primary600,
        DownloadStatus.queued => AppColors.slate500,
      };
      final label = task.status == DownloadStatus.downloading
          ? '${(task.progress * 100).clamp(0, 100).round()}%'
          : task.status.label;
      if (compact) {
        return _iconChip(
          context,
          icon: switch (task.status) {
            DownloadStatus.downloading => Icons.downloading_rounded,
            DownloadStatus.paused => Icons.pause_circle_outline_rounded,
            DownloadStatus.failed => Icons.error_outline_rounded,
            DownloadStatus.completed => Icons.download_done_rounded,
            DownloadStatus.queued => Icons.schedule_rounded,
          },
          color: color,
          tooltip: label,
        );
      }
      return _ChapterDownloadPill(
        icon: switch (task.status) {
          DownloadStatus.downloading => Icons.downloading_rounded,
          DownloadStatus.paused => Icons.pause_circle_outline_rounded,
          DownloadStatus.failed => Icons.error_outline_rounded,
          DownloadStatus.completed => Icons.download_done_rounded,
          DownloadStatus.queued => Icons.schedule_rounded,
        },
        label: compact && label.length > 3 ? label.substring(0, 3) : label,
        color: color,
      );
    }

    final accent = themeColor ?? AppColors.primary600;
    return _iconChip(
      context,
      icon: Icons.download_rounded,
      color: accent,
      tooltip: '下载章节',
      onTap: onDownload,
    );
  }

  Widget _iconChip(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    final size = compact ? 20.0 : 22.0;
    final chip = SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          icon,
          size: compact ? 15 : 16,
          color: color,
        ),
      ),
    );
    return Tooltip(
      message: tooltip,
      child: onTap == null
          ? chip
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: chip,
            ),
    );
  }
}

class _ChapterDownloadPill extends StatelessWidget {
  const _ChapterDownloadPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(context.isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
