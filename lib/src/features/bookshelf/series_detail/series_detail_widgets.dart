part of 'series_detail_page.dart';

class _SeriesHeader extends StatelessWidget {
  const _SeriesHeader({
    required this.title,
    required this.filterMenuLink,
    required this.showFilterMenu,
    required this.onBack,
    required this.onToggleFilter,
    required this.onSettings,
  });

  final String title;
  final LayerLink filterMenuLink;
  final bool showFilterMenu;
  final VoidCallback onBack;
  final VoidCallback onToggleFilter;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
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
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CompositedTransformTarget(
              link: filterMenuLink,
              child: _HeaderIconButton(
                icon: Icons.filter_list_rounded,
                tooltip: '筛选',
                active: showFilterMenu,
                onPressed: onToggleFilter,
              ),
            ),
            const SizedBox(width: 10),
            _HeaderIconButton(
              icon: Icons.settings_outlined,
              tooltip: '管理系列',
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
  final VoidCallback onPressed;
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
