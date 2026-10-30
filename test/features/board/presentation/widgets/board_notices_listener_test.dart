import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/card_drafts.dart';
import 'package:cardo/features/board/presentation/widgets/board_notices_listener.dart';
import 'package:cardo/features/board/presentation/widgets/board_snackbar.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';
import '../../helpers/board_fixtures.dart';
import '../../helpers/pump_board.dart';

const String _card = DemoIds.handshakeCard;
const String _other = DemoIds.rankCard;
const String _third = DemoIds.readOnlyCard;
const String _archivedText = 'Карточка в архиве. Ваш текст не сохранён.';
const String _notFoundText = 'Карточка уже в архиве.';
const String _forbiddenText = 'Нет прав на это действие.';
const Duration _step = Duration(milliseconds: 100);

List<String> _mockClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add(
          (call.arguments as Map<Object?, Object?>)['text']! as String,
        );
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  var left = total;
  while (left > Duration.zero) {
    final chunk = left < _step ? left : _step;
    await tester.pump(chunk);
    left -= chunk;
  }
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 200; i++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
    await tester.pump(_step);
  }
}

Future<void> _copyCurrent(WidgetTester tester) async {
  await tester.tap(find.text('Скопировать'));
  await tester.pump();
  await _pumpFor(tester, const Duration(milliseconds: 800));
}

OpRejection? _rejectMoves(BoardOp op) {
  if (op is! MoveCard) {
    return null;
  }
  return OpRejection(
    reason: op.cardId == _third ? NackReason.forbidden : NackReason.notFound,
  );
}

void _loseDraft(ProviderContainer container, String cardId, String text) {
  container.read(cardDraftsProvider.notifier).edit(cardId, text);
  container.read(boardNotifierProvider.notifier).archiveCard(cardId);
}

void _rejectMove(ProviderContainer container, String cardId) {
  container
      .read(boardNotifierProvider.notifier)
      .moveCardToColumnEnd(cardId: cardId, toColumnId: DemoIds.review);
}

