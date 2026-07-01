import 'package:url_launcher/url_launcher.dart';

const tingReaderWebsiteUrl = 'https://www.tingreader.cn';
const userAgreementUrl = '$tingReaderWebsiteUrl/about/user-agreement';
const privacyPolicyUrl = '$tingReaderWebsiteUrl/about/privacy-policy';
const changelogUrl = '$tingReaderWebsiteUrl/about/changelog';
const serverUpdateGuideUrl = '$tingReaderWebsiteUrl/guide/update';

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
