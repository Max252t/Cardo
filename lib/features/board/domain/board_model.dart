import 'package:flutter/foundation.dart';

import '../../../core/models/board_role.dart';
import '../../../core/ranking/rank.dart';

enum ColumnMarker { backlog, inProgress, review, done }

abstract final class CardLimits {
  static const int titleMaxLength = 500;
  static const int descriptionMaxLength = 10000;
}

@immutable
class BoardMember {
  const BoardMember({
    required this.userId,
    required this.name,
    required this.avatarColor,
    required this.role,
  });

  final String userId;
  final String name;
  final String avatarColor;
  final BoardRole role;

  BoardMember copyWith({
    String? userId,
    String? name,
    String? avatarColor,
    BoardRole? role,
  }) {
    return BoardMember(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarColor: avatarColor ?? this.avatarColor,
      role: role ?? this.role,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BoardMember &&
        other.userId == userId &&
        other.name == name &&
        other.avatarColor == avatarColor &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(userId, name, avatarColor, role);

  @override
  String toString() => 'BoardMember($userId, $name, ${role.wireName})';
}

@immutable
class ColumnModel {
  const ColumnModel({
    required this.id,
    required this.title,
    required this.rank,
    required this.version,
    required this.marker,
  });

  final String id;
  final String title;
  final String rank;
  final int version;
  final ColumnMarker marker;

  ColumnModel copyWith({
    String? id,
    String? title,
    String? rank,
    int? version,
    ColumnMarker? marker,
  }) {
    return ColumnModel(
      id: id ?? this.id,
      title: title ?? this.title,
      rank: rank ?? this.rank,
      version: version ?? this.version,
      marker: marker ?? this.marker,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ColumnModel &&
        other.id == id &&
        other.title == title &&
        other.rank == rank &&
        other.version == version &&
        other.marker == marker;
  }

  @override
  int get hashCode => Object.hash(id, title, rank, version, marker);

  @override
  String toString() => 'ColumnModel($id, $title, $rank, v$version)';
}

@immutable
class CardModel {
  const CardModel({
    required this.id,
    required this.columnId,
    required this.title,
    required this.rank,
    required this.createdBy,
    required this.updatedBy,
    this.description = '',
    this.version = 1,
    this.descriptionVersion = 1,
    this.archived = false,
  });

  final String id;
  final String columnId;
  final String title;
  final String description;
  final String rank;
  final int version;
  final int descriptionVersion;
  final String createdBy;
  final String updatedBy;
  final bool archived;

  bool get hasDescription => description.trim().isNotEmpty;

  CardModel copyWith({
    String? id,
    String? columnId,
    String? title,
    String? description,
    String? rank,
    int? version,
    int? descriptionVersion,
    String? createdBy,
    String? updatedBy,
    bool? archived,
  }) {
    return CardModel(
      id: id ?? this.id,
      columnId: columnId ?? this.columnId,
      title: title ?? this.title,
      description: description ?? this.description,
      rank: rank ?? this.rank,
      version: version ?? this.version,
      descriptionVersion: descriptionVersion ?? this.descriptionVersion,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      archived: archived ?? this.archived,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CardModel &&
        other.id == id &&
        other.columnId == columnId &&
        other.title == title &&
        other.description == description &&
        other.rank == rank &&
        other.version == version &&
        other.descriptionVersion == descriptionVersion &&
        other.createdBy == createdBy &&
        other.updatedBy == updatedBy &&
        other.archived == archived;
  }

  @override
  int get hashCode => Object.hash(
    id,
    columnId,
    title,
    description,
    rank,
    version,
    descriptionVersion,
    createdBy,
    updatedBy,
    archived,
  );

  @override
  String toString() => 'CardModel($id in $columnId @ $rank, v$version)';
}

@immutable
class BoardModel {
  BoardModel({
    required this.id,
    required this.title,
    required this.seq,
    required List<ColumnModel> columns,
    required List<CardModel> cards,
    required List<BoardMember> members,
  }) : columns = List<ColumnModel>.unmodifiable(columns),
       cards = List<CardModel>.unmodifiable(cards),
       members = List<BoardMember>.unmodifiable(members);

  final String id;
  final String title;
  final int seq;
  final List<ColumnModel> columns;
  final List<CardModel> cards;
  final List<BoardMember> members;

  List<ColumnModel> get orderedColumns {
    final sorted = List<ColumnModel>.of(columns)
      ..sort((a, b) => compareRanks(a.rank, b.rank));
    return sorted;
  }

  List<CardModel> cardsIn(String columnId) {
    final list =
        cards
            .where((card) => card.columnId == columnId && !card.archived)
            .toList()
          ..sort((a, b) {
            final byRank = compareRanks(a.rank, b.rank);
            return byRank != 0 ? byRank : a.id.compareTo(b.id);
          });
    return list;
  }

  CardModel? cardById(String id) {
    for (final card in cards) {
      if (card.id == id) {
        return card;
      }
    }
    return null;
  }

  ColumnModel? columnById(String id) {
    for (final column in columns) {
      if (column.id == id) {
        return column;
      }
    }
    return null;
  }

  BoardMember? memberById(String userId) {
    for (final member in members) {
      if (member.userId == userId) {
        return member;
      }
    }
    return null;
  }

  BoardModel copyWith({
    String? id,
    String? title,
    int? seq,
    List<ColumnModel>? columns,
    List<CardModel>? cards,
    List<BoardMember>? members,
  }) {
    return BoardModel(
      id: id ?? this.id,
      title: title ?? this.title,
      seq: seq ?? this.seq,
      columns: columns ?? this.columns,
      cards: cards ?? this.cards,
      members: members ?? this.members,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BoardModel &&
        other.id == id &&
        other.title == title &&
        other.seq == seq &&
        listEquals(other.columns, columns) &&
        listEquals(other.cards, cards) &&
        listEquals(other.members, members);
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    seq,
    Object.hashAll(columns),
    Object.hashAll(cards),
    Object.hashAll(members),
  );

  @override
  String toString() =>
      'BoardModel($id, seq $seq, ${columns.length} columns, '
      '${cards.length} cards)';
}
