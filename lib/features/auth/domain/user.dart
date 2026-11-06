class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarColor,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String avatarColor;
  final DateTime createdAt;

  User copyWith({String? displayName, String? avatarColor}) {
    return User(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarColor: avatarColor ?? this.avatarColor,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.displayName == displayName &&
        other.avatarColor == avatarColor &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, email, displayName, avatarColor, createdAt);

  @override
  String toString() => 'User($id)';
}
