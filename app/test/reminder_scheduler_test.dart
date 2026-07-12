import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/reminders/reminder_scheduler.dart';

void main() {
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
