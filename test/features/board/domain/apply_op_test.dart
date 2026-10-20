import 'package:cardo/core/ranking/rank.dart';
import 'package:cardo/features/board/domain/apply_op.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

void main() {
  late BoardModel board;

  setUp(() {
    board = makeBoard();
  });

  group('MoveCard anchors (TZ 9.2)', () {
    test('between existing after and before', () {
      final next = applyOp(
        board,
        moveOp('b1', colA, afterId: 'a1', beforeId: 'a2'),
      );
      expect(ids(next, colA), <String>['a1', 'b1', 'a2', 'a3']);
      expect(ids(next, colB), <String>['b2']);
    });

    test('missing before goes right after the after anchor', () {
      final next = applyOp(
        board,
        moveOp('b1', colA, afterId: 'a1', beforeId: 'gone'),
      );
      expect(ids(next, colA), <String>['a1', 'b1', 'a2', 'a3']);
    });

    test('null before goes right after the after anchor', () {
      final next = applyOp(board, moveOp('b1', colA, afterId: 'a2'));
      expect(ids(next, colA), <String>['a1', 'a2', 'b1', 'a3']);
    });

    test('missing after goes right before the before anchor', () {
      final next = applyOp(
        board,
        moveOp('b1', colA, afterId: 'gone', beforeId: 'a2'),
      );
      expect(ids(next, colA), <String>['a1', 'b1', 'a2', 'a3']);
    });

    test('null after goes right before the before anchor', () {
      final next = applyOp(board, moveOp('b1', colA, beforeId: 'a3'));
      expect(ids(next, colA), <String>['a1', 'a2', 'b1', 'a3']);
    });

    test('before the first card', () {
      final next = applyOp(board, moveOp('b1', colA, beforeId: 'a1'));
      expect(ids(next, colA), <String>['b1', 'a1', 'a2', 'a3']);
    });

    test('no anchors at all goes to the end', () {
      final next = applyOp(board, moveOp('b1', colA));
      expect(ids(next, colA), <String>['a1', 'a2', 'a3', 'b1']);
    });

    test('both anchors missing goes to the end', () {
      final next = applyOp(
        board,
        moveOp('b1', colA, afterId: 'x', beforeId: 'y'),
      );
      expect(ids(next, colA), <String>['a1', 'a2', 'a3', 'b1']);
    });

    test('after the last card', () {
      final next = applyOp(board, moveOp('b1', colA, afterId: 'a3'));
      expect(ids(next, colA), <String>['a1', 'a2', 'a3', 'b1']);
    });

    test('into an empty column', () {
      final next = applyOp(board, moveOp('a1', colC));
      expect(ids(next, colC), <String>['a1']);
      expect(ids(next, colA), <String>['a2', 'a3']);
    });

    test('anchor equal to the moved card itself is ignored', () {
      final next = applyOp(
        board,
        moveOp('a2', colA, afterId: 'a2', beforeId: 'a3'),
      );
      expect(ids(next, colA), <String>['a1', 'a2', 'a3']);
    });

    test('anchors from another column fall back to the end', () {
      final next = applyOp(board, moveOp('a1', colB, afterId: 'a2'));
      expect(ids(next, colB), <String>['b1', 'b2', 'a1']);
    });

    test('reorder inside a column forward', () {
      final next = applyOp(board, moveOp('a1', colA, afterId: 'a3'));
      expect(ids(next, colA), <String>['a2', 'a3', 'a1']);
    });

    test('reorder inside a column backward', () {
      final next = applyOp(board, moveOp('a3', colA, beforeId: 'a1'));
      expect(ids(next, colA), <String>['a3', 'a1', 'a2']);
    });

    test('result rank sits strictly between neighbours', () {
      final next = applyOp(
        board,
        moveOp('b1', colA, afterId: 'a1', beforeId: 'a2'),
      );
      final moved = next.cardById('b1')!;
      expect(compareRanks(board.cardById('a1')!.rank, moved.rank), lessThan(0));
      expect(compareRanks(moved.rank, board.cardById('a2')!.rank), lessThan(0));
      expect(isValidRank(moved.rank), isTrue);
    });

    test('other cards keep rank and column', () {
      final next = applyOp(
        board,
        moveOp('b1', colA, afterId: 'a1', beforeId: 'a2'),
      );
      for (final id in <String>['a1', 'a2', 'a3', 'b2']) {
        expect(next.cardById(id), board.cardById(id));
      }
    });

    test('does not mutate the source board', () {
      final snapshot = board.cards.toList();
      applyOp(board, moveOp('b1', colA));
      expect(board.cards, snapshot);
    });
  });

  group('MoveCard special cases', () {
    test('move to the same place keeps rank and order', () {
      final before = board.cardById('a2')!;
      final next = applyOp(
        board,
        moveOp('a2', colA, afterId: 'a1', beforeId: 'a3'),
      );
      expect(ids(next, colA), <String>['a1', 'a2', 'a3']);
      expect(next.cardById('a2')!.rank, before.rank);
      expect(next.cardById('a2')!.columnId, colA);
    });

    test('move last card to the end keeps rank', () {
      final before = board.cardById('a3')!;
      final next = applyOp(board, moveOp('a3', colA, afterId: 'a2'));
      expect(next.cardById('a3')!.rank, before.rank);
    });

    test('missing card leaves the board identical', () {
      final next = applyOp(board, moveOp('nope', colA));
      expect(identical(next, board), isTrue);
    });

    test('archived card leaves the board identical', () {
      final withArchived = board.copyWith(
        cards: <CardModel>[
          ...board.cards,
          makeCard('z1', colA, 'zz', archived: true),
        ],
      );
      final next = applyOp(withArchived, moveOp('z1', colB));
      expect(identical(next, withArchived), isTrue);
    });

    test('missing target column leaves the board identical', () {
      final next = applyOp(board, moveOp('a1', 'no-column'));
      expect(identical(next, board), isTrue);
    });

    test('version increments by one on move', () {
      final next = applyOp(board, moveOp('b2', colA));
      expect(next.cardById('b2')!.version, 5);
    });

    test('neighbour version is untouched', () {
      final next = applyOp(
        board,
        moveOp('b2', colA, afterId: 'a1', beforeId: 'a2'),
      );
      expect(next.cardById('a1')!.version, 1);
      expect(next.cardById('a2')!.version, 1);
      expect(next.cardById('b1')!.version, 1);
    });

    test('two moves bump version twice', () {
      final first = applyOp(board, moveOp('a1', colB, opId: 'x'));
      final second = applyOp(first, moveOp('a1', colC, opId: 'y'));
      expect(second.cardById('a1')!.version, 3);
      expect(second.cardById('a1')!.columnId, colC);
    });

    test('move does not change seq', () {
      final next = applyOp(board, moveOp('a1', colB));
      expect(next.seq, board.seq);
    });
  });

  group('CreateCard', () {
    CreateCard create({
      String cardId = 'n1',
      String columnId = colA,
      String? afterId,
      String? beforeId,
    }) {
      return CreateCard(
        opId: 'c-$cardId',
        cardId: cardId,
        columnId: columnId,
        title: 'New',
        actorId: 'u1',
        afterId: afterId,
        beforeId: beforeId,
      );
    }

    test('appends to the end without anchors', () {
      final next = applyOp(board, create());
      expect(ids(next, colA), <String>['a1', 'a2', 'a3', 'n1']);
      final card = next.cardById('n1')!;
      expect(card.title, 'New');
      expect(card.createdBy, 'u1');
      expect(card.updatedBy, 'u1');
      expect(card.version, 1);
      expect(card.archived, isFalse);
    });

    test('respects the after anchor', () {
      final next = applyOp(board, create(afterId: 'a1'));
      expect(ids(next, colA), <String>['a1', 'n1', 'a2', 'a3']);
    });

    test('respects the before anchor when after is missing', () {
      final next = applyOp(board, create(beforeId: 'a1'));
      expect(ids(next, colA), <String>['n1', 'a1', 'a2', 'a3']);
    });

    test('into an empty column', () {
      final next = applyOp(board, create(columnId: colC));
      expect(ids(next, colC), <String>['n1']);
    });

    test('is idempotent by card id', () {
      final once = applyOp(board, create());
      final twice = applyOp(once, create());
      expect(twice, once);
      expect(identical(twice, once), isTrue);
    });

    test('ignores an unknown column', () {
      final next = applyOp(board, create(columnId: 'nope'));
      expect(identical(next, board), isTrue);
    });
  });

  group('EditCardTitle', () {
    test('changes title, author and version', () {
      final next = applyOp(
        board,
        const EditCardTitle(
          opId: 'e',
          cardId: 'a1',
          title: 'Renamed',
          actorId: 'u2',
        ),
      );
      final card = next.cardById('a1')!;
      expect(card.title, 'Renamed');
      expect(card.updatedBy, 'u2');
      expect(card.createdBy, 'u1');
      expect(card.version, 2);
    });

    test('missing card is a no-op', () {
      final next = applyOp(
        board,
        const EditCardTitle(
          opId: 'e',
          cardId: 'nope',
          title: 'x',
          actorId: 'u1',
        ),
      );
      expect(identical(next, board), isTrue);
    });

    test('archived card is a no-op', () {
      final withArchived = applyOp(
        board,
        const ArchiveCard(opId: 'a', cardId: 'a1'),
      );
      final next = applyOp(
        withArchived,
        const EditCardTitle(opId: 'e', cardId: 'a1', title: 'x', actorId: 'u1'),
      );
      expect(identical(next, withArchived), isTrue);
    });
  });

  group('ArchiveCard', () {
    test('hides the card from its column', () {
      final next = applyOp(board, const ArchiveCard(opId: 'a', cardId: 'a2'));
      expect(ids(next, colA), <String>['a1', 'a3']);
      expect(next.cardById('a2')!.archived, isTrue);
    });

    test('is idempotent', () {
      const op = ArchiveCard(opId: 'a', cardId: 'a2');
      final once = applyOp(board, op);
      final twice = applyOp(once, op);
      expect(identical(twice, once), isTrue);
    });

    test('missing card is a no-op', () {
      final next = applyOp(board, const ArchiveCard(opId: 'a', cardId: 'zz'));
      expect(identical(next, board), isTrue);
    });
  });

  group('applyOps', () {
    test('folds operations in order', () {
      final next = applyOps(board, <BoardOp>[
        moveOp('a1', colB, opId: '1'),
        moveOp('a2', colB, afterId: 'a1', opId: '2'),
        const ArchiveCard(opId: '3', cardId: 'b1'),
      ]);
      expect(ids(next, colB), <String>['b2', 'a1', 'a2']);
    });

    test('empty list returns the same board', () {
      expect(identical(applyOps(board, const <BoardOp>[]), board), isTrue);
    });
  });

  group('resolveInsertIndex', () {
    late List<CardModel> ordered;

    setUp(() {
      ordered = board.cardsIn(colA);
    });

    test('after wins over before', () {
      expect(resolveInsertIndex(ordered, afterId: 'a1', beforeId: 'a3'), 1);
    });

    test('before is used when after is missing', () {
      expect(resolveInsertIndex(ordered, afterId: 'gone', beforeId: 'a3'), 2);
    });

    test('before is used when after is null', () {
      expect(resolveInsertIndex(ordered, beforeId: 'a2'), 1);
    });

    test('end when both are missing', () {
      expect(resolveInsertIndex(ordered, afterId: 'x', beforeId: 'y'), 3);
      expect(resolveInsertIndex(ordered), 3);
    });

    test('empty list', () {
      expect(resolveInsertIndex(const <CardModel>[], afterId: 'a'), 0);
    });
  });

  group('anchorsAt', () {
    late List<CardModel> ordered;

    setUp(() {
      ordered = board.cardsIn(colA);
    });

    test('start has only before', () {
      expect(
        anchorsAt(ordered, 0),
        const CardAnchors(afterId: null, beforeId: 'a1'),
      );
    });

    test('middle has both', () {
      expect(
        anchorsAt(ordered, 2),
        const CardAnchors(afterId: 'a2', beforeId: 'a3'),
      );
    });

    test('end has only after', () {
      expect(
        anchorsAt(ordered, 3),
        const CardAnchors(afterId: 'a3', beforeId: null),
      );
    });

    test('index is clamped', () {
      expect(anchorsAt(ordered, -5), anchorsAt(ordered, 0));
      expect(anchorsAt(ordered, 99), anchorsAt(ordered, 3));
    });

    test('empty list has no anchors', () {
      expect(anchorsAt(const <CardModel>[], 0), const CardAnchors());
    });

    test('equality and hashCode', () {
      expect(
        const CardAnchors(afterId: 'a', beforeId: 'b'),
        const CardAnchors(afterId: 'a', beforeId: 'b'),
      );
      expect(
        const CardAnchors(afterId: 'a', beforeId: 'b').hashCode,
        const CardAnchors(afterId: 'a', beforeId: 'b').hashCode,
      );
      expect(
        const CardAnchors(afterId: 'a'),
        isNot(const CardAnchors(beforeId: 'a')),
      );
    });
  });

  group('rankAtIndex', () {
    test('between two cards', () {
      final ordered = board.cardsIn(colA);
      final rank = rankAtIndex(ordered, 1);
      expect(compareRanks(ordered[0].rank, rank), lessThan(0));
      expect(compareRanks(rank, ordered[1].rank), lessThan(0));
    });

    test('at the start', () {
      final ordered = board.cardsIn(colA);
      expect(
        compareRanks(rankAtIndex(ordered, 0), ordered[0].rank),
        lessThan(0),
      );
    });

    test('at the end', () {
      final ordered = board.cardsIn(colA);
      expect(
        compareRanks(ordered.last.rank, rankAtIndex(ordered, 3)),
        lessThan(0),
      );
    });

    test('empty list gives initial rank', () {
      expect(rankAtIndex(const <CardModel>[], 0), rankInitial());
    });

    test('index is clamped', () {
      final ordered = board.cardsIn(colA);
      expect(rankAtIndex(ordered, 99), rankAtIndex(ordered, 3));
      expect(rankAtIndex(ordered, -1), rankAtIndex(ordered, 0));
    });

    test('equal neighbour ranks fall back to after the previous', () {
      final ordered = <CardModel>[
        makeCard('x', colA, 'V'),
        makeCard('y', colA, 'V'),
      ];
      final rank = rankAtIndex(ordered, 1);
      expect(compareRanks('V', rank), lessThan(0));
      expect(isValidRank(rank), isTrue);
    });
  });

  group('BoardModel queries', () {
    test('cardsIn sorts by rank and skips archived', () {
      final shuffled = board.copyWith(
        cards: <CardModel>[
          makeCard('late', colA, 'z'),
          makeCard('early', colA, '1'),
          makeCard('gone', colA, '5', archived: true),
        ],
      );
      expect(ids(shuffled, colA), <String>['early', 'late']);
    });

    test('equal ranks tie-break by id', () {
      final tie = board.copyWith(
        cards: <CardModel>[makeCard('b', colA, 'V'), makeCard('a', colA, 'V')],
      );
      expect(ids(tie, colA), <String>['a', 'b']);
    });

    test('orderedColumns sorts by rank', () {
      final reversed = board.copyWith(columns: board.columns.reversed.toList());
      expect(reversed.orderedColumns.map((c) => c.id).toList(), <String>[
        colA,
        colB,
        colC,
      ]);
    });

    test('lookups return null for unknown ids', () {
      expect(board.cardById('nope'), isNull);
      expect(board.columnById('nope'), isNull);
      expect(board.memberById('nope'), isNull);
      expect(board.memberById('u1'), isNotNull);
    });

    test('value equality and copyWith', () {
      expect(makeBoard(), makeBoard());
      expect(makeBoard().hashCode, makeBoard().hashCode);
      expect(board.copyWith(seq: 99), isNot(board));
      expect(board.copyWith(), board);
      final card = board.cardById('a1')!;
      expect(card.copyWith(title: 'x'), isNot(card));
      expect(card.copyWith(), card);
      expect(card.copyWith().hashCode, card.hashCode);
    });

    test('hasDescription ignores whitespace', () {
      final card = board.cardById('a1')!;
      expect(card.hasDescription, isFalse);
      expect(card.copyWith(description: '  \n').hasDescription, isFalse);
      expect(card.copyWith(description: 'text').hasDescription, isTrue);
    });

    test('board lists are unmodifiable', () {
      expect(
        () => board.cards.add(makeCard('q', colA, 'a')),
        throwsUnsupportedError,
      );
    });
  });
}