void main() {
  group('a rejection while a lost draft is on screen', () {
    testWidgets('does not push the draft out and shows itself afterwards', (
      tester,
    ) async {
      final copied = _mockClipboard(tester);
      await pumpBoard(tester, rejectWhen: _rejectMoves);
      final container = containerOf(tester);
      _loseDraft(container, _card, 'precious');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_archivedText), findsOneWidget);

      _rejectMove(container, _other);
      await _pumpFor(tester, const Duration(milliseconds: 600));

      expect(find.text(_archivedText), findsOneWidget);
      expect(find.text('Скопировать'), findsOneWidget);
      expect(find.text(_notFoundText), findsNothing);

      await _copyCurrent(tester);
      expect(copied, ['precious']);
      await _pumpUntil(tester, find.text(_notFoundText));
      expect(find.text(_notFoundText), findsOneWidget);
      expect(find.text(_archivedText), findsNothing);
      expect(container.read(lostDraftProvider), isEmpty);
      await _pumpFor(tester, const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('without lost drafts still replaces the current snackbar', (
      tester,
    ) async {
      await pumpBoard(tester, rejectWhen: _rejectMoves);
      final container = containerOf(tester);

      _rejectMove(container, _third);
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text(_forbiddenText), findsOneWidget);

      _rejectMove(container, _other);
      await _pumpFor(tester, const Duration(milliseconds: 800));
      expect(find.text(_forbiddenText), findsNothing);
      expect(find.text(_notFoundText), findsOneWidget);
      await _pumpFor(tester, const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('queues behind a draft that is waiting in the queue', (
      tester,
    ) async {
      _mockClipboard(tester);
      await pumpBoard(tester, rejectWhen: _rejectMoves);
      final container = containerOf(tester);
      _loseDraft(container, _card, 'first');
      _loseDraft(container, _third, 'second');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_archivedText), findsOneWidget);
      expect(container.read(lostDraftProvider), hasLength(2));

      _rejectMove(container, _other);
      await _pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text(_notFoundText), findsNothing);
      expect(find.text(_archivedText), findsOneWidget);

      await _copyCurrent(tester);
      expect(find.text(_archivedText), findsOneWidget);
      expect(find.text(_notFoundText), findsNothing);
      await _copyCurrent(tester);
      await _pumpUntil(tester, find.text(_notFoundText));
      expect(find.text(_notFoundText), findsOneWidget);
      await _pumpFor(tester, const Duration(seconds: 6));
    });
  });

  group('lifecycle of a lost draft record', () {
    testWidgets('stays past 10 s for a screen reader until copied', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final copied = _mockClipboard(tester);
      await pumpBoard(tester);
      final container = containerOf(tester);
      _loseDraft(container, _card, 'kept');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _pumpFor(tester, const Duration(seconds: 15));
      expect(find.text(_archivedText), findsOneWidget);
      expect(container.read(lostDraftProvider), hasLength(1));

      await _copyCurrent(tester);
      expect(copied, ['kept']);
      expect(container.read(lostDraftProvider), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays while the snackbar is on screen, goes after 10 s', (
      tester,
    ) async {
      _mockClipboard(tester);
      await pumpBoard(tester);
      final container = containerOf(tester);
      _loseDraft(container, _card, 'kept');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _pumpFor(tester, const Duration(seconds: 4));
      await _pumpFor(tester, const Duration(milliseconds: 700));
      expect(find.text(_archivedText), findsOneWidget);
      expect(container.read(lostDraftProvider), hasLength(1));

      await _pumpFor(tester, const Duration(seconds: 4));
      expect(find.text(_archivedText), findsOneWidget);
      expect(container.read(lostDraftProvider), hasLength(1));

      await _pumpFor(tester, const Duration(seconds: 3));
      expect(find.text(_archivedText), findsNothing);
      expect(container.read(lostDraftProvider), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is removed after the copy action', (tester) async {
      _mockClipboard(tester);
      await pumpBoard(tester);
      final container = containerOf(tester);
      _loseDraft(container, _card, 'copied');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(lostDraftProvider), hasLength(1));

      await _copyCurrent(tester);
      expect(container.read(lostDraftProvider), isEmpty);
      expect(find.text(_archivedText), findsNothing);
    });

    testWidgets('is removed when the snackbar is closed another way', (
      tester,
    ) async {
      _mockClipboard(tester);
      await pumpBoard(tester);
      final container = containerOf(tester);
      _loseDraft(container, _card, 'closed');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(lostDraftProvider), hasLength(1));

      ScaffoldMessenger.of(tester.element(find.text(_archivedText)))
          .hideCurrentSnackBar();
      await _pumpFor(tester, const Duration(milliseconds: 800));
      expect(container.read(lostDraftProvider), isEmpty);
    });

    testWidgets('records of queued drafts stay until their turn is over', (
      tester,
    ) async {
      _mockClipboard(tester);
      await pumpBoard(tester);
      final container = containerOf(tester);
      _loseDraft(container, _card, 'first');
      _loseDraft(container, _other, 'second');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _pumpFor(tester, const Duration(seconds: 5));
      expect(container.read(lostDraftProvider), hasLength(2));

      await _copyCurrent(tester);
      expect(container.read(lostDraftProvider), hasLength(1));
      expect(container.read(lostDraftProvider).single.text, 'second');
      expect(find.text(_archivedText), findsOneWidget);

      await _copyCurrent(tester);
      expect(container.read(lostDraftProvider), isEmpty);
    });
  });

  group('repeated listener calls', () {
    testWidgets('never show the same lost draft twice', (tester) async {
      final copied = _mockClipboard(tester);
      await pumpBoard(tester);
      final container = containerOf(tester);
      _loseDraft(container, _card, 'first');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _loseDraft(container, _other, 'second');
      await tester.pump();
      _loseDraft(container, _third, 'third');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _copyCurrent(tester);
      await _copyCurrent(tester);
      await _copyCurrent(tester);
      expect(copied, ['first', 'second', 'third']);
      await _pumpFor(tester, const Duration(seconds: 12));
      expect(find.text(_archivedText), findsNothing);
      expect(find.text('Скопировать'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('unmounting the listener', () {
    testWidgets('before the snackbar closes does not throw', (tester) async {
      final copied = _mockClipboard(tester);
      final container = makeContainer(gateway: ControlledGateway());
      container.read(boardNotifierProvider);
      addTearDown(container.dispose);
      final shown = ValueNotifier<bool>(true);
      addTearDown(shown.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: wrapApp(
            ValueListenableBuilder<bool>(
              valueListenable: shown,
              builder: (context, show, _) => show
                  ? const BoardNoticesListener(child: SizedBox())
                  : const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pump();

      container
          .read(lostDraftProvider.notifier)
          .report(
            const LostDraft(
              cardId: _card,
              text: 'left behind',
              reason: LostDraftReason.archived,
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(_archivedText), findsOneWidget);

      shown.value = false;
      await tester.pump();
      expect(find.byType(BoardNoticesListener), findsNothing);

      await _copyCurrent(tester);
      expect(copied, ['left behind']);
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('together with the whole app does not throw', (tester) async {
      final container = makeContainer(gateway: ControlledGateway());
      container.read(boardNotifierProvider);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: wrapApp(const BoardNoticesListener(child: SizedBox())),
        ),
      );
      await tester.pump();
      container
          .read(lostDraftProvider.notifier)
          .report(
            const LostDraft(
              cardId: _card,
              text: 'gone',
              reason: LostDraftReason.createRejected,
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 12));
      expect(tester.takeException(), isNull);
    });
  });

  group('LostDraftNotifier.remove', () {
    const first = LostDraft(
      cardId: 'a',
      text: 'one',
      reason: LostDraftReason.archived,
    );
    const second = LostDraft(
      cardId: 'b',
      text: 'two',
      reason: LostDraftReason.createRejected,
    );

    test('removes only one of several equal records', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(lostDraftProvider.notifier)
        ..report(first)
        ..report(second)
        ..report(first);

      notifier.remove(first);
      expect(container.read(lostDraftProvider), [second, first]);
      notifier.remove(first);
      expect(container.read(lostDraftProvider), [second]);
      notifier.remove(first);
      expect(container.read(lostDraftProvider), [second]);
    });

    test('ignores an unknown record without notifying', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(lostDraftProvider.notifier)
        ..report(first);
      var notifications = 0;
      container.listen<List<LostDraft>>(
        lostDraftProvider,
        (previous, next) => notifications++,
      );
      notifier.remove(second);
      expect(notifications, 0);
      expect(container.read(lostDraftProvider), [first]);
    });

    test('keeps the order of the rest', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const third = LostDraft(
        cardId: 'c',
        text: 'three',
        reason: LostDraftReason.archived,
      );
      container.read(lostDraftProvider.notifier)
        ..report(first)
        ..report(second)
        ..report(third)
        ..remove(second);
      expect(container.read(lostDraftProvider), [first, third]);
    });
  });

  group('showBoardSnackbar', () {
    testWidgets('returns null without a ScaffoldMessenger', (tester) async {
      ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? result;
      var called = false;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              if (!called) {
                called = true;
                result = showBoardSnackbar(context, message: 'nobody');
              }
              return const SizedBox();
            },
          ),
        ),
      );
      expect(called, isTrue);
      expect(result, isNull);
    });

    testWidgets('returns a controller and uses the default duration', (
      tester,
    ) async {
      await pumpApp(tester, const SizedBox());
      final context = tester.element(find.byType(Scaffold));
      final controller = showBoardSnackbar(context, message: 'default');
      expect(controller, isNotNull);
      await tester.pump();
      await _pumpFor(tester, const Duration(seconds: 3));
      expect(find.text('default'), findsOneWidget);
      await _pumpFor(tester, const Duration(seconds: 2));
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('default'), findsNothing);
      expect(CardoDurations.snackbar, const Duration(seconds: 4));
    });

    testWidgets('honours a custom duration', (tester) async {
      await pumpApp(tester, const SizedBox());
      final context = tester.element(find.byType(Scaffold));
      final controller = showBoardSnackbar(
        context,
        message: 'long',
        duration: const Duration(seconds: 9),
      )!;
      final closed = <SnackBarClosedReason>[];
      controller.closed.then(closed.add);
      await tester.pump();
      await _pumpFor(tester, const Duration(seconds: 7));
      expect(find.text('long'), findsOneWidget);
      expect(closed, isEmpty);
      await _pumpFor(tester, const Duration(seconds: 3));
      expect(find.text('long'), findsNothing);
      expect(closed, [SnackBarClosedReason.timeout]);
    });

    testWidgets(
      'a snackbar with an action closes on timeout without a screen reader',
      (tester) async {
        await pumpApp(tester, const SizedBox());
        final context = tester.element(find.byType(Scaffold));
        final closed = <SnackBarClosedReason>[];
        showBoardSnackbar(
          context,
          message: 'with action',
          actionLabel: 'Do',
          onAction: () {},
          duration: const Duration(seconds: 2),
        )!.closed.then(closed.add);
        await tester.pump();
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(find.text('with action'), findsOneWidget);
        await _pumpFor(tester, const Duration(seconds: 3));
        expect(find.text('with action'), findsNothing);
        expect(closed, [SnackBarClosedReason.timeout]);
      },
    );

    testWidgets('a snackbar with an action stays for a screen reader', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpApp(tester, const SizedBox());
      final context = tester.element(find.byType(Scaffold));
      final closed = <SnackBarClosedReason>[];
      showBoardSnackbar(
        context,
        message: 'with action',
        actionLabel: 'Do',
        onAction: () {},
        duration: const Duration(seconds: 2),
      )!.closed.then(closed.add);
      await tester.pump();
      await _pumpFor(tester, const Duration(seconds: 6));
      expect(find.text('with action'), findsOneWidget);
      expect(closed, isEmpty);
    });

    testWidgets('a shorter duration closes earlier than the default', (
      tester,
    ) async {
      await pumpApp(tester, const SizedBox());
      final context = tester.element(find.byType(Scaffold));
      showBoardSnackbar(
        context,
        message: 'short',
        duration: const Duration(seconds: 1),
      );
      await tester.pump();
      await _pumpFor(tester, const Duration(seconds: 3));
      expect(find.text('short'), findsNothing);
    });
  });
}
