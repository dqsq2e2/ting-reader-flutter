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
    await showPlayerChapters(context, player);
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

        // 横屏大屏使用左右分栏；竖屏/窄屏保持原来的单列布局。
        final wideLayout = size.width >= 700 && size.width > size.height;
        final wideCompact = wideLayout && size.height < 540;

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

        final transportMainSize =
            wideLayout ? (wideCompact ? 72.0 : 88.0) : mainButtonSize;
        final transportMainIcon =
            wideLayout ? (wideCompact ? 34.0 : 40.0) : mainIconSize;
        final transportSideSize =
            wideLayout ? (wideCompact ? 46.0 : 54.0) : sideButtonSize;
        final transportSideIcon =
            wideLayout ? (wideCompact ? 24.0 : 28.0) : sideIconSize;
        final transportGap =
            wideLayout ? (wideCompact ? 18.0 : 28.0) : controlGap;

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
        final wideCoverMaxWidth =
            (size.width * 0.40).clamp(220.0, 560.0).toDouble();
        final wideCoverMaxHeight = (size.height * (wideCompact ? 0.56 : 0.70))
            .clamp(200.0, 640.0)
            .toDouble();
        final coverMaxWidth =
            wideLayout ? wideCoverMaxWidth : coverBounds.width;
        final coverMaxHeight =
            wideLayout ? wideCoverMaxHeight : coverBounds.height;
        final titleFontSize = wideLayout
            ? (size.width >= 1200 ? 34.0 : (wideCompact ? 24.0 : 30.0))
            : (tightControls ? 22.0 : 24.0);
        final titleBoxHeight = wideLayout
            ? (wideCompact ? 62.0 : 86.0)
            : (tightControls ? 32.0 : 36.0);
        final blockGap = wideLayout
            ? (wideCompact ? 16.0 : 24.0)
            : (tightControls ? 16.0 : 20.0);

        final authorName = book.author?.trim();
        final narratorName = book.narrator?.trim();
        final performerParts = <String>[
          if (authorName != null && authorName.isNotEmpty) authorName,
          if (narratorName != null && narratorName.isNotEmpty) narratorName,
        ];
        final authorLine = performerParts.isEmpty
            ? context.localeText('未知作者', 'Unknown author')
            : performerParts.join(' / ');

        final headerRow = Row(
          children: [
            _IconCircle(
              icon: Icons.keyboard_arrow_down_rounded,
              ghost: true,
              onPressed: () async => player.setExpanded(false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Text(
                      localizedBookTitle(context, book),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authorLine,
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
              onPressed: () async => _openPlaybackSettings(player, book),
            ),
          ],
        );

        final coverWidget = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: coverMaxWidth,
            maxHeight: coverMaxHeight,
          ),
          child: AspectRatio(
            aspectRatio: coverAspectRatio(_coverShape),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(wideLayout ? 36 : 30),
                border: Border.all(
                  color: context.isDark ? AppColors.slate800 : Colors.white,
                  width: wideLayout ? 8 : 7,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: context.isDark ? 0.44 : 0.18),
                    blurRadius: wideLayout ? 46 : 34,
                    offset: const Offset(0, 22),
                  ),
                ],
              ),
              child: CoverImage(
                url: coverUrl,
                radius: wideLayout ? 28 : 24,
              ),
            ),
          ),
        );

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: titleBoxHeight,
              width: double.infinity,
              child: wideLayout
                  ? Align(
                      alignment: Alignment.center,
                      child: Text(
                        localizedChapterTitle(context, chapter),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          height: 1.18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : ScrollingText(
                      text: localizedChapterTitle(context, chapter),
                      style: TextStyle(
                        fontSize: titleFontSize,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                      ),
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
                  border: Border.all(color: const Color(0xffffcdd5)),
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
          ],
        );

        final quickActions = Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.bolt_rounded,
                label: _formatPlaybackSpeed(player.playbackSpeed),
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
                active:
                    remaining != null || player.sleepEpisodesRemaining != null,
                onTapWithContext: (buttonContext) =>
                    _openSleepTimerSheet(player, buttonContext),
              ),
            ),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.list_alt_rounded,
                label: context.localeText('选集', 'Chapters'),
                onTap: () => _openChapterSheet(context, player, themeColor),
              ),
            ),
          ],
        );

        final progressBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: wideLayout ? 7 : 6,
                activeTrackColor: accentColor,
                inactiveTrackColor:
                    context.isDark ? AppColors.slate800 : AppColors.slate200,
                thumbColor: accentColor,
                overlayColor: accentColor.withValues(alpha: 0.16),
              ),
              child: Slider(
                min: 0,
                max: sliderMax,
                value: sliderValue,
                onChanged: (value) => setState(() => _dragSeekValue = value),
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
                    style: TextStyle(color: context.mutedText),
                  ),
                  const Spacer(),
                  Text(
                    formatDurationShort(maxDuration),
                    style: TextStyle(color: context.mutedText),
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
          ],
        );

        final transportRow = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconCircle(
              icon: Icons.skip_previous_rounded,
              onPressed: player.previousChapter,
              diameter: transportSideSize,
              iconSize: transportSideIcon,
            ),
            SizedBox(width: transportGap),
            _IconCircle(
              filled: true,
              icon: player.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onPressed: player.togglePlay,
              diameter: transportMainSize,
              iconSize: transportMainIcon,
              fillColor: accentColor,
              filledIconColor: accentTextColor,
            ),
            SizedBox(width: transportGap),
            _IconCircle(
              icon: Icons.skip_next_rounded,
              onPressed: player.nextChapter,
              diameter: transportSideSize,
              iconSize: transportSideIcon,
            ),
          ],
        );

        final controlsBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            quickActions,
            SizedBox(
              height: wideLayout
                  ? (wideCompact ? 14 : 20)
                  : (tightControls ? 16 : 22),
            ),
            progressBlock,
            SizedBox(
              height: wideLayout
                  ? (wideCompact ? 16 : 24)
                  : (tightControls ? 20 : 26),
            ),
            transportRow,
          ],
        );

        final body = wideLayout
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: Center(child: coverWidget),
                  ),
                  SizedBox(width: wideCompact ? 32 : 56),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        titleBlock,
                        SizedBox(height: blockGap),
                        controlsBlock,
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  coverWidget,
                  SizedBox(height: tightControls ? 20 : 24),
                  titleBlock,
                  SizedBox(height: blockGap),
                  controlsBlock,
                ],
              );

        final content = Column(
          children: [
            headerRow,
            SizedBox(height: wideLayout ? (wideCompact ? 16 : 28) : 28),
            body,
          ],
        );

        final horizontalPadding =
            (size.width * 0.045).clamp(20.0, 64.0).toDouble();
        final verticalTopPadding = wideLayout ? 20.0 : 18.0;

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
                child: LayoutBuilder(
                  builder: (context, viewport) {
                    final horizontal = wideLayout ? horizontalPadding : 22.0;
                    final bottom = wideLayout ? 28.0 : bottomContentPadding;
                    final minHeight =
                        (viewport.maxHeight - verticalTopPadding - bottom)
                            .clamp(0.0, double.infinity)
                            .toDouble();
                    final scrollPadding = EdgeInsets.fromLTRB(
                      horizontal,
                      verticalTopPadding,
                      horizontal,
                      bottom,
                    );
                    if (wideLayout) {
                      // Keep the top bar anchored while centering the two
                      // columns in the remaining viewport.
                      final bodyMinHeight =
                          (minHeight - 38 - 28).clamp(0.0, double.infinity);
                      return SingleChildScrollView(
                        padding: scrollPadding,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1440),
                            child: Column(
                              children: [
                                headerRow,
                                const SizedBox(height: 28),
                                ConstrainedBox(
                                  constraints:
                                      BoxConstraints(minHeight: bodyMinHeight),
                                  child: Center(child: body),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      padding: scrollPadding,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: content,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
