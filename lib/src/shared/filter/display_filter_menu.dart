import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';
import '../cards/book_card.dart';

class DisplayFilterSortOption {
  const DisplayFilterSortOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

class DisplayFilterMenu extends StatelessWidget {
  const DisplayFilterMenu({
    super.key,
    required this.sortBy,
    required this.sortOptions,
    required this.iconSize,
    required this.onSortChanged,
    required this.onIconSizeChanged,
    this.coverShape,
    this.onCoverShapeChanged,
  });

  final String sortBy;
  final List<DisplayFilterSortOption> sortOptions;
  final IconSizeSetting iconSize;
  final CoverShape? coverShape;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<IconSizeSetting> onIconSizeChanged;
  final ValueChanged<CoverShape>? onCoverShapeChanged;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DisplayFilterSection(context.localeText('排序方式', 'Sort')),
            for (final option in sortOptions)
              _DisplayFilterOption(
                label: option.label,
                selected: _sortSelected(option.value),
                onTap: () => onSortChanged(option.value),
              ),
            _DisplayFilterSection(context.localeText('图标大小', 'Icon Size'),
                topBorder: true),
            _DisplayFilterOption(
              label: context.localeText('大图标', 'Large'),
              selected: iconSize == IconSizeSetting.large,
              onTap: () => onIconSizeChanged(IconSizeSetting.large),
            ),
            _DisplayFilterOption(
              label: context.localeText('中图标（默认）', 'Medium (Default)'),
              selected: iconSize == IconSizeSetting.medium,
              onTap: () => onIconSizeChanged(IconSizeSetting.medium),
            ),
            _DisplayFilterOption(
              label: context.localeText('小图标', 'Small'),
              selected: iconSize == IconSizeSetting.small,
              onTap: () => onIconSizeChanged(IconSizeSetting.small),
            ),
            if (coverShape != null && onCoverShapeChanged != null) ...[
              _DisplayFilterSection(context.localeText('封面形状', 'Cover Shape'),
                  topBorder: true),
              _DisplayFilterOption(
                label: context.localeText('3:4 比例（默认）', '3:4 (Default)'),
                selected: coverShape == CoverShape.rect,
                onTap: () => onCoverShapeChanged!(CoverShape.rect),
              ),
              _DisplayFilterOption(
                label: context.localeText('1:1 方形', '1:1 Square'),
                selected: coverShape == CoverShape.square,
                onTap: () => onCoverShapeChanged!(CoverShape.square),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _sortSelected(String optionValue) {
    return sortBy == optionValue;
  }
}

class _DisplayFilterSection extends StatelessWidget {
  const _DisplayFilterSection(this.label, {this.topBorder = false});

  final String label;
  final bool topBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, topBorder ? 12 : 8, 16, 8),
      decoration: BoxDecoration(
        border: topBorder
            ? Border(top: BorderSide(color: context.faintBorder))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.tertiaryText,
          fontSize: context.adaptiveFont(13, 12),
        ),
      ),
    );
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
