import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/notes/mood_analyzer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.recall.notes/mood_model');

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('sends bounded token batches and parses native logits', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'classify');
          expect(call.arguments, {
            'inputIds': [
              [0, 10999, 2],
              [0, 102, 1099, 631, 1102, 452, 2],
            ],
          });
          return [
            List<double>.generate(28, (index) => index.toDouble()),
            List<double>.generate(28, (index) => -index.toDouble()),
          ];
        });

    final classifier = AndroidOnnxEmotionClassifier(channel: channel);
    final output = await classifier.classify([
      'bad',
      'a bad thing happened today',
    ]);

    expect(output, hasLength(2));
    expect(output.first, hasLength(28));
    expect(output.first.last, 27);
    expect(output.last.last, -27);
  });
}
