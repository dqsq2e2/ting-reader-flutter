import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/download_state.dart';
import '../state/player_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/urls.dart';
import 'app_scope.dart';
import 'book_card.dart';
import 'common_widgets.dart';

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
                ? themeColor.withOpacity(0.72)
                : (context.isDark ? AppColors.slate300 : AppColors.slate500);
        final onAccent = themeColor != null && _isPlayerThemeLight(themeColor)
            ? AppColors.slate600
            : Colors.white;
        final bgColor = themeColor == null
            ? (context.isDark
                ? AppColors.slate900.withOpacity(0.97)
                : Colors.white.withOpacity(0.98))
            : Color.alphaBlend(
                themeColor.withOpacity(context.isDark ? 0.18 : 0.12),
                context.isDark ? AppColors.slate900 : Colors.white,
              );
        final borderColor = themeColor == null
            ? context.faintBorder
            : themeColor.withOpacity(context.isDark ? 0.32 : 0.28);

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
                        Colors.black.withOpacity(context.isDark ? 0.36 : 0.16),
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
                  color: Colors.black.withOpacity(context.isDark ? 0.36 : 0.16),
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
                        overlayColor: AppColors.primary500.withOpacity(0.14),
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

class _MiniProgressSlider extends StatefulWidget {
  const _MiniProgressSlider({
    required this.player,
    required this.currentTime,
    required this.duration,
    required this.percent,
    required this.accentColor,
  });

  final PlayerState player;
  final double currentTime;
  final double duration;
  final double percent;
  final Color accentColor;

  @override
  State<_MiniProgressSlider> createState() => _MiniProgressSliderState();
}

class _MiniProgressSliderState extends State<_MiniProgressSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final max = widget.duration > 0 ? widget.duration : 1.0;
    final value = (_dragValue ?? widget.currentTime).clamp(0, max).toDouble();
    final canSeek = max > 1 || widget.percent > 0;
    return SizedBox(
      height: 24,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          activeTrackColor: widget.accentColor,
          inactiveTrackColor:
              context.isDark ? AppColors.slate800 : AppColors.slate200,
          thumbColor: widget.accentColor,
          overlayColor: widget.accentColor.withOpacity(0.12),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(
          min: 0,
          max: max,
          value: value,
          onChanged:
              canSeek ? (next) => setState(() => _dragValue = next) : null,
          onChangeStart:
              canSeek ? (_) => setState(() => _dragValue = value) : null,
          onChangeEnd: canSeek
              ? (next) {
                  setState(() => _dragValue = null);
                  widget.player.seek(next);
                }
              : null,
        ),
      ),
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

class _CollapsedMiniPlayer extends StatelessWidget {
  const _CollapsedMiniPlayer({
    required this.appState,
    required this.player,
    required this.book,
    required this.chapter,
    required this.coverShape,
    required this.accentColor,
    required this.subduedAccent,
    required this.onAccent,
    required this.bgColor,
    required this.borderColor,
  });

  final AppState appState;
  final PlayerState player;
  final Book book;
  final Chapter chapter;
  final CoverShape coverShape;
  final Color accentColor;
  final Color subduedAccent;
  final Color onAccent;
  final Color bgColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final width = coverShape == CoverShape.square ? 62.0 : 48.0;
    final height = coverShape == CoverShape.square ? 62.0 : 64.0;
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => player.setMiniCollapsed(false),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor.withOpacity(0.9),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(context.isDark ? 0.36 : 0.16),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: CoverImage(
            url: bookCoverUrl(appState, book),
            radius: 12,
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.color,
    this.onPressed,
    this.onPressedWithContext,
  }) : assert(onPressed != null || onPressedWithContext != null);

  final IconData icon;
  final Color color;
  final Future<void> Function()? onPressed;
  final Future<void> Function(BuildContext context)? onPressedWithContext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final contextHandler = onPressedWithContext;
          if (contextHandler != null) {
            contextHandler(context);
            return;
          }
          onPressed?.call();
        },
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _MiniCollapseButton extends StatelessWidget {
  const _MiniCollapseButton({
    this.icon = Icons.keyboard_arrow_down_rounded,
    required this.color,
    required this.onPressed,
    this.plain = false,
    this.size,
    this.circleSize,
    this.iconSize,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool plain;
  final double? size;
  final double? circleSize;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final targetSize = size ?? (plain ? 32.0 : 48.0);
    final visualSize = circleSize ?? 38.0;
    final resolvedIconSize = iconSize ?? 22.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: targetSize,
        height: targetSize,
        child: Center(
          child: plain
              ? Icon(icon, color: color, size: resolvedIconSize)
              : Container(
                  width: visualSize,
                  height: visualSize,
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? AppColors.slate800.withOpacity(0.52)
                        : AppColors.slate100.withOpacity(0.86),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: resolvedIconSize,
                  ),
                ),
        ),
      ),
    );
  }
}

