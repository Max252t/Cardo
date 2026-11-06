import '../data/realtime/protocol_issue.dart';

class ProtocolIssueTally {
  ProtocolIssueTally({this.threshold = defaultThreshold});

  static const int defaultThreshold = 3;

  final int threshold;
  int _unknown = 0;
  bool _announced = false;

  bool get announced => _announced;

  bool record(ProtocolIssue issue) {
    if (_announced || issue is! UnknownMessageType) {
      return false;
    }
    _unknown++;
    if (_unknown < threshold) {
      return false;
    }
    _announced = true;
    return true;
  }
}
