part of 'book_detail_page.dart';

class _ScrapeHeader extends StatelessWidget {
  const _ScrapeHeader({
    required this.step,
    required this.selectedCount,
    required this.resultsCount,
    required this.onStep,
    required this.onClose,
  });

  final String step;
  final int selectedCount;
  final int resultsCount;
  final ValueChanged<String> onStep;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('search', '搜索条件'),
      ('results', '选择字段'),
      ('review', '确认应用'),
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
              const Expanded(
                child: Text(
                  '手动刮削',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                          (items[i].$1 == 'review' && selectedCount > 0),
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
              color:
                  selected ? Colors.white.withValues(alpha: 0.18) : context.cardColor,
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
            color: Colors.black.withValues(alpha: context.isDark ? 0.12 : 0.035),
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
  final _ScrapeSource? source;
  final Map<String, _SelectedScrapeField> selectedFields;

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
    final fields = source?.resultFields ?? const <String>[];
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
                  url: _draftField('cover_url')?.toString() ?? '',
                  radius: 10,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ScrapeSectionLabel('当前书籍'),
                    const SizedBox(height: 8),
                    Text(
                      _formatScrapeValue(_draftField('title'), book.title),
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
                      '作者：${_formatScrapeValue(_draftField('author'), '未填写')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.mutedText, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '演播：${_formatScrapeValue(_draftField('narrator'), '未填写')}',
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
              const _ScrapeSectionLabel('当前插件返回字段'),
              const SizedBox(height: 12),
              if (fields.isEmpty)
                Text(
                  '未声明返回字段',
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final key in fields)
                      _ScrapeReturnFieldPill(keyName: key),
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
  const _ScrapeReturnFieldPill({required this.keyName});

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
            definition?.label ?? keyName,
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

  final _ScrapeSource source;
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
                    source.searchFields.map((field) => field.label).join(' / '),
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

  final _ScrapeSource source;
  final Map<String, TextEditingController> controllers;
  final bool enabled;
  final VoidCallback onToggle;
  final void Function(_ScrapeSearchField field, String value) onFieldChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScrapeSectionLabel('搜索参数'),
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
              child: Text(enabled ? '已启用' : '未启用'),
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
            '${field.label}${field.required ? ' *' : ''}',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.faintBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.12 : 0.035),
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
          if (actionLabel != null)
            OutlinedButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.tune_rounded, size: 16),
              label: Text(actionLabel!),
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

class _ScrapeResultCard extends StatelessWidget {
  const _ScrapeResultCard({
    required this.result,
    required this.selectedFields,
    required this.onOpen,
  });

  final _ScrapeResult result;
  final Map<String, _SelectedScrapeField> selectedFields;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final coverShape =
        coverShapeFromAppSettings(AppScope.appOf(context).settings);
    final cover = _scrapeItemValue(result.item, 'cover_url')?.toString() ?? '';
    final fields = result.source.resultFields
        .where((key) => _hasScrapeValue(_scrapeItemValue(result.item, key)))
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
                color: Colors.black.withValues(alpha: context.isDark ? 0.12 : 0.035),
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
                          result.title,
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
                          result.subtitle.isEmpty
                              ? '未返回作者/演播'
                              : result.subtitle,
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
                      label: _scrapeFieldDefinitions[key]?.label ?? key,
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
  final _ScrapeResult result;
  final Map<String, _SelectedScrapeField> selectedFields;
  final String keyName;
  final bool selected;
  final bool selectedFromOther;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final definition = _scrapeFieldDefinitions[keyName];
    final value = _scrapeItemValue(result.item, keyName);
    final hasValue = _hasScrapeValue(value);
    final currentValue = _draftScrapeFieldValue(book, selectedFields, keyName);
    final label = definition?.label ?? keyName;
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
            color: Colors.black.withValues(alpha: context.isDark ? 0.12 : 0.035),
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
                      ? '已采用'
                      : selectedFromOther
                          ? '替换'
                          : '采用',
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
                  label: '当前',
                  value: currentValue,
                  color: AppColors.slate400,
                  book: book,
                );
                final next = _ScrapeCoverCompare(
                  label: '应用',
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
                  label: '当前',
                  value: _formatScrapeValue(currentValue, '未知'),
                  color: AppColors.slate400,
                  backgroundColor:
                      context.isDark ? AppColors.slate950 : AppColors.slate50,
                  foregroundColor: AppColors.slate500,
                  maxLines: isDescription ? 3 : 2,
                ),
                const SizedBox(height: 10),
                _ScrapeValueCompare(
                  label: '应用',
                  value: _formatScrapeValue(value),
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
          if (isDescription && _hasScrapeValue(value)) ...[
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
                child: Text(expanded ? '收起' : '展开'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
