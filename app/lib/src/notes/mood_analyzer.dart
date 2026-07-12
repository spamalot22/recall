import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'note_models.dart';

const currentMoodModelVersion = 1;
const _modelAsset = 'assets/models/recall_goemotions_v1.bin';
const _featureBuckets = 32768;
const _maxAnalysisCharacters = 8192;
const _maxAnalysisTokens = 256;

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

class RecallMoodAnalyzer implements MoodAnalyzer {
  Future<_EmotionModel>? _model;

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

    if (title.trim().isEmpty && body.trim().isEmpty) {
      return const MoodAnalysis(
        mood: ColorMood.clear,
        confidence: 1,
        modelVersion: currentMoodModelVersion,
      );
    }

    try {
      final model = await (_model ??= _EmotionModel.load());
      return model.analyze(title: title, body: body);
    } on Object {
      return const MoodAnalysis(
        mood: ColorMood.clear,
        confidence: 0,
        modelVersion: 0,
      );
    }
  }
}

class _EmotionModel {
  _EmotionModel(this._labels);

  final List<_LabelModel> _labels;

  static Future<_EmotionModel> load() async {
    final data = await rootBundle.load(_modelAsset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (bytes.length < 12 ||
        String.fromCharCodes(bytes.take(4)) != 'RCLM' ||
        data.getUint16(4, Endian.little) != currentMoodModelVersion ||
        data.getUint16(6, Endian.little) != _Emotion.values.length ||
        data.getUint32(8, Endian.little) != _featureBuckets) {
      throw const FormatException('Recall mood model is invalid.');
    }

    var offset = 12;
    final labels = <_LabelModel>[];
    for (var index = 0; index < _Emotion.values.length; index++) {
      final bias = data.getFloat32(offset, Endian.little);
      final scale = data.getFloat32(offset + 4, Endian.little);
      if (!bias.isFinite || !scale.isFinite || scale <= 0 || scale > 100) {
        throw const FormatException('Recall mood model has invalid weights.');
      }
      offset += 8;
      final end = offset + _featureBuckets;
      if (end > bytes.length) {
        throw const FormatException('Recall mood model is truncated.');
      }
      labels.add(
        _LabelModel(
          bias: bias,
          scale: scale,
          weights: Int8List.sublistView(bytes, offset, end),
        ),
      );
      offset = end;
    }
    if (offset != bytes.length) {
      throw const FormatException('Recall mood model has trailing data.');
    }
    return _EmotionModel(labels);
  }

  MoodAnalysis analyze({required String title, required String body}) {
    final titleScores = title.trim().isEmpty ? null : _scores(title);
    final bodyScores = body.trim().isEmpty ? null : _scores(body);
    final scores = List<double>.generate(_labels.length, (index) {
      if (titleScores == null) return bodyScores![index];
      if (bodyScores == null) return titleScores[index];
      return titleScores[index] * 0.2 + bodyScores[index] * 0.8;
    });

    final grouped = <ColorMood, double>{};
    for (var index = 0; index < scores.length; index++) {
      final mood = _emotionMoods[_Emotion.values[index]]!;
      grouped[mood] = math.max(
        grouped[mood] ?? double.negativeInfinity,
        scores[index],
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

  List<double> _scores(String text) {
    final features = _features(text);
    final featureScale = 1 / math.sqrt(math.max(1, features.length));
    return _labels
        .map((label) {
          var score = label.bias;
          for (final feature in features) {
            score += label.weights[feature] * label.scale * featureScale;
          }
          return score;
        })
        .toList(growable: false);
  }
}

class _LabelModel {
  const _LabelModel({
    required this.bias,
    required this.scale,
    required this.weights,
  });

  final double bias;
  final double scale;
  final Int8List weights;
}

Set<int> _features(String text) {
  final boundedText = text.length <= _maxAnalysisCharacters
      ? text
      : text.substring(0, _maxAnalysisCharacters);
  final words = RegExp(r"[a-z]+(?:'[a-z]+)?|[0-9]+")
      .allMatches(boundedText.toLowerCase())
      .map((match) => match.group(0)!)
      .take(_maxAnalysisTokens)
      .toList(growable: false);
  final features = <int>{
    for (final word in words) _fnv1a('u:$word') % _featureBuckets,
  };
  for (var index = 1; index < words.length; index++) {
    features.add(
      _fnv1a('b:${words[index - 1]}_${words[index]}') % _featureBuckets,
    );
  }
  return features;
}

int _fnv1a(String value) {
  var hash = 0x811C9DC5;
  for (final byte in Uint8List.fromList(value.codeUnits)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
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
