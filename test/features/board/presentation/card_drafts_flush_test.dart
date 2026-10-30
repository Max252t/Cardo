import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/domain/card_draft.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/card_drafts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';

const String _card = DemoIds.handshakeCard;
const String _other = DemoIds.rankCard;
const Duration _tick = Duration(milliseconds: 1);
const Duration _hold = Duration(milliseconds: 150);

ProviderContainer _open(ControlledGateway gateway) {
  final container = makeContainer(gateway: gateway);
  container.read(cardDraftsProvider);
  container.read(boardNotifierProvider);
  return container;
}

CardDraftsNotifier _drafts(ProviderContainer container) =>
    container.read(cardDraftsProvider.notifier);

CardDraft? _draft(ProviderContainer container, [String cardId = _card]) =>
    container.read(cardDraftsProvider)[cardId];

List<EditCardDescription> _descriptionCalls(
  ControlledGateway gateway, [
  String? cardId,
]) => [
  for (final call in gateway.calls)
    if (call.op is EditCardDescription &&
        (cardId == null || (call.op as EditCardDescription).cardId == cardId))
      call.op as EditCardDescription,
];

GatewayCall _lastDescriptionCall(ControlledGateway gateway) =>
    gateway.calls.lastWhere((call) => call.op is EditCardDescription);

void _flushBehindInFlightSave(
  ProviderContainer container, {
  String cardId = _card,
  String first = 'first',
  String second = 'first and more',
}) {
  _drafts(container).edit(cardId, first);
  _drafts(container).save(cardId);
  _drafts(container).edit(cardId, second);
  _drafts(container).flush(cardId);
}

