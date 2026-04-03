import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/order.freezed.dart';
part 'generated/order.g.dart';

/// 领域层：订单模型
@freezed
class DomainOrder with _$DomainOrder {
  const factory DomainOrder({
    /// 订单号（交易号）
    required String tradeNo,
    
    /// 套餐 ID
    required int planId,
    
    /// 周期类型
    required String period,
    
    /// 订单金额（元）
    required double totalAmount,
    
    /// 订单状态
    required OrderStatus status,
    
    /// 套餐名称（可选）
    String? planName,
    
    /// 创建时间
    required DateTime createdAt,
    
    /// 支付时间
    DateTime? paidAt,
    
    /// 元数据
    @Default({}) Map<String, dynamic> metadata,
  }) = _DomainOrder;

  const DomainOrder._();

  factory DomainOrder.fromJson(Map<String, dynamic> json) => 
    _$DomainOrderFromJson(json);

  // ========== 业务逻辑 ==========

  /// 是否待支付
  bool get isPending => status == OrderStatus.pending;

  /// 是否已完成
  bool get isCompleted => status == OrderStatus.completed;

  /// 是否已取消
  bool get isCanceled => status == OrderStatus.canceled;

  /// 是否正在处理
  bool get isProcessing => status == OrderStatus.processing;

  /// 是否可以支付
  bool get canPay => status == OrderStatus.pending;

  /// 是否可以取消（待付款和开通中的订单都可以取消）
  bool get canCancel => status == OrderStatus.pending || status == OrderStatus.processing;

  /// 是否需要在创建新订单前自动取消（后端要求）
  bool get shouldAutoCancelBeforeNewOrder => canCancel;
}

/// 订单状态枚举
enum OrderStatus {
  /// 待支付
  pending(0, '待支付'),
  
  /// 开通中
  processing(1, '开通中'),
  
  /// 已取消
  canceled(2, '已取消'),
  
  /// 已完成
  completed(3, '已完成'),
  
  /// 已折抵
  discounted(4, '已折抵');

  const OrderStatus(this.code, this.label);
  
  final int code;
  final String label;

  static OrderStatus fromCode(int code) {
    return OrderStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => OrderStatus.pending,
    );
  }
}

/// 佣金状态枚举
enum OrderCommissionStatus {
  /// 待确认
  pending(0, '待确认'),
  
  /// 发放中
  processing(1, '发放中'),
  
  /// 已发放
  completed(2, '已发放'),
  
  /// 无佣金
  none(3, '无佣金');

  const OrderCommissionStatus(this.code, this.label);
  
  final int code;
  final String label;

  static OrderCommissionStatus fromCode(int code) {
    return OrderCommissionStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => OrderCommissionStatus.pending,
    );
  }
}
