import 'package:cardo/features/board/domain/apply_event.dart';
import 'package:cardo/features/board/domain/apply_op.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

EditCardDescription _edit(
  String cardId,
  String text, {
  int base = 1,
  DateTime? at,
  String actor = 'u2',
}) {
  return EditCardDescription(
    opId: 'e',
    cardId: cardId,
    description: text,
    baseDescriptionVersion: base,
    actorId: actor,
    at: at,
  );
}

void main() {
  late BoardModel board;

  setUp(() {
    board = makeBoard();
  });

  group('applyOp EditCardDescription', () {
    test('sets text, bumps both versions and stamps the author', () {
      final at = DateTime.utc(2026, 3, 4, 5);
      final next = applyOp(board, _edit('a1', 'hello', at: at));
      final card = next.cardById('a1')!;
      final before = board.cardById('a1')!;
      expect(card.description, 'hello');
      expect(card.version, before.version + 1);
      expect(card.descriptionVersion, before.descriptionVersion + 1);
      expect(card.updatedBy, 'u2');
      expect(card.updatedAt, at);
      expect(card.title, before.title);
      expect(card.columnId, before.columnId);
      expect(card.rank, before.rank);
      expect(card.createdBy, before.createdBy);
      expect(card.createdAt, before.createdAt);
    });

    test('keeps updatedAt when the operation has no timestamp', () {
      final next = applyOp(board, _edit('a1', 'hello'));
      expect(next.cardById('a1')!.updatedAt, board.cardById('a1')!.updatedAt);
    });

    test('is cumulative', () {
      final next = applyOp(
        applyOp(board, _edit('a1', 'one')),
        _edit('a1', 'two', base: 2),
      );
      final card = next.cardById('a1')!;
      expect(card.description, 'two');
      expect(card.version, 3);
      expect(card.descriptionVersion, 3);
    });

    test('does not touch other cards', () {
      final next = applyOp(board, _edit('a1', 'hello'));
      expect(next.cardById('a2'), board.cardById('a2'));
      expect(next.cards.length, board.cards.length);
    });

    test('missing card changes nothing', () {
      expect(applyOp(board, _edit('zz', 'x')), board);
    });

    test('archived card changes nothing', () {
      final archived = applyOp(
        board,
        const ArchiveCard(opId: 'a', cardId: 'a1'),
      );
      expect(applyOp(archived, _edit('a1', 'x')), archived);
    });

    test('the domain does not enforce the length limit', () {
      final text = 'x' * (CardLimits.descriptionMaxLength + 1);
      final next = applyOp(board, _edit('a1', text));
      expect(next.cardById('a1')!.description.length, text.length);
    });

    test('an empty description is allowed', () {
      final filled = applyOp(board, _edit('a1', 'text'));
      final cleared = applyOp(filled, _edit('a1', '', base: 2));
      expect(cleared.cardById('a1')!.description, '');
      expect(cleared.cardById('a1')!.hasDescription, isFalse);
    });
  });

  group('applyEvent card.edited', () {
    CardEditedEvent remote({
      String? text = 'remote',
      String? title,
      int descriptionVersion = 5,
      int version = 9,
      String actorId = 'u2',
      DateTime? serverTs,
      int seq = 11,
      String cardId = 'a1',
    }) {
      return CardEditedEvent(
        seq: seq,
        serverTs: serverTs ?? DateTime.utc(2026, 5, 5),
        actorId: actorId,
        cardId: cardId,
        description: text,
        title: title,
        version: version,
        descriptionVersion: descriptionVersion,
      );
    }

    test('applies description, versions and author only', () {
      final before = board.cardById('a1')!;
      final next = applyEvent(board, remote()).cardById('a1')!;
      expect(next.description, 'remote');
      expect(next.descriptionVersion, 5);
      expect(next.version, 9);
      expect(next.updatedBy, 'u2');
      expect(next.updatedAt, DateTime.utc(2026, 5, 5));
      expect(next.columnId, before.columnId);
      expect(next.rank, before.rank);
      expect(next.title, before.title);
      expect(next.createdBy, before.createdBy);
      expect(next.createdAt, before.createdAt);
    });

    test('the event version is authoritative', () {
      final ahead = applyOp(
        applyOp(board, moveOp('a1', colB, baseVersion: 1, opId: 'm1')),
        moveOp('a1', colA, baseVersion: 2, opId: 'm2'),
      );
      expect(ahead.cardById('a1')!.version, 3);
      final next = applyEvent(ahead, remote(version: 4));
      expect(next.cardById('a1')!.version, 4);
      expect(next.cardById('a1')!.description, 'remote');
    });

    test('a title-only edit keeps the description', () {
      final next = applyEvent(board, remote(text: null, title: 'Renamed'));
      expect(next.cardById('a1')!.title, 'Renamed');
      expect(
        next.cardById('a1')!.description,
        board.cardById('a1')!.description,
      );
    });

    test('unknown card changes only the seq', () {
      final next = applyEvent(board, remote(cardId: 'zz'));
      expect(next, board.copyWith(seq: 11));
    });

    test('an archived card stays archived', () {
      final archived = applyOp(
        board,
        const ArchiveCard(opId: 'a', cardId: 'a1'),
      );
      expect(applyEvent(archived, remote()).cardById('a1')!.archived, isTrue);
    });

    test('does not touch other cards', () {
      final next = applyEvent(board, remote());
      expect(next.cardById('a2'), board.cardById('a2'));
    });

    test('advances the board seq', () {
      expect(applyEvent(board, remote(seq: 42)).seq, 42);
    });
  });
}
