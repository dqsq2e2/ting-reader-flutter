part of 'mine_page.dart';

class AdminStatisticsPage extends StatefulWidget {
  const AdminStatisticsPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<AdminStatisticsPage> createState() => _AdminStatisticsPageState();
}

class _AdminStatisticsPageState extends State<AdminStatisticsPage> {
  bool _loading = true;
  bool _refreshing = false;
  AdminStatistics? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (silent) {
        _refreshing = true;
      } else {
        _loading = true;
      }
    });
    try {
      final res =
          await AppScope.appOf(context).api.get('/api/system/statistics');
      setState(() => _stats = AdminStatistics.fromJson(asMap(res.data)));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final stats = _stats;
    if (stats == null) {
      return PageListView(
        children: [
          if (widget.onBack != null) ...[
            AppBackButton(onPressed: widget.onBack!),
            const SizedBox(height: 24),
          ],
          EmptyState(
            icon: Icons.query_stats_rounded,
            title: context.localeText('暂无统计数据', 'No Statistics'),
            message: context.localeText(
                '后台还没有返回统计信息。', 'The backend has not returned statistics yet.'),
          ),
        ],
      );
    }
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactScreen = screenWidth < 640;
    final overview = stats.overview;
    final totalLibraries =
        math.max<num>(1, _numStat(overview, 'total_libraries'));
    final localPercent =
        ((_numStat(overview, 'local_libraries') / totalLibraries) * 100)
            .round();
    final webdavPercent =
        ((_numStat(overview, 'webdav_libraries') / totalLibraries) * 100)
            .round();
    final totalUsers = _numStat(overview, 'total_users');
    final activeRate = totalUsers > 0
        ? ((_numStat(overview, 'active_users') / totalUsers) * 100).round()
        : 0;
    num maxUserListen = 1;
    for (final item in stats.userActivity) {
      maxUserListen = math.max(
        maxUserListen,
        _numStat(item, 'listen_seconds'),
      );
    }
    num maxBookHeat = 1;
    for (final item in stats.topBooks) {
      maxBookHeat = math.max(maxBookHeat, _bookHeatScore(item));
    }

    return PageListView(
      onRefresh: _load,
      children: [
        if (widget.onBack != null) ...[
          AppBackButton(onPressed: widget.onBack!),
          const SizedBox(height: 20),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final header = HeaderText(
              icon: Icons.bar_chart_rounded,
              title: context.localeText('数据统计', 'Statistics'),
              subtitle: context.localeText(
                  '生成时间：${_formatDateTime(stats.generatedAt, context)}',
                  'Generated: ${_formatDateTime(stats.generatedAt, context)}'),
            );
            final refreshButton = FilledButton.icon(
              onPressed: _refreshing ? null : () => _load(silent: true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.slate950,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: compactScreen ? 14 : 18,
                  vertical: compactScreen ? 11 : 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                Icons.refresh_rounded,
                size: compactScreen ? 16 : 18,
                color: Colors.white,
              ),
              label: Text(
                _refreshing
                    ? context.localeText('刷新中', 'Refreshing')
                    : context.localeText('刷新报表', 'Refresh'),
                style: TextStyle(
                  fontSize: compactScreen ? 13 : 14,
                ),
              ),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: refreshButton),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: header),
                refreshButton,
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            final compact = constraints.maxWidth < 560;
            final spacing = compact ? 12.0 : 16.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _StatisticsMetricTile(
                  width: width,
                  icon: Icons.library_books_rounded,
                  color: AppColors.primary600,
                  label: context.localeText('馆藏作品', 'Books'),
                  value: _statText(overview, 'total_books'),
                  detail: context.localeText(
                      '${_statText(overview, 'total_chapters')} 章 · ${formatDurationHumanForLocale(context, _numStat(overview, 'total_duration'))}',
                      '${_statText(overview, 'total_chapters')} chapters · ${formatDurationHumanForLocale(context, _numStat(overview, 'total_duration'))}'),
                ),
                _StatisticsMetricTile(
                  width: width,
                  icon: Icons.headphones_rounded,
                  color: Colors.green,
                  label: context.localeText('累计收听', 'Listening'),
                  value: formatDurationHumanForLocale(
                    context,
                    _numStat(overview, 'total_listen_seconds'),
                  ),
                  detail: context.localeText(
                      '${_statText(overview, 'total_progress_records')} 条进度记录',
                      '${_statText(overview, 'total_progress_records')} progress records'),
                ),
                _StatisticsMetricTile(
                  width: width,
                  icon: Icons.people_rounded,
                  color: Colors.purple,
                  label: context.localeText('活跃用户', 'Active Users'),
                  value:
                      '${_statText(overview, 'active_users')} / ${_statText(overview, 'total_users')}',
                  detail: context.localeText(
                      '活跃率 $activeRate% · 管理员 ${_statText(overview, 'admin_users')}',
                      'Active $activeRate% · Admins ${_statText(overview, 'admin_users')}'),
                ),
                _StatisticsMetricTile(
                  width: width,
                  icon: Icons.storage_rounded,
                  color: Colors.orange,
                  label: context.localeText('媒体库', 'Libraries'),
                  value: _statText(overview, 'total_libraries'),
                  detail: context.localeText(
                      '本地 ${_statText(overview, 'local_libraries')} · WebDAV ${_statText(overview, 'webdav_libraries')}',
                      'Local ${_statText(overview, 'local_libraries')} · WebDAV ${_statText(overview, 'webdav_libraries')}'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        _StatisticsPanel(
          title: context.localeText('活跃趋势', 'Activity Trend'),
          icon: Icons.trending_up_rounded,
          child: stats.recentActivity.isEmpty
              ? _StatisticsEmpty(
                  text: context.localeText('暂无近期活跃记录', 'No recent activity'))
              : _TrendChart(items: stats.recentActivity),
        ),
        const SizedBox(height: 24),
        _StatisticsPanel(
          title: context.localeText('媒体库结构', 'Library Mix'),
          icon: Icons.storage_rounded,
          child: _LibraryMix(
            total: _numStat(overview, 'total_libraries'),
            local: _numStat(overview, 'local_libraries'),
            webdav: _numStat(overview, 'webdav_libraries'),
            localPercent: localPercent,
            webdavPercent: webdavPercent,
          ),
        ),
        const SizedBox(height: 24),
        _StatisticsPanel(
          title: context.localeText('馆藏数据', 'Library Data'),
          icon: Icons.library_books_rounded,
          child: stats.libraryBreakdown.isEmpty
              ? _StatisticsEmpty(
                  text: context.localeText('暂无媒体库数据', 'No library data'))
              : _LibraryBreakdownGrid(items: stats.libraryBreakdown),
        ),
        const SizedBox(height: 24),
        _StatisticsPanel(
          title: context.localeText('用户使用情况', 'User Activity'),
          icon: Icons.insights_rounded,
          child: stats.userActivity.isEmpty
              ? _StatisticsEmpty(
                  text: context.localeText('暂无用户活跃数据', 'No user activity'))
              : _UserActivityList(
                  items: stats.userActivity,
                  maxListen: maxUserListen,
                ),
        ),
        const SizedBox(height: 24),
        _StatisticsPanel(
          title: context.localeText('热门收听作品', 'Top Books'),
          icon: Icons.menu_book_rounded,
          child: stats.topBooks.isEmpty
              ? _StatisticsEmpty(
                  text:
                      context.localeText('暂无作品收听数据', 'No book listening data'))
              : _TopBooksLeaderboard(
                  items: stats.topBooks,
                  maxHeat: maxBookHeat,
                ),
        ),
        const SafeBottomSpacer(),
      ],
    );
  }
}

class _StatisticsMetricTile extends StatelessWidget {
  const _StatisticsMetricTile({
    required this.width,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
  });

  final double width;
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final compact = width < 180;
    final tiny = width < 150;
    return SizedBox(
      width: width,
      height: tiny
          ? 148
          : compact
              ? 164
              : null,
      child: TingCard(
        radius: 18,
        padding: EdgeInsets.all(tiny
            ? 12
            : compact
                ? 16
                : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: tiny
                      ? 34
                      : compact
                          ? 38
                          : 42,
                  height: tiny
                      ? 34
                      : compact
                          ? 38
                          : 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(tiny ? 11 : 13),
                  ),
                  child: Icon(icon, color: color, size: tiny ? 18 : 21),
                ),
                const Spacer(),
                Text(
                  label,
                  style: TextStyle(
                    color: context.tertiaryText,
                    fontSize: tiny
                        ? 10
                        : compact
                            ? 11
                            : 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: tiny ? 10 : 18),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: tiny
                        ? 20
                        : compact
                            ? 22
                            : 26,
                    height: 1,
                  ),
                ),
              ),
            ),
            SizedBox(height: tiny ? 6 : 8),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.tertiaryText,
                fontSize: tiny ? 11 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsPanel extends StatelessWidget {
  const _StatisticsPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return TingCard(
      radius: 24,
      padding: EdgeInsets.all(compact ? 18 : 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon,
                    color: AppColors.slate600, size: compact ? 18 : 20),
              ),
              SizedBox(width: compact ? 10 : 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 16 : 18,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 14 : 18),
          child,
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final totalUpdates = items.fold<num>(
      0,
      (sum, item) => sum + _numStat(item, 'progress_updates'),
    );
    final totalListen = items.fold<num>(
      0,
      (sum, item) => sum + _numStat(item, 'listen_seconds'),
    );
    final activeUsers = items.fold<num>(
      0,
      (max, item) => math.max(max, _numStat(item, 'active_users')),
    );
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 240 ? 3 : 1;
            final gap = constraints.maxWidth < 430 ? 8.0 : 12.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _TrendStat(
                    width: width,
                    label: context.localeText('更新次数', 'Updates'),
                    value:
                        context.localeText('$totalUpdates 次', '$totalUpdates')),
                _TrendStat(
                    width: width,
                    label: context.localeText('活跃峰值', 'Peak Active'),
                    value:
                        context.localeText('$activeUsers 人', '$activeUsers')),
                _TrendStat(
                  width: width,
                  label: context.localeText('累计收听', 'Listening'),
                  value: formatDurationHumanForLocale(context, totalListen),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Container(
          height: compact ? 220 : 290,
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.slate950 : AppColors.slate50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.faintBorder),
          ),
          child: CustomPaint(
            painter: _TrendPainter(items),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final item in items.take(8))
                      Text(
                        _formatDay((item['date'] ?? '').toString()),
                        style: TextStyle(
                          color: context.tertiaryText,
                          fontSize: compact ? 10 : 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendStat extends StatelessWidget {
  const _TrendStat({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 13,
        vertical: compact ? 11 : 13,
      ),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.tertiaryText,
              fontSize: compact ? 10.5 : 12,
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.items);

  final List<Map<String, dynamic>> items;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = EdgeInsets.fromLTRB(28, 24, 28, 42);
    final chart = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );
    final gridPaint = Paint()
      ..color = AppColors.slate200
      ..strokeWidth = 1;
    for (final mark in [0.25, 0.5, 0.75]) {
      final y = chart.top + chart.height * mark;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    if (items.isEmpty) return;
    num maxUpdates = 1;
    for (final item in items) {
      maxUpdates = math.max(
        maxUpdates,
        _numStat(item, 'progress_updates'),
      );
    }
    final points = <Offset>[];
    for (var i = 0; i < items.length; i++) {
      final x = items.length == 1
          ? chart.center.dx
          : chart.left + chart.width * (i / (items.length - 1));
      final updates = _numStat(items[i], 'progress_updates');
      final y = chart.bottom - chart.height * (updates / maxUpdates);
      points.add(Offset(x, y));
    }
    final area = Path()
      ..moveTo(chart.left, chart.bottom)
      ..lineTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      area.lineTo(point.dx, point.dy);
    }
    area
      ..lineTo(chart.right, chart.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x2e0284c7), Color(0x05059669)],
        ).createShader(chart),
    );
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.primary600, Color(0xff059669)],
        ).createShader(chart)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final dotPaint = Paint()..color = Colors.white;
    final dotStroke = Paint()
      ..color = AppColors.primary600
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final point in points) {
      canvas.drawCircle(point, 6, dotPaint);
      canvas.drawCircle(point, 6, dotStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.items != items;
}

class _LibraryMix extends StatelessWidget {
  const _LibraryMix({
    required this.total,
    required this.local,
    required this.webdav,
    required this.localPercent,
    required this.webdavPercent,
  });

  final num total;
  final num local;
  final num webdav;
  final int localPercent;
  final int webdavPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SmallStat(
                label: context.localeText('总数', 'Total'),
                value: '$total',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SmallStat(
                label: context.localeText('本地', 'Local'),
                value: '$local',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _SmallStat(label: 'WebDAV', value: '$webdav')),
          ],
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(
            children: [
              Expanded(
                flex: math.max(1, localPercent),
                child: Container(height: 12, color: AppColors.primary500),
              ),
              Expanded(
                flex: math.max(1, webdavPercent),
                child: Container(height: 12, color: Colors.purple),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _MixRow(
            label: context.localeText('本地库', 'Local'),
            value: '$localPercent%',
            color: AppColors.primary500),
        const SizedBox(height: 12),
        _MixRow(
            label: 'WebDAV', value: '$webdavPercent%', color: Colors.purple),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate800 : AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.tertiaryText,
              fontSize: compact ? 11 : 12,
            ),
          ),
          SizedBox(height: compact ? 4 : 5),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 17 : 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MixRow extends StatelessWidget {
  const _MixRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 12.5 : 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LibraryBreakdownGrid extends StatelessWidget {
  const _LibraryBreakdownGrid({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final gap = constraints.maxWidth < 430 ? 10.0 : 16.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _LibraryBreakdownCard(item: item)),
          ],
        );
      },
    );
  }
}