class _MiniTextButton extends StatelessWidget {
  const _MiniTextButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final light = _isPlayerThemeLight(color);
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onPressed(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: light ? AppColors.slate600 : color,
              decoration: TextDecoration.none,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaybackSettingField extends StatelessWidget {
  const _PlaybackSettingField({
    required this.controller,
    required this.icon,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: context.mutedText),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: context.tertiaryText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: context.isDark ? AppColors.slate800 : AppColors.slate50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.faintBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: AppColors.primary500, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.ghost = false,
    this.diameter,
    this.iconSize,
    this.fillColor,
    this.filledIconColor,
  });

  final IconData icon;
  final Future<void> Function() onPressed;
  final bool filled;
  final bool ghost;
  final double? diameter;
  final double? iconSize;
  final Color? fillColor;
  final Color? filledIconColor;

  @override
  Widget build(BuildContext context) {
    final size = diameter ?? (filled ? 46 : 38);
    final resolvedIconSize = iconSize ?? (filled ? 28 : 22);
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: filled
            ? (fillColor ?? AppColors.primary600)
            : ghost
                ? Colors.transparent
                : (context.isDark
                    ? AppColors.slate800.withOpacity(0.6)
                    : Colors.white.withOpacity(0.6)),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onPressed(),
          child: Icon(
            icon,
            color:
                filled ? (filledIconColor ?? Colors.white) : context.mutedText,
            size: resolvedIconSize,
          ),
        ),
      ),
    );
  }
}

class _ExpandedPlayer extends StatefulWidget {
  const _ExpandedPlayer({required this.player});

  final PlayerState player;

  @override
  State<_ExpandedPlayer> createState() => _ExpandedPlayerState();
}

class _ExpandedPlayerState extends State<_ExpandedPlayer> {
  static const _speedSteps = [0.75, 1.0, 1.25, 1.5, 2.0];

  Timer? _sleepTimer;
  int? _sleepRemainingSeconds;
  CoverShape _coverShape = CoverShape.rect;
  double? _dragSeekValue;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coverShape = coverShapeFromAppSettings(AppScope.appOf(context).settings);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleSpeed(PlayerState player) async {
    final current = player.playbackSpeed;
    final index =
        _speedSteps.indexWhere((value) => (value - current).abs() < 0.001);
    final next = _speedSteps[(index + 1) % _speedSteps.length];
    await player.setSpeed(next);
  }

  Future<void> _downloadCurrentChapter(PlayerState player) async {
    final book = player.currentBook;
    final chapter = player.currentChapter;
    if (book == null || chapter == null) return;

    final downloadState = AppScope.downloadOf(context);
    if (downloadState.hasChapter(chapter.id)) {
      _showPlayerMessage('当前章节已下载');
      return;
    }
    final task = downloadState.taskForChapter(chapter.id);
    if (task != null) {
      if (task.status == DownloadStatus.paused ||
          task.status == DownloadStatus.failed) {
        await downloadState.resumeTask(chapter.id);
        _showPlayerMessage('已恢复下载：${chapter.title}');
      } else {
        _showPlayerMessage('下载任务已存在：${task.status.label}');
      }
      return;
    }

    try {
      downloadState.queueChapter(book, chapter);
      _showPlayerMessage('已加入下载队列：${chapter.title}');
    } catch (err) {
      _showPlayerMessage('加入下载失败：$err');
    }
  }

  void _showPlayerMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  _ExpandedDownloadAction _downloadActionFor(Chapter chapter) {
    final downloadState = AppScope.downloadOf(context);
    if (downloadState.hasChapter(chapter.id)) {
      return const _ExpandedDownloadAction(
        icon: Icons.download_done_rounded,
        label: '已下载',
        active: true,
      );
    }
    final task = downloadState.taskForChapter(chapter.id);
    if (task == null) {
      return const _ExpandedDownloadAction(
        icon: Icons.download_rounded,
        label: '下载',
      );
    }
    return _ExpandedDownloadAction(
      icon: switch (task.status) {
        DownloadStatus.downloading => Icons.downloading_rounded,
        DownloadStatus.paused => Icons.pause_circle_outline_rounded,
        DownloadStatus.failed => Icons.error_outline_rounded,
        DownloadStatus.completed => Icons.download_done_rounded,
        DownloadStatus.queued => Icons.schedule_rounded,
      },
      label: task.status == DownloadStatus.downloading
          ? '${(task.progress * 100).clamp(0, 100).round()}%'
          : task.status.label,
      active: task.status != DownloadStatus.failed,
    );
  }

