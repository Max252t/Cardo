import 'package:cardo/features/board/data/realtime/protocol_issue.dart';
import 'package:cardo/features/board/presentation/protocol_issue_tally.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('announces once after repeated unknown message types', () {
    final tally = ProtocolIssueTally(threshold: 3);

    expect(tally.record(const UnknownMessageType('a')), isFalse);
    expect(tally.record(const UnknownMessageType('b')), isFalse);
    expect(tally.record(const UnknownMessageType('c')), isTrue);
    expect(tally.announced, isTrue);
    expect(tally.record(const UnknownMessageType('d')), isFalse);
  });

  test('other issues never trigger the announcement', () {
    final tally = ProtocolIssueTally(threshold: 1);

    expect(tally.record(const MalformedMessage('x')), isFalse);
    expect(tally.record(const InvalidPayload('t', 'd')), isFalse);
    expect(tally.record(const BinaryFrameReceived()), isFalse);
    expect(tally.announced, isFalse);
  });

  test('the default threshold is three', () {
    final tally = ProtocolIssueTally();

    expect(tally.record(const UnknownMessageType('a')), isFalse);
    expect(tally.record(const UnknownMessageType('a')), isFalse);
    expect(tally.record(const UnknownMessageType('a')), isTrue);
  });
}
