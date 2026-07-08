import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/updates/update_service.dart';

void main() {
  group('SemanticVersion', () {
    test('parses bare semantic versions', () {
      expect(SemanticVersion.tryParse('0.1.1').toString(), '0.1.1');
      expect(SemanticVersion.tryParse('10.20.30').toString(), '10.20.30');
    });

    test('rejects non-release versions', () {
      expect(SemanticVersion.tryParse('dev'), isNull);
      expect(SemanticVersion.tryParse('v1.2.3'), isNull);
      expect(SemanticVersion.tryParse('1.2.3-beta.1'), isNull);
      expect(SemanticVersion.tryParse('01.2.3'), isNull);
    });

    test('compares version components numerically', () {
      expect(
        SemanticVersion.tryParse(
          '0.1.2',
        )!.compareTo(SemanticVersion.tryParse('0.1.1')!),
        isPositive,
      );
      expect(
        SemanticVersion.tryParse(
          '0.10.0',
        )!.compareTo(SemanticVersion.tryParse('0.9.9')!),
        isPositive,
      );
      expect(
        SemanticVersion.tryParse(
          '2.0.0',
        )!.compareTo(SemanticVersion.tryParse('10.0.0')!),
        isNegative,
      );
    });
  });
}