void main() {
  group('a non-conflict nack on the description operation', () {
    testWidgets('clears the flush request and does not resend', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _flushBehindInFlightSave(container);
      expect(_draft(container)!.flushRequested, isTrue);
      expect(_descriptionCalls(gateway).length, 1);

      gateway.calls.single.completer.complete(
        const OpRejected(OpRejection(reason: NackReason.forbidden)),
      );
      await tester.pump(_tick);

      final draft = _draft(container)!;
      expect(draft.flushRequested, isFalse);
      expect(draft.submitted, isFalse);
      expect(draft.conflict, isFalse);
      expect(draft.text, 'first and more');

      await tester.pump(_hold);
      await tester.pump(_hold);

      expect(_descriptionCalls(gateway).length, 1);
      expect(container.read(boardNotifierProvider).rejected, isEmpty);
      expect(_draft(container)!.text, 'first and more');
      expect(_draft(container)!.flushRequested, isFalse);
      container.dispose();
    });

    for (final reason in <NackReason>[
      NackReason.forbidden,
      NackReason.notFound,
      NackReason.validationError,
      NackReason.rateLimited,
    ]) {
      testWidgets('${reason.name} keeps the draft and stops auto sending', (
        tester,
      ) async {
        final gateway = ControlledGateway();
        final container = _open(gateway);
        _flushBehindInFlightSave(container);
        gateway.calls.single.completer.complete(
          OpRejected(OpRejection(reason: reason)),
        );
        await tester.pump(_tick);
        await tester.pump(_hold);
        await tester.pump(_hold);

        expect(_descriptionCalls(gateway).length, 1);
        expect(_draft(container)!.flushRequested, isFalse);
        expect(_draft(container)!.text, 'first and more');
        container.dispose();
      });
    }

    testWidgets('new input afterwards can be saved again', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _flushBehindInFlightSave(container);
      gateway.calls.single.completer.complete(
        const OpRejected(OpRejection(reason: NackReason.forbidden)),
      );
      await tester.pump(_tick);
      await tester.pump(_hold);
      expect(_descriptionCalls(gateway).length, 1);

      _drafts(container).edit(_card, 'typed again');
      expect(_draft(container)!.flushRequested, isFalse);
      _drafts(container).save(_card);

      final calls = _descriptionCalls(gateway);
      expect(calls.length, 2);
      expect(calls.last.description, 'typed again');
      expect(_draft(container)!.submitted, isTrue);
      await tester.pump(_hold);
      container.dispose();
    });

    testWidgets('a repeated flush after the nack sends the text once more', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _flushBehindInFlightSave(container);
      gateway.calls.single.completer.complete(
        const OpRejected(OpRejection(reason: NackReason.forbidden)),
      );
      await tester.pump(_tick);
      await tester.pump(_hold);

      _drafts(container).flush(_card);

      final calls = _descriptionCalls(gateway);
      expect(calls.length, 2);
      expect(calls.last.description, 'first and more');
      await tester.pump(_hold);
      container.dispose();
    });

    testWidgets('a version conflict still produces a conflict', (tester) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _flushBehindInFlightSave(container);
      gateway.calls.single.completer.complete(
        const OpRejected(
          OpRejection(reason: NackReason.versionConflict, actorId: 'maxim'),
        ),
      );
      await tester.pump(_tick);

      final draft = _draft(container)!;
      expect(draft.conflict, isTrue);
      expect(draft.conflictActorId, 'maxim');
      expect(draft.text, 'first and more');
      expect(draft.submitted, isFalse);

      await tester.pump(_hold);
      await tester.pump(_hold);
      expect(_descriptionCalls(gateway).length, 1);
      expect(_draft(container)!.conflict, isTrue);
      container.dispose();
    });
  });

  group('auto sending of requested flushes', () {
    testWidgets('re-entrant reconciliation sends the draft exactly once', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      container
          .read(boardNotifierProvider.notifier)
          .moveCardToColumnEnd(cardId: _card, toColumnId: DemoIds.review);
      gateway.calls.single.completer.complete(
        const OpRejected(OpRejection(reason: NackReason.forbidden)),
      );
      await tester.pump(_tick);

      _drafts(container).edit(_card, 'typed while locked');
      _drafts(container).flush(_card);
      container
          .read(boardNotifierProvider.notifier)
          .editCardTitle(cardId: _other, title: 'Unrelated');
      await tester.pump(_tick);
      expect(_descriptionCalls(gateway), isEmpty);

      await tester.pump(_hold);
      expect(_descriptionCalls(gateway, _card).length, 1);
      expect(_draft(container)!.submitted, isTrue);
      expect(_draft(container)!.flushRequested, isFalse);

      container
          .read(boardNotifierProvider.notifier)
          .editCardTitle(cardId: _other, title: 'Unrelated again');
      await tester.pump(_tick);
      await tester.pump(_hold);
      expect(_descriptionCalls(gateway, _card).length, 1);
      container.dispose();
    });

    testWidgets('two drafts with a requested flush go out once each', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _flushBehindInFlightSave(container, cardId: _card);
      _flushBehindInFlightSave(
        container,
        cardId: _other,
        first: 'other first',
        second: 'other first and more',
      );
      expect(_descriptionCalls(gateway).length, 2);

      for (final call in gateway.calls.toList()) {
        call.completer.complete(const OpConfirmed(seq: 1285));
      }
      await tester.pump(_tick);

      expect(_descriptionCalls(gateway, _card).length, 2);
      expect(_descriptionCalls(gateway, _other).length, 2);
      expect(
        _descriptionCalls(gateway, _card).last.description,
        'first and more',
      );
      expect(
        _descriptionCalls(gateway, _other).last.description,
        'other first and more',
      );
      expect(_draft(container)!.submitted, isTrue);
      expect(_draft(container, _other)!.submitted, isTrue);

      await tester.pump(_hold);
      await tester.pump(_hold);
      expect(_descriptionCalls(gateway, _card).length, 2);
      expect(_descriptionCalls(gateway, _other).length, 2);
      container.dispose();
    });

    testWidgets('the flush flag returns when the operation is not created', (
      tester,
    ) async {
      final gateway = ControlledGateway(
        initial: demoBoardSnapshot(currentUserRole: BoardRole.viewer),
      );
      final container = ProviderContainer(
        overrides: [
          boardGatewayProvider.overrideWithValue(gateway),
          idGeneratorProvider.overrideWithValue(IdSequence().call),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 1, 1, 12)),
          canEditBoardProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      container.read(cardDraftsProvider);
      container.read(boardNotifierProvider);

      _drafts(container).edit(_card, 'kept for later');
      _drafts(container).flush(_card);

      final draft = _draft(container)!;
      expect(gateway.calls, isEmpty);
      expect(draft.flushRequested, isTrue);
      expect(draft.submitted, isFalse);
      expect(draft.text, 'kept for later');

      _drafts(container).save(_card);
      expect(gateway.calls, isEmpty);
      expect(_draft(container)!.text, 'kept for later');
      await tester.pump(_hold);
    });

    testWidgets('a confirmed save leaves no flush request behind', (
      tester,
    ) async {
      final gateway = ControlledGateway();
      final container = _open(gateway);
      _drafts(container).edit(_card, 'plain');
      _drafts(container).flush(_card);
      expect(_descriptionCalls(gateway).length, 1);
      expect(_draft(container)!.flushRequested, isFalse);
      _lastDescriptionCall(gateway).completer
          .complete(const OpConfirmed(seq: 1285));
      await tester.pump(_tick);
      await tester.pump(_hold);
      expect(_descriptionCalls(gateway).length, 1);
      expect(container.read(cardDraftsProvider), isEmpty);
      container.dispose();
    });
  });
}
