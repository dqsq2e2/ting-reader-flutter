part of '../mini_player.dart';

extension _PlaybackMenus on _ExpandedPlayerState {
  Future<void> _openSpeedSheet(
    PlayerState player,
    BuildContext anchorContext,
  ) async {
    var speed = player.playbackSpeed.clamp(0.5, 3.0).toDouble();
    await _showAnchoredPopover(
      anchorContext: anchorContext,
      width: 252,
      estimatedHeight: 96,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.faintBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: context.isDark ? 0.48 : 0.18),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('0.5x',
                      style: TextStyle(color: context.mutedText, fontSize: 12)),
                  const Spacer(),
                  Text('${speed.toStringAsFixed(1)}x',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('3.0x',
                      style: TextStyle(color: context.mutedText, fontSize: 12)),
                ],
              ),
              Slider(
                min: 0.5,
                max: 3,
                divisions: 25,
                value: speed,
                activeColor: AppColors.primary600,
                onChanged: (value) {
                  final normalized = (value * 10).round() / 10;
                  setSheetState(() => speed = normalized);
                  player.setSpeed(normalized);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBookmarks(PlayerState player) async {
    final book = player.currentBook;
    if (book == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => const BookBookmarkDialog(),
    );
  }

  Future<void> _downloadCurrentChapter(PlayerState player) async {
    final book = player.currentBook;
    final chapter = player.currentChapter;
    if (book == null || chapter == null) return;
    try {
      final result =
          await AppScope.downloadOf(context).requestChapter(book, chapter);
      if (!mounted) return;
      _showPlayerMessage(
          result.messageForLocale(context.isEnglishLocale, chapter.title));
    } catch (error) {
      if (mounted) {
        _showPlayerMessage(context.localeText(
            '加入下载失败：$error', 'Failed to add download: $error'));
      }
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
      icon: task.status.downloadIcon(),
      label: task.downloadLabel(context.isEnglishLocale),
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

  Future<void> _startSleepTimer(PlayerState player, int minutes) async {
    player.startSleepTimer(minutes);
  }

  void _cancelSleepTimer() => widget.player.cancelSleepTimer();
  void _startEpisodeSleepTimer(int episodes) =>
      widget.player.startEpisodeSleepTimer(episodes);

  Future<void> _openSleepTimerSheet(
    PlayerState player,
    BuildContext anchorContext,
  ) async {
    final controller = TextEditingController();
    final episodeController = TextEditingController();
    // 0 = 按分钟，1 = 按集数；有集数定时在跑时默认落在集数页。
    var sheetTab = player.sleepEpisodesRemaining != null ? 1 : 0;
    await _showAnchoredPopover(
      anchorContext: anchorContext,
      width: 216,
      estimatedHeight: 252,
      alignRight: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final remaining = _sleepRemainingSeconds;
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
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? AppColors.slate800
                          : AppColors.slate100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ChapterTabButton(
                            label: context.localeText('按分钟', 'Minutes'),
                            selected: sheetTab == 0,
                            accent: AppColors.primary600,
                            onAccent: Colors.white,
                            fontWeight: FontWeight.w400,
                            onTap: () => setSheetState(() => sheetTab = 0),
                          ),
                        ),
                        Expanded(
                          child: _ChapterTabButton(
                            label: context.localeText('按集数', 'Episodes'),
                            selected: sheetTab == 1,
                            accent: AppColors.primary600,
                            onAccent: Colors.white,
                            fontWeight: FontWeight.w400,
                            onTap: () => setSheetState(() => sheetTab = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (sheetTab == 0) ...[
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
                                    side:
                                        BorderSide(color: context.faintBorder),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: EdgeInsets.zero,
                                    textStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  child: Text(
                                    context.localeText(
                                        '${row[i]} 分钟', '${row[i]} min'),
                                    maxLines: 1,
                                  ),
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
                      height: 40,
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
                          SizedBox(
                            width: 80,
                            height: 32,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: context.localeText(
                                    '自定义分钟', 'Custom minutes'),
                                hintStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ),
                          const Spacer(),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            child: Text(context.localeText('开启', 'Start')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (sheetTab == 1) ...[
                    for (final row in const [
                      [1, 2],
                      [3, 4],
                    ]) ...[
                      Row(
                        children: [
                          for (var i = 0; i < row.length; i++) ...[
                            if (i > 0) const SizedBox(width: 7),
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: OutlinedButton(
                                  onPressed: () {
                                    _startEpisodeSleepTimer(row[i]);
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: context.mutedText,
                                    side:
                                        BorderSide(color: context.faintBorder),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: EdgeInsets.zero,
                                    textStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  // 字号缩小并保持单行，避免按钮文字折行。
                                  child: Text(
                                    row[i] == 1
                                        ? context.localeText(
                                            '播完本集', 'This episode')
                                        : context.localeText('播完 ${row[i]} 集',
                                            '${row[i]} episodes'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (row.first != 3) const SizedBox(height: 7),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      height: 40,
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
                          SizedBox(
                            width: 80,
                            height: 32,
                            child: TextField(
                              controller: episodeController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: context.localeText(
                                    '自定义集数', 'Custom episodes'),
                                hintStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              final episodes =
                                  int.tryParse(episodeController.text.trim()) ??
                                      0;
                              if (episodes <= 0) return;
                              _startEpisodeSleepTimer(episodes);
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.primary600,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 30),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            child: Text(context.localeText('开启', 'Start')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _sleepRemainingSeconds == null &&
                              player.sleepEpisodesRemaining == null
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
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      child: Text(context.localeText('取消定时', 'Cancel Timer')),
                    ),
                  ),
                  if (remaining != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.localeText('剩余 ${_formatSleepTime(remaining)}',
                          'Remaining ${_formatSleepTime(remaining)}'),
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                  if (player.sleepEpisodesRemaining != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.localeText(
                          '再播 ${player.sleepEpisodesRemaining} 集后停止',
                          'Stops after ${player.sleepEpisodesRemaining} more ep.'),
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
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
    episodeController.dispose();
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
                    const SizedBox(height: 18),
                    StatefulBuilder(
                      builder: (context, setVolumeState) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child:
                                      Text(context.localeText('音量', 'Volume'))),
                              Text('${(player.volume * 100).round()}%',
                                  style: TextStyle(
                                      color: context.mutedText, fontSize: 12)),
                            ],
                          ),
                          Slider(
                            min: 0,
                            max: 1,
                            value: player.volume.clamp(0, 1).toDouble(),
                            activeColor: AppColors.primary600,
                            onChanged: (value) {
                              setVolumeState(() {});
                              player.setVolume(value);
                            },
                          ),
                        ],
                      ),
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
                                await player.savePlaybackSettings(
                                    book, skipIntro, skipOutro);
                                if (mounted) _updateMenuState(() {});
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
}
