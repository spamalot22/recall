import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../account/secure_account_store.dart';
import '../data/local_database.dart';
import '../notes/note_models.dart';
import '../notes/notes_repository.dart';

const _snoozeTenMinutesAction = 'snooze_10_minutes';
const _snoozeOneHourAction = 'snooze_1_hour';
const _completeAction = 'complete_reminder';

@pragma('vm:entry-point')
void reminderNotificationActionBackground(NotificationResponse response) {
  unawaited(_handleReminderNotificationAction(response));
}

Future<void> _handleReminderNotificationAction(
  NotificationResponse response,
) async {
  final noteId = response.payload;
  if (noteId == null || noteId.isEmpty || noteId.length > 128) {
    return;
  }
  final snoozeDuration = switch (response.actionId) {
    _snoozeTenMinutesAction => const Duration(minutes: 10),
    _snoozeOneHourAction => const Duration(hours: 1),
    _ => null,
  };
  if (snoozeDuration == null && response.actionId != _completeAction) {
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  final accountStore = SecureAccountStore();
  final database = LocalDatabase(
    databaseKey: accountStore.readOrCreateDatabaseKey,
  );
  final scheduler = ReminderScheduler();
  try {
    final repository = NotesRepository(database);
    if (snoozeDuration != null) {
      final schedule = await repository.snoozeNoteReminder(
        noteId,
        DateTime.now().add(snoozeDuration),
      );
      if (schedule != null) {
        await scheduler.scheduleSnooze(schedule, requestPermissions: false);
      }
    } else {
      await repository.completeReminderOccurrence(noteId);
      await scheduler.cancelSnooze(noteId);
    }
  } on Object {
    // Notification actions must not crash the background Flutter isolate.
  } finally {
    scheduler.dispose();
    await database.close();
  }
}

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
  final StreamController<String> _openNoteRequests =
      StreamController<String>.broadcast();

  Future<void>? _initialization;

  Stream<String> get openNoteRequests => _openNoteRequests.stream;

  Future<void> initialize() => _ensureInitialized();

  void dispose() => _openNoteRequests.close();

  Future<void> scheduleNoteReminder({
    required String noteId,
    required String title,
    required String body,
    required NoteReminder reminder,
    bool requestPermissions = true,
  }) async {
    await _ensureInitialized();

    if (!reminder.repeats && !reminder.nextFireAt.isAfter(DateTime.now())) {
      await cancelNoteReminder(noteId);
      return;
    }

    final id = notificationIdForNote(noteId);
    final notificationTitle = _notificationTitle(title);
    final notificationBody = _notificationBody(body);
    final details = _notificationDetails(body);
    final scheduledDate = _toScheduledDate(reminder.nextFireAt);
    final matchComponents = _matchComponentsFor(reminder.recurrence);
    final scheduleMode = await _androidScheduleMode(
      requestPermissions: requestPermissions,
    );

    await _notifications.cancel(id: id);
    try {
      await _notifications.zonedSchedule(
        id: id,
        title: notificationTitle,
        body: notificationBody,
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
        title: notificationTitle,
        body: notificationBody,
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
    await cancelSnooze(noteId);
  }

  Future<void> cancelSnooze(String noteId) async {
    await _ensureInitialized();
    await _notifications.cancel(id: snoozeNotificationIdForNote(noteId));
  }

  Future<void> scheduleSnooze(
    ScheduledNoteReminder schedule, {
    bool requestPermissions = true,
  }) async {
    await _ensureInitialized();
    final snoozeUntil = schedule.reminder.snoozeUntil;
    final id = snoozeNotificationIdForNote(schedule.noteId);
    await _notifications.cancel(id: id);
    if (snoozeUntil == null || !snoozeUntil.isAfter(DateTime.now())) {
      return;
    }

    await _notifications.zonedSchedule(
      id: id,
      title: _notificationTitle(schedule.title),
      body: _notificationBody(schedule.body),
      scheduledDate: _toScheduledDate(snoozeUntil),
      notificationDetails: _notificationDetails(schedule.body),
      androidScheduleMode: await _androidScheduleMode(
        requestPermissions: requestPermissions,
      ),
      payload: schedule.noteId,
    );
  }

  Future<void> reconcileNoteReminders(
    List<ScheduledNoteReminder> schedules, {
    bool requestPermissions = true,
  }) async {
    await _ensureInitialized();
    final desiredIds = schedules
        .map((schedule) => notificationIdForNote(schedule.noteId))
        .toSet();
    for (final schedule in schedules) {
      final snoozeUntil = schedule.reminder.snoozeUntil;
      if (snoozeUntil != null && snoozeUntil.isAfter(DateTime.now())) {
        desiredIds.add(snoozeNotificationIdForNote(schedule.noteId));
      }
    }
    final pending = await _notifications.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.payload != null &&
          !desiredIds.contains(notification.id)) {
        await _notifications.cancel(id: notification.id);
      }
    }
    for (final schedule in schedules) {
      await scheduleNoteReminder(
        noteId: schedule.noteId,
        title: schedule.title,
        body: schedule.body,
        reminder: schedule.reminder,
        requestPermissions: requestPermissions,
      );
      await scheduleSnooze(schedule, requestPermissions: requestPermissions);
    }
  }

  int notificationIdForNote(String noteId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in noteId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    return hash & 0x7fffffff;
  }

  int snoozeNotificationIdForNote(String noteId) {
    return notificationIdForNote('snooze:$noteId');
  }

  Future<void> _ensureInitialized() {
    final active = _initialization;
    if (active != null) {
      return active;
    }
    final operation = _initialize();
    _initialization = operation;
    return operation;
  }

  Future<void> _initialize() async {
    timezone_data.initializeTimeZones();
    await _setLocalTimezone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
    );
    try {
      await _notifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            reminderNotificationActionBackground,
      );
      final launchDetails = await _notifications
          .getNotificationAppLaunchDetails();
      if ((launchDetails?.didNotificationLaunchApp ?? false) &&
          launchDetails?.notificationResponse != null) {
        _handleNotificationResponse(launchDetails!.notificationResponse!);
      }
    } on Object {
      _initialization = null;
      rethrow;
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      return;
    }
    final noteId = response.payload;
    if (noteId != null &&
        noteId.isNotEmpty &&
        noteId.length <= 128 &&
        !_openNoteRequests.isClosed) {
      _openNoteRequests.add(noteId);
    }
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

  Future<AndroidScheduleMode> _androidScheduleMode({
    bool requestPermissions = true,
  }) async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    if (requestPermissions) {
      await android.requestNotificationsPermission();
    }

    final canScheduleExact = await android.canScheduleExactNotifications();
    if (canScheduleExact == true) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    if (!requestPermissions) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
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

  NotificationDetails _notificationDetails(String body) {
    final expandedBody = _limitNotificationText(body.trim(), 1000);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.private,
        styleInformation: expandedBody.isEmpty
            ? null
            : BigTextStyleInformation(expandedBody),
        actions: const [
          AndroidNotificationAction(_snoozeTenMinutesAction, 'Snooze 10 min'),
          AndroidNotificationAction(_snoozeOneHourAction, 'Snooze 1 hour'),
          AndroidNotificationAction(
            _completeAction,
            'Done',
            semanticAction: SemanticAction.markAsRead,
          ),
        ],
      ),
    );
  }

  String _notificationTitle(String title) {
    final trimmed = title.trim();
    return trimmed.isEmpty
        ? 'Recall reminder'
        : _limitNotificationText(trimmed, 120);
  }

  String _notificationBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return 'Open Recall';
    }

    return _limitNotificationText(trimmed.split('\n').first, 240);
  }

  String _limitNotificationText(String value, int maxRunes) {
    final runes = value.runes;
    if (runes.length <= maxRunes) {
      return value;
    }
    return '${String.fromCharCodes(runes.take(maxRunes - 3))}...';
  }
}
