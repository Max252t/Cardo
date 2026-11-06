import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/board_fixtures.dart';
import '../helpers/pump_board.dart';
import '../helpers/pump_sheet.dart';

const Duration _age = Duration(days: 1);

class _Clock {
  _Clock(this.value);

  DateTime value;

  DateTime call() => value;

  void advance(Duration by) => value = value.add(by);
}

Future<_Clock> _pumpBoardWithClock(WidgetTester tester) async {
  tester.view.physicalSize = compactSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final snapshotNow = demoReferenceTime;
  final clock = _Clock(
    snapshotNow.subtract(_age).add(const Duration(seconds: 30)),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        boardGatewayProvider.overrideWithValue(
          FakeBoardGateway(
            initial: demoBoardSnapshot(now: snapshotNow),
            confirmDelay: confirmDelay,
          ),
        ),
        idGeneratorProvider.overrideWithValue(IdSequence().call),
        nowProvider.overrideWithValue(clock.call),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BoardScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return clock;
}

void main() {
  group('the card meta row while the sheet is open', () {
    testWidgets('moves from "just now" to "1 minute ago" on the tick', (
      tester,
    ) async {
      final clock = await _pumpBoardWithClock(tester);
      await openCardSheet(tester);
      expect(find.text('Создал Максим · только что'), findsOneWidget);

      clock.advance(const Duration(minutes: 1));
      await tester.pump(CardoDurations.nowTick);
      await tester.pump();

      expect(find.text('Создал Максим · только что'), findsNothing);
      expect(find.text('Создал Максим · 1 минуту назад'), findsOneWidget);

      clock.advance(const Duration(minutes: 1));
      await tester.pump(CardoDurations.nowTick);
      await tester.pump();
      expect(find.text('Создал Максим · 2 минуты назад'), findsOneWidget);

      await closeCardSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not change before the tick elapses', (tester) async {
      final clock = await _pumpBoardWithClock(tester);
      await openCardSheet(tester);

      clock.advance(const Duration(minutes: 1));
      await tester.pump(CardoDurations.nowTick - const Duration(seconds: 31));
      expect(find.text('Создал Максим · только что'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Создал Максим · 1 минуту назад'), findsOneWidget);

      await closeCardSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('leaves no timer behind once the sheet is closed', (
      tester,
    ) async {
      final clock = await _pumpBoardWithClock(tester);
      await openCardSheet(tester);
      expect(find.byType(CardSheet), findsOneWidget);

      await closeCardSheet(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(CardSheet), findsNothing);

      clock.advance(const Duration(minutes: 5));
      await tester.pump(CardoDurations.nowTick * 3);
      expect(tester.takeException(), isNull);
    });
  });

  group('tickingNowProvider', () {
    testWidgets('ticks while listened to and refreshes the value', (
      tester,
    ) async {
      final clock = _Clock(DateTime.utc(2026, 1, 1, 12));
      final container = ProviderContainer(
        overrides: [nowProvider.overrideWithValue(clock.call)],
      );
      addTearDown(container.dispose);
      final seen = <DateTime>[];
      final subscription = container.listen<DateTime>(
        tickingNowProvider,
        (previous, next) => seen.add(next),
        fireImmediately: true,
      );

      expect(seen, [DateTime.utc(2026, 1, 1, 12)]);

      clock.advance(const Duration(minutes: 1));
      await tester.pump(CardoDurations.nowTick);
      expect(seen.last, DateTime.utc(2026, 1, 1, 12, 1));
      expect(seen.length, 2);

      clock.advance(const Duration(minutes: 1));
      await tester.pump(CardoDurations.nowTick);
      expect(seen.last, DateTime.utc(2026, 1, 1, 12, 2));
      expect(seen.length, 3);

      subscription.close();
      await tester.pump();
      clock.advance(const Duration(minutes: 10));
      await tester.pump(CardoDurations.nowTick * 3);
      expect(seen.length, 3);
    });

    for (final start in <DateTime>[
      DateTime.utc(2026, 1, 1, 12),
      DateTime.utc(2026, 1, 1, 12, 0, 30),
      DateTime.utc(2026, 1, 1, 12, 0, 59, 999),
    ]) {
      testWidgets('aligns the first tick to the minute from ${start.second}.'
          '${start.millisecond}', (tester) async {
        final clock = _Clock(start);
        final container = ProviderContainer(
          overrides: [nowProvider.overrideWithValue(clock.call)],
        );
        addTearDown(container.dispose);
        final seen = <DateTime>[];
        final subscription = container.listen<DateTime>(
          tickingNowProvider,
          (previous, next) => seen.add(next),
          fireImmediately: true,
        );
        final toBoundary =
            CardoDurations.nowTick -
            Duration(seconds: start.second, milliseconds: start.millisecond);
        const millisecond = Duration(milliseconds: 1);

        clock.advance(toBoundary);
        await tester.pump(toBoundary - millisecond);
        expect(seen.length, 1);
        await tester.pump(millisecond);
        expect(seen.length, 2);
        expect(seen.last.second, 0);
        expect(seen.last.millisecond, 0);

        clock.advance(CardoDurations.nowTick);
        await tester.pump(CardoDurations.nowTick - millisecond);
        expect(seen.length, 2);
        await tester.pump(millisecond);
        expect(seen.length, 3);

        subscription.close();
        await tester.pump();
        await tester.pump(millisecond);
      });
    }

    testWidgets('keeps one pending timer at a time and frees it', (
      tester,
    ) async {
      final clock = _Clock(DateTime.utc(2026, 1, 1, 12));
      final container = ProviderContainer(
        overrides: [nowProvider.overrideWithValue(clock.call)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen<DateTime>(
        tickingNowProvider,
        (previous, next) {},
      );
      await tester.pump(CardoDurations.nowTick);
      await tester.pump(CardoDurations.nowTick);
      subscription.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
