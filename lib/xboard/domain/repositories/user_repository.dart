import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/models/models.dart';

/// 用户仓储接口
/// 
/// 定义用户相关数据访问的契约
/// 具体实现由基础设施层提供（XBoard、V2Board等）
abstract class UserRepository {
  /// 获取当前用户信息
  Future<Result<DomainUser>> getUserInfo();

  /// 验证 Token 是否有效
  Future<Result<bool>> validateToken();

  /// 切换流量提醒
  Future<Result<void>> toggleTrafficReminder(bool enabled);

  /// 切换到期提醒
  Future<Result<void>> toggleExpireReminder(bool enabled);
}
