part of 'book_detail_page.dart';

class _ScrapeSource {
  const _ScrapeSource({
    required this.id,
    required this.name,
    required this.enabled,
    required this.autoScrape,
    required this.searchFields,
    required this.resultFields,
  });

  final String id;
  final String name;
  final bool enabled;
  final bool autoScrape;
  final List<_ScrapeSearchField> searchFields;
  final List<String> resultFields;

  factory _ScrapeSource.fromJson(Map<String, dynamic> json) {
    final fields = asMapList(json['searchFields'] ?? json['search_fields'])
        .map(_ScrapeSearchField.fromJson)
        .toList();
    final rawResultFields = json['resultFields'] ?? json['result_fields'];
    final resultFields = _scrapeStringList(rawResultFields)
        .map(_normalizeScrapeFieldKey)
        .where(_scrapeFieldDefinitions.containsKey)
        .toSet()
        .toList();
    return _ScrapeSource(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '插件',
      enabled: json['enabled'] == true,
      autoScrape: json['autoScrape'] == true || json['auto_scrape'] == true,
      searchFields: fields.isEmpty ? _defaultScrapeSearchFields : fields,
      resultFields: resultFields.isEmpty ? _scrapeFieldOrder : resultFields,
    );
  }
}

class _ScrapeSearchField {
  const _ScrapeSearchField({
    required this.key,
    required this.label,
    required this.required,
    required this.defaultFrom,
    this.placeholder,
  });

  final String key;
  final String label;
  final bool required;
  final String defaultFrom;
  final String? placeholder;

  factory _ScrapeSearchField.fromJson(Map<String, dynamic> json) {
    return _ScrapeSearchField(
      key: json['key']?.toString() ?? 'title',
      label: json['label']?.toString() ?? _scrapeFieldLabel(json['key']),
      required: json['required'] == true,
      defaultFrom:
          (json['defaultFrom'] ?? json['default_from'] ?? json['key'] ?? '')
              .toString(),
      placeholder: json['placeholder']?.toString(),
    );
  }
}

class _ScrapeResult {
  const _ScrapeResult({
    required this.item,
    required this.source,
    required this.index,
  });

  final Map<String, dynamic> item;
  final _ScrapeSource source;
  final int index;

  String get key => '${source.id}:${item['id'] ?? 'result'}:$index';
  String get externalId => item['id']?.toString() ?? 'result-${index + 1}';
  String get title => _formatScrapeValue(_scrapeItemValue(item, 'title'));
  String get subtitle {
    final author = _formatScrapeValue(_scrapeItemValue(item, 'author'), '');
    final narrator = _formatScrapeValue(_scrapeItemValue(item, 'narrator'), '');
    return [author, narrator].where((value) => value.isNotEmpty).join(' / ');
  }
}

class _SelectedScrapeField {
  _SelectedScrapeField({
    required this.key,
    required this.label,
    required this.value,
    required this.sourceId,
    required this.sourceName,
    required this.resultId,
    required this.resultKey,
    required this.resultTitle,
  });

  final String key;
  final String label;
  Object value;
  final String sourceId;
  final String sourceName;
  final String resultId;
  final String resultKey;
  final String resultTitle;
}

const _defaultScrapeSearchFields = [
  _ScrapeSearchField(
    key: 'title',
    label: '书名',
    required: true,
    defaultFrom: 'book.title',
  ),
  _ScrapeSearchField(
    key: 'author',
    label: '作者',
    required: false,
    defaultFrom: 'book.author',
  ),
  _ScrapeSearchField(
    key: 'narrator',
    label: '演播',
    required: false,
    defaultFrom: 'book.narrator',
  ),
];

const _scrapeFieldDefinitions = <String, ({String label, IconData icon})>{
  'title': (label: '书名', icon: Icons.menu_book_rounded),
  'author': (label: '作者', icon: Icons.person_rounded),
  'narrator': (label: '演播', icon: Icons.mic_rounded),
  'cover_url': (label: '封面', icon: Icons.image_rounded),
  'description': (label: '简介', icon: Icons.notes_rounded),
  'tags': (label: '标签', icon: Icons.local_offer_rounded),
  'genre': (label: '类型', icon: Icons.category_rounded),
  'year': (label: '年份', icon: Icons.calendar_month_rounded),
  'subtitle': (label: '副标题', icon: Icons.subtitles_rounded),
  'published_date': (label: '发布日期', icon: Icons.event_rounded),
  'publisher': (label: '出版社', icon: Icons.apartment_rounded),
  'isbn': (label: 'ISBN', icon: Icons.tag_rounded),
  'asin': (label: 'ASIN', icon: Icons.tag_rounded),
  'language': (label: '语言', icon: Icons.language_rounded),
  'explicit': (label: '成人内容', icon: Icons.verified_rounded),
  'abridged': (label: '删节版', icon: Icons.verified_rounded),
  'duration': (label: '总时长', icon: Icons.timer_rounded),
};

