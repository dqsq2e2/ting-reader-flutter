part of '../download_state.dart';

/// Always transcode these source extensions, regardless of platform.
const _alwaysTranscodeDownloadExtensions = {'strm', 'm3u8'};

/// On Android, transcode these extensions because just_audio can't play them
/// natively.
const _androidTranscodeDownloadExtensions = {
  'wma',
  'ape',
  'tta',
  'tak',
  'ra',
  'rm',
  'aif',
  'aiff',
  'aifc',
  'ac3',
  'dts',
};

int _statusSort(DownloadStatus status) {
  return switch (status) {
    DownloadStatus.downloading => 0,
    DownloadStatus.queued => 1,
    DownloadStatus.paused => 2,
    DownloadStatus.failed => 3,
    DownloadStatus.completed => 4,
  };
}

int? _int(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _boolLike(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

double? _double(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _string(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? _normalizeDirectoryPath(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return Directory(text).absolute.path;
}

Map<String, dynamic> _bookMetadataFromBook(Book book) {
  return {
    'id': book.id,
    'library_id': book.libraryId,
    'title': book.title,
    'author': book.author,
    'narrator': book.narrator,
    'description': book.description,
    'cover_url': book.coverUrl,
    'theme_color': book.themeColor,
    'duration': book.duration,
    'size': book.size,
    'path': book.path,
    'hash': book.hash,
    'created_at': book.createdAt,
    'updated_at': book.updatedAt,
    'library_type': book.libraryType,
    'skip_intro': book.skipIntro,
    'skip_outro': book.skipOutro,
    'tags': book.tags,
    'genre': book.genre,
    'year': book.year,
    'chapter_regex': book.chapterRegex,
  }..removeWhere((_, value) => value == null || value == '');
}

String _coverExtension({String? contentType, required String source}) {
  final type = contentType?.toLowerCase() ?? '';
  if (type.contains('png')) return 'png';
  if (type.contains('webp')) return 'webp';
  if (type.contains('gif')) return 'gif';
  if (type.contains('jpeg') || type.contains('jpg')) return 'jpg';

  final path = Uri.tryParse(source)?.path ?? source.split('?').first;
  final dot = path.lastIndexOf('.');
  if (dot >= 0 && dot < path.length - 1) {
    final ext = path.substring(dot + 1).toLowerCase();
    if (const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      return ext == 'jpeg' ? 'jpg' : ext;
    }
  }
  return 'jpg';
}

int? _parseContentRangeTotal(String? value) {
  if (value == null || value.isEmpty) return null;
  final slash = value.lastIndexOf('/');
  if (slash < 0 || slash == value.length - 1) return null;
  return int.tryParse(value.substring(slash + 1));
}

String? _downloadExtensionFromHeaders(Headers headers) {
  final explicit = headers.value('x-download-extension') ??
      headers.value('x-audio-extension') ??
      headers.value('x-content-extension');
  final sanitized = _sanitizeExtension(explicit);
  if (sanitized != null) return sanitized;

  final contentType =
      headers.value('content-type')?.split(';').first.trim().toLowerCase();
  return switch (contentType) {
    'audio/mpeg' || 'audio/mp3' => 'mp3',
    'audio/mp4' || 'audio/x-m4a' || 'video/mp4' => 'm4a',
    'audio/aac' || 'audio/aacp' => 'aac',
    'audio/flac' || 'audio/x-flac' => 'flac',
    'audio/ogg' || 'application/ogg' => 'ogg',
    'audio/opus' => 'opus',
    'audio/wav' || 'audio/x-wav' || 'audio/wave' => 'wav',
    'audio/webm' || 'video/webm' => 'webm',
    'audio/amr' => 'amr',
    _ => null,
  };
}

String? _sanitizeExtension(String? value) {
  if (value == null) return null;
  final normalized =
      value.trim().replaceFirst(RegExp(r'^\.'), '').toLowerCase();
  if (RegExp(r'^[a-z0-9]{1,8}$').hasMatch(normalized)) {
    return normalized == 'mp4' ? 'm4a' : normalized;
  }
  return null;
}

String _replacePathExtension(String path, String extension) {
  final separator = Platform.pathSeparator;
  final separatorIndex = path.lastIndexOf(separator);
  final dotIndex = path.lastIndexOf('.');
  if (dotIndex > separatorIndex) {
    return '${path.substring(0, dotIndex)}.$extension';
  }
  return '$path.$extension';
}

String _extensionFromPath(String path) {
  final clean = path.split('?').first;
  final dot = clean.lastIndexOf('.');
  if (dot >= 0 && dot < clean.length - 1) {
    final ext = clean.substring(dot + 1).toLowerCase();
    if (RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext)) return ext;
  }
  return 'mp3';
}

String _safeSegment(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .trim();
  if (cleaned.isEmpty) return 'item';
  return cleaned.length > 72 ? cleaned.substring(0, 72) : cleaned;
}
