enum BoardRole {
  owner('owner'),
  editor('editor'),
  viewer('viewer');

  const BoardRole(this.wireName);

  final String wireName;

  bool get canEdit => this != BoardRole.viewer;

  bool get canManageMembers => this == BoardRole.owner;

  static BoardRole? tryParse(String? value) {
    for (final role in values) {
      if (role.wireName == value) {
        return role;
      }
    }
    return null;
  }
}
