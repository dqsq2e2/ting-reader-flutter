import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/state/download_state.dart';
import '../../core/state/player_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/urls.dart';
import '../../shared/app_scope.dart';
import '../../shared/cards/book_card.dart';
import '../../shared/common/common_widgets.dart';

part 'parts/chapter_sheet.dart';
part 'parts/collapsed_mini_player.dart';
part 'parts/expanded_player.dart';
part 'parts/player_controls.dart';
part 'parts/scrolling_title.dart';
part 'parts/theme_utils.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  CoverShape _coverShape = CoverShape.rect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coverShape = coverShapeFromAppSettings(AppScope.appOf(context).settings);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final player = AppScope.playerOf(context);

    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final book = player.currentBook;
        final chapter = player.currentChapter;
        if (book == null || chapter == null) return const SizedBox.shrink();

        final percent = player.duration > 0
            ? (player.currentTime / player.duration).clamp(0.0, 1.0)
            : 0.0;
        final duration =
            player.duration > 0 ? player.duration : chapter.duration.toDouble();
        final themeColor = _effectivePlayerThemeColor(book.themeColor);
        final accentColor = themeColor ?? AppColors.primary600;
        final subduedAccent =
            themeColor != null && !_isPlayerThemeLight(themeColor)
                ? themeColor.withValues(alpha: 0.72)
                : (context.isDark ? AppColors.slate300 : AppColors.slate500);
        final onAccent = themeColor != null && _isPlayerThemeLight(themeColor)
            ? AppColors.slate600
            : Colors.white;
        final bgColor = themeColor == null
            ? (context.isDark
                ? AppColors.slate900.withValues(alpha: 0.97)
                : Colors.white.withValues(alpha: 0.98))
            : Color.alphaBlend(
                themeColor.withValues(alpha: context.isDark ? 0.18 : 0.12),
                context.isDark ? AppColors.slate900 : Colors.white,
              );
        final borderColor = themeColor == null
            ? context.faintBorder
            : themeColor.withValues(alpha: context.isDark ? 0.32 : 0.28);

        if (player.isMiniCollapsed) {
          return _CollapsedMiniPlayer(
            appState: appState,
            player: player,
            book: book,
            chapter: chapter,
            coverShape: _coverShape,
            accentColor: accentColor,
            subduedAccent: subduedAccent,
            onAccent: onAccent,
            bgColor: bgColor,
            borderColor: borderColor,
          );
        }

        final screenWidth = MediaQuery.sizeOf(context).width;
        final isPhoneWidth = screenWidth < 640;
        final miniHeight = isPhoneWidth ? 72.0 : 88.0;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Container(
              height: miniHeight,
              padding: EdgeInsets.symmetric(
                horizontal: isPhoneWidth ? 10 : 24,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: context.isDark ? 0.36 : 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: context.isDark ? Colors.white : AppColors.slate900,
                  decoration: TextDecoration.none,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 768;
                    final compact = !desktop;
                    final tiny = constraints.maxWidth < 500;
                    final veryTiny = constraints.maxWidth < 380;
                    final coverWidth = _coverShape == CoverShape.square
                        ? (veryTiny
                            ? 42.0
                            : desktop
                                ? 72.0
                                : 50.0)
                        : (veryTiny
                            ? 34.0
                            : desktop
                                ? 56.0
                                : 44.0);
                    final coverHeight = _coverShape == CoverShape.square
                        ? coverWidth
                        : coverWidth / (3 / 4);
                    final infoWidth = constraints.maxWidth >= 1024
                        ? 320.0
                        : constraints.maxWidth >= 768
                            ? 240.0
                            : 200.0;
                    final centerHorizontalPadding =
                        constraints.maxWidth >= 1024 ? 24.0 : 12.0;
                    final rightWidth =
                        constraints.maxWidth >= 1024 ? 140.0 : 100.0;
                    final row = Row(
                      children: [
                        GestureDetector(
                          onTap: () => _openExpanded(context, player),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: coverWidth,
                                height: coverHeight,
                                child: CoverImage(
                                  url: bookCoverUrl(appState, book),
                                  radius: 12,
                                ),
                              ),
                              if (!compact && !tiny) ...[
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: infoWidth - coverWidth - 12,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.isDark
                                              ? Colors.white
                                              : AppColors.slate900,
                                          decoration: TextDecoration.none,
                                          fontSize: 14,
                                          height: 1.18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        chapter.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.mutedText,
                                          decoration: TextDecoration.none,
                                          fontSize: 12,
                                          height: 1.18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!compact) ...[
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: centerHorizontalPadding),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _MiniIconButton(
                                        icon: Icons.skip_previous_rounded,
                                        color: subduedAccent,
                                        onPressed: player.previousChapter,
                                      ),
                                      const SizedBox(width: 24),
                                      _MiniIconButton(
                                        icon: Icons.rotate_left_rounded,
                                        color: subduedAccent,
                                        onPressed: () => player.seek(
                                          (player.currentTime - 15)
                                              .clamp(0, duration)
                                              .toDouble(),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      _IconCircle(
                                        filled: true,
                                        icon: player.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        onPressed: player.togglePlay,
                                        diameter: 40,
                                        iconSize: 22,
                                        fillColor: accentColor,
                                        filledIconColor: onAccent,
                                      ),
                                      const SizedBox(width: 24),
                                      _MiniIconButton(
                                        icon: Icons.rotate_right_rounded,
                                        color: subduedAccent,
                                        onPressed: () => player.seek(
                                          (player.currentTime + 30)
                                              .clamp(0, duration)
                                              .toDouble(),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      _MiniIconButton(
                                        icon: Icons.skip_next_rounded,
                                        color: subduedAccent,
                                        onPressed: player.nextChapter,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 32,
                                        child: Text(
                                          formatDurationShort(
                                              player.currentTime),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: context.tertiaryText,
                                            decoration: TextDecoration.none,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _MiniProgressSlider(
                                          player: player,
                                          currentTime: player.currentTime,
                                          duration: duration,
                                          percent: percent,
                                          accentColor: accentColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 32,
                                        child: Text(
                                          formatDurationShort(duration),
                                          style: TextStyle(
                                            color: context.tertiaryText,
                                            decoration: TextDecoration.none,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(minWidth: rightWidth),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _MiniIconButton(
                                  icon: player.volume <= 0
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: subduedAccent,
                                  onPressedWithContext: (buttonContext) =>
                                      _openMiniVolumePopover(
                                    player,
                                    buttonContext,
                                  ),
                                ),
                                SizedBox(
                                    width:
                                        constraints.maxWidth >= 1024 ? 16 : 10),
                                _MiniTextButton(
                                  label: _formatPlaybackSpeed(
                                      player.playbackSpeed),
                                  color: accentColor,
                                  onPressed: () => _cycleMiniSpeed(player),
                                ),
                                SizedBox(
                                    width:
                                        constraints.maxWidth >= 1024 ? 16 : 10),
                                _MiniCollapseButton(
                                  icon: Icons.chevron_left_rounded,
                                  color: subduedAccent,
                                  onPressed: () =>
                                      player.setMiniCollapsed(true),
                                  plain: true,
                                ),
                                SizedBox(
                                    width:
                                        constraints.maxWidth >= 1024 ? 8 : 4),
                                _MiniIconButton(
                                  icon: Icons.open_in_full_rounded,
                                  color: subduedAccent,
                                  onPressed: () async =>
                                      _openExpanded(context, player),
                                ),
                                SizedBox(
                                    width:
                                        constraints.maxWidth >= 1024 ? 4 : 2),
                              ],
                            ),
                          ),
                        ] else ...[
                          SizedBox(width: veryTiny ? 8 : 10),
                          Expanded(
                            flex: 2,
                            child: _MiniProgressSlider(
                              player: player,
                              currentTime: player.currentTime,
                              duration: duration,
                              percent: percent,
                              accentColor: accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _IconCircle(
                            filled: true,
                            icon: player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            onPressed: player.togglePlay,
                            diameter: veryTiny ? 38 : 40,
                            iconSize: veryTiny ? 21 : 22,
                            fillColor: accentColor,
                            filledIconColor: onAccent,
                          ),
                          SizedBox(width: veryTiny ? 14 : 16),
                          _MiniCollapseButton(
                            icon: Icons.chevron_left_rounded,
                            color: subduedAccent,
                            onPressed: () => player.setMiniCollapsed(true),
                            size: veryTiny ? 32 : 34,
                            circleSize: veryTiny ? 28 : 30,
                            iconSize: veryTiny ? 19 : 20,
                          ),
                        ],
                      ],
                    );
                    return Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: compact
                          ? (event) {
                              if (event.localPosition.dx >=
                                  constraints.maxWidth - 42) {
                                player.setMiniCollapsed(true);
                              }
                            }
                          : null,
                      onPointerUp: compact
                          ? (event) {
                              if (event.localPosition.dx >=
                                  constraints.maxWidth - 42) {
                                player.setMiniCollapsed(true);
                              }
                            }
                          : null,
                      child: row,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _cycleMiniSpeed(PlayerState player) async {
    const steps = [0.75, 1.0, 1.25, 1.5, 2.0];
    final index = steps
        .indexWhere((value) => (value - player.playbackSpeed).abs() < 0.001);
    final next = steps[(index + 1) % steps.length];
    await player.setSpeed(next);
  }

  Future<void> _openMiniVolumePopover(
    PlayerState player,
    BuildContext anchorContext,
  ) async {
    final anchor = _buttonRect(anchorContext);
    if (anchor == null) return;
    var nextVolume = player.volume.clamp(0, 1).toDouble();
    await _showMiniAnchoredPopover(
      anchor: anchor,
      width: 52,
      height: 178,
      child: StatefulBuilder(
        builder: (context, setPopoverState) {
          return Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: context.faintBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.36 : 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(nextVolume * 100).round()}',
                  style: TextStyle(
                    color: context.secondaryText,
                    decoration: TextDecoration.none,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                RotatedBox(
                  quarterTurns: -1,
                  child: SizedBox(
                    width: 108,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: AppColors.primary500,
                        inactiveTrackColor: context.isDark
                            ? AppColors.slate700
                            : AppColors.slate200,
                        thumbColor: AppColors.primary500,
                        overlayColor: AppColors.primary500.withValues(alpha: 0.14),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 13,
                        ),
                      ),
                      child: Slider(
                        min: 0,
                        max: 1,
                        value: nextVolume,
                        onChanged: (value) {
                          setPopoverState(() => nextVolume = value);
                          player.setVolume(value);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  nextVolume <= 0
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  size: 17,
                  color: AppColors.slate500,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openExpanded(BuildContext context, PlayerState player) {
    player.setExpanded(true);
  }

  Rect? _buttonRect(BuildContext anchorContext) {
    final box = anchorContext.findRenderObject();
    final overlayBox = Overlay.of(context).context.findRenderObject();
    if (box is! RenderBox || overlayBox is! RenderBox) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    return topLeft & box.size;
  }

  Future<void> _showMiniAnchoredPopover({
    required Rect anchor,
    required double width,
    required double height,
    required Widget child,
  }) {
    final overlaySize = MediaQuery.sizeOf(context);
    final left = (anchor.center.dx - width / 2)
        .clamp(12.0, overlaySize.width - width - 12);
    final top = (anchor.top - height - 12)
        .clamp(12.0, overlaySize.height - height - 12);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, _, __) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.pop(dialogContext),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Material(color: Colors.transparent, child: child),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class ExpandedPlayerOverlay extends StatelessWidget {
  const ExpandedPlayerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final player = AppScope.playerOf(context);
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        if (!player.isExpanded || !player.hasChapter) {
          return const SizedBox.shrink();
        }
        return _ExpandedPlayer(player: player);
      },
    );
  }
}

