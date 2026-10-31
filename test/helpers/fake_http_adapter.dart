import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeResponse {
  const FakeResponse(
    this.status, {
    this.json,
    this.text,
    this.headers = const <String, String>{},
    this.failure,
  });

  factory FakeResponse.ok(Object? json, {int status = 200}) =>
      FakeResponse(status, json: json);

  factory FakeResponse.empty(int status) => FakeResponse(status);

  factory FakeResponse.error(
    int status,
    String code, {
    String message = 'message',
    Map<String, String> headers = const <String, String>{},
  }) => FakeResponse(
    status,
    json: <String, Object?>{
      'error': <String, Object?>{'code': code, 'message': message},
    },
    headers: headers,
  );

  factory FakeResponse.network(DioExceptionType type) =>
      FakeResponse(0, failure: type);

  final int status;
  final Object? json;
  final String? text;
  final Map<String, String> headers;
  final DioExceptionType? failure;
}

class RecordedRequest {
  RecordedRequest(RequestOptions options)
    : method = options.method,
      path = options.path,
      headers = <String, dynamic>{
        for (final entry in options.headers.entries)
          entry.key.toLowerCase(): entry.value,
      },
      data = options.data;

  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Object? data;

  String? get authorization => headers['authorization'] as String?;

  Map<String, dynamic> get body => data! as Map<String, dynamic>;
}

typedef FakeHandler = FutureOr<FakeResponse> Function(RequestOptions options);

class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter([FakeHandler? handler])
    : handler = handler ?? ((options) => FakeResponse.error(404, 'not_found'));

  FakeHandler handler;
  final List<RecordedRequest> requests = <RecordedRequest>[];

  List<RecordedRequest> to(String path) =>
      requests.where((request) => request.path == path).toList();

  int count(String path) => to(path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(RecordedRequest(options));
    final response = await handler(options);
    final failure = response.failure;
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure);
    }
    final String body;
    if (response.text != null) {
      body = response.text!;
    } else if (response.json != null) {
      body = jsonEncode(response.json);
    } else {
      body = '';
    }
    return ResponseBody.fromString(
      body,
      response.status,
      headers: <String, List<String>>{
        if (body.isNotEmpty && !_hasContentType(response.headers))
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        for (final entry in response.headers.entries)
          entry.key: <String>[entry.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

bool _hasContentType(Map<String, String> headers) {
  return headers.keys.any((key) => key.toLowerCase() == 'content-type');
}
