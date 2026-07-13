import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/reminders/reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initializes Android notifications with a bare drawable name', () async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    const notificationsChannel = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    const deviceChannel = MethodChannel('app.recall.notes/device');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notificationsChannel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' => true,
        'getNotificationAppLaunchDetails' => null,
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(
      deviceChannel,
      (call) async => call.method == 'localTimezone' ? 'UTC' : null,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(notificationsChannel, null);
      messenger.setMockMethodCallHandler(deviceChannel, null);
    });

    final scheduler = ReminderScheduler();
    addTearDown(scheduler.dispose);
    await scheduler.initialize();

    final initializeCall = calls.singleWhere(
      (call) => call.method == 'initialize',
    );
    final arguments = initializeCall.arguments as Map<Object?, Object?>;
    final iconName = arguments['defaultIcon'] as String;
    expect(iconName, 'ic_notification');
    expect(
      File('android/app/src/main/res/drawable/$iconName.xml').existsSync(),
      isTrue,
    );
    expect(
      File(
        'android/app/src/main/res/raw/keep.xml',
      ).readAsStringSync(),
      contains('@drawable/$iconName'),
    );
  });

  test('uses exact alarms only when capability is already granted', () async {
    final mode = await resolveAndroidReminderScheduleMode(
      requestPermissions: true,
      requestNotificationsPermission: () async => true,
      canScheduleExactNotifications: () async => true,
    );

    expect(mode, AndroidScheduleMode.exactAllowWhileIdle);
  });

  test('falls back when exact alarms are unavailable', () async {
    final mode = await resolveAndroidReminderScheduleMode(
      requestPermissions: true,
      requestNotificationsPermission: () async => true,
      canScheduleExactNotifications: () async => false,
    );

    expect(mode, AndroidScheduleMode.inexactAllowWhileIdle);
  });

  test('permission API failures do not prevent scheduling', () async {
    final mode = await resolveAndroidReminderScheduleMode(
      requestPermissions: true,
      requestNotificationsPermission: () => throw StateError('unavailable'),
      canScheduleExactNotifications: () => throw StateError('unavailable'),
    );

    expect(mode, AndroidScheduleMode.inexactAllowWhileIdle);
  });

  test(
    'background scheduling does not request notification permission',
    () async {
      var requested = false;
      final mode = await resolveAndroidReminderScheduleMode(
        requestPermissions: false,
        requestNotificationsPermission: () async {
          requested = true;
          return true;
        },
        canScheduleExactNotifications: () async => false,
      );

      expect(requested, isFalse);
      expect(mode, AndroidScheduleMode.inexactAllowWhileIdle);
    },
  );
}
