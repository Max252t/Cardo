import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/domain/apply_event.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';
import '../helpers/event_factory.dart';

void main() {
  late BoardModel board;

  setUp(() => board = makeBoard());

  group('seq', () {
    test('every event moves the board seq to the event seq', () {
      for (final event in oneOfEachEvent(firstSeq: 11)) {
        expect(applyEvent(board, event).seq, event.seq, reason: event.type);
      }
    });

    test('applyEvents folds in order and ends at the last seq', () {
      final result = applyEvents(board, <BoardEvent>[
        renamed(11, title: 'one'),
        renamed(12, title: 'two'),
      ]);

      expect(result.title, 'two');
      expect(result.seq, 12);
    });

    test('an event on a missing entity still advances seq', () {
      final result = applyEvent(board, cardEdited(11, 'nope', title: 'x'));

      expect(result.seq, 11);
      expect(result.cards, board.cards);
    });
  });

  group('card.created', () {
    test(
      'adds the card with rank, version and descriptionVersion verbatim',
      () {
        final event = cardCreated(
          11,
          'n1',
          colB,
          'mm',
          title: 'Hello',
          description: 'Body',
          version: 7,
          descriptionVersion: 3,
          actorId: 'u9',
        );

        final card = applyEvent(board, event).cardById('n1')!;

        expect(card.columnId, colB);
        expect(card.rank, 'mm');
        expect(card.version, 7);
        expect(card.descriptionVersion, 3);
        expect(card.title, 'Hello');
        expect(card.description, 'Body');
        expect(card.createdBy, 'u9');
        expect(card.updatedBy, 'u9');
        expect(card.archived, isFalse);
      },
    );

    test('a repeated create replaces the card instead of duplicating it', () {
      final first = applyEvent(board, cardCreated(11, 'n1', colA, 'x'));
      final again = applyEvent(
        first,
        cardCreated(12, 'n1', colA, 'y', title: 'Second'),
      );

      expect(again.cards.where((card) => card.id == 'n1'), hasLength(1));
      expect(again.cardById('n1')!.title, 'Second');
      expect(again.cardById('n1')!.rank, 'y');
    });

    test('a created card is placed in its column by rank', () {
      final result = applyEvent(board, cardCreated(11, 'low', colA, '1'));

      expect(ids(result, colA), ['low', 'a1', 'a2', 'a3']);
    });
  });

  group('card.edited', () {
    test('title only keeps the description', () {
      final seeded = applyEvent(
        board,
        cardEdited(11, 'a1', description: 'Old', descriptionVersion: 2),
      );

      final result = applyEvent(
        seeded,
        cardEdited(12, 'a1', title: 'New title', version: 5),
      );

      final card = result.cardById('a1')!;
      expect(card.title, 'New title');
      expect(card.description, 'Old');
      expect(card.version, 5);
    });

    test('description only keeps the title', () {
      final result = applyEvent(
        board,
        cardEdited(
          11,
          'a1',
          description: 'Fresh body',
          version: 6,
          descriptionVersion: 4,
        ),
      );

      final card = result.cardById('a1')!;
      expect(card.title, 'Card a1');
      expect(card.description, 'Fresh body');
      expect(card.version, 6);
      expect(card.descriptionVersion, 4);
    });

    test('title and description together', () {
      final result = applyEvent(
        board,
        cardEdited(
          11,
          'a2',
          title: 'Both',
          description: 'Also',
          version: 9,
          descriptionVersion: 8,
          actorId: 'u7',
        ),
      );

      final card = result.cardById('a2')!;
      expect(card.title, 'Both');
      expect(card.description, 'Also');
      expect(card.version, 9);
      expect(card.descriptionVersion, 8);
      expect(card.updatedBy, 'u7');
      expect(card.updatedAt, eventTime);
    });

    test('version and descriptionVersion come from the event, not +1', () {
      final result = applyEvent(
        board,
        cardEdited(11, 'a1', title: 'x', version: 40, descriptionVersion: 30),
      );

      expect(result.cardById('a1')!.version, 40);
      expect(result.cardById('a1')!.descriptionVersion, 30);
    });

    test('an empty description is a real value', () {
      final seeded = applyEvent(
        board,
        cardEdited(11, 'a1', description: 'Text'),
      );

      final result = applyEvent(seeded, cardEdited(12, 'a1', description: ''));

      expect(result.cardById('a1')!.description, '');
    });

    test('other cards stay untouched', () {
      final result = applyEvent(board, cardEdited(11, 'a1', title: 'x'));

      expect(result.cardById('a2'), board.cardById('a2'));
      expect(result.cardById('b1'), board.cardById('b1'));
    });

    test('a missing card is ignored without throwing', () {
      expect(
        () => applyEvent(board, cardEdited(11, 'ghost', title: 'x')),
        returnsNormally,
      );
      expect(
        applyEvent(board, cardEdited(11, 'ghost', title: 'x')).cards,
        board.cards,
      );
    });
  });

  group('card.moved', () {
    test('changes column, rank and version from the event', () {
      final result = applyEvent(
        board,
        cardMoved(11, 'a1', colA, colC, 'q', version: 12, actorId: 'u5'),
      );

      final card = result.cardById('a1')!;
      expect(card.columnId, colC);
      expect(card.rank, 'q');
      expect(card.version, 12);
      expect(card.updatedBy, 'u5');
      expect(ids(result, colA), ['a2', 'a3']);
      expect(ids(result, colC), ['a1']);
    });

    test('the order in the target column follows the new rank', () {
      final b = board.cardsIn(colB);
      final result = applyEvent(
        board,
        cardMoved(11, 'a1', colA, colB, '${b.first.rank}0'),
      );

      expect(ids(result, colB), ['b1', 'a1', 'b2']);
    });

    test('a missing card is ignored', () {
      final result = applyEvent(board, cardMoved(11, 'ghost', colA, colB, 'x'));

      expect(result.cards, board.cards);
    });
  });

  group('card.archived', () {
    test('marks the card archived and takes the version', () {
      final result = applyEvent(
        board,
        cardArchived(11, 'a2', colA, version: 8),
      );

      expect(result.cardById('a2')!.archived, isTrue);
      expect(result.cardById('a2')!.version, 8);
      expect(ids(result, colA), ['a1', 'a3']);
    });

    test('a missing card is ignored', () {
      final result = applyEvent(board, cardArchived(11, 'ghost', colA));

      expect(result.cards, board.cards);
    });
  });

  group('column events', () {
    test('column.created adds a column with the event rank and version', () {
      final result = applyEvent(
        board,
        columnCreated(11, 'col-n', 'zzz', title: 'Extra', version: 4),
      );

      final column = result.columnById('col-n')!;
      expect(column.title, 'Extra');
      expect(column.rank, 'zzz');
      expect(column.version, 4);
      expect(result.orderedColumns.last.id, 'col-n');
      expect(result.orderedColumns.last.marker, ColumnMarker.done);
    });

    test('column.created recomputes markers for the neighbours', () {
      final result = applyEvent(board, columnCreated(11, 'col-n', 'zzz'));

      expect(result.columnById(colC)!.marker, ColumnMarker.review);
      expect(result.columnById(colA)!.marker, ColumnMarker.backlog);
    });

    test('a repeated column.created replaces rather than duplicates', () {
      final once = applyEvent(board, columnCreated(11, 'col-n', 'zzz'));
      final twice = applyEvent(
        once,
        columnCreated(12, 'col-n', 'zzz', title: 'Again'),
      );

      expect(twice.columns.where((c) => c.id == 'col-n'), hasLength(1));
      expect(twice.columnById('col-n')!.title, 'Again');
    });

    test('column.renamed sets title and version', () {
      final result = applyEvent(
        board,
        ColumnRenamedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columnId: colB,
          title: 'Doing',
          version: 6,
        ),
      );

      expect(result.columnById(colB)!.title, 'Doing');
      expect(result.columnById(colB)!.version, 6);
      expect(result.columnById(colA)!.title, 'A');
    });

    test('column.moved takes rank and version and reorders', () {
      final result = applyEvent(
        board,
        ColumnMovedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columnId: colA,
          rank: 'zzz',
          version: 3,
        ),
      );

      expect(result.orderedColumns.map((c) => c.id), [colB, colC, colA]);
      expect(result.columnById(colA)!.version, 3);
      expect(result.columnById(colA)!.rank, 'zzz');
      expect(result.orderedColumns.first.marker, ColumnMarker.backlog);
      expect(result.orderedColumns.last.marker, ColumnMarker.done);
    });

    test('column.archived removes the column and archives card_ids', () {
      final result = applyEvent(
        board,
        ColumnArchivedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columnId: colA,
          cardIds: const <String>['a1', 'a3'],
          version: 2,
        ),
      );

      expect(result.columnById(colA), isNull);
      expect(result.cardById('a1')!.archived, isTrue);
      expect(result.cardById('a3')!.archived, isTrue);
      expect(result.orderedColumns.map((c) => c.id), [colB, colC]);
    });

    test('column.archived archives card_ids even outside the column', () {
      final result = applyEvent(
        board,
        ColumnArchivedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columnId: colA,
          cardIds: const <String>['b1'],
          version: 2,
        ),
      );

      expect(result.cardById('b1')!.archived, isTrue);
      expect(result.cardById('b2')!.archived, isFalse);
    });

    test('column.archived leaves other columns cards alone', () {
      final result = applyEvent(
        board,
        ColumnArchivedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columnId: colA,
          cardIds: const <String>['a1', 'a2', 'a3'],
          version: 2,
        ),
      );

      expect(ids(result, colB), ['b1', 'b2']);
    });

    test('events for a missing column change nothing but seq', () {
      final events = <BoardEvent>[
        ColumnRenamedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columnId: 'ghost',
          title: 'x',
          version: 2,
        ),
        ColumnMovedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columnId: 'ghost',
          rank: 'x',
          version: 2,
        ),
        ColumnArchivedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columnId: 'ghost',
          cardIds: const <String>['a1'],
          version: 2,
        ),
      ];

      for (final event in events) {
        final result = applyEvent(board, event);
        expect(result.columns, board.columns, reason: event.type);
        expect(result.cards, board.cards, reason: event.type);
        expect(result.seq, 11);
      }
    });
  });

  group('rebalance', () {
    test('column.rebalanced rewrites card ranks and the order follows', () {
      final result = applyEvent(
        board,
        ColumnRebalancedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columnId: colA,
          cards: const <CardRankEntry>[
            (cardId: 'a3', rank: 'b'),
            (cardId: 'a1', rank: 'm'),
            (cardId: 'a2', rank: 'x'),
          ],
        ),
      );

      expect(result.cardById('a3')!.rank, 'b');
      expect(result.cardById('a1')!.rank, 'm');
      expect(result.cardById('a2')!.rank, 'x');
      expect(ids(result, colA), ['a3', 'a1', 'a2']);
    });

    test('column.rebalanced does not bump versions or touch other cards', () {
      final result = applyEvent(
        board,
        ColumnRebalancedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columnId: colA,
          cards: const <CardRankEntry>[(cardId: 'a1', rank: 'q')],
        ),
      );

      expect(result.cardById('a1')!.version, board.cardById('a1')!.version);
      expect(result.cardById('a2'), board.cardById('a2'));
      expect(result.cardById('b2'), board.cardById('b2'));
    });

    test('column.rebalanced ignores unknown card ids', () {
      final result = applyEvent(
        board,
        ColumnRebalancedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columnId: colA,
          cards: const <CardRankEntry>[(cardId: 'ghost', rank: 'q')],
        ),
      );

      expect(result.cards, board.cards);
    });

    test('columns.rebalanced rewrites column ranks and reorders', () {
      final result = applyEvent(
        board,
        ColumnsRebalancedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columns: const <ColumnRankEntry>[
            (columnId: colC, rank: 'b'),
            (columnId: colB, rank: 'm'),
            (columnId: colA, rank: 'x'),
          ],
        ),
      );

      expect(result.orderedColumns.map((c) => c.id), [colC, colB, colA]);
      expect(result.columnById(colC)!.rank, 'b');
      expect(result.orderedColumns.first.marker, ColumnMarker.backlog);
      expect(result.orderedColumns.last.marker, ColumnMarker.done);
    });

    test('columns.rebalanced keeps version and title', () {
      final result = applyEvent(
        board,
        ColumnsRebalancedEvent(
          seq: 11,
          serverTs: eventTime,
          actorId: 'u2',
          columns: const <ColumnRankEntry>[(columnId: colA, rank: 'zz')],
        ),
      );

      expect(result.columnById(colA)!.version, board.columnById(colA)!.version);
      expect(result.columnById(colA)!.title, 'A');
    });
  });

  group('board events', () {
    test('board.renamed changes the title only', () {
      final result = applyEvent(board, renamed(11, title: 'Shiny'));

      expect(result.title, 'Shiny');
      expect(result.cards, board.cards);
      expect(result.columns, board.columns);
      expect(result.members, board.members);
    });

    test('board.deleted leaves content alone and advances seq', () {
      final result = applyEvent(
        board,
        BoardDeletedEvent(seq: 11, serverTs: eventTime, actorId: 'u2'),
      );

      expect(result.cards, board.cards);
      expect(result.columns, board.columns);
      expect(result.title, board.title);
      expect(result.seq, 11);
    });

    test('an unknown event type is ignored and advances seq', () {
      final result = applyEvent(
        board,
        UnknownBoardEvent(
          seq: 11,
          serverTs: eventTime,
          unknownType: 'future.thing',
        ),
      );

      expect(result.cards, board.cards);
      expect(result.seq, 11);
    });
  });

  group('member events', () {
    test('member.added appends the member with the event fields', () {
      final result = applyEvent(
        board,
        memberAdded(
          11,
          'u3',
          role: BoardRole.viewer,
          name: 'Kate',
          color: '#445566',
        ),
      );

      final member = result.memberById('u3')!;
      expect(member.name, 'Kate');
      expect(member.avatarColor, '#445566');
      expect(member.role, BoardRole.viewer);
      expect(result.members, hasLength(2));
    });

    test('member.added for an existing member replaces it', () {
      final once = applyEvent(board, memberAdded(11, 'u3'));
      final twice = applyEvent(
        once,
        memberAdded(12, 'u3', role: BoardRole.viewer, name: 'Renamed'),
      );

      expect(twice.members.where((m) => m.userId == 'u3'), hasLength(1));
      expect(twice.memberById('u3')!.role, BoardRole.viewer);
      expect(twice.memberById('u3')!.name, 'Renamed');
    });

    test('member.role_changed updates the role of the current user', () {
      final result = applyEvent(board, roleChanged(11, 'u1', BoardRole.viewer));

      expect(result.memberById('u1')!.role, BoardRole.viewer);
      expect(result.memberById('u1')!.role.canEdit, isFalse);
    });

    test('member.role_changed keeps name and colour', () {
      final result = applyEvent(board, roleChanged(11, 'u1', BoardRole.owner));

      expect(result.memberById('u1')!.name, 'One');
      expect(result.memberById('u1')!.avatarColor, '#2D68F5');
      expect(result.memberById('u1')!.role, BoardRole.owner);
    });

    test('member.role_changed for an unknown user changes nobody', () {
      final result = applyEvent(
        board,
        roleChanged(11, 'ghost', BoardRole.viewer),
      );

      expect(result.members, board.members);
    });

    test('member.removed drops the member', () {
      final added = applyEvent(board, memberAdded(11, 'u3'));

      final result = applyEvent(added, memberRemoved(12, 'u3'));

      expect(result.memberById('u3'), isNull);
      expect(result.members, board.members);
    });

    test('member.removed of the current user leaves no membership', () {
      final result = applyEvent(board, memberRemoved(11, 'u1'));

      expect(result.memberById('u1'), isNull);
      expect(result.members, isEmpty);
    });

    test('member.removed for an unknown user is a no-op', () {
      final result = applyEvent(board, memberRemoved(11, 'ghost'));

      expect(result.members, board.members);
    });
  });

  group('all 15 types', () {
    test('every type applies without throwing, in sequence', () {
      final events = oneOfEachEvent(firstSeq: 11);
      var current = board;

      for (final event in events) {
        current = applyEvent(current, event);
      }

      expect(events.map((e) => e.type).toSet(), hasLength(15));
      expect(current.seq, 25);
      expect(current.title, 'Renamed');
    });

    test('every type is safe against an empty board', () {
      final empty = BoardModel(
        id: 'b',
        title: 'T',
        seq: 0,
        columns: const <ColumnModel>[],
        cards: const <CardModel>[],
        members: const <BoardMember>[],
      );

      for (final event in oneOfEachEvent()) {
        expect(() => applyEvent(empty, event), returnsNormally);
      }
    });
  });
}
