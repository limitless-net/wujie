import 'package:fl_clash/xboard/core/core.dart';

/// 认证仓储接口
abstract class AuthRepository {
  /// 登录
  Future<Result<void>> login({
    required String email,
    required String password,
  });

  /// 注册
  Future<Result<void>> register({
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
  });

  /// 登出
  Future<Result<void>> logout();

  /// 发送验证码
  Future<Result<void>> sendVerificationCode(String email);

  /// 重置密码
  Future<Result<void>> resetPassword({
    required String email,
    required String password,
    required String emailCode,
  });

  /// 检查是否已登录
  Future<bool> isLoggedIn();

  /// 获取认证 Token
  Future<String?> getAuthToken();
}
