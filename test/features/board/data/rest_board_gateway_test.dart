import 'dart:async';

import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/network/api_policy.dart';
import 'package:cardo/core/network/dio_factory.dart';
import 'package:cardo/core/realtime/connection_status.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/board/data/rest_board_gateway.dart';
import 'package:cardo/features/board/domain/board_op.dart';
import 'package:cardo/features/board/domain/board_session.dart';
import 'package:cardo/features/board/presentation/board_providers.dart';
import 'package:cardo/features/boards/data/dio_boards_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';

const CurrentUser me = CurrentUser(
  userId: annaId,
  name: 'Anna',
  email: 'anna@example.com',
  avatarColor: '#7C3AED',
);

const String otherId = '0190a1f2-0000-7000-8000-000000000002';

class StubServer {
  StubServer({
    Map<String, Object?>? snapshot,
    Map<String, Object?>? list,
    this.snapshotResponse,
    this.listResponse,
  }) : snapshot = snapshot ?? snapshotJson(),
       list =
           list ??
           boardListJson(<Map<String, Object?>>[
             boardJson(id: 'other-board', title: 'Other', role: 'viewer'),
             boardJson(),
           ]) {
    adapter = FakeHttpAdapter(handle);
    dio = createDio(Uri.parse('http://api.test'), adapter: adapter);
    api = DioBoardsApi(dio);
  }

  final Map<String, Object?> snapshot;
  final Map<String, Object?> list;
  FakeResponse? snapshotResponse;
  FakeResponse? listResponse;
  FutureOr<void> Function()? onSnapshot;
  late final FakeHttpAdapter adapter;
  late final Dio dio;
  late final DioBoardsApi api;

  Future<FakeResponse> handle(RequestOptions options) async {
    if (options.path == ApiPaths.boards) {
      return listResponse ?? FakeResponse.ok(list);
    }
    await onSnapshot?.call();
    return snapshotResponse ?? FakeResponse.ok(snapshot);
  }

  Future<Result<RestBoardGateway, ApiFailure>> load({
    String id = boardId1,
    CurrentUser user = me,
  }) {
    return RestBoardGateway.load(api: api, boardId: id, currentUser: user);
  }
}

Future<RestBoardGateway> loaded(StubServer server) async {
  final result = await server.load();
  return (result as Success<RestBoardGateway, ApiFailure>).value;
}

