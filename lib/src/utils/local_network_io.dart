import 'dart:convert';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

import 'ipv4_subnet.dart';

Future<bool?> isServerOnCurrentIpv4Subnet(String serverUrl) async {
  final uri = Uri.tryParse(serverUrl);
  if (uri == null || uri.host.isEmpty) return null;

  final serverAddresses = await _resolveIpv4(uri.host);
  if (serverAddresses.isEmpty) return null;

  final networks = await _currentIpv4Networks();
  if (networks.isEmpty) return null;
  for (final network in networks) {
    for (final serverAddress in serverAddresses) {
      if (ipv4AddressesSharePrefix(
        network.address,
        serverAddress,
        network.prefixLength,
      )) {
        return true;
      }
    }
  }
  return false;
}

Future<List<_Ipv4Network>> _currentIpv4Networks() async {
  final networks = <_Ipv4Network>[];
  await _appendPluginNetwork(networks);
  if (Platform.isWindows) {
    networks.addAll(await _windowsIpv4Networks());
  } else if (Platform.isLinux) {
    networks.addAll(await _linuxIpv4Networks());
  } else if (Platform.isMacOS) {
    networks.addAll(await _macOsIpv4Networks());
  }

  final seen = <String>{};
  return networks.where((network) {
    if (!_isUsableIpv4(network.address)) return false;
    return seen.add('${network.address}/${network.prefixLength}');
  }).toList();
}

Future<void> _appendPluginNetwork(List<_Ipv4Network> networks) async {
  try {
    final info = NetworkInfo();
    final values = await Future.wait([
      info.getWifiIP(),
      info.getWifiSubmask(),
    ]).timeout(const Duration(seconds: 2));
    final address = values[0];
    final mask = values[1];
    if (address == null || mask == null) return;
    final prefixLength = ipv4PrefixLengthFromMask(mask);
    if (prefixLength == null) return;
    networks.add(_Ipv4Network(address, prefixLength));
  } catch (_) {
    // Desktop wired connections commonly return no Wi-Fi information.
  }
}

Future<List<_Ipv4Network>> _windowsIpv4Networks() async {
  const script = r'''
$items = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.AddressState -eq 'Preferred' -and $_.IPAddress -notlike '127.*' } |
  ForEach-Object { [PSCustomObject]@{ address = $_.IPAddress; prefix_length = $_.PrefixLength } }
@($items) | ConvertTo-Json -Compress
''';
  try {
    final result = await Process.run(
      'powershell.exe',
      const [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-Command',
        script,
      ],
    ).timeout(const Duration(seconds: 3));
    if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
      final decoded = jsonDecode(result.stdout.toString().trim());
      final items = decoded is List ? decoded : [decoded];
      final networks =
          items.map(_networkFromJson).whereType<_Ipv4Network>().toList();
      if (networks.isNotEmpty) return networks;
    }
  } catch (_) {
    // Fall through to ipconfig, which also works on older Windows editions.
  }

  try {
    final result = await Process.run('ipconfig', const ['/all'])
        .timeout(const Duration(seconds: 2));
    if (result.exitCode != 0) return const [];
    final expression = RegExp(
      r'IPv4[^\r\n]*:\s*(\d+\.\d+\.\d+\.\d+)[^\r\n]*\r?\n'
      r'[^\r\n]*:\s*(\d+\.\d+\.\d+\.\d+)',
      caseSensitive: false,
    );
    final networks = <_Ipv4Network>[];
    for (final match in expression.allMatches(result.stdout.toString())) {
      final prefix = ipv4PrefixLengthFromMask(match.group(2)!);
      if (prefix != null) {
        networks.add(_Ipv4Network(match.group(1)!, prefix));
      }
    }
    return networks;
  } catch (_) {
    return const [];
  }
}

Future<List<_Ipv4Network>> _linuxIpv4Networks() async {
  try {
    final result = await Process.run(
      'ip',
      const ['-j', '-4', 'addr', 'show', 'up'],
    ).timeout(const Duration(seconds: 2));
    if (result.exitCode != 0) return const [];
    final decoded = jsonDecode(result.stdout.toString());
    if (decoded is! List) return const [];
    final networks = <_Ipv4Network>[];
    for (final interface in decoded.whereType<Map>()) {
      final addresses = interface['addr_info'];
      if (addresses is! List) continue;
      for (final address in addresses.whereType<Map>()) {
        final local = address['local']?.toString() ?? '';
        final prefix = int.tryParse(address['prefixlen']?.toString() ?? '');
        if (local.isNotEmpty && prefix != null) {
          networks.add(_Ipv4Network(local, prefix));
        }
      }
    }
    return networks;
  } catch (_) {
    return const [];
  }
}

Future<List<_Ipv4Network>> _macOsIpv4Networks() async {
  try {
    final result = await Process.run('ifconfig', const [])
        .timeout(const Duration(seconds: 2));
    if (result.exitCode != 0) return const [];
    final expression = RegExp(
      r'\binet\s+(\d+\.\d+\.\d+\.\d+)\s+netmask\s+(0x[0-9a-fA-F]+|\d+\.\d+\.\d+\.\d+)',
    );
    final networks = <_Ipv4Network>[];
    for (final match in expression.allMatches(result.stdout.toString())) {
      final address = match.group(1)!;
      final rawMask = match.group(2)!;
      final prefix = rawMask.startsWith('0x')
          ? _prefixLengthFromHexMask(rawMask)
          : ipv4PrefixLengthFromMask(rawMask);
      if (prefix != null) networks.add(_Ipv4Network(address, prefix));
    }
    return networks;
  } catch (_) {
    return const [];
  }
}

_Ipv4Network? _networkFromJson(dynamic raw) {
  if (raw is! Map) return null;
  final address = raw['address']?.toString() ?? '';
  final prefix = int.tryParse(raw['prefix_length']?.toString() ?? '');
  if (address.isEmpty || prefix == null || prefix < 0 || prefix > 32) {
    return null;
  }
  return _Ipv4Network(address, prefix);
}

Future<List<String>> _resolveIpv4(String host) async {
  final literal = InternetAddress.tryParse(host);
  if (literal != null) {
    return literal.type == InternetAddressType.IPv4
        ? [literal.address]
        : const [];
  }

  try {
    final addresses = await InternetAddress.lookup(
      host,
      type: InternetAddressType.IPv4,
    ).timeout(const Duration(seconds: 1));
    return addresses.map((address) => address.address).toList();
  } catch (_) {
    return const [];
  }
}

int? _prefixLengthFromHexMask(String value) {
  final mask = int.tryParse(value.substring(2), radix: 16);
  if (mask == null) return null;
  final octets =
      [24, 16, 8, 0].map((shift) => (mask >> shift) & 0xff).join('.');
  return ipv4PrefixLengthFromMask(octets);
}

bool _isUsableIpv4(String value) {
  final parsed = ipv4Value(value);
  if (parsed == null) return false;
  final first = (parsed >> 24) & 0xff;
  final second = (parsed >> 16) & 0xff;
  return first != 0 && first != 127 && !(first == 169 && second == 254);
}

class _Ipv4Network {
  const _Ipv4Network(this.address, this.prefixLength);

  final String address;
  final int prefixLength;
}
