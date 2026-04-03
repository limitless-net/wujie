import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/models/models.dart';

/// 订单仓储接口
abstract class OrderRepository {
  /// 获取订单列表
  Future<Result<List<DomainOrder>>> getOrders();

  /// 根据交易号获取订单详情
  Future<Result<DomainOrder>> getOrderByTradeNo(String tradeNo);

  /// 创建订单
  /// 
  /// 返回订单的交易号（tradeNo）
  Future<Result<String>> createOrder({
    required int planId,
    required String period,
    String? couponCode,
  });

  /// 取消订单
  Future<Result<void>> cancelOrder(String tradeNo);
}
