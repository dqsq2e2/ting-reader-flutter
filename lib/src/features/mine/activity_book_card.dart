import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/urls.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';

class ActivityBookCard extends StatelessWidget {
  const ActivityBookCard({
    super.key,
    required this.book,
    required this.coverShape,
    required this.countLabel,
    required this.expanded,
    required this.onExpand,
    this.preview,
    this.meta,
    this.percent,
    this.selection,
    this.child,
  });

  final Book book;
  final CoverShape coverShape;
  final String countLabel;
  final String? preview;
  final String? meta;
  final int? percent;
  final bool expanded;
  final VoidCallback onExpand;
  final Widget? selection;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color:
                  Colors.black.withValues(alpha: context.isDark ? 0.12 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: context.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: context.faintBorder.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: onExpand,
              child: Padding(
                padding: EdgeInsets.all(compact ? 16 : 20),
                child: Row(
                  children: [
                    if (selection != null) ...[
                      selection!,
                      const SizedBox(width: 12),
                    ],
                    SizedBox(
                      width: compact ? 64 : 80,
                      child: AspectRatio(
                        aspectRatio: coverAspectRatio(coverShape),
                        child: CoverImage(
                            url: bookCoverUrl(AppScope.appOf(context), book),
                            radius: 12),
                      ),
                    ),
                    SizedBox(width: compact ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                                child: Text(book.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: compact ? 14 : 16,
                                        fontWeight: FontWeight.w700))),
                            const SizedBox(width: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: context.isDark
                                    ? AppColors.slate800
                                    : AppColors.slate100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                child: Text(countLabel,
                                    style: TextStyle(
                                        color: context.mutedText,
                                        fontSize: 10)),
                              ),
                            ),
                          ]),
                          if (preview?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(preview!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: context.mutedText, fontSize: 12)),
                          ],
                          if (meta != null) ...[
                            const SizedBox(height: 6),
                            Row(children: [
                              Icon(Icons.access_time_rounded,
                                  size: 13, color: context.mutedText),
                              const SizedBox(width: 5),
                              Expanded(
                                  child: Text(meta!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: context.mutedText,
                                          fontSize: 12))),
                            ]),
                          ],
                          if (percent != null)
                            ActivityProgress(percent: percent!),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: expanded ? 0 : -0.25,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20, color: context.mutedText),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded && child != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.isDark
                      ? AppColors.slate950.withValues(alpha: 0.25)
                      : AppColors.slate50.withValues(alpha: 0.6),
                  border: Border(
                      top: BorderSide(
                          color: context.faintBorder.withValues(alpha: 0.6))),
                ),
                child: Material(type: MaterialType.transparency, child: child!),
              ),
          ],
        ),
      ),
    );
  }
}

class ActivityProgress extends StatelessWidget {
  const ActivityProgress(
      {super.key, required this.percent, this.topSpacing = 12});
  final int percent;
  final double topSpacing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: topSpacing),
        child: Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: percent / 100,
                backgroundColor: context.isDark
                    ? AppColors.slate800
                    : AppColors.slate200.withValues(alpha: 0.6),
                color: percent == 100
                    ? const Color(0xff10b981)
                    : AppColors.primary500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
              width: 32,
              child: Text('$percent%',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: context.mutedText, fontSize: 10))),
        ]),
      );
}
