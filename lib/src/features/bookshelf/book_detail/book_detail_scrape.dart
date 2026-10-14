import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/state/scrape_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/locale.dart';
import '../../../core/utils/urls.dart';
import '../../../shared/app_scope.dart';
import '../../../shared/cards/book_card.dart';
import '../../../shared/common/common_widgets.dart';
import '../../../shared/common/media_widgets.dart';

part 'book_detail_scrape_compare.dart';
part 'book_detail_scrape_widgets.dart';

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

class ScrapeDiffDialog extends StatefulWidget {
  const ScrapeDiffDialog({super.key, required this.bookId});

  final String bookId;

  @override
  State<ScrapeDiffDialog> createState() => _ScrapeDiffDialogState();
}

class _ScrapeDiffDialogState extends State<ScrapeDiffDialog> {
  ScrapeState? _session;
  Book? get _book => _session?.book;
  List<ScrapeSource> get _sources => _session?.sources ?? const [];
  Set<String> get _enabledSourceIds => _session!.enabledSources;
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  List<ScrapeResult> get _results => _session?.results ?? const [];
  Map<String, SelectedScrapeField> get _selectedFields =>
      _session!.selectedFields;
  final Set<String> _expandedScrapeDescriptions = {};
  String? _activeSourceId;
  String _resultView = 'list';
  int? _selectedResultIndex;
  String _step = 'search';
  bool get _loading => _session?.loading ?? true;
  bool get _searching => _session?.searching ?? false;
  bool get _saving => _session?.saving ?? false;
  String? get _error => _session?.error;
  set _error(String? value) {
    _session?.error = value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session != null) return;
    _session = ScrapeState(AppScope.appOf(context).api, widget.bookId)
      ..addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session?.removeListener(_sessionChanged);
    _session?.dispose();
    for (final sourceControllers in _controllers.values) {
      for (final controller in sourceControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    await _session?.load();
    final book = _book;
    if (!mounted || book == null) return;
    setState(() {
      _activeSourceId = _sources
              .where((source) => _enabledSourceIds.contains(source.id))
              .firstOrNull
              ?.id ??
          _sources.firstOrNull?.id;
      for (final source in _sources) {
        _controllers[source.id] = {
          for (final field in source.searchFields)
            field.key:
                TextEditingController(text: bookDefaultScrapeValue(book, field))
        };
      }
    });
  }

  ScrapeSource? get _activeSource {
    final activeId = _activeSourceId;
    if (activeId == null) return _sources.isEmpty ? null : _sources.first;
    return _sources.where((source) => source.id == activeId).firstOrNull;
  }

  int get _selectedCount => _selectedFields.length;
  int get _filledSelectedCount => _selectedFields.values
      .where((field) => hasScrapeValue(field.value))
      .length;

  Future<void> _search() async {
    if (_enabledSourceIds.isEmpty) {
      setState(() => _error =
          context.localeText('请至少启用一个插件', 'Enable at least one plugin'));
      return;
    }
    for (final source
        in _sources.where((s) => _enabledSourceIds.contains(s.id))) {
      for (final field in source.searchFields) {
        if (!field.required) continue;
        final value = _controllers[source.id]?[field.key]?.text.trim() ?? '';
        if (value.isEmpty) {
          setState(() {
            _activeSourceId = source.id;
            _step = 'search';
            final label = _localizedScrapeSearchFieldLabel(context, field);
            _error = context.localeText('${source.name} 的 $label 不能为空',
                '${source.name}: $label is required');
          });
          return;
        }
      }
    }
    setState(() {
      _resultView = 'list';
      _selectedResultIndex = null;
      _expandedScrapeDescriptions.clear();
    });
    final completed = await _session?.search({
      for (final source in _sources)
        source.id: {
          for (final entry in (_controllers[source.id] ?? {}).entries)
            entry.key: entry.value.text.trim(),
        }
    });
    if (mounted && completed == true) {
      setState(() {
        _step = 'results';
      });
    }
  }

  void _clearScrapeResults() {
    _session?.clearResults();
    _resultView = 'list';
    _selectedResultIndex = null;
    _expandedScrapeDescriptions.clear();
    _error = null;
  }

  void _handleSearchValueChanged(
    ScrapeSource source,
    ScrapeSearchField field,
    String value,
  ) {
    final sharedKind = sharedScrapeSearchKind(field);
    setState(() {
      _clearScrapeResults();
      if (sharedKind == null) return;
      for (final targetSource in _sources) {
        for (final targetField in targetSource.searchFields) {
          if (sharedScrapeSearchKind(targetField) != sharedKind) continue;
          if (targetSource.id == source.id && targetField.key == field.key) {
            continue;
          }
          final controller = _controllers[targetSource.id]?[targetField.key];
          if (controller == null || controller.text == value) continue;
          controller.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          );
        }
      }
    });
  }

