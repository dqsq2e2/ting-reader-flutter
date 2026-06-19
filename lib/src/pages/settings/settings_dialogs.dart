part of 'settings_page.dart';

String _stringValue(
  Map<String, dynamic> data,
  String snake, {
  String? camel,
  Map<String, dynamic>? nested,
  String fallback = '',
}) {
  final value = data[snake] ??
      (camel == null ? null : data[camel]) ??
      nested?[snake] ??
      (camel == null ? null : nested?[camel]);
  return value?.toString() ?? fallback;
}

num _numValue(
  Map<String, dynamic> data,
  String snake,
  String camel, {
  num fallback = 0,
}) {
  final value = data[snake] ?? data[camel];
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _boolValue(
  Map<String, dynamic> data,
  String snake,
  String camel, {
  Map<String, dynamic>? nested,
  required bool fallback,
}) {
  final value = data[snake] ?? data[camel] ?? nested?[snake] ?? nested?[camel];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value == null) return fallback;
  return value.toString() == 'true';
}
