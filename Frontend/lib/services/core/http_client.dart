import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_env.dart';
import '../local_storage.dart';

typedef RawRequest = Future<http.Response> Function();

class HttpClient {
  HttpClient._();

  static final HttpClient instance = HttpClient._();

  bool _isRefreshing = false;
  final List<Completer<Map<String, dynamic>>> _refreshQueue = [];

  void Function()? onAuthFailed;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    bool skipAuth = false,
  }) {
    final uri = _uri(path, queryParameters);
    return send(() => http.get(uri, headers: _headers(skipAuth: skipAuth)), uri.path);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
    bool skipAuth = false,
  }) {
    final uri = _uri(path, queryParameters);
    return send(
      () => http.post(
        uri,
        headers: _headers(skipAuth: skipAuth),
        body: body == null ? null : jsonEncode(body),
      ),
      uri.path,
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
    bool skipAuth = false,
  }) {
    final uri = _uri(path, queryParameters);
    return send(
      () => http.put(
        uri,
        headers: _headers(skipAuth: skipAuth),
        body: body == null ? null : jsonEncode(body),
      ),
      uri.path,
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
    bool skipAuth = false,
  }) {
    final uri = _uri(path, queryParameters);
    return send(
      () => http.delete(
        uri,
        headers: _headers(skipAuth: skipAuth),
        body: body == null ? null : jsonEncode(body),
      ),
      uri.path,
    );
  }

  Future<Map<String, dynamic>> multipart(
    String method,
    String path, {
    required List<http.MultipartFile> files,
    Map<String, String>? fields,
    Map<String, String>? queryParameters,
    bool skipAuth = false,
  }) {
    final uri = _uri(path, queryParameters);
    return send(() async {
      final request = http.MultipartRequest(method, uri);
      request.headers.addAll(_headers(json: false, skipAuth: skipAuth));
      request.fields.addAll(fields ?? const {});
      request.files.addAll(files);
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    }, uri.path);
  }

  Future<Map<String, dynamic>> send(RawRequest requestFn, String requestPath) async {
    final response = await requestFn();
    final result = parseResponse(response);

    if (result['statusCode'] == 401 && !requestPath.contains('/auth/refresh')) {
      return _retryWithRefresh(requestFn);
    }

    return result;
  }

  Map<String, String> _headers({bool json = true, bool skipAuth = false}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (!skipAuth) {
      final token = LocalStorage.instance.read('accessToken');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final raw = path.startsWith('http://') || path.startsWith('https://')
        ? path
        : '${AppEnv.apiBaseUrl}${path.startsWith('/') ? path : '/$path'}';
    final uri = Uri.parse(raw);
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...queryParameters,
    });
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final refreshToken = LocalStorage.instance.read('refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('没有refreshToken，请重新登录');
    }

    final response = await http.post(
      _uri('/auth/refresh'),
      headers: _headers(skipAuth: true),
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    return parseResponse(response);
  }

  Future<Map<String, dynamic>> _retryWithRefresh(RawRequest requestFn) async {
    if (_isRefreshing) {
      final completer = Completer<Map<String, dynamic>>();
      _refreshQueue.add(completer);
      final refreshResult = await completer.future;
      if (refreshResult['statusCode'] == 200) {
        return parseResponse(await requestFn());
      }
      return refreshResult;
    }

    _isRefreshing = true;

    try {
      final refreshResult = await refreshToken();
      if (refreshResult['statusCode'] != 200) {
        await _clearTokensAndNotify();
        _completeRefreshQueue(refreshResult, null);
        return refreshResult;
      }

      final body = refreshResult['body'] as Map<String, dynamic>?;
      final token = body?['token'] as String? ?? '';
      final newRefreshToken = body?['refreshToken'] as String? ?? '';
      if (token.isEmpty || newRefreshToken.isEmpty) {
        final errorResult = {
          'statusCode': 401,
          'body': {'message': '刷新Token失败，请重新登录'},
        };
        await _clearTokensAndNotify();
        _completeRefreshQueue(errorResult, null);
        return errorResult;
      }

      await LocalStorage.instance.write('accessToken', token);
      await LocalStorage.instance.write('refreshToken', newRefreshToken);
      _completeRefreshQueue(refreshResult, null);
      return parseResponse(await requestFn());
    } catch (e) {
      await _clearTokensAndNotify();
      _completeRefreshQueue(null, e);
      return {
        'statusCode': 401,
        'body': {'message': '刷新Token失败，请重新登录'},
      };
    } finally {
      _isRefreshing = false;
    }
  }

  void _completeRefreshQueue(Map<String, dynamic>? result, Object? error) {
    for (final completer in _refreshQueue) {
      if (error != null) {
        completer.completeError(error);
      } else if (result != null) {
        completer.complete(result);
      } else {
        completer.completeError(Exception('刷新Token失败'));
      }
    }
    _refreshQueue.clear();
  }

  Future<void> _clearTokensAndNotify() async {
    await LocalStorage.instance.delete('accessToken');
    await LocalStorage.instance.delete('refreshToken');
    onAuthFailed?.call();
  }

  Map<String, dynamic> parseResponse(http.Response response) {
    if (response.body.trim().isEmpty) {
      return {
        'statusCode': response.statusCode,
        'body': {'message': response.statusCode == 204 ? '操作成功' : '服务器返回空响应'},
      };
    }

    try {
      return {
        'statusCode': response.statusCode,
        'body': jsonDecode(response.body),
      };
    } catch (_) {
      return {
        'statusCode': response.statusCode,
        'body': {'message': '服务器响应格式错误'},
      };
    }
  }
}
