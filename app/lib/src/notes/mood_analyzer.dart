import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'note_models.dart';
import 'roberta_tokenizer.dart';

const currentMoodModelVersion = 2;
const _emotionLabelCount = 28;

class MoodAnalysis {
  const MoodAnalysis({
    required this.mood,
    required this.confidence,
    required this.modelVersion,
  });

  final ColorMood mood;
  final double confidence;
  final int modelVersion;
}

abstract interface class MoodAnalyzer {
  Future<MoodAnalysis> analyze({
    required String title,
    required String body,
    Iterable<String> checklistItems,
    NoteReminder? reminder,
    DateTime? now,
  });
}

abstract interface class ContextualEmotionClassifier {
  Future<List<List<double>>> classify(List<String> texts);
}

class RecallMoodAnalyzer implements MoodAnalyzer {
  RecallMoodAnalyzer({ContextualEmotionClassifier? classifier})
    : _classifier = classifier ?? AndroidOnnxEmotionClassifier();

  final ContextualEmotionClassifier _classifier;

  @override
  Future<MoodAnalysis> analyze({
    required String title,
    required String body,
    Iterable<String> checklistItems = const [],
    NoteReminder? reminder,
    DateTime? now,
  }) async {
    final functionalMood = automaticMoodForNote(
      title: title,
      body: body,
      checklistItems: checklistItems,
      reminder: reminder,
      now: now,
    );
    if (functionalMood != ColorMood.clear) {
      return MoodAnalysis(
        mood: functionalMood,
        confidence: 1,
        modelVersion: currentMoodModelVersion,
      );
    }

    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.isEmpty && cleanBody.isEmpty) {
      return const MoodAnalysis(
        mood: ColorMood.clear,
        confidence: 1,
        modelVersion: currentMoodModelVersion,
      );
    }

    try {
      final texts = <String>[
        if (cleanTitle.isNotEmpty) cleanTitle,
        if (cleanBody.isNotEmpty) cleanBody,
      ];
      final scores = await _classifier.classify(texts);
      return _analyzeScores(
        scores,
        hasTitle: cleanTitle.isNotEmpty,
        hasBody: cleanBody.isNotEmpty,
      );
    } on Object {
      return const MoodAnalysis(
        mood: ColorMood.clear,
        confidence: 0,
        modelVersion: 0,
      );
    }
  }
}

class AndroidOnnxEmotionClassifier implements ContextualEmotionClassifier {
  AndroidOnnxEmotionClassifier({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'app.recall.notes/mood_model';

  final MethodChannel _channel;
  Future<RobertaTokenizer>? _tokenizer;

  @override
  Future<List<List<double>>> classify(List<String> texts) async {
    if (texts.isEmpty) {
      return const [];
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError(
        'The bundled mood model runtime is currently available on Android.',
      );
    }
    final tokenizer = await (_tokenizer ??= RobertaTokenizer.load());
    final inputIds = texts.map(tokenizer.encode).toList(growable: false);
    final rawOutput = await _channel.invokeMethod<List<Object?>>('classify', {
      'inputIds': inputIds,
    });
    if (rawOutput == null || rawOutput.length != texts.length) {
      throw const FormatException('Recall mood model returned invalid output.');
    }

    return rawOutput
        .map((row) {
          if (row is! List || row.length != _emotionLabelCount) {
            throw const FormatException(
              'Recall mood model returned invalid scores.',
            );
          }
          final values = row
              .map((value) {
                if (value is! num || !value.isFinite) {
                  throw const FormatException(
                    'Recall mood model returned a non-finite score.',
                  );
                }
                return value.toDouble();
              })
              .toList(growable: false);
          return values;
        })
        .toList(growable: false);
  }
}

MoodAnalysis _analyzeScores(
  List<List<double>> scores, {
  required bool hasTitle,
  required bool hasBody,
}) {
  final expectedRows = hasTitle && hasBody ? 2 : 1;
  if (scores.length != expectedRows ||
      scores.any((row) => row.length != _emotionLabelCount)) {
    throw const FormatException('Recall mood model score shape is invalid.');
  }

  final blended = List<double>.generate(_emotionLabelCount, (index) {
    if (!hasTitle || !hasBody) {
      return scores.single[index];
    }
    return scores[0][index] * 0.2 + scores[1][index] * 0.8;
  });

  final grouped = <ColorMood, double>{};
  for (var index = 0; index < blended.length; index++) {
    final mood = _emotionMoods[_Emotion.values[index]]!;
    grouped[mood] = math.max(
      grouped[mood] ?? double.negativeInfinity,
      blended[index],
    );
  }
  final ranked = grouped.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  final winner = ranked.first;
  final confidence = _sigmoid(winner.value);
  final margin = winner.value - ranked[1].value;
  final accepted =
      winner.key != ColorMood.clear && confidence >= 0.64 && margin >= 0.35;

  return MoodAnalysis(
    mood: accepted ? winner.key : ColorMood.clear,
    confidence: confidence,
    modelVersion: currentMoodModelVersion,
  );
}

double _sigmoid(double value) {
  if (value >= 0) return 1 / (1 + math.exp(-math.min(value, 30)));
  final exponent = math.exp(math.max(value, -30));
  return exponent / (1 + exponent);
}

enum _Emotion {
  admiration,
  amusement,
  anger,
  annoyance,
  approval,
  caring,
  confusion,
  curiosity,
  desire,
  disappointment,
  disapproval,
  disgust,
  embarrassment,
  excitement,
  fear,
  gratitude,
  grief,
  joy,
  love,
  nervousness,
  optimism,
  pride,
  realization,
  relief,
  remorse,
  sadness,
  surprise,
  neutral,
}

const _emotionMoods = {
  _Emotion.admiration: ColorMood.warm,
  _Emotion.amusement: ColorMood.joyful,
  _Emotion.anger: ColorMood.intense,
  _Emotion.annoyance: ColorMood.intense,
  _Emotion.approval: ColorMood.calm,
  _Emotion.caring: ColorMood.warm,
  _Emotion.confusion: ColorMood.tense,
  _Emotion.curiosity: ColorMood.surprised,
  _Emotion.desire: ColorMood.joyful,
  _Emotion.disappointment: ColorMood.reflective,
  _Emotion.disapproval: ColorMood.intense,
  _Emotion.disgust: ColorMood.intense,
  _Emotion.embarrassment: ColorMood.reflective,
  _Emotion.excitement: ColorMood.joyful,
  _Emotion.fear: ColorMood.tense,
  _Emotion.gratitude: ColorMood.warm,
  _Emotion.grief: ColorMood.reflective,
  _Emotion.joy: ColorMood.joyful,
  _Emotion.love: ColorMood.warm,
  _Emotion.nervousness: ColorMood.tense,
  _Emotion.optimism: ColorMood.joyful,
  _Emotion.pride: ColorMood.joyful,
  _Emotion.realization: ColorMood.surprised,
  _Emotion.relief: ColorMood.calm,
  _Emotion.remorse: ColorMood.reflective,
  _Emotion.sadness: ColorMood.reflective,
  _Emotion.surprise: ColorMood.surprised,
  _Emotion.neutral: ColorMood.clear,
};
