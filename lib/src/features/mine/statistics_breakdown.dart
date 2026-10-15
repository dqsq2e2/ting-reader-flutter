part of 'statistics_pages.dart';

class _LibraryBreakdownGrid extends StatelessWidget {
  const _LibraryBreakdownGrid({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 805
                ? 2
                : 1;
        const gap = 12.0;
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
      padding: EdgeInsets.all(compact ? 13 : 16),
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
                  _formatDateTime(item['last_scanned_at']?.toString(), context),
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
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 805
                ? 2
                : 1;
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
                  label: context.localeText(
                    '活跃记录',
                    'Activity records',
                  ),
                  value: _statText(item, 'progress_updates'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactStat(
                  label: context.localeText('收听', 'Listened'),
                  value: _formatShortDurationLabel(
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
    final isRss = value.toLowerCase() == 'rss';
    final color = isWebdav
        ? Colors.purple
        : isRss
            ? Colors.orange
            : AppColors.primary600;
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
  final date = backendDateTimeInApplicationTimeZone(
    value,
    context == null ? null : AppScope.appOf(context).applicationTimeZone,
  );
  if (date == null) return value;
  return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatDay(String value, [BuildContext? context]) {
  final date = backendDateTimeInApplicationTimeZone(
    value,
    context == null ? null : AppScope.appOf(context).applicationTimeZone,
  );
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
