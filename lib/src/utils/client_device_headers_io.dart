import 'dart:io';

Future<Map<String, String>> buildClientDeviceHeaders() async {
  final os = Platform.operatingSystem;
  final osName = _prettyOsName(os);
  final osVersion =
      Platform.operatingSystemVersion.replaceAll(RegExp(r'\s+'), ' ').trim();
  final hostName = _hostName();
  final localIp = await _primaryLocalIp();
  final device = [
    'Ting Reader Flutter',
    osName,
    if (hostName.isNotEmpty) hostName,
    if (localIp.isNotEmpty) localIp,
  ].join(' / ');

  return {
    'User-Agent': 'TingReaderFlutter/1.0.0 ($osName; $osVersion; $hostName)',
    'X-Ting-Client': 'flutter',
    'X-Ting-Device': device,
    if (localIp.isNotEmpty) 'X-Real-IP': localIp,
  };
}

String _prettyOsName(String os) {
  switch (os) {
    case 'android':
      return 'Android';
    case 'ios':
      return 'iOS';
    case 'macos':
      return 'macOS';
    case 'windows':
      return 'Windows';
    case 'linux':
      return 'Linux';
    default:
      return os.isEmpty ? 'Unknown OS' : os;
  }
}

String _hostName() {
  try {
    return Platform.localHostname;
  } catch (_) {
    return '';
  }
}

Future<String> _primaryLocalIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && address.address.isNotEmpty) {
          return address.address;
        }
      }
    }
  } catch (_) {
    return '';
  }
  return '';
}
