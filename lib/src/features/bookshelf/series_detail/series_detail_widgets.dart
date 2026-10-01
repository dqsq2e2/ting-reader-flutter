part of 'series_detail_page.dart';

class _SeriesHeader extends StatelessWidget {
  const _SeriesHeader({
    required this.title,
    required this.filterMenuLink,
    required this.showFilterMenu,
    required this.onBack,
    required this.onToggleFilter,
    required this.onSettings,
    required this.onSelect,
    this.selectionToolbar,
  });

  final String title;
  final LayerLink filterMenuLink;
  final bool showFilterMenu;
  final VoidCallback onBack;
  final VoidCallback onToggleFilter;
  final VoidCallback? onSettings;
  final VoidCallback onSelect;
  final Widget? selectionToolbar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < (selectionToolbar != null ? 1000 : 620);
        final left = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBackButton(onPressed: onBack),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
        final actions = selectionToolbar ??
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BatchActionButton(
                  icon: Icons.layers_rounded,
                  label: compact
                      ? context.localeText('选择', 'Select')
                      : context.localeText('选择模式', 'Select Mode'),
                  compact: compact,
                  onPressed: onSelect,
                ),
                CompositedTransformTarget(
                  link: filterMenuLink,
                  child: _HeaderIconButton(
                    icon: Icons.filter_list_rounded,
                    tooltip: context.localeText('筛选', 'Filter'),
                    active: showFilterMenu,
                    onPressed: onToggleFilter,
                  ),
                ),
                if (onSettings != null)
                  _HeaderIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: context.localeText('管理系列', 'Manage Series'),
                    onPressed: onSettings,
                  ),
              ],
            );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            actions,
          ],
        );
      },
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final borderColor = active ? AppColors.primary500 : context.faintBorder;
    final bg = active
        ? AppColors.primary50
        : (context.isDark ? AppColors.slate900 : Colors.white);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: active ? 2 : 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: active ? AppColors.primary600 : context.mutedText,
            ),
          ),
        ),
      ),
    );
  }
}

enum _SeriesBatchOperation { markRead, markUnread, delete }

class _SeriesSelectionToolbar extends StatelessWidget {
  const _SeriesSelectionToolbar({
    required this.selectedCount,
    required this.busy,
    required this.canManage,
    required this.onSelectAll,
    required this.onExit,
    required this.onAction,
  });

  final int selectedCount;
  final bool busy;
  final bool canManage;
  final VoidCallback onSelectAll;
  final VoidCallback onExit;
  final ValueChanged<_SeriesBatchOperation> onAction;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    PopupMenuItem<_SeriesBatchOperation> item(
        _SeriesBatchOperation operation, IconData icon, String label) {
      final color = operation == _SeriesBatchOperation.delete
          ? const Color(0xffef4444)
          : context.secondaryText;
      return PopupMenuItem(
        value: operation,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: color)),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        BatchCountBadge(
          label: context.localeText(
              '已选 $selectedCount', '$selectedCount selected'),
          compact: compact,
        ),
        BatchActionButton(
          icon: Icons.select_all_rounded,
          label: context.localeText('全选', 'Select All'),
          compact: compact,
          onPressed: busy ? null : onSelectAll,
        ),
        PopupMenuButton<_SeriesBatchOperation>(
          enabled: !busy,
          tooltip: context.localeText('批量操作', 'Batch Actions'),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 8),
          onSelected: onAction,
          itemBuilder: (context) => selectedCount == 0
              ? [
                  PopupMenuItem(
                    enabled: false,
                    child: Text(context.localeText(
                        '请先在下方勾选书籍', 'Select books below first')),
                  ),
                ]
              : [
                  item(_SeriesBatchOperation.markRead, Icons.task_alt_rounded,
                      context.localeText('标记已读', 'Mark as read')),
                  item(
                      _SeriesBatchOperation.markUnread,
                      Icons.radio_button_unchecked_rounded,
                      context.localeText('标记未读', 'Mark as unread')),
                  if (canManage) ...[
                    const PopupMenuDivider(),
                    item(
                        _SeriesBatchOperation.delete,
                        Icons.delete_outline_rounded,
                        context.localeText('删除', 'Delete')),
                  ],
                ],
          child: IgnorePointer(
            child: BatchActionButton(
              label: compact
                  ? context.localeText('操作', 'Actions')
                  : context.localeText('批量操作', 'Batch Actions'),
              leading: const Icon(Icons.expand_more_rounded,
                  size: 18, color: Colors.white),
              compact: compact,
              filled: true,
              loading: busy,
              onPressed: () {},
            ),
          ),
        ),
        _HeaderIconButton(
          icon: Icons.close_rounded,
          tooltip: context.l10n.commonCancel,
          onPressed: busy ? null : onExit,
        ),
      ],
    );
  }
}
