import 'package:flutter/services.dart';

class ApkInstaller {
  const ApkInstaller();

  static const _channel = MethodChannel('app.recall.notes/apk_installer');

  Future<void> installApk(String path) async {
    try {
      await _channel.invokeMethod<void>('installApk', {'path': path});
    } on PlatformException catch (error) {
      if (error.code == 'permission_required') {
        throw const InstallPermissionRequiredException();
      }

      throw ApkInstallException(
        error.message ?? 'Android could not open the APK installer.',
      );
    }
  }

  Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallPermissionSettings');
    } on PlatformException catch (error) {
      throw ApkInstallException(
        error.message ?? 'Android could not open install permission settings.',
      );
    }
  }
}

class InstallPermissionRequiredException implements Exception {
  const InstallPermissionRequiredException();

  @override
  String toString() => 'Android requires permission to install unknown apps.';
}

class ApkInstallException implements Exception {
  const ApkInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}
