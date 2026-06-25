part of '../book_detail_page.dart';

class _ChapterGroups extends StatelessWidget {
  const _ChapterGroups({
    required this.total,
    required this.groupSize,
    required this.groupIndex,
    required this.onGroupChanged,
  });

  final int total;
  final int groupSize;
  final int groupIndex;
  final ValueChanged<int> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    final groupCount = (total / groupSize).ceil();
    if (groupCount <= 1) return const SizedBox.shrink();

    return HorizontalScrollControls(
      child: Row(
        children: [
          for (var i = 0; i < groupCount; i++) ...[
            _ChapterRangeChip(
              label: _labelFor(i),
              selected: i == groupIndex,
              onTap: () => onGroupChanged(i),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _labelFor(int index) {
    final start = index * groupSize + 1;
    final end = math.min((index + 1) * groupSize, total);
    if (total == 0) return '0';
    return '第 $start-$end 章';
  }
}

class _ChapterRangeChip extends StatelessWidget {
  const _ChapterRangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final foreground = selected ? Colors.white : context.secondaryText;
    return Material(
      color: selected
          ? AppColors.primary600
          : (context.isDark ? AppColors.slate800 : context.cardColor),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 13,
            vertical: compact ? 8 : 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? AppColors.primary600 : context.faintBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 12 : 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerChapterRow extends StatelessWidget {
  const _ManagerChapterRow({
    required this.chapter,
    required this.selected,
    required this.changed,
    required this.selectionMode,
    required this.onSelected,
    required this.onEdit,
  });

  final Chapter chapter;
  final bool selected;
  final bool changed;
  final bool selectionMode;
  final VoidCallback onSelected;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final background = selected
        ? AppColors.primary50
        : changed
            ? const Color(0xfffffbeb)
            : (context.isDark
                ? AppColors.slate900.withValues(alpha: 0.6)
                : Colors.white);
    final borderColor = selected
        ? AppColors.primary300
        : changed
            ? const Color(0xfffde68a)
            : context.faintBorder.withValues(alpha: 0.62);
    return Material(
      color: context.isDark ? context.cardColor : background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: selectionMode ? onSelected : onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 12,
            compact ? 9 : 10,
            compact ? 8 : 10,
            compact ? 9 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.isDark ? context.faintBorder : borderColor,
            ),
          ),
          child: Row(
            children: [
              if (selectionMode) ...[
                BatchCheckbox(
                  checked: selected,
                  compact: compact,
                  onChanged: onSelected,
                ),
                const SizedBox(width: 6),
              ],
              Container(
                constraints: BoxConstraints(minWidth: compact ? 34 : 40),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 9,
                  vertical: compact ? 7 : 8,
                ),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? AppColors.slate800
                      : AppColors.primary50.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${chapter.chapterIndex}',
                  style: TextStyle(
                    color: AppColors.primary600,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w400,
                          height: 1.22,
                        ),
                      ),
                    ),
                    if (changed) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffecfeff),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '已修改',
                          style: TextStyle(
                            color: AppColors.primary600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!selectionMode) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: '编辑章节',
                  child: Material(
                    color: context.isDark
                        ? AppColors.slate800
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox.square(
                        dimension: compact ? 32 : 34,
                        child: Icon(
                          Icons.edit_rounded,
                          size: compact ? 16 : 17,
                          color: context.secondaryText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
