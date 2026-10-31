final DateTime t0 = DateTime.utc(2026, 3, 1, 12);

const String annaId = '0190a1f2-0000-7000-8000-000000000001';
const String boardId1 = '0190a1f2-0000-7000-8000-0000000000b1';

String iso(DateTime value) => value.toUtc().toIso8601String();

Map<String, Object?> userJson({
  String id = annaId,
  String email = 'anna@example.com',
  String displayName = 'Anna',
  String avatarColor = '#7C3AED',
  DateTime? createdAt,
}) => <String, Object?>{
  'id': id,
  'email': email,
  'display_name': displayName,
  'avatar_color': avatarColor,
  'created_at': iso(createdAt ?? t0),
};

Map<String, Object?> tokenJson({
  String access = 'access-1',
  String refresh = 'refresh-1',
  DateTime? accessExpiresAt,
  DateTime? refreshExpiresAt,
  Map<String, Object?>? user,
}) => <String, Object?>{
  'token_type': 'Bearer',
  'access_token': access,
  'access_expires_at': iso(
    accessExpiresAt ?? t0.add(const Duration(minutes: 15)),
  ),
  'expires_in': 900,
  'refresh_token': refresh,
  'refresh_expires_at': iso(
    refreshExpiresAt ?? t0.add(const Duration(days: 30)),
  ),
  'user': ?user,
};

Map<String, Object?> boardJson({
  String id = boardId1,
  String title = 'Roadmap',
  String ownerId = annaId,
  int? seq = 7,
  String role = 'owner',
}) => <String, Object?>{
  'id': id,
  'title': title,
  'owner_id': ownerId,
  'seq': ?seq,
  'role': role,
  'created_at': iso(t0),
  'updated_at': iso(t0.add(const Duration(hours: 1))),
};

Map<String, Object?> columnJson({
  required String id,
  String title = 'Column',
  required String rank,
  int version = 1,
}) => <String, Object?>{
  'id': id,
  'title': title,
  'rank': rank,
  'version': version,
};

Map<String, Object?> cardJson({
  required String id,
  required String columnId,
  String title = 'Card',
  String description = '',
  String rank = 'V',
  int version = 1,
  int descriptionVersion = 1,
  String createdBy = annaId,
  String updatedBy = annaId,
}) => <String, Object?>{
  'id': id,
  'column_id': columnId,
  'title': title,
  'description': description,
  'rank': rank,
  'version': version,
  'description_version': descriptionVersion,
  'created_by': createdBy,
  'updated_by': updatedBy,
  'created_at': iso(t0),
  'updated_at': iso(t0.add(const Duration(minutes: 5))),
};

Map<String, Object?> memberJson({
  required String userId,
  String displayName = 'Member',
  String avatarColor = '#0EA5E9',
  String role = 'editor',
}) => <String, Object?>{
  'user_id': userId,
  'display_name': displayName,
  'avatar_color': avatarColor,
  'role': role,
  'joined_at': iso(t0),
};

Map<String, Object?> snapshotJson({
  Map<String, Object?>? board,
  List<Map<String, Object?>>? columns,
  List<Map<String, Object?>>? cards,
  List<Map<String, Object?>>? members,
  int seq = 7,
}) {
  final info = <String, Object?>{...(board ?? boardJson())}..remove('seq');
  return <String, Object?>{
    'board': info,
    'columns':
        columns ??
        <Map<String, Object?>>[
          columnJson(id: 'col-b', title: 'Done', rank: 'c'),
          columnJson(id: 'col-a', title: 'To do', rank: 'a'),
          columnJson(id: 'col-m', title: 'Doing', rank: 'b'),
        ],
    'cards':
        cards ??
        <Map<String, Object?>>[
          cardJson(id: 'card-1', columnId: 'col-a', title: 'First'),
        ],
    'members':
        members ??
        <Map<String, Object?>>[
          memberJson(userId: annaId, displayName: 'Anna', role: 'owner'),
        ],
    'seq': seq,
  };
}

Map<String, Object?> boardListJson(List<Map<String, Object?>> boards) =>
    <String, Object?>{'boards': boards};
