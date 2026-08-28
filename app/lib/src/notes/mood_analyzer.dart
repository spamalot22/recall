import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'note_models.dart';
import 'roberta_tokenizer.dart';

const currentMoodModelVersion = 4;
const _emotionLabelCount = 28;
const _fallbackModelAsset = 'assets/models/recall_goemotions_v1.bin';
const _fallbackModelFormatVersion = 1;
const _fallbackFeatureBuckets = 32768;
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

abstract interface class ContextualEmotionClassifier {
  Future<List<List<double>>> classify(List<String> texts);
}

class RecallMoodAnalyzer implements MoodAnalyzer {
  RecallMoodAnalyzer({
    ContextualEmotionClassifier? classifier,
    this.contextualAnalysisEnabled = const bool.fromEnvironment(
      'ENABLE_CONTEXTUAL_MOODS',
    ),
  }) : _classifier = classifier ?? AndroidOnnxEmotionClassifier();

  final ContextualEmotionClassifier _classifier;
  final bool contextualAnalysisEnabled;
  Future<_FallbackEmotionModel>? _fallbackModel;

  @override
  Future<MoodAnalysis> analyze({
    required String title,
    required String body,
    Iterable<String> checklistItems = const [],
    NoteReminder? reminder,
    DateTime? now,
  }) async {
    final cleanChecklistItems = checklistItems
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final functionalMood = automaticMoodForNote(
      title: title,
      body: body,
      checklistItems: cleanChecklistItems,
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
    final cleanBody = [
      if (body.trim().isNotEmpty) body.trim(),
      ...cleanChecklistItems,
    ].join('\n');
    if (cleanTitle.isEmpty && cleanBody.isEmpty) {
      return const MoodAnalysis(
        mood: ColorMood.clear,
        confidence: 1,
        modelVersion: currentMoodModelVersion,
      );
    }

    // Keep the native model behind an explicit build flag until its Android
    // runtime has been validated across supported physical devices.
    if (contextualAnalysisEnabled) {
      try {
        final texts = <String>[
          if (cleanTitle.isNotEmpty) cleanTitle,
          if (cleanBody.isNotEmpty) cleanBody,
        ];
        final scores = await _classifier.classify(texts);
        final contextual = _analyzeScores(
          scores,
          hasTitle: cleanTitle.isNotEmpty,
          hasBody: cleanBody.isNotEmpty,
        );
        if (contextual.mood != ColorMood.clear) {
          return contextual;
        }
      } on Object {
        // Fall through to the platform-independent bundled model.
      }
    }

    try {
      final model = await (_fallbackModel ??= _FallbackEmotionModel.load());
      return model.analyze(title: cleanTitle, body: cleanBody);
    } on Object {
      final source = '$cleanTitle\n$cleanBody';
      return MoodAnalysis(
        mood: _stableFallbackMood(source),
        confidence: 0,
        modelVersion: currentMoodModelVersion,
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

class _FallbackEmotionModel {
  _FallbackEmotionModel(this._labels);

  final List<_FallbackLabelModel> _labels;

  static Future<_FallbackEmotionModel> load() async {
    final data = await rootBundle.load(_fallbackModelAsset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (bytes.length < 12 ||
        String.fromCharCodes(bytes.take(4)) != 'RCLM' ||
        data.getUint16(4, Endian.little) != _fallbackModelFormatVersion ||
        data.getUint16(6, Endian.little) != _Emotion.values.length ||
        data.getUint32(8, Endian.little) != _fallbackFeatureBuckets) {
      throw const FormatException('Recall fallback mood model is invalid.');
    }

    var offset = 12;
    final labels = <_FallbackLabelModel>[];
    for (var index = 0; index < _Emotion.values.length; index++) {
      final bias = data.getFloat32(offset, Endian.little);
      final scale = data.getFloat32(offset + 4, Endian.little);
      if (!bias.isFinite || !scale.isFinite || scale <= 0 || scale > 100) {
        throw const FormatException(
          'Recall fallback mood model has invalid weights.',
        );
      }
      offset += 8;
      final end = offset + _fallbackFeatureBuckets;
      if (end > bytes.length) {
        throw const FormatException('Recall fallback mood model is truncated.');
      }
      labels.add(
        _FallbackLabelModel(
          bias: bias,
          scale: scale,
          weights: Int8List.sublistView(bytes, offset, end),
        ),
      );
      offset = end;
    }
    if (offset != bytes.length) {
      throw const FormatException(
        'Recall fallback mood model has trailing data.',
      );
    }
    return _FallbackEmotionModel(labels);
  }

  MoodAnalysis analyze({required String title, required String body}) {
    final titleScores = title.isEmpty ? null : _scores(title);
    final bodyScores = body.isEmpty ? null : _scores(body);
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
    final strongest = ranked.first;
    final strongestNonNeutral = ranked.firstWhere(
      (candidate) => candidate.key != ColorMood.clear,
    );
    final confidence = _sigmoid(strongestNonNeutral.value);
    final margin =
        strongestNonNeutral.value -
        ranked
            .firstWhere((candidate) => candidate.key != strongestNonNeutral.key)
            .value;
    final confidentlyEmotional =
        strongest.key == strongestNonNeutral.key &&
        confidence >= 0.64 &&
        margin >= 0.35;

    return MoodAnalysis(
      mood: confidentlyEmotional
          ? strongestNonNeutral.key
          : _subduedMoodFor(strongestNonNeutral.key),
      confidence: confidence,
      modelVersion: currentMoodModelVersion,
    );
  }

  List<double> _scores(String text) {
    final features = _fallbackFeatures(text);
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

class _FallbackLabelModel {
  const _FallbackLabelModel({
    required this.bias,
    required this.scale,
    required this.weights,
  });

  final double bias;
  final double scale;
  final Int8List weights;
}

Set<int> _fallbackFeatures(String text) {
  final boundedText = text.length <= _maxAnalysisCharacters
      ? text
      : text.substring(0, _maxAnalysisCharacters);
  final words = RegExp(r"[a-z]+(?:'[a-z]+)?|[0-9]+")
      .allMatches(boundedText.toLowerCase())
      .map((match) => match.group(0)!)
      .take(_maxAnalysisTokens)
      .toList(growable: false);
  final features = <int>{
    for (final word in words)
      _fnv1a(utf8.encode('u:$word')) % _fallbackFeatureBuckets,
  };
  for (var index = 1; index < words.length; index++) {
    features.add(
      _fnv1a(utf8.encode('b:${words[index - 1]}_${words[index]}')) %
          _fallbackFeatureBuckets,
    );
  }
  return features;
}

ColorMood _stableFallbackMood(String text) {
  const moods = [
    ColorMood.calm,
    ColorMood.reflective,
    ColorMood.routine,
    ColorMood.focus,
  ];
  return moods[_fnv1a(utf8.encode(text)) % moods.length];
}

ColorMood _subduedMoodFor(ColorMood mood) {
  return switch (mood) {
    ColorMood.intense ||
    ColorMood.tense ||
    ColorMood.reflective => ColorMood.reflective,
    ColorMood.joyful || ColorMood.warm || ColorMood.calm => ColorMood.calm,
    ColorMood.surprised => ColorMood.focus,
    ColorMood.clear => ColorMood.routine,
    _ => mood,
  };
}

int _fnv1a(List<int> bytes) {
  var hash = 0x811C9DC5;
  for (final byte in bytes) {
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
