/// Shared JSON parsing helpers used by all model classes.
///
/// These accept both snake_case and camelCase keys (server returns snake_case,
/// some legacy responses use camelCase) and normalize loose values
/// (e.g. parse `int` from `"123"` or `123.0`).
///
/// `asMap` / `asMapList` are also re-exported from `models.dart` to preserve
/// the existing public API.
library;

String? readString(Map<String, dynamic> json, String snake, [String? camel]) {
  final value = json[snake] ?? (camel == null ? null : json[camel]);
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? readInt(Map<String, dynamic> json, String snake, [String? camel]) {
  final value = json[snake] ?? (camel == null ? null : json[camel]);
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? readDouble(Map<String, dynamic> json, String snake, [String? camel]) {
  final value = json[snake] ?? (camel == null ? null : json[camel]);
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool? readBool(Map<String, dynamic> json, String snake, [String? camel]) {
  final value = json[snake] ?? (camel == null ? null : json[camel]);
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value.toString() == 'true';
}

List<String> readStringList(dynamic value) {
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }
  return const [];
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

Map<String, String> readStringMap(dynamic value) {
  final map = asMap(value);
  return map.map((key, item) => MapEntry(key, item?.toString() ?? ''));
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) return const [];
  return value.map(asMap).toList();
}
