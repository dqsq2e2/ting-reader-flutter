import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';
import '../cards/book_card.dart';

class DisplayFilterSortOption {
  const DisplayFilterSortOption({required this.value, required this.label});

  final String value;
  final String label;
}

class DisplayFilterMenu extends StatefulWidget {
  const DisplayFilterMenu({
    super.key,
    required this.sortBy,
    required this.sortOptions,
    required this.iconSize,
    required this.onSortChanged,
    required this.onIconSizeChanged,
    this.coverShape,
    this.onCoverShapeChanged,
    this.viewMode,
    this.onViewModeChanged,
  });

  final String sortBy;
  final List<DisplayFilterSortOption> sortOptions;
  final IconSizeSetting iconSize;
  final CoverShape? coverShape;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<IconSizeSetting> onIconSizeChanged;
  final ValueChanged<CoverShape>? onCoverShapeChanged;
  final BookshelfViewMode? viewMode;
  final ValueChanged<BookshelfViewMode>? onViewModeChanged;

  @override
  State<DisplayFilterMenu> createState() => _DisplayFilterMenuState();
}

class _DisplayFilterMenuState extends State<DisplayFilterMenu> {
  String? _expandedSection;

  Widget _section(String id, String title, List<Widget> options) {
    final expanded = _expandedSection == id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: expanded,
          child: InkWell(
            onTap: () =>
                setState(() => _expandedSection = expanded ? null : id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: context.secondaryText,
                        fontSize: context.adaptiveFont(15, 14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...options,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 224,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.faintBorder),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.65,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.viewMode != null && widget.onViewModeChanged != null)
                  _section('view', context.localeText('展示模式', 'View Mode'), [
                    _DisplayFilterOption(
                      label: context.localeText('网格（默认）', 'Grid (Default)'),
                      selected: widget.viewMode == BookshelfViewMode.grid,
                      onTap: () =>
                          widget.onViewModeChanged!(BookshelfViewMode.grid),
                    ),
                    _DisplayFilterOption(
                      label: context.localeText('列表', 'List'),
                      selected: widget.viewMode == BookshelfViewMode.list,
                      onTap: () =>
                          widget.onViewModeChanged!(BookshelfViewMode.list),
                    ),
                  ]),
                _section('sort', context.localeText('排序方式', 'Sort'), [
                  for (final option in widget.sortOptions)
                    _DisplayFilterOption(
                      label: option.label,
                      selected: _sortSelected(option.value),
                      onTap: () => widget.onSortChanged(option.value),
                    ),
                ]),
                _section('size', context.localeText('图标大小', 'Icon Size'), [
                  _DisplayFilterOption(
                    label: context.localeText('大图标', 'Large'),
                    selected: widget.iconSize == IconSizeSetting.large,
                    onTap: () =>
                        widget.onIconSizeChanged(IconSizeSetting.large),
                  ),
                  _DisplayFilterOption(
                    label: context.localeText('中图标（默认）', 'Medium (Default)'),
                    selected: widget.iconSize == IconSizeSetting.medium,
                    onTap: () =>
                        widget.onIconSizeChanged(IconSizeSetting.medium),
                  ),
                  _DisplayFilterOption(
                    label: context.localeText('小图标', 'Small'),
                    selected: widget.iconSize == IconSizeSetting.small,
                    onTap: () =>
                        widget.onIconSizeChanged(IconSizeSetting.small),
                  ),
                ]),
                if (widget.coverShape != null &&
                    widget.onCoverShapeChanged != null)
                  _section('shape', context.localeText('封面形状', 'Cover Shape'), [
                    _DisplayFilterOption(
                      label: context.localeText('3:4 比例', '3:4'),
                      selected: widget.coverShape == CoverShape.rect,
                      onTap: () => widget.onCoverShapeChanged!(CoverShape.rect),
                    ),
                    _DisplayFilterOption(
                      label: context.localeText(
                        '1:1 方形（默认）',
                        '1:1 Square (Default)',
                      ),
                      selected: widget.coverShape == CoverShape.square,
                      onTap: () =>
                          widget.onCoverShapeChanged!(CoverShape.square),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _sortSelected(String optionValue) {
    return widget.sortBy == optionValue;
  }
}

class _DisplayFilterOption extends StatelessWidget {
  const _DisplayFilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary50.withValues(alpha: 0.7)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color:
                        selected ? AppColors.primary600 : context.secondaryText,
                    fontSize: context.adaptiveFont(15, 14),
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary600,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
