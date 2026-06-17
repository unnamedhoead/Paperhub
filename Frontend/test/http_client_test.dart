import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/services/core/http_client.dart';

void main() {
  test('parseResponse decodes json body with status code', () {
    final result = HttpClient.instance.parseResponse(
      http.Response('{"message":"ok","value":1}', 200),
    );

    expect(result['statusCode'], 200);
    expect(result['body']['message'], 'ok');
    expect(result['body']['value'], 1);
  });

  test('parseResponse handles empty 204 response', () {
    final result = HttpClient.instance.parseResponse(http.Response('', 204));

    expect(result['statusCode'], 204);
    expect(result['body']['message'], '操作成功');
  });

  test('parseResponse handles invalid json response', () {
    final result = HttpClient.instance.parseResponse(http.Response('not-json', 500));

    expect(result['statusCode'], 500);
    expect(result['body']['message'], '服务器响应格式错误');
  });
}
