import 'package:cardo/features/boards/domain/board_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoardLimits.validateTitle', () {
    test('rejects empty and blank titles', () {
      expect(BoardLimits.validateTitle(''), BoardTitleIssue.empty);
      expect(BoardLimits.validateTitle('   '), BoardTitleIssue.empty);
    });

    test('200 runes pass and 201 are too long', () {
      expect(BoardLimits.validateTitle('a' * 200), isNull);
      expect(BoardLimits.validateTitle('a' * 201), BoardTitleIssue.tooLong);
    });

    test('counts runes rather than UTF-16 units', () {
      expect(BoardLimits.validateTitle('😀' * 200), isNull);
      expect(BoardLimits.validateTitle('😀' * 201), BoardTitleIssue.tooLong);
    });
  });
}
