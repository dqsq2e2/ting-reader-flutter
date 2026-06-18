import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'book_card.dart';

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
      shadowColor: Colors.black.withOpacity(0.16),
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
            const _DisplayFilterSection('排序方式'),
            for (final option in sortOptions)
              _DisplayFilterOption(
                label: option.label,
                selected: _sortSelected(option.value),
                onTap: () => onSortChanged(option.value),
              ),
            const _DisplayFilterSection('图标大小', topBorder: true),
            _DisplayFilterOption(
              label: '大图标',
              selected: iconSize == IconSizeSetting.large,
              onTap: () => onIconSizeChanged(IconSizeSetting.large),
            ),
            _DisplayFilterOption(
              label: '中图标（默认）',
              selected: iconSize == IconSizeSetting.medium,
              onTap: () => onIconSizeChanged(IconSizeSetting.medium),
            ),
            _DisplayFilterOption(
              label: '小图标',
              selected: iconSize == IconSizeSetting.small,
              onTap: () => onIconSizeChanged(IconSizeSetting.small),
            ),
            if (coverShape != null && onCoverShapeChanged != null) ...[
              const _DisplayFilterSection('封面形状', topBorder: true),
              _DisplayFilterOption(
                label: '3:4 比例（默认）',
                selected: coverShape == CoverShape.rect,
                onTap: () => onCoverShapeChanged!(CoverShape.rect),
              ),
              _DisplayFilterOption(
                label: '1:1 方形',
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
    if (optionValue == 'createdAt') {
      return sortBy == 'createdAt' || sortBy == 'created_at';
    }
    if (optionValue == 'updatedAt') {
      return sortBy == 'updatedAt' || sortBy == 'updated_at';
    }
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
      color:
          selected ? AppColors.primary50.withOpacity(0.7) : Colors.transparent,
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
