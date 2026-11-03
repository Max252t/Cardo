import '../../../core/models/board_role.dart';
import '../../../core/network/json_fields.dart';
import '../../board/data/realtime/event_codec.dart';
import '../../board/domain/board_event.dart';
import '../../board/domain/board_model.dart';
import '../domain/board_info.dart';

BoardRole _readRole(Map<String, dynamic> json, String key) {
  final role = BoardRole.tryParse(readString(json, key));
  if (role == null) {
    throw FormatException('Unknown role in "$key"');
  }
  return role;
}

BoardInfo boardInfoFromJson(Object? raw, {int? seq}) {
  final json = asJsonMap(raw, 'board');
  return BoardInfo(
    id: readNonEmptyString(json, 'id'),
    title: readString(json, 'title'),
    ownerId: readNonEmptyString(json, 'owner_id'),
    role: _readRole(json, 'role'),
    createdAt: readDate(json, 'created_at'),
    updatedAt: readDate(json, 'updated_at'),
    seq: seq ?? (json.containsKey('seq') ? readInt(json, 'seq') : null),
  );
}

List<BoardInfo> boardListFromJson(Object? raw) {
  final json = asJsonMap(raw, 'board list');
  return <BoardInfo>[
    for (final item in readObjectList(json, 'boards')) boardInfoFromJson(item),
  ];
}

ServerBoard serverBoardFromJson(Object? raw) {
  final json = asJsonMap(raw, 'snapshot');
  final seq = readInt(json, 'seq');
  final info = boardInfoFromJson(json['board'], seq: seq);
  final columns = withColumnMarkers(<ColumnModel>[
    for (final item in readObjectList(json, 'columns'))
      ColumnModel(
        id: readNonEmptyString(item, 'id'),
        title: readString(item, 'title'),
        rank: readNonEmptyString(item, 'rank'),
        version: readInt(item, 'version'),
        marker: ColumnMarker.backlog,
      ),
  ]);
  final cards = <CardModel>[
    for (final item in readObjectList(json, 'cards'))
      CardModel(
        id: readNonEmptyString(item, 'id'),
        columnId: readNonEmptyString(item, 'column_id'),
        title: readString(item, 'title'),
        description: readString(item, 'description'),
        rank: readNonEmptyString(item, 'rank'),
        version: readInt(item, 'version'),
        descriptionVersion: readInt(item, 'description_version'),
        createdBy: readNonEmptyString(item, 'created_by'),
        updatedBy: readNonEmptyString(item, 'updated_by'),
        createdAt: readDate(item, 'created_at'),
        updatedAt: readDate(item, 'updated_at'),
      ),
  ];
  final members = <BoardMember>[
    for (final item in readObjectList(json, 'members'))
      BoardMember(
        userId: readNonEmptyString(item, 'user_id'),
        name: readString(item, 'display_name'),
        avatarColor: _lenientColor(readString(item, 'avatar_color')),
        role: _readRole(item, 'role'),
      ),
  ];
  return ServerBoard(
    info: info,
    model: BoardModel(
      id: info.id,
      title: info.title,
      seq: seq,
      columns: columns,
      cards: cards,
      members: members,
    ),
  );
}

String _lenientColor(String value) {
  try {
    return normalizeAvatarColor(value);
  } on FormatException {
    return value;
  }
}

EventsPage eventsPageFromJson(Object? raw) {
  final json = asJsonMap(raw, 'events page');
  final events = <BoardEvent>[];
  for (final item in readObjectList(json, 'events')) {
    try {
      events.add(decodeEvent(item));
    } on FormatException {
      continue;
    }
  }
  return EventsPage(
    events: events,
    seq: readInt(json, 'seq'),
    hasMore: readBool(json, 'has_more'),
  );
}
