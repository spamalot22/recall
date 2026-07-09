import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../notes/note_models.dart';

class ReminderScheduler {
  ReminderScheduler({
    FlutterLocalNotificationsPlugin? notifications,
    MethodChannel? deviceChannel,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _deviceChannel =
           deviceChannel ?? const MethodChannel('app.recall.notes/device');

  static const _channelId = 'recall_reminders';
  static const _channelName = 'Reminders';
  static const _channelDescription = 'Recall note reminders';

  final FlutterLocalNotificationsPlugin _notifications;
  final MethodChannel _deviceChannel;

  bool _initialized = false;

  Future<void> scheduleNoteReminder({
    required String noteId,
    required String title,
    required String body,
    required NoteReminder reminder,
  }) async {
    await _ensureInitialized();

    if (!reminder.repeats && !reminder.nextFireAt.isAfter(DateTime.now())) {
      await cancelNoteReminder(noteId);
      return;
    }

    final id = notificationIdForNote(noteId);
    final details = _notificationDetails();
    final scheduledDate = _toScheduledDate(reminder.nextFireAt);
    final matchComponents = _matchComponentsFor(reminder.recurrence);
    final scheduleMode = await _androidScheduleMode();

    await _notifications.cancel(id: id);
    try {
      await _notifications.zonedSchedule(
        id: id,
        title: _notificationTitle(title),
        body: _notificationBody(body),
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: matchComponents,
        payload: noteId,
      );
    } on PlatformException {
      if (scheduleMode == AndroidScheduleMode.inexactAllowWhileIdle) {
        rethrow;
      }

      await _notifications.zonedSchedule(
        id: id,
        title: _notificationTitle(title),
        body: _notificationBody(body),
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
        payload: noteId,
      );
    }
  }

  Future<void> cancelNoteReminder(String noteId) async {
    await _ensureInitialized();
    await _notifications.cancel(id: notificationIdForNote(noteId));
  }

  int notificationIdForNote(String noteId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in noteId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return hash & 0x7fffffff;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    timezone_data.initializeTimeZones();
    await _setLocalTimezone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(settings: initializationSettings);
    _initialized = true;
  }

  Future<void> _setLocalTimezone() async {
    try {
      final timezoneName = await _deviceChannel.invokeMethod<String>(
        'localTimezone',
      );
      if (timezoneName == null || timezoneName.isEmpty) {
        return;
      }

      tz.setLocalLocation(tz.getLocation(timezoneName));
    } on Object {
      // UTC fallback is still schedulable. Android devices should return an
      // IANA timezone through the platform channel in normal app runs.
    }
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    await android.requestNotificationsPermission();

    final canScheduleExact = await android.canScheduleExactNotifications();
    if (canScheduleExact == true) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    await android.requestExactAlarmsPermission();
    final grantedAfterRequest = await android.canScheduleExactNotifications();
    return grantedAfterRequest == true
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  tz.TZDateTime _toScheduledDate(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    return tz.TZDateTime.local(
      localDateTime.year,
      localDateTime.month,
      localDateTime.day,
      localDateTime.hour,
      localDateTime.minute,
    );
  }

  DateTimeComponents? _matchComponentsFor(ReminderRecurrence recurrence) {
    return switch (recurrence) {
      ReminderRecurrence.none => null,
      ReminderRecurrence.daily => DateTimeComponents.time,
      ReminderRecurrence.weekly => DateTimeComponents.dayOfWeekAndTime,
      ReminderRecurrence.monthly => DateTimeComponents.dayOfMonthAndTime,
      ReminderRecurrence.yearly => DateTimeComponents.dateAndTime,
    };
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.private,
      ),
    );
  }

  String _notificationTitle(String title) {
    final trimmed = title.trim();
    return trimmed.isEmpty ? 'Recall reminder' : trimmed;
  }

  String _notificationBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return 'Open Recall';
    }

    return trimmed.split('\n').first;
  }
}
