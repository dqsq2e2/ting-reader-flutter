import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';

/// The same main/extra chapter choice is used for browsing and editing.
class ChapterTypeSelector extends StatelessWidget {
  const ChapterTypeSelector({
    super.key,
    required this.activeTab,
    required this.onChanged,
    this.mainCount,
    this.extraCount,
    this.compact = false,
    this.expanded = false,
  });

  final String activeTab;
  final ValueChanged<String> onChanged;
  final int? mainCount;
  final int? extraCount;
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    Widget choice(String tab, String label, int? count) {
      final selected = activeTab == tab;
      final button = TextButton(
        onPressed: () => onChanged(tab),
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : context.secondaryText,
          backgroundColor: selected ? AppColors.primary600 : Colors.transparent,
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 11 : 14, vertical: expanded ? 10 : 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          count == null ? label : '$label ($count)',
          maxLines: 1,
          style: TextStyle(fontSize: compact ? 13 : 14),
        ),
      );
      return expanded ? Expanded(child: button) : button;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          choice('main', context.localeText('正文', 'Main'), mainCount),
          choice('extra', context.localeText('番外', 'Extra'), extraCount),
        ],
      ),
    );
  }
}
