import 'package:cardo/features/auth/domain/auth_validation.dart';
import 'package:cardo/features/boards/domain/board_info.dart';
import 'package:cardo/shared/widgets/cardo_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_server.dart';
import '../../../helpers/pump_cardo_app.dart';

const String emoji = '\u{1F600}';
const String createKey = 'POST /api/boards';

EditableText fieldAt(WidgetTester tester, int index) {
  return tester.widget<EditableText>(find.byType(EditableText).at(index));
}

String textAt(WidgetTester tester, int index) =>
    fieldAt(tester, index).controller.text;

void expectWholePairs(String text) {
  expect(String.fromCharCodes(text.runes), text);
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      expect(i + 1, lessThan(text.length), reason: 'lone high surrogate');
      final next = text.codeUnitAt(i + 1);
      expect(next >= 0xDC00 && next <= 0xDFFF, isTrue);
      i++;
    } else {
      expect(unit >= 0xDC00 && unit <= 0xDFFF, isFalse, reason: 'lone low');
    }
  }
}

void main() {
  group('registration name', () {
    Future<void> open(WidgetTester tester) {
      return pumpCardoApp(tester, signedIn: false, openLocation: '/register');
    }

    testWidgets('emoji are cut by runes exactly at the limit', (tester) async {
      await open(tester);

      await enterAt(tester, 0, emoji * 150);

      final text = textAt(tester, 0);
      expect(text.runes.length, AuthLimits.nameMax);
      expect(text.length, AuthLimits.nameMax * 2);
      expectWholePairs(text);
    });

    testWidgets('exactly the limit is kept untouched', (tester) async {
      await open(tester);

      await enterAt(tester, 0, emoji * AuthLimits.nameMax);

      expect(textAt(tester, 0), emoji * AuthLimits.nameMax);
    });

    testWidgets('a pair that would straddle the limit is dropped whole', (
      tester,
    ) async {
      await open(tester);

      await enterAt(tester, 0, '${'a' * 99}$emoji$emoji');

      final text = textAt(tester, 0);
      expect(text, '${'a' * 99}$emoji');
      expect(text.runes.length, AuthLimits.nameMax);
      expectWholePairs(text);
    });

    testWidgets('the cut text is what the server receives', (tester) async {
      final server = FakeServer();
      final app = await pumpCardoApp(
        tester,
        server: server,
        signedIn: false,
        openLocation: '/register',
      );

      await enterAt(tester, 0, emoji * 130);
      await enterAt(tester, 1, 'anna@example.com');
      await enterAt(tester, 2, 'secret-pass');
      await tester.ensureVisible(find.byType(CardoPrimaryButton));
      await tester.tap(find.byType(CardoPrimaryButton));
      await pumpFrames(tester, 4);

      final name =
          server
                  .requests('POST /api/auth/register')
                  .single
                  .body['display_name']!
              as String;
      expect(name, emoji * AuthLimits.nameMax);
      expect(app.location, '/boards');
    });
  });

  group('profile name', () {
    Future<AppHandle> open(WidgetTester tester) {
      return pumpCardoApp(
        tester,
        server: FakeServer()..user = userJson(displayName: 'Anna'),
        openLocation: '/profile',
      );
    }

    testWidgets('emoji are cut by runes exactly at the limit', (tester) async {
      await open(tester);

      await enterAt(tester, 0, emoji * 150);

      final text = textAt(tester, 0);
      expect(text.runes.length, AuthLimits.nameMax);
      expectWholePairs(text);
    });

    testWidgets('exactly the limit is kept untouched', (tester) async {
      await open(tester);

      await enterAt(tester, 0, emoji * AuthLimits.nameMax);

      expect(textAt(tester, 0), emoji * AuthLimits.nameMax);
    });

    testWidgets('a pair that would straddle the limit is dropped whole', (
      tester,
    ) async {
      await open(tester);

      await enterAt(tester, 0, '${'a' * 99}$emoji$emoji');

      expect(textAt(tester, 0), '${'a' * 99}$emoji');
    });

    testWidgets('the saved name is the cut one', (tester) async {
      final server = FakeServer();
      final app = await pumpCardoApp(
        tester,
        server: server,
        openLocation: '/profile',
      );

      await enterAt(tester, 0, emoji * 120);
      final save = find.widgetWithText(
        CardoPrimaryButton,
        app.l10n.profileSave,
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await pumpFrames(tester, 3);

      expect(
        server.requests('PATCH /api/me').single.body['display_name'],
        emoji * AuthLimits.nameMax,
      );
    });
  });

  group('board title in the dialog', () {
    for (final variant in const <Variant>[ruPhone, ruDesktop]) {
      Future<AppHandle> open(WidgetTester tester, {FakeServer? server}) async {
        final app = await pumpCardoApp(
          tester,
          server: server,
          variant: variant,
        );
        await tester.tap(find.text(app.l10n.boardsNew));
        await pumpFrames(tester, 6);
        return app;
      }

      Finder submit(AppHandle app) =>
          find.widgetWithText(CardoPrimaryButton, app.l10n.newBoardSubmit);

      testWidgets('emoji are cut by runes exactly at the limit on $variant', (
        tester,
      ) async {
        await open(tester);

        await tester.enterText(find.byType(TextFormField), emoji * 260);
        await tester.pump();

        final text = titleText(tester);
        expect(text.runes.length, BoardLimits.titleMax);
        expect(text.length, BoardLimits.titleMax * 2);
        expectWholePairs(text);
      });

      testWidgets('a straddling pair is dropped whole on $variant', (
        tester,
      ) async {
        await open(tester);

        await tester.enterText(
          find.byType(TextFormField),
          '${'a' * 199}$emoji$emoji',
        );
        await tester.pump();

        expect(titleText(tester), '${'a' * 199}$emoji');
      });

      testWidgets('the counter counts runes: 150 emoji is 150 of 200 on '
          '$variant', (tester) async {
        final app = await open(tester);

        await tester.enterText(find.byType(TextFormField), emoji * 150);
        await tester.pump();

        expect(
          find.text(app.l10n.cardDescriptionCounter(150, 200)),
          findsOneWidget,
        );
        expect(
          find.text(app.l10n.cardDescriptionCounter(300, 200)),
          findsNothing,
        );
      });

      testWidgets('the counter reaches 200 of 200 on the limit on $variant', (
        tester,
      ) async {
        final app = await open(tester);

        await tester.enterText(find.byType(TextFormField), emoji * 230);
        await tester.pump();

        expect(
          find.text(app.l10n.cardDescriptionCounter(200, 200)),
          findsOneWidget,
        );
      });

      testWidgets('200 emoji are accepted and sent on $variant', (
        tester,
      ) async {
        final server = FakeServer();
        final app = await open(tester, server: server);

        await tester.enterText(find.byType(TextFormField), emoji * 200);
        await tester.tap(submit(app));
        await pumpFrames(tester, 4);

        expect(
          server.requests(createKey).single.body['title'],
          emoji * BoardLimits.titleMax,
        );
      });

      testWidgets('too long text shows the error and sends nothing on '
          '$variant', (tester) async {
        final server = FakeServer();
        final app = await open(tester, server: server);

        await tester.enterText(find.byType(TextFormField), 'seed');
        titleController(tester).text = emoji * 201;
        await tester.pump();
        await tester.tap(submit(app));
        await pumpFrames(tester, 3);

        expect(
          find.text(app.l10n.fieldTooLong(BoardLimits.titleMax)),
          findsOneWidget,
        );
        expect(server.count(createKey), 0);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

TextEditingController titleController(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText).last).controller;

String titleText(WidgetTester tester) => titleController(tester).text;
