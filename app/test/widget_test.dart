import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/main.dart';
import 'package:recall_app/src/notes/note_models.dart';
import 'package:recall_app/src/providers.dart';
import 'package:recall_app/src/updates/update_service.dart';

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

  testWidgets('manual update check closes settings before showing status', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notePreviewsProvider.overrideWith((ref) => Stream.value(sampleNotes)),
          updateServiceProvider.overrideWithValue(_NoUpdateService()),
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
