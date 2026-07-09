import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/main.dart';
import 'package:recall_app/src/notes/note_models.dart';
import 'package:recall_app/src/providers.dart';

void main() {
  testWidgets('Recall home screen renders note cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
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

  testWidgets('FAB opens the note editor with reminder controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
        ],
        child: const RecallApp(),
      ),
    );

    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget);
    expect(find.text('Add reminder'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
