import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/notes/mood_analyzer.dart';
import 'package:recall_app/src/notes/note_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecallMoodAnalyzer analyzer;

  setUp(() {
    analyzer = RecallMoodAnalyzer(
      classifier: _FixtureEmotionClassifier(),
      contextualAnalysisEnabled: true,
    );
  });

  Future<void> expectMood(String body, ColorMood mood) async {
    final result = await analyzer.analyze(title: '', body: body);
    expect(result.mood, mood, reason: body);
    expect(result.confidence, inInclusiveRange(0, 1));
    expect(result.modelVersion, currentMoodModelVersion);
  }

  test('maps contextual emotion scores to colour moods', () async {
    await expectMood('This is good', ColorMood.warm);
    await expectMood('This is bad', ColorMood.intense);
    await expectMood('I feel happy today', ColorMood.joyful);
    await expectMood('I feel sad today', ColorMood.reflective);
    await expectMood('I love my family', ColorMood.warm);
    await expectMood('I am nervous about tomorrow', ColorMood.tense);
    await expectMood('What a surprise', ColorMood.surprised);
  });

  test(
    'recognizes emotion in a sentence instead of defaulting to clear',
    () async {
      await expectMood('a bad thing happened today', ColorMood.reflective);
    },
  );

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

  test(
    'empty notes remain neutral and non-empty notes always get a mood',
    () async {
      await expectMood('', ColorMood.clear);
      expect(
        (await analyzer.analyze(title: '', body: 'bad')).mood,
        ColorMood.reflective,
      );
      expect(
        (await analyzer.analyze(title: '', body: 'the of and')).mood,
        isNot(ColorMood.clear),
      );
    },
  );

  test(
    'uses bundled fallback when on-device inference is unavailable',
    () async {
      final unavailable = RecallMoodAnalyzer(
        classifier: _UnavailableEmotionClassifier(),
        contextualAnalysisEnabled: true,
      );
      final result = await unavailable.analyze(title: '', body: 'I feel sad');
      expect(result.mood, ColorMood.reflective);
      expect(result.confidence, inInclusiveRange(0, 1));
      expect(result.modelVersion, currentMoodModelVersion);
    },
  );

  test('release default never enters the native contextual runtime', () async {
    final classifier = _RecordingEmotionClassifier();
    final releaseAnalyzer = RecallMoodAnalyzer(classifier: classifier);

    final result = await releaseAnalyzer.analyze(
      title: '',
      body: 'a bad thing happened today',
    );

    expect(classifier.calls, 0);
    expect(result.mood, isNot(ColorMood.clear));
    expect(result.confidence, inInclusiveRange(0, 1));
    expect(result.modelVersion, currentMoodModelVersion);
  });

  test('release fallback recognizes ordinary emotional language', () async {
    final releaseAnalyzer = RecallMoodAnalyzer();

    expect(
      (await releaseAnalyzer.analyze(title: '', body: 'This is good')).mood,
      ColorMood.warm,
    );
    expect(
      (await releaseAnalyzer.analyze(title: '', body: 'This is bad')).mood,
      ColorMood.intense,
    );
    expect(
      (await releaseAnalyzer.analyze(
        title: '',
        body: 'I feel happy today',
      )).mood,
      ColorMood.joyful,
    );
    expect(
      (await releaseAnalyzer.analyze(title: '', body: 'I feel sad today')).mood,
      ColorMood.reflective,
    );
  });

  test('fallback mood is stable for the same note text', () async {
    final releaseAnalyzer = RecallMoodAnalyzer();

    final first = await releaseAnalyzer.analyze(
      title: 'A thought',
      body: 'Something ambiguous happened',
    );
    final second = await releaseAnalyzer.analyze(
      title: 'A thought',
      body: 'Something ambiguous happened',
    );

    expect(first.mood, isNot(ColorMood.clear));
    expect(second.mood, first.mood);
  });

  test('checklist text participates in sentiment analysis', () async {
    final result = await analyzer.analyze(
      title: '',
      body: '',
      checklistItems: const ['I feel sad and disappointed today'],
    );

    expect(result.mood, ColorMood.reflective);
  });
}

class _FixtureEmotionClassifier implements ContextualEmotionClassifier {
  static const _labels = {
    'This is good': 0,
    'This is bad': 11,
    'I feel happy today': 17,
    'I feel sad today': 25,
    'I feel sad and disappointed today': 25,
    'I love my family': 18,
    'I am nervous about tomorrow': 19,
    'What a surprise': 26,
    'a bad thing happened today': 25,
    'bad': 27,
    'the of and': 27,
  };

  @override
  Future<List<List<double>>> classify(List<String> texts) async {
    return texts
        .map((text) {
          final scores = List<double>.filled(28, -6);
          scores[_labels[text] ?? 27] = 4;
          return scores;
        })
        .toList(growable: false);
  }
}

class _UnavailableEmotionClassifier implements ContextualEmotionClassifier {
  @override
  Future<List<List<double>>> classify(List<String> texts) {
    throw StateError('Native runtime is unavailable.');
  }
}

class _RecordingEmotionClassifier implements ContextualEmotionClassifier {
  int calls = 0;

  @override
  Future<List<List<double>>> classify(List<String> texts) async {
    calls++;
    throw StateError('The native classifier must remain gated off.');
  }
}
