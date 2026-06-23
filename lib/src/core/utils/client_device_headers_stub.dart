Future<Map<String, String>> buildClientDeviceHeaders() async {
  return const {
    'User-Agent': 'TingReaderFlutter/1.0.0 (Web)',
    'X-Ting-Client': 'flutter-web',
    'X-Ting-Device': 'Ting Reader Flutter / Web',
  };
}