void main() {
  group('load: mapping', () {
    test('maps columns, cards, seq and title from the snapshot', () async {
      final gateway = await loaded(StubServer());
      final snapshot = gateway.snapshot();

      expect(snapshot.board.id, boardId1);
      expect(snapshot.board.title, 'Roadmap');
      expect(snapshot.board.seq, 7);
      expect(snapshot.board.columns.map((c) => c.id), <String>[
        'col-a',
        'col-m',
        'col-b',
      ]);
      expect(snapshot.board.cards.single.id, 'card-1');
      expect(snapshot.currentUser, me);
    });

    test(
      'requests the snapshot of the right board with the encoded id',
      () async {
        final server = StubServer();

        await server.load(id: 'a b');

        expect(server.adapter.count('/api/boards/a%20b'), 1);
        expect(server.adapter.count(ApiPaths.boards), 1);
      },
    );

    test('starts offline with nobody online', () async {
      final snapshot = (await loaded(StubServer())).snapshot();

      expect(snapshot.connection, ConnectionStatus.offline);
      expect(snapshot.presence.onlineUserIds, isEmpty);
      expect(snapshot.presence.editingByCard, isEmpty);
    });

    test('the snapshot is stable between calls', () async {
      final gateway = await loaded(StubServer());

      expect(identical(gateway.snapshot(), gateway.snapshot()), isTrue);
    });
  });

  group('load: role and current member', () {
    for (final role in BoardRole.values) {
      test('the current member gets the role of board.role ($role)', () async {
        final server = StubServer(
          snapshot: snapshotJson(
            board: boardJson(role: role.wireName),
            members: <Map<String, Object?>>[
              memberJson(userId: annaId, role: 'owner'),
              memberJson(userId: otherId, role: 'editor'),
            ],
          ),
        );

        final snapshot = (await loaded(server)).snapshot();

        expect(snapshot.board.memberById(annaId)?.role, role);
        expect(snapshot.board.memberById(otherId)?.role, BoardRole.editor);
      });
    }

    test(
      'a missing current user is appended with the session identity',
      () async {
        final server = StubServer(
          snapshot: snapshotJson(
            board: boardJson(role: 'editor'),
            members: <Map<String, Object?>>[
              memberJson(userId: otherId, displayName: 'Bob', role: 'owner'),
            ],
          ),
        );

        final snapshot = (await loaded(server)).snapshot();

        expect(snapshot.board.members.map((m) => m.userId), <String>[
          otherId,
          annaId,
        ]);
        final added = snapshot.board.memberById(annaId)!;
        expect(added.name, 'Anna');
        expect(added.avatarColor, '#7C3AED');
        expect(added.role, BoardRole.editor);
      },
    );

    test('an empty member list still yields the current member', () async {
      final server = StubServer(
        snapshot: snapshotJson(
          board: boardJson(role: 'viewer'),
          members: const [],
        ),
      );

      final snapshot = (await loaded(server)).snapshot();

      expect(snapshot.board.members.single.userId, annaId);
      expect(snapshot.board.members.single.role, BoardRole.viewer);
    });

    test(
      'an existing current member keeps the server name and color',
      () async {
        final server = StubServer(
          snapshot: snapshotJson(
            members: <Map<String, Object?>>[
              memberJson(
                userId: annaId,
                displayName: 'Server Anna',
                avatarColor: '#0EA5E9',
                role: 'owner',
              ),
            ],
          ),
        );

        final member = (await loaded(server))
            .snapshot()
            .board
            .memberById(annaId)!;

        expect(member.name, 'Server Anna');
        expect(member.avatarColor, '#0EA5E9');
      },
    );

    test('a viewer cannot edit', () async {
      final server = StubServer(
        snapshot: snapshotJson(board: boardJson(role: 'viewer')),
      );

      final snapshot = (await loaded(server)).snapshot();

      expect(snapshot.board.memberById(annaId)?.role.canEdit, isFalse);
    });
  });

  group('load: boards list for the sidebar', () {
    test('lists every board of the user', () async {
      final snapshot = (await loaded(StubServer())).snapshot();

      expect(snapshot.boards.map((b) => b.id), <String>[
        'other-board',
        boardId1,
      ]);
      expect(snapshot.boards.map((b) => b.title), <String>['Other', 'Roadmap']);
    });

    test('a current board missing from the list is put first', () async {
      final server = StubServer(
        list: boardListJson(<Map<String, Object?>>[
          boardJson(id: 'other-board', title: 'Other'),
        ]),
      );

      final snapshot = (await loaded(server)).snapshot();

      expect(snapshot.boards.map((b) => b.id), <String>[
        boardId1,
        'other-board',
      ]);
    });

    test('a failing list does not break opening the board', () async {
      final server = StubServer(
        listResponse: FakeResponse.error(500, 'internal'),
      );

      final result = await server.load();

      expect(result.isSuccess, isTrue);
      final snapshot = result.valueOrNull!.snapshot();
      expect(snapshot.boards.map((b) => b.id), <String>[boardId1]);
      expect(snapshot.board.id, boardId1);
    });

    test(
      'a network failure on the list does not break opening either',
      () async {
        final server = StubServer(
          listResponse: FakeResponse.network(DioExceptionType.connectionError),
        );

        final result = await server.load();

        expect(result.isSuccess, isTrue);
      },
    );

    test('a malformed list does not break opening', () async {
      final server = StubServer(
        listResponse: FakeResponse.ok(<String, Object?>{'boards': 'oops'}),
      );

      final result = await server.load();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.snapshot().boards, hasLength(1));
    });

    test('both requests are issued before either finishes', () async {
      final server = StubServer();
      final gate = Completer<void>();
      server.onSnapshot = () => gate.future;

      final pending = server.load();
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(
        server.adapter.requests.map((r) => r.path),
        containsAll(<String>[ApiPaths.boards, ApiPaths.board(boardId1)]),
      );
      gate.complete();
      expect((await pending).isSuccess, isTrue);
    });
  });

  group('load: failures of the snapshot', () {
    test('404 is NotFoundFailure', () async {
      final server = StubServer(
        snapshotResponse: FakeResponse.error(404, 'not_found'),
      );

      final result = await server.load();

      expect(result.failureOrNull, const NotFoundFailure());
    });

    test('403 is ForbiddenFailure', () async {
      final server = StubServer(
        snapshotResponse: FakeResponse.error(403, 'forbidden'),
      );

      expect((await server.load()).failureOrNull, const ForbiddenFailure());
    });

    test('network errors are NetworkFailure', () async {
      for (final entry in <DioExceptionType, NetworkFailureKind>{
        DioExceptionType.connectionError: NetworkFailureKind.offline,
        DioExceptionType.connectionTimeout: NetworkFailureKind.timeout,
        DioExceptionType.receiveTimeout: NetworkFailureKind.timeout,
      }.entries) {
        final server = StubServer(
          snapshotResponse: FakeResponse.network(entry.key),
        );

        expect(
          (await server.load()).failureOrNull,
          NetworkFailure(entry.value),
        );
      }
    });

    test('a broken snapshot is UnknownFailure', () async {
      final server = StubServer(
        snapshotResponse: FakeResponse.ok(snapshotJson()..remove('columns')),
      );

      expect((await server.load()).failureOrNull, const UnknownFailure());
    });

    test('503 busy keeps Retry-After', () async {
      final server = StubServer(
        snapshotResponse: FakeResponse.error(
          503,
          'busy',
          headers: <String, String>{'Retry-After': '4'},
        ),
      );

      expect(
        (await server.load()).failureOrNull,
        const BusyFailure(retryAfter: Duration(seconds: 4)),
      );
    });

    test('a failed snapshot wins over a good list', () async {
      final server = StubServer(
        snapshotResponse: FakeResponse.error(404, 'not_found'),
      );

      final result = await server.load();

      expect(result.isSuccess, isFalse);
      expect(server.adapter.count(ApiPaths.boards), 1);
    });
  });

  group('offline behaviour', () {
    test('submit is unsupported and never reaches the network', () async {
      final server = StubServer();
      final gateway = await loaded(server);
      final before = server.adapter.requests.length;

      await expectLater(
        gateway.submit(
          const MoveCard(
            opId: 'op-1',
            cardId: 'card-1',
            toColumnId: 'col-b',
            baseVersion: 1,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(server.adapter.requests.length, before);
    });

    test('board edits stay queued and the connection stays offline', () async {
      final server = StubServer();
      final gateway = await loaded(server);
      final before = server.adapter.requests.length;
      final container = ProviderContainer(
        overrides: [boardGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final listener = container.listen(boardNotifierProvider, (_, _) {});
      addTearDown(listener.close);
      final notifier = container.read(boardNotifierProvider.notifier);

      notifier.createCard(columnId: 'col-a', title: 'New card');
      notifier.moveCardToColumnEnd(cardId: 'card-1', toColumnId: 'col-b');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(boardNotifierProvider);
      expect(state.connection, ConnectionStatus.offline);
      expect(state.pending, hasLength(2));
      expect(server.adapter.requests.length, before);
      expect(
        container.read(boardViewProvider).cardsIn('col-b').map((c) => c.id),
        contains('card-1'),
      );
    });

    test('a viewer cannot queue edits', () async {
      final server = StubServer(
        snapshot: snapshotJson(board: boardJson(role: 'viewer')),
      );
      final gateway = await loaded(server);
      final container = ProviderContainer(
        overrides: [boardGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final listener = container.listen(boardNotifierProvider, (_, _) {});
      addTearDown(listener.close);

      container
          .read(boardNotifierProvider.notifier)
          .createCard(columnId: 'col-a', title: 'Nope');

      expect(container.read(boardNotifierProvider).pending, isEmpty);
    });
  });

  group('buildSnapshot', () {
    test('is a pure mapping of its inputs', () async {
      final server = StubServer();
      final board = (await server.api.getBoard(boardId1)).valueOrNull!;
      final boards = (await server.api.listBoards()).valueOrNull!;

      final a = RestBoardGateway.buildSnapshot(
        board: board,
        boards: boards,
        currentUser: me,
      );
      final b = RestBoardGateway.buildSnapshot(
        board: board,
        boards: boards,
        currentUser: me,
      );

      expect(a, b);
    });
  });
}