const _scrapeFieldOrder = [
  'title',
  'author',
  'narrator',
  'cover_url',
  'description',
  'tags',
  'genre',
  'year',
  'subtitle',
  'published_date',
  'publisher',
  'isbn',
  'asin',
  'language',
  'explicit',
  'abridged',
  'duration',
];

int _scrapeFieldSortIndex(String key) {
  final index = _scrapeFieldOrder.indexOf(key);
  return index < 0 ? 999 : index;
}

bool _scrapeFieldIsWide(String key) {
  return key == 'cover_url' || key == 'description' || key == 'tags';
}

String _normalizeScrapeFieldKey(String key) {
  final normalized = key
      .replaceAllMapped(
          RegExp('[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}')
      .toLowerCase();
  if (normalized == 'intro') return 'description';
  if (normalized == 'published_year') return 'year';
  return normalized;
}

String _scrapeFieldLabel(Object? key) {
  final normalized = _normalizeScrapeFieldKey(key?.toString() ?? '');
  return _scrapeFieldDefinitions[normalized]?.label ?? (key?.toString() ?? '');
}

List<String> _scrapeStringList(Object? value) {
  if (value is Iterable) return value.map((item) => item.toString()).toList();
  if (value is String && value.trim().isNotEmpty) return [value.trim()];
  return const [];
}

Object? _scrapeItemValue(Map<String, dynamic> item, String fieldKey) {
  switch (fieldKey) {
    case 'cover_url':
      return item['coverUrl'] ?? item['cover_url'];
    case 'description':
      return item['description'] ?? item['intro'];
    case 'year':
      return item['publishedYear'] ?? item['published_year'] ?? item['year'];
    case 'published_date':
      return item['publishedDate'] ?? item['published_date'];
    default:
      return item[fieldKey];
  }
}

bool _hasScrapeValue(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  return true;
}

String _formatScrapeValue(Object? value, [String emptyLabel = '未返回']) {
  if (!_hasScrapeValue(value)) return emptyLabel;
  if (value is Iterable) {
    return value.map((item) => item.toString()).join(' / ');
  }
  if (value is bool) return value ? '是' : '否';
  return value.toString();
}

Object _scrapeValueForApi(Object value) {
  if (value is Iterable && value is! String) {
    return value.map((item) => item.toString()).toList();
  }
  return value;
}

String _scrapeValueForEditor(Object? value) {
  if (!_hasScrapeValue(value)) return '';
  if (value is Iterable && value is! String) {
    return value.map((item) => item.toString()).join(', ');
  }
  return value.toString();
}

Object _scrapeEditorValueForField(String fieldKey, String value) {
  if (fieldKey == 'tags') {
    return value
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }
  if (fieldKey == 'explicit' || fieldKey == 'abridged') {
    return value == 'true';
  }
  return value;
}

String _normalizeScrapeTitleForMatch(Object? value) {
  if (!_hasScrapeValue(value) || (value is Iterable && value is! String)) {
    return '';
  }
  return value.toString().toLowerCase().replaceAll(
        RegExp(
          r"""[\s\u3000"'`‘’“”.,，。:：;；!?！？、·•・《》<>〈〉【】\[\]（）(){}｛｝\-—–_/\\|+*=#￥$%^&~…]+""",
        ),
        '',
      );
}

int _scrapeCommonPrefixLength(String a, String b) {
  final maxLength = a.length < b.length ? a.length : b.length;
  var length = 0;
  while (length < maxLength && a[length] == b[length]) {
    length++;
  }
  return length;
}

int _scrapeCharacterOverlap(String a, String b) {
  final counts = <String, int>{};
  for (var i = 0; i < a.length; i++) {
    final char = a[i];
    counts[char] = (counts[char] ?? 0) + 1;
  }
  var overlap = 0;
  for (var i = 0; i < b.length; i++) {
    final char = b[i];
    final count = counts[char] ?? 0;
    if (count <= 0) continue;
    overlap++;
    counts[char] = count - 1;
  }
  return overlap;
}

int _scrapeTitleMatchScore(Object? candidate, List<String> terms) {
  final normalizedCandidate = _normalizeScrapeTitleForMatch(candidate);
  if (normalizedCandidate.isEmpty) return 0;
  var best = 0;
  for (final term in terms) {
    final normalizedTerm = _normalizeScrapeTitleForMatch(term);
    if (normalizedTerm.isEmpty) continue;
    if (normalizedCandidate == normalizedTerm) {
      best = best < 100000 ? 100000 : best;
      continue;
    }
    final minLength = normalizedCandidate.length < normalizedTerm.length
        ? normalizedCandidate.length
        : normalizedTerm.length;
    final maxLength = normalizedCandidate.length > normalizedTerm.length
        ? normalizedCandidate.length
        : normalizedTerm.length;
    final lengthRatio = minLength / maxLength;
    final score = normalizedCandidate.contains(normalizedTerm) ||
            normalizedTerm.contains(normalizedCandidate)
        ? 80000 + (lengthRatio * 10000).round()
        : ((2 *
                        _scrapeCharacterOverlap(
                          normalizedCandidate,
                          normalizedTerm,
                        ) /
                        (normalizedCandidate.length + normalizedTerm.length)) *
                    70000)
                .round() +
            (_scrapeCommonPrefixLength(normalizedCandidate, normalizedTerm) /
                    maxLength *
                    10000)
                .round();
    if (score > best) best = score;
  }
  return best;
}

String _scrapeErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    final map = asMap(data);
    final message = map['message']?.toString() ?? map['error']?.toString();
    if (message != null && message.trim().isNotEmpty) {
      return message.trim();
    }
    return error.message ?? error.toString();
  }
  return error.toString();
}

