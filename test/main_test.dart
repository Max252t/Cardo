import 'package:cardo/core/config/app_config.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/features/design_preview/design_system_preview.dart';
import 'package:cardo/main.dart';
import 'package:cardo/shared/providers/app_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({Widget? home}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(AppConfig.parse('')),
      boardGatewayProvider.overrideWithValue(
        FakeBoardGateway(
          initial: demoBoardSnapshot(),
          confirmDelay: Duration.zero,
        ),
      ),
    ],
    child: CardoApp(home: home),
  );
}

void main() {
  testWidgets('without a server address the config screen is shown', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Не задан адрес сервера'), findsOneWidget);
    expect(find.byType(BoardScreen), findsNothing);
    expect(find.text('Открыть демо-доску'), findsOneWidget);
  });

  testWidgets('the debug demo button opens the demo board', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открыть демо-доску'));
    await tester.pumpAndSettle();
    expect(find.byType(BoardScreen), findsOneWidget);
    expect(find.byType(DesignSystemPreview), findsNothing);
    expect(find.text('Запуск Cardo 1.0'), findsWidgets);
  });

  testWidgets('the design preview is still reachable as home', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(home: const DesignSystemPreview()));
    await tester.pump();
    expect(find.byType(DesignSystemPreview), findsOneWidget);
    expect(find.byType(BoardScreen), findsNothing);
  });

  testWidgets('both system themes build without errors', (tester) async {
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    for (final brightness in Brightness.values) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
