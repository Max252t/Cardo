import 'package:cardo/core/models/board_role.dart';
import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/network/api_policy.dart';
import 'package:cardo/core/network/dio_factory.dart';
import 'package:cardo/features/boards/data/dio_boards_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/api_json.dart';
import '../../../helpers/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter adapter;
  late DioBoardsApi api;

  void serve(FakeResponse response) {
    adapter = FakeHttpAdapter((options) => response);
    api = DioBoardsApi(
      createDio(Uri.parse('http://api.test'), adapter: adapter),
    );
  }

  group('listBoards', () {
    test('GET /api/boards and maps every board with its role', () async {
      serve(
        FakeResponse.ok(
          boardListJson(<Map<String, Object?>>[
            boardJson(role: 'owner'),
            boardJson(id: 'b2', title: 'Two', role: 'viewer'),
          ]),
        ),
      );

      final result = await api.listBoards();

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, ApiPaths.boards);
      expect(result.valueOrNull?.map((b) => b.role), <BoardRole>[
        BoardRole.owner,
        BoardRole.viewer,
      ]);
    });

    test('an empty list is a success', () async {
      serve(FakeResponse.ok(boardListJson(const [])));

      expect((await api.listBoards()).valueOrNull, isEmpty);
    });

    test('a malformed body is unknown', () async {
      serve(FakeResponse.ok(<String, Object?>{'boards': 5}));

      expect((await api.listBoards()).failureOrNull, const UnknownFailure());
    });

    test('errors are typed', () async {
      serve(FakeResponse.error(500, 'internal'));
      expect(
        (await api.listBoards()).failureOrNull,
        const UnknownFailure(statusCode: 500, code: 'internal'),
      );

      serve(FakeResponse.network(DioExceptionType.connectionError));
      expect(
        (await api.listBoards()).failureOrNull,
        const NetworkFailure(NetworkFailureKind.offline),
      );

      serve(
        FakeResponse.error(
          429,
          'rate_limited',
          headers: <String, String>{'Retry-After': '5'},
        ),
      );
      expect(
        (await api.listBoards()).failureOrNull,
        const RateLimitedFailure(retryAfter: Duration(seconds: 5)),
      );
    });
  });

  group('createBoard', () {
    test('POST /api/boards with the title and maps the 201 Board', () async {
      serve(FakeResponse.ok(boardJson(title: 'New', seq: 0), status: 201));

      final result = await api.createBoard('New');

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.body, <String, Object?>{'title': 'New'});
      expect(result.valueOrNull?.title, 'New');
      expect(result.valueOrNull?.role, BoardRole.owner);
    });

    test('validation errors are typed', () async {
      serve(FakeResponse.error(400, 'validation_error', message: 'too long'));

      expect(
        (await api.createBoard('x')).failureOrNull,
        const ValidationFailure(message: 'too long'),
      );
    });

    test('payload_too_large is a validation failure', () async {
      serve(FakeResponse.error(413, 'payload_too_large'));

      expect(
        (await api.createBoard('x')).failureOrNull,
        isA<ValidationFailure>(),
      );
    });
  });

  group('getBoard', () {
    test(
      'GET /api/boards/{id} with an encoded id and maps the snapshot',
      () async {
        serve(FakeResponse.ok(snapshotJson()));

        final result = await api.getBoard('a/b');

        expect(adapter.requests.single.path, '/api/boards/a%2Fb');
        expect(result.valueOrNull?.model.columns, hasLength(3));
        expect(result.valueOrNull?.info.seq, 7);
      },
    );

    test('404 and 410 are typed', () async {
      serve(FakeResponse.error(404, 'not_found'));
      expect((await api.getBoard('x')).failureOrNull, const NotFoundFailure());

      serve(FakeResponse.error(410, 'gone'));
      expect((await api.getBoard('x')).failureOrNull, const GoneFailure());
    });

    test('400 for a non-uuid id is a validation failure', () async {
      serve(FakeResponse.error(400, 'validation_error'));

      expect(
        (await api.getBoard('not-a-uuid')).failureOrNull,
        isA<ValidationFailure>(),
      );
    });

    test('a broken snapshot is unknown', () async {
      serve(FakeResponse.ok(<String, Object?>{'board': 1}));

      expect((await api.getBoard('x')).failureOrNull, const UnknownFailure());
    });
  });
}
