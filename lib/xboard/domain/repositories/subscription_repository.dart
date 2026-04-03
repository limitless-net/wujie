import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/models/models.dart';

/// 订阅仓储接口
abstract class SubscriptionRepository {
  /// 获取订阅信息
  Future<Result<DomainSubscription>> getSubscription();

  /// 获取订阅链接
  Future<Result<String>> getSubscriptionUrl();

  /// 重置订阅链接
  Future<Result<String>> resetSubscriptionUrl();
}