  void _openResultDetail(int index) {
    setState(() {
      _selectedResultIndex = index;
      _resultView = 'detail';
    });
  }

  void _toggleScrapeDescription(String key) {
    setState(() {
      if (_expandedScrapeDescriptions.contains(key)) {
        _expandedScrapeDescriptions.remove(key);
      } else {
        _expandedScrapeDescriptions.add(key);
      }
    });
  }

  void _toggleField(ScrapeResult result, String key) {
    setState(() => _session?.select(
        result,
        key,
        _localizedScrapeResultFieldLabel(context, result.source, key),
        _formatScrapeValueForLocale(
            context, scrapeItemValue(result.item, 'title'))));
  }

  void _selectAll(ScrapeResult result) {
    setState(() {
      for (final key in result.source.resultFields) {
        _session?.select(
            result,
            key,
            _localizedScrapeResultFieldLabel(context, result.source, key),
            _formatScrapeValueForLocale(
                context, scrapeItemValue(result.item, 'title')));
      }
    });
  }

  void _updateSelectedField(String key, String value) {
    setState(() => _session?.edit(
        key,
        value,
        _localizedScrapeFieldLabel(context, key),
        context.localeText('手动填写', 'Manual edit')));
  }

  Future<void> _apply() async {
    if (await _session?.apply() == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Dialog(
        child: SizedBox(
          width: 320,
          height: 180,
          child:
              LoadingView(label: context.localeText('正在加载...', 'Loading...')),
        ),
      );
    }
    if (_book == null || _sources.isEmpty) {
      return AlertDialog(
        title: Text(context.localeText('没有可用插件', 'No Plugins Available')),
        content: Text(_error ??
            context.localeText('请先在插件管理中启用刮削插件。',
                'Enable a scraper plugin in plugin management first.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonClose),
          ),
        ],
      );
    }

    final compact = MediaQuery.sizeOf(context).width < 760;
    return Dialog(
      insetPadding: EdgeInsets.all(compact ? 4 : 8),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FractionallySizedBox(
        heightFactor: compact ? 0.98 : 0.92,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1152),
          child: Container(
            decoration: BoxDecoration(
              color: context.isDark ? AppColors.slate950 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: context.isDark ? 0.36 : 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _ScrapeHeader(
                  step: _step,
                  selectedCount: _selectedCount,
                  resultsCount: _results.length,
                  searching: _searching,
                  onStep: (step) => setState(() => _step = step),
                  onClose: _saving ? null : () => Navigator.pop(context, false),
                ),
                Expanded(
                  child: ColoredBox(
                    color:
                        context.isDark ? AppColors.slate950 : AppColors.slate50,
                    child: _step == 'search'
                        ? _buildSearchStep()
                        : _step == 'results'
                            ? _buildResultsStep()
                            : _buildReviewStep(),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchStep() {
    final active = _activeSource;
    return _ScrapeScrollArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showAside = constraints.maxWidth >= 900;
          final main = _ScrapePanel(
            child: LayoutBuilder(
              builder: (context, panelConstraints) {
                final stack = panelConstraints.maxWidth < 720;
                final sources = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _ScrapeSectionLabel(context.localeText(
                                '本次启用插件', 'Enabled plugins'))),
                        Text(
                          _scrapeCountText(context, _enabledSourceIds.length,
                              '个', 'plugin', 'plugins'),
                          style: const TextStyle(
                            color: AppColors.primary600,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final source in _sources)
                      _ScrapeSourceTile(
                        source: source,
                        active: active?.id == source.id,
                        enabled: _enabledSourceIds.contains(source.id),
                        onToggle: () => setState(() {
                          _clearScrapeResults();
                          if (_enabledSourceIds.contains(source.id)) {
                            _enabledSourceIds.remove(source.id);
                          } else {
                            _enabledSourceIds.add(source.id);
                          }
                        }),
                        onTap: () =>
                            setState(() => _activeSourceId = source.id),
                      ),
                  ],
                );
                final form = active == null
                    ? EmptyState(
                        icon: Icons.extension_off_rounded,
                        title:
                            context.localeText('未选择插件', 'No Plugin Selected'),
                        message: context.localeText(
                            '请选择一个刮削插件。', 'Choose a scraper plugin.'),
                      )
                    : _ScrapeSearchForm(
                        source: active,
                        controllers: _controllers[active.id] ?? {},
                        enabled: _enabledSourceIds.contains(active.id),
                        onToggle: () => setState(() {
                          _clearScrapeResults();
                          if (_enabledSourceIds.contains(active.id)) {
                            _enabledSourceIds.remove(active.id);
                          } else {
                            _enabledSourceIds.add(active.id);
                          }
                        }),
                        onFieldChanged: (field, value) =>
                            _handleSearchValueChanged(active, field, value),
                      );
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      sources,
                      const SizedBox(height: 18),
                      form,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 260, child: sources),
                    const SizedBox(width: 20),
                    Expanded(child: form),
                  ],
                );
              },
            ),
          );

          final aside = _ScrapeSearchAside(
            book: _book!,
            source: active,
            selectedFields: _selectedFields,
          );

          if (!showAside) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                main,
                const SizedBox(height: 16),
                aside,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              const SizedBox(width: 16),
              SizedBox(width: 320, child: aside),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResultsStep() {
    final selectedResult = _selectedResultIndex == null
        ? null
        : (_selectedResultIndex! >= 0 && _selectedResultIndex! < _results.length
            ? _results[_selectedResultIndex!]
            : null);
    if (_resultView == 'detail' && selectedResult != null) {
      return _buildResultDetailStep(selectedResult);
    }

    return _ScrapeScrollArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScrapeSummaryCard(
            title: context.localeText('搜索结果', 'Search Results'),
            subtitle: _scrapeSummaryText(context,
                pluginCount: _enabledSourceIds.length,
                resultCount: _results.length,
                selectedCount: _selectedCount),
            actionLabel: context.localeText('修改搜索', 'Edit Search'),
            actionIcon: Icons.arrow_back_rounded,
            onAction: () => setState(() => _step = 'search'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ScrapeNotice(message: _error!),
          ],
          const SizedBox(height: 14),
          if (_searching)
            SizedBox(
                height: 260,
                child: LoadingView(
                    label: context.localeText('搜索中...', 'Searching...')))
          else if (_results.isEmpty)
            EmptyState(
              icon: Icons.search_off_rounded,
              title: context.localeText('暂无搜索结果', 'No Results'),
              message: context.localeText(
                  '换一个插件或关键词试试。', 'Try another plugin or keyword.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 920
                    ? 3
                    : constraints.maxWidth > 620
                        ? 2
                        : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 156,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return _ScrapeResultCard(
                      result: result,
                      selectedFields: _selectedFields,
                      onOpen: () => _openResultDetail(index),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildResultDetailStep(ScrapeResult result) {
    final cover = scrapeItemValue(result.item, 'cover_url')?.toString() ?? '';
    final fields = [...result.source.resultFields]..sort(
        (a, b) => _scrapeFieldSortIndex(a).compareTo(_scrapeFieldSortIndex(b)));
    final book = _book!;

    return _ScrapeScrollArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _resultView = 'list'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(context.localeText('返回搜索结果', 'Back to Results')),
              style: TextButton.styleFrom(
                backgroundColor:
                    context.isDark ? AppColors.slate900 : Colors.white,
                foregroundColor:
                    context.isDark ? AppColors.slate300 : AppColors.slate600,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.faintBorder),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ScrapeNotice(message: _error!),
          ],
          const SizedBox(height: 14),
          _ScrapePanel(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 620;
                final coverWidget = SizedBox(
                  width: 112,
                  height: 160,
                  child: CoverImage(url: cover, radius: 12),
                );
                final info = Column(
                  crossAxisAlignment: stack
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? AppColors.slate950
                            : AppColors.slate100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        result.source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slate500,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _scrapeResultTitleForLocale(context, result),
                      textAlign: stack ? TextAlign.center : TextAlign.left,
                      style: const TextStyle(
                        color: AppColors.slate900,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.externalId,
                      textAlign: stack ? TextAlign.center : TextAlign.left,
                      style: const TextStyle(
                        color: AppColors.slate500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
                final applyAll = ElevatedButton.icon(
                  onPressed: fields.isEmpty ? null : () => _selectAll(result),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        context.isDark ? Colors.white : AppColors.slate950,
                    foregroundColor:
                        context.isDark ? AppColors.slate950 : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: Text(context.localeText('采用全部', 'Use All')),
                );
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      coverWidget,
                      const SizedBox(height: 14),
                      info,
                      const SizedBox(height: 16),
                      applyAll,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    coverWidget,
                    const SizedBox(width: 16),
                    Expanded(child: info),
                    const SizedBox(width: 16),
                    applyAll,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          if (fields.isEmpty)
            EmptyState(
              icon: Icons.fact_check_outlined,
              title: context.localeText('没有可应用字段', 'No Applicable Fields'),
              message: context.localeText('这个结果没有返回可写入书籍的字段。',
                  'This result has no fields that can be written to the book.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 860;
                return _buildResultFieldLayout(
                  book: book,
                  result: result,
                  fields: fields,
                  twoColumns: twoColumns,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildResultFieldTile(Book book, ScrapeResult result, String key) {
    final selected = _selectedFields[key]?.resultKey == result.key &&
        _selectedFields[key]?.sourceId == result.source.id;
    final selectedFromOther = _selectedFields[key] != null && !selected;
    final expandKey = '${result.key}:$key';
    return _ScrapeResultFieldTile(
      book: book,
      result: result,
      selectedFields: _selectedFields,
      keyName: key,
      selected: selected,
      selectedFromOther: selectedFromOther,
      expanded: _expandedScrapeDescriptions.contains(expandKey),
      onToggleExpanded: () => _toggleScrapeDescription(expandKey),
      onTap: () => _toggleField(result, key),
    );
  }

  Widget _buildResultFieldLayout({
    required Book book,
    required ScrapeResult result,
    required List<String> fields,
    required bool twoColumns,
  }) {
    if (!twoColumns) {
      return Column(
        children: [
          for (final key in fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildResultFieldTile(book, result, key),
            ),
        ],
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i++) {
      final first = fields[i];
      if (_scrapeFieldIsWide(first)) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildResultFieldTile(book, result, first),
          ),
        );
        continue;
      }

      String? second;
      if (i + 1 < fields.length && !_scrapeFieldIsWide(fields[i + 1])) {
        second = fields[i + 1];
        i++;
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildResultFieldTile(book, result, first)),
              const SizedBox(width: 12),
              Expanded(
                child: second == null
                    ? const SizedBox.shrink()
                    : _buildResultFieldTile(book, result, second),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildReviewStep() {
    final book = _book;
    if (book == null) return const SizedBox.shrink();
    return _ScrapeScrollArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScrapeSummaryCard(
            title: context.localeText('确认书籍信息', 'Review Book Information'),
            subtitle: _scrapeCountText(context, _selectedCount, '个字段待保存',
                'field to save', 'fields to save'),
            actionLabel: context.localeText('清空', 'Clear'),
            actionIcon: Icons.delete_outline_rounded,
            onAction: _selectedFields.isEmpty
                ? null
                : () => setState(() => _selectedFields.clear()),
          ),
          const SizedBox(height: 10),
          Text(
            context.localeText(
              '未修改的项保留当前值。未刮到的信息可以直接补填，编辑后会加入本次保存。',
              'Unchanged fields keep their current values. Fill in missing information here to include it in this save.',
            ),
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              for (final key in scrapeFieldOrder)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SelectedScrapeFieldCard(
                    key: ValueKey('scrape-review-$key'),
                    book: book,
                    selected: _selectedFields.containsKey(key),
                    field: _selectedFields[key] ??
                        SelectedScrapeField(
                          key: key,
                          label: _localizedScrapeFieldLabel(context, key),
                          value: bookScrapeFieldValue(book, key) ?? '',
                          sourceId: '',
                          sourceName: '',
                          resultId: '',
                          resultKey: '',
                          resultTitle: '',
                        ),
                    onChanged: (value) => _updateSelectedField(key, value),
                    onRemove: () => setState(() => _selectedFields.remove(key)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(top: BorderSide(color: context.faintBorder)),
      ),
      child: Row(
        children: [
          Text(
            _scrapeCountText(context, _selectedCount, '个字段', 'field selected',
                'fields selected'),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (_step == 'search') ...[
            TextButton(
              onPressed:
                  _searching ? null : () => Navigator.pop(context, false),
              child: Text(context.l10n.commonCancel),
            ),
            const SizedBox(width: 10),
            PrimaryButton(
              label: context.isEnglishLocale
                  ? 'Search ${_enabledSourceIds.length} ${_enabledSourceIds.length == 1 ? 'plugin' : 'plugins'}'
                  : '搜索 ${_enabledSourceIds.length} 个插件',
              icon: Icons.search_rounded,
              loading: _searching,
              onPressed: _enabledSourceIds.isEmpty ? null : _search,
            ),
          ] else if (_step == 'results') ...[
            TextButton.icon(
              onPressed: () => setState(() {
                if (_resultView == 'detail') {
                  _resultView = 'list';
                } else {
                  _step = 'search';
                }
              }),
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(_resultView == 'detail'
                  ? context.localeText('搜索结果', 'Search Results')
                  : context.localeText('搜索条件', 'Search Conditions')),
            ),
            const SizedBox(width: 10),
            PrimaryButton(
              label: context.localeText('确认应用', 'Review & Apply'),
              icon: Icons.arrow_forward_rounded,
              onPressed:
                  _searching ? null : () => setState(() => _step = 'review'),
            ),
          ] else ...[
            TextButton.icon(
              onPressed: () => setState(() => _step = 'results'),
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(context.localeText('返回', 'Back')),
            ),
            const SizedBox(width: 10),
            PrimaryButton(
              label: context.localeText('应用', 'Apply'),
              icon: Icons.save_rounded,
              loading: _saving,
              onPressed: _filledSelectedCount == 0 ? null : _apply,
            ),
          ],
        ],
      ),
    );
  }
}
