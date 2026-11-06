import 'dart:async';

import 'package:dio/dio.dart';

import 'api_json.dart';
import 'fake_http_adapter.dart';

class FakeServer {
  FakeServer() {
    adapter = FakeHttpAdapter(handle);
  }

  late final FakeHttpAdapter adapter;

  final DateTime now = t0.add(const Duration(hours: 2));

  Map<String, Object?> tokens({
    String access = 'access-1',
    String refresh = 'refresh-1',
    Map<String, Object?>? user,
  }) {
    return tokenJson(
      access: access,
      refresh: refresh,
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      refreshExpiresAt: now.add(const Duration(days: 30)),
      user: user,
    );
  }

  Map<String, Object?> user = userJson();
  List<Map<String, Object?>> boards = <Map<String, Object?>>[
    boardJson(title: 'Roadmap', role: 'owner'),
    boardJson(id: 'board-2', title: 'Design', role: 'editor'),
    boardJson(id: 'board-3', title: 'Archive', role: 'viewer'),
  ];

  final Map<String, FakeResponse Function(RequestOptions)> _overrides =
      <String, FakeResponse Function(RequestOptions)>{};
  final Map<String, Completer<void>> _gates = <String, Completer<void>>{};
  int _issued = 0;

  void on(String key, FakeResponse response) {
    _overrides[key] = (options) => response;
  }

  void onCall(String key, FakeResponse Function(RequestOptions) responder) {
    _overrides[key] = responder;
  }

  void clear(String key) {
    _overrides.remove(key);
  }

  Completer<void> gate(String key) {
    final completer = Completer<void>();
    _gates[key] = completer;
    return completer;
  }

  int count(String key) {
    return adapter.requests
        .where((request) => '${request.method} ${request.path}' == key)
        .length;
  }

  List<RecordedRequest> requests(String key) {
    return adapter.requests
        .where((request) => '${request.method} ${request.path}' == key)
        .toList();
  }

  Future<FakeResponse> handle(RequestOptions options) async {
    final key = '${options.method} ${options.path}';
    final gate = _gates[key];
    if (gate != null) {
      await gate.future;
    }
    final override = _overrides[key];
    if (override != null) {
      return override(options);
    }
    return _default(options, key);
  }

  FakeResponse _default(RequestOptions options, String key) {
    final body = options.data;
    switch (key) {
      case 'POST /api/auth/login':
        return FakeResponse.ok(tokens(user: user));
      case 'POST /api/auth/register':
        final payload = body as Map<String, dynamic>;
        user = <String, Object?>{
          ...user,
          'email': payload['email'],
          'display_name': payload['display_name'],
          if (payload['avatar_color'] != null)
            'avatar_color': payload['avatar_color'],
        };
        return FakeResponse.ok(tokens(user: user), status: 201);
      case 'POST /api/auth/refresh':
        _issued++;
        return FakeResponse.ok(
          tokens(access: 'access-r$_issued', refresh: 'refresh-r$_issued'),
        );
      case 'POST /api/auth/logout':
        return FakeResponse.empty(204);
      case 'GET /api/me':
        return FakeResponse.ok(user);
      case 'PATCH /api/me':
        final payload = body as Map<String, dynamic>;
        user = <String, Object?>{...user, ...payload};
        return FakeResponse.ok(user);
      case 'GET /api/boards':
        return FakeResponse.ok(boardListJson(boards));
      case 'POST /api/boards':
        final payload = body as Map<String, dynamic>;
        final created = boardJson(
          id: 'created-board',
          title: payload['title'] as String,
          seq: 0,
        );
        boards = <Map<String, Object?>>[created, ...boards];
        return FakeResponse.ok(created, status: 201);
    }
    final prefix = '${options.method} /api/boards/';
    if (key.startsWith('GET /api/boards/')) {
      final id = Uri.decodeComponent(key.substring(prefix.length));
      for (final board in boards) {
        if (board['id'] == id) {
          return FakeResponse.ok(
            snapshotJson(
              board: board,
              members: <Map<String, Object?>>[
                memberJson(
                  userId: user['id']! as String,
                  displayName: user['display_name']! as String,
                  role: board['role']! as String,
                ),
              ],
            ),
          );
        }
      }
      return FakeResponse.error(404, 'not_found');
    }
    return FakeResponse.error(404, 'not_found');
  }
}
