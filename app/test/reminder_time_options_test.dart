import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/notes/note_models.dart';
import 'package:recall_app/src/reminders/reminder_editor.dart';
import 'package:recall_app/src/reminders/reminder_time_options.dart';

void main() {
  group('reminder time presets', () {
    test('hides each preset after its time has passed today', () {
      final date = DateTime(2026, 7, 13);

      expect(
        _labels(
          availableReminderTimePresets(
            selectedDate: date,
            now: DateTime(2026, 7, 13, 9, 0, 1),
          ),
        ),
        ['Afternoon', 'Evening'],
      );
      expect(
        _labels(
          availableReminderTimePresets(
            selectedDate: date,
            now: DateTime(2026, 7, 13, 13, 0, 1),
          ),
        ),
        ['Evening'],
      );
      expect(
        availableReminderTimePresets(
          selectedDate: date,
          now: DateTime(2026, 7, 13, 18, 0, 1),
        ),
        isEmpty,
      );
    });

    test('shows all presets for a future date', () {
      expect(
        _labels(
          availableReminderTimePresets(
            selectedDate: DateTime(2026, 7, 14),
            now: DateTime(2026, 7, 13, 22),
          ),
        ),
        ['Morning', 'Afternoon', 'Evening'],
      );
    });

    test('uses a future custom time after the evening preset', () {
      final time = validReminderTimeForDate(
        selectedDate: DateTime(2026, 7, 13),
        preferredTime: const TimeOfDay(hour: 9, minute: 0),
        now: DateTime(2026, 7, 13, 19, 7),
      );

      expect(time, const TimeOfDay(hour: 19, minute: 15));
    });

    test('defaults to tomorrow morning when today has ended', () {
      final selection = defaultReminderDateTime(
        DateTime(2026, 7, 13, 23, 59, 30),
      );

      expect(selection, DateTime(2026, 7, 14, 9));
      expect(
        canScheduleReminderOnDate(
          DateTime(2026, 7, 13),
          DateTime(2026, 7, 13, 23, 59, 30),
        ),
        isFalse,
      );
    });
  });

  testWidgets('sheet hides expired presets and remains usable when compact', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 13, 10);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  await showReminderEditor(
                    context,
                    initialAt: null,
                    initialRecurrence: ReminderRecurrence.none,
                    nowProvider: () => now,
                  );
                },
                child: const Text('Open reminder'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open reminder'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Morning'), findsNothing);
    expect(find.textContaining('Afternoon'), findsOneWidget);
    expect(find.textContaining('Evening'), findsOneWidget);

    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Morning'), findsOneWidget);
    expect(find.textContaining('Afternoon'), findsOneWidget);
    expect(find.textContaining('Evening'), findsOneWidget);

    final done = find.widgetWithText(FilledButton, 'Done');
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    expect(done, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

List<String> _labels(List<ReminderTimePreset> presets) {
  return presets.map((preset) => preset.label).toList();
}
