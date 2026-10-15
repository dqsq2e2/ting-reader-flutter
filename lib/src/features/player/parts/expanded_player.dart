part of '../mini_player.dart';

class _ExpandedPlayer extends StatefulWidget {
  const _ExpandedPlayer({required this.player});

  final PlayerState player;

  @override
  State<_ExpandedPlayer> createState() => _ExpandedPlayerState();
}

class _ExpandedPlayerState extends State<_ExpandedPlayer> {
  int? get _sleepRemainingSeconds => widget.player.sleepRemainingSeconds;
  // 按集数睡眠的状态由 PlayerState 管理（避免 widget 销毁丢失）。
  CoverShape _coverShape = CoverShape.square;
  double? _dragSeekValue;

  void _updateMenuState(VoidCallback change) => setState(change);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coverShape = coverShapeFromAppSettings(AppScope.appOf(context).settings);
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

  Size _expandedCoverBounds({
    required Size screenSize,
    required EdgeInsets safePadding,
    required double bottomContentPadding,
    required bool tightControls,
    required double mainButtonSize,
    required bool hasError,
  }) {
    final portraitPhone =
        screenSize.height > screenSize.width && screenSize.width < 600;
    final squareMaxSize = tightControls ? 300.0 : 340.0;
    final baseMaxWidth = _coverShape == CoverShape.square
        ? squareMaxSize
        : (tightControls ? 280.0 : 320.0);
    // Tall artwork shares the square cover's height budget on portrait phones.
    final baseMaxHeight = _coverShape == CoverShape.square
        ? squareMaxSize
        : (portraitPhone ? squareMaxSize : (tightControls ? 340.0 : 390.0));
    if (!portraitPhone) return Size(baseMaxWidth, baseMaxHeight);

    final afterCoverGap = tightControls ? 20.0 : 24.0;
    final titleHeight = tightControls ? 32.0 : 36.0;
    final quickActionGap = tightControls ? 16.0 : 20.0;
    final sliderGap = tightControls ? 16.0 : 22.0;
    final controlsGap = tightControls ? 20.0 : 26.0;
    final errorHeight = hasError ? 72.0 : 0.0;
    final reservedHeight = safePadding.top +
        safePadding.bottom +
        18 +
        38 +
        28 +
        afterCoverGap +
        titleHeight +
        9 +
        18 +
        errorHeight +
        quickActionGap +
        63 +
        sliderGap +
        48 +
        42 +
        controlsGap +
        mainButtonSize +
        bottomContentPadding;
    final availableCoverHeight = screenSize.height - reservedHeight;
    final minCoverHeight = _coverShape == CoverShape.square ? 132.0 : 156.0;
    final coverMaxHeight =
        availableCoverHeight.clamp(minCoverHeight, baseMaxHeight).toDouble();
    return Size(baseMaxWidth, coverMaxHeight);
  }

  double _expandedBottomContentPadding({
    required Size screenSize,
    required EdgeInsets safePadding,
  }) {
    final portraitPhone =
        screenSize.height > screenSize.width && screenSize.width < 600;
    if (!portraitPhone) return 28.0;

    const referencePortraitHeight = 900.0;
    const referenceBottomPadding = 28.0;
    final heightRatio =
        (screenSize.height / referencePortraitHeight).clamp(0.0, 1.0);
    final scaledPadding = (referenceBottomPadding * heightRatio)
        .clamp(12.0, referenceBottomPadding)
        .toDouble();
    final safeAreaAdjustment = safePadding.bottom * 0.65;
    return (scaledPadding - safeAreaAdjustment)
        .clamp(8.0, referenceBottomPadding)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final mediaPadding = MediaQuery.paddingOf(context);

    return AnimatedBuilder(
      animation: widget.player,
      builder: (context, _) {
        final player = widget.player;
        final errorValue = player.error;
        final remaining = _sleepRemainingSeconds;
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
        final themeColor = effectiveBookThemeColor(book.themeColor);
        final accentColor = themeColor ?? AppColors.primary600;
        final accentTextColor =
            themeColor != null && isBookThemeLight(themeColor)
                ? AppColors.slate600
                : Colors.white;
        final coverUrl = bookCoverUrl(appState, book);
        final backgroundColor = context.isDark
            ? AppColors.slate950
            : Color.alphaBlend(
                (themeColor ?? AppColors.primary600).withValues(alpha: 0.08),
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
        final bottomContentPadding = _expandedBottomContentPadding(
          screenSize: size,
          safePadding: mediaPadding,
        );
        final coverBounds = _expandedCoverBounds(
          screenSize: size,
          safePadding: mediaPadding,
          bottomContentPadding: bottomContentPadding,
          tightControls: tightControls,
          mainButtonSize: mainButtonSize,
          hasError: errorValue != null,
        );
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
                              AppColors.slate950.withValues(alpha: 0.92),
                              AppColors.slate950.withValues(alpha: 0.86),
                              AppColors.slate950.withValues(alpha: 0.96),
                            ]
                          : [
                              backgroundColor.withValues(alpha: 0.90),
                              backgroundColor.withValues(alpha: 0.72),
                              backgroundColor.withValues(alpha: 0.94),
                            ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.fromLTRB(22, 18, 22, bottomContentPadding),
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
                                        localizedChapterTitle(context, chapter),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        localizedBookTitle(context, book),
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
                              maxWidth: coverBounds.width,
                              maxHeight: coverBounds.height,
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
                                      color: Colors.black.withValues(
                                          alpha: context.isDark ? 0.44 : 0.18),
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
                            child: ScrollingText(
                              text: localizedChapterTitle(context, chapter),
                              style: TextStyle(
                                fontSize: tightControls ? 22 : 24,
                                height: 1.18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            book.narrator ??
                                book.author ??
                                localizedBookTitle(context, book),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.mutedText,
                              fontSize: 14,
                            ),
                          ),
                          if (errorValue != null) ...[
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
                                errorValue,
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
                                  onTapWithContext: (buttonContext) =>
                                      _openSpeedSheet(player, buttonContext),
                                ),
                              ),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.bookmark_add_outlined,
                                  label: context.localeText('书签', 'Bookmarks'),
                                  onTap: () => _openBookmarks(player),
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
                                  label: remaining != null
                                      ? _formatSleepTime(remaining)
                                      : player.sleepEpisodesRemaining != null
                                          ? context.localeText(
                                              '${player.sleepEpisodesRemaining} 集',
                                              '${player.sleepEpisodesRemaining} ep')
                                          : context.localeText('定时', 'Timer'),
                                  active: remaining != null ||
                                      player.sleepEpisodesRemaining != null,
                                  onTapWithContext: (buttonContext) =>
                                      _openSleepTimerSheet(
                                          player, buttonContext),
                                ),
                              ),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.list_alt_rounded,
                                  label: context.localeText('选集', 'Chapters'),
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
                              overlayColor: accentColor.withValues(alpha: 0.16),
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
