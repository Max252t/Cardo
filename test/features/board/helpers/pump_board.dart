import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/features/board/data/board_gateway.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_fixtures.dart';

const Size compactSize = Size(375, 812);
const Size mediumSize = Size(700, 900);
const Size expandedSize = Size(1280, 800);

const Duration confirmDelay = Duration(milliseconds: 200);

Future<void> pumpBoard(
  WidgetTester tester, {
  Size size = compactSize,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool disableAnimations = false,
  BoardRole role = BoardRole.editor,
  BoardGateway? gateway,
  RejectPolicy? rejectWhen,
  Duration delay = confirmDelay,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final board =
      gateway ??
      FakeBoardGateway(
        initial: demoBoardSnapshot(currentUserRole: role),
        confirmDelay: delay,
        rejectWhen: rejectWhen,
      );
  final ids = IdSequence();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        boardGatewayProvider.overrideWithValue(board),
        idGeneratorProvider.overrideWithValue(ids.call),
        nowProvider.overrideWithValue(() => demoReferenceTime),
      ],
      child: MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme: brightness == Brightness.light
            ? buildLightTheme()
            : buildDarkTheme(),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, app) {
          final data = MediaQuery.of(context);
          return MediaQuery(
            data: data.copyWith(
              disableAnimations: disableAnimations,
              textScaler: TextScaler.linear(textScale),
            ),
            child: Directionality(textDirection: textDirection, child: app!),
          );
        },
        home: const BoardScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

ProviderContainer containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(BoardScreen)));
}

Future<void> settleBoard(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 600),
]) async {
  await tester.pump(duration);
  await tester.pump(duration);
}
