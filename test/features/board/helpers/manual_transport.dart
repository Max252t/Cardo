import 'dart:async';
import 'dart:convert';

import 'package:cardo/core/network/api_failure.dart';
import 'package:cardo/core/result/result.dart';
import 'package:cardo/features/board/data/realtime/board_catch_up.dart';
import 'package:cardo/features/board/data/realtime/realtime_transport.dart';
import 'package:cardo/features/board/domain/board_event.dart';
import 'package:cardo/features/boards/data/boards_dto.dart';
import 'package:cardo/features/boards/domain/board_info.dart';

class ManualChannel implements RealtimeChannel {
  final StreamController<String> _incoming = StreamController<String>();
  final List<String> sent = <String>[];
  int? _closeCode;
  String? _closeReason;
  bool closedByClient = false;
  int? clientCloseCode;
  bool throwOnSend = false;

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  List<Map<String, dynamic>> get sentMessages => <Map<String, dynamic>>[
    for (final text in sent) jsonDecode(text) as Map<String, dynamic>,
  ];

  List<String> get sentTypes => <String>[
    for (final message in sentMessages) message['type'] as String,
  ];

  @override
  void send(String text) {
    if (throwOnSend) {
      throw StateError('closed');
    }
    sent.add(text);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closedByClient = true;
    clientCloseCode = code;
    if (!_incoming.isClosed) {
      unawaited(_incoming.close());
    }
  }

  void push(String text) => _incoming.add(text);

  void pushJson(Map<String, Object?> message) => push(jsonEncode(message));

  void pushError(Object error) => _incoming.addError(error);

  void serverClose(int? code, [String? reason]) {
    _closeCode = code;
    _closeReason = reason;
    unawaited(_incoming.close());
  }
}

class ManualTransport implements RealtimeTransport {
  final List<ManualChannel> channels = <ManualChannel>[];
  final List<Uri> uris = <Uri>[];
  final List<Map<String, String>> headers = <Map<String, String>>[];
  Object? failWith;
  int failures = 0;
  Completer<ManualChannel>? gate;

  ManualChannel get last => channels.last;

  @override
  Future<RealtimeChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    uris.add(uri);
    this.headers.add(headers);
    if (failures > 0) {
      failures--;
      throw failWith ?? Exception('refused');
    }
    final pending = gate;
    final channel = pending == null ? ManualChannel() : await pending.future;
    channels.add(channel);
    return channel;
  }
}

Map<String, Object?> serverMessage(
  String type, [
  Map<String, Object?> payload = const <String, Object?>{},
]) {
  return <String, Object?>{'v': 1, 'type': type, 'payload': payload};
}

class StubCatchUp implements BoardCatchUpSource {
  final List<Result<EventsPage, ApiFailure>> eventResults =
      <Result<EventsPage, ApiFailure>>[];
  final List<Result<ServerBoard, ApiFailure>> boardResults =
      <Result<ServerBoard, ApiFailure>>[];
  final List<int> eventRequests = <int>[];
  int boardRequests = 0;
  Result<EventsPage, ApiFailure>? eventFallback;
  Result<ServerBoard, ApiFailure>? boardFallback;

  @override
  Future<Result<EventsPage, ApiFailure>> getEvents(
    String boardId,
    int afterSeq,
  ) async {
    eventRequests.add(afterSeq);
    if (eventResults.isNotEmpty) {
      return eventResults.removeAt(0);
    }
    return eventFallback ??
        Success<EventsPage, ApiFailure>(
          EventsPage(
            events: const <BoardEvent>[],
            seq: afterSeq,
            hasMore: false,
          ),
        );
  }

  @override
  Future<Result<ServerBoard, ApiFailure>> getBoard(String boardId) async {
    boardRequests++;
    if (boardResults.isNotEmpty) {
      return boardResults.removeAt(0);
    }
    return boardFallback ??
        const Failure<ServerBoard, ApiFailure>(
          NetworkFailure(NetworkFailureKind.offline),
        );
  }
}

Map<String, Object?> snapshotJson({int seq = 20, String title = 'Snap'}) {
  return <String, Object?>{
    'board': <String, Object?>{
      'id': 'board',
      'title': title,
      'owner_id': 'u1',
      'role': 'editor',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    },
    'columns': <Object?>[
      <String, Object?>{'id': 'col-a', 'title': 'A', 'rank': 'V', 'version': 1},
    ],
    'cards': <Object?>[],
    'members': <Object?>[
      <String, Object?>{
        'user_id': 'u1',
        'display_name': 'One',
        'avatar_color': '#2D68F5',
        'role': 'editor',
        'joined_at': '2026-01-01T00:00:00Z',
      },
    ],
    'seq': seq,
  };
}

Success<ServerBoard, ApiFailure> stubBoard({int seq = 20}) {
  return Success<ServerBoard, ApiFailure>(
    serverBoardFromJson(snapshotJson(seq: seq)),
  );
}

Success<EventsPage, ApiFailure> stubPage(
  List<BoardEvent> events, {
  bool hasMore = false,
}) {
  return Success<EventsPage, ApiFailure>(
    EventsPage(
      events: events,
      seq: events.isEmpty ? 0 : events.last.seq,
      hasMore: hasMore,
    ),
  );
}
