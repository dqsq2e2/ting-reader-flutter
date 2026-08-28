import 'package:url_launcher/url_launcher.dart';

const tingReaderWebsiteUrl = 'https://www.tingreader.cn';

String localizedTingReaderWebsiteUrl(String languageCode) {
  return _isEnglish(languageCode)
      ? '$tingReaderWebsiteUrl/en'
      : tingReaderWebsiteUrl;
}

String localizedUserAgreementUrl(String languageCode) {
  return _localizedDocumentUrl('/about/user-agreement', languageCode);
}

String localizedPrivacyPolicyUrl(String languageCode) {
  return _localizedDocumentUrl('/about/privacy-policy', languageCode);
}

String localizedChangelogUrl(String languageCode) {
  return _localizedDocumentUrl('/about/changelog', languageCode);
}

String localizedServerUpdateGuideUrl(String languageCode) {
  return _localizedDocumentUrl('/guide/update', languageCode);
}

String localizedDownloadPageUrl(String languageCode) {
  return '${localizedTingReaderWebsiteUrl(languageCode)}#download';
}

String _localizedDocumentUrl(String path, String languageCode) {
  return '$tingReaderWebsiteUrl$path${_isEnglish(languageCode) ? '/en' : ''}';
}

bool _isEnglish(String languageCode) {
  return languageCode.toLowerCase().startsWith('en');
}

Future<bool> openExternalUrl(String rawUrl) async {
  final normalized = _normalizeUrl(rawUrl);
  final uri = Uri.tryParse(normalized);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> openRepositoryUrl(String repository) {
  final trimmed = repository.trim();
  if (trimmed.isEmpty) return Future.value(false);
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return openExternalUrl(trimmed);
  }
  if (trimmed.startsWith('github.com/')) {
    return openExternalUrl('https://$trimmed');
  }
  return openExternalUrl(
    'https://github.com/${trimmed.replaceFirst(RegExp(r'^/+'), '')}',
  );
}

String _normalizeUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}
