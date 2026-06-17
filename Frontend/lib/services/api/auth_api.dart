import '../core/http_client.dart';
import '../local_storage.dart';

class AuthApi {
  /// 发送邮箱验证码
  static Future<Map<String, dynamic>> sendVerification(String email) async {
    return HttpClient.instance.post('/auth/send-verification', body: {
      'email': email,
    });
  }

  /// 校验验证码
  static Future<Map<String, dynamic>> verifyCode(
    String email,
    String code,
  ) async {
    return HttpClient.instance.post('/auth/verify', body: {
      'email': email,
      'code': code,
    });
  }

  /// 用户注册
  static Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
    return HttpClient.instance.post('/auth/register', body: {
      'email': email,
      'password': password,
    });
  }

  /// 用户登录
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    return HttpClient.instance.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
  }

  /// 请求重置密码（发送验证码）
  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    return HttpClient.instance.post('/auth/request-reset', body: {
      'email': email,
    });
  }

  /// 重置密码（验证码 + 新密码）
  static Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    return HttpClient.instance.post('/auth/reset-password', body: {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }

  /// 刷新Token
  static Future<Map<String, dynamic>> refreshToken() async {
    return HttpClient.instance.refreshToken();
  }

  /// 退出登录（清除所有Token）
  static Future<void> logout() async {
    await LocalStorage.instance.delete('accessToken');
    await LocalStorage.instance.delete('refreshToken');
  }
}
