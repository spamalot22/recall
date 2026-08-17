import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/notes/roberta_tokenizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RobertaTokenizer tokenizer;

  setUpAll(() async {
    tokenizer = await RobertaTokenizer.load();
  });

  test('matches the model tokenizer for ordinary note text', () {
    expect(tokenizer.encode('bad'), [0, 10999, 2]);
    expect(tokenizer.encode('a bad thing happened today'), [
      0,
      102,
      1099,
      631,
      1102,
      452,
      2,
    ]);
    expect(tokenizer.encode('This is good'), [0, 713, 16, 205, 2]);
    expect(tokenizer.encode('I feel sad today'), [0, 100, 619, 5074, 452, 2]);
  });

  test('matches byte-level tokenization for punctuation and unicode', () {
    expect(tokenizer.encode("I can't believe it!"), [
      0,
      100,
      64,
      75,
      679,
      24,
      328,
      2,
    ]);
    expect(tokenizer.encode('Café tomorrow 😀'), [
      0,
      347,
      2001,
      1140,
      3859,
      17841,
      7471,
      2,
    ]);
  });

  test('caps model input at 64 tokens', () {
    final encoded = tokenizer.encode(List.filled(100, 'remember').join(' '));
    expect(encoded, hasLength(64));
    expect(encoded.first, 0);
    expect(encoded.last, 2);
  });
}
