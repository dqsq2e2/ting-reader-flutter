import 'package:url_launcher/url_launcher.dart';

const tingReaderWebsiteUrl = 'https://www.tingreader.cn';

Future<bool> openExternalUrl(String rawUrl) async {
  final normalized = _normalizeUrl(rawUrl);
  final uri = Uri.tryParse(normalized);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _normalizeUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}
