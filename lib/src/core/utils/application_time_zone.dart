import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

const defaultApplicationTimeZone = 'UTC';

bool _initialized = false;
String _applicationTimeZone = defaultApplicationTimeZone;

void initializeApplicationTimeZones() {
  if (_initialized) return;
  timezone_data.initializeTimeZones();
  _initialized = true;
}

String get applicationTimeZone => _applicationTimeZone;

List<String> get applicationTimeZoneOptions {
  initializeApplicationTimeZones();
  final values = timezone.timeZoneDatabase.locations.keys.toList()..sort();
  return values;
}

bool isSupportedApplicationTimeZone(String value) {
  initializeApplicationTimeZones();
  return timezone.timeZoneDatabase.locations.containsKey(value.trim());
}

String normalizeApplicationTimeZone(String? value) {
  final candidate = value?.trim() ?? '';
  return isSupportedApplicationTimeZone(candidate)
      ? candidate
      : defaultApplicationTimeZone;
}

void setApplicationTimeZone(String? value) {
  _applicationTimeZone = normalizeApplicationTimeZone(value);
}

timezone.Location _locationFor(String? value) {
  initializeApplicationTimeZones();
  return timezone.getLocation(normalizeApplicationTimeZone(value));
}

DateTime nowInApplicationTimeZone([String? value]) {
  return timezone.TZDateTime.now(_locationFor(value ?? applicationTimeZone));
}

DateTime toApplicationTimeZone(DateTime instant, [String? value]) {
  return timezone.TZDateTime.from(
    instant.toUtc(),
    _locationFor(value ?? applicationTimeZone),
  );
}

/// Server and SQLite timestamps without an explicit offset are UTC.
DateTime? parseBackendUtcDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  var value = raw.trim();
  if (value.length > 10 && value[10] == ' ') {
    value = '${value.substring(0, 10)}T${value.substring(11)}';
  }
  value = value.replaceAllMapped(
    RegExp(r'(\.\d{3})\d+'),
    (match) => match.group(1)!,
  );
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    value = '${value}T00:00:00Z';
  } else if (!RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
      .hasMatch(value)) {
    value = '${value}Z';
  }
  return DateTime.tryParse(value)?.toUtc();
}

DateTime? backendDateTimeInApplicationTimeZone(String? raw, [String? value]) {
  final instant = parseBackendUtcDateTime(raw);
  return instant == null ? null : toApplicationTimeZone(instant, value);
}