String _bookDefaultScrapeValue(Book book, _ScrapeSearchField field) {
  final key = field.key;
  final from = field.defaultFrom;
  if (key == 'title' ||
      key == 'query' ||
      from == 'book.title' ||
      from == 'title') {
    return book.title;
  }
  if (key == 'author' || from == 'book.author' || from == 'author') {
    return book.author ?? '';
  }
  if (key == 'narrator' || from == 'book.narrator' || from == 'narrator') {
    return book.narrator ?? '';
  }
  return '';
}

Object? _bookScrapeFieldValue(Book book, String fieldKey) {
  switch (fieldKey) {
    case 'title':
      return book.title;
    case 'author':
      return book.author;
    case 'narrator':
      return book.narrator;
    case 'cover_url':
      return book.coverUrl;
    case 'description':
      return book.description;
    case 'tags':
      return book.tags
          ?.split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    case 'genre':
      return book.genre;
    case 'year':
      return book.year;
    default:
      return null;
  }
}

Object? _draftScrapeFieldValue(
  Book book,
  Map<String, _SelectedScrapeField> selectedFields,
  String fieldKey,
) {
  return selectedFields[fieldKey]?.value ??
      _bookScrapeFieldValue(book, fieldKey);
}

String? _sharedScrapeSearchKind(_ScrapeSearchField field) {
  final from = field.defaultFrom;
  if (field.key == 'title' || field.key == 'query' || from == 'book.title') {
    return 'title';
  }
  if (field.key == 'author' || from == 'book.author') return 'author';
  if (field.key == 'narrator' || from == 'book.narrator') return 'narrator';
  return null;
}

Set<String> _configuredScrapeSourceIds(Map<String, dynamic>? config) {
  if (config == null) return <String>{};
  const keys = [
    'defaultSources',
    'default_sources',
    'coverSources',
    'cover_sources',
    'introSources',
    'intro_sources',
    'authorSources',
    'author_sources',
    'narratorSources',
    'narrator_sources',
    'tagsSources',
    'tags_sources',
  ];
  return {
    for (final key in keys)
      if (config[key] is Iterable)
        for (final value in config[key] as Iterable)
          if (value is String && value.trim().isNotEmpty) value.trim(),
  };
}

