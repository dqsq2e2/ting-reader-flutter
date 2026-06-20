bool ipv4AddressesSharePrefix(
  String first,
  String second,
  int prefixLength,
) {
  final firstValue = ipv4Value(first);
  final secondValue = ipv4Value(second);
  if (firstValue == null || secondValue == null) return false;
  if (prefixLength == 0) return true;
  if (prefixLength < 0 || prefixLength > 32) return false;
  final mask = (0xffffffff << (32 - prefixLength)) & 0xffffffff;
  return (firstValue & mask) == (secondValue & mask);
}

bool ipv4AddressesShareMask(
  String first,
  String second,
  String subnetMask,
) {
  final prefixLength = ipv4PrefixLengthFromMask(subnetMask);
  if (prefixLength == null) return false;
  return ipv4AddressesSharePrefix(first, second, prefixLength);
}

int? ipv4PrefixLengthFromMask(String value) {
  final mask = ipv4Value(value);
  if (mask == null) return null;
  var prefix = 0;
  var foundZero = false;
  for (var bit = 31; bit >= 0; bit--) {
    final enabled = (mask & (1 << bit)) != 0;
    if (enabled && foundZero) return null;
    if (enabled) {
      prefix++;
    } else {
      foundZero = true;
    }
  }
  return prefix;
}

int? ipv4Value(String value) {
  final parts = value.split('.');
  if (parts.length != 4) return null;
  var result = 0;
  for (final part in parts) {
    final octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) return null;
    result = (result << 8) | octet;
  }
  return result;
}
