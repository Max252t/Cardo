import 'package:cardo/core/config/app_config.dart';
import 'package:cardo/features/auth/presentation/auth_providers.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/features/board/presentation/widgets/card_sheet.dart';
import 'package:cardo/main.dart';
import 'package:cardo/shared/providers/app_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/pump_cardo_app.dart';

void main() {
  group('card sheet on a server board', () {
    for (final size in const <Size>[Size(375, 812), Size(700, 900)]) {
      testWidgets('opens on tap at ${size.width.toInt()}px', (tester) async {
        final app = await pumpCardoApp(
          tester,
          variant: Variant(const Locale('ru'), size, 1),
          openLocation: '/boards/$boardId1',
        );

        await tester.tap(find.text('First').first);
        await pumpFrames(tester);

        expect(find.byType(CardSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(app.location, '/boards/$boardId1');
      });
    }
  });

  group('card sheet on the demo board', () {
    testWidgets('opens on tap', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.localesTestValue = const [Locale('ru')];
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appConfigProvider.overrideWithValue(AppConfig.parse(''))],
          child: const CardoApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Открыть демо-доску'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rate limit на логин: 5 попыток в минуту').first);
      await pumpFrames(tester);

      expect(find.byType(CardSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('board scope shares app providers', () {
    testWidgets('session, token manager and dio are the same instances', (
      tester,
    ) async {
      final app = await pumpCardoApp(tester, openLocation: '/boards/$boardId1');
      final inner = ProviderScope.containerOf(
        tester.element(find.byType(BoardScreen)),
      );

      expect(identical(inner, app.container), isFalse);
      expect(
        identical(
          inner.read(sessionProvider.notifier),
          app.container.read(sessionProvider.notifier),
        ),
        isTrue,
      );
      expect(
        identical(
          inner.read(tokenManagerProvider),
          app.container.read(tokenManagerProvider),
        ),
        isTrue,
      );
      expect(
        identical(inner.read(dioProvider), app.container.read(dioProvider)),
        isTrue,
      );
    });

    testWidgets('board providers stay scoped to the board', (tester) async {
      final app = await pumpCardoApp(tester, openLocation: '/boards/$boardId1');
      final inner = ProviderScope.containerOf(
        tester.element(find.byType(BoardScreen)),
      );

      expect(inner.read(boardViewProvider).id, boardId1);
      expect(() => app.container.read(boardGatewayProvider), throwsA(anything));
    });
  });
}
