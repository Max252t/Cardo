import 'dart:async';

import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

const String _card = DemoIds.handshakeCard;

FakeBoardGateway _gateway() {
  return FakeBoardGateway(confirmDelay: Duration.zero);
}

EditCardDescription _edit(
  String text, {
  int base = 1,
  String cardId = _card,
  String opId = 'op',
}) {
  return EditCardDescription(
    opId: opId,
    cardId: cardId,
    description: text,
    baseDescriptionVersion: base,
    actorId: DemoIds.elena,
  );
}

OpRejection _rejection(OpOutcome outcome) => (outcome as OpRejected).rejection;

void main() {
  group('submit EditCardDescription', () {
    test('a matching base is confirmed and applied', () async {
      final gateway = _gateway();
      final outcome = await gateway.submit(_edit('new text'));
      expect(outcome, isA<OpConfirmed>());
      final card = gateway.serverBoard.cardById(_card)!;
      expect(card.description, 'new text');
      expect(card.descriptionVersion, 2);
      expect(gateway.serverBoard.seq, 1285);
    });

    test('a stale base is a version_conflict with the last author', () async {
      final gateway = _gateway();
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'remote',
        actorId: DemoIds.anya,
      );
      final outcome = await gateway.submit(_edit('mine'));
      final rejection = _rejection(outcome);
      expect(rejection.reason, NackReason.versionConflict);
      expect(rejection.actorId, DemoIds.anya);
      expect(rejection.atSeq, 1285);
      expect(gateway.serverBoard.cardById(_card)!.description, 'remote');
    });

    test('the conflict actor falls back to the card author', () async {
      final gateway = _gateway();
      final stale = await gateway.submit(_edit('mine', base: 9));
      expect(_rejection(stale).actorId, DemoIds.maxim);
    });

    test('our own confirmed edit is the conflict author afterwards', () async {
      final gateway = _gateway();
      await gateway.submit(_edit('first'));
      final outcome = await gateway.submit(_edit('second', opId: 'op2'));
      expect(_rejection(outcome).actorId, DemoIds.elena);
    });

    test('a nack pushes the current card to subscribers', () async {
      final gateway = _gateway();
      final updates = <RemoteCardUpdate>[];
      final subscription = gateway.remoteUpdates.listen(updates.add);
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'remote',
        actorId: DemoIds.maxim,
      );
      await gateway.submit(_edit('mine'));
      expect(updates.length, 1);
      expect(updates.single.card.description, 'remote');
      expect(updates.single.card.descriptionVersion, 2);
      expect(updates.single.actorId, DemoIds.maxim);
      expect(updates.single.seq, 1285);
      await subscription.cancel();
    });

    test('a confirmed edit does not push anything', () async {
      final gateway = _gateway();
      final updates = <RemoteCardUpdate>[];
      final subscription = gateway.remoteUpdates.listen(updates.add);
      await gateway.submit(_edit('mine'));
      expect(updates, isEmpty);
      await subscription.cancel();
    });

    test('an unknown card is not found', () async {
      final gateway = _gateway();
      final outcome = await gateway.submit(_edit('x', cardId: 'zz'));
      expect(_rejection(outcome).reason, NackReason.notFound);
    });

    test('exactly 10 000 characters pass', () async {
      final gateway = _gateway();
      final outcome = await gateway.submit(
        _edit('x' * CardLimits.descriptionMaxLength),
      );
      expect(outcome, isA<OpConfirmed>());
      expect(
        gateway.serverBoard.cardById(_card)!.description.length,
        CardLimits.descriptionMaxLength,
      );
    });

    test('10 001 characters are a validation_error with the limit', () async {
      final gateway = _gateway();
      final original = gateway.serverBoard.cardById(_card)!.description;
      final outcome = await gateway.submit(
        _edit('x' * (CardLimits.descriptionMaxLength + 1)),
      );
      final rejection = _rejection(outcome);
      expect(rejection.reason, NackReason.validationError);
      expect(rejection.limit, 10000);
      expect(rejection.actorId, isNull);
      expect(gateway.serverBoard.cardById(_card)!.description, original);
    });
  });

  group('simulateRemoteDescriptionEdit', () {
    test('changes the server without delivering by default', () async {
      final gateway = _gateway();
      final updates = <RemoteCardUpdate>[];
      final subscription = gateway.remoteUpdates.listen(updates.add);
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'remote',
        actorId: DemoIds.anya,
      );
      final card = gateway.serverBoard.cardById(_card)!;
      expect(card.description, 'remote');
      expect(card.descriptionVersion, 2);
      expect(card.version, 15);
      expect(gateway.serverBoard.seq, 1285);
      expect(updates, isEmpty);
      await subscription.cancel();
    });

    test('delivers the updated card when asked', () async {
      final gateway = _gateway();
      final updates = <RemoteCardUpdate>[];
      final subscription = gateway.remoteUpdates.listen(updates.add);
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'remote',
        actorId: DemoIds.anya,
        deliver: true,
      );
      expect(updates.length, 1);
      expect(updates.single.card, gateway.serverBoard.cardById(_card));
      expect(updates.single.actorId, DemoIds.anya);
      expect(updates.single.seq, 1285);
      await subscription.cancel();
    });

    test('ignores unknown and archived cards', () async {
      final gateway = _gateway();
      final before = gateway.serverBoard;
      gateway.simulateRemoteDescriptionEdit(
        cardId: 'zz',
        text: 'x',
        actorId: DemoIds.anya,
        deliver: true,
      );
      expect(gateway.serverBoard, before);
      await gateway.submit(const ArchiveCard(opId: 'a', cardId: _card));
      final archived = gateway.serverBoard;
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'x',
        actorId: DemoIds.anya,
        deliver: true,
      );
      expect(gateway.serverBoard, archived);
    });

    test('two edits grow the version twice', () {
      final gateway = _gateway();
      for (final text in <String>['one', 'two']) {
        gateway.simulateRemoteDescriptionEdit(
          cardId: _card,
          text: text,
          actorId: DemoIds.anya,
        );
      }
      expect(gateway.serverBoard.cardById(_card)!.descriptionVersion, 3);
      expect(gateway.serverBoard.seq, 1286);
    });
  });

  group('dispose', () {
    test('closes the remote stream', () async {
      final gateway = _gateway();
      final done = Completer<void>();
      gateway.remoteUpdates.listen((_) {}, onDone: done.complete);
      await gateway.dispose();
      await done.future;
      expect(done.isCompleted, isTrue);
    });
  });
}
