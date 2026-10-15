part of 'book_detail_page.dart';

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
    final progressPositionValue = widget.chapter.progressPosition;
    final compact = MediaQuery.sizeOf(context).width < 640;
    final metaColor = context.tertiaryText;
    final progress =
        progressPositionValue != null && widget.chapter.duration > 0
            ? (progressPositionValue / widget.chapter.duration).clamp(0.0, 1.0)
            : 0.0;
    final progressText = progress >= 0.95
        ? context.localeText('已播完', 'Completed')
        : progress > 0
            ? context.localeText('已播${(progress * 100).floor()}%',
                '${(progress * 100).floor()}% played')
            : null;
    final themeColor = widget.themeColor;
    final themedActive = widget.active && themeColor != null && !context.isDark;
    final themeTextColor = themeColor != null && isBookThemeLight(themeColor)
        ? AppColors.slate600
        : Colors.white;
    final bg =
        themedActive ? themeColor.withValues(alpha: 0.1) : context.cardColor;
    final borderColor = widget.active
        ? (themeColor != null && !context.isDark
            ? themeColor.withValues(alpha: 0.3)
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
                BatchCheckbox(
                  checked: widget.selected,
                  compact: compact,
                  enabled: !widget.downloaded && widget.task == null,
                  tooltip: widget.selected
                      ? context.localeText('取消选择', 'Unselect')
                      : context.localeText('选择章节', 'Select chapter'),
                  onChanged: widget.downloaded || widget.task != null
                      ? null
                      : widget.onSelected,
                ),
                SizedBox(width: compact ? 4 : 8),
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
                PlayingBars(
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
        tooltip: context.localeText('已下载', 'Downloaded'),
      );
    }

    final task = this.task;
    if (task != null) {
      final color = task.status.downloadColor;
      final label = task.downloadLabel(context.isEnglishLocale);
      if (compact) {
        return _iconChip(
          context,
          icon: task.status.downloadIcon(),
          color: color,
          tooltip: label,
        );
      }
      return _ChapterDownloadPill(
        icon: task.status.downloadIcon(),
        label: compact && label.length > 3 ? label.substring(0, 3) : label,
        color: color,
      );
    }

    final accent = themeColor ?? AppColors.primary600;
    return _iconChip(
      context,
      icon: Icons.download_rounded,
      color: accent,
      tooltip: context.localeText('下载章节', 'Download chapter'),
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
        color: color.withValues(alpha: context.isDark ? 0.18 : 0.10),
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
