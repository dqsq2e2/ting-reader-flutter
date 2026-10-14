import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'download_models.dart';

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

int downloadStatusOrder(DownloadStatus status) {
  return switch (status) {
    DownloadStatus.downloading => 0,
    DownloadStatus.queued => 1,
    DownloadStatus.paused => 2,
    DownloadStatus.failed => 3,
    DownloadStatus.completed => 4,
  };
}

int? parseDownloadRangeTotal(String? value) {
  if (value == null || value.isEmpty) return null;
  final slash = value.lastIndexOf('/');
  if (slash < 0 || slash == value.length - 1) return null;
  return int.tryParse(value.substring(slash + 1));
}

String? downloadExtensionFromHeaders(Headers headers) {
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

String replaceDownloadExtension(String path, String extension) {
  final separator = Platform.pathSeparator;
  final separatorIndex = path.lastIndexOf(separator);
  final dotIndex = path.lastIndexOf('.');
  if (dotIndex > separatorIndex) {
    return '${path.substring(0, dotIndex)}.$extension';
  }
  return '$path.$extension';
}

String downloadPathExtension(String path) {
  final clean = path.split('?').first;
  final dot = clean.lastIndexOf('.');
  if (dot >= 0 && dot < clean.length - 1) {
    final ext = clean.substring(dot + 1).toLowerCase();
    if (RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext)) return ext;
  }
  return 'mp3';
}

bool shouldTranscodeDownload(DownloadTask task) {
  final extension = downloadPathExtension(task.chapterPath);
  return task.transcode ||
      _alwaysTranscodeDownloadExtensions.contains(extension) ||
      !kIsWeb &&
          Platform.isAndroid &&
          _androidTranscodeDownloadExtensions.contains(extension);
}

int estimatedDownloadBytes(DownloadTask task, bool transcode) =>
    transcode ? (task.duration ?? 0) * 16000 : 0;
