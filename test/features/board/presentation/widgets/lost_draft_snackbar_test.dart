import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/card_drafts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_board.dart';

const String _card = DemoIds.handshakeCard;
const String _other = DemoIds.rankCard;
const String _archivedText = 'Карточка в архиве. Ваш текст не сохранён.';
const String _createRejectedText =
    'Карточку не удалось создать. Ваш текст не сохранён.';

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

Future<void> _dismissCurrent(WidgetTester tester) async {
  await tester.tap(find.text('Скопировать'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _waitForQueuedSnackbar(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    if (find.text('Скопировать').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<String> _createRejectedCard(
  WidgetTester tester,
  ProviderContainer container,
  String text,
) async {
  container
      .read(boardNotifierProvider.notifier)
      .createCard(columnId: DemoIds.backlog, title: 'Fresh $text');
  await tester.pump();
  final card = container
      .read(boardViewProvider)
      .cards
      .firstWhere((card) => card.title == 'Fresh $text');
  container.read(cardDraftsProvider.notifier).edit(card.id, text);
  return card.id;
}

OpRejection? _rejectCreates(BoardOp op) =>
    op is CreateCard ? const OpRejection(reason: NackReason.forbidden) : null;

void main() {
  group('a draft lost to a rejected create', () {
    testWidgets('is reported with its reason and offered for copying', (
      tester,
    ) async {
      final copied = _mockClipboard(tester);
      await pumpBoard(tester, rejectWhen: _rejectCreates);
      final container = containerOf(tester);
      final cardId = await _createRejectedCard(tester, container, 'my words');
      expect(container.read(cardDraftsProvider)[cardId]!.text, 'my words');

      final reported = <LostDraft>[];
      container.listen<List<LostDraft>>(lostDraftProvider, (previous, next) {
        reported.addAll(next);
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Нет прав на это действие.'), findsOneWidget);
      await _waitForQueuedSnackbar(tester);

      expect(container.read(cardDraftsProvider), isEmpty);
      expect(reported, [
        LostDraft(
          cardId: cardId,
          text: 'my words',
          reason: LostDraftReason.createRejected,
        ),
      ]);
      expect(container.read(lostDraftProvider), hasLength(1));
      expect(find.text(_createRejectedText), findsOneWidget);
      expect(find.text(_archivedText), findsNothing);
      expect(find.text('Скопировать'), findsOneWidget);

      await tester.tap(find.text('Скопировать'));
      await tester.pump();
      expect(copied, ['my words']);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });

  group('a draft lost to an archived card', () {
    testWidgets('shows the archive text, not the create text', (tester) async {
      final copied = _mockClipboard(tester);
      await pumpBoard(tester);
      final container = containerOf(tester);
      container.read(cardDraftsProvider.notifier).edit(_card, 'precious');
      container.read(boardNotifierProvider.notifier).archiveCard(_card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(_archivedText), findsOneWidget);
      expect(find.text(_createRejectedText), findsNothing);

      await tester.tap(find.text('Скопировать'));
      await tester.pump();
      expect(copied, ['precious']);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });

  group('two lost drafts in a row', () {
    testWidgets('are shown one after another and copy their own text', (
      tester,
    ) async {
      final copied = _mockClipboard(tester);
      await pumpBoard(tester);
      final container = containerOf(tester);
      container.read(cardDraftsProvider.notifier)
        ..edit(_card, 'first words')
        ..edit(_other, 'second words');
      container.read(boardNotifierProvider.notifier)
        ..archiveCard(_card)
        ..archiveCard(_other);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(lostDraftProvider), hasLength(2));
      expect(find.text(_archivedText), findsOneWidget);
      expect(find.text('Скопировать'), findsOneWidget);

      await _dismissCurrent(tester);
      expect(copied, ['first words']);
      expect(find.text(_archivedText), findsOneWidget);
      expect(find.text('Скопировать'), findsOneWidget);

      await _dismissCurrent(tester);
      expect(copied, ['first words', 'second words']);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text(_archivedText), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('of different reasons keep their own messages', (tester) async {
      final copied = _mockClipboard(tester);
      await pumpBoard(tester, rejectWhen: _rejectCreates);
      final container = containerOf(tester);
      await _createRejectedCard(tester, container, 'created words');
      await tester.pump(const Duration(milliseconds: 300));
      await _waitForQueuedSnackbar(tester);
      expect(find.text(_createRejectedText), findsOneWidget);

      container.read(cardDraftsProvider.notifier).edit(_card, 'archived words');
      container.read(boardNotifierProvider.notifier).archiveCard(_card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_createRejectedText), findsOneWidget);
      expect(find.text(_archivedText), findsNothing);
      expect(container.read(lostDraftProvider), hasLength(2));

      await _dismissCurrent(tester);
      expect(copied, ['created words']);
      expect(find.text(_archivedText), findsOneWidget);
      expect(find.text(_createRejectedText), findsNothing);

      await _dismissCurrent(tester);
      expect(copied, ['created words', 'archived words']);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });
}
