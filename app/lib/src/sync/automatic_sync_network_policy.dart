import 'dart:async';
import 'dart:io';

import '../network/lan_address.dart';

typedef LocalAddressLoader = Future<List<InternetAddress>> Function();

class AutomaticSyncNetworkPolicy {
  AutomaticSyncNetworkPolicy({LocalAddressLoader? localAddressLoader})
    : _localAddressLoader = localAddressLoader ?? _loadLocalAddresses;

  final LocalAddressLoader _localAddressLoader;

  Future<bool> shouldAttempt(String serverUrl) async {
    final uri = Uri.tryParse(serverUrl);
    if (uri == null || !uri.hasAuthority) {
      return false;
    }
    if (uri.host.toLowerCase() == 'localhost') {
      return true;
    }
    final target = InternetAddress.tryParse(uri.host);
    if (target == null || !isPrivateOrLoopbackAddress(target)) {
      // HTTPS deployments with public DNS retain their existing behavior.
      return true;
    }
    try {
      final localAddresses = await _localAddressLoader().timeout(
        const Duration(seconds: 2),
      );
      return localAddresses.any((local) => isOnSameLanSubnet(target, local));
    } on Object {
      return false;
    }
  }

  static Future<List<InternetAddress>> _loadLocalAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.any,
      includeLoopback: false,
    );
    return [for (final interface in interfaces) ...interface.addresses];
  }
}
