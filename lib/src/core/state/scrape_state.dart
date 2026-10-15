import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../models/models.dart';

/// Owns one manual scrape session: sources, search inputs, ranked results,
/// selected field provenance and application requests. Widgets own text focus.
class ScrapeState extends ChangeNotifier {
  ScrapeState(this.api, this.bookId);
  final ApiClient api;
  final String bookId;
  final Set<CancelToken> _requests = {};
  CancelToken? _searchToken;
  bool _disposed = false;
  bool loading = true;
  bool searching = false;
  bool saving = false;
  String? error;
  Book? book;
  List<ScrapeSource> sources = [];
  final Set<String> enabledSources = {};
  List<ScrapeResult> results = [];
  final Map<String, SelectedScrapeField> selectedFields = {};

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  CancelToken _request() {
    if (_disposed) throw StateError('Scrape session closed');
    final token = CancelToken();
    _requests.add(token);
    return token;
  }

  Future<void> load() async {
    if (_disposed) return;
    final token = _request();
    try {
      final response = await Future.wait([
        api.get('/api/books/${Uri.encodeComponent(bookId)}',
            cancelToken: token),
        api.get('/api/scraper/sources', cancelToken: token),
        api.get('/api/libraries', cancelToken: token),
      ]);
      if (_disposed || token.isCancelled) return;
      book = Book.fromJson(asMap(response[0].data));
      sources = asMapList(asMap(response[1].data)['sources'])
          .map(ScrapeSource.fromJson)
          .where((source) => source.enabled)
          .toList();
      final rawLibraries = response[2].data;
      final libraries = asMapList(rawLibraries is List
              ? rawLibraries
              : asMap(rawLibraries)['libraries'])
          .map(Library.fromJson);
      final config = libraries
          .where((library) => library.id == book?.libraryId)
          .firstOrNull
          ?.scraperConfig;
      enabledSources.addAll(defaultEnabledScrapeSourceIds(sources, config));
    } catch (failure) {
      if (!_disposed && !token.isCancelled) error = scrapeErrorMessage(failure);
    } finally {
      _requests.remove(token);
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  void clearResults() {
    _searchToken?.cancel('Scrape inputs changed');
    results = [];
    searching = false;
    error = null;
  }

  Future<bool> search(Map<String, Map<String, String>> inputs) async {
    if (_disposed) return false;
    _searchToken?.cancel('Scrape search replaced');
    final token = _request();
    _searchToken = token;
    final enabled =
        sources.where((source) => enabledSources.contains(source.id)).toList();
    final values = {
      for (final entry in inputs.entries)
        entry.key: Map<String, String>.from(entry.value)
    };
    final terms = <String>[];
    final seen = <String>{};
    void addTerm(String? value) {
      for (final part in (value ?? '').split(RegExp(r'[|丨]'))) {
        final normalized = normalizeScrapeTitleForMatch(part);
        if (normalized.isNotEmpty && seen.add(normalized)) {
          terms.add(part.trim());
        }
      }
    }

    for (final source in enabled) {
      for (final field in source.searchFields) {
        if (sharedScrapeSearchKind(field) == 'title') {
          addTerm(values[source.id]?[field.key]);
        }
      }
    }
    addTerm(book?.title);
    searching = true;
    error = null;
    results = [];
    _notify();
    final found =
        <({Map<String, dynamic> item, ScrapeSource source, int order})>[];
    final failures = <String>[];
    try {
      for (var index = 0; index < enabled.length; index++) {
        final source = enabled[index];
        if (_disposed || token.isCancelled) return false;
        try {
          final response = await api.post('/api/scraper/search',
              cancelToken: token,
              receiveTimeout: const Duration(minutes: 2),
              data: {
                'source': source.id,
                'search_params': values[source.id] ?? {},
                'page': 1,
                'page_size': 20,
              });
          if (_disposed || token.isCancelled) return false;
          final items = asMapList(asMap(response.data)['items']);
          for (var item = 0; item < items.length; item++) {
            found.add((
              item: items[item],
              source: source,
              order: index * 10000 + item
            ));
          }
        } catch (failure) {
          if (_disposed || token.isCancelled) return false;
          failures.add('${source.name}: ${scrapeErrorMessage(failure)}');
        }
      }
      found.sort((a, b) {
        final score = scrapeTitleMatchScore(
                scrapeItemValue(b.item, 'title'), terms)
            .compareTo(
                scrapeTitleMatchScore(scrapeItemValue(a.item, 'title'), terms));
        return score == 0 ? a.order.compareTo(b.order) : score;
      });
      if (_disposed || token.isCancelled) return false;
      results = [
        for (var index = 0; index < found.length; index++)
          ScrapeResult(
              item: found[index].item,
              source: found[index].source,
              index: index)
      ];
      error = failures.isEmpty ? null : failures.join('\n');
      return true;
    } finally {
      _requests.remove(token);
      if (!_disposed && identical(_searchToken, token)) {
        searching = false;
        _notify();
      }
    }
  }

  void select(
      ScrapeResult result, String key, String label, String resultTitle) {
    if (!scrapeFieldOrder.contains(key)) return;
    final value = scrapeItemValue(result.item, key);
    if (value == null || !hasScrapeValue(value)) return;
    selectedFields[key] = SelectedScrapeField(
        key: key,
        label: label,
        value: value,
        sourceId: result.source.id,
        sourceName: result.source.name,
        resultId: result.externalId,
        resultKey: result.key,
        resultTitle: resultTitle);
  }

  void edit(String key, String value, String label, String manualLabel) {
    final original = book;
    if (original == null || !scrapeFieldOrder.contains(key)) return;
    final field = selectedFields[key];
    final next = scrapeEditorValueForField(key, value);
    final current = bookScrapeFieldValue(original, key);
    if ((field == null || field.sourceId.isEmpty) &&
        current != null &&
        jsonEncode(next) ==
            jsonEncode(scrapeEditorValueForField(
                key, scrapeValueForEditor(current)))) {
      selectedFields.remove(key);
    } else if (field != null) {
      field.value = next;
    } else {
      selectedFields[key] = SelectedScrapeField(
          key: key,
          label: label,
          value: next,
          sourceId: '',
          sourceName: manualLabel,
          resultId: '',
          resultKey: '',
          resultTitle: '');
    }
  }

  Future<bool> apply() async {
    if (_disposed ||
        saving ||
        !selectedFields.entries.any((entry) =>
            scrapeFieldOrder.contains(entry.key) &&
            hasScrapeValue(entry.value.value))) {
      return false;
    }
    final token = _request();
    saving = true;
    error = null;
    _notify();
    final fields = {
      for (final entry in selectedFields.entries)
        if (scrapeFieldOrder.contains(entry.key) &&
            hasScrapeValue(entry.value.value))
          entry.key: {
            'value': scrapeValueForApi(entry.value.value),
            if (entry.value.sourceId.isNotEmpty) 'source': entry.value.sourceId,
            if (entry.value.resultId.isNotEmpty)
              'external_id': entry.value.resultId,
          }
    };
    try {
      await api.post('/api/books/${Uri.encodeComponent(bookId)}/scrape-apply',
          data: {'fields': fields, 'apply_metadata': true}, cancelToken: token);
      return !_disposed;
    } catch (failure) {
      if (!_disposed && !token.isCancelled) error = scrapeErrorMessage(failure);
      return false;
    } finally {
      _requests.remove(token);
      if (!_disposed) {
        saving = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final token in _requests) {
      token.cancel('Scrape session closed');
    }
    _requests.clear();
    super.dispose();
  }
}

class ScrapeSource {
  const ScrapeSource({
    required this.id,
    required this.name,
    required this.enabled,
    required this.autoScrape,
    required this.searchFields,
    required this.resultFields,
    required this.resultFieldLabels,
  });

  final String id;
  final String name;
  final bool enabled;
  final bool autoScrape;
  final List<ScrapeSearchField> searchFields;
  final List<String> resultFields;
  final Map<String, LocalizedPluginText> resultFieldLabels;

  factory ScrapeSource.fromJson(Map<String, dynamic> json) {
    final fields = asMapList(json['search_fields'])
        .map(ScrapeSearchField.fromJson)
        .toList();
    final rawResultFields = json['result_fields'];
    final resultFields = scrapeStringList(rawResultFields)
        .map(normalizeScrapeFieldKey)
        .where(scrapeFieldOrder.contains)
        .toSet()
        .toList();
    return ScrapeSource(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Plugin',
      enabled: json['enabled'] == true,
      autoScrape: json['auto_scrape'] == true,
      searchFields: fields.isEmpty ? defaultScrapeSearchFields : fields,
      resultFields: rawResultFields is List && rawResultFields.isNotEmpty
          ? resultFields
          : scrapeFieldOrder,
      resultFieldLabels: localizedPluginTextMap(json['result_field_labels']),
    );
  }
}

class LocalizedPluginText {
  const LocalizedPluginText({this.zh, this.en});

  final String? zh;
  final String? en;

  factory LocalizedPluginText.fromJson(Map<String, dynamic> json) {
    return LocalizedPluginText(
      zh: firstLocalizedString(
        json,
        const ['zh', 'zhCN', 'zh-CN', 'zhHans', 'zh-Hans'],
      ),
      en: firstLocalizedString(
        json,
        const ['en', 'enUS', 'en-US'],
      ),
    );
  }

  static LocalizedPluginText? fromAny(Object? value) {
    if (value is Map) {
      final map = value.map((key, value) => MapEntry(key.toString(), value));
      final text = LocalizedPluginText.fromJson(map);
      if ((text.zh ?? '').trim().isNotEmpty ||
          (text.en ?? '').trim().isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String resolve({required bool english}) {
    final preferred = english ? en : zh;
    final fallback = english ? zh : en;
    return (preferred?.trim().isNotEmpty == true
            ? preferred
            : fallback?.trim().isNotEmpty == true
                ? fallback
                : null) ??
        '';
  }

  String get fallback {
    final enValue = en;
    final zhValue = zh;
    if (zhValue != null && zhValue.trim().isNotEmpty) return zhValue.trim();
    if (enValue != null && enValue.trim().isNotEmpty) return enValue.trim();
    return '';
  }
}

class ScrapeSearchField {
  const ScrapeSearchField({
    required this.key,
    required this.label,
    required this.required,
    required this.defaultFrom,
    this.labelI18n,
    this.placeholder,
    this.placeholderI18n,
  });

  final String key;
  final String label;
  final bool required;
  final String defaultFrom;
  final LocalizedPluginText? labelI18n;
  final String? placeholder;
  final LocalizedPluginText? placeholderI18n;

  factory ScrapeSearchField.fromJson(Map<String, dynamic> json) {
    final rawLabel = json['label'];
    final labelI18n = LocalizedPluginText.fromAny(
      json['label_i18n'] ?? (rawLabel is Map ? rawLabel : null),
    );
    final rawPlaceholder = json['placeholder'];
    return ScrapeSearchField(
      key: json['key']?.toString() ?? 'title',
      label: rawLabel is String
          ? rawLabel
          : labelI18n?.fallback ?? scrapeFieldLabel(json['key']),
      labelI18n: labelI18n,
      required: json['required'] == true,
      defaultFrom: (json['default_from'] ?? json['key'] ?? '').toString(),
      placeholder: rawPlaceholder is String ? rawPlaceholder : null,
      placeholderI18n: LocalizedPluginText.fromAny(
        json['placeholder_i18n'] ??
            (rawPlaceholder is Map ? rawPlaceholder : null),
      ),
    );
  }
}

class ScrapeResult {
  const ScrapeResult({
    required this.item,
    required this.source,
    required this.index,
  });

  final Map<String, dynamic> item;
  final ScrapeSource source;
  final int index;

  String get key => '${source.id}:${item['id'] ?? 'result'}:$index';
  String get externalId => item['id']?.toString() ?? 'result-${index + 1}';
  String get title => formatScrapeValue(scrapeItemValue(item, 'title'));
  String get subtitle {
    final author = formatScrapeValue(scrapeItemValue(item, 'author'), '');
    final narrator = formatScrapeValue(scrapeItemValue(item, 'narrator'), '');
    return [author, narrator].where((value) => value.isNotEmpty).join(' / ');
  }
}

class SelectedScrapeField {
  SelectedScrapeField({
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

const defaultScrapeSearchFields = [
  ScrapeSearchField(
    key: 'title',
    label: 'Title',
    labelI18n: LocalizedPluginText(zh: '书名', en: 'Title'),
    required: true,
    defaultFrom: 'book.title',
  ),
  ScrapeSearchField(
    key: 'author',
    label: 'Author',
    labelI18n: LocalizedPluginText(zh: '作者', en: 'Author'),
    required: false,
    defaultFrom: 'book.author',
  ),
  ScrapeSearchField(
    key: 'narrator',
    label: 'Narrator',
    labelI18n: LocalizedPluginText(zh: '演播', en: 'Narrator'),
    required: false,
    defaultFrom: 'book.narrator',
  ),
];

const scrapeFieldLabels = <String, String>{
  'title': 'Title',
  'author': 'Author',
  'narrator': 'Narrator',
  'cover_url': 'Cover',
  'description': 'Description',
  'tags': 'Tags',
  'genre': 'Genre',
  'year': 'Year',
};
const scrapeFieldOrder = [
  'title',
  'author',
  'narrator',
  'cover_url',
  'description',
  'tags',
  'genre',
  'year',
];

String normalizeScrapeFieldKey(String key) {
  final normalized = key
      .replaceAllMapped(
          RegExp('[A-Z]'), (match) => '_${match[0]?.toLowerCase() ?? ''}')
      .toLowerCase();
  if (normalized == 'intro') return 'description';
  if (normalized == 'published_year') return 'year';
  return normalized;
}

String scrapeFieldLabel(Object? key) {
  final normalized = normalizeScrapeFieldKey(key?.toString() ?? '');
  return scrapeFieldLabels[normalized] ?? (key?.toString() ?? '');
}

List<String> scrapeStringList(Object? value) {
  if (value is Iterable) return value.map((item) => item.toString()).toList();
  if (value is String && value.trim().isNotEmpty) return [value.trim()];
  return const [];
}

String? firstLocalizedString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

Map<String, LocalizedPluginText> localizedPluginTextMap(Object? value) {
  if (value is! Map) return const {};
  final labels = <String, LocalizedPluginText>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    final label = LocalizedPluginText.fromAny(entry.value);
    if (key.isEmpty || label == null) continue;
    labels[key] = label;
    labels.putIfAbsent(normalizeScrapeFieldKey(key), () => label);
  }
  return labels;
}

Object? scrapeItemValue(Map<String, dynamic> item, String fieldKey) {
  switch (fieldKey) {
    case 'cover_url':
      return item['cover_url'];
    case 'description':
      return item['description'] ?? item['intro'];
    case 'year':
      return item['published_year'] ?? item['year'];
    case 'published_date':
      return item['published_date'];
    default:
      return item[fieldKey];
  }
}

bool hasScrapeValue(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  return true;
}

String formatScrapeValue(Object? value, [String emptyLabel = 'Not returned']) {
  if (!hasScrapeValue(value)) return emptyLabel;
  if (value is Iterable) {
    return value.map((item) => item.toString()).join(' / ');
  }
  if (value is bool) return value ? 'Yes' : 'No';
  return value.toString();
}

Object scrapeValueForApi(Object value) {
  if (value is Iterable && value is! String) {
    return value.map((item) => item.toString()).toList();
  }
  return value;
}

String scrapeValueForEditor(Object? value) {
  if (!hasScrapeValue(value)) return '';
  if (value is Iterable && value is! String) {
    return value.map((item) => item.toString()).join(', ');
  }
  return value.toString();
}

Object scrapeEditorValueForField(String fieldKey, String value) {
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

String normalizeScrapeTitleForMatch(Object? value) {
  if (!hasScrapeValue(value) || (value is Iterable && value is! String)) {
    return '';
  }
  return value.toString().toLowerCase().replaceAll(
        RegExp(
          r"""[\s\u3000"'`‘’“”.,，。:：;；!?！？、·•・《》<>〈〉【】\[\]（）(){}｛｝\-—–_/\\|+*=#￥$%^&~…]+""",
        ),
        '',
      );
}

int scrapeCommonPrefixLength(String a, String b) {
  final maxLength = a.length < b.length ? a.length : b.length;
  var length = 0;
  while (length < maxLength && a[length] == b[length]) {
    length++;
  }
  return length;
}

int scrapeCharacterOverlap(String a, String b) {
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

int scrapeTitleMatchScore(Object? candidate, List<String> terms) {
  final normalizedCandidate = normalizeScrapeTitleForMatch(candidate);
  if (normalizedCandidate.isEmpty) return 0;
  var best = 0;
  for (final term in terms) {
    final normalizedTerm = normalizeScrapeTitleForMatch(term);
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
                        scrapeCharacterOverlap(
                          normalizedCandidate,
                          normalizedTerm,
                        ) /
                        (normalizedCandidate.length + normalizedTerm.length)) *
                    70000)
                .round() +
            (scrapeCommonPrefixLength(normalizedCandidate, normalizedTerm) /
                    maxLength *
                    10000)
                .round();
    if (score > best) best = score;
  }
  return best;
}

String scrapeErrorMessage(Object error) {
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

String bookDefaultScrapeValue(Book book, ScrapeSearchField field) {
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

Object? bookScrapeFieldValue(Book book, String fieldKey) {
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

Object? draftScrapeFieldValue(
  Book book,
  Map<String, SelectedScrapeField> selectedFields,
  String fieldKey,
) {
  return selectedFields[fieldKey]?.value ??
      bookScrapeFieldValue(book, fieldKey);
}

String? sharedScrapeSearchKind(ScrapeSearchField field) {
  final from = field.defaultFrom;
  if (field.key == 'title' || field.key == 'query' || from == 'book.title') {
    return 'title';
  }
  if (field.key == 'author' || from == 'book.author') return 'author';
  if (field.key == 'narrator' || from == 'book.narrator') return 'narrator';
  return null;
}

Set<String> configuredScrapeSourceIds(Map<String, dynamic>? config) {
  if (config == null) return <String>{};
  const keys = [
    'default_sources',
    'cover_sources',
    'intro_sources',
    'author_sources',
    'narrator_sources',
    'tags_sources',
  ];
  return {
    for (final key in keys)
      if (config[key] is Iterable)
        for (final value in config[key] as Iterable)
          if (value is String && value.trim().isNotEmpty) value.trim(),
  };
}

Set<String> defaultEnabledScrapeSourceIds(
  List<ScrapeSource> sources,
  Map<String, dynamic>? config,
) {
  final configured = configuredScrapeSourceIds(config);
  if (configured.isEmpty) return <String>{};
  return {
    for (final source in sources)
      if (source.autoScrape && configured.contains(source.id)) source.id,
  };
}
