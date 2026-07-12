import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/notes/mood_analyzer.dart';
import 'package:recall_app/src/notes/note_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecallMoodAnalyzer analyzer;

  setUp(() {
    analyzer = RecallMoodAnalyzer();
  });

  Future<void> expectMood(String body, ColorMood mood) async {
    final result = await analyzer.analyze(title: '', body: body);
    expect(result.mood, mood, reason: body);
    expect(result.confidence, inInclusiveRange(0, 1));
    expect(result.modelVersion, currentMoodModelVersion);
  }

  test('learns ordinary emotional words without hand-authored rules', () async {
    await expectMood('This is good', ColorMood.warm);
    await expectMood('This is bad', ColorMood.intense);
    await expectMood('I feel happy today', ColorMood.joyful);
    await expectMood('I feel sad today', ColorMood.reflective);
    await expectMood('I love my family', ColorMood.warm);
    await expectMood('I am nervous about tomorrow', ColorMood.tense);
    await expectMood('What a surprise', ColorMood.surprised);
  });

  test('body has more influence than title', () async {
    final result = await analyzer.analyze(
      title: 'This is good',
      body: 'I feel sad and disappointed today',
    );
    expect(result.mood, ColorMood.reflective);
  });

  test('functional rules take precedence over emotional tone', () async {
    final result = await analyzer.analyze(
      title: 'Urgent',
      body: 'Buy the wonderful birthday present immediately',
    );
    expect(result.mood, ColorMood.urgent);
    expect(result.confidence, 1);
  });

  test('empty and uncertain notes remain neutral', () async {
    await expectMood('', ColorMood.clear);
    await expectMood('the of and', ColorMood.clear);
  });
}
