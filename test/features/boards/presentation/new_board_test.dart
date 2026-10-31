import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cardo/features/boards/domain/board_info.dart';
import 'package:cardo/shared/widgets/cardo_buttons.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/pump_cardo_app.dart';

const String createKey = 'POST /api/boards';

Future<AppHandle> openForm(
  WidgetTester tester, {
  FakeServer? server,
  Variant variant = ruPhone,
}) async {
  final app = await pumpCardoApp(tester, server: server, variant: variant);
  final wide = variant.size.width > 840;
  if (wide) {
    await tester.tap(find.text(app.l10n.boardsNew));
  } else {
    await tester.tap(find.text(app.l10n.boardsNew));
  }
  await pumpFrames(tester, 6);
  return app;
}

Finder submit(AppHandle app) =>
    find.widgetWithText(CardoPrimaryButton, app.l10n.newBoardSubmit);

String titleText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText).last).controller.text;

void main() {
  group('layout without overflow', () {
    for (final variant in allVariants) {
      testWidgets('form opens for $variant', (tester) async {
        final app = await openForm(tester, variant: variant);

        expect(find.text(app.l10n.newBoardName), findsOneWidget);
        expect(submit(app), findsOneWidget);
        if (variant.size.width > 840) {
          expect(find.byType(Dialog), findsOneWidget);
        } else {
          expect(find.byType(BottomSheet), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('form with an error opens for $variant', (tester) async {
        final server = FakeServer()
          ..on(createKey, FakeResponse.error(400, 'validation_error'));
        final app = await openForm(tester, server: server, variant: variant);

        await tester.enterText(find.byType(TextFormField), 'Board');
        await tester.pump();
        await tester.tap(submit(app));
        await pumpFrames(tester, 3);

        expect(find.text(app.l10n.errorValidation), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('form with a validation message renders for $variant', (
        tester,
      ) async {
        final app = await openForm(tester, variant: variant);

        await tester.tap(submit(app));
        await pumpFrames(tester, 3);

        expect(find.text(app.l10n.newBoardRequired), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('validation', () {
    testWidgets('an empty title is rejected', (tester) async {
      final app = await openForm(tester);

      await tester.tap(submit(app));
      await pumpFrames(tester, 3);

      expect(find.text(app.l10n.newBoardRequired), findsOneWidget);
      expect(app.server.count(createKey), 0);
    });

    testWidgets('a blank title is rejected', (tester) async {
      final app = await openForm(tester);

      await tester.enterText(find.byType(TextFormField), '     ');
      await tester.tap(submit(app));
      await pumpFrames(tester, 3);

      expect(find.text(app.l10n.newBoardRequired), findsOneWidget);
      expect(app.server.count(createKey), 0);
    });

    testWidgets('one character is enough', (tester) async {
      final app = await openForm(tester);

      await tester.enterText(find.byType(TextFormField), 'A');
      await tester.tap(submit(app));
      await pumpFrames(tester, 4);

      expect(app.server.count(createKey), 1);
    });

    testWidgets('typing is capped at 200 characters', (tester) async {
      await openForm(tester);

      await tester.enterText(find.byType(TextFormField), 'x' * 260);
      await tester.pump();

      expect(titleText(tester).length, BoardLimits.titleMax);
    });

    testWidgets('exactly 200 characters are accepted and sent', (tester) async {
      final app = await openForm(tester);

      await tester.enterText(find.byType(TextFormField), 'x' * 200);
      await tester.tap(submit(app));
      await pumpFrames(tester, 4);

      expect(
        (app.server.requests(createKey).single.body['title'] as String).length,
        200,
      );
    });

    testWidgets('the counter follows the input', (tester) async {
      final app = await openForm(tester);

      await tester.enterText(find.byType(TextFormField), 'abcd');
      await tester.pump();

      expect(
        find.text(app.l10n.cardDescriptionCounter(4, 200)),
        findsOneWidget,
      );
    });
  });

  group('creating', () {
    testWidgets('sends the trimmed title and opens the new board', (
      tester,
    ) async {
      final app = await openForm(tester);

      await tester.enterText(find.byType(TextFormField), '  Sprint 12 ');
      await tester.tap(submit(app));
      await pumpFrames(tester, 8);

      expect(app.server.requests(createKey).single.body, <String, Object?>{
        'title': 'Sprint 12',
      });
      expect(app.location, '/boards/created-board');
      expect(find.byType(BottomSheet), findsNothing);
      expect(app.server.count('GET /api/boards/created-board'), 1);
    });

    testWidgets('on the desktop the dialog closes and the board opens', (
      tester,
    ) async {
      final app = await openForm(tester, variant: ruDesktop);

      await tester.enterText(find.byType(TextFormField), 'Desktop board');
      await tester.tap(submit(app));
      await pumpFrames(tester, 8);

      expect(app.location, '/boards/created-board');
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('the submit action on the keyboard creates', (tester) async {
      final app = await openForm(tester);

      await tester.enterText(find.byType(TextFormField), 'Kb');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await pumpFrames(tester, 8);

      expect(app.server.count(createKey), 1);
      expect(app.location, '/boards/created-board');
    });

    testWidgets('the list is refreshed after creation', (tester) async {
      final app = await openForm(tester);

      await tester.enterText(find.byType(TextFormField), 'Fresh');
      await tester.tap(submit(app));
      await pumpFrames(tester, 8);

      expect(app.server.count('GET /api/boards'), greaterThanOrEqualTo(2));
    });

    testWidgets('while sending: blocked button, one request, no closing', (
      tester,
    ) async {
      final server = FakeServer();
      final gate = server.gate(createKey);
      final app = await openForm(tester, server: server);

      await tester.enterText(find.byType(TextFormField), 'Slow');
      await tester.tap(submit(app));
      await pumpFrames(tester, 2);
      await tester.tap(sheetButton, warnIfMissed: false);
      await pumpFrames(tester, 2);

      expect(server.count(createKey), 1);
      expect(tester.widget<CardoPrimaryButton>(sheetButton).busy, isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byIcon(LucideIcons.x),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );

      gate.complete();
      await pumpFrames(tester, 8);

      expect(app.location, '/boards/created-board');
    });
  });

  group('failures keep the form open', () {
    final cases = <String, (FakeResponse, String Function(AppHandle))>{
      'validation_error': (
        FakeResponse.error(400, 'validation_error'),
        (app) => app.l10n.errorValidation,
      ),
      'rate_limited': (
        FakeResponse.error(
          429,
          'rate_limited',
          headers: <String, String>{'Retry-After': '20'},
        ),
        (app) => app.l10n.errorRateLimitedSeconds(20),
      ),
      'offline': (
        FakeResponse.network(DioExceptionType.connectionError),
        (app) => app.l10n.errorNetworkOffline,
      ),
      'server error': (
        FakeResponse.error(500, 'internal'),
        (app) => app.l10n.errorUnknown,
      ),
    };
    for (final entry in cases.entries) {
      testWidgets(entry.key, (tester) async {
        final server = FakeServer()..on(createKey, entry.value.$1);
        final app = await openForm(tester, server: server);

        await tester.enterText(find.byType(TextFormField), 'Keep me');
        await tester.tap(submit(app));
        await pumpFrames(tester, 4);

        expect(find.text(entry.value.$2(app)), findsOneWidget);
        expect(app.location, '/boards');
        expect(titleText(tester), 'Keep me');
        expect(
          tester.widget<CardoPrimaryButton>(submit(app)).onPressed,
          isNotNull,
        );
      });
    }

    testWidgets('editing clears the message and a retry can succeed', (
      tester,
    ) async {
      final server = FakeServer()
        ..on(createKey, FakeResponse.error(500, 'internal'));
      final app = await openForm(tester, server: server);
      await tester.enterText(find.byType(TextFormField), 'Try');
      await tester.tap(submit(app));
      await pumpFrames(tester, 4);
      expect(find.text(app.l10n.errorUnknown), findsOneWidget);

      server.clear(createKey);
      await tester.enterText(find.byType(TextFormField), 'Try again');
      await tester.pump();
      expect(find.text(app.l10n.errorUnknown), findsNothing);
      await tester.tap(submit(app));
      await pumpFrames(tester, 8);

      expect(app.location, '/boards/created-board');
    });
  });

  group('closing', () {
    testWidgets('the close button dismisses the sheet', (tester) async {
      final app = await openForm(tester);

      await tester.tap(find.byTooltip(app.l10n.commonClose));
      await pumpFrames(tester, 6);

      expect(find.byType(BottomSheet), findsNothing);
      expect(app.location, '/boards');
      expect(app.server.count(createKey), 0);
    });

    testWidgets('Cancel dismisses the desktop dialog', (tester) async {
      final app = await openForm(tester, variant: ruDesktop);

      await tester.tap(find.text(app.l10n.commonCancel));
      await pumpFrames(tester, 6);

      expect(find.byType(Dialog), findsNothing);
      expect(app.server.count(createKey), 0);
    });

    testWidgets('the compact sheet carries the owner note, the dialog not', (
      tester,
    ) async {
      final compact = await openForm(tester);
      expect(find.text(compact.l10n.newBoardNote), findsOneWidget);
    });

    testWidgets('the desktop dialog has no note', (tester) async {
      final app = await openForm(tester, variant: ruDesktop);

      expect(find.text(app.l10n.newBoardNote), findsNothing);
    });

    testWidgets('English texts', (tester) async {
      await openForm(tester, variant: enPhone);

      expect(find.text('New board'), findsWidgets);
      expect(find.text('Create board'), findsOneWidget);
    });
  });
}

final Finder sheetButton = find.descendant(
  of: find.byType(BottomSheet),
  matching: find.byType(CardoPrimaryButton),
);
