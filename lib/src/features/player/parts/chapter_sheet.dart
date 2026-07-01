part of '../mini_player.dart';

class _ChapterPageGroup {
  const _ChapterPageGroup({
    required this.start,
    required this.end,
    required this.chapters,
  });

  final int start;
  final int end;
  final List<Chapter> chapters;
}

class _ChapterSheetList extends StatefulWidget {
  const _ChapterSheetList({
    required this.player,
    required this.themeColor,
  });

  final PlayerState player;
  final Color? themeColor;

  @override
  State<_ChapterSheetList> createState() => _ChapterSheetListState();
}

class _ChapterSheetListState extends State<_ChapterSheetList> {
  static const _chaptersPerGroup = 100;

  late bool _showExtra;
  int _groupIndex = 0;
  bool _ascending = true;
  final Map<String, GlobalKey> _chapterKeys = {};
  final Map<int, GlobalKey> _groupKeys = {};

  @override
  void initState() {
    super.initState();
    _showExtra = _chapterLooksExtra(widget.player.currentChapter);
    _groupIndex = _initialGroupIndex();
    _ensureCurrentVisible();
  }

  void _ensureCurrentVisible({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final groupContext = _groupKeys[_groupIndex]?.currentContext;
      if (groupContext != null) {
        Scrollable.ensureVisible(
          groupContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }

      final currentId = widget.player.currentChapter?.id;
      final chapterContext =
          currentId == null ? null : _chapterKeys[currentId]?.currentContext;
      if (chapterContext != null) {
        Scrollable.ensureVisible(
          chapterContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (attempt < 3) {
        _ensureCurrentVisible(attempt: attempt + 1);
      }
    });
  }

  int _initialGroupIndex() {
    final chapters = _chaptersForTab(_showExtra);
    final current = widget.player.currentChapter;
    if (current == null) return 0;
    final index = chapters.indexWhere((chapter) => chapter.id == current.id);
    if (index < 0) return 0;
    return index ~/ _chaptersPerGroup;
  }

  bool _chapterLooksExtra(Chapter? chapter) {
    if (chapter == null) return false;
    return chapter.isExtra ||
        RegExp(r'番外|SP|Extra', caseSensitive: false).hasMatch(chapter.title);
  }

  List<Chapter> _chaptersForTab(bool extra) {
    final chapters = widget.player.chapters
        .where((chapter) => _chapterLooksExtra(chapter) == extra)
        .toList(growable: false);
    return chapters;
  }

  List<_ChapterPageGroup> _groupsFor(List<Chapter> chapters) {
    final groups = <_ChapterPageGroup>[];
    for (var i = 0; i < chapters.length; i += _chaptersPerGroup) {
      final end = (i + _chaptersPerGroup).clamp(0, chapters.length);
      final slice = chapters.sublist(i, end);
      groups.add(_ChapterPageGroup(
        start: i + 1,
        end: end,
        chapters: slice,
      ));
    }
    return groups;
  }

  List<Chapter> _visibleGroupChapters(_ChapterPageGroup group) {
    return _ascending ? group.chapters : group.chapters.reversed.toList();
  }

  _ChapterProgressLabel? _progressText(BuildContext context, Chapter chapter) {
    final position = chapter.progressPosition;
    if (position == null || chapter.duration <= 0) return null;
    final percent = ((position / chapter.duration) * 100).floor();
    if (percent <= 0) return null;
    if (percent >= 95) {
      return _ChapterProgressLabel(
        text: context.localeText('已播完', 'Done'),
        completed: true,
      );
    }
    return _ChapterProgressLabel(
      text: context.localeText('已播$percent%', 'Played $percent%'),
      completed: false,
    );
  }

  Future<void> _downloadChapter(Chapter chapter) async {
    final book = widget.player.currentBook;
    if (book == null) return;
    final downloadState = AppScope.downloadOf(context);
    if (downloadState.hasChapter(chapter.id)) return;
    final task = downloadState.taskForChapter(chapter.id);
    if (task != null) {
      if (task.status == DownloadStatus.paused ||
          task.status == DownloadStatus.failed) {
        await downloadState.resumeTask(chapter.id);
      }
      return;
    }
    downloadState.queueChapter(book, chapter);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.player,
      builder: (context, _) {
        final book = widget.player.currentBook;
        if (book == null || widget.player.chapters.isEmpty) {
          return const SizedBox.shrink();
        }

        final mainChapters = _chaptersForTab(false);
        final extraChapters = _chaptersForTab(true);
        final downloadState = AppScope.downloadOf(context);
        final activeExtra = _showExtra && extraChapters.isNotEmpty;
        final currentChapters = activeExtra ? extraChapters : mainChapters;
        final groups = _groupsFor(currentChapters);
        var groupIndex = _groupIndex;
        if (groupIndex < 0) groupIndex = 0;
        if (groups.isNotEmpty && groupIndex >= groups.length) {
          groupIndex = groups.length - 1;
        }
        final activeGroup = groups.isEmpty ? null : groups[groupIndex];
        final activeChapters = activeGroup == null
            ? const <Chapter>[]
            : _visibleGroupChapters(activeGroup);
        final accent = widget.themeColor ?? AppColors.primary600;
        final onAccent =
            widget.themeColor != null && _isPlayerThemeLight(widget.themeColor!)
                ? AppColors.slate600
                : Colors.white;
        final height = MediaQuery.sizeOf(context).height * 0.8;

        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 672),
              child: SizedBox(
                height: height.clamp(460, 720),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border.all(color: context.faintBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: context.isDark ? 0.5 : 0.18),
                        blurRadius: 34,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 18, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.queue_music_rounded,
                                    color: AppColors.primary600,
                                    size: 25,
                                  ),
                                  const SizedBox(width: 9),
                                  Text(
                                    context.localeText('章节列表', 'Chapters'),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (extraChapters.isNotEmpty) ...[
                                    const SizedBox(width: 14),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: context.isDark
                                            ? AppColors.slate800
                                            : AppColors.slate100,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          _ChapterTabButton(
                                            label: context.localeText(
                                              '正文 (${mainChapters.length})',
                                              'Main (${mainChapters.length})',
                                            ),
                                            selected: !activeExtra,
                                            accent: accent,
                                            onAccent: onAccent,
                                            onTap: () => setState(() {
                                              _showExtra = false;
                                              _groupIndex = 0;
                                              _ensureCurrentVisible();
                                            }),
                                          ),
                                          _ChapterTabButton(
                                            label: context.localeText(
                                              '番外 (${extraChapters.length})',
                                              'Extra (${extraChapters.length})',
                                            ),
                                            selected: activeExtra,
                                            accent: accent,
                                            onAccent: onAccent,
                                            onTap: () => setState(() {
                                              _showExtra = true;
                                              _groupIndex = 0;
                                              _ensureCurrentVisible();
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 10),
                                  _ChapterSortButton(
                                    ascending: _ascending,
                                    onTap: () => setState(() {
                                      _ascending = !_ascending;
                                      _ensureCurrentVisible();
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon:
                                  const Icon(Icons.keyboard_arrow_down_rounded),
                              tooltip: context.localeText('关闭', 'Close'),
                            ),
                          ],
                        ),
                      ),
                      if (groups.length > 1)
                        Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: context.isDark
                                ? AppColors.slate800.withValues(alpha: 0.5)
                                : AppColors.slate50,
                            border: Border.symmetric(
                              horizontal:
                                  BorderSide(color: context.faintBorder),
                            ),
                          ),
                          child: HorizontalScrollControls(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                for (var index = 0;
                                    index < groups.length;
                                    index++) ...[
                                  Builder(
                                    builder: (context) {
                                      final group = groups[index];
                                      final selected = groupIndex == index;
                                      return ChoiceChip(
                                        key: _groupKeys.putIfAbsent(
                                          index,
                                          () => GlobalKey(),
                                        ),
                                        selected: selected,
                                        showCheckmark: false,
                                        label: Text(
                                          context.localeText(
                                            '第 ${group.start}-${group.end} 章',
                                            'Ch. ${group.start}-${group.end}',
                                          ),
                                        ),
                                        labelStyle: TextStyle(
                                          color: selected
                                              ? onAccent
                                              : context.mutedText,
                                        ),
                                        selectedColor: accent,
                                        backgroundColor: context.cardColor,
                                        side: BorderSide(
                                          color: selected
                                              ? accent
                                              : context.faintBorder,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        onSelected: (_) {
                                          setState(() {
                                            _groupIndex = index;
                                            _ensureCurrentVisible();
                                          });
                                        },
                                      );
                                    },
                                  ),
                                  if (index != groups.length - 1)
                                    const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: activeGroup == null
                            ? Center(
                                child: Text(
                                  activeExtra
                                      ? context.localeText(
                                          '暂无番外章节',
                                          'No extra chapters',
                                        )
                                      : context.localeText(
                                          '暂无正文章节',
                                          'No main chapters',
                                        ),
                                  style: TextStyle(color: context.mutedText),
                                ),
                              )
                            : SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 14, 14, 18),
                                child: Column(
                                  children: [
                                    for (var index = 0;
                                        index < activeChapters.length;
                                        index++) ...[
                                      Builder(
                                        builder: (context) {
                                          final chapter = activeChapters[index];
                                          final originalIndex = activeGroup
                                              .chapters
                                              .indexOf(chapter);
                                          final actualIndex =
                                              groupIndex * _chaptersPerGroup +
                                                  (originalIndex < 0
                                                      ? index
                                                      : originalIndex);
                                          return KeyedSubtree(
                                            key: _chapterKeys.putIfAbsent(
                                              chapter.id,
                                              () => GlobalKey(),
                                            ),
                                            child: _ChapterSheetTile(
                                              chapter: chapter,
                                              fallbackIndex: actualIndex + 1,
                                              active: chapter.id ==
                                                  widget.player.currentChapter
                                                      ?.id,
                                              isPlaying:
                                                  widget.player.isPlaying,
                                              progressText: _progressText(
                                                  context, chapter),
                                              downloaded: downloadState
                                                  .hasChapter(chapter.id),
                                              task: downloadState
                                                  .taskForChapter(chapter.id),
                                              accent: accent,
                                              onAccent: onAccent,
                                              onTap: () async {
                                                await widget.player.playChapter(
                                                  book,
                                                  widget.player.chapters,
                                                  chapter,
                                                );
                                                if (context.mounted) {
                                                  Navigator.pop(context);
                                                }
                                              },
                                              onDownload: () =>
                                                  _downloadChapter(
                                                chapter,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (index != activeChapters.length - 1)
                                        const SizedBox(height: 8),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChapterTabButton extends StatelessWidget {
  const _ChapterTabButton({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onAccent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color onAccent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? context.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : context.mutedText,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ChapterProgressLabel {
  const _ChapterProgressLabel({
    required this.text,
    required this.completed,
  });

  final String text;
  final bool completed;
}

class _ChapterSortButton extends StatelessWidget {
  const _ChapterSortButton({
    required this.ascending,
    required this.onTap,
  });

  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: context.secondaryText,
        backgroundColor:
            context.isDark ? AppColors.slate800 : AppColors.slate100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(
        ascending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
        size: 17,
      ),
      label: Text(
        ascending
            ? context.localeText('正序', 'Ascending')
            : context.localeText('逆序', 'Descending'),
      ),
    );
  }
}

class _ChapterSheetTile extends StatelessWidget {
  const _ChapterSheetTile({
    required this.chapter,
    required this.fallbackIndex,
    required this.active,
    required this.isPlaying,
    required this.progressText,
    required this.downloaded,
    required this.task,
    required this.accent,
    required this.onAccent,
    required this.onTap,
    required this.onDownload,
  });

  final Chapter chapter;
  final int fallbackIndex;
  final bool active;
  final bool isPlaying;
  final _ChapterProgressLabel? progressText;
  final bool downloaded;
  final DownloadTask? task;
  final Color accent;
  final Color onAccent;
  final Future<void> Function() onTap;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Material(
      color: active
          ? accent.withValues(alpha: context.isDark ? 0.16 : 0.1)
          : context.cardColor,
      borderRadius: BorderRadius.circular(compact ? 10 : 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 10 : 16),
        child: Container(
          padding: EdgeInsets.all(compact ? 8 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 10 : 16),
            border: Border.all(
              color:
                  active ? accent.withValues(alpha: 0.3) : context.faintBorder,
            ),
          ),
          child: Row(
            children: [
              if (!compact) ...[
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? accent
                        : (context.isDark
                            ? AppColors.slate800
                            : AppColors.slate100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${chapter.chapterIndex == 0 ? fallbackIndex : chapter.chapterIndex}',
                    style: TextStyle(
                      color: active ? onAccent : context.mutedText,
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
                      localizedChapterTitle(context, chapter),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? accent : null,
                        fontSize: compact ? 14 : 16,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: context.mutedText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatDurationShort(chapter.duration),
                              style: TextStyle(
                                color: context.mutedText,
                                fontSize: 12,
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
                              color: progressText!.completed
                                  ? const Color(0xffdcfce7)
                                  : AppColors.primary50,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              progressText!.text,
                              style: TextStyle(
                                color: progressText!.completed
                                    ? const Color(0xff22c55e)
                                    : AppColors.primary600,
                                fontSize: compact ? 10 : 11,
                              ),
                            ),
                          ),
                        _ChapterSheetDownloadMark(
                          compact: compact,
                          downloaded: downloaded,
                          task: task,
                          accent: accent,
                          onDownload: onDownload,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (active && isPlaying) ...[
                SizedBox(width: compact ? 6 : 10),
                _PlayingBars(color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterSheetDownloadMark extends StatelessWidget {
  const _ChapterSheetDownloadMark({
    required this.compact,
    required this.downloaded,
    required this.task,
    required this.accent,
    required this.onDownload,
  });

  final bool compact;
  final bool downloaded;
  final DownloadTask? task;
  final Color accent;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    if (downloaded) {
      return _iconMark(
        icon: Icons.check_rounded,
        color: AppColors.primary600,
        tooltip: context.localeText('已下载', 'Downloaded'),
      );
    }

    final task = this.task;
    if (task == null) {
      return _iconMark(
        icon: Icons.download_rounded,
        color: accent,
        tooltip: context.localeText('下载章节', 'Download chapter'),
        onTap: onDownload,
      );
    }
    final color = switch (task.status) {
      DownloadStatus.downloading => AppColors.primary600,
      DownloadStatus.paused => Colors.orange,
      DownloadStatus.failed => Colors.red,
      DownloadStatus.completed => AppColors.primary600,
      DownloadStatus.queued => AppColors.slate500,
    };
    final icon = switch (task.status) {
      DownloadStatus.downloading => Icons.downloading_rounded,
      DownloadStatus.paused => Icons.pause_rounded,
      DownloadStatus.failed => Icons.error_outline_rounded,
      DownloadStatus.completed => Icons.check_rounded,
      DownloadStatus.queued => Icons.schedule_rounded,
    };
    final label = task.status == DownloadStatus.downloading
        ? '${(task.progress.clamp(0, 1) * 100).round()}%'
        : task.status.labelForLocale(context.isEnglishLocale);

    return _iconMark(
      icon: icon,
      color: color,
      tooltip: label,
    );
  }

  Widget _iconMark({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    final size = compact ? 20.0 : 22.0;
    final child = SizedBox(
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
          ? child
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: child,
            ),
    );
  }
}

class _PlayingBars extends StatefulWidget {
  const _PlayingBars({required this.color});

  final Color color;

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _height(double offset) {
    final phase = (_controller.value + offset) % 1;
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 7 + wave * 13;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 19,
          height: 22,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final offset in const [0.0, 0.22, 0.44])
                Container(
                  width: 4,
                  height: _height(offset),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
