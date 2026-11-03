sealed class ProtocolIssue {
  const ProtocolIssue();
}

final class MalformedMessage extends ProtocolIssue {
  const MalformedMessage(this.detail);

  final String detail;

  @override
  bool operator ==(Object other) =>
      other is MalformedMessage && other.detail == detail;

  @override
  int get hashCode => Object.hash(MalformedMessage, detail);

  @override
  String toString() => 'MalformedMessage($detail)';
}

final class UnsupportedVersion extends ProtocolIssue {
  const UnsupportedVersion(this.version);

  final Object? version;

  @override
  bool operator ==(Object other) =>
      other is UnsupportedVersion && other.version == version;

  @override
  int get hashCode => Object.hash(UnsupportedVersion, version);

  @override
  String toString() => 'UnsupportedVersion($version)';
}

final class UnknownMessageType extends ProtocolIssue {
  const UnknownMessageType(this.type);

  final String type;

  @override
  bool operator ==(Object other) =>
      other is UnknownMessageType && other.type == type;

  @override
  int get hashCode => Object.hash(UnknownMessageType, type);

  @override
  String toString() => 'UnknownMessageType($type)';
}

final class InvalidPayload extends ProtocolIssue {
  const InvalidPayload(this.type, this.detail);

  final String type;
  final String detail;

  @override
  bool operator ==(Object other) =>
      other is InvalidPayload && other.type == type && other.detail == detail;

  @override
  int get hashCode => Object.hash(InvalidPayload, type, detail);

  @override
  String toString() => 'InvalidPayload($type, $detail)';
}

final class BinaryFrameReceived extends ProtocolIssue {
  const BinaryFrameReceived();

  @override
  bool operator ==(Object other) => other is BinaryFrameReceived;

  @override
  int get hashCode => (BinaryFrameReceived).hashCode;

  @override
  String toString() => 'BinaryFrameReceived';
}

final class OutgoingTooLarge extends ProtocolIssue {
  const OutgoingTooLarge(this.bytes);

  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is OutgoingTooLarge && other.bytes == bytes;

  @override
  int get hashCode => Object.hash(OutgoingTooLarge, bytes);

  @override
  String toString() => 'OutgoingTooLarge($bytes)';
}

final class ServerReportedError extends ProtocolIssue {
  const ServerReportedError(this.code, this.message);

  final String code;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is ServerReportedError &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(ServerReportedError, code, message);

  @override
  String toString() => 'ServerReportedError($code, $message)';
}

final class NackWithoutOpId extends ProtocolIssue {
  const NackWithoutOpId();

  @override
  bool operator ==(Object other) => other is NackWithoutOpId;

  @override
  int get hashCode => (NackWithoutOpId).hashCode;

  @override
  String toString() => 'NackWithoutOpId';
}

final class ClosedForProtocolViolation extends ProtocolIssue {
  const ClosedForProtocolViolation(this.reason);

  final String? reason;

  @override
  bool operator ==(Object other) =>
      other is ClosedForProtocolViolation && other.reason == reason;

  @override
  int get hashCode => Object.hash(ClosedForProtocolViolation, reason);

  @override
  String toString() => 'ClosedForProtocolViolation($reason)';
}

final class RealtimeNotSupported extends ProtocolIssue {
  const RealtimeNotSupported();

  @override
  bool operator ==(Object other) => other is RealtimeNotSupported;

  @override
  int get hashCode => (RealtimeNotSupported).hashCode;

  @override
  String toString() => 'RealtimeNotSupported';
}