class _LibraryBreakdownCard extends StatelessWidget {
  const _LibraryBreakdownCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final type = (item['library_type'] ?? '').toString();
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.slate950.withValues(alpha: 0.45)
            : AppColors.slate50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['name'] ??
                              context.localeText('未命名媒体库', 'Unnamed Library'))
                          .toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: compact ? 5 : 8),
                    Text(
                      formatDurationHumanForLocale(
                        context,
                        _numStat(item, 'total_duration'),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.tertiaryText,
                        fontSize: compact ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              ),
              _TypeBadge(value: type),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _CompactStat(
                  label: context.localeText('作品', 'Books'),
                  value: _statText(item, 'total_books'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactStat(
                  label: context.localeText('章节', 'Chapters'),
                  value: _statText(item, 'total_chapters'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactStat(
                  label: context.localeText('时长', 'Duration'),
                  value: _formatShortDurationLabel(
                    _numStat(item, 'total_duration'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: context.faintBorder),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                context.localeText('最近扫描', 'Last Scan'),
                style: TextStyle(
                  color: context.tertiaryText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formatDateTime(item['last_scanned_at']?.toString()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: context.tertiaryText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserActivityList extends StatelessWidget {
  const _UserActivityList({
    required this.items,
    required this.maxListen,
  });

  final List<Map<String, dynamic>> items;
  final num maxListen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _UserActivityRow(item: items[i], maxListen: maxListen),
          if (i != items.length - 1)
            Divider(height: 18, color: context.faintBorder),
        ],
      ],
    );
  }
}

class _UserActivityRow extends StatelessWidget {
  const _UserActivityRow({required this.item, required this.maxListen});

  final Map<String, dynamic> item;
  final num maxListen;

  @override
  Widget build(BuildContext context) {
    final username = (item['username'] ?? 'User').toString();
    final role = (item['role'] ?? '').toString();
    final listen = _numStat(item, 'listen_seconds');
    final records = _statText(item, 'progress_records');
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: compact ? 18 : 20,
              backgroundColor: AppColors.primary100,
              foregroundColor: AppColors.primary600,
              child: Text(
                username.isEmpty ? 'U' : username.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 14 : 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${role == 'admin' ? context.localeText('管理员', 'Admin') : context.localeText('普通用户', 'User')} · ${_statText(item, 'listened_books')} ${context.localeText('本', 'books')}',
                    style: TextStyle(
                      color: context.tertiaryText,
                      fontSize: compact ? 11.5 : 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDurationHumanForLocale(context, listen),
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDateTime(item['last_active_at']?.toString(), context),
                  style: TextStyle(
                    color: context.tertiaryText,
                    fontSize: compact ? 10.5 : 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ProgressLine(
                value: listen,
                max: maxListen,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              context.localeText('$records 条', '$records records'),
              style: TextStyle(
                color: context.tertiaryText,
                fontSize: compact ? 10.5 : 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TopBooksLeaderboard extends StatelessWidget {
  const _TopBooksLeaderboard({
    required this.items,
    required this.maxHeat,
  });

  final List<Map<String, dynamic>> items;
  final num maxHeat;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100 ? 3 : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: width,
                child: _TopBookCard(
                  item: items[i],
                  rank: i + 1,
                  maxHeat: maxHeat,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TopBookCard extends StatelessWidget {
  const _TopBookCard({
    required this.item,
    required this.rank,
    required this.maxHeat,
  });

  final Map<String, dynamic> item;
  final int rank;
  final num maxHeat;

  @override
  Widget build(BuildContext context) {
    final heat = _bookHeatScore(item);
    final accent = _rankAccent(rank);
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Container(
      padding: EdgeInsets.all(compact ? 13 : 16),
      decoration: BoxDecoration(
        color: accent.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.badge,
                  borderRadius: BorderRadius.circular(compact ? 11 : 13),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: accent.badgeText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['title'] ??
                              context.localeText('未知作品', 'Unknown Book'))
                          .toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item['author'] ?? context.localeText('未知作者', 'Unknown Author')} · ${item['library_name'] ?? context.localeText('未知媒体库', 'Unknown Library')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.tertiaryText,
                        fontSize: compact ? 11.5 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CompactStat(
                  label: context.localeText('听众', 'Listeners'),
                  value: _statText(item, 'listeners'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactStat(
                  label: context.localeText('记录', 'Records'),
                  value: _statText(item, 'progress_updates'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactStat(
                  label: context.localeText('收听', 'Listened'),
                  value: formatDurationHumanForLocale(
                    context,
                    _numStat(item, 'listen_seconds'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                context.localeText('综合热度', 'Heat'),
                style: TextStyle(
                  color: context.tertiaryText,
                  fontSize: compact ? 11.5 : 12,
                ),
              ),
              const Spacer(),
              Text(
                '$heat',
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: compact ? 11.5 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _ProgressLine(value: heat, max: maxHeat, color: accent.badge),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.tertiaryText,
              fontSize: compact ? 10.5 : 11,
            ),
          ),
          SizedBox(height: compact ? 2 : 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final isWebdav = value.toLowerCase() == 'webdav';
    final color = isWebdav ? Colors.purple : AppColors.primary600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        value.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.value,
    required this.max,
    required this.color,
  });

  final num value;
  final num max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 8,
        color: color,
        backgroundColor:
            context.isDark ? AppColors.slate800 : AppColors.slate100,
      ),
    );
  }
}

class _StatisticsEmpty extends StatelessWidget {
  const _StatisticsEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.faintBorder),
      ),
      child: Text(text, style: TextStyle(color: context.mutedText)),
    );
  }
}

class _RankAccent {
  const _RankAccent({
    required this.surface,
    required this.border,
    required this.badge,
    required this.badgeText,
  });

  final Color surface;
  final Color border;
  final Color badge;
  final Color badgeText;
}

_RankAccent _rankAccent(int rank) {
  if (rank == 1) {
    return const _RankAccent(
      surface: Color(0xfff5f3ff),
      border: Color(0xffede9fe),
      badge: Colors.purple,
      badgeText: Colors.white,
    );
  }
  if (rank == 2) {
    return const _RankAccent(
      surface: Color(0xfff0f9ff),
      border: Color(0xffe0f2fe),
      badge: AppColors.primary500,
      badgeText: Colors.white,
    );
  }
  return const _RankAccent(
    surface: AppColors.slate50,
    border: AppColors.slate200,
    badge: AppColors.slate200,
    badgeText: AppColors.slate600,
  );
}

num _bookHeatScore(Map<String, dynamic> item) {
  final listeners = _numStat(item, 'listeners');
  final updates = _numStat(item, 'progress_updates');
  final listen = _numStat(item, 'listen_seconds');
  return listeners * 20 + updates * 6 + (listen / 60).ceil();
}

String _formatDateTime(String? value, [BuildContext? context]) {
  if (value == null || value.isEmpty) {
    return context?.localeText('暂无记录', 'No record') ?? 'No record';
  }
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatDay(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value.length > 5 ? value.substring(5) : value;
  return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _formatShortDurationLabel(num seconds) {
  final safe = math.max<num>(0, seconds).round();
  final hours = safe ~/ 3600;
  final minutes = ((safe % 3600) / 60).round();
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${math.max(0, minutes)}m';
}

String _statText(Map<String, dynamic> map, String key) {
  return (map[key] ?? 0).toString();
}

num _numStat(Map<String, dynamic> map, String key) {
  final value = map[key] ?? 0;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? 0;
}