  Rect _buttonRect(BuildContext anchorContext) {
    final box = anchorContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      final size = MediaQuery.sizeOf(context);
      return Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 1,
        height: 1,
      );
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _showAnchoredPopover({
    required BuildContext anchorContext,
    required double width,
    required double estimatedHeight,
    required WidgetBuilder builder,
    bool alignRight = false,
  }) async {
    final anchor = _buttonRect(anchorContext);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final minLeft = padding.left + 12;
    final maxLeft = size.width - width - padding.right - 12;
    var left = alignRight ? anchor.right - width : anchor.center.dx - width / 2;
    if (maxLeft >= minLeft) {
      left = left.clamp(minLeft, maxLeft).toDouble();
    }
    var top = anchor.top - estimatedHeight - 14;
    final minTop = padding.top + 12;
    if (top < minTop) {
      top = anchor.bottom + 12;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, __) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: width,
              child: Material(
                color: Colors.transparent,
                child: builder(dialogContext),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openVolumeSheet(
    PlayerState player,
    BuildContext anchorContext,
  ) async {
    final current = player.volume;
    var nextVolume = current;
    await _showAnchoredPopover(
      anchorContext: anchorContext,
      width: 50,
      estimatedHeight: 206,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: context.faintBorder),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withOpacity(context.isDark ? 0.48 : 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(nextVolume * 100).round()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 100,
                    width: 48,
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 13,
                          ),
                        ),
                        child: Slider(
                          min: 0,
                          max: 1,
                          value: nextVolume.clamp(0, 1).toDouble(),
                          activeColor: AppColors.primary600,
                          inactiveColor: context.isDark
                              ? AppColors.slate700
                              : AppColors.slate200,
                          onChanged: (value) {
                            setSheetState(() => nextVolume = value);
                            player.setVolume(value);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    tooltip: nextVolume <= 0 ? '取消静音' : '静音',
                    onPressed: () {
                      final value = nextVolume <= 0 ? 1.0 : 0.0;
                      setSheetState(() => nextVolume = value);
                      player.setVolume(value);
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: nextVolume <= 0
                          ? AppColors.primary100
                          : Colors.transparent,
                      foregroundColor: nextVolume <= 0
                          ? AppColors.primary600
                          : AppColors.slate400,
                      minimumSize: const Size(34, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      nextVolume <= 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      size: 17,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _startSleepTimer(PlayerState player, int minutes) async {
    _sleepTimer?.cancel();
    _sleepRemainingSeconds = minutes * 60;
    setState(() {});
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final remaining = (_sleepRemainingSeconds ?? 0) - 1;
      if (remaining <= 0) {
        _sleepTimer?.cancel();
        _sleepTimer = null;
        _sleepRemainingSeconds = null;
        if (player.isPlaying) {
          await player.togglePlay();
        }
        if (mounted) setState(() {});
        return;
      }
      _sleepRemainingSeconds = remaining;
      if (mounted) setState(() {});
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepRemainingSeconds = null;
    if (mounted) setState(() {});
  }

  Future<void> _openSleepTimerSheet(
    PlayerState player,
    BuildContext anchorContext,
  ) async {
    final controller = TextEditingController();
    await _showAnchoredPopover(
      anchorContext: anchorContext,
      width: 198,
      estimatedHeight: 204,
      alignRight: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: context.faintBorder),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withOpacity(context.isDark ? 0.48 : 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: context.faintBorder),
                      ),
                    ),
                    child: Text(
                      '睡眠定时',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.tertiaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  for (final row in const [
                    [15, 30],
                    [45, 60],
                  ]) ...[
                    Row(
                      children: [
                        for (var i = 0; i < row.length; i++) ...[
                          if (i > 0) const SizedBox(width: 7),
                          Expanded(
                            child: SizedBox(
                              height: 32,
                              child: OutlinedButton(
                                onPressed: () async {
                                  await _startSleepTimer(player, row[i]);
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: context.mutedText,
                                  side: BorderSide(color: context.faintBorder),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.zero,
                                  textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: Text('${row[i]} 分钟'),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (row.first != 45) const SizedBox(height: 7),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? AppColors.slate900.withOpacity(0.5)
                          : AppColors.slate50,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: context.faintBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: '自定义分钟',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final minutes =
                                int.tryParse(controller.text.trim()) ?? 0;
                            if (minutes <= 0) return;
                            await _startSleepTimer(player, minutes);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.primary600,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(48, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('开启'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _sleepTimer == null
                          ? null
                          : () {
                              _cancelSleepTimer();
                              Navigator.pop(dialogContext);
                            },
                      style: TextButton.styleFrom(
                        backgroundColor: context.isDark
                            ? const Color(0xff7f1d1d).withOpacity(0.22)
                            : const Color(0xfffff1f2),
                        foregroundColor: const Color(0xffef4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('取消定时'),
                    ),
                  ),
                  if (_sleepRemainingSeconds != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '剩余 ${_formatSleepTime(_sleepRemainingSeconds!)}',
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _openPlaybackSettings(PlayerState player, Book book) async {
    final introController =
        TextEditingController(text: book.skipIntro.toString());
    final outroController =
        TextEditingController(text: book.skipOutro.toString());
    final hostContext = context;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '播放设置',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(context.isDark ? 0.55 : 0.2),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '播放设置',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                          color: context.mutedText,
                          tooltip: '关闭',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _PlaybackSettingField(
                      controller: introController,
                      icon: Icons.skip_previous_rounded,
                      label: '跳过片头 (秒)',
                      hint: '例如: 30',
                    ),
                    const SizedBox(height: 18),
                    _PlaybackSettingField(
                      controller: outroController,
                      icon: Icons.skip_next_rounded,
                      label: '跳过片尾 (秒)',
                      hint: '例如: 15',
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              foregroundColor: context.mutedText,
                            ),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final skipIntro =
                                  int.tryParse(introController.text.trim()) ??
                                      0;
                              final skipOutro =
                                  int.tryParse(outroController.text.trim()) ??
                                      0;
                              try {
                                await player.appState.api.patch(
                                  '/api/books/${book.id}',
                                  data: {
                                    'skip_intro': skipIntro,
                                    'skip_outro': skipOutro,
                                  },
                                );
                                final updated = book.copyWith(
                                  skipIntro: skipIntro,
                                  skipOutro: skipOutro,
                                );
                                player.replaceCurrentBook(updated);
                                if (mounted) setState(() {});
                                if (!mounted) return;
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                ScaffoldMessenger.of(hostContext).showSnackBar(
                                  const SnackBar(content: Text('播放设置已保存')),
                                );
                              } catch (err) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(hostContext).showSnackBar(
                                  SnackBar(content: Text('保存失败：$err')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              elevation: 8,
                              shadowColor:
                                  AppColors.primary500.withOpacity(0.3),
                              backgroundColor: AppColors.primary600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 20),
                            label: const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    introController.dispose();
    outroController.dispose();
  }

  Future<void> _openChapterSheet(
      BuildContext context, PlayerState player, Color? themeColor) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ChapterSheetList(
        player: player,
        themeColor: themeColor,
      ),
    );
  }

  String _formatSleepTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final bottom = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: widget.player,
      builder: (context, _) {
        final player = widget.player;
        final book = player.currentBook;
        final chapter = player.currentChapter;
        if (book == null || chapter == null) return const SizedBox.shrink();
        final downloadAction = _downloadActionFor(chapter);
        final maxDuration =
            player.duration > 0 ? player.duration : chapter.duration.toDouble();
        final sliderMax = maxDuration <= 0 ? 1.0 : maxDuration;
        final sliderValue = (_dragSeekValue ?? player.currentTime)
            .clamp(0, sliderMax)
            .toDouble();
        final themeColor = _effectivePlayerThemeColor(book.themeColor);
        final accentColor = themeColor ?? AppColors.primary600;
        final accentTextColor =
            themeColor != null && _isPlayerThemeLight(themeColor)
                ? AppColors.slate600
                : Colors.white;
        final coverUrl = bookCoverUrl(appState, book);
        final backgroundColor = context.isDark
            ? AppColors.slate950
            : Color.alphaBlend(
                (themeColor ?? AppColors.primary600).withOpacity(0.08),
                const Color(0xfffbfaf7),
              );
        final size = MediaQuery.sizeOf(context);
        final compactControls = size.width < 480 || size.height < 760;
        final tightControls = size.width < 380 || size.height < 680;
        final mainButtonSize =
            tightControls ? 66.0 : (compactControls ? 74.0 : 80.0);
        final mainIconSize =
            tightControls ? 32.0 : (compactControls ? 36.0 : 38.0);
        final sideButtonSize =
            tightControls ? 42.0 : (compactControls ? 46.0 : 50.0);
        final sideIconSize =
            tightControls ? 22.0 : (compactControls ? 24.0 : 26.0);
        final controlGap =
            tightControls ? 14.0 : (compactControls ? 18.0 : 22.0);
        final coverMaxWidth = _coverShape == CoverShape.square
            ? (tightControls ? 300.0 : 340.0)
            : (tightControls ? 280.0 : 320.0);
        final coverMaxHeight = _coverShape == CoverShape.square
            ? coverMaxWidth
            : (tightControls ? 340.0 : 390.0);

        return Material(
          color: backgroundColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: backgroundColor),
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: context.isDark ? 0.24 : 0.18,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
                      child: Transform.scale(
                        scale: 1.18,
                        child: CoverImage(
                          url: coverUrl,
                          radius: 0,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: context.isDark
                          ? [
                              AppColors.slate950.withOpacity(0.92),
                              AppColors.slate950.withOpacity(0.86),
                              AppColors.slate950.withOpacity(0.96),
                            ]
                          : [
                              backgroundColor.withOpacity(0.90),
                              backgroundColor.withOpacity(0.72),
                              backgroundColor.withOpacity(0.94),
                            ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(22, 18, 22, 28 + bottom),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _IconCircle(
                                icon: Icons.keyboard_arrow_down_rounded,
                                ghost: true,
                                onPressed: () async =>
                                    player.setExpanded(false),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Column(
                                    children: [
                                      Text(
                                        chapter.title,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        book.title,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: context.mutedText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              _IconCircle(
                                icon: Icons.settings_rounded,
                                ghost: true,
                                onPressed: () async =>
                                    _openPlaybackSettings(player, book),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: coverMaxWidth,
                              maxHeight: coverMaxHeight,
                            ),
                            child: AspectRatio(
                              aspectRatio: coverAspectRatio(_coverShape),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: context.isDark
                                        ? AppColors.slate800
                                        : Colors.white,
                                    width: 7,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                          context.isDark ? 0.44 : 0.18),
                                      blurRadius: 34,
                                      offset: const Offset(0, 22),
                                    ),
                                  ],
                                ),
                                child: CoverImage(
                                  url: coverUrl,
                                  radius: 24,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: tightControls ? 20 : 24),
                          SizedBox(
                            height: tightControls ? 32 : 36,
                            child: _ScrollingPlayerTitle(
                              text: chapter.title,
                              style: TextStyle(
                                fontSize: tightControls ? 22 : 24,
                                height: 1.18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            book.narrator ?? book.author ?? book.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.mutedText,
                              fontSize: 14,
                            ),
                          ),
                          if (player.error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xfffff1f2),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xffffcdd5)),
                              ),
                              child: Text(
                                player.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xffe11d48),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: tightControls ? 16 : 20),
                          Row(
                            children: [
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.bolt_rounded,
                                  label: _formatPlaybackSpeed(
                                      player.playbackSpeed),
                                  active: player.playbackSpeed != 1,
                                  onTap: () => _toggleSpeed(player),
                                ),
                              ),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: player.volume <= 0
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  label: player.volume <= 0
                                      ? '静音'
                                      : '${(player.volume * 100).round()}%',
                                  active: player.volume != 1,
                                  onTapWithContext: (buttonContext) =>
                                      _openVolumeSheet(player, buttonContext),
                                ),
                              ),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: downloadAction.icon,
                                  label: downloadAction.label,
                                  active: downloadAction.active,
                                  onTap: () => _downloadCurrentChapter(player),
                                ),
                              ),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.timer_outlined,
                                  label: _sleepRemainingSeconds == null
                                      ? '定时'
                                      : _formatSleepTime(
                                          _sleepRemainingSeconds!),
                                  active: _sleepRemainingSeconds != null,
                                  onTapWithContext: (buttonContext) =>
                                      _openSleepTimerSheet(
                                          player, buttonContext),
                                ),
                              ),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.list_alt_rounded,
                                  label: '选集',
                                  onTap: () => _openChapterSheet(
                                      context, player, themeColor),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: tightControls ? 16 : 22),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 6,
                              activeTrackColor: accentColor,
                              inactiveTrackColor: context.isDark
                                  ? AppColors.slate800
                                  : AppColors.slate200,
                              thumbColor: accentColor,
                              overlayColor: accentColor.withOpacity(0.16),
                            ),
                            child: Slider(
                              min: 0,
                              max: sliderMax,
                              value: sliderValue,
                              onChanged: (value) =>
                                  setState(() => _dragSeekValue = value),
                              onChangeStart: (_) =>
                                  setState(() => _dragSeekValue = sliderValue),
                              onChangeEnd: (value) {
                                setState(() => _dragSeekValue = null);
                                player.seek(value);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                _SeekButton(
                                  icon: Icons.rotate_left_rounded,
                                  label: '15',
                                  onPressed: () => player.seek(
                                    (player.currentTime - 15)
                                        .clamp(0, maxDuration)
                                        .toDouble(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  formatDurationShort(sliderValue),
                                  style: TextStyle(
                                    color: context.mutedText,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  formatDurationShort(maxDuration),
                                  style: TextStyle(
                                    color: context.mutedText,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _SeekButton(
                                  icon: Icons.rotate_right_rounded,
                                  label: '15',
                                  onPressed: () => player.seek(
                                    (player.currentTime + 15)
                                        .clamp(0, maxDuration)
                                        .toDouble(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: tightControls ? 20 : 26),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _IconCircle(
                                icon: Icons.skip_previous_rounded,
                                onPressed: player.previousChapter,
                                diameter: sideButtonSize,
                                iconSize: sideIconSize,
                              ),
                              SizedBox(width: controlGap),
                              _IconCircle(
                                filled: true,
                                icon: player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                onPressed: player.togglePlay,
                                diameter: mainButtonSize,
                                iconSize: mainIconSize,
                                fillColor: accentColor,
                                filledIconColor: accentTextColor,
                              ),
                              SizedBox(width: controlGap),
                              _IconCircle(
                                icon: Icons.skip_next_rounded,
                                onPressed: player.nextChapter,
                                diameter: sideButtonSize,
                                iconSize: sideIconSize,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Color? _effectivePlayerThemeColor(String? raw) {
  final color = _parsePlayerThemeColor(raw);
  if (color == null) return null;
  return _playerThemeLuminance(color) > 0.9 ? null : color;
}

Color? _parsePlayerThemeColor(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  if (value.startsWith('#')) {
    var hex = value.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((char) => '$char$char').join();
    }
    if (hex.length == 6) {
      final rgb = int.tryParse(hex, radix: 16);
      if (rgb != null) return Color(0xff000000 | rgb);
    }
  }

  final match = RegExp(r'rgba?\(([^)]+)\)').firstMatch(value);
  if (match != null) {
    final parts = match
        .group(1)!
        .split(',')
        .map((part) => part.trim())
        .toList(growable: false);
    if (parts.length >= 3) {
      int? channel(String text) {
        final parsed = double.tryParse(text);
        if (parsed == null) return null;
        return parsed.round().clamp(0, 255);
      }

      final r = channel(parts[0]);
      final g = channel(parts[1]);
      final b = channel(parts[2]);
      if (r != null && g != null && b != null) {
        return Color.fromARGB(255, r, g, b);
      }
    }
  }
  return null;
}

double _playerThemeLuminance(Color color) {
  return (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
}

bool _isPlayerThemeLight(Color color) => _playerThemeLuminance(color) > 0.65;

String _formatPlaybackSpeed(double speed) {
  if ((speed - speed.roundToDouble()).abs() < 0.001) {
    return '${speed.round()}x';
  }
  var text = speed.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return '${text}x';
}

class _ChapterPageGroup {
  const _ChapterPageGroup({
    required this.start,
    required this.end,
    required this.chapters,
  });

  final int start;
  final int end;
  final List<Chapter> chapters;
}

class _ChapterSheetList extends StatefulWidget {
  const _ChapterSheetList({
    required this.player,
    required this.themeColor,
  });

  final PlayerState player;
  final Color? themeColor;

  @override
  State<_ChapterSheetList> createState() => _ChapterSheetListState();
}

class _ChapterSheetListState extends State<_ChapterSheetList> {
  static const _chaptersPerGroup = 100;

  late bool _showExtra;
  int _groupIndex = 0;
  bool _ascending = true;
  final Map<String, GlobalKey> _chapterKeys = {};
  final Map<int, GlobalKey> _groupKeys = {};

  @override
  void initState() {
    super.initState();
    _showExtra = _chapterLooksExtra(widget.player.currentChapter);
    _groupIndex = _initialGroupIndex();
    _ensureCurrentVisible();
  }

  void _ensureCurrentVisible({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final groupContext = _groupKeys[_groupIndex]?.currentContext;
      if (groupContext != null) {
        Scrollable.ensureVisible(
          groupContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }

      final currentId = widget.player.currentChapter?.id;
      final chapterContext =
          currentId == null ? null : _chapterKeys[currentId]?.currentContext;
      if (chapterContext != null) {
        Scrollable.ensureVisible(
          chapterContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (attempt < 3) {
        _ensureCurrentVisible(attempt: attempt + 1);
      }
    });
  }

  int _initialGroupIndex() {
    final chapters = _chaptersForTab(_showExtra);
    final current = widget.player.currentChapter;
    if (current == null) return 0;
    final index = chapters.indexWhere((chapter) => chapter.id == current.id);
    if (index < 0) return 0;
    return index ~/ _chaptersPerGroup;
  }

  bool _chapterLooksExtra(Chapter? chapter) {
    if (chapter == null) return false;
    return chapter.isExtra ||
        RegExp(r'番外|SP|Extra', caseSensitive: false).hasMatch(chapter.title);
  }

  List<Chapter> _chaptersForTab(bool extra) {
    final chapters = widget.player.chapters
        .where((chapter) => _chapterLooksExtra(chapter) == extra)
        .toList(growable: false);
    return chapters;
  }

  List<_ChapterPageGroup> _groupsFor(List<Chapter> chapters) {
    final groups = <_ChapterPageGroup>[];
    for (var i = 0; i < chapters.length; i += _chaptersPerGroup) {
      final end = (i + _chaptersPerGroup).clamp(0, chapters.length);
      final slice = chapters.sublist(i, end);
      groups.add(_ChapterPageGroup(
        start: i + 1,
        end: end,
        chapters: slice,
      ));
    }
    return groups;
  }

  List<Chapter> _visibleGroupChapters(_ChapterPageGroup group) {
    return _ascending ? group.chapters : group.chapters.reversed.toList();
  }

  String? _progressText(Chapter chapter) {
    final position = chapter.progressPosition;
    if (position == null || chapter.duration <= 0) return null;
    final percent = ((position / chapter.duration) * 100).floor();
    if (percent <= 0) return null;
    if (percent >= 95) return '已播完';
    return '已播$percent%';
  }

  Future<void> _downloadChapter(Chapter chapter) async {
    final book = widget.player.currentBook;
    if (book == null) return;
    final downloadState = AppScope.downloadOf(context);
    if (downloadState.hasChapter(chapter.id)) return;
    final task = downloadState.taskForChapter(chapter.id);
    if (task != null) {
      if (task.status == DownloadStatus.paused ||
          task.status == DownloadStatus.failed) {
        await downloadState.resumeTask(chapter.id);
      }
      return;
    }
    downloadState.queueChapter(book, chapter);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.player,
      builder: (context, _) {
        final book = widget.player.currentBook;
        if (book == null || widget.player.chapters.isEmpty) {
          return const SizedBox.shrink();
        }

        final mainChapters = _chaptersForTab(false);
        final extraChapters = _chaptersForTab(true);
        final downloadState = AppScope.downloadOf(context);
        final activeExtra = _showExtra && extraChapters.isNotEmpty;
        final currentChapters = activeExtra ? extraChapters : mainChapters;
        final groups = _groupsFor(currentChapters);
        var groupIndex = _groupIndex;
        if (groupIndex < 0) groupIndex = 0;
        if (groups.isNotEmpty && groupIndex >= groups.length) {
          groupIndex = groups.length - 1;
        }
        final activeGroup = groups.isEmpty ? null : groups[groupIndex];
        final activeChapters = activeGroup == null
            ? const <Chapter>[]
            : _visibleGroupChapters(activeGroup);
        final accent = widget.themeColor ?? AppColors.primary600;
        final onAccent =
            widget.themeColor != null && _isPlayerThemeLight(widget.themeColor!)
                ? AppColors.slate600
                : Colors.white;
        final height = MediaQuery.sizeOf(context).height * 0.8;

        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 672),
              child: SizedBox(
                height: height.clamp(460, 720),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border.all(color: context.faintBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(context.isDark ? 0.5 : 0.18),
                        blurRadius: 34,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 18, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.queue_music_rounded,
                                    color: AppColors.primary600,
                                    size: 25,
                                  ),
                                  const SizedBox(width: 9),
                                  const Text(
                                    '章节列表',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (extraChapters.isNotEmpty) ...[
                                    const SizedBox(width: 14),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: context.isDark
                                            ? AppColors.slate800
                                            : AppColors.slate100,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          _ChapterTabButton(
                                            label:
                                                '正文 (${mainChapters.length})',
                                            selected: !activeExtra,
                                            accent: accent,
                                            onAccent: onAccent,
                                            onTap: () => setState(() {
                                              _showExtra = false;
                                              _groupIndex = 0;
                                              _ensureCurrentVisible();
                                            }),
                                          ),
                                          _ChapterTabButton(
                                            label:
                                                '番外 (${extraChapters.length})',
                                            selected: activeExtra,
                                            accent: accent,
                                            onAccent: onAccent,
                                            onTap: () => setState(() {
                                              _showExtra = true;
                                              _groupIndex = 0;
                                              _ensureCurrentVisible();
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 10),
                                  _ChapterSortButton(
                                    ascending: _ascending,
                                    onTap: () => setState(() {
                                      _ascending = !_ascending;
                                      _ensureCurrentVisible();
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon:
                                  const Icon(Icons.keyboard_arrow_down_rounded),
                              tooltip: '关闭',
                            ),
                          ],
                        ),
                      ),
                      if (groups.length > 1)
                        Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: context.isDark
                                ? AppColors.slate800.withOpacity(0.5)
                                : AppColors.slate50,
                            border: Border.symmetric(
                              horizontal:
                                  BorderSide(color: context.faintBorder),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var index = 0;
                                    index < groups.length;
                                    index++) ...[
                                  Builder(
                                    builder: (context) {
                                      final group = groups[index];
                                      final selected = groupIndex == index;
                                      return ChoiceChip(
                                        key: _groupKeys.putIfAbsent(
                                          index,
                                          () => GlobalKey(),
                                        ),
                                        selected: selected,
                                        showCheckmark: false,
                                        label: Text(
                                          '第 ${group.start}-${group.end} 章',
                                        ),
                                        labelStyle: TextStyle(
                                          color: selected
                                              ? onAccent
                                              : context.mutedText,
                                        ),
                                        selectedColor: accent,
                                        backgroundColor: context.cardColor,
                                        side: BorderSide(
                                          color: selected
                                              ? accent
                                              : context.faintBorder,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        onSelected: (_) {
                                          setState(() {
                                            _groupIndex = index;
                                            _ensureCurrentVisible();
                                          });
                                        },
                                      );
                                    },
                                  ),
                                  if (index != groups.length - 1)
                                    const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: activeGroup == null
                            ? Center(
                                child: Text(
                                  activeExtra ? '暂无番外章节' : '暂无正文章节',
                                  style: TextStyle(color: context.mutedText),
                                ),
                              )
                            : SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 14, 14, 18),
                                child: Column(
                                  children: [
                                    for (var index = 0;
                                        index < activeChapters.length;
                                        index++) ...[
                                      Builder(
                                        builder: (context) {
                                          final chapter = activeChapters[index];
                                          final originalIndex = activeGroup
                                              .chapters
                                              .indexOf(chapter);
                                          final actualIndex =
                                              groupIndex * _chaptersPerGroup +
                                                  (originalIndex < 0
                                                      ? index
                                                      : originalIndex);
                                          return KeyedSubtree(
                                            key: _chapterKeys.putIfAbsent(
                                              chapter.id,
                                              () => GlobalKey(),
                                            ),
                                            child: _ChapterSheetTile(
                                              chapter: chapter,
                                              fallbackIndex: actualIndex + 1,
                                              active: chapter.id ==
                                                  widget.player.currentChapter
                                                      ?.id,
                                              isPlaying:
                                                  widget.player.isPlaying,
                                              progressText:
                                                  _progressText(chapter),
                                              downloaded: downloadState
                                                  .hasChapter(chapter.id),
                                              task: downloadState
                                                  .taskForChapter(chapter.id),
                                              accent: accent,
                                              onAccent: onAccent,
                                              onTap: () async {
                                                await widget.player.playChapter(
                                                  book,
                                                  widget.player.chapters,
                                                  chapter,
                                                );
                                                if (context.mounted) {
                                                  Navigator.pop(context);
                                                }
                                              },
                                              onDownload: () =>
                                                  _downloadChapter(
                                                chapter,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (index != activeChapters.length - 1)
                                        const SizedBox(height: 8),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChapterTabButton extends StatelessWidget {
  const _ChapterTabButton({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onAccent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color onAccent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? context.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : context.mutedText,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ChapterSortButton extends StatelessWidget {
  const _ChapterSortButton({
    required this.ascending,
    required this.onTap,
  });

  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: context.secondaryText,
        backgroundColor:
            context.isDark ? AppColors.slate800 : AppColors.slate100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(
        ascending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
        size: 17,
      ),
      label: Text(ascending ? '正序' : '逆序'),
    );
  }
}

class _ChapterSheetTile extends StatelessWidget {
  const _ChapterSheetTile({
    required this.chapter,
    required this.fallbackIndex,
    required this.active,
    required this.isPlaying,
    required this.progressText,
    required this.downloaded,
    required this.task,
    required this.accent,
    required this.onAccent,
    required this.onTap,
    required this.onDownload,
  });

  final Chapter chapter;
  final int fallbackIndex;
  final bool active;
  final bool isPlaying;
  final String? progressText;
  final bool downloaded;
  final DownloadTask? task;
  final Color accent;
  final Color onAccent;
  final Future<void> Function() onTap;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Material(
      color: active
          ? accent.withOpacity(context.isDark ? 0.16 : 0.1)
          : context.cardColor,
      borderRadius: BorderRadius.circular(compact ? 10 : 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 10 : 16),
        child: Container(
          padding: EdgeInsets.all(compact ? 8 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 10 : 16),
            border: Border.all(
              color: active ? accent.withOpacity(0.3) : context.faintBorder,
            ),
          ),
          child: Row(
            children: [
              if (!compact) ...[
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? accent
                        : (context.isDark
                            ? AppColors.slate800
                            : AppColors.slate100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${chapter.chapterIndex == 0 ? fallbackIndex : chapter.chapterIndex}',
                    style: TextStyle(
                      color: active ? onAccent : context.mutedText,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? accent : null,
                        fontSize: compact ? 14 : 16,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: context.mutedText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatDurationShort(chapter.duration),
                              style: TextStyle(
                                color: context.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (progressText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: progressText == '已播完'
                                  ? const Color(0xffdcfce7)
                                  : AppColors.primary50,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              progressText!,
                              style: TextStyle(
                                color: progressText == '已播完'
                                    ? const Color(0xff22c55e)
                                    : AppColors.primary600,
                                fontSize: compact ? 10 : 11,
                              ),
                            ),
                          ),
                        _ChapterSheetDownloadMark(
                          compact: compact,
                          downloaded: downloaded,
                          task: task,
                          accent: accent,
                          onDownload: onDownload,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (active && isPlaying) ...[
                SizedBox(width: compact ? 6 : 10),
                _PlayingBars(color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterSheetDownloadMark extends StatelessWidget {
  const _ChapterSheetDownloadMark({
    required this.compact,
    required this.downloaded,
    required this.task,
    required this.accent,
    required this.onDownload,
  });

  final bool compact;
  final bool downloaded;
  final DownloadTask? task;
  final Color accent;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    if (downloaded) {
      return _iconMark(
        icon: Icons.check_rounded,
        color: AppColors.primary600,
        tooltip: '已下载',
      );
    }

    final task = this.task;
    if (task == null) {
      return _iconMark(
        icon: Icons.download_rounded,
        color: accent,
        tooltip: '下载章节',
        onTap: onDownload,
      );
    }
    final color = switch (task.status) {
      DownloadStatus.downloading => AppColors.primary600,
      DownloadStatus.paused => Colors.orange,
      DownloadStatus.failed => Colors.red,
      DownloadStatus.completed => AppColors.primary600,
      DownloadStatus.queued => AppColors.slate500,
    };
    final icon = switch (task.status) {
      DownloadStatus.downloading => Icons.downloading_rounded,
      DownloadStatus.paused => Icons.pause_rounded,
      DownloadStatus.failed => Icons.error_outline_rounded,
      DownloadStatus.completed => Icons.check_rounded,
      DownloadStatus.queued => Icons.schedule_rounded,
    };
    final label = task.status == DownloadStatus.downloading
        ? '${(task.progress.clamp(0, 1) * 100).round()}%'
        : task.status.label;

    return _iconMark(
      icon: icon,
      color: color,
      tooltip: label,
    );
  }

  Widget _iconMark({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    final size = compact ? 20.0 : 22.0;
    final child = SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          icon,
          size: compact ? 15 : 16,
          color: color,
        ),
      ),
    );
    return Tooltip(
      message: tooltip,
      child: onTap == null
          ? child
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: child,
            ),
    );
  }
}

class _PlayingBars extends StatefulWidget {
  const _PlayingBars({required this.color});

  final Color color;

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _height(double offset) {
    final phase = (_controller.value + offset) % 1;
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 7 + wave * 13;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 19,
          height: 22,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final offset in const [0.0, 0.22, 0.44])
                Container(
                  width: 4,
                  height: _height(offset),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ScrollingPlayerTitle extends StatefulWidget {
  const _ScrollingPlayerTitle({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  State<_ScrollingPlayerTitle> createState() => _ScrollingPlayerTitleState();
}

class _ScrollingPlayerTitleState extends State<_ScrollingPlayerTitle>
    with SingleTickerProviderStateMixin {
  static const _gap = 44.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  );
  String? _lastText;
  double? _lastWidth;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: direction,
        )..layout();
        final textWidth = painter.width;
        final overflowing = textWidth > maxWidth;

        if (!overflowing || maxWidth <= 0) {
          if (_controller.isAnimating) _controller.stop();
          _lastText = widget.text;
          _lastWidth = maxWidth;
          return Center(
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: style,
            ),
          );
        }

        final distance = textWidth + _gap;
        if (_lastText != widget.text || _lastWidth != maxWidth) {
          _lastText = widget.text;
          _lastWidth = maxWidth;
          _controller
            ..duration = Duration(
              milliseconds: (distance * 38).round().clamp(5200, 15000),
            )
            ..reset()
            ..repeat();
        } else if (!_controller.isAnimating) {
          _controller.repeat();
        }

        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(-distance * _controller.value, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.text, maxLines: 1, style: style),
                  const SizedBox(width: _gap),
                  Text(widget.text, maxLines: 1, style: style),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.onTapWithContext,
    this.active = false,
  }) : assert(onTap != null || onTapWithContext != null);

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Future<void> Function(BuildContext context)? onTapWithContext;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primary600;
    return InkWell(
      onTap: () {
        final handler = onTapWithContext;
        if (handler != null) {
          handler(context);
        } else {
          onTap?.call();
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 36,
              child: Center(
                child: Icon(
                  icon,
                  size: 19,
                  color: active ? activeColor : context.mutedText,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? activeColor : context.tertiaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedDownloadAction {
  const _ExpandedDownloadAction({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;
}

class _SeekButton extends StatelessWidget {
  const _SeekButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onPressed(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 31, color: context.mutedText),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.mutedText,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
