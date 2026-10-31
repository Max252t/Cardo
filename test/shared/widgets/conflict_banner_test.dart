import 'package:cardo/shared/widgets/conflict_banner.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../helpers/pump_app.dart';

Widget _banner({VoidCallback? onOverwrite, VoidCallback? onCancel}) {
  return SizedBox(
    width: 340,
    child: ConflictBanner(
      title: 'Описание изменил Максим',
      text: 'Ваш черновик сохранён.',
      onOverwrite: onOverwrite ?? () {},
      onCancel: onCancel ?? () {},
    ),
  );
}

final Finder _overwrite = find.widgetWithText(FilledButton, 'Перезаписать');
final Finder _cancel = find.widgetWithText(OutlinedButton, 'Отменить');

void main() {
  testWidgets('shows title, text, icon and both actions', (tester) async {
    await pumpApp(tester, _banner());
    expect(find.text('Описание изменил Максим'), findsOneWidget);
    expect(find.text('Ваш черновик сохранён.'), findsOneWidget);
    expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
    expect(_overwrite, findsOneWidget);
    expect(_cancel, findsOneWidget);
  });

  testWidgets('callbacks fire', (tester) async {
    var overwritten = 0;
    var cancelled = 0;
    await pumpApp(
      tester,
      _banner(onOverwrite: () => overwritten++, onCancel: () => cancelled++),
    );
    await tester.tap(_overwrite);
    await tester.tap(_cancel);
    expect(overwritten, 1);
    expect(cancelled, 1);
  });

  testWidgets('buttons sit side by side at normal scale', (tester) async {
    await pumpApp(tester, _banner());
    expect(tester.getTopLeft(_overwrite).dy, tester.getTopLeft(_cancel).dy);
    expect(
      tester.getTopLeft(_cancel).dx,
      greaterThan(tester.getTopRight(_overwrite).dx),
    );
  });

  testWidgets('buttons stack at text scale 1.3 and above', (tester) async {
    for (final scale in <double>[1.3, 1.5, 2]) {
      await pumpApp(tester, _banner(), textScale: scale);
      expect(
        tester.getTopLeft(_cancel).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(_overwrite).dy),
        reason: 'scale $scale',
      );
      expect(
        tester.getTopLeft(_cancel).dx,
        tester.getTopLeft(_overwrite).dx,
        reason: 'scale $scale',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('buttons stay side by side just below 1.3', (tester) async {
    await pumpApp(tester, _banner(), textScale: 1.29);
    expect(
      tester.getTopLeft(_cancel).dx,
      greaterThan(tester.getTopRight(_overwrite).dx),
    );
  });

  testWidgets('both buttons are at least 44 tall and wide', (tester) async {
    for (final scale in <double>[1, 2]) {
      await pumpApp(tester, _banner(), textScale: scale);
      for (final finder in <Finder>[_overwrite, _cancel]) {
        final size = tester.getSize(finder);
        expect(size.height, greaterThanOrEqualTo(44), reason: 'scale $scale');
        expect(size.width, greaterThanOrEqualTo(44), reason: 'scale $scale');
      }
    }
  });

  testWidgets('is a live region with the combined label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, _banner());
    final node = tester.getSemantics(
      find.bySemanticsLabel('Описание изменил Максим. Ваш черновик сохранён.'),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('icon and text use the conflict tokens in both themes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await pumpApp(tester, _banner(), brightness: brightness);
      final colors = brightness == Brightness.light
          ? CardoColors.light
          : CardoColors.dark;
      expect(
        tester.widget<Icon>(find.byIcon(LucideIcons.triangleAlert)).color,
        colors.conflictIcon,
      );
      expect(
        tester.widget<Text>(find.text('Описание изменил Максим')).style!.color,
        colors.conflictTitle,
      );
      expect(
        tester.widget<Text>(find.text('Ваш черновик сохранён.')).style!.color,
        colors.conflictText,
      );
    }
  });

  testWidgets('narrow width at scale 2 does not overflow', (tester) async {
    await pumpApp(
      tester,
      SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: ConflictBanner(
            title: 'Описание изменил другой участник',
            text: 'Ваш черновик сохранён. Перезаписать его версией или отменить свои правки?',
            onOverwrite: () {},
            onCancel: () {},
          ),
        ),
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
