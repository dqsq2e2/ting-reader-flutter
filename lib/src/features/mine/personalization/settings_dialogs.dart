part of 'personalization_page.dart';

String _stringValue(
  Map<String, dynamic> data,
  String key, {
  Map<String, dynamic>? nested,
  String fallback = '',
}) {
  final value = data[key] ?? nested?[key];
  return value?.toString() ?? fallback;
}

num _numValue(
  Map<String, dynamic> data,
  String key, {
  num fallback = 0,
}) {
  final value = data[key];
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _boolValue(
  Map<String, dynamic> data,
  String key, {
  Map<String, dynamic>? nested,
  required bool fallback,
}) {
  final value = data[key] ?? nested?[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value == null) return fallback;
  return value.toString() == 'true';
}
