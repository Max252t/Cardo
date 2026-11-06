import 'realtime_transport.dart';

RealtimeTransport createRealtimeTransport() =>
    const UnsupportedRealtimeTransport();

class UnsupportedRealtimeTransport implements RealtimeTransport {
  const UnsupportedRealtimeTransport();

  @override
  Future<RealtimeChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    throw const RealtimeUnsupportedException();
  }
}
