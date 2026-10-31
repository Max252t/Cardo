import 'package:dio/dio.dart';

import 'api_policy.dart';

Dio createDio(Uri baseUri, {HttpClientAdapter? adapter}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUri.toString(),
      connectTimeout: ApiPolicy.connectTimeout,
      sendTimeout: ApiPolicy.sendTimeout,
      receiveTimeout: ApiPolicy.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: <String, Object>{Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
  }
  return dio;
}
