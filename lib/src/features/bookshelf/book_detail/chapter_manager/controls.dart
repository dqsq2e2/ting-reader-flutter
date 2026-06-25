part of '../book_detail_page.dart';

class _ChapterManagerSearchField extends StatelessWidget {
  const _ChapterManagerSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).width < 640 ? 42 : 44,
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDark ? AppColors.slate700 : AppColors.slate200,
        ),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, size: 19),
          hintText: hintText,
          hintStyle: TextStyle(
            color: context.mutedText,
            fontSize: MediaQuery.sizeOf(context).width < 640 ? 14 : 15,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _ChapterTypeSwitch extends StatelessWidget {
  const _ChapterTypeSwitch({
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
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate900 : AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.faintBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChapterTypeSwitchItem(
            label: compact ? '正文' : '正文 $mainCount',
            selected: activeTab == 'main',
            compact: compact,
            onTap: () => onChanged('main'),
          ),
          _ChapterTypeSwitchItem(
            label: compact ? '番外' : '番外 $extraCount',
            selected: activeTab == 'extra',
            compact: compact,
            onTap: () => onChanged('extra'),
          ),
        ],
      ),
    );
  }
}

class _ChapterTypeSwitchItem extends StatelessWidget {
  const _ChapterTypeSwitchItem({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : context.secondaryText;
    return Material(
      color: selected ? AppColors.primary600 : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 14,
            vertical: compact ? 6 : 7,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 12 : 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
