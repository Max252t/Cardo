import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/domain/card_draft.dart';
import 'package:cardo/features/board/domain/unsaved_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

BoardSyncState stateWith(List<PendingOp> pending) {
  final board = makeBoard();
  return BoardSyncState(
    confirmed: board,
    lastSeq: board.seq,
    pending: pending,
    connection: ConnectionStatus.connected,
  );
}

PendingOp descriptionOp(String cardId, String text) {
  return PendingOp(
    op: EditCardDescription(
      opId: 'op-$cardId',
      cardId: cardId,
      description: text,
      baseDescriptionVersion: 0,
      actorId: 'u1',
    ),
    status: PendingOpStatus.queued,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  test('a draft that differs from the card is unsaved', () {
    final found = unsavedDescriptions(const [
      CardDraft(cardId: 'a1', text: 'typed', baseDescriptionVersion: 0),
    ], stateWith(const []));

    expect(found, [
      const UnsavedText(cardId: 'a1', cardTitle: 'Card a1', text: 'typed'),
    ]);
  });

  test('empty drafts and drafts equal to the saved text are skipped', () {
    final found = unsavedDescriptions(const [
      CardDraft(cardId: 'a1', text: '', baseDescriptionVersion: 0),
      CardDraft(cardId: 'a2', text: '', baseDescriptionVersion: 0),
    ], stateWith(const []));

    expect(found, isEmpty);
  });

  test('a pending description edit is unsaved too', () {
    final found = unsavedDescriptions(
      const <CardDraft>[],
      stateWith([descriptionOp('a2', 'queued text')]),
    );

    expect(found.single.text, 'queued text');
    expect(found.single.cardTitle, 'Card a2');
  });

  test('one entry per card, the draft wins over its pending edit', () {
    final found = unsavedDescriptions(const [
      CardDraft(cardId: 'a1', text: 'newest', baseDescriptionVersion: 0),
    ], stateWith([descriptionOp('a1', 'older'), descriptionOp('a2', 'other')]));

    expect(found.map((e) => e.text), ['newest', 'other']);
  });

  test('other operations carry no text', () {
    final found = unsavedDescriptions(
      const <CardDraft>[],
      stateWith([
        PendingOp(
          op: moveOp('a1', colB),
          status: PendingOpStatus.queued,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]),
    );

    expect(found, isEmpty);
  });
}
