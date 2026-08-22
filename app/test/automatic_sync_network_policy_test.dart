import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/network/lan_address.dart';
import 'package:recall_app/src/sync/automatic_sync_network_policy.dart';

void main() {
  test('recognizes private LAN addresses without accepting public IPs', () {
    expect(isPrivateOrLoopbackHost('192.168.1.10'), isTrue);
    expect(isPrivateOrLoopbackHost('10.0.2.2'), isTrue);
    expect(isPrivateOrLoopbackHost('172.20.0.4'), isTrue);
    expect(isPrivateOrLoopbackHost('localhost'), isTrue);
    expect(isPrivateOrLoopbackHost('8.8.8.8'), isFalse);
    expect(isPrivateOrLoopbackHost('example.com'), isFalse);
  });

  test('allows HTTP only for numeric private or loopback backup URLs', () {
    expect(
      isAllowedBackupTransport(Uri.parse('http://192.168.1.10:8787')),
      isTrue,
    );
    expect(
      isAllowedBackupTransport(Uri.parse('http://recall.example.com')),
      isFalse,
    );
    expect(
      isAllowedBackupTransport(Uri.parse('ftp://192.168.1.10:8787')),
      isFalse,
    );
    expect(
      isAllowedBackupTransport(Uri.parse('https://recall.example.com')),
      isTrue,
    );
  });

  test('automatic LAN sync runs only on the server subnet', () async {
    final atHome = AutomaticSyncNetworkPolicy(
      localAddressLoader: () async => [InternetAddress('192.168.1.42')],
    );
    final away = AutomaticSyncNetworkPolicy(
      localAddressLoader: () async => [InternetAddress('192.168.50.8')],
    );

    expect(await atHome.shouldAttempt('http://192.168.1.10:8787'), isTrue);
    expect(await away.shouldAttempt('http://192.168.1.10:8787'), isFalse);
  });

  test('public HTTPS deployments retain automatic sync', () async {
    final policy = AutomaticSyncNetworkPolicy(
      localAddressLoader: () async => const [],
    );

    expect(await policy.shouldAttempt('https://recall.example.com'), isTrue);
  });
}
