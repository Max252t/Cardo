import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/domain/board_sync_state.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:cardo/l10n/app_localizations_ru.dart';
import 'package:cardo/shared/widgets/conflict_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_board.dart';
import '../helpers/pump_sheet.dart';

const Locale _en = Locale('en');
const Locale _ru = Locale('ru');

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

Future<void> _moveRateLimit(WidgetTester tester) async {
  containerOf(tester)
      .read(boardNotifierProvider.notifier)
      .moveCard(cardId: 'c-rate-limit', toColumnId: DemoIds.review);
  await tester.pump(confirmDelay + const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final sizes = <String, Size>{
    'compact 375': compactSize,
    'medium 700': mediumSize,
    'expanded 1280': expandedSize,
  };
  final scales = <double>[1, 2];

  group('board in English', () {
    for (final size in sizes.entries) {
      for (final brightness in Brightness.values) {
        for (final scale in scales) {
          testWidgets(
            '${size.key} ${brightness.name} x$scale builds without errors',
            (tester) async {
              await pumpBoard(
                tester,
                size: size.value,
                brightness: brightness,
                textScale: scale,
                locale: _en,
              );
              expect(tester.takeException(), isNull);
              if (scale == 1) {
                expect(find.text('Add card'), findsWidgets);
              }
              expect(find.text('Добавить карточку'), findsNothing);
              await _finish(tester);
            },
          );
        }
      }
    }

    testWidgets('header shows the seq with an English thousands separator', (
      tester,
    ) async {
      await pumpBoard(tester, size: expandedSize, locale: _en);
      expect(find.text('seq 1,284'), findsWidgets);
      expect(find.text('seq 1 284'), findsNothing);
      await _finish(tester);
    });

    testWidgets('header keeps non-breaking spaces in Russian', (tester) async {
      await pumpBoard(tester, size: expandedSize, locale: _ru);
      expect(find.textContaining('seq 1'), findsWidgets);
      expect(find.text('seq 1,284'), findsNothing);
      await _finish(tester);
    });

    testWidgets('members dialog opens in English', (tester) async {
      await pumpBoard(tester, size: expandedSize, locale: _en);
      await tester.tap(find.text('Members'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Members'), findsNWidgets(2));
      expect(find.text('Участники'), findsNothing);
      await _finish(tester);
    });

    testWidgets('viewer banner names the owner', (tester) async {
      await pumpBoard(tester, role: BoardRole.viewer, locale: _en);
      expect(
        find.text(
          'You are a viewer: you can look but not edit. '
          'Access is managed by the owner, Максим.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add card'), findsNothing);
      await _finish(tester);
    });

    testWidgets('forbidden nack snackbar is in English', (tester) async {
      await pumpBoard(
        tester,
        locale: _en,
        rejectWhen: (op) => const OpRejection(reason: NackReason.forbidden),
      );
      await _moveRateLimit(tester);
      expect(
        find.text("You don't have permission to do that."),
        findsOneWidget,
      );
      await _finish(tester);
    });

    testWidgets('rejected card is labelled in English', (tester) async {
      await pumpBoard(
        tester,
        size: expandedSize,
        locale: _en,
        rejectWhen: (op) => const OpRejection(reason: NackReason.notFound),
      );
      await _moveRateLimit(tester);
      expect(find.text('The card is already archived.'), findsWidgets);
      expect(find.text('Not applied'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('internal nack retries and then gives the final message', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        locale: _en,
        rejectWhen: (op) => const OpRejection(reason: NackReason.internal),
      );
      await _moveRateLimit(tester);
      expect(find.text("Couldn't save. Trying again…"), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(confirmDelay + const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(confirmDelay + const Duration(milliseconds: 350));
      expect(find.text("Couldn't save the change."), findsOneWidget);
      await _finish(tester);
    });
  });

  group('card sheet in English', () {
    for (final size in sizes.entries) {
      for (final brightness in Brightness.values) {
        for (final scale in scales) {
          testWidgets(
            '${size.key} ${brightness.name} x$scale builds without errors',
            (tester) async {
              await pumpBoard(
                tester,
                size: size.value,
                brightness: brightness,
                textScale: scale,
                locale: _en,
              );
              await openCardSheet(tester);
              expect(find.byType(CardSheet), findsOneWidget);
              expect(
                find.text('Created by Максим · yesterday'),
                findsOneWidget,
              );
              expect(find.byTooltip('Close'), findsOneWidget);
              expect(tester.takeException(), isNull);
              await _finish(tester);
            },
          );
        }
      }
    }

    testWidgets('meta shows plural days for an older card', (tester) async {
      await pumpBoard(tester, locale: _en);
      await tester.tap(find.text('Rate limit на логин: 5 попыток в минуту'));
      await tester.pump();
      await tester.pump(sheetAnimation);
      await tester.pump(sheetAnimation);
      expect(find.text('Created by Елена · 2 days ago'), findsOneWidget);
      await _finish(tester);
    });

    testWidgets('counter uses English grouping', (tester) async {
      await pumpBoard(tester, locale: _en);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, 'abc');
      await tester.pump();
      expect(find.text('3 / 10,000'), findsOneWidget);
      expect(find.text('3 / 10 000'), findsNothing);
      await _finish(tester);
    });

    testWidgets('counter over the limit uses English grouping', (tester) async {
      await pumpBoard(tester, size: expandedSize, locale: _en);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, 'x' * 10001);
      await tester.pump();
      expect(find.text('10,001 / 10,000'), findsOneWidget);
      expect(
        find.text(
          'Description is too long: 10,000 characters maximum. '
          'Saving is unavailable.',
        ),
        findsOneWidget,
      );
      await _finish(tester);
    });

    testWidgets('counter keeps Russian grouping in ru', (tester) async {
      await pumpBoard(tester, locale: _ru);
      await openCardSheet(tester);
      await tester.enterText(descriptionField, 'abc');
      await tester.pump();
      expect(
        find.text(AppLocalizationsRu().cardDescriptionCounter(3, 10000)),
        findsOneWidget,
      );
      expect(find.text('3 / 10,000'), findsNothing);
      await _finish(tester);
    });

    testWidgets('conflict banner is in English', (tester) async {
      final gateway = fakeGateway();
      await pumpBoard(tester, gateway: gateway, locale: _en);
      await openCardSheet(tester);
      gateway.simulateRemoteDescriptionEdit(
        cardId: DemoIds.handshakeCard,
        text: 'theirs',
        actorId: DemoIds.maxim,
      );
      await tester.enterText(descriptionField, 'mine');
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      await tester.pump(sheetAnimation);
      await tester.pump(const Duration(milliseconds: 400));
      await openCardSheet(tester);

      expect(find.byType(ConflictBanner), findsOneWidget);
      expect(find.text('Максим changed the description'), findsOneWidget);
      expect(
        find.text(
          'Your draft is saved. Overwrite their version or discard your changes?',
        ),
        findsOneWidget,
      );
      expect(find.text('Overwrite'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });
  });
}
