import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/models/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/application_time_zone.dart';
import '../../core/utils/locale.dart';
import '../../shared/app_scope.dart';
import '../../shared/common/common_widgets.dart';

part 'statistics_breakdown.dart';

part 'statistics_charts.dart';

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
  CancelToken? _request;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load({bool silent = false}) async {
    _request?.cancel('Statistics query replaced');
    final request = CancelToken();
    _request = request;
    setState(() {
      _loadFailed = false;
      if (silent) {
        _refreshing = true;
      } else {
        _loading = true;
      }
    });
    try {
      final res = await AppScope.appOf(context)
          .api
          .get('/api/system/statistics', cancelToken: request);
      if (!mounted || request.isCancelled || !identical(_request, request)) {
        return;
      }
      setState(() => _stats = AdminStatistics.fromJson(asMap(res.data)));
    } catch (_) {
      if (mounted && !request.isCancelled && identical(_request, request)) {
        setState(() => _loadFailed = true);
      }
    } finally {
      if (mounted && identical(_request, request)) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _request?.cancel('Statistics page disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onBackValue = widget.onBack;
    if (_loading) return const LoadingView();
    if (_loadFailed) {
      return PageListView(children: [
        if (onBackValue != null) AppBackButton(onPressed: onBackValue),
        LoadErrorView(onRetry: _load),
      ]);
    }
    final stats = _stats;
    if (stats == null) {
      return PageListView(
        children: [
          if (onBackValue != null) ...[
            AppBackButton(onPressed: onBackValue),
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
    final rssPercent =
        ((_numStat(overview, 'rss_libraries') / totalLibraries) * 100).round();
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
        if (onBackValue != null) ...[
          AppBackButton(onPressed: onBackValue),
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
                      '当前 ${_statText(overview, 'total_progress_records')} 条进度记录',
                      '${_statText(overview, 'total_progress_records')} current progress records'),
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
                      '本地 ${_statText(overview, 'local_libraries')} · WebDAV ${_statText(overview, 'webdav_libraries')} · RSS ${_statText(overview, 'rss_libraries')}',
                      'Local ${_statText(overview, 'local_libraries')} · WebDAV ${_statText(overview, 'webdav_libraries')} · RSS ${_statText(overview, 'rss_libraries')}'),
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
            rss: _numStat(overview, 'rss_libraries'),
            localPercent: localPercent,
            webdavPercent: webdavPercent,
            rssPercent: rssPercent,
          ),
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
          title: context.localeText('馆藏数据', 'Library Data'),
          icon: Icons.library_books_rounded,
          child: stats.libraryBreakdown.isEmpty
              ? _StatisticsEmpty(
                  text: context.localeText('暂无媒体库数据', 'No library data'))
              : _LibraryBreakdownGrid(items: stats.libraryBreakdown),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: context.tertiaryText,
                      fontSize: tiny
                          ? 10
                          : compact
                              ? 11
                              : 12,
                    ),
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
              maxLines: 2,
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

class _LibraryMix extends StatelessWidget {
  const _LibraryMix({
    required this.total,
    required this.local,
    required this.webdav,
    required this.rss,
    required this.localPercent,
    required this.webdavPercent,
    required this.rssPercent,
  });

  final num total;
  final num local;
  final num webdav;
  final num rss;
  final int localPercent;
  final int webdavPercent;
  final int rssPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 480 ? 2 : 4;
            final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (label, value) in [
                  (context.localeText('总数', 'Total'), total),
                  (context.localeText('本地', 'Local'), local),
                  ('WebDAV', webdav),
                  ('RSS', rss),
                ])
                  SizedBox(
                    width: width,
                    child: _SmallStat(label: label, value: '$value'),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 12,
            color: context.isDark ? AppColors.slate800 : AppColors.slate100,
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  for (final (count, color) in [
                    (local, AppColors.primary500),
                    (webdav, Colors.purple),
                    (rss, Colors.orange),
                  ])
                    if (count > 0 && total > 0)
                      Container(
                        width: constraints.maxWidth * count / total,
                        color: color,
                      ),
                ],
              ),
            ),
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
        const SizedBox(height: 12),
        _MixRow(label: 'RSS', value: '$rssPercent%', color: Colors.orange),
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