Set<String> _defaultEnabledScrapeSourceIds(
  List<_ScrapeSource> sources,
  Map<String, dynamic>? config,
) {
  final configured = _configuredScrapeSourceIds(config);
  if (configured.isEmpty) return <String>{};
  return {
    for (final source in sources)
      if (source.autoScrape && configured.contains(source.id)) source.id,
  };
}

class _ScrapeDiffDialog extends StatefulWidget {
  const _ScrapeDiffDialog({required this.bookId});

  final String bookId;

  @override
  State<_ScrapeDiffDialog> createState() => _ScrapeDiffDialogState();
}

class _ScrapeDiffDialogState extends State<_ScrapeDiffDialog> {
  Book? _book;
  List<_ScrapeSource> _sources = [];
  final Set<String> _enabledSourceIds = {};
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  List<_ScrapeResult> _results = [];
  final Map<String, _SelectedScrapeField> _selectedFields = {};
  final Set<String> _expandedScrapeDescriptions = {};
  String? _activeSourceId;
  String _resultView = 'list';
  int? _selectedResultIndex;
  String _step = 'search';
  bool _loading = true;
  bool _searching = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final sourceControllers in _controllers.values) {
      for (final controller in sourceControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.appOf(context).api;
    try {
      final results = await Future.wait([
        api.get('/api/books/${widget.bookId}'),
        api.get('/api/scraper/sources'),
        api.get('/api/libraries'),
      ]);
      final book = Book.fromJson(asMap(results[0].data));
      final rawSources = asMapList(asMap(results[1].data)['sources']);
      final sources = rawSources
          .map(_ScrapeSource.fromJson)
          .where((source) => source.enabled)
          .toList();
      final rawLibraryPayload = results[2].data;
      final rawLibraries = rawLibraryPayload is List
          ? asMapList(rawLibraryPayload)
          : asMapList(asMap(rawLibraryPayload)['libraries']);
      final libraries = rawLibraries.map(Library.fromJson).toList();
      final library =
          libraries.where((item) => item.id == book.libraryId).firstOrNull;
      final defaultEnabledIds =
          _defaultEnabledScrapeSourceIds(sources, library?.scraperConfig);
      final firstSource = sources
              .where((source) => defaultEnabledIds.contains(source.id))
              .firstOrNull ??
          (sources.isEmpty ? null : sources.first);
      if (!mounted) return;
      setState(() {
        _book = book;
        _sources = sources;
        _activeSourceId = firstSource?.id;
        _enabledSourceIds
          ..clear()
          ..addAll(defaultEnabledIds);
        for (final source in sources) {
          final fields = source.searchFields;
          _controllers[source.id] = {
            for (final field in fields)
              field.key: TextEditingController(
                text: _bookDefaultScrapeValue(book, field),
              ),
          };
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '加载刮削插件失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _ScrapeSource? get _activeSource {
    final activeId = _activeSourceId;
    if (activeId == null) return _sources.isEmpty ? null : _sources.first;
    return _sources.where((source) => source.id == activeId).firstOrNull;
  }

  int get _selectedCount => _selectedFields.length;
  int get _filledSelectedCount => _selectedFields.values
      .where((field) => _hasScrapeValue(field.value))
      .length;

  Future<void> _search() async {
    if (_enabledSourceIds.isEmpty) {
      setState(() => _error = '请至少启用一个插件');
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
            _error = '${source.name} 的 ${field.label}不能为空';
          });
          return;
        }
      }
    }
    setState(() {
      _searching = true;
      _error = null;
      _results = [];
      _resultView = 'list';
      _selectedResultIndex = null;
      _expandedScrapeDescriptions.clear();
    });
    final api = AppScope.appOf(context).api;
    final rawResults = <({
      Map<String, dynamic> item,
      _ScrapeSource source,
      int index,
      int order
    })>[];
    final errors = <String>[];
    var sourceOrder = 0;
    for (final source
        in _sources.where((s) => _enabledSourceIds.contains(s.id))) {
      try {
        final values = <String, String>{
          for (final entry in (_controllers[source.id] ?? {}).entries)
            entry.key: entry.value.text.trim(),
        };
        final res = await api.post(
          '/api/scraper/search',
          data: {
            'source': source.id,
            'search_params': values,
            'page': 1,
            'page_size': 20,
          },
        );
        final items = asMapList(asMap(res.data)['items']);
        for (var i = 0; i < items.length; i++) {
          rawResults.add(
            (
              item: items[i],
              source: source,
              index: i,
              order: sourceOrder * 10000 + i
            ),
          );
        }
      } catch (error) {
        errors.add('${source.name}: ${_scrapeErrorMessage(error)}');
      }
      sourceOrder++;
    }
    final titleTerms = _scrapeTitleMatchTerms();
    final sortedResults = [...rawResults]..sort((a, b) {
        final scoreA = _scrapeTitleMatchScore(
            _scrapeItemValue(a.item, 'title'), titleTerms);
        final scoreB = _scrapeTitleMatchScore(
            _scrapeItemValue(b.item, 'title'), titleTerms);
        return scoreB.compareTo(scoreA) == 0
            ? a.order.compareTo(b.order)
            : scoreB.compareTo(scoreA);
      });
    final nextResults = [
      for (var i = 0; i < sortedResults.length; i++)
        _ScrapeResult(
          item: sortedResults[i].item,
          source: sortedResults[i].source,
          index: i,
        ),
    ];
    if (!mounted) return;
    setState(() {
      _results = nextResults;
      _step = 'results';
      _resultView = 'list';
      _selectedResultIndex = null;
      _expandedScrapeDescriptions.clear();
      _error = errors.isEmpty ? null : errors.join('\n');
      _searching = false;
    });
  }

  void _clearScrapeResults() {
    _results = [];
    _resultView = 'list';
    _selectedResultIndex = null;
    _expandedScrapeDescriptions.clear();
    _error = null;
  }

  void _handleSearchValueChanged(
    _ScrapeSource source,
    _ScrapeSearchField field,
    String value,
  ) {
    final sharedKind = _sharedScrapeSearchKind(field);
    setState(() {
      _clearScrapeResults();
      if (sharedKind == null) return;
      for (final targetSource in _sources) {
        for (final targetField in targetSource.searchFields) {
          if (_sharedScrapeSearchKind(targetField) != sharedKind) continue;
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

  void _toggleField(_ScrapeResult result, String key) {
    final value = _scrapeItemValue(result.item, key);
    if (!_hasScrapeValue(value)) return;
    setState(() {
      if (_selectedFields[key]?.resultKey == result.key) {
        return;
      } else {
        final definition = _scrapeFieldDefinitions[key];
        _selectedFields[key] = _SelectedScrapeField(
          key: key,
          label: definition?.label ?? key,
          value: value!,
          sourceId: result.source.id,
          sourceName: result.source.name,
          resultId: result.externalId,
          resultKey: result.key,
          resultTitle: result.title,
        );
      }
    });
  }

  void _selectAll(_ScrapeResult result) {
    setState(() {
      for (final key in result.source.resultFields) {
        final value = _scrapeItemValue(result.item, key);
        if (!_hasScrapeValue(value)) continue;
        final definition = _scrapeFieldDefinitions[key];
        _selectedFields[key] = _SelectedScrapeField(
          key: key,
          label: definition?.label ?? key,
          value: value!,
          sourceId: result.source.id,
          sourceName: result.source.name,
          resultId: result.externalId,
          resultKey: result.key,
          resultTitle: result.title,
        );
      }
    });
  }

  void _updateSelectedField(String key, String value) {
    setState(() {
      final field = _selectedFields[key];
      if (field == null) return;
      field.value = _scrapeEditorValueForField(key, value);
    });
  }

  List<String> _scrapeTitleMatchTerms() {
    final terms = <String>[];
    final seen = <String>{};
    void add(Object? value) {
      if (!_hasScrapeValue(value) || value is Iterable && value is! String) {
        return;
      }
      for (final part in value.toString().split(RegExp(r'[|丨]'))) {
        final trimmed = part.trim();
        final normalized = _normalizeScrapeTitleForMatch(trimmed);
        if (normalized.isEmpty || seen.contains(normalized)) continue;
        seen.add(normalized);
        terms.add(trimmed);
      }
    }

    for (final source
        in _sources.where((s) => _enabledSourceIds.contains(s.id))) {
      final controllers = _controllers[source.id] ?? {};
      for (final field in source.searchFields) {
        if (_sharedScrapeSearchKind(field) == 'title') {
          add(controllers[field.key]?.text);
        }
      }
    }
    add(_book?.title);
    return terms;
  }

  Future<void> _apply() async {
    if (_filledSelectedCount == 0 || _saving) return;
    setState(() => _saving = true);
    final fields = <String, dynamic>{
      for (final entry in _selectedFields.entries)
        if (_hasScrapeValue(entry.value.value))
          entry.key: {
            'value': _scrapeValueForApi(entry.value.value),
            'source': entry.value.sourceId,
            'external_id': entry.value.resultId,
          },
    };
    try {
      await AppScope.appOf(context).api.post(
        '/api/books/${widget.bookId}/scrape-apply',
        data: {
          'fields': fields,
          'apply_metadata': true,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '应用失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Dialog(
        child: SizedBox(
          width: 320,
          height: 180,
          child: LoadingView(label: '正在加载...'),
        ),
      );
    }
    if (_book == null || _sources.isEmpty) {
      return AlertDialog(
        title: const Text('没有可用插件'),
        content: Text(_error ?? '请先在插件管理中启用刮削插件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('关闭'),
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
                        const Expanded(child: _ScrapeSectionLabel('本次启用插件')),
                        Text(
                          '${_enabledSourceIds.length} 个',
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
                    ? const EmptyState(
                        icon: Icons.extension_off_rounded,
                        title: '未选择插件',
                        message: '请选择一个刮削插件。',
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
            title: '搜索结果',
            subtitle:
                '${_enabledSourceIds.length} 个插件 · ${_results.length} 条结果 · 已选择 $_selectedCount 个字段',
            actionLabel: '修改搜索',
            actionIcon: Icons.arrow_back_rounded,
            onAction: () => setState(() => _step = 'search'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ScrapeNotice(message: _error!),
          ],
          const SizedBox(height: 14),
          if (_searching)
            const SizedBox(height: 260, child: LoadingView(label: '搜索中...'))
          else if (_results.isEmpty)
            const EmptyState(
              icon: Icons.search_off_rounded,
              title: '暂无搜索结果',
              message: '换一个插件或关键词试试。',
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

  Widget _buildResultDetailStep(_ScrapeResult result) {
    final cover = _scrapeItemValue(result.item, 'cover_url')?.toString() ?? '';
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
              label: const Text('返回搜索结果'),
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
                      result.title,
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
                  label: const Text('采用全部'),
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
            const EmptyState(
              icon: Icons.fact_check_outlined,
              title: '没有可应用字段',
              message: '这个结果没有返回可写入书籍的字段。',
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

  Widget _buildResultFieldTile(Book book, _ScrapeResult result, String key) {
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
    required _ScrapeResult result,
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
    final selected = _selectedFields.values.toList()
      ..sort((a, b) =>
          _scrapeFieldSortIndex(a.key).compareTo(_scrapeFieldSortIndex(b.key)));
    return _ScrapeScrollArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScrapeSummaryCard(
            title: '待应用字段',
            subtitle: '${selected.length} 个字段',
            actionLabel: '清空',
            actionIcon: Icons.delete_outline_rounded,
            onAction: selected.isEmpty
                ? null
                : () => setState(() => _selectedFields.clear()),
          ),
          const SizedBox(height: 14),
          if (selected.isEmpty)
            const EmptyState(
              icon: Icons.fact_check_outlined,
              title: '未选择字段',
              message: '回到搜索结果，选择要应用到书籍的字段。',
            )
          else
            Column(
              children: [
                for (final field in selected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SelectedScrapeFieldCard(
                      field: field,
                      onChanged: (value) =>
                          _updateSelectedField(field.key, value),
                      onRemove: () =>
                          setState(() => _selectedFields.remove(field.key)),
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
            '已选择 $_selectedCount 个字段',
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
              child: const Text('取消'),
            ),
            const SizedBox(width: 10),
            PrimaryButton(
              label: '搜索 ${_enabledSourceIds.length} 个插件',
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
              label: Text(_resultView == 'detail' ? '搜索结果' : '搜索条件'),
            ),
            const SizedBox(width: 10),
            PrimaryButton(
              label: '确认应用',
              icon: Icons.arrow_forward_rounded,
              onPressed: _selectedFields.isEmpty
                  ? null
                  : () => setState(() => _step = 'review'),
            ),
          ] else ...[
            TextButton.icon(
              onPressed: () => setState(() => _step = 'results'),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('返回'),
            ),
            const SizedBox(width: 10),
            PrimaryButton(
              label: '应用',
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
