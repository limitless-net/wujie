import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/models/models.dart';

/// 邀请仓储接口
abstract class InviteRepository {
  /// 获取邀请信息
  Future<Result<DomainInvite>> getInviteInfo();

  /// 生成邀请码
  Future<Result<DomainInviteCode>> generateInviteCode();

  /// 获取佣金历史
  Future<Result<List<DomainCommission>>> getCommissionHistory({
    int page = 1,
    int pageSize = 100,
  });

  /// 划转佣金到余额
  /// 
  /// [amountInYuan] 划转金额（元）
  Future<Result<void>> transferCommissionToBalance(double amountInYuan);

  /// 提现佣金
  /// 
  /// [method] 提现方式（如：支付宝、微信）
  /// [account] 提现账户
  Future<Result<void>> withdrawCommission({
    required String method,
    required String account,
  });
}
