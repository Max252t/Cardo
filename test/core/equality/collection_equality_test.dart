import 'package:cardo/core/equality/collection_equality.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/card_draft.dart';
import 'package:cardo/features/board/domain/relative_age.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/board/helpers/board_fixtures.dart';

void main() {
  group('listEquals', () {
    test('null and identical inputs', () {
      expect(listEquals<int>(null, null), isTrue);
      expect(listEquals<int>(null, <int>[]), isFalse);
      expect(listEquals<int>(<int>[], null), isFalse);
      final list = <int>[1, 2];
      expect(listEquals(list, list), isTrue);
    });

    test('empty lists are equal', () {
      expect(listEquals(<int>[], <int>[]), isTrue);
    });

    test('compares length and elements in order', () {
      expect(listEquals(<int>[1, 2], <int>[1, 2]), isTrue);
      expect(listEquals(<int>[1, 2], <int>[1, 2, 3]), isFalse);
      expect(listEquals(<int>[1, 2], <int>[2, 1]), isFalse);
      expect(listEquals(<int>[1, 2], <int>[1, 3]), isFalse);
    });

    test('uses element equality, not identity', () {
      expect(listEquals(<String>['a' * 3], <String>['aaa']), isTrue);
      expect(
        listEquals(
          <List<int>>[
            <int>[1],
          ],
          <List<int>>[
            <int>[1],
          ],
        ),
        isFalse,
      );
    });

    test('null elements are comparable', () {
      expect(listEquals(<int?>[null, 1], <int?>[null, 1]), isTrue);
      expect(listEquals(<int?>[null], <int?>[1]), isFalse);
    });
  });

  group('mapEquals', () {
    test('null and identical inputs', () {
      expect(mapEquals<String, int>(null, null), isTrue);
      expect(mapEquals<String, int>(null, <String, int>{}), isFalse);
      expect(mapEquals<String, int>(<String, int>{}, null), isFalse);
      final map = <String, int>{'a': 1};
      expect(mapEquals(map, map), isTrue);
    });

    test('empty maps are equal', () {
      expect(mapEquals(<String, int>{}, <String, int>{}), isTrue);
    });

    test('ignores insertion order', () {
      expect(
        mapEquals(<String, int>{'a': 1, 'b': 2}, <String, int>{'b': 2, 'a': 1}),
        isTrue,
      );
    });

    test('differs by length, key or value', () {
      expect(
        mapEquals(<String, int>{'a': 1}, <String, int>{'a': 1, 'b': 2}),
        isFalse,
      );
      expect(mapEquals(<String, int>{'a': 1}, <String, int>{'b': 1}), isFalse);
      expect(mapEquals(<String, int>{'a': 1}, <String, int>{'a': 2}), isFalse);
    });

    test('a null value is not the same as a missing key', () {
      expect(
        mapEquals(<String, int?>{'a': null}, <String, int?>{'b': null}),
        isFalse,
      );
      expect(
        mapEquals(<String, int?>{'a': null}, <String, int?>{'a': null}),
        isTrue,
      );
    });
  });

  group('hashList', () {
    test('equal sequences hash equally', () {
      expect(hashList(<int>[1, 2, 3]), hashList(<int>[1, 2, 3]));
      expect(hashList(<int>[]), hashList(<int>[]));
    });

    test('order matters', () {
      expect(hashList(<int>[1, 2]), isNot(hashList(<int>[2, 1])));
    });

    test('works with any iterable and null items', () {
      expect(hashList(<int?>[null, 1]), hashList(<int?>[null, 1]));
      expect(hashList(<int>[1, 2].map((e) => e)), hashList(<int>[1, 2]));
    });
  });

  group('domain equality after leaving foundation', () {
    test('BoardModel equality covers its collections', () {
      final a = makeBoard();
      final b = makeBoard();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(cards: a.cards.sublist(1)), isNot(a));
      expect(a.copyWith(members: const <BoardMember>[]), isNot(a));
      expect(a.copyWith(columns: a.columns.reversed.toList()), isNot(a));
    });

    test('CardModel equality includes timestamps and description', () {
      final a = makeCard('x', colA, 'a');
      expect(a, makeCard('x', colA, 'a'));
      expect(a.copyWith(updatedAt: DateTime.utc(2027)), isNot(a));
      expect(a.copyWith(createdAt: DateTime.utc(2027)), isNot(a));
      expect(a.copyWith(description: 'd'), isNot(a));
      expect(a.copyWith(descriptionVersion: 2), isNot(a));
    });

    test('CardDraft and RelativeAge are value objects', () {
      const draft = CardDraft(
        cardId: 'c',
        text: 't',
        baseDescriptionVersion: 1,
      );
      const same = CardDraft(cardId: 'c', text: 't', baseDescriptionVersion: 1);
      expect(draft, same);
      expect(draft.hashCode, same.hashCode);
      expect(draft.withText('u'), isNot(draft));
      expect(
        const RelativeAge(RelativeAgeKind.days, 2),
        const RelativeAge(RelativeAgeKind.days, 2),
      );
      expect(
        const RelativeAge(RelativeAgeKind.days, 2),
        isNot(const RelativeAge(RelativeAgeKind.days, 3)),
      );
    });
  });
}
