enum NackReason {
  versionConflict,
  notFound,
  forbidden,
  validationError,
  rateLimited,
  resyncRequired,
  internal,
}

class OpRejection {
  const OpRejection({
    required this.reason,
    this.atSeq,
    this.actorId,
    this.limit,
  });

  final NackReason reason;
  final int? atSeq;
  final String? actorId;
  final int? limit;

  OpRejection withSeq(int seq) {
    return OpRejection(
      reason: reason,
      atSeq: atSeq ?? seq,
      actorId: actorId,
      limit: limit,
    );
  }

  OpRejection withActor(String? actor) {
    return OpRejection(
      reason: reason,
      atSeq: atSeq,
      actorId: actor,
      limit: limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OpRejection &&
        other.reason == reason &&
        other.atSeq == atSeq &&
        other.actorId == actorId &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(reason, atSeq, actorId, limit);

  @override
  String toString() => 'OpRejection(${reason.name}, at $atSeq)';
}
