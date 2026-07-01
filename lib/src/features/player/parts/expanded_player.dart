part of '../mini_player.dart';

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
      _showPlayerMessage(context.localeText(
          '当前章节已下载', 'Current chapter is already downloaded'));
      return;
    }
    final task = downloadState.taskForChapter(chapter.id);
    if (task != null) {
      if (task.status == DownloadStatus.paused ||
          task.status == DownloadStatus.failed) {
        final resumedMessage = context.localeText(
            '已恢复下载：${chapter.title}', 'Resumed download: ${chapter.title}');
        await downloadState.resumeTask(chapter.id);
        _showPlayerMessage(resumedMessage);
      } else {
        final status = task.status.labelForLocale(context.isEnglishLocale);
        _showPlayerMessage(context.localeText(
            '下载任务已存在：$status', 'Download task already exists: $status'));
      }
      return;
    }

    try {
      downloadState.queueChapter(book, chapter);
      _showPlayerMessage(context.localeText('已加入下载队列：${chapter.title}',
          'Added to download queue: ${chapter.title}'));
    } catch (err) {
      _showPlayerMessage(
          context.localeText('加入下载失败：$err', 'Failed to add download: $err'));
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
      return _ExpandedDownloadAction(
        icon: Icons.download_done_rounded,
        label: context.localeText('已下载', 'Downloaded'),
        active: true,
      );
    }
    final task = downloadState.taskForChapter(chapter.id);
    if (task == null) {
      return _ExpandedDownloadAction(
        icon: Icons.download_rounded,
        label: context.localeText('下载', 'Download'),
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
          : task.status.labelForLocale(context.isEnglishLocale),
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
      barrierLabel: context.l10n.commonClose,
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
                    color: Colors.black
                        .withValues(alpha: context.isDark ? 0.48 : 0.18),
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
                    tooltip: nextVolume <= 0
                        ? context.localeText('取消静音', 'Unmute')
                        : context.localeText('静音', 'Mute'),
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
                    color: Colors.black
                        .withValues(alpha: context.isDark ? 0.48 : 0.18),
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
                      context.localeText('睡眠定时', 'Sleep Timer'),
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
                                child: Text(context.localeText(
                                    '${row[i]} 分钟', '${row[i]} min')),
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
                          ? AppColors.slate900.withValues(alpha: 0.5)
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
                            decoration: InputDecoration(
                              isDense: true,
                              hintText:
                                  context.localeText('自定义分钟', 'Custom minutes'),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
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
                          child: Text(context.localeText('开启', 'Start')),
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
                            ? const Color(0xff7f1d1d).withValues(alpha: 0.22)
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
                      child: Text(context.localeText('取消定时', 'Cancel Timer')),
                    ),
                  ),
                  if (_sleepRemainingSeconds != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.localeText(
                          '剩余 ${_formatSleepTime(_sleepRemainingSeconds!)}',
                          'Remaining ${_formatSleepTime(_sleepRemainingSeconds!)}'),
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
      barrierLabel: context.localeText('播放设置', 'Playback Settings'),
      barrierColor: Colors.black.withValues(alpha: 0.6),
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
                      color: Colors.black
                          .withValues(alpha: context.isDark ? 0.55 : 0.2),
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
                        Text(
                          context.localeText('播放设置', 'Playback Settings'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                          color: context.mutedText,
                          tooltip: context.l10n.commonClose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _PlaybackSettingField(
                      controller: introController,
                      icon: Icons.skip_previous_rounded,
                      label: context.localeText('跳过片头 (秒)', 'Skip Intro (sec)'),
                      hint: context.localeText('例如: 30', 'For example: 30'),
                    ),
                    const SizedBox(height: 18),
                    _PlaybackSettingField(
                      controller: outroController,
                      icon: Icons.skip_next_rounded,
                      label: context.localeText('跳过片尾 (秒)', 'Skip Outro (sec)'),
                      hint: context.localeText('例如: 15', 'For example: 15'),
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
                            child: Text(context.l10n.commonCancel),
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
                                if (!hostContext.mounted) return;
                                ScaffoldMessenger.of(hostContext).showSnackBar(
                                  SnackBar(
                                      content: Text(hostContext.localeText(
                                          '播放设置已保存',
                                          'Playback settings saved'))),
                                );
                              } catch (err) {
                                if (!mounted) return;
                                if (!hostContext.mounted) return;
                                ScaffoldMessenger.of(hostContext).showSnackBar(
                                  SnackBar(
                                      content: Text(hostContext.localeText(
                                          '保存失败：$err', 'Save failed: $err'))),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              elevation: 8,
                              shadowColor:
                                  AppColors.primary500.withValues(alpha: 0.3),
                              backgroundColor: AppColors.primary600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 20),
                            label: Text(context.localeText('保存', 'Save')),
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

  Size _expandedCoverBounds({
    required Size screenSize,
    required EdgeInsets safePadding,
    required double bottomContentPadding,
    required bool tightControls,
    required double mainButtonSize,
    required bool hasError,
  }) {
    final baseMaxWidth = _coverShape == CoverShape.square
        ? (tightControls ? 300.0 : 340.0)
        : (tightControls ? 280.0 : 320.0);
    final baseMaxHeight = _coverShape == CoverShape.square
        ? baseMaxWidth
        : (tightControls ? 340.0 : 390.0);
    final portraitPhone =
        screenSize.height > screenSize.width && screenSize.width < 600;
    if (!portraitPhone) return Size(baseMaxWidth, baseMaxHeight);

    // Honor 90 Pro is the reference device where the previous cover size fits.
    const referencePortraitHeight = 900.0;
    if (screenSize.height >= referencePortraitHeight) {
      return Size(baseMaxWidth, baseMaxHeight);
    }

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
          hasError: player.error != null,
        );
        final readerExtensionContext = <String, Object?>{
          'book_id': book.id,
          'book_title': book.title,
          'book_path': book.path,
          'chapter_id': chapter.id,
          'chapter_title': chapter.title,
          'chapter_path': chapter.path,
          'position': player.currentTime,
          'duration': maxDuration,
          'playback_state': player.isPlaying ? 'playing' : 'paused',
        };

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
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PluginExtensionSlot(
                                  slot: ClientExtensionSlot.readerToolbarAction,
                                  extensionContext: readerExtensionContext,
                                ),
                                PluginExtensionSlot(
                                  slot: ClientExtensionSlot.readerSidePanel,
                                  extensionContext: readerExtensionContext,
                                  padding: const EdgeInsets.only(left: 6),
                                ),
                              ],
                            ),
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
                            child: _ScrollingPlayerTitle(
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
                                      ? context.localeText('静音', 'Muted')
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
                                      ? context.localeText('定时', 'Timer')
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
