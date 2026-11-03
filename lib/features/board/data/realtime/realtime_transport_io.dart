import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/network/api_policy.dart';
import '../../../../core/realtime/realtime_policy.dart';
import 'realtime_transport.dart';

RealtimeTransport createRealtimeTransport() => const IoRealtimeTransport();

class IoRealtimeTransport implements RealtimeTransport {
  const IoRealtimeTransport({this.pingInterval = RealtimePolicy.pingInterval});

  final Duration pingInterval;

  @override
  Future<RealtimeChannel> connect(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final channel = IOWebSocketChannel.connect(
      uri,
      headers: headers,
      pingInterval: pingInterval,
      connectTimeout: ApiPolicy.connectTimeout,
    );
    try {
      await channel.ready;
    } on WebSocketChannelException catch (error) {
      final inner = error.inner;
      final status = inner is WebSocketException ? inner.httpStatusCode : null;
      if (status != null) {
        throw RealtimeUpgradeRejected(status);
      }
      rethrow;
    }
    return _IoChannel(channel);
  }
}

class _IoChannel implements RealtimeChannel {
  _IoChannel(this._channel) : messages = _channel.stream.map(_asText);

  final WebSocketChannel _channel;

  @override
  final Stream<String> messages;

  static String _asText(dynamic frame) {
    if (frame is String) {
      return frame;
    }
    throw const FormatException('binary frame');
  }

  @override
  int? get closeCode => _channel.closeCode;

  @override
  String? get closeReason => _channel.closeReason;

  @override
  void send(String text) => _channel.sink.add(text);

  @override
  Future<void> close([int? code, String? reason]) =>
      _channel.sink.close(code, reason);
}
