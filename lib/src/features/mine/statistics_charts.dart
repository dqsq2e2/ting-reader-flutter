part of 'statistics_pages.dart';

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
                    label: context.localeText(
                      '最近活跃记录',
                      'Activity records (14d)',
                    ),
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
                        _formatDay((item['date'] ?? '').toString(), context),
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
