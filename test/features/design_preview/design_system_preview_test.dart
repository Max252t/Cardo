import 'package:cardo/features/design_preview/design_system_preview.dart';
import 'package:cardo/main.dart';
import 'package:cardo/shared/widgets/card_tile.dart';
import 'package:cardo/shared/widgets/connection_pill.dart';
import 'package:cardo/shared/widgets/role_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sizes = <String, Size>{
  'mobile 375': Size(375, 812),
  'desktop 1280': Size(1280, 800),
};

void main() {
  for (final sizeEntry in _sizes.entries) {
    for (final brightness in Brightness.values) {
      for (final scale in <double>[1.0, 2.0]) {
        testWidgets(
          'preview ${sizeEntry.key} ${brightness.name} text x$scale',
          (tester) async {
            tester.view.physicalSize = sizeEntry.value;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              tester.platformDispatcher.clearAllTestValues();
            });

            await tester.pumpWidget(
              const CardoApp(home: DesignSystemPreview()),
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
            expect(find.text('Дизайн-система'), findsOneWidget);

            final scrollable = find.byType(Scrollable).first;
            for (var i = 0; i < 40; i++) {
              await tester.drag(scrollable, const Offset(0, -400));
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
            expect(find.byType(ConnectionPill), findsWidgets);
          },
        );
      }
    }
  }

  testWidgets('preview shows all component families', (tester) async {
    tester.view.physicalSize = const Size(1280, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const CardoApp(home: DesignSystemPreview()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CardTile), findsWidgets);
    expect(find.byType(ConnectionPill), findsWidgets);
    expect(find.byType(RoleBadge), findsWidgets);
    expect(find.text('Светлая тема'), findsOneWidget);
    expect(find.text('Тёмная тема'), findsOneWidget);
  });

  testWidgets('app uses russian locale and no-animation theme', (tester) async {
    await tester.pumpWidget(const CardoApp(home: DesignSystemPreview()));
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.themeAnimationStyle, AnimationStyle.noAnimation);
    expect(app.supportedLocales.map((l) => l.languageCode), contains('ru'));
  });
}
