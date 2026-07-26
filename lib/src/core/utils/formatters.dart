import 'package:lpinyin/lpinyin.dart';
import 'package:flutter/widgets.dart';

import 'locale.dart';

String formatDurationShort(num seconds) {
  if (seconds <= 0) return '0:00';
  final total = seconds.round();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}

String formatDurationHuman(num seconds) {
  if (seconds <= 0) return '0 分钟';
  final hours = seconds ~/ 3600;
  final minutes = ((seconds % 3600) / 60).round();
  if (hours > 0) return '$hours 小时 $minutes 分钟';
  return '$minutes 分钟';
}

String formatDurationHumanForLocale(BuildContext context, num seconds) {
  if (!context.isEnglishLocale) return formatDurationHuman(seconds);
  if (seconds <= 0) return '0 min';
  final hours = seconds ~/ 3600;
  final minutes = ((seconds % 3600) / 60).round();
  if (hours > 0) {
    final hourText = hours == 1 ? '1 hr' : '$hours hrs';
    if (minutes <= 0) return hourText;
    return '$hourText $minutes min';
  }
  return '$minutes min';
}

String formatDateCn(String? raw) {
  if (raw == null || raw.isEmpty) return '从未';
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return raw;
  return '${date.month}月${date.day}日';
}

String formatFullDateCn(DateTime date) {
  const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return '${date.year}年${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
}

String formatBytes(num bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var index = 0;
  while (size >= 1024 && index < units.length - 1) {
    size /= 1024;
    index++;
  }
  return '${size.toStringAsFixed(size >= 10 || index == 0 ? 0 : 1)} ${units[index]}';
}

String greeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return '早上好';
  if (hour >= 12 && hour < 14) return '中午好';
  if (hour >= 14 && hour < 18) return '下午好';
  return '晚上好';
}

String greetingForLocale(BuildContext context) {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) {
    return context.localeText('早上好', 'Good morning');
  }
  if (hour >= 12 && hour < 14) {
    return context.localeText('中午好', 'Good noon');
  }
  if (hour >= 14 && hour < 18) {
    return context.localeText('下午好', 'Good afternoon');
  }
  return context.localeText('晚上好', 'Good evening');
}

String pinyinInitial(String value) {
  if (value.isEmpty) return '#';
  final first = value.substring(0, 1);
  final code = first.codeUnitAt(0);
  if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
    return first.toUpperCase();
  }
  if (code < 0x4e00 || code > 0x9fa5) return '#';

  // CJK codepoint order does not follow pinyin order, so the initial must
  // come from the actual pinyin. This also keeps grouping consistent with
  // chineseSortKey/compareChineseText (and the web client's collation).
  final pinyin = PinyinHelper.getPinyinE(first, separator: '').trim();
  if (pinyin.isEmpty) return '#';
  final initialCode = pinyin.codeUnitAt(0);
  if (initialCode >= 97 && initialCode <= 122) {
    return String.fromCharCode(initialCode - 32);
  }
  if (initialCode >= 65 && initialCode <= 90) {
    return String.fromCharCode(initialCode);
  }
  return '#';
}

int compareChineseText(String a, String b) {
  final aKey = chineseSortKey(a);
  final bKey = chineseSortKey(b);
  final byKey = aKey.compareTo(bKey);
  if (byKey != 0) return byKey;
  return a.toLowerCase().compareTo(b.toLowerCase());
}

String chineseSortKey(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '#';
  return PinyinHelper.getPinyinE(trimmed, separator: '')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '');
}
