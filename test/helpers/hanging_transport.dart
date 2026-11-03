import 'dart:async';

import 'package:cardo/features/board/data/realtime/realtime_transport.dart';

class HangingTransport implements RealtimeTransport {
  final List<Uri> attempts = <Uri>[];
  final List<Map<String, String>> headers = <Map<String, String>>[];

  @override
  Future<RealtimeChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) {
    attempts.add(uri);
    this.headers.add(headers);
    return Completer<RealtimeChannel>().future;
  }
}
