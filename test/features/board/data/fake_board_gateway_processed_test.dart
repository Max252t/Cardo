import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

const String _card = DemoIds.handshakeCard;

EditCardDescription _edit(String text, {int base = 1, String opId = 'op'}) {
  return EditCardDescription(
    opId: opId,
    cardId: _card,
    description: text,
    baseDescriptionVersion: base,
    actorId: DemoIds.elena,
  );
}

OpRejection _rejection(OpOutcome outcome) => (outcome as OpRejected).rejection;

void main() {
  test('a repeated op id returns the stored confirmation', () async {
    final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
    final first = await gateway.submit(_edit('once', opId: 'same'));
    final second = await gateway.submit(_edit('once', opId: 'same'));
    expect(first, isA<OpConfirmed>());
    expect(second, first);
    final card = gateway.serverBoard.cardById(_card)!;
    expect(card.descriptionVersion, 2);
    expect(gateway.serverBoard.seq, (first as OpConfirmed).seq);
  });

  test('a repeated op id returns the stored nack', () async {
    final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
    gateway.simulateRemoteDescriptionEdit(
      cardId: _card,
      text: 'theirs',
      actorId: DemoIds.maxim,
    );
    final first = await gateway.submit(_edit('mine', opId: 'same'));
    final second = await gateway.submit(_edit('mine', opId: 'same'));
    expect(_rejection(first).reason, NackReason.versionConflict);
    expect(second, first);
  });

  test('a different op id with the same content is a new operation', () async {
    final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
    await gateway.submit(_edit('once', opId: 'a'));
    final second = await gateway.submit(_edit('once', opId: 'b'));
    expect(_rejection(second).reason, NackReason.versionConflict);
  });

  test('forced rejections are not remembered', () async {
    var rejectNext = true;
    final gateway = FakeBoardGateway(
      confirmDelay: Duration.zero,
      rejectWhen: (op) {
        if (!rejectNext) {
          return null;
        }
        rejectNext = false;
        return const OpRejection(reason: NackReason.internal);
      },
    );
    final first = await gateway.submit(_edit('retry', opId: 'same'));
    final second = await gateway.submit(_edit('retry', opId: 'same'));
    expect(_rejection(first).reason, NackReason.internal);
    expect(second, isA<OpConfirmed>());
  });

  test('announced conflicts publish the card before the nack', () async {
    final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
    final events = <RemoteCardUpdate>[];
    final subscription = gateway.remoteUpdates.listen(events.add);
    gateway.simulateRemoteDescriptionEdit(
      cardId: _card,
      text: 'theirs',
      actorId: DemoIds.maxim,
    );
    await gateway.submit(_edit('mine'));
    expect(events.length, 1);
    expect(events.single.card.description, 'theirs');
    await subscription.cancel();
    await gateway.dispose();
  });

  test('without announcements the event is delivered on demand', () async {
    final gateway = FakeBoardGateway(
      confirmDelay: Duration.zero,
      announceConflicts: false,
    );
    final events = <RemoteCardUpdate>[];
    final subscription = gateway.remoteUpdates.listen(events.add);
    gateway.simulateRemoteDescriptionEdit(
      cardId: _card,
      text: 'theirs',
      actorId: DemoIds.maxim,
    );
    final outcome = await gateway.submit(_edit('mine'));
    expect(_rejection(outcome).atSeq, gateway.serverBoard.seq);
    expect(events, isEmpty);
    gateway.publishCard(_card);
    expect(events.length, 1);
    expect(events.single.seq, gateway.serverBoard.seq);
    expect(events.single.actorId, DemoIds.maxim);
    expect(events.single.card.descriptionVersion, 2);
    await subscription.cancel();
    await gateway.dispose();
  });
}
