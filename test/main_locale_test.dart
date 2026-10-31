import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester, List<Locale> locales) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = locales;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        boardGatewayProvider.overrideWithValue(
          FakeBoardGateway(
            initial: demoBoardSnapshot(),
            confirmDelay: Duration.zero,
          ),
        ),
      ],
      child: const CardoApp(),
    ),
  );
  await tester.pump();
}

void main() {
  group('CardoApp follows the system locale', () {
    testWidgets('en-US gives English', (tester) async {
      await _pumpApp(tester, const [Locale('en', 'US')]);
      expect(find.text('Add card'), findsWidgets);
      expect(find.text('Добавить карточку'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unsupported language gives English', (tester) async {
      await _pumpApp(tester, const [Locale('de')]);
      expect(find.text('Add card'), findsWidgets);
      expect(find.text('Добавить карточку'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ru-RU gives Russian', (tester) async {
      await _pumpApp(tester, const [Locale('ru', 'RU')]);
      expect(find.text('Добавить карточку'), findsWidgets);
      expect(find.text('Add card'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the first supported language of the list is used', (
      tester,
    ) async {
      await _pumpApp(tester, const [Locale('de'), Locale('ru')]);
      expect(find.text('Добавить карточку'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the app locale is exposed to the widget tree', (tester) async {
      await _pumpApp(tester, const [Locale('en', 'GB')]);
      final context = tester.element(find.byType(Scaffold).first);
      expect(Localizations.localeOf(context).languageCode, 'en');
    });
  });
}
