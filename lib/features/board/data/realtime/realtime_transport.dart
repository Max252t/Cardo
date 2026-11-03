abstract interface class RealtimeChannel {
  Stream<String> get messages;

  int? get closeCode;

  String? get closeReason;

  void send(String text);

  Future<void> close([int? code, String? reason]);
}

abstract interface class RealtimeTransport {
  Future<RealtimeChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
  });
}

class RealtimeUnsupportedException implements Exception {
  const RealtimeUnsupportedException();

  @override
  String toString() => 'RealtimeUnsupportedException';
}

class RealtimeUpgradeRejected implements Exception {
  const RealtimeUpgradeRejected(this.status);

  final int status;

  @override
  String toString() => 'RealtimeUpgradeRejected($status)';
}
