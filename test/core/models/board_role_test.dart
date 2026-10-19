import 'package:cardo/core/models/board_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoardRole.tryParse', () {
    test('parses wire names', () {
      expect(BoardRole.tryParse('owner'), BoardRole.owner);
      expect(BoardRole.tryParse('editor'), BoardRole.editor);
      expect(BoardRole.tryParse('viewer'), BoardRole.viewer);
    });

    test('returns null for unknown values', () {
      expect(BoardRole.tryParse(null), isNull);
      expect(BoardRole.tryParse(''), isNull);
      expect(BoardRole.tryParse('admin'), isNull);
      expect(BoardRole.tryParse('Owner'), isNull);
    });

    test('wire name round trips', () {
      for (final role in BoardRole.values) {
        expect(BoardRole.tryParse(role.wireName), role);
      }
    });
  });

  group('permissions', () {
    test('canEdit', () {
      expect(BoardRole.owner.canEdit, isTrue);
      expect(BoardRole.editor.canEdit, isTrue);
      expect(BoardRole.viewer.canEdit, isFalse);
    });

    test('canManageMembers', () {
      expect(BoardRole.owner.canManageMembers, isTrue);
      expect(BoardRole.editor.canManageMembers, isFalse);
      expect(BoardRole.viewer.canManageMembers, isFalse);
    });
  });
}
