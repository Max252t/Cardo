import 'package:flutter/foundation.dart';

@immutable
class AvatarIdentity {
  const AvatarIdentity({required this.name, required this.colorHex});

  final String name;
  final String colorHex;

  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  @override
  bool operator ==(Object other) {
    return other is AvatarIdentity &&
        other.name == name &&
        other.colorHex == colorHex;
  }

  @override
  int get hashCode => Object.hash(name, colorHex);
}
