import 'dart:async';
import 'dart:io';

import 'package:dynamic_color_testing/dynamic_color_testing.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:recall_app/main.dart';
import 'package:recall_app/src/account/secure_account_store.dart';
import 'package:recall_app/src/data/local_database.dart';
import 'package:recall_app/src/notes/mood_analyzer.dart';
import 'package:recall_app/src/notes/note_models.dart';
import 'package:recall_app/src/notes/notes_repository.dart';
import 'package:recall_app/src/providers.dart';
import 'package:recall_app/src/reminders/reminder_scheduler.dart';
import 'package:recall_app/src/sync/sync_service.dart';
import 'package:recall_app/src/sync/background_sync.dart';
import 'package:recall_app/src/updates/apk_installer.dart';
import 'package:recall_app/src/updates/update_service.dart';

void main() {
  setUp(() => DynamicColorTestingUtils.setMockDynamicColors());

  testWidgets('uses the Android Material dynamic color scheme', (tester) async {
    DynamicColorTestingUtils.setMockDynamicColors(
      corePalette: SampleCorePalettes.green,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(RecallHomePage));
    expect(
      Theme.of(context).colorScheme.primary,
      SampleColorSchemes.green(Brightness.light).primary,
    );
  });

  testWidgets('Recall home screen renders note cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Recall'), findsOneWidget);
    expect(find.text('Search notes'), findsOneWidget);
    expect(find.text('Monthly filter order'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('new note opens body-first with an optional title', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget);
    expect(find.text('Title (optional)'), findsOneWidget);
    expect(find.text('Start writing...'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    final bodyField = tester.widget<TextField>(
      find.byKey(const Key('note-body-field')),
    );
    expect(bodyField.focusNode?.hasFocus, isTrue);

    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    final scaffold = find.byType(Scaffold);
    final scaffoldHeight = tester.getSize(scaffold).height;
    final keyboardInset = MediaQuery.viewInsetsOf(
      tester.element(scaffold),
    ).bottom;
    final reminderButton = find.byTooltip('Add reminder');
    expect(
      tester.getRect(reminderButton).bottom,
      lessThanOrEqualTo(scaffoldHeight - keyboardInset),
    );

    await tester.tap(reminderButton);
    await tester.pumpAndSettle();

    expect(bodyField.focusNode?.hasFocus, isFalse);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Choose date'), findsOneWidget);
    expect(find.text('Choose time'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
  });

  testWidgets('date and time pickers open independently', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add reminder'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose time'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('separate date and time choices save one reminder timestamp', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(
      database,
      moodAnalyzer: _ClearMoodAnalyzer(),
    );
    final today = DateTime.now();
    final expectedDate = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 1));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-body-field')),
      'Remember this tomorrow morning',
    );
    await tester.tap(find.byTooltip('Add reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Morning'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    final notes = await database.select(database.notes).get();
    expect(notes, hasLength(1));
    final saved = await repository.loadNoteForEditing(notes.single.id);
    final reminderAt = saved?.reminder?.nextFireAt;
    expect(reminderAt, isNotNull);
    expect(reminderAt?.year, expectedDate.year);
    expect(reminderAt?.month, expectedDate.month);
    expect(reminderAt?.day, expectedDate.day);
    expect(reminderAt?.hour, 9);
    expect(reminderAt?.minute, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('editing a reminder preserves and updates separate choices', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(
      database,
      moodAnalyzer: _ClearMoodAnalyzer(),
    );
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1, 13);
    final noteId = await repository.createTextNote(
      title: 'Existing reminder',
      body: 'Change this reminder time.',
      reminder: NoteReminder(
        nextFireAt: tomorrow,
        recurrence: ReminderRecurrence.none,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Existing reminder'));
    await tester.pumpAndSettle();

    final bodyFieldFinder = find.byKey(const Key('note-body-field'));
    await tester.tap(bodyFieldFinder);
    await tester.pump();
    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();

    final timestampButton = find.byKey(
      const Key('editor-reminder-timestamp-button'),
    );
    expect(timestampButton, findsOneWidget);
    final scaffold = find.byType(Scaffold);
    final keyboardTop =
        tester.getSize(scaffold).height -
        MediaQuery.viewInsetsOf(tester.element(scaffold)).bottom;
    final timestampRect = tester.getRect(timestampButton);
    expect(timestampRect.bottom, lessThanOrEqualTo(keyboardTop));
    expect(timestampRect.bottom, greaterThan(keyboardTop - 56));

    await tester.tap(timestampButton);
    await tester.pump();
    final bodyField = tester.widget<TextField>(bodyFieldFinder);
    expect(bodyField.focusNode?.hasFocus, isFalse);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    final tomorrowChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Tomorrow'),
    );
    final afternoonChip = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.textContaining('Afternoon'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(tomorrowChip.selected, isTrue);
    expect(afternoonChip.selected, isTrue);

    await tester.tap(find.textContaining('Evening'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    final saved = await repository.loadNoteForEditing(noteId);
    expect(saved?.reminder?.nextFireAt.hour, 18);
    expect(saved?.reminder?.nextFireAt.minute, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('titleless notes lead with their content', (tester) async {
    const titleless = NotePreview(
      id: 'titleless',
      title: '',
      body: 'The body is the note',
      mood: ColorMood.focus,
      reminderLabel: '',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith(
            (ref) => Stream.value(const [titleless]),
          ),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();

    expect(find.text('The body is the note'), findsOneWidget);
    expect(find.text('Untitled'), findsNothing);
    expect(find.byTooltip('Use list layout'), findsOneWidget);

    await tester.tap(find.byTooltip('Use list layout'));
    await tester.pump();
    expect(find.byTooltip('Use grid layout'), findsOneWidget);
  });

  testWidgets('note cards shrink to content and retain their height cap', (
    tester,
  ) async {
    const shortNote = NotePreview(
      id: 'short-card',
      title: '',
      body: 'One line',
      mood: ColorMood.clear,
      reminderLabel: '',
    );
    final reminderNote = NotePreview(
      id: 'reminder-card',
      title: '',
      body: 'One line',
      mood: ColorMood.clear,
      reminderLabel: 'Tomorrow 9:00 AM',
      reminderAt: DateTime(2026, 8, 26, 9),
    );
    const longNote = NotePreview(
      id: 'long-card',
      title: '',
      body:
          'Line one\nLine two\nLine three\nLine four\nLine five\n'
          'Line six\nLine seven\nLine eight\nLine nine',
      mood: ColorMood.clear,
      reminderLabel: '',
    );

    Future<double> cardHeight(
      NotePreview note, {
      double maxHeight = 204,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  child: NoteCard(note: note, maxHeight: maxHeight),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byType(NoteCard)).height;
    }

    final shortHeight = await cardHeight(shortNote);
    final reminderHeight = await cardHeight(reminderNote);
    final longHeight = await cardHeight(longNote);
    final cappedListHeight = await cardHeight(longNote, maxHeight: 176);

    expect(shortHeight, 56);
    expect(reminderHeight, greaterThan(shortHeight));
    expect(reminderHeight, lessThan(204));
    expect(longHeight, lessThanOrEqualTo(204));
    expect(longHeight, greaterThan(reminderHeight));
    expect(cappedListHeight, lessThanOrEqualTo(176));
  });

  testWidgets('holding a card opens actions without an overflow button', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.onLongPress != null,
      ),
      findsNWidgets(sampleNotes.length),
    );
    await tester.longPress(find.text('Monthly filter order'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Unpin'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Archive'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Move to trash'), findsOneWidget);
  });

  testWidgets('holding and dragging a card persists its new position', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(
      database,
      moodAnalyzer: _ClearMoodAnalyzer(),
    );
    final firstId = await repository.createTextNote(title: 'First', body: '');
    final secondId = await repository.createTextNote(title: 'Second', body: '');
    final thirdId = await repository.createTextNote(title: 'Third', body: '');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use list layout'));
    await tester.pumpAndSettle();

    final source = tester.getCenter(find.text('Third'));
    final target = tester.getCenter(find.text('First')) + const Offset(0, 30);
    final originalOrder = (await repository.watchNotePreviews().first)
        .map((note) => note.id)
        .toList();
    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 360));
    await gesture.moveTo(target);

    var animatedTranslation = 0.0;
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 8));
      animatedTranslation = _largestCardTranslation(tester, [
        firstId,
        secondId,
        thirdId,
      ]);
      if (animatedTranslation > 1) {
        break;
      }
    }
    expect(animatedTranslation, greaterThan(1));
    expect(
      find.byKey(ValueKey('note-drop-placeholder-$thirdId')),
      findsOneWidget,
    );
    expect(
      (await repository.watchNotePreviews().first).map((note) => note.id),
      originalOrder,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      _largestCardTranslation(tester, [firstId, secondId, thirdId]),
      lessThan(animatedTranslation),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      _largestCardTranslation(tester, [firstId, secondId, thirdId]),
      closeTo(0, 0.01),
    );

    expect(
      (await repository.watchNotePreviews().first).map((note) => note.id),
      [secondId, firstId, thirdId],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('grid cards animate into their reordered positions', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(
      database,
      moodAnalyzer: _ClearMoodAnalyzer(),
    );
    final firstId = await repository.createTextNote(
      title: 'Grid first',
      body: '',
    );
    final secondId = await repository.createTextNote(
      title: 'Grid second',
      body: '',
    );
    final thirdId = await repository.createTextNote(
      title: 'Grid third',
      body: '',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();

    final source = tester.getCenter(find.text('Grid third'));
    final target =
        tester.getCenter(find.text('Grid first')) + const Offset(0, 30);
    final originalOrder = (await repository.watchNotePreviews().first)
        .map((note) => note.id)
        .toList();
    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 360));
    await gesture.moveTo(target);

    var animatedTranslation = 0.0;
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 8));
      animatedTranslation = _largestCardTranslation(tester, [
        firstId,
        secondId,
        thirdId,
      ]);
      if (animatedTranslation > 1) {
        break;
      }
    }
    expect(animatedTranslation, greaterThan(1));
    expect(
      (await repository.watchNotePreviews().first).map((note) => note.id),
      originalOrder,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      _largestCardTranslation(tester, [firstId, secondId, thirdId]),
      closeTo(0, 0.01),
    );
    expect(
      (await repository.watchNotePreviews().first).map((note) => note.id),
      [secondId, firstId, thirdId],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('grid drop targets empty space in the pointed column', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(
      database,
      moodAnalyzer: _ClearMoodAnalyzer(),
    );
    final firstId = await repository.createTextNote(
      title: 'Column first',
      body: '',
    );
    final secondId = await repository.createTextNote(
      title: 'Column second',
      body: '',
    );
    final tallId = await repository.createTextNote(
      title: 'Tall opposite card',
      body: List.filled(24, 'A tall card body').join(' '),
    );
    final sourceId = await repository.createTextNote(
      title: 'Move to short column',
      body: '',
    );
    final lastShortColumnId = await repository.createTextNote(
      title: 'Last short-column card',
      body: '',
    );
    await repository.reorderNotes([
      firstId,
      secondId,
      tallId,
      sourceId,
      lastShortColumnId,
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();

    final tallRect = tester.getRect(
      find.byKey(ValueKey('note-position-$tallId')),
    );
    final lastShortColumnRect = tester.getRect(
      find.byKey(ValueKey('note-position-$lastShortColumnId')),
    );
    expect(
      (lastShortColumnRect.center.dx - tallRect.center.dx).abs(),
      greaterThan(100),
    );
    expect(lastShortColumnRect.bottom, lessThan(tallRect.bottom));
    final target = Offset(
      lastShortColumnRect.center.dx,
      (lastShortColumnRect.bottom + tallRect.bottom) / 2,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Move to short column')),
    );
    await tester.pump(const Duration(milliseconds: 360));
    await gesture.moveTo(target);
    for (var frame = 0; frame < 36; frame++) {
      await tester.pump(const Duration(milliseconds: 8));
    }

    final placeholderRect = tester.getRect(
      find.byKey(ValueKey('note-drop-placeholder-$sourceId')),
    );
    expect(
      placeholderRect.center.dx,
      closeTo(lastShortColumnRect.center.dx, 1),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      (await repository.watchNotePreviews().first).map((note) => note.id),
      [firstId, secondId, tallId, lastShortColumnId, sourceId],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'grid drop keeps the pointed column when removing the source reflows it',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [600.0, 800.0, 1200.0]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        final database = LocalDatabase.forTesting(NativeDatabase.memory());
        final repository = NotesRepository(
          database,
          moodAnalyzer: _ClearMoodAnalyzer(),
        );
        final firstId = await repository.createTextNote(
          title: 'First left card',
          body: '',
        );
        final firstRightId = await repository.createTextNote(
          title: 'First right card',
          body: '',
        );
        final sourceId = await repository.createTextNote(
          title: 'Tall card moving right',
          body: List.filled(24, 'A tall source card body').join(' '),
        );
        final secondRightId = await repository.createTextNote(
          title: 'Second right card',
          body: '',
        );
        final lastRightId = await repository.createTextNote(
          title: 'Last right card',
          body: '',
        );
        await repository.reorderNotes([
          firstId,
          firstRightId,
          sourceId,
          secondRightId,
          lastRightId,
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localDatabaseProvider.overrideWithValue(database),
              moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
              reminderSchedulerProvider.overrideWithValue(
                _NoopReminderScheduler(),
              ),
              syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
              storedSessionProvider.overrideWith((ref) async => null),
              backgroundStartupEnabledProvider.overrideWithValue(false),
            ],
            child: const RecallApp(),
          ),
        );
        await tester.pumpAndSettle();

        final sourceRect = tester.getRect(
          find.byKey(ValueKey('note-position-$sourceId')),
        );
        final lastRightRect = tester.getRect(
          find.byKey(ValueKey('note-position-$lastRightId')),
        );
        expect(
          (sourceRect.center.dx - lastRightRect.center.dx).abs(),
          greaterThan(100),
        );
        expect(lastRightRect.bottom, lessThan(sourceRect.bottom));
        final target = Offset(
          lastRightRect.center.dx,
          lastRightRect.bottom + 28,
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Tall card moving right')),
        );
        await tester.pump(const Duration(milliseconds: 360));
        await gesture.moveTo(target);
        for (var frame = 0; frame < 36; frame++) {
          await tester.pump(const Duration(milliseconds: 8));
        }

        final placeholderRect = tester.getRect(
          find.byKey(ValueKey('note-drop-placeholder-$sourceId')),
        );
        expect(placeholderRect.center.dx, closeTo(lastRightRect.center.dx, 1));

        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          tester
              .getRect(find.byKey(ValueKey('note-position-$sourceId')))
              .center
              .dx,
          closeTo(lastRightRect.center.dx, 1),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        await database.close();
      }
    },
  );

  testWidgets('a card can be dropped into empty space before the first card', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(
      database,
      moodAnalyzer: _ClearMoodAnalyzer(),
    );
    final firstId = await repository.createTextNote(title: 'First', body: '');
    final secondId = await repository.createTextNote(title: 'Second', body: '');
    final thirdId = await repository.createTextNote(title: 'Third', body: '');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use list layout'));
    await tester.pumpAndSettle();

    final firstCard = find.byKey(ValueKey('note-position-$thirdId'));
    final leadingSpace = Offset(
      tester.getCenter(firstCard).dx,
      tester.getTopLeft(firstCard).dy - 6,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('First')),
    );
    await tester.pump(const Duration(milliseconds: 360));
    await gesture.moveTo(leadingSpace);

    var animatedTranslation = 0.0;
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 8));
      animatedTranslation = _largestCardTranslation(tester, [
        firstId,
        secondId,
        thirdId,
      ]);
      if (animatedTranslation > 1) {
        break;
      }
    }
    expect(animatedTranslation, greaterThan(1));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      (await repository.watchNotePreviews().first).map((note) => note.id),
      [firstId, thirdId, secondId],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('cancelling a live card reorder restores the saved order', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(
      database,
      moodAnalyzer: _ClearMoodAnalyzer(),
    );
    await repository.createTextNote(title: 'First', body: '');
    await repository.createTextNote(title: 'Second', body: '');
    await repository.createTextNote(title: 'Third', body: '');
    final originalOrder = (await repository.watchNotePreviews().first)
        .map((note) => note.id)
        .toList();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use list layout'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('First')),
    );
    await tester.pump(const Duration(milliseconds: 360));
    await gesture.moveTo(
      tester.getCenter(find.text('Third')) + const Offset(0, 30),
    );
    var animatedTranslation = 0.0;
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 8));
      animatedTranslation = _largestCardTranslation(tester, originalOrder);
      if (animatedTranslation > 1) {
        break;
      }
    }
    expect(animatedTranslation, greaterThan(1));

    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(
      (await repository.watchNotePreviews().first).map((note) => note.id),
      originalOrder,
    );
    expect(_largestCardTranslation(tester, originalOrder), closeTo(0, 0.01));
    expect(find.text('Move to trash'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('filtered reordering preserves hidden card positions', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(
      database,
      moodAnalyzer: _ClearMoodAnalyzer(),
    );
    final firstId = await repository.createTextNote(
      title: 'Visible first',
      body: '',
    );
    final hiddenId = await repository.createTextNote(title: 'Hidden', body: '');
    final thirdId = await repository.createTextNote(
      title: 'Visible third',
      body: '',
    );
    await repository.reorderNotes([thirdId, hiddenId, firstId]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Visible');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use list layout'));
    await tester.pumpAndSettle();

    final source = tester.getCenter(find.text('Visible third'));
    final target =
        tester.getCenter(find.text('Visible first')) + const Offset(0, 30);
    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 360));
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      (await repository.watchNotePreviews().first).map((note) => note.id),
      [firstId, hiddenId, thirdId],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('dragging a card near the viewport edge auto-scrolls', (
    tester,
  ) async {
    final notes = List.generate(
      20,
      (index) => NotePreview(
        id: 'scroll-card-$index',
        title: 'Scroll card $index',
        body: 'Card body',
        mood: ColorMood.clear,
        reminderLabel: '',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(notes)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Use list layout'));
    await tester.pumpAndSettle();

    final scrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .singleWhere(
          (state) =>
              state.position.axis == Axis.vertical &&
              state.position.maxScrollExtent > 0,
        );
    final source = tester.getCenter(find.text('Scroll card 0'));
    final viewportBox = scrollable.context.findRenderObject()! as RenderBox;
    final viewport = viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 360));
    await gesture.moveTo(Offset(source.dx, viewport.bottom - 2));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(scrollable.position.pixels, greaterThan(0));
    final placeholder = find.byKey(
      const ValueKey('note-drop-placeholder-scroll-card-0'),
    );
    expect(placeholder, findsOneWidget);
    final placeholderRect = tester.getRect(placeholder);
    expect(placeholderRect.bottom, greaterThan(viewport.top));
    expect(placeholderRect.top, lessThan(viewport.bottom));

    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('swiping a note archives it with undo feedback', (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(
      database,
      moodAnalyzer: _ClearMoodAnalyzer(),
    );
    final noteId = await repository.createTextNote(
      title: 'Swipe me',
      body: 'Archive this note from the home screen.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byType(Dismissible);
    final cardWidth = tester.getSize(card).width;
    await tester.drag(card, Offset(-cardWidth * 0.8, 0), touchSlopY: 0);
    await tester.pumpAndSettle();

    expect(find.text('Note archived.'), findsOneWidget);
    final archived = await (database.select(
      database.notes,
    )..where((note) => note.id.equals(noteId))).getSingle();
    expect(archived.isArchived, isTrue);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Swipe me'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('back saves a non-empty titleless note', (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          reminderSchedulerProvider.overrideWithValue(
            _FailingCancellationReminderScheduler(),
          ),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-body-field')),
      'Captured without a title',
    );
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    final notes = await database.select(database.notes).get();
    expect(notes, hasLength(1));
    expect(notes.single.title, isEmpty);
    expect(notes.single.body, 'Captured without a title');
    expect(
      find.text('Note saved, but the reminder could not be scheduled.'),
      findsNothing,
    );
  });

  testWidgets('new note autosaves while typing and Done reuses the draft', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    final bodyField = find.byKey(const Key('note-body-field'));
    await tester.enterText(bodyField, 'Autosaved first version');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    var notes = await database.select(database.notes).get();
    expect(notes, hasLength(1));
    final autosavedId = notes.single.id;
    expect(notes.single.body, 'Autosaved first version');
    expect(find.byType(NoteEditorPage), findsOneWidget);

    await tester.enterText(bodyField, 'Autosaved final version');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Done'));
    await tester.pumpAndSettle();

    notes = await database.select(database.notes).get();
    expect(notes, hasLength(1));
    expect(notes.single.id, autosavedId);
    expect(notes.single.body, 'Autosaved final version');
    expect(find.byType(NoteEditorPage), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'opening reminder while autosaving never starts native mood inference',
    (tester) async {
      final database = LocalDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final classifier = _UnexpectedEmotionClassifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(database),
            moodAnalyzerProvider.overrideWithValue(
              RecallMoodAnalyzer(classifier: classifier),
            ),
            notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
            reminderSchedulerProvider.overrideWithValue(
              _NoopReminderScheduler(),
            ),
            syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
            storedSessionProvider.overrideWith((ref) async => null),
            backgroundStartupEnabledProvider.overrideWithValue(false),
          ],
          child: const RecallApp(),
        ),
      );

      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('note-body-field')),
        'Keep this note and remind me tomorrow',
      );
      await tester.tap(find.byTooltip('Add reminder'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('Add reminder'), findsOneWidget);
      expect(classifier.calls, 0);
      final notes = await database.select(database.notes).get();
      expect(notes, hasLength(1));
      expect(notes.single.body, 'Keep this note and remind me tomorrow');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('backgrounding flushes a new note before the debounce', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-body-field')),
      'Persisted as the app backgrounds',
    );
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    final notes = await database.select(database.notes).get();
    expect(notes, hasLength(1));
    expect(notes.single.body, 'Persisted as the app backgrounds');

    for (final state in const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('discard removes an autosaved new-note draft', (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-body-field')),
      'Draft to discard',
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(await database.select(database.notes).get(), hasLength(1));

    await tester.tap(find.byTooltip('Note actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(await database.select(database.notes).get(), isEmpty);
    expect(find.byType(NoteEditorPage), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('clearing an autosaved new note removes the persisted draft', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    final bodyField = find.byKey(const Key('note-body-field'));
    await tester.enterText(bodyField, 'Temporary draft');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(await database.select(database.notes).get(), hasLength(1));

    await tester.enterText(bodyField, '');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(await database.select(database.notes).get(), isEmpty);
    expect(find.byType(NoteEditorPage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('trashing closes the editor when reminder cleanup fails', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(
      database,
      moodAnalyzer: _ClearMoodAnalyzer(),
    );
    final noteId = await repository.createTextNote(
      title: 'Trash me',
      body: 'Close after moving this note.',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          notePreviewsProvider.overrideWith(
            (ref) => Stream.value([
              NotePreview(
                id: noteId,
                title: 'Trash me',
                body: 'Close after moving this note.',
                mood: ColorMood.clear,
                reminderLabel: '',
              ),
            ]),
          ),
          reminderSchedulerProvider.overrideWithValue(
            _FailingCancellationReminderScheduler(),
          ),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Trash me'));
    await tester.pumpAndSettle();
    expect(find.text('Edit note'), findsOneWidget);

    await tester.tap(find.byTooltip('Note actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move to trash'));
    await tester.pumpAndSettle();

    expect(find.text('Edit note'), findsNothing);
    expect(
      find.text(
        'Note moved to trash, but its reminder could not be cancelled.',
      ),
      findsOneWidget,
    );
    final note = await (database.select(
      database.notes,
    )..where((entry) => entry.id.equals(noteId))).getSingle();
    expect(note.trashedAt, isNotNull);
  });

  testWidgets('notification tap opens the linked note', (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = NotesRepository(
      database,
      moodAnalyzer: _ClearMoodAnalyzer(),
    );
    final noteId = await repository.createTextNote(
      title: 'Open from reminder',
      body: 'The notification links here.',
    );
    final scheduler = _NoopReminderScheduler();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          notePreviewsProvider.overrideWith(
            (ref) => Stream.value(const [
              NotePreview(
                id: 'notification-note',
                title: 'Open from reminder',
                body: 'The notification links here.',
                mood: ColorMood.clear,
                reminderLabel: '',
              ),
            ]),
          ),
          reminderSchedulerProvider.overrideWithValue(scheduler),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pump();

    scheduler.openNote(noteId);
    await tester.pumpAndSettle();

    expect(find.byType(NoteEditorPage), findsOneWidget);
    final titleField = tester.widget<TextField>(
      find.byKey(const Key('note-title-field')),
    );
    expect(titleField.controller?.text, 'Open from reminder');
  });

  testWidgets('manual update check closes settings before showing status', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          updateServiceProvider.overrideWithValue(_NoUpdateService()),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();

    expect(find.text('Check for updates'), findsNothing);
    expect(find.text('Recall is up to date.'), findsOneWidget);
  });

  testWidgets('startup automatically offers an available update', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    final updateService = _AvailableUpdateService();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          updateServiceProvider.overrideWithValue(updateService),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundSyncControllerProvider.overrideWithValue(
            BackgroundSyncController(
              settingsStore: BackgroundSyncSettingsStore(
                storage: _MemoryBackgroundSyncStorage(),
              ),
              scheduler: _NoopBackgroundWorkScheduler(),
            ),
          ),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.textContaining('Recall 0.1.8 is available'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget);
    expect(updateService.cleanupCalled, isTrue);
  });

  testWidgets('update download can be cancelled without opening installer', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    final updateService = _CancellableUpdateService();
    final installer = _RecordingApkInstaller();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          updateServiceProvider.overrideWithValue(updateService),
          apkInstallerProvider.overrideWithValue(installer),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundSyncControllerProvider.overrideWithValue(
            BackgroundSyncController(
              settingsStore: BackgroundSyncSettingsStore(
                storage: _MemoryBackgroundSyncStorage(),
              ),
              scheduler: _NoopBackgroundWorkScheduler(),
            ),
          ),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install'));
    await tester.pump();

    expect(find.text('Downloading update'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Update download cancelled.'), findsOneWidget);
    expect(installer.installAttempts, 0);
  });

  testWidgets('returning from install settings retries the downloaded APK', (
    tester,
  ) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    final updateService = _ReadyUpdateService();
    final installer = _PermissionRetryApkInstaller();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          notePreviewsProvider.overrideWith((ref) => Stream.value(const [])),
          reminderSchedulerProvider.overrideWithValue(_NoopReminderScheduler()),
          syncServiceProvider.overrideWithValue(_NoopSyncService(database)),
          updateServiceProvider.overrideWithValue(updateService),
          apkInstallerProvider.overrideWithValue(installer),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundSyncControllerProvider.overrideWithValue(
            BackgroundSyncController(
              settingsStore: BackgroundSyncSettingsStore(
                storage: _MemoryBackgroundSyncStorage(),
              ),
              scheduler: _NoopBackgroundWorkScheduler(),
            ),
          ),
        ],
        child: const RecallApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();

    expect(find.text('Permission needed'), findsOneWidget);
    expect(installer.installAttempts, 1);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(installer.settingsOpenAttempts, 1);

    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    expect(installer.installAttempts, 2);
  });

  testWidgets('settings opens encrypted backup account setup', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          storedSessionProvider.overrideWith((ref) async => null),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect encrypted backup'));
    await tester.pumpAndSettle();

    expect(find.text('Connect your backup'), findsOneWidget);
    expect(find.text('Backup URL'), findsOneWidget);
    expect(find.text('Use a recovery key'), findsOneWidget);
  });

  testWidgets('settings exposes configurable background sync', (tester) async {
    final database = LocalDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final session = StoredSession(
      account: const StoredAccount(
        serverUrl: 'https://example.com',
        userId: 'user-id',
        email: 'user@example.com',
        deviceId: 'device-id',
      ),
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      masterKey: SecretKeyData(List<int>.filled(32, 1)),
    );
    final backgroundSync = BackgroundSyncController(
      settingsStore: BackgroundSyncSettingsStore(
        storage: _MemoryBackgroundSyncStorage(),
      ),
      scheduler: _NoopBackgroundWorkScheduler(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(database),
          moodAnalyzerProvider.overrideWithValue(_ClearMoodAnalyzer()),
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          storedSessionProvider.overrideWith((ref) async => session),
          syncServiceProvider.overrideWithValue(
            _NoopSyncService(database, pendingCount: 2),
          ),
          backgroundSyncControllerProvider.overrideWithValue(backgroundSync),
          backgroundStartupEnabledProvider.overrideWithValue(false),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Background sync'), findsOneWidget);
    expect(find.text('Sync frequency'), findsOneWidget);
    expect(find.text('Every hour'), findsWidgets);
    expect(find.text('Last successful sync'), findsOneWidget);
    expect(find.text('Last attempt'), findsOneWidget);
    expect(find.text('2 waiting to sync'), findsOneWidget);
  });
}

double _largestCardTranslation(WidgetTester tester, Iterable<String> noteIds) {
  return noteIds
      .map((id) {
        final translation = tester
            .widget<Transform>(find.byKey(ValueKey('note-position-$id')))
            .transform
            .getTranslation();
        return translation.x.abs() + translation.y.abs();
      })
      .reduce((largest, value) => value > largest ? value : largest);
}

class _NoUpdateService extends UpdateService {
  @override
  Future<UpdateCheckResult> checkForUpdate({
    String currentVersion = appVersion,
  }) async {
    return UpdateCheckResult(
      currentVersion: const SemanticVersion(1, 0, 0),
      latestVersion: const SemanticVersion(1, 0, 0),
      apkName: 'recall-android-1.0.0.apk',
      apkDownloadUrl: Uri.parse('https://example.com/recall.apk'),
      releaseUrl: Uri.parse('https://example.com/releases/1.0.0'),
      updateAvailable: false,
    );
  }
}

class _AvailableUpdateService extends UpdateService {
  bool cleanupCalled = false;

  @override
  Future<void> cleanupStaleDownloads() async {
    cleanupCalled = true;
  }

  @override
  Future<UpdateCheckResult> checkForUpdate({
    String currentVersion = appVersion,
  }) async {
    return UpdateCheckResult(
      currentVersion: const SemanticVersion(0, 1, 7),
      latestVersion: const SemanticVersion(0, 1, 8),
      apkName: 'recall-android-0.1.8.apk',
      apkDownloadUrl: Uri.parse(
        'https://github.com/spamalot22/recall/releases/download/0.1.8/recall-android-0.1.8.apk',
      ),
      releaseUrl: Uri.parse(
        'https://github.com/spamalot22/recall/releases/tag/0.1.8',
      ),
      downloadSizeBytes: 63634094,
      updateAvailable: true,
    );
  }
}

class _ReadyUpdateService extends _AvailableUpdateService {
  @override
  Future<File> downloadApk(
    UpdateCheckResult update, {
    void Function(int received, int? total)? onProgress,
    UpdateCancellationToken? cancellationToken,
  }) async {
    onProgress?.call(1, 1);
    return File('/tmp/recall-test-update.apk');
  }
}

class _CancellableUpdateService extends _AvailableUpdateService {
  @override
  Future<File> downloadApk(
    UpdateCheckResult update, {
    void Function(int received, int? total)? onProgress,
    UpdateCancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken;
    if (token == null) {
      throw StateError('A cancellation token is required.');
    }
    await token.whenCancelled;
    throw const UpdateCancelledException();
  }
}

class _RecordingApkInstaller extends ApkInstaller {
  int installAttempts = 0;

  @override
  Future<void> installApk(String path) async {
    installAttempts += 1;
  }
}

class _PermissionRetryApkInstaller extends _RecordingApkInstaller {
  int settingsOpenAttempts = 0;

  @override
  Future<void> installApk(String path) async {
    installAttempts += 1;
    if (installAttempts == 1) {
      throw const InstallPermissionRequiredException();
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    settingsOpenAttempts += 1;
  }
}

class _ClearMoodAnalyzer implements MoodAnalyzer {
  @override
  Future<MoodAnalysis> analyze({
    required String title,
    required String body,
    Iterable<String> checklistItems = const [],
    NoteReminder? reminder,
    DateTime? now,
  }) async {
    return const MoodAnalysis(
      mood: ColorMood.clear,
      confidence: 1,
      modelVersion: currentMoodModelVersion,
    );
  }
}

class _UnexpectedEmotionClassifier implements ContextualEmotionClassifier {
  int calls = 0;

  @override
  Future<List<List<double>>> classify(List<String> texts) async {
    calls++;
    throw StateError('Native mood inference must remain disabled.');
  }
}

class _NoopReminderScheduler extends ReminderScheduler {
  final _openRequests = StreamController<String>.broadcast();

  @override
  Stream<String> get openNoteRequests => _openRequests.stream;

  void openNote(String noteId) => _openRequests.add(noteId);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelNoteReminder(String noteId) async {}

  @override
  Future<void> reconcileNoteReminders(
    List<ScheduledNoteReminder> schedules, {
    bool requestPermissions = true,
  }) async {}

  @override
  Future<void> scheduleNoteReminder({
    required String noteId,
    required String title,
    required String body,
    required NoteReminder reminder,
    bool requestPermissions = true,
  }) async {}

  @override
  void dispose() {
    _openRequests.close();
    super.dispose();
  }
}

class _FailingCancellationReminderScheduler extends _NoopReminderScheduler {
  @override
  Future<void> cancelNoteReminder(String noteId) async {
    throw StateError('Notification service unavailable');
  }
}

class _NoopSyncService extends SyncService {
  _NoopSyncService(LocalDatabase database, {this.pendingCount = 0})
    : super(database, SecureAccountStore());

  final int pendingCount;

  @override
  Future<SyncResult> sync() async => const SyncResult(connected: false);

  @override
  Future<int> pendingChangeCount() async => pendingCount;

  @override
  Future<void> queueDeletion(String noteId) async {}
}

class _MemoryBackgroundSyncStorage implements BackgroundSyncStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _NoopBackgroundWorkScheduler implements BackgroundWorkScheduler {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> cancelOneOff() async {}

  @override
  Future<void> enqueueOneOff() async {}

  @override
  Future<void> schedulePeriodic(Duration interval) async {}
}
