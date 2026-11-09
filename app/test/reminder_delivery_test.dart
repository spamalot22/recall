import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/notes/note_models.dart';
import 'package:recall_app/src/reminders/reminder_alarm.dart';
import 'package:recall_app/src/reminders/reminder_editor.dart';
import 'package:recall_app/src/reminders/reminder_scheduler.dart';
import 'package:recall_app/src/sync/sync_execution_lock.dart';

class _ImmediateLock implements SyncExecutionLock {
  @override
  Future<T> synchronized<T>(Future<T> Function() operation) => operation();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final anchor = DateTime(2026, 10, 5, 22);
  final restart = DateTime(2026, 11, 9, 22);
  final reminder = NoteReminder(
    nextFireAt: anchor,
    recurrence: ReminderRecurrence.daily,
    cycle: const ReminderCycle(
      activeDuration: ReminderDuration(
        value: 1,
        unit: ReminderDurationUnit.weeks,
      ),
      restDuration: ReminderDuration(
        value: 4,
        unit: ReminderDurationUnit.weeks,
      ),
    ),
  );
  late DateTime now;
  late ReminderScheduler scheduler;
  late Map<int, Map<String, Object?>> pending;
  late List<int> cancelled;
  late List<Map<String, Object?>> scheduled;
  late List<Map<String, Object?>> active;
  int? failAfter;
  String? failNote;
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const device = MethodChannel('app.recall.notes/device');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    now = DateTime(2026, 10, 12, 23);
    pending = {};
    cancelled = [];
    scheduled = [];
    active = [];
    failAfter = null;
    failNote = null;
    messenger.setMockMethodCallHandler(device, (_) async => 'Europe/London');
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize' ||
          call.method == 'canScheduleExactNotifications') {
        return true;
      }
      if (call.method == 'pendingNotificationRequests') {
        return pending.values.toList();
      }
      if (call.method == 'getActiveNotifications') return active;
      if (call.method == 'cancel') {
        final args = Map<String, Object?>.from(call.arguments as Map);
        cancelled.add(args['id'] as int);
        pending.remove(args['id']);
        active.removeWhere((entry) => entry['id'] == args['id']);
      }
      if (call.method == 'zonedSchedule') {
        final args = Map<String, Object?>.from(call.arguments as Map);
        if (scheduled.length == failAfter ||
            ReminderAlarm.noteIdFromPayload(args['payload'] as String?) ==
                failNote) {
          throw PlatformException(code: 'schedule_failed');
        }
        scheduled.add(args);
        pending[args['id'] as int] = {
          'id': args['id'],
          'title': args['title'],
          'body': args['body'],
          'payload': args['payload'],
        };
      }
      return null;
    });
    scheduler = ReminderScheduler(
      executionLock: _ImmediateLock(),
      now: () => now,
    );
  });
  tearDown(() {
    scheduler.dispose();
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(device, null);
  });

  Future<void> schedule(String id) => scheduler.scheduleNoteReminder(
    noteId: id,
    title: 'Reminder',
    body: '',
    reminder: reminder,
    requestPermissions: false,
  );

  test('queues the next active week during a four-week rest', () async {
    await schedule('note');
    final times = scheduled
        .map((a) => ReminderAlarm.parse(a['payload'] as String)!.at)
        .toList();
    expect(times.first, restart.toUtc());
    expect(times.take(7), [
      for (var i = 0; i < 7; i++) DateTime(2026, 11, 9 + i, 22).toUtc(),
    ]);
    expect(times[7], DateTime(2026, 12, 14, 22).toUtc());
  });

  test(
    'spring clock change does not shift later cycle times',
    () {
      final rule = NoteReminder(
        nextFireAt: DateTime(2026, 2, 1, 2, 30),
        recurrence: ReminderRecurrence.daily,
        cycle: reminder.cycle,
      );
      final queued = reminderOccurrencesAfter(
        rule,
        after: DateTime(2026, 1, 31),
        count: 30,
      );
      final regenerated = reminderOccurrencesAfter(
        rule,
        after: DateTime(2026, 4, 1),
        count: 7,
      );
      expect(regenerated.first, DateTime(2026, 4, 12, 2, 30));
      expect(
        queued.where((date) => date.isAfter(DateTime(2026, 4, 1))).take(7),
        regenerated,
      );
      expect(
        queued
            .where((date) => date.month == 3 && date.day > 8)
            .every((date) => date.hour == 2),
        isTrue,
      );
    },
    skip: DateTime(2026, 1).timeZoneOffset != const Duration(hours: -5),
  );

  test(
    'notification payload retains note identity and rejects malformed input',
    () {
      final alarm = ReminderAlarm('note', restart, 'rule');
      expect(ReminderAlarm.noteIdFromPayload(alarm.payload), 'note');
      expect(ReminderAlarm.noteIdFromPayload('legacy-note'), 'legacy-note');
      expect(ReminderAlarm.noteIdFromPayload('{broken'), isNull);
      expect(
        ReminderAlarm.parse(
          '{"note":"note","at":99999999999999999,"rule":"r"}',
        ),
        isNull,
      );
    },
  );

  test('expired pending alarm is removed after its grace period', () async {
    await schedule('note');
    final expiredId = pending.keys.first;
    now = restart.add(const Duration(days: 2));
    await schedule('note');
    expect(cancelled, contains(expiredId));
  });

  test('overdue snooze survives maintenance but removal cancels it', () async {
    final snoozed = NoteReminder(
      nextFireAt: anchor,
      recurrence: ReminderRecurrence.daily,
      cycle: reminder.cycle,
      snoozeUntil: restart,
    );
    now = restart.subtract(const Duration(minutes: 5));
    await scheduler.scheduleSnooze(
      ScheduledNoteReminder(
        noteId: 'note',
        title: 'Reminder',
        body: '',
        reminder: snoozed,
      ),
      requestPermissions: false,
    );
    final id = scheduler.snoozeNotificationIdForNote('note');
    now = restart.add(const Duration(minutes: 5));
    await scheduler.scheduleSnooze(
      ScheduledNoteReminder(
        noteId: 'note',
        title: 'Reminder',
        body: '',
        reminder: snoozed,
      ),
      requestPermissions: false,
    );
    expect(pending.containsKey(id), isTrue);
    await scheduler.cancelSnooze('note');
    expect(pending.containsKey(id), isFalse);
  });

  test(
    'maintenance keeps the due alarm if Android delivery is delayed',
    () async {
      await schedule('note');
      final due = pending.entries.first;
      now = restart.add(const Duration(minutes: 5));
      await scheduler.reconcileNoteReminders([
        ScheduledNoteReminder(
          noteId: 'note',
          title: 'Reminder',
          body: '',
          reminder: reminder,
        ),
      ], requestPermissions: false);
      expect(cancelled, isNot(contains(due.key)));
      expect(pending[due.key], due.value);
      expect(
        scheduled.map((a) => ReminderAlarm.parse(a['payload'] as String)!.at),
        contains(DateTime(2026, 11, 10, 22).toUtc()),
      );
    },
  );

  test('failed replacement preserves already queued alarms', () async {
    await schedule('note');
    final before = Map.of(pending);
    failNote = 'note';
    await expectLater(schedule('note'), throwsA(isA<PlatformException>()));
    expect(pending, before);
    expect(cancelled, isEmpty);
  });

  test(
    'partly failed replacement removes its newly introduced alarms',
    () async {
      await schedule('note');
      final before = Map.of(pending);
      scheduled.clear();
      failAfter = 2;
      await expectLater(
        scheduler.scheduleNoteReminder(
          noteId: 'note',
          title: 'Reminder',
          body: '',
          reminder: NoteReminder(
            nextFireAt: anchor.add(const Duration(hours: 1)),
            recurrence: reminder.recurrence,
            cycle: reminder.cycle,
          ),
          requestPermissions: false,
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(pending, before);
    },
  );

  test(
    'elapsed one-time schedule cleans up obsolete recurring alarms',
    () async {
      await schedule('note');
      await scheduler.scheduleNoteReminder(
        noteId: 'note',
        title: 'Reminder',
        body: '',
        reminder: NoteReminder(
          nextFireAt: now.subtract(const Duration(minutes: 1)),
          recurrence: ReminderRecurrence.none,
        ),
        requestPermissions: false,
      );
      expect(pending, isEmpty);
    },
  );

  test(
    'deleting a note also clears its already delivered notifications',
    () async {
      await schedule('note');
      final deliveredId = pending.keys.first;
      pending.remove(deliveredId);
      active.add({'id': deliveredId, 'groupKey': 'recall-note:note'});
      await scheduler.cancelNoteReminder('note');
      expect(active, isEmpty);
    },
  );

  test(
    'one failed reminder does not prevent the other notes scheduling',
    () async {
      failNote = 'bad';
      await expectLater(
        scheduler.reconcileNoteReminders([
          for (final id in ['bad', 'good'])
            ScheduledNoteReminder(
              noteId: id,
              title: 'Reminder',
              body: '',
              reminder: reminder,
            ),
        ], requestPermissions: false),
        throwsA(isA<PlatformException>()),
      );
      expect(scheduled, hasLength(24));
      expect(
        scheduled.every(
          (a) =>
              ReminderAlarm.noteIdFromPayload(a['payload'] as String) == 'good',
        ),
        isTrue,
      );
    },
  );

  test('deleting a note cancels stable occurrence alarms', () async {
    await schedule('note');
    await scheduler.cancelNoteReminder('note');
    expect(pending, isEmpty);
  });

  testWidgets('cycle editor displays next date after a four-week rest', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = null;
    now = DateTime(2026, 11, 9, 21);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showReminderEditor(
                context,
                initialAt: anchor,
                initialRecurrence: ReminderRecurrence.daily,
                initialCycle: reminder.cycle,
                nowProvider: () => now,
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final preview = tester.widget<Text>(
      find.byKey(const Key('next-cycle-notification')),
    );
    expect(preview.data, contains('November 9, 2026'));
    expect(preview.data, contains('10:00 PM'));
  });
}
