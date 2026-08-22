import 'dart:io';

bool isAllowedBackupTransport(Uri uri) {
  return uri.scheme == 'https' ||
      (uri.scheme == 'http' && isPrivateOrLoopbackHost(uri.host));
}

bool isPrivateOrLoopbackHost(String host) {
  if (host.toLowerCase() == 'localhost') {
    return true;
  }
  final address = InternetAddress.tryParse(host);
  return address != null && isPrivateOrLoopbackAddress(address);
}

bool isPrivateOrLoopbackAddress(InternetAddress address) {
  if (address.isLoopback) {
    return true;
  }
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 169 && bytes[1] == 254);
  }
  return (bytes[0] & 0xfe) == 0xfc ||
      (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80);
}

bool isOnSameLanSubnet(InternetAddress target, InternetAddress local) {
  if (target.type != local.type) {
    return false;
  }
  if (target.isLoopback) {
    return local.isLoopback;
  }
  if (!isPrivateOrLoopbackAddress(target) ||
      !isPrivateOrLoopbackAddress(local)) {
    return false;
  }
  final targetBytes = target.rawAddress;
  final localBytes = local.rawAddress;
  final prefixBytes = target.type == InternetAddressType.IPv4 ? 3 : 8;
  for (var index = 0; index < prefixBytes; index++) {
    if (targetBytes[index] != localBytes[index]) {
      return false;
    }
  }
  return true;
}
