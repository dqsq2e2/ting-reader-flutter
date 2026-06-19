part of 'home_page.dart';

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final date = DateTime.now().toLocal();
    final dateText = '${date.month}月${date.day}日${_weekdayCn(date.weekday)}';

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting(),
          style: const TextStyle(
            color: AppColors.primary600,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '今天听点什么',
          style: TextStyle(
            color: AppColors.slate950,
            fontSize: 36,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '推荐、最近、书单和你的听书节奏都在这里。',
          style: TextStyle(color: context.mutedText, fontSize: 16),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: compact ? WrapAlignment.start : WrapAlignment.end,
      children: [
        SizedBox(
          height: 48,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.cardColor,
              border: Border.all(color: context.faintBorder),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppColors.slate500),
                const SizedBox(width: 8),
                Text(
                  dateText,
                  style: TextStyle(color: context.mutedText, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onSearch,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.slate950,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.search_rounded, size: 20),
          label: const Text(
            '搜索内容',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 18),
          actions,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        const SizedBox(width: 20),
        actions,
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.item,
    required this.next,
    required this.listenMinutes,
    required this.favoritesCount,
    required this.playlistsCount,
    required this.recentCount,
    required this.coverShape,
    required this.showHero,
    required this.showStats,
    required this.onCycle,
    required this.onPrimary,
    required this.onPlaylists,
  });

  final _HeroItem? item;
  final _HeroItem? next;
  final int listenMinutes;
  final int favoritesCount;
  final int playlistsCount;
  final int recentCount;
  final CoverShape coverShape;
  final bool showHero;
  final bool showStats;
  final VoidCallback onCycle;
  final VoidCallback onPrimary;
  final VoidCallback onPlaylists;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showHero)
          _HeroCard(
            item: item,
            next: next,
            coverShape: coverShape,
            onCycle: onCycle,
            onPrimary: onPrimary,
            onPlaylists: onPlaylists,
          ),
        if (showHero && showStats) const SizedBox(height: 24),
        if (showStats)
          _HomeStatsGrid(
            listenMinutes: listenMinutes,
            favoritesCount: favoritesCount,
            playlistsCount: playlistsCount,
            recentCount: recentCount,
          ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.item,
    required this.next,
    required this.coverShape,
    required this.onCycle,
    required this.onPrimary,
    required this.onPlaylists,
  });

  final _HeroItem? item;
  final _HeroItem? next;
  final CoverShape coverShape;
  final VoidCallback onCycle;
  final VoidCallback onPrimary;
  final VoidCallback onPlaylists;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final cover = item == null
        ? ''
        : coverUrl(
            appState,
            url: item!.coverUrl,
            libraryId: item!.libraryId,
            bookId: item!.id,
          );
    final nextCover = next == null
        ? ''
        : coverUrl(
            appState,
            url: next!.coverUrl,
            libraryId: next!.libraryId,
            bookId: next!.id,
          );

    final smallScreen = MediaQuery.sizeOf(context).width < 640;
    return Container(
      constraints: BoxConstraints(minHeight: smallScreen ? 0 : 420),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xfff8fafc),
            Color(0xffdbeafe),
            Color(0xfff0f9ff),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary200.withOpacity(0.65),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -70,
            width: 460,
            height: 460,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.18,
                child: CoverImage(url: cover, radius: 220),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.74),
                    Colors.white.withOpacity(0.18),
                    AppColors.slate900.withOpacity(0.08),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(smallScreen ? 16 : 28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final text = _HeroText(
                  item: item,
                  onPrimary: onPrimary,
                  onPlaylists: onPlaylists,
                  includeActions: !compact,
                );
                final coverStack = _HeroCoverStack(
                  cover: cover,
                  nextCover: nextCover,
                  nextTitle: next?.title,
                  canCycle: next != null,
                  coverShape: coverShape,
                  onCycle: onCycle,
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text,
                      const SizedBox(height: 20),
                      Align(alignment: Alignment.center, child: coverStack),
                      const SizedBox(height: 20),
                      _HeroActions(
                        isProgress: item?.progress != null,
                        hasItem: item != null,
                        compact: true,
                        onPrimary: onPrimary,
                        onPlaylists: onPlaylists,
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: 32),
                    coverStack,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({
    required this.item,
    required this.onPrimary,
    required this.onPlaylists,
    required this.includeActions,
  });

  final _HeroItem? item;
  final VoidCallback onPrimary;
  final VoidCallback onPlaylists;
  final bool includeActions;

  @override
  Widget build(BuildContext context) {
    final isProgress = item?.progress != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final titleSize = compact ? 32.0 : 46.0;
        final headlineGap = compact ? 16.0 : 26.0;
        final subtitleGap = compact ? 8.0 : 15.0;
        final descriptionGap = compact ? 12.0 : 18.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.slate900.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: AppColors.slate900.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.amber,
                        size: 15,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        isProgress ? '继续收听' : '今日推荐',
                        style: const TextStyle(
                          color: AppColors.slate700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: headlineGap),
                Text(
                  item?.title ?? '打开一本新的声音',
                  maxLines: compact ? 2 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.slate950,
                    fontSize: titleSize,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: subtitleGap),
                Text(
                  item?.subtitle ?? '从书架里挑一本作品开始播放',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.slate500,
                    fontSize: compact ? 14 : 16,
                  ),
                ),
                SizedBox(height: descriptionGap),
                Text(
                  item?.description ?? '从书架里挑一本最近添加的作品，或者去搜索页面发现新的内容。',
                  maxLines: compact ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.slate700,
                    fontSize: compact ? 14 : 16,
                    height: compact ? 1.55 : 1.66,
                  ),
                ),
              ],
            ),
            if (includeActions) ...[
              const SizedBox(height: 28),
              _HeroActions(
                isProgress: isProgress,
                hasItem: item != null,
                compact: false,
                onPrimary: onPrimary,
                onPlaylists: onPlaylists,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HeroActions extends StatelessWidget {
  const _HeroActions({
    required this.isProgress,
    required this.hasItem,
    required this.compact,
    required this.onPrimary,
    required this.onPlaylists,
  });

  final bool isProgress;
  final bool hasItem;
  final bool compact;
  final VoidCallback onPrimary;
  final VoidCallback onPlaylists;

  @override
  Widget build(BuildContext context) {
    final primary = FilledButton.icon(
      onPressed: onPrimary,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.slate950,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(
        hasItem ? Icons.play_arrow_rounded : Icons.library_books_rounded,
        size: 20,
      ),
      label: Text(
        hasItem ? (isProgress ? '继续播放' : '查看详情') : '去书架',
      ),
    );
    final secondary = OutlinedButton.icon(
      onPressed: onPlaylists,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.48),
        foregroundColor: AppColors.slate800,
        side: BorderSide(color: Colors.white.withOpacity(0.7)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.queue_music_rounded, size: 20),
      label: const Text(
        '管理书单',
      ),
    );

    if (compact) {
      return Row(
        children: [
          Expanded(child: primary),
          const SizedBox(width: 12),
          Expanded(child: secondary),
        ],
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [primary, secondary],
    );
  }
}

class _HeroCoverStack extends StatelessWidget {
  const _HeroCoverStack({
    required this.cover,
    required this.nextCover,
    required this.nextTitle,
    required this.canCycle,
    required this.coverShape,
    required this.onCycle,
  });

  final String cover;
  final String nextCover;
  final String? nextTitle;
  final bool canCycle;
  final CoverShape coverShape;
  final VoidCallback onCycle;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 760;
    final width = compact
        ? math.min(screenWidth * 0.62, 216.0)
        : screenWidth >= 1280
            ? 320.0
            : 290.0;
    final radius = compact ? 22.0 : 28.0;
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: coverAspectRatio(coverShape),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: compact ? -8 : -18,
              top: compact ? 12 : 22,
              right: compact ? 10 : 22,
              bottom: compact ? 0 : -2,
              child: Transform.rotate(
                angle: -0.08,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(radius),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.slate900.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (canCycle)
              Positioned(
                right: compact ? -12 : -22,
                top: compact ? 22 : 40,
                bottom: compact ? -4 : -8,
                left: compact ? 24 : 38,
                child: Transform.rotate(
                  angle: 0.09,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CoverImage(url: nextCover, radius: radius),
                        Container(color: AppColors.slate950.withOpacity(0.32)),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: GestureDetector(
                onTap: canCycle ? onCycle : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CoverImage(url: cover, radius: radius),
                      if (canCycle)
                        Positioned(
                          left: compact ? 8 : 14,
                          right: compact ? 8 : 14,
                          bottom: compact ? 8 : 14,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 10 : 12,
                              vertical: compact ? 8 : 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.slate950.withOpacity(0.48),
                              borderRadius:
                                  BorderRadius.circular(compact ? 14 : 18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!compact) ...[
                                        const Text(
                                          '点击封面切换',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      Text(
                                        '下一本：${nextTitle ?? '继续切换'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: compact ? 8 : 10),
                                Container(
                                  width: compact ? 28 : 34,
                                  height: compact ? 28 : 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.refresh_rounded,
                                      color: Colors.white, size: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
