import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/board/domain/board_model.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/gateway_probe.dart';

const String _card = DemoIds.handshakeCard;

Future<(FakeBoardGateway, GatewayProbe)> _open() async {
  final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
  final probe = GatewayProbe(gateway);
  await probe.settle();
  addTearDown(probe.dispose);
  return (gateway, probe);
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

void main() {
  group('EditCardDescription over the protocol', () {
    test('a matching base is confirmed and applied', () async {
      final (gateway, probe) = await _open();
      await probe.send(_edit('new text'));
      final event = probe.events.single as CardEditedEvent;
      expect(event.description, 'new text');
      expect(event.descriptionVersion, 2);
      final card = gateway.serverBoard.cardById(_card)!;
      expect(card.description, 'new text');
      expect(card.descriptionVersion, 2);
      expect(gateway.serverBoard.seq, 1285);
    });

    test('a stale base is a version_conflict at the current seq', () async {
      final (gateway, probe) = await _open();
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'remote',
        actorId: DemoIds.anya,
      );
      await probe.send(_edit('mine'));
      final rejection = probe.nacks.single.rejection;
      expect(rejection.reason, NackReason.versionConflict);
      expect(rejection.atSeq, 1285);
      expect(gateway.serverBoard.cardById(_card)!.description, 'remote');
    });

    test('a nack delivers the held remote edit first', () async {
      final (gateway, probe) = await _open();
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'remote',
        actorId: DemoIds.maxim,
      );
      await probe.send(_edit('mine'));
      final remote = probe.events.single as CardEditedEvent;
      expect(remote.description, 'remote');
      expect(remote.descriptionVersion, 2);
      expect(remote.actorId, DemoIds.maxim);
      expect(remote.seq, 1285);
    });

    test('a confirmed edit does not deliver anything else', () async {
      final (_, probe) = await _open();
      await probe.send(_edit('mine'));
      expect(probe.events.length, 1);
      expect(probe.nacks, isEmpty);
    });

    test('an unknown card is not found', () async {
      final (_, probe) = await _open();
      await probe.send(_edit('x', cardId: 'zz'));
      expect(probe.nacks.single.rejection.reason, NackReason.notFound);
    });

    test('exactly 10 000 characters pass', () async {
      final (gateway, probe) = await _open();
      await probe.send(_edit('x' * CardLimits.descriptionMaxLength));
      expect(probe.events.single, isA<CardEditedEvent>());
      expect(
        gateway.serverBoard.cardById(_card)!.description.length,
        CardLimits.descriptionMaxLength,
      );
    });

    test('10 001 characters are a validation_error', () async {
      final (gateway, probe) = await _open();
      final original = gateway.serverBoard.cardById(_card)!.description;
      await probe.send(_edit('x' * (CardLimits.descriptionMaxLength + 1)));
      expect(probe.nacks.single.rejection.reason, NackReason.validationError);
      expect(gateway.serverBoard.cardById(_card)!.description, original);
    });
  });

  group('simulateRemoteDescriptionEdit', () {
    test('changes the server without delivering by default', () async {
      final (gateway, probe) = await _open();
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'remote',
        actorId: DemoIds.anya,
      );
      await probe.settle();
      final card = gateway.serverBoard.cardById(_card)!;
      expect(card.description, 'remote');
      expect(card.descriptionVersion, 2);
      expect(card.version, 15);
      expect(gateway.serverBoard.seq, 1285);
      expect(probe.events, isEmpty);
    });

    test('delivers the edit when asked', () async {
      final (gateway, probe) = await _open();
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'remote',
        actorId: DemoIds.anya,
        deliver: true,
      );
      await probe.settle();
      final event = probe.events.single as CardEditedEvent;
      expect(event.actorId, DemoIds.anya);
      expect(event.seq, 1285);
      expect(event.description, 'remote');
    });

    test('ignores unknown and archived cards', () async {
      final (gateway, probe) = await _open();
      final before = gateway.serverBoard;
      gateway.simulateRemoteDescriptionEdit(
        cardId: 'zz',
        text: 'x',
        actorId: DemoIds.anya,
        deliver: true,
      );
      expect(gateway.serverBoard, before);
      await probe.send(const ArchiveCard(opId: 'a', cardId: _card));
      final archived = gateway.serverBoard;
      gateway.simulateRemoteDescriptionEdit(
        cardId: _card,
        text: 'x',
        actorId: DemoIds.anya,
        deliver: true,
      );
      expect(gateway.serverBoard, archived);
    });

    test('two edits grow the version twice', () async {
      final (gateway, _) = await _open();
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
    test('closes the signal stream', () async {
      final gateway = FakeBoardGateway(confirmDelay: Duration.zero);
      var done = false;
      gateway.signals.listen((_) {}, onDone: () => done = true);
      await gateway.dispose();
      await pumpEventQueue();
      expect(done, isTrue);
    });
  });
}
