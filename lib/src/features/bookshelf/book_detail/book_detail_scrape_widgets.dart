part of 'book_detail_scrape.dart';

class _ScrapeHeader extends StatelessWidget {
  const _ScrapeHeader({
    required this.step,
    required this.selectedCount,
    required this.resultsCount,
    required this.searching,
    required this.onStep,
    required this.onClose,
  });

  final String step;
  final int selectedCount;
  final int resultsCount;
  final bool searching;
  final ValueChanged<String> onStep;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('search', context.localeText('搜索条件', 'Search Conditions')),
      ('results', context.localeText('选择字段', 'Select Fields')),
      ('review', context.localeText('确认应用', 'Review & Apply')),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(bottom: BorderSide(color: context.faintBorder)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.refresh_rounded, color: AppColors.primary600),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.localeText('手动刮削', 'Manual Scrape'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _ScrapeStepButton(
                      index: i + 1,
                      label: items[i].$2,
                      selected: step == items[i].$1,
                      enabled: items[i].$1 == 'search' ||
                          step == items[i].$1 ||
                          (items[i].$1 == 'results' && resultsCount > 0) ||
                          (items[i].$1 == 'review' && !searching),
                      onTap: () => onStep(items[i].$1),
                    ),
                    if (i != items.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.slate300,
                          size: 18,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrapeScrollArea extends StatelessWidget {
  const _ScrapeScrollArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1152),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ScrapeStepButton extends StatelessWidget {
  const _ScrapeStepButton({
    required this.index,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onTap : null,
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? AppColors.primary600
            : (enabled
                ? (context.isDark ? AppColors.slate900 : AppColors.slate100)
                : (context.isDark
                    ? AppColors.slate900.withValues(alpha: 0.55)
                    : AppColors.slate50)),
        foregroundColor: selected
            ? Colors.white
            : (enabled
                ? (context.isDark ? AppColors.slate300 : AppColors.slate600)
                : AppColors.slate300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.18)
                  : context.cardColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ScrapeSectionLabel extends StatelessWidget {
  const _ScrapeSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.tertiaryText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ScrapePanel extends StatelessWidget {
  const _ScrapePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: child,
    );
  }
}

class _ScrapeSearchAside extends StatelessWidget {
  const _ScrapeSearchAside({
    required this.book,
    required this.source,
    required this.selectedFields,
  });

  final Book book;
  final ScrapeSource? source;
  final Map<String, SelectedScrapeField> selectedFields;

  Object? _draftField(String key) {
    final selected = selectedFields[key]?.value;
    if (selected != null) return selected;
    switch (key) {
      case 'title':
        return book.title;
      case 'author':
        return book.author;
      case 'narrator':
        return book.narrator;
      case 'cover_url':
        return book.coverUrl;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceValue = source;
    final appState = AppScope.appOf(context);
    final fields = sourceValue?.resultFields ?? const <String>[];
    final draftCoverUrl = coverUrl(
      appState,
      url: _draftField('cover_url')?.toString(),
      libraryId: book.libraryId,
      bookId: book.id,
    );
    final authorText = _formatScrapeValueForLocale(
      context,
      _draftField('author'),
      '未填写',
      'Not set',
    );
    final narratorText = _formatScrapeValueForLocale(
      context,
      _draftField('narrator'),
      '未填写',
      'Not set',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScrapePanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 82,
                height: 112,
                child: CoverImage(
                  url: draftCoverUrl,
                  radius: 10,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ScrapeSectionLabel(
                        context.localeText('当前书籍', 'Current Book')),
                    const SizedBox(height: 8),
                    Text(
                      formatScrapeValue(_draftField('title'), book.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.localeText(
                          '作者：$authorText', 'Author: $authorText'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.mutedText, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.localeText(
                          '演播：$narratorText', 'Narrator: $narratorText'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ScrapePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScrapeSectionLabel(
                  context.localeText('当前插件返回字段', 'Plugin Fields')),
              const SizedBox(height: 12),
              if (fields.isEmpty)
                Text(
                  context.localeText('未声明返回字段', 'No declared fields'),
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (sourceValue != null)
                      for (final key in fields)
                        _ScrapeReturnFieldPill(
                            source: sourceValue, keyName: key),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScrapeReturnFieldPill extends StatelessWidget {
  const _ScrapeReturnFieldPill({
    required this.source,
    required this.keyName,
  });

  final ScrapeSource source;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final definition = _scrapeFieldDefinitions[keyName];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.slate950 : AppColors.slate100,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            definition?.icon ?? Icons.info_outline_rounded,
            size: 14,
            color: context.tertiaryText,
          ),
          const SizedBox(width: 6),
          Text(
            _localizedScrapeResultFieldLabel(context, source, keyName),
            style: TextStyle(
              color: context.isDark ? AppColors.slate300 : AppColors.slate600,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrapeSourceTile extends StatelessWidget {
  const _ScrapeSourceTile({
    required this.source,
    required this.active,
    required this.enabled,
    required this.onToggle,
    required this.onTap,
  });

  final ScrapeSource source;
  final bool active;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary50
            : (context.isDark ? AppColors.slate950 : AppColors.slate50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.primary200 : context.faintBorder,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: enabled ? AppColors.primary600 : AppColors.slate300,
                borderRadius: BorderRadius.circular(99),
              ),
              alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    source.searchFields
                        .map((field) =>
                            _localizedScrapeSearchFieldLabel(context, field))
                        .join(' / '),
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
          ),
        ],
      ),
    );
  }
}

class _ScrapeSearchForm extends StatelessWidget {
  const _ScrapeSearchForm({
    required this.source,
    required this.controllers,
    required this.enabled,
    required this.onToggle,
    required this.onFieldChanged,
  });

  final ScrapeSource source;
  final Map<String, TextEditingController> controllers;
  final bool enabled;
  final VoidCallback onToggle;
  final void Function(ScrapeSearchField field, String value) onFieldChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScrapeSectionLabel(
                      context.localeText('搜索参数', 'Search Parameters')),
                ],
              ),
            ),
            TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                backgroundColor:
                    enabled ? AppColors.primary600 : AppColors.slate100,
                foregroundColor: enabled ? Colors.white : AppColors.slate500,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(enabled
                  ? context.localeText('已启用', 'Enabled')
                  : context.localeText('未启用', 'Disabled')),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          source.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        for (final field in source.searchFields) ...[
          Text(
            '${_localizedScrapeSearchFieldLabel(context, field)}${field.required ? ' *' : ''}',
            style: TextStyle(
              color: context.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controllers[field.key],
            onChanged: (value) => onFieldChanged(field, value),
            decoration: InputDecoration(
              hintText: field.placeholder ?? '',
              isDense: true,
              filled: true,
              fillColor:
                  context.isDark ? AppColors.slate950 : AppColors.slate50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ScrapeSummaryCard extends StatelessWidget {
  const _ScrapeSummaryCard({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabelValue = actionLabel;
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: context.mutedText)),
              ],
            ),
          ),
          if (actionLabelValue != null)
            OutlinedButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.tune_rounded, size: 16),
              label: Text(actionLabelValue),
            ),
        ],
      ),
    );
  }
}

class _ScrapeNotice extends StatelessWidget {
  const _ScrapeNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xfffffbeb),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xfffde68a)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xffb45309),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
