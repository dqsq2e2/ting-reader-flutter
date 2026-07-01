part of 'home_page.dart';

class _HeroItem {
  const _HeroItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    this.coverUrl,
    this.libraryId,
    this.book,
    this.progress,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String? coverUrl;
  final String? libraryId;
  final Book? book;
  final ProgressItem? progress;
}

String _weekdayCn(int weekday) {
  const values = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return values[(weekday - 1).clamp(0, values.length - 1)];
}

String _weekdayEn(int weekday) {
  const values = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return values[(weekday - 1).clamp(0, values.length - 1)];
}

String _inlineDescription(String? value, String fallback) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return fallback;
  return text.replaceAll(RegExp(r'\s+'), ' ');
}
