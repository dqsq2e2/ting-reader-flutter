import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/urls.dart';
import 'app_scope.dart';
import 'common_widgets.dart';

enum CoverShape { rect, square }

enum IconSizeSetting { small, medium, large }

CoverShape coverShapeFromString(String? value) {
  return value == 'square' ? CoverShape.square : CoverShape.rect;
}

CoverShape coverShapeFromAppSettings(Map<String, dynamic> settings) {
  final settingsJson = asMap(
    settings['settings_json'] ?? settings['settingsJson'],
  );
  final directValue =
      settings['bookshelfCoverShape'] ?? settings['bookshelf_cover_shape'];
  return coverShapeFromString(
    (directValue ??
            settingsJson['bookshelfCoverShape'] ??
            settingsJson['bookshelf_cover_shape'])
        ?.toString(),
  );
}

double coverAspectRatio(CoverShape shape) {
  return shape == CoverShape.square ? 1 : 3 / 4;
}

IconSizeSetting iconSizeFromString(String? value) {
  if (value == 'small') return IconSizeSetting.small;
  if (value == 'large') return IconSizeSetting.large;
  return IconSizeSetting.medium;
}

IconSizeSetting iconSizeFromAppSettings(Map<String, dynamic> settings) {
  final settingsJson = asMap(
    settings['settings_json'] ?? settings['settingsJson'],
  );
  final directValue =
      settings['bookshelfIconSize'] ?? settings['bookshelf_icon_size'];
  return iconSizeFromString(
    (directValue ??
            settingsJson['bookshelfIconSize'] ??
            settingsJson['bookshelf_icon_size'])
        ?.toString(),
  );
}

int gridColumnsForWidth(double width, IconSizeSetting size) {
  if (size == IconSizeSetting.small) {
    if (width >= 1500) return 10;
    if (width >= 1024) return 8;
    if (width >= 768) return 7;
    if (width >= 520) return 6;
    return 4;
  }
  if (size == IconSizeSetting.large) {
    if (width >= 1500) return 6;
    if (width >= 768) return 4;
    return 2;
  }
  if (width >= 1500) return 7;
  if (width >= 1024) return 6;
  if (width >= 640) return 5;
  return 3;
}

double gridSpacing(IconSizeSetting size) {
  switch (size) {
    case IconSizeSetting.small:
      return 12;
    case IconSizeSetting.medium:
      return 20;
    case IconSizeSetting.large:
      return 24;
  }
}

class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.coverShape = CoverShape.rect,
    this.selected = false,
    this.selectionMode = false,
  });

  final Book book;
  final VoidCallback onTap;
  final CoverShape coverShape;
  final bool selected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final url = bookCoverUrl(appState, book);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: selectionMode && !selected ? 0.64 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AspectRatio(
                  aspectRatio: coverAspectRatio(coverShape),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CoverImage(url: url, radius: 6),
                  ),
                ),
                if (selectionMode)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary600
                            : context.cardColor.withValues(alpha: 0.86),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary600
                              : AppColors.slate300,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              book.author?.isNotEmpty == true ? book.author! : '未知作者',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SeriesCard extends StatelessWidget {
  const SeriesCard({
    super.key,
    required this.series,
    required this.onTap,
    this.coverShape = CoverShape.rect,
  });

  final Series series;
  final VoidCallback onTap;
  final CoverShape coverShape;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final url = seriesCoverUrl(appState, series);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 8,
                right: 8,
                top: -6,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? AppColors.slate800
                        : AppColors.slate200,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 3,
                right: 3,
                top: -1,
                bottom: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? AppColors.slate700
                        : AppColors.slate300,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              AspectRatio(
                aspectRatio: coverAspectRatio(coverShape),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CoverImage(url: url, radius: 6),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers_rounded, color: Colors.white, size: 11),
                      SizedBox(width: 4),
                      Text(
                        '系列',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary600.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${series.books.length} 本书',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            series.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            series.author?.isNotEmpty == true ? series.author! : '系列',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
