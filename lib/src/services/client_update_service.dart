import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/external_links.dart';

class ClientReleaseInfo {
  const ClientReleaseInfo({
    required this.version,
    required this.downloadUrl,
    required this.size,
    required this.date,
  });

  factory ClientReleaseInfo.fromJson(Map<String, dynamic> json) {
    return ClientReleaseInfo(
      version: json['version']?.toString() ?? '',
      downloadUrl: json['downloadUrl']?.toString() ??
          json['download_url']?.toString() ??
          '',
      size: json['size']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }

  final String version;
  final String downloadUrl;
  final String size;
  final String date;

  bool get hasDownload => downloadUrl.isNotEmpty;
}

class ClientUpdateService {
  ClientUpdateService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
              ),
            );

  static const downloadPageUrl = '$tingReaderWebsiteUrl/#download';

  final Dio _dio;

  Future<PackageInfo> packageInfo() => PackageInfo.fromPlatform();

  Future<String> currentVersion() async {
    return (await packageInfo()).version;
  }

  Future<String> currentVersionLabel() async {
    final info = await packageInfo();
    return 'v${info.version}';
  }

  Future<ClientReleaseInfo?> fetchLatest() async {
    final endpoint = _clientEndpoint;
    if (endpoint == null) return null;
    final response = await _dio.get<Object?>(endpoint);
    final data = response.data;
    if (data is! Map) return null;
    return ClientReleaseInfo.fromJson(Map<String, dynamic>.from(data));
  }

  bool isNewer(String remoteVersion, String currentVersion) {
    return _compareVersions(remoteVersion, currentVersion) > 0;
  }

  bool get canInstallDirectly {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  String get updateActionLabel => canInstallDirectly ? '下载安装' : '打开浏览器下载';

  Future<void> openOrInstall(
    ClientReleaseInfo release, {
    ValueChanged<double>? onProgress,
  }) async {
    if (!release.hasDownload) {
      await openExternalUrl(downloadPageUrl);
      return;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _downloadAndInstallApk(release, onProgress: onProgress);
      return;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await _downloadAndOpenInstaller(release, onProgress: onProgress);
      return;
    }
    await openExternalUrl(release.downloadUrl);
  }

  Future<void> openDownloadPage() => openExternalUrl(downloadPageUrl);

  String? get _clientEndpoint {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '$tingReaderWebsiteUrl/api/client/android';
      case TargetPlatform.windows:
        return '$tingReaderWebsiteUrl/api/client/desktop/winSetup';
      case TargetPlatform.macOS:
        return '$tingReaderWebsiteUrl/api/client/desktop/macZip';
      case TargetPlatform.linux:
        return '$tingReaderWebsiteUrl/api/client/desktop/linuxTar';
      case TargetPlatform.iOS:
        return '$tingReaderWebsiteUrl/api/client/ios';
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  Future<void> _downloadAndInstallApk(
    ClientReleaseInfo release, {
    ValueChanged<double>? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final safeVersion =
        release.version.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final targetPath = '${tempDir.path}/ting-reader-$safeVersion.apk';
    await _dio.download(
      release.downloadUrl,
      targetPath,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress?.call(received / total);
      },
    );
    onProgress?.call(1);
    final result = await OpenFilex.open(
      targetPath,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw StateError(result.message);
    }
  }

  Future<void> _downloadAndOpenInstaller(
    ClientReleaseInfo release, {
    ValueChanged<double>? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final safeVersion =
        release.version.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final uri = Uri.tryParse(release.downloadUrl);
    var extension = 'exe';
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final fileName = uri.pathSegments.last;
      final dotIndex = fileName.lastIndexOf('.');
      if (dotIndex >= 0 && dotIndex < fileName.length - 1) {
        extension = fileName.substring(dotIndex + 1);
      }
    }
    final targetPath = '${tempDir.path}/ting-reader-$safeVersion.$extension';
    await _dio.download(
      release.downloadUrl,
      targetPath,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress?.call(received / total);
      },
    );
    onProgress?.call(1);
    final result = await OpenFilex.open(targetPath);
    if (result.type != ResultType.done) {
      throw StateError(result.message);
    }
  }
}

int _compareVersions(String left, String right) {
  final leftParts = _versionParts(left);
  final rightParts = _versionParts(right);
  final maxLength = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var i = 0; i < maxLength; i++) {
    final leftValue = i < leftParts.length ? leftParts[i] : 0;
    final rightValue = i < rightParts.length ? rightParts[i] : 0;
    if (leftValue != rightValue) return leftValue.compareTo(rightValue);
  }
  return 0;
}

List<int> _versionParts(String version) {
  final normalized = version
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[+-]'))
      .first;
  return normalized
      .split('.')
      .map((part) => int.tryParse(part.replaceAll(RegExp(r'\D'), '')) ?? 0)
      .toList();
}
