part of 'book_detail_scrape.dart';

class _ScrapeResultCard extends StatelessWidget {
  const _ScrapeResultCard({
    required this.result,
    required this.selectedFields,
    required this.onOpen,
  });

  final ScrapeResult result;
  final Map<String, SelectedScrapeField> selectedFields;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final coverShape =
        coverShapeFromAppSettings(AppScope.appOf(context).settings);
    final cover = scrapeItemValue(result.item, 'cover_url')?.toString() ?? '';
    final fields = result.source.resultFields
        .where((key) => hasScrapeValue(scrapeItemValue(result.item, key)))
        .toList();
    final selectedFromThisResult = selectedFields.values
        .where((field) =>
            field.sourceId == result.source.id && field.resultKey == result.key)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.faintBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: context.isDark ? 0.12 : 0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: coverShape == CoverShape.square ? 96 : 84,
                    height: coverShape == CoverShape.square ? 96 : 112,
                    child: CoverImage(url: cover, radius: 8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: context.isDark
                                      ? AppColors.slate800
                                      : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  result.source.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.tertiaryText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.slate300,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _scrapeResultTitleForLocale(context, result),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.slate950,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _scrapeResultSubtitleForLocale(context, result)
                                  .isEmpty
                              ? context.localeText(
                                  '未返回作者/演播', 'No author/narrator')
                              : _scrapeResultSubtitleForLocale(context, result),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.slate500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final key in fields.take(4))
                    _ScrapeTinyBadge(
                      label: _localizedScrapeResultFieldLabel(
                          context, result.source, key),
                    ),
                  if (fields.length > 4)
                    _ScrapeTinyBadge(label: '+${fields.length - 4}'),
                  for (final field in selectedFromThisResult.take(3))
                    _ScrapeTinyBadge(
                      label: field.label,
                      selected: true,
                    ),
                  if (selectedFromThisResult.length > 3)
                    _ScrapeTinyBadge(
                      label: '+${selectedFromThisResult.length - 3}',
                      selected: true,
                      soft: true,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScrapeTinyBadge extends StatelessWidget {
  const _ScrapeTinyBadge({
    required this.label,
    this.selected = false,
    this.soft = false,
  });

  final String label;
  final bool selected;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: selected
            ? (soft ? AppColors.primary100 : AppColors.primary600)
            : (context.isDark ? AppColors.slate800 : AppColors.slate100),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected
              ? (soft ? AppColors.primary700 : Colors.white)
              : context.tertiaryText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScrapeResultFieldTile extends StatelessWidget {
  const _ScrapeResultFieldTile({
    required this.book,
    required this.result,
    required this.selectedFields,
    required this.keyName,
    required this.selected,
    required this.selectedFromOther,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onTap,
  });

  final Book book;
  final ScrapeResult result;
  final Map<String, SelectedScrapeField> selectedFields;
  final String keyName;
  final bool selected;
  final bool selectedFromOther;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final definition = _scrapeFieldDefinitions[keyName];
    final value = scrapeItemValue(result.item, keyName);
    final hasValue = hasScrapeValue(value);
    final currentValue = draftScrapeFieldValue(book, selectedFields, keyName);
    final label =
        _localizedScrapeResultFieldLabel(context, result.source, keyName);
    final isCover = keyName == 'cover_url';
    final isDescription = keyName == 'description';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.faintBorder),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: context.isDark ? 0.12 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                definition?.icon ?? Icons.check_rounded,
                color: context.tertiaryText,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.isDark
                        ? AppColors.slate100
                        : AppColors.slate800,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: hasValue ? onTap : null,
                icon: Icon(
                  selected ? Icons.check_rounded : Icons.add_rounded,
                  size: 15,
                ),
                label: Text(
                  selected
                      ? context.localeText('已采用', 'Used')
                      : selectedFromOther
                          ? context.localeText('替换', 'Replace')
                          : context.localeText('采用', 'Use'),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: selected
                      ? AppColors.primary600
                      : hasValue
                          ? (context.isDark
                              ? AppColors.slate950
                              : AppColors.slate100)
                          : (context.isDark
                              ? AppColors.slate950.withValues(alpha: 0.55)
                              : AppColors.slate50),
                  foregroundColor: selected
                      ? Colors.white
                      : hasValue
                          ? AppColors.slate600
                          : AppColors.slate300,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isCover)
            LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 420;
                final current = _ScrapeCoverCompare(
                  label: context.localeText('当前', 'Current'),
                  value: currentValue,
                  color: AppColors.slate400,
                  book: book,
                );
                final next = _ScrapeCoverCompare(
                  label: context.localeText('应用', 'Apply'),
                  value: value,
                  color: AppColors.primary500,
                );
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      current,
                      const SizedBox(height: 12),
                      next,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: current),
                    const SizedBox(width: 12),
                    Expanded(child: next),
                  ],
                );
              },
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ScrapeValueCompare(
                  label: context.localeText('当前', 'Current'),
                  value: _formatScrapeValueForLocale(
                      context, currentValue, '未知', 'Unknown'),
                  color: AppColors.slate400,
                  backgroundColor:
                      context.isDark ? AppColors.slate950 : AppColors.slate50,
                  foregroundColor: AppColors.slate500,
                  maxLines: isDescription ? 3 : 2,
                ),
                const SizedBox(height: 10),
                _ScrapeValueCompare(
                  label: context.localeText('应用', 'Apply'),
                  value: _formatScrapeValueForLocale(context, value),
                  color: AppColors.primary500,
                  backgroundColor: context.isDark
                      ? AppColors.primary950.withValues(alpha: 0.25)
                      : AppColors.primary50,
                  foregroundColor:
                      context.isDark ? Colors.white : AppColors.slate950,
                  maxLines: isDescription && !expanded ? 5 : null,
                ),
              ],
            ),
          if (isDescription && hasScrapeValue(value)) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onToggleExpanded,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary600,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(expanded
                    ? context.localeText('收起', 'Collapse')
                    : context.localeText('展开', 'Expand')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
