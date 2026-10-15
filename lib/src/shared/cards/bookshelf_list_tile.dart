import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/locale.dart';
import '../common/common_widgets.dart';
import '../common/media_widgets.dart';

String bookCredits(String? author, String? narrator) {
  const unknown = {
    'unknown',
    'unknow',
    'unknown author',
    'unknown narrator',
    'unknown artist',
    '未知',
    '未知作者',
    '未知演播',
    '未知主播',
    '未知演播者',
    '未知演播人',
  };
  return [author, narrator]
      .map((value) => value?.trim() ?? '')
      .where(
          (value) => value.isNotEmpty && !unknown.contains(value.toLowerCase()))
      .join(' · ');
}

String bookPrimaryCredit(String? author, String? narrator) {
  final authorCredit = bookCredits(author, null);
  return authorCredit.isNotEmpty ? authorCredit : bookCredits(null, narrator);
}

class BookshelfListTile extends StatelessWidget {
  const BookshelfListTile({
    super.key,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.coverWidth,
    required this.coverAspectRatio,
    required this.onTap,
    this.narrator,
    this.bookCount,
    this.progress,
    this.selectionMode = false,
    this.selected = false,
  });

  final String title;
  final String? author;
  final String? narrator;
  final String coverUrl;
  final double coverWidth;
  final double coverAspectRatio;
  final int? bookCount;
  final int? progress;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    final bookCount = this.bookCount;
    final credits = bookCredits(author, narrator);
    final progressColor =
        progress == 100 ? const Color(0xff10b981) : context.mutedText;
    return Semantics(
      button: true,
      selected: selectionMode ? selected : null,
      child: Material(
        color: selectionMode && selected
            ? AppColors.primary600.withValues(alpha: 0.08)
            : context.cardColor,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.faintBorder)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: coverWidth,
                  height: coverWidth / coverAspectRatio,
                  child: CoverImage(url: coverUrl, radius: 8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (bookCount != null) ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.layers_rounded,
                                          size: 12,
                                          color: AppColors.primary600),
                                      const SizedBox(width: 4),
                                      Text(context.localeText('系列', 'Series'),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.primary600)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Text(title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35)),
                                if (credits.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    credits,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: context.mutedText, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (bookCount != null) ...[
                            const SizedBox(width: 12),
                            Text(
                                context.localeText(
                                    '$bookCount 本书', '$bookCount books'),
                                style: TextStyle(
                                    color: context.mutedText, fontSize: 12)),
                          ] else if (progress != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              progress == 100
                                  ? context.localeText('已读', 'Read')
                                  : progress == 0
                                      ? context.localeText('未读', 'Unread')
                                      : '$progress%',
                              style:
                                  TextStyle(color: progressColor, fontSize: 12),
                            ),
                          ],
                          if (selectionMode) ...[
                            const SizedBox(width: 12),
                            BatchCheckbox(
                              checked: selected,
                              compact: true,
                              interactive: false,
                              visualSize: 20,
                            ),
                          ] else if (MediaQuery.sizeOf(context).width >=
                              640) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: context.tertiaryText),
                          ],
                        ],
                      ),
                      if (bookCount == null &&
                          progress != null &&
                          progress > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 3,
                            color: progress == 100
                                ? const Color(0xff10b981)
                                : AppColors.primary500,
                            backgroundColor: context.faintBorder,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
