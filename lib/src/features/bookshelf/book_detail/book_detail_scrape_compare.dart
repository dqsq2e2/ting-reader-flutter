part of 'book_detail_scrape.dart';

class _ScrapeCoverCompare extends StatelessWidget {
  const _ScrapeCoverCompare({
    required this.label,
    required this.value,
    required this.color,
    this.book,
  });

  final String label;
  final Object? value;
  final Color color;
  final Book? book;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.appOf(context);
    final coverShape = coverShapeFromAppSettings(appState.settings);
    final rawUrl = value?.toString().trim() ?? '';
    final resolvedUrl = coverUrl(
      appState,
      url: rawUrl,
      libraryId: book?.libraryId,
      bookId: book?.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.slate900 : AppColors.slate100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.faintBorder),
          ),
          child: AspectRatio(
            aspectRatio: coverAspectRatio(coverShape),
            child: CoverImage(
              url: resolvedUrl,
              radius: 9,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrapeValueCompare extends StatelessWidget {
  const _ScrapeValueCompare({
    required this.label,
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.foregroundColor,
    this.maxLines,
  });

  final String label;
  final String value;
  final Color color;
  final Color backgroundColor;
  final Color foregroundColor;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            maxLines: maxLines,
            overflow:
                maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedScrapeFieldCard extends StatelessWidget {
  const _SelectedScrapeFieldCard({
    super.key,
    required this.book,
    required this.selected,
    required this.field,
    required this.onChanged,
    required this.onRemove,
  });

  final SelectedScrapeField field;
  final Book book;
  final bool selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final definition = _scrapeFieldDefinitions[field.key];
    final editorValue = scrapeValueForEditor(field.value);
    final isLongText = field.key == 'description' || field.key == 'tags';
    final isBoolean = field.key == 'explicit' || field.key == 'abridged';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.faintBorder),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label,
                      style: const TextStyle(
                        color: AppColors.slate950,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selected
                          ? [field.sourceName, field.resultTitle]
                              .where((value) => value.isNotEmpty)
                              .join(' · ')
                          : context.localeText(
                              '当前值 · 未修改', 'Current value · Unchanged'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.tertiaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                IconButton(
                  tooltip: context.localeText('恢复当前值', 'Restore current value'),
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: const Color(0xffef4444),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (field.key == 'cover_url')
            LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 560;
                final preview = SizedBox(
                  width: 160,
                  child: AspectRatio(
                    aspectRatio: coverAspectRatio(
                      coverShapeFromAppSettings(
                        AppScope.appOf(context).settings,
                      ),
                    ),
                    child: CoverImage(
                      url: coverUrl(AppScope.appOf(context),
                          url: editorValue,
                          libraryId: book.libraryId,
                          bookId: book.id),
                      radius: 10,
                    ),
                  ),
                );
                final input = _ScrapeReviewTextField(
                  value: editorValue,
                  label: context.localeText('封面 URL', 'Cover URL'),
                  onChanged: onChanged,
                );
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      preview,
                      const SizedBox(height: 12),
                      input,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    preview,
                    const SizedBox(width: 16),
                    Expanded(child: input),
                  ],
                );
              },
            )
          else if (isBoolean)
            _ScrapeReviewBooleanField(
              value: field.value is bool ? field.value as bool : null,
              onChanged: onChanged,
            )
          else
            _ScrapeReviewTextField(
              value: editorValue,
              label: field.key == 'tags'
                  ? context.localeText('应用值（逗号分隔）', 'Value (comma-separated)')
                  : context.localeText('应用值', 'Value'),
              maxLines: isLongText ? (field.key == 'description' ? 6 : 3) : 1,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _ScrapeReviewTextField extends StatefulWidget {
  const _ScrapeReviewTextField({
    required this.value,
    required this.label,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String value;
  final String label;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<_ScrapeReviewTextField> createState() => _ScrapeReviewTextFieldState();
}

class _ScrapeReviewTextFieldState extends State<_ScrapeReviewTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _ScrapeReviewTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppColors.primary500,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          style: const TextStyle(
            color: AppColors.slate950,
            fontSize: 14,
            height: 1.45,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: context.isDark
                ? AppColors.primary950.withValues(alpha: 0.25)
                : AppColors.primary50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.faintBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.faintBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary600,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrapeReviewBooleanField extends StatelessWidget {
  const _ScrapeReviewBooleanField({
    required this.value,
    required this.onChanged,
  });

  final bool? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.localeText('应用值', 'Value'),
          style: const TextStyle(
            color: AppColors.primary500,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.isDark
                ? AppColors.primary950.withValues(alpha: 0.25)
                : AppColors.primary50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.faintBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value == null
                  ? ''
                  : value == true
                      ? 'true'
                      : 'false',
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: '',
                  enabled: false,
                  child: Text(context.localeText('未知', 'Unknown')),
                ),
                DropdownMenuItem(
                    value: 'true', child: Text(context.localeText('是', 'Yes'))),
                DropdownMenuItem(
                    value: 'false', child: Text(context.localeText('否', 'No'))),
              ],
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}

const _scrapeFieldDefinitions = <String, ({String label, IconData icon})>{
  'title': (label: 'Title', icon: Icons.menu_book_rounded),
  'author': (label: 'Author', icon: Icons.person_rounded),
  'narrator': (label: 'Narrator', icon: Icons.mic_rounded),
  'cover_url': (label: 'Cover', icon: Icons.image_rounded),
  'description': (label: 'Description', icon: Icons.notes_rounded),
  'tags': (label: 'Tags', icon: Icons.local_offer_rounded),
  'genre': (label: 'Genre', icon: Icons.category_rounded),
  'year': (label: 'Year', icon: Icons.calendar_month_rounded),
};

int _scrapeFieldSortIndex(String key) {
  final index = scrapeFieldOrder.indexOf(key);
  return index < 0 ? 999 : index;
}

bool _scrapeFieldIsWide(String key) {
  return key == 'cover_url' || key == 'description' || key == 'tags';
}

String _localizedScrapeFieldLabel(BuildContext context, String key) {
  switch (normalizeScrapeFieldKey(key)) {
    case 'title':
      return context.localeText('书名', 'Title');
    case 'author':
      return context.localeText('作者', 'Author');
    case 'narrator':
      return context.localeText('演播', 'Narrator');
    case 'cover_url':
      return context.localeText('封面', 'Cover');
    case 'description':
      return context.localeText('简介', 'Description');
    case 'tags':
      return context.localeText('标签', 'Tags');
    case 'genre':
      return context.localeText('类型', 'Genre');
    case 'year':
      return context.localeText('年份', 'Year');
    case 'subtitle':
      return context.localeText('副标题', 'Subtitle');
    case 'published_date':
      return context.localeText('发布日期', 'Published');
    case 'publisher':
      return context.localeText('出版社', 'Publisher');
    case 'isbn':
      return 'ISBN';
    case 'asin':
      return 'ASIN';
    case 'language':
      return context.localeText('语言', 'Language');
    case 'explicit':
      return context.localeText('成人内容', 'Explicit');
    case 'abridged':
      return context.localeText('删节版', 'Abridged');
    case 'duration':
      return context.localeText('总时长', 'Duration');
    default:
      return key;
  }
}

String _localizedScrapeResultFieldLabel(
  BuildContext context,
  ScrapeSource source,
  String key,
) {
  final normalized = normalizeScrapeFieldKey(key);
  final declared = source.resultFieldLabels[key]
          ?.resolve(english: context.isEnglishLocale) ??
      source.resultFieldLabels[normalized]
          ?.resolve(english: context.isEnglishLocale);
  if (declared != null && declared.trim().isNotEmpty) {
    return declared.trim();
  }
  return _localizedScrapeFieldLabel(context, normalized);
}

String _localizedScrapeSearchFieldLabel(
  BuildContext context,
  ScrapeSearchField field,
) {
  final declared = field.labelI18n?.resolve(english: context.isEnglishLocale);
  if (declared != null && declared.trim().isNotEmpty) {
    return declared.trim();
  }
  final normalized = normalizeScrapeFieldKey(field.key);
  if (_scrapeFieldDefinitions.containsKey(normalized)) {
    return _localizedScrapeFieldLabel(context, normalized);
  }
  return field.label;
}

String _formatScrapeValueForLocale(
  BuildContext context,
  Object? value, [
  String? emptyZh,
  String? emptyEn,
]) {
  if (!hasScrapeValue(value)) {
    return context.localeText(emptyZh ?? '未返回', emptyEn ?? 'Not returned');
  }
  if (value is Iterable) {
    return value.map((item) => item.toString()).join(' / ');
  }
  if (value is bool) {
    return context.localeText(value ? '是' : '否', value ? 'Yes' : 'No');
  }
  return value.toString();
}

String _scrapeResultTitleForLocale(BuildContext context, ScrapeResult result) {
  return _formatScrapeValueForLocale(
    context,
    scrapeItemValue(result.item, 'title'),
  );
}

String _scrapeResultSubtitleForLocale(
  BuildContext context,
  ScrapeResult result,
) {
  final author = _formatScrapeValueForLocale(
    context,
    scrapeItemValue(result.item, 'author'),
    '',
    '',
  );
  final narrator = _formatScrapeValueForLocale(
    context,
    scrapeItemValue(result.item, 'narrator'),
    '',
    '',
  );
  return [author, narrator].where((value) => value.isNotEmpty).join(' / ');
}

String _scrapeCountText(
  BuildContext context,
  int count,
  String zhUnit,
  String enSingular,
  String enPlural,
) {
  if (!context.isEnglishLocale) return '$count $zhUnit';
  return '$count ${count == 1 ? enSingular : enPlural}';
}

String _scrapeSummaryText(
  BuildContext context, {
  required int pluginCount,
  required int resultCount,
  required int selectedCount,
}) {
  if (!context.isEnglishLocale) {
    return '$pluginCount 个插件 · $resultCount 条结果 · 已选择 $selectedCount 个字段';
  }
  final plugins = pluginCount == 1 ? 'plugin' : 'plugins';
  final results = resultCount == 1 ? 'result' : 'results';
  final fields = selectedCount == 1 ? 'field' : 'fields';
  return '$pluginCount $plugins · $resultCount $results · $selectedCount $fields selected';
}
