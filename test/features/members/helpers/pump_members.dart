import 'dart:async';

import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/network/dio_factory.dart';
import 'package:cardo/features/board/data/demo_board_fixture.dart';
import 'package:cardo/features/board/data/fake_board_gateway.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/board/presentation/board_screen.dart';
import 'package:cardo/features/board/presentation/widgets/board_header_actions.dart';
import 'package:cardo/features/members/data/dio_members_api.dart';
import 'package:cardo/features/members/presentation/members_providers.dart';
import 'package:cardo/l10n/app_localizations.dart';
import 'package:cardo/theme/cardo_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';

const Size compactSize = Size(375, 812);
const Size narrowSize = Size(360, 640);
const Size expandedSize = Size(1280, 800);

const String boardPath = '/api/boards/${DemoIds.board}';
const String membersPath = '$boardPath/members';
const String invitesPath = '$boardPath/invites';
const String anyaPath = '$membersPath/${DemoIds.anya}';

const String inviteToken = 'k7Qe2mVx9pLk7Qe2mVx9pLk7Qe2mVx9pL';

Map<String, Object?> inviteJson({
  String id = 'invite-1',
  String role = 'editor',
  int uses = 1,
  int maxUses = 5,
  String? token,
}) => <String, Object?>{
  'id': id,
  'role': role,
  'expires_at': iso(DateTime.utc(2026, 1, 15, 12).add(const Duration(days: 6))),
  'max_uses': maxUses,
  'uses': uses,
  'token': ?token,
};

Map<String, Object?> invitesJson(List<Map<String, Object?>> invites) =>
    <String, Object?>{'invites': invites};

class MembersRig {
  MembersRig(this.gateway, this.adapter, this.l10n, this.clipboard);

  final FakeBoardGateway gateway;
  final FakeHttpAdapter adapter;
  final AppLocalizations l10n;
  final List<String> clipboard;
  final Map<String, FutureOr<FakeResponse> Function(RequestOptions)> routes =
      <String, FutureOr<FakeResponse> Function(RequestOptions)>{};

  void on(String method, String path, FakeResponse response) {
    routes['$method $path'] = (options) => response;
  }

  Completer<void> hold(String method, String path, FakeResponse response) {
    final gate = Completer<void>();
    routes['$method $path'] = (options) async {
      await gate.future;
      return response;
    };
    return gate;
  }

  List<RecordedRequest> sent(String method, String path) => adapter.requests
      .where((r) => r.method == method && r.path == path)
      .toList();
}

Future<MembersRig> pumpMembers(
  WidgetTester tester, {
  Size size = compactSize,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  BoardRole role = BoardRole.owner,
  Locale locale = const Locale('ru'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final gateway = FakeBoardGateway(
    initial: demoBoardSnapshot(currentUserRole: role),
    confirmDelay: Duration.zero,
  );
  final clipboard = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<Object?, Object?>;
        clipboard.add(args['text']! as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  late MembersRig rig;
  final adapter = FakeHttpAdapter((options) {
    final route = rig.routes['${options.method} ${options.path}'];
    if (route != null) {
      return route(options);
    }
    if (options.method == 'GET' && options.path == invitesPath) {
      return FakeResponse.ok(invitesJson(const []));
    }
    return FakeResponse.error(404, 'not_found');
  });
  rig = MembersRig(gateway, adapter, lookupAppLocalizations(locale), clipboard);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        boardGatewayProvider.overrideWithValue(gateway),
        nowProvider.overrideWithValue(() => demoReferenceTime),
        membersApiProvider.overrideWithValue(
          DioMembersApi(
            createDio(Uri.parse('http://api.test'), adapter: adapter),
          ),
        ),
      ],
      child: MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme: brightness == Brightness.light
            ? buildLightTheme()
            : buildDarkTheme(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, app) {
          final data = MediaQuery.of(context);
          return MediaQuery(
            data: data.copyWith(textScaler: TextScaler.linear(textScale)),
            child: app!,
          );
        },
        home: const BoardScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return rig;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openMembers(WidgetTester tester, MembersRig rig) async {
  final width = tester.view.physicalSize.width;
  if (width >= 1000) {
    await tester.tap(find.byType(MembersButton));
  } else {
    await tester.tap(find.byTooltip(rig.l10n.boardMembers));
  }
  await settle(tester);
}

Future<void> enterEmail(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextFormField), text);
  await tester.pump();
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await settle(tester);
}
