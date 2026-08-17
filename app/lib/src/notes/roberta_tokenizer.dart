import 'dart:convert';

import 'package:flutter/services.dart';

const _tokenizerAsset = 'assets/models/recall_roberta_tokenizer_v2.json';
const _maximumSequenceLength = 64;

class RobertaTokenizer {
  RobertaTokenizer._({required this.vocabulary, required this.mergeRanks});

  final Map<String, int> vocabulary;
  final Map<String, int> mergeRanks;
  final Map<String, List<String>> _tokenCache = {};

  static Future<RobertaTokenizer> load() async {
    final source = await rootBundle.loadString(_tokenizerAsset);
    return fromJson(source);
  }

  static RobertaTokenizer fromJson(String source) {
    final document = jsonDecode(source) as Map<String, dynamic>;
    final model = document['model'] as Map<String, dynamic>?;
    if (model == null || model['type'] != 'BPE') {
      throw const FormatException('Recall tokenizer is not a BPE tokenizer.');
    }

    final rawVocabulary = model['vocab'] as Map<String, dynamic>?;
    final rawMerges = model['merges'] as List<dynamic>?;
    if (rawVocabulary == null || rawMerges == null) {
      throw const FormatException('Recall tokenizer data is incomplete.');
    }

    final vocabulary = rawVocabulary.map(
      (token, id) => MapEntry(token, (id as num).toInt()),
    );
    final mergeRanks = <String, int>{};
    for (var index = 0; index < rawMerges.length; index++) {
      final merge = rawMerges[index] as String;
      if (_splitMerge(merge) == null) {
        throw const FormatException('Recall tokenizer has an invalid merge.');
      }
      mergeRanks[merge] = index;
    }
    if (vocabulary['<s>'] != 0 ||
        vocabulary['<pad>'] != 1 ||
        vocabulary['</s>'] != 2) {
      throw const FormatException(
        'Recall tokenizer special tokens are invalid.',
      );
    }
    return RobertaTokenizer._(
      vocabulary: Map.unmodifiable(vocabulary),
      mergeRanks: Map.unmodifiable(mergeRanks),
    );
  }

  List<int> encode(String text) {
    final ids = <int>[0];
    for (final match in _preTokenPattern.allMatches(text)) {
      final encoded = utf8
          .encode(match.group(0)!)
          .map((byte) => _byteEncoder[byte]!)
          .join();
      for (final token in _bytePairEncode(encoded)) {
        final id = vocabulary[token];
        if (id == null) {
          throw const FormatException(
            'Recall tokenizer produced an unknown token.',
          );
        }
        ids.add(id);
        if (ids.length == _maximumSequenceLength - 1) {
          ids.add(2);
          return ids;
        }
      }
    }
    ids.add(2);
    return ids;
  }

  List<String> _bytePairEncode(String token) {
    final cached = _tokenCache[token];
    if (cached != null) {
      return cached;
    }

    var parts = token.runes.map(String.fromCharCode).toList(growable: false);
    while (parts.length > 1) {
      var bestRank = 1 << 62;
      String? bestLeft;
      String? bestRight;
      for (var index = 0; index < parts.length - 1; index++) {
        final left = parts[index];
        final right = parts[index + 1];
        final rank = mergeRanks['$left $right'];
        if (rank != null && rank < bestRank) {
          bestRank = rank;
          bestLeft = left;
          bestRight = right;
        }
      }
      if (bestLeft == null || bestRight == null) {
        break;
      }

      final merged = <String>[];
      var index = 0;
      while (index < parts.length) {
        if (index < parts.length - 1 &&
            parts[index] == bestLeft &&
            parts[index + 1] == bestRight) {
          merged.add(bestLeft + bestRight);
          index += 2;
        } else {
          merged.add(parts[index]);
          index++;
        }
      }
      parts = merged;
    }

    final result = List<String>.unmodifiable(parts);
    if (_tokenCache.length < 4096) {
      _tokenCache[token] = result;
    }
    return result;
  }
}

List<String>? _splitMerge(String merge) {
  final separator = merge.indexOf(' ');
  if (separator <= 0 || separator == merge.length - 1) {
    return null;
  }
  return [merge.substring(0, separator), merge.substring(separator + 1)];
}

final _preTokenPattern = RegExp(
  r"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+",
  unicode: true,
);

final Map<int, String> _byteEncoder = _buildByteEncoder();

Map<int, String> _buildByteEncoder() {
  final bytes = <int>[
    for (var value = 33; value <= 126; value++) value,
    for (var value = 161; value <= 172; value++) value,
    for (var value = 174; value <= 255; value++) value,
  ];
  final codePoints = [...bytes];
  var extra = 0;
  for (var byte = 0; byte < 256; byte++) {
    if (!bytes.contains(byte)) {
      bytes.add(byte);
      codePoints.add(256 + extra);
      extra++;
    }
  }
  return Map.unmodifiable({
    for (var index = 0; index < bytes.length; index++)
      bytes[index]: String.fromCharCode(codePoints[index]),
  });
}
