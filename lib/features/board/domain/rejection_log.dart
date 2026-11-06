import '../../../core/equality/collection_equality.dart';
import 'board_model.dart';
import 'board_op.dart';
import 'op_rejection.dart';

enum RejectedOpKind {
  move,
  create,
  editTitle,
  editDescription,
  archive,
  createColumn,
  renameColumn,
  moveColumn,
  archiveColumn,
}

enum DropCause { stale, targetGone }

class RejectedOp {
  const RejectedOp({
    required this.opId,
    required this.kind,
    this.cardId,
    this.subject,
    this.destination,
    this.rejection,
    this.dropCause,
    this.actorId,
    this.copyText = '',
  });

  final String opId;
  final RejectedOpKind kind;
  final String? cardId;
  final String? subject;
  final String? destination;
  final OpRejection? rejection;
  final DropCause? dropCause;
  final String? actorId;
  final String copyText;

  bool get dropped => dropCause != null;

  RejectedOp withActor(String actor) {
    return RejectedOp(
      opId: opId,
      kind: kind,
      cardId: cardId,
      subject: subject,
      destination: destination,
      rejection: rejection,
      dropCause: dropCause,
      actorId: actor,
      copyText: copyText,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RejectedOp &&
        other.opId == opId &&
        other.kind == kind &&
        other.cardId == cardId &&
        other.subject == subject &&
        other.destination == destination &&
        other.rejection == rejection &&
        other.dropCause == dropCause &&
        other.actorId == actorId &&
        other.copyText == copyText;
  }

  @override
  int get hashCode => Object.hash(
    opId,
    kind,
    cardId,
    subject,
    destination,
    rejection,
    dropCause,
    actorId,
    copyText,
  );

  @override
  String toString() => 'RejectedOp($opId, ${kind.name})';
}

RejectedOp describeRejected(
  BoardOp op,
  BoardModel confirmed,
  BoardModel view, {
  OpRejection? rejection,
  DropCause? dropCause,
}) {
  String? cardTitle(String id) =>
      confirmed.cardById(id)?.title ?? view.cardById(id)?.title;
  String? columnTitle(String id) =>
      confirmed.columnById(id)?.title ?? view.columnById(id)?.title;
  RejectedOp build(
    RejectedOpKind kind, {
    String? cardId,
    String? subject,
    String? destination,
    String copyText = '',
  }) {
    return RejectedOp(
      opId: op.opId,
      kind: kind,
      cardId: cardId,
      subject: subject,
      destination: destination,
      rejection: rejection,
      dropCause: dropCause,
      actorId: rejection?.actorId,
      copyText: copyText,
    );
  }

  switch (op) {
    case MoveCard():
      return build(
        RejectedOpKind.move,
        cardId: op.cardId,
        subject: cardTitle(op.cardId),
        destination: columnTitle(op.toColumnId),
      );
    case CreateCard():
      return build(
        RejectedOpKind.create,
        subject: op.title,
        copyText: op.description.isEmpty
            ? op.title
            : '${op.title}\n${op.description}',
      );
    case EditCardTitle():
      return build(
        RejectedOpKind.editTitle,
        cardId: op.cardId,
        subject: cardTitle(op.cardId),
        copyText: op.title,
      );
    case EditCardDescription():
      return build(
        RejectedOpKind.editDescription,
        cardId: op.cardId,
        subject: cardTitle(op.cardId),
        copyText: op.description,
      );
    case ArchiveCard():
      return build(
        RejectedOpKind.archive,
        cardId: op.cardId,
        subject: cardTitle(op.cardId),
      );
    case CreateColumn():
      return build(
        RejectedOpKind.createColumn,
        subject: op.title,
        copyText: op.title,
      );
    case RenameColumn():
      return build(
        RejectedOpKind.renameColumn,
        subject: columnTitle(op.columnId),
        copyText: op.title,
      );
    case MoveColumn():
      return build(
        RejectedOpKind.moveColumn,
        subject: columnTitle(op.columnId),
      );
    case ArchiveColumn():
      return build(
        RejectedOpKind.archiveColumn,
        subject: columnTitle(op.columnId),
      );
  }
}

class RejectionLog {
  RejectionLog(List<RejectedOp> entries)
    : entries = List<RejectedOp>.unmodifiable(entries);

  const RejectionLog.empty() : entries = const <RejectedOp>[];

  static const int maxEntries = 50;

  final List<RejectedOp> entries;

  bool get isEmpty => entries.isEmpty;

  Set<String> get ids => <String>{for (final entry in entries) entry.opId};

  bool contains(String opId) => entries.any((entry) => entry.opId == opId);

  RejectionLog add(Iterable<RejectedOp> items) {
    final known = ids;
    final fresh = <RejectedOp>[
      for (final item in items)
        if (known.add(item.opId)) item,
    ];
    if (fresh.isEmpty) {
      return this;
    }
    return RejectionLog(<RejectedOp>[...entries, ...fresh]);
  }

  RejectionLog capped(Set<String> keep) {
    var excess = entries.length - maxEntries;
    if (excess <= 0) {
      return this;
    }
    final kept = <RejectedOp>[];
    for (final entry in entries) {
      if (excess > 0 && !keep.contains(entry.opId)) {
        excess--;
      } else {
        kept.add(entry);
      }
    }
    return RejectionLog(kept);
  }

  RejectionLog only(Set<String> keep) {
    return RejectionLog(<RejectedOp>[
      for (final entry in entries)
        if (keep.contains(entry.opId)) entry,
    ]);
  }

  RejectionLog withActor(String opId, String actorId) {
    final index = entries.indexWhere(
      (entry) => entry.opId == opId && entry.actorId == null,
    );
    if (index < 0) {
      return this;
    }
    return RejectionLog(<RejectedOp>[
      for (var i = 0; i < entries.length; i++)
        i == index ? entries[i].withActor(actorId) : entries[i],
    ]);
  }

  List<RejectedOp> forIds(Iterable<String> opIds) {
    final wanted = opIds.toSet();
    return <RejectedOp>[
      for (final entry in entries)
        if (wanted.contains(entry.opId)) entry,
    ];
  }

  @override
  bool operator ==(Object other) {
    return other is RejectionLog && listEquals(other.entries, entries);
  }

  @override
  int get hashCode => Object.hashAll(entries);

  @override
  String toString() => 'RejectionLog(${entries.length})';
}
